import SwiftUI

// MARK: - 增强主题管理器
extension ThemeManager {
    
    // MARK: - 动态颜色
    var primaryTextColor: Color {
        isDarkMode ? .white : .black
    }
    
    var secondaryTextColor: Color {
        isDarkMode ? Color.white.opacity(0.7) : Color.black.opacity(0.6)
    }
    
    var backgroundPrimary: Color {
        isDarkMode ? Color(.systemBackground) : Color(.systemBackground)
    }
    
    var backgroundSecondary: Color {
        isDarkMode ? Color(.secondarySystemBackground) : Color(.secondarySystemBackground)
    }
    
    var cardBackground: Color {
        isDarkMode ? Color(.secondarySystemBackground) : Color(.systemBackground)
    }
    
    var borderColor: Color {
        isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.1)
    }
    
    var shadowColor: Color {
        isDarkMode ? Color.black.opacity(0.3) : Color.black.opacity(0.1)
    }
    
    // MARK: - 状态颜色
    var successColor: Color {
        Color.green
    }
    
    var warningColor: Color {
        Color.orange
    }
    
    var errorColor: Color {
        Color.red
    }
    
    var infoColor: Color {
        Color.blue
    }
    
    // MARK: - 渐变色
    var accentGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                accentColor,
                accentColor.opacity(0.8)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var backgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                backgroundPrimary,
                backgroundSecondary
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - 动态图标颜色
    func iconColor(for status: IconStatus) -> Color {
        switch status {
        case .active:
            return accentColor
        case .inactive:
            return secondaryTextColor
        case .success:
            return successColor
        case .warning:
            return warningColor
        case .error:
            return errorColor
        case .disabled:
            return Color.gray
        }
    }
    
    // MARK: - 自定义颜色调色板
    static let colorPalette: [String: Color] = [
        "blue": Color.blue,
        "purple": Color.purple,
        "pink": Color.pink,
        "red": Color.red,
        "orange": Color.orange,
        "yellow": Color.yellow,
        "green": Color.green,
        "mint": Color.mint,
        "teal": Color.teal,
        "cyan": Color.cyan,
        "indigo": Color.indigo
    ]
    
    func setCustomAccentColor(_ colorName: String) {
        if let color = Self.colorPalette[colorName] {
            let hexString = color.toHex()
            setAccentColor(hexString)
        }
    }
}

// MARK: - 图标状态枚举
enum IconStatus {
    case active
    case inactive
    case success
    case warning
    case error
    case disabled
}

// MARK: - 动态图标组件
struct DynamicIcon: View {
    let systemName: String
    let status: IconStatus
    let size: CGFloat
    let animated: Bool
    
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isAnimating = false
    
    init(
        systemName: String,
        status: IconStatus = .active,
        size: CGFloat = 20,
        animated: Bool = false
    ) {
        self.systemName = systemName
        self.status = status
        self.size = size
        self.animated = animated
    }
    
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .medium))
            .foregroundColor(themeManager.iconColor(for: status))
            .scaleEffect(isAnimating && animated ? 1.2 : 1.0)
            .rotationEffect(.degrees(isAnimating && animated ? 360 : 0))
            .animation(
                animated ? AnimationUtils.springBouncy.repeatForever(autoreverses: true) : .none,
                value: isAnimating
            )
            .onAppear {
                if animated {
                    isAnimating = true
                }
            }
    }
}

// MARK: - 主题化卡片组件
struct ThemedCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let padding: EdgeInsets
    
    @EnvironmentObject var themeManager: ThemeManager
    
    init(
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 4,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.padding = padding
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(themeManager.cardBackground)
                    .shadow(
                        color: themeManager.shadowColor,
                        radius: shadowRadius,
                        x: 0,
                        y: 2
                    )
            )
    }
}

// MARK: - 渐变按钮样式
struct GradientButtonStyle: ButtonStyle {
    let gradient: LinearGradient
    let cornerRadius: CGFloat
    
    @EnvironmentObject var themeManager: ThemeManager
    
    init(
        gradient: LinearGradient? = nil,
        cornerRadius: CGFloat = 12
    ) {
        self.gradient = gradient ?? LinearGradient(
            gradient: Gradient(colors: [Color.accentColor, Color.accentColor.opacity(0.8)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        self.cornerRadius = cornerRadius
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .fontWeight(.semibold)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(gradient)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(AnimationUtils.buttonPress, value: configuration.isPressed)
    }
}

// MARK: - 主题化分隔线
struct ThemedDivider: View {
    let thickness: CGFloat
    let opacity: Double
    
    @EnvironmentObject var themeManager: ThemeManager
    
    init(thickness: CGFloat = 1, opacity: Double = 0.2) {
        self.thickness = thickness
        self.opacity = opacity
    }
    
    var body: some View {
        Rectangle()
            .fill(themeManager.borderColor.opacity(opacity))
            .frame(height: thickness)
    }
}

// MARK: - 状态指示器
struct StatusIndicator: View {
    let status: IconStatus
    let text: String?
    let size: CGFloat
    
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isPulsing = false
    
    init(status: IconStatus, text: String? = nil, size: CGFloat = 8) {
        self.status = status
        self.text = text
        self.size = size
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(themeManager.iconColor(for: status))
                .frame(width: size, height: size)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .animation(AnimationUtils.loadingPulse, value: isPulsing)
                .onAppear {
                    if status == .active {
                        isPulsing = true
                    }
                }
            
            if let text = text {
                Text(text)
                    .font(.caption2)
                    .foregroundColor(themeManager.iconColor(for: status))
            }
        }
    }
}

// MARK: - 颜色选择器
struct ColorPicker: View {
    @Binding var selectedColor: String
    let columns = Array(repeating: GridItem(.adaptive(minimum: 44)), count: 6)
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Array(ThemeManager.colorPalette.keys.sorted()), id: \.self) { colorName in
                Button {
                    selectedColor = colorName
                    themeManager.setCustomAccentColor(colorName)
                } label: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(ThemeManager.colorPalette[colorName] ?? .gray)
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    selectedColor == colorName ? Color.white : Color.clear,
                                    lineWidth: 3
                                )
                        )
                        .shadow(radius: 2)
                }
                .scaleEffect(selectedColor == colorName ? 1.1 : 1.0)
                .animation(AnimationUtils.springBouncy, value: selectedColor)
            }
        }
    }
}

// MARK: - 颜色扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}

// MARK: - 视图扩展
extension View {
    func themedCard(
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 4,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    ) -> some View {
        ThemedCard(cornerRadius: cornerRadius, shadowRadius: shadowRadius, padding: padding) {
            self
        }
    }
    
    func gradientButton(
        gradient: LinearGradient? = nil,
        cornerRadius: CGFloat = 12
    ) -> some View {
        buttonStyle(GradientButtonStyle(gradient: gradient, cornerRadius: cornerRadius))
    }
}