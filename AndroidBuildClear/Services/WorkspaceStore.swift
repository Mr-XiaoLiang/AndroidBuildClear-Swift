import AppKit
import Foundation
import Observation

/// 状态中枢。对应 Compose 版的 `FinderState` + `FilePathCache` + `FolderChooser`。
///
/// 这里的 `folders` / `buildFiles` / `isBusy` 就是唯一数据源：
/// UI 直接订阅这些属性、直接调用这里的方法，不再往别处搬运状态。
@Observable
final class WorkspaceStore {

    // MARK: - UI 观察的状态

    private(set) var folders: [FolderItem] = []

    private(set) var buildFiles: [BuildFileItem] = []

    /// 扫描或删除进行中（对应 Compose 的 `isLoading`）。
    private(set) var isBusy = false

    /// 删除前的确认弹窗。
    var isConfirmingDelete = false

    /// 删除失败的详情，非 nil 时由界面弹窗展示。
    var deleteErrorMessage: String?

    // MARK: - 派生状态

    var hasChecked: Bool { buildFiles.contains { $0.isChecked } }

    var checkedCount: Int { buildFiles.count(where: \.isChecked) }

    // MARK: - 内部

    @ObservationIgnored private let bookmarks = SecurityScopedBookmarks()

    // MARK: - 启动恢复

    /// 读取上次保存的文件夹。与原实现一致：只恢复清单，扫描交给用户显式触发。
    func restoreSavedFolders() {
        folders = bookmarks.restoreFolders()
        // 顺手把已经不存在或重复的记录从磁盘上清掉。
        bookmarks.persist(folders)
    }

    // MARK: - 文件夹

    /// 原生文件夹选择面板。对应 Compose 版的 `FolderChooser.showNativeFolderChooser`。
    func chooseFolders() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = "添加"
        panel.message = "选择要扫描 Gradle 工程 build 目录的文件夹"

        if let lastFolder = bookmarks.lastFolderURL() {
            panel.directoryURL = lastFolder
        }

        let handler: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let self else { return }
            for url in panel.urls {
                self.addFolder(url)
            }
        }

        // 有窗口时挂成原生 sheet，没有窗口时退化成独立模态面板。
        if let window = NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: window, completionHandler: handler)
        } else {
            panel.begin(completionHandler: handler)
        }
    }

    func addFolder(_ url: URL) {
        let folder = FolderItem(url: url.standardizedFileURL)
        guard !folders.contains(where: { $0.id == folder.id }) else { return }

        bookmarks.beginAccess(folder.url)
        folders.append(folder)
        bookmarks.rememberLast(folder.url)
        bookmarks.persist(folders)
    }

    func removeFolder(_ folder: FolderItem) {
        folders.removeAll { $0.id == folder.id }
        // 与原实现一致：属于该根目录的扫描结果一并丢弃。
        buildFiles.removeAll { $0.rootPath == folder.path }

        bookmarks.stopAccess(folder.url)
        bookmarks.persist(folders)
    }

    // MARK: - 扫描

    func scan() {
        guard !isBusy else { return }

        let roots = folders
        guard !roots.isEmpty else {
            buildFiles = []
            return
        }

        isBusy = true
        Task {
            // 目录遍历扔到后台，逻辑上对应 Compose 的 Dispatchers.IO。
            let found = await Task.detached(priority: .userInitiated) {
                BuildFileScanner.scan(roots: roots)
            }.value

            // 扫描期间文件夹可能被增删，丢掉已经不属于当前清单的结果。
            let validRoots = Set(folders.map(\.path))
            buildFiles = found.filter { validRoots.contains($0.rootPath) }
            isBusy = false
        }
    }

    // MARK: - 勾选

    func toggle(_ item: BuildFileItem) {
        guard let index = buildFiles.firstIndex(where: { $0.id == item.id }) else { return }
        buildFiles[index] = buildFiles[index].toggled()
    }

    /// 全选 / 取消全选。工具栏上那个计数按钮用它。
    /// 只要还有没勾的就全勾上，已经全勾了则全取消。
    func toggleAllChecked() {
        guard !buildFiles.isEmpty else { return }

        let shouldCheckAll = buildFiles.contains { !$0.isChecked }
        buildFiles = buildFiles.map { item in
            var copy = item
            copy.isChecked = shouldCheckAll
            return copy
        }
    }

    // MARK: - 删除

    func requestDeleteChecked() {
        guard hasChecked, !isBusy else { return }
        isConfirmingDelete = true
    }

    func deleteChecked() {
        let targets = buildFiles.filter(\.isChecked)
        guard !targets.isEmpty, !isBusy else { return }

        // 与原实现一致：先从列表移除，再真正动磁盘。
        buildFiles.removeAll { $0.isChecked }
        isBusy = true

        Task {
            let failures = await Task.detached(priority: .userInitiated) {
                BuildFileScanner.delete(items: targets)
            }.value

            isBusy = false
            if !failures.isEmpty {
                deleteErrorMessage = "以下 \(failures.count) 个目录没能删除：\n\n"
                    + failures.prefix(6).joined(separator: "\n")
            }
        }
    }
}
