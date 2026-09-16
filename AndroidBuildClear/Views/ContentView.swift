import SwiftUI

/// 主界面。对应 Compose 版的 `App()`：
/// 左右分栏 + 左侧文件夹面板 + 右侧 build 目录面板。
struct ContentView: View {

    @Environment(WorkspaceStore.self) private var store

    @State private var leftWidth: CGFloat = 280

    /// 工具栏 + 标题栏的高度，由 `WindowTitleBarConfigurator` 量出来后回填。
    @State private var chromeHeight: CGFloat = 0

    var body: some View {
        @Bindable var store = store

        ResizableSplitView(leftWidth: $leftWidth) {
            FolderPanelView(topInset: chromeHeight)
        } right: {
            BuildFilePanelView(topInset: chromeHeight)
        }
        .frame(minWidth: 780, minHeight: 500)
        // 列表拉通窗口顶底：内容滚到工具栏底下（玻璃才折射得到东西），
        // 裁剪边界退到窗口外沿，不再有"在半空中被切断"的观感。
        // 平时内容待在工具栏下方，靠的是各栏里那块看不见的留白。
        .ignoresSafeArea(edges: [.top, .bottom])
        .background(AppBackdrop())
        .background(WindowTitleBarConfigurator(topChromeHeight: $chromeHeight))
        // 用原生工具栏：macOS 26 的工具栏本来就是"控件各自一块悬浮玻璃"的形态，
        // 不去画整条背景，这才是备忘录那种观感。
        .toolbar {
            // NSToolbar 是从最左边依次摆项的，不加弹性空格的话所有项都会贴在左边。
            // 这个 spacer 等价于 AppKit 的 flexible space，把后面的项顶到靠右。
            ToolbarSpacer()

            // 计数单独一组
            ToolbarItemGroup(placement: .primaryAction) {
                countsButton
            }

            // 两组之间必须来一段固定间隔：光靠分组边界，系统还是会
            // 把相邻的两组画成同一块玻璃，看着就是一坨。
            ToolbarSpacer(.fixed)

            // 真正会改变状态的操作
            ToolbarItemGroup(placement: .primaryAction) {
                scanButton
                addFolderButton
            }
        }
        .alert("删除 build 目录？", isPresented: $store.isConfirmingDelete) {
            Button("取消", role: .cancel) { }
            Button("删除 \(store.checkedCount) 个目录", role: .destructive) {
                store.deleteChecked()
            }
        } message: {
            Text("这些目录会被彻底删除、无法恢复。请确认它们都只是可以重新生成的构建产物。")
        }
        .alert(
            "有目录没能删除",
            isPresented: Binding(
                get: { store.deleteErrorMessage != nil },
                set: { if !$0 { store.deleteErrorMessage = nil } }
            )
        ) {
            Button("知道了", role: .cancel) { store.deleteErrorMessage = nil }
        } message: {
            Text(store.deleteErrorMessage ?? "")
        }
    }

    /// 计数按钮：图标 + 数字，省横向空间；完整说明交给悬停提示。
    /// 同时兼作全选开关 —— 还有没勾的就全勾上，已经全勾了则全取消。
    private var countsButton: some View {
        Button {
            store.toggleAllChecked()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "folder")
                Text("\(store.folders.count)")

                Text("|")
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 1)

                Image(systemName: "hammer")
                Text("\(store.buildFiles.count)")
            }
            // 数字变化时宽度不抖
            .monospacedDigit()
        }
        .disabled(store.buildFiles.isEmpty)
        .help(countsHelp)
    }

    private var countsHelp: String {
        let action = store.hasChecked ? "点击可全部取消勾选" : "点击可全部勾选"
        return """
        \(store.folders.count) 个文件夹
        \(store.buildFiles.count) 个 build 目录
        \(action)
        """
    }

    /// 扫描按钮：图标和转圈**常驻**在同一个固定尺寸的槽位里，只切透明度。
    /// 若写成 if/else 二选一，工具栏项的度量会变化，NSToolbar 重新测量后整组重排，
    /// 看起来就是"点一下抖一下"。
    private var scanButton: some View {
        Button {
            store.scan()
        } label: {
            Label {
                Text("重新扫描")
            } icon: {
                ZStack {
                    Image(systemName: "arrow.clockwise")
                        .opacity(store.isBusy ? 0 : 1)

                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                        .opacity(store.isBusy ? 1 : 0)
                }
                .frame(width: 16, height: 16)
            }
        }
        .disabled(store.folders.isEmpty || store.isBusy)
        .help("重新扫描所有文件夹里的 build 目录 (⌘R)")
    }

    private var addFolderButton: some View {
        Button {
            store.chooseFolders()
        } label: {
            Label("添加文件夹", systemImage: "folder.badge.plus")
        }
        .help("添加要扫描的文件夹 (⌘O)")
    }
}

#Preview {
    ContentView()
        .environment(WorkspaceStore())
}
