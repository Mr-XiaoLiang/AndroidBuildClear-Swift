import SwiftUI

/// 左栏：待扫描的文件夹清单。对应 Compose 版的 `FolderPanel`。
struct FolderPanelView: View {

    @Environment(WorkspaceStore.self) private var store

    /// 顶部留白 = 工具栏 + 标题栏的高度（由窗口配置器量出来）。
    var topInset: CGFloat = 0

    /// 底部留白，让最后一行不至于贴着窗口下沿。
    var bottomInset: CGFloat = 20

    var body: some View {
        list
            // 列表本身拉通整窗（内容能滚到工具栏底下），
            // 但用看不见的留白把内容"推"到工具栏下方，平时不会和工具栏打架。
            .safeAreaInset(edge: .top, spacing: 0) { spacer(topInset) }
            .safeAreaInset(edge: .bottom, spacing: 0) { spacer(bottomInset) }
    }

    private func spacer(_ height: CGFloat) -> some View {
        Color.clear.frame(height: height)
    }

    // MARK: - 清单

    @ViewBuilder
    private var list: some View {
        if store.folders.isEmpty {
            ContentUnavailableView {
                Label("还没有文件夹", systemImage: "folder.badge.plus")
            } description: {
                Text("添加一个装着 Gradle 工程的文件夹，再点「重新扫描」。")
            } actions: {
                Button("添加文件夹…") { store.chooseFolders() }
                    .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(store.folders) { folder in
                FolderRow(folder: folder)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .frame(maxHeight: .infinity)
        }
    }
}

// MARK: - 单行

private struct FolderRow: View {

    @Environment(WorkspaceStore.self) private var store

    let folder: FolderItem

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(folder.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 6)

            Button {
                store.removeFolder(folder)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .opacity(isHovered ? 1 : 0.3)
            .help("从清单里移除")
        }
        .padding(.vertical, 2)
        .onHover { isHovered = $0 }
    }
}
