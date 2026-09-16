import SwiftUI

/// 窗口底色：低饱和的彩色光晕，给液态玻璃提供「可折射的内容」。
///
/// 液态玻璃本质是折射 + 模糊它背后的东西，如果背后是纯色，效果几乎看不见。
struct AppBackdrop: View {

    @Environment(\.colorScheme) private var colorScheme

    /// 深色模式下光晕需要更强的亮度才看得出来。
    private var intensity: Double { colorScheme == .dark ? 0.42 : 0.30 }

    var body: some View {
        ZStack {
            // 窗口自身的原生底色（保留 macOS 的窗体材质）
            Rectangle().fill(.background)

            RadialGradient(
                colors: [.accentColor.opacity(intensity), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 560
            )
            RadialGradient(
                colors: [Color.purple.opacity(intensity * 0.85), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 620
            )
            RadialGradient(
                colors: [Color.teal.opacity(intensity * 0.6), .clear],
                center: UnitPoint(x: 0.9, y: 0.08),
                startRadius: 0,
                endRadius: 460
            )
        }
        .ignoresSafeArea()
    }
}
