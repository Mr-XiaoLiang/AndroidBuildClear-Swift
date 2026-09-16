import SwiftUI

/// 右栏：扫描出来的 build 目录清单 + 右下角悬浮的删除按钮。
/// 对应 Compose 版的 `BuildFilePanel`。
struct BuildFilePanelView: View {

    @Environment(WorkspaceStore.self) private var store

    /// 顶部留白 = 工具栏 + 标题栏的高度（由窗口配置器量出来）。
    var topInset: CGFloat = 0

    /// 底部留白要比左栏多：右下角有个悬浮按钮，最后一行得能从它下面露出来。
    var bottomInset: CGFloat = 64

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            list
                // 列表拉通整窗（内容能滚到工具栏底下、也能滚到底沿），
                // 用看不见的留白把内容推到工具栏下方。
                .safeAreaInset(edge: .top, spacing: 0) { spacer(topInset) }
                .safeAreaInset(edge: .bottom, spacing: 0) { spacer(bottomInset) }

            deleteButton
                .padding(18)
        }
    }

    private func spacer(_ height: CGFloat) -> some View {
        Color.clear.frame(height: height)
    }

    // MARK: - 清单

    @ViewBuilder
    private var list: some View {
        if store.buildFiles.isEmpty {
            ContentUnavailableView {
                Label(emptyTitle, systemImage: emptySymbol)
            } description: {
                Text(emptyDescription)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(store.buildFiles) { item in
                BuildFileRow(item: item)
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)
            .frame(maxHeight: .infinity)
        }
    }

    private var emptyTitle: String {
        store.isBusy ? "正在扫描…" : "没有发现 build 目录"
    }

    private var emptySymbol: String {
        store.isBusy ? "hourglass" : "sparkles"
    }

    private var emptyDescription: String {
        store.folders.isEmpty
            ? "先在左边添加要扫描的文件夹。"
            : "点工具栏的「重新扫描」再找一次。"
    }

    // MARK: - 悬浮删除按钮

    private var deleteButton: some View {
        Button {
            store.requestDeleteChecked()
        } label: {
            Label("删除 \(store.checkedCount) 个 build 目录", systemImage: "trash")
                .font(.system(size: 13, weight: .semibold))
        }
        .buttonStyle(.glassProminent)
        .tint(.red)
        .disabled(!store.hasChecked || store.isBusy)
        .opacity(store.hasChecked ? 1 : 0.45)
        .help("删除所有已勾选的 build 目录 (⌘⌫)")
    }
}

// MARK: - 单行

private struct BuildFileRow: View {

    @Environment(WorkspaceStore.self) private var store

    let item: BuildFileItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundStyle(item.isChecked ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.headline)

                Text(item.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 6)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { store.toggle(item) }
    }
}
