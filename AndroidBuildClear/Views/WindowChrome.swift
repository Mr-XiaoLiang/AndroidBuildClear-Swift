import AppKit
import SwiftUI

/// 窗口外观配置：
/// 1. 把标题栏做成"透明的一层"，让内容能铺到窗口最上沿；
/// 2. 把工具栏 + 标题栏占掉的高度报给 SwiftUI —— 列表拉通整窗之后，
///    需要靠这个值把顶部留白补回来，内容平时才会待在工具栏下方。
///
/// 为什么不用 SwiftUI 的 `.windowStyle(.hiddenTitleBar)`：
/// 它连标题栏一起去掉，并且会让工具栏项跑到左边、随项增删左右乱跳。
struct WindowTitleBarConfigurator: NSViewRepresentable {

    /// 工具栏 + 标题栏占据的高度。
    @Binding var topChromeHeight: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = TitleBarTransparentView()
        view.reportChromeHeight = makeReporter()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? TitleBarTransparentView)?.reportChromeHeight = makeReporter()
    }

    private func makeReporter() -> (CGFloat) -> Void {
        { height in
            guard abs(topChromeHeight - height) > 0.5 else { return }
            topChromeHeight = height
        }
    }

    // MARK: -

    private final class TitleBarTransparentView: NSView {

        var reportChromeHeight: ((CGFloat) -> Void)?

        /// 纯配置用的视图，不参与命中测试。
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }

            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            // 内容视图铺满整个窗口（含标题栏区域），背景和列表才透得上来。
            window.styleMask.insert(.fullSizeContentView)
            // 工具栏与标题栏并成一行，配合 titleVisibility = .hidden 就只剩一栏高度。
            window.toolbarStyle = .unified
        }

        override func layout() {
            super.layout()
            report()
        }

        private func report() {
            guard let window else { return }
            let height = Self.chromeHeight(of: window)
            // 延后一拍再回写状态，避免在布局过程中触发 SwiftUI 更新。
            DispatchQueue.main.async { [weak self] in
                self?.reportChromeHeight?(height)
            }
        }

        /// 内容视图铺满整窗时，`contentLayoutRect` 会排除工具栏占用的那条高度。
        private static func chromeHeight(of window: NSWindow) -> CGFloat {
            if let top = window.contentView?.safeAreaInsets.top, top > 0 {
                return top
            }
            guard let contentView = window.contentView else { return 0 }
            return max(0, contentView.bounds.height - window.contentLayoutRect.height)
        }
    }
}
