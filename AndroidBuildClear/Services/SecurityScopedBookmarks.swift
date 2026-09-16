import Foundation

/// 文件夹清单的持久化。对应 Compose 版的 `FilePathCache`
/// （原版用 `java.util.prefs.Preferences` 存纯路径字符串）。
///
/// Mac 版必须用**安全作用域书签**：App 开启了沙盒，用户通过打开面板授权一次之后，
/// 只记路径字符串下次启动就没有权限了，必须靠书签换回访问权。
final class SecurityScopedBookmarks {

    private enum Key {
        static let folders = "folder_bookmarks"
        static let lastFolder = "last_folder_bookmark"
    }

    private let defaults: UserDefaults

    /// 已经拿到访问权、等待释放的路径，避免重复 start / 提前 stop。
    private var accessingPaths: Set<String> = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - 读取

    /// 恢复上次保存的文件夹列表。路径已失效的条目会被丢弃。
    func restoreFolders() -> [FolderItem] {
        let stored = (defaults.array(forKey: Key.folders) as? [Data]) ?? []
        var items: [FolderItem] = []
        var seenPaths: Set<String> = []

        for data in stored {
            guard let url = resolve(data) else { continue }
            let path = url.path(percentEncoded: false)
            guard seenPaths.insert(path).inserted else { continue }
            guard FileManager.default.fileExists(atPath: path) else { continue }

            beginAccess(url)
            items.append(FolderItem(url: url))
        }
        return items
    }

    /// 打开文件夹选择面板时的初始目录。
    func lastFolderURL() -> URL? {
        guard let data = defaults.data(forKey: Key.lastFolder) else { return nil }
        return resolve(data)
    }

    // MARK: - 写入

    func persist(_ folders: [FolderItem]) {
        let data = folders.compactMap { makeBookmark(for: $0.url) }
        defaults.set(data, forKey: Key.folders)
    }

    func rememberLast(_ url: URL) {
        guard let data = makeBookmark(for: url) else { return }
        defaults.set(data, forKey: Key.lastFolder)
    }

    // MARK: - 沙盒访问权

    func beginAccess(_ url: URL) {
        let path = url.path(percentEncoded: false)
        guard accessingPaths.insert(path).inserted else { return }
        _ = url.startAccessingSecurityScopedResource()
    }

    func stopAccess(_ url: URL) {
        let path = url.path(percentEncoded: false)
        guard accessingPaths.remove(path) != nil else { return }
        url.stopAccessingSecurityScopedResource()
    }

    // MARK: - 私有

    /// 优先创建安全作用域书签；在没有沙盒的环境（例如未签名的本地运行）会失败，
    /// 此时退回普通书签，保证功能不至于完全失效。
    private func makeBookmark(for url: URL) -> Data? {
        if let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            return data
        }
        return try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func resolve(_ data: Data) -> URL? {
        var isStale = false
        if let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) {
            return url
        }
        return try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }
}
