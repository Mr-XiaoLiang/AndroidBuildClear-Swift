import AppKit
import SwiftUI

/// 左右分栏布局，对应 Compose 版的 `ResizableSplitLayout`：
/// 左侧固定宽度、中间是 10pt 热区的可拖拽分隔条、右侧自动填满剩余空间。
struct ResizableSplitView<Left: View, Right: View>: View {

    @Binding var leftWidth: CGFloat

    var minLeftWidth: CGFloat = 200
    var maxLeftWidth: CGFloat = 620
    var defaultLeftWidth: CGFloat = 280

    /// 分隔条的命中热区宽度。视觉上只是一条细线，但热区要够大才好拖。
    var dividerHitWidth: CGFloat = 10

    @ViewBuilder var left: () -> Left
    @ViewBuilder var right: () -> Right

    @State private var widthAtDragStart: CGFloat?
    @State private var isDividerHovered = false

    var body: some View {
        GeometryReader { proxy in
            // 左侧再宽也要给右侧留下至少 minLeftWidth 的空间。
            let effectiveMax = max(minLeftWidth, min(maxLeftWidth, proxy.size.width - minLeftWidth))

            HStack(spacing: 0) {
                left()
                    .frame(width: min(max(leftWidth, minLeftWidth), effectiveMax))

                divider(effectiveMax: effectiveMax)

                right()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func divider(effectiveMax: CGFloat) -> some View {
        ZStack {
            Color.clear

            // 常驻的细分隔线：两栏现在都是平铺的，需要它来承担分区的视觉职责。
            // 悬停时只是换成强调色，不改变粗细，避免拖动过程中的视觉跳动。
            Rectangle()
                .fill(
                    isDividerHovered
                        ? AnyShapeStyle(Color.accentColor)
                        : AnyShapeStyle(Color(nsColor: .separatorColor))
                )
                .frame(width: 1)
        }
        .frame(width: dividerHitWidth)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        // 原生「左右拉伸」指针，等价于 Compose 版的 E_RESIZE_CURSOR
        .pointerStyle(.columnResize)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isDividerHovered = hovering
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let start = widthAtDragStart ?? leftWidth
                    if widthAtDragStart == nil { widthAtDragStart = start }
                    leftWidth = min(max(start + value.translation.width, minLeftWidth), effectiveMax)
                }
                .onEnded { _ in widthAtDragStart = nil }
        )
        .onTapGesture(count: 2) {
            withAnimation(.snappy) { leftWidth = defaultLeftWidth }
        }
    }
}
