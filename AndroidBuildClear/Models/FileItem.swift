import Foundation

/// 待扫描的根目录。对应 Compose 版的 `Folder` / `FileInfo`。
///
/// 标注 `nonisolated` 是为了让它能安全地穿过 MainActor 边界
/// （目录遍历放在后台线程执行）。
nonisolated struct FolderItem: Identifiable, Hashable, Sendable {

    let url: URL

    /// 用路径当身份，天然去重（Compose 版也是用 path 做 key）。
    var id: String { path }

    var path: String { url.path(percentEncoded: false) }

    /// 磁盘根目录的 `lastPathComponent` 会是空串，这里兜底显示完整路径。
    var name: String {
        let last = url.lastPathComponent
        return last.isEmpty ? path : last
    }
}

/// 被扫描出来的 `build` 产物目录。对应 Compose 版的 `BuildFile`。
nonisolated struct BuildFileItem: Identifiable, Hashable, Sendable {

    /// 它所属的根文件夹路径，用于在移除文件夹时一并清理。
    let rootPath: String

    let path: String

    var isChecked: Bool = true

    var id: String { path }

    var name: String { (path as NSString).lastPathComponent }

    var url: URL { URL(fileURLWithPath: path) }

    /// 与 Compose 的 `BuildFile.toggle()` 一致：返回一份翻转勾选状态后的副本。
    func toggled() -> BuildFileItem {
        var copy = self
        copy.isChecked.toggle()
        return copy
    }
}
