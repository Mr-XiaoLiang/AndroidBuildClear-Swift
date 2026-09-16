import SwiftUI

@main
struct AndroidBuildClearApp: App {

    /// 全局唯一的共享状态。对应 Compose 版里的 `FinderState` 单例，
    /// 这里改成从 environment 注入，避免隐式全局变量。
    @State private var store = WorkspaceStore()

    var body: some Scene {
        // 工具类应用只需要一个窗口，用 Window 而不是 WindowGroup。
        Window("BuildClean", id: "main") {
            ContentView()
                .environment(store)
                .task {
                    store.restoreSavedFolders()
                }
        }
        .defaultSize(width: 1060, height: 680)
        .windowResizability(.contentMinSize)
        // 标题栏的透明化交给 WindowTitleBarConfigurator 用 AppKit 处理：
        // 不能用 .windowStyle(.hiddenTitleBar)，那会把标题栏整个去掉，
        // 工具栏项会因此跑到左边并随着项增删左右乱跳。
        .commands {
            // 单窗口工具：去掉「新建」相关菜单项。
            CommandGroup(replacing: .newItem) { }

            CommandMenu("扫描") {
                Button("添加文件夹…") {
                    store.chooseFolders()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("重新扫描") {
                    store.scan()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(store.folders.isEmpty || store.isBusy)

                Divider()

                Button("删除已勾选的 build 目录") {
                    store.requestDeleteChecked()
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(!store.hasChecked || store.isBusy)
            }
        }
    }
}
