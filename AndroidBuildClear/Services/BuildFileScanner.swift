import Foundation

/// 递归查找 Gradle 模块的 `build` 产物目录。
///
/// 判定条件与 Compose 版 `BuildFileFinder` 完全一致：
/// 同一个目录下同时存在 `build/` 目录，以及 `build.gradle` 或 `build.gradle.kts`。
/// 命中之后不再深入它自己的 `build/` 子目录（那里全是编译产物）。
nonisolated enum BuildFileScanner {

    static let buildDirName = "build"
    static let gradleScriptNames: Set<String> = ["build.gradle", "build.gradle.kts"]

    private static let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
    private static let keySet = Set(resourceKeys)

    /// 同步遍历。调用方负责把它放到后台线程执行。
    static func scan(roots: [FolderItem]) -> [BuildFileItem] {
        var results: [BuildFileItem] = []
        for root in roots {
            collect(root: root, into: &results)
        }
        return results
    }

    private static func collect(root: FolderItem, into results: inout [BuildFileItem]) {
        let manager = FileManager.default

        // 先进先出，跟 Compose 版的 BFS 顺序保持一致（浅层模块排在前面）。
        var pending: [URL] = [root.url]
        var cursor = 0

        while cursor < pending.count {
            let directory = pending[cursor]
            cursor += 1

            // 用 .skipsHiddenFiles 让系统帮我们跳过隐藏项：
            // 构建产物不会藏在隐藏目录里，同时顺带避开了 .git / .gradle 这些巨型目录。
            guard let children = try? manager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            ) else { continue }

            // 注意：判定用的名字集合要收**所有**子项，
            // 因为 build.gradle / build.gradle.kts 是文件而不是目录。
            var allChildNames: Set<String> = []
            var subdirectories: [URL] = []

            for child in children {
                allChildNames.insert(child.lastPathComponent)

                guard let values = try? child.resourceValues(forKeys: keySet),
                      values.isDirectory == true else { continue }

                // 不跟随符号链接，避免软链成环把遍历卡死。
                if values.isSymbolicLink != true {
                    subdirectories.append(child)
                }
            }

            let isModuleRoot = allChildNames.contains(buildDirName)
                && !allChildNames.isDisjoint(with: gradleScriptNames)

            if isModuleRoot {
                let buildURL = directory.appending(path: buildDirName)
                results.append(
                    BuildFileItem(rootPath: root.path, path: buildURL.path(percentEncoded: false))
                )
            }

            for subdirectory in subdirectories {
                // 命中模块根后不再深入它自己的 build 产物目录。
                if isModuleRoot, subdirectory.lastPathComponent == buildDirName { continue }
                pending.append(subdirectory)
            }
        }
    }

    /// 递归删除给定的目录，返回删除失败的条目描述（全部成功时返回空数组）。
    static func delete(items: [BuildFileItem]) -> [String] {
        let manager = FileManager.default
        var failures: [String] = []

        for item in items {
            guard manager.fileExists(atPath: item.path) else { continue }
            do {
                try manager.removeItem(at: item.url)
            } catch {
                failures.append("\(item.path)\n  → \(error.localizedDescription)")
            }
        }
        return failures
    }
}
