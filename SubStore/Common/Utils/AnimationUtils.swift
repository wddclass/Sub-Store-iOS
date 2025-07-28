import SwiftUI

// MARK: - 动画工具类
struct AnimationUtils {
    
    // MARK: - 预定义动画
    static let springDefault = Animation.spring(
        response: 0.6,
        dampingFraction: 0.8,
        blendDuration: 0
    )
    
    static let springBouncy = Animation.spring(
        response: 0.8,
        dampingFraction: 0.6,
        blendDuration: 0
    )
    
    static let easeInOut = Animation.easeInOut(duration: 0.3)
    static let easeIn = Animation.easeIn(duration: 0.2)
    static let easeOut = Animation.easeOut(duration: 0.2)
    
    static let smooth = Animation.interpolatingSpring(
        mass: 1,
        stiffness: 100,
        damping: 10,
        initialVelocity: 0
    )
    
    // MARK: - 页面转场动画
    static let pageTransition = Animation.easeInOut(duration: 0.35)
    static let modalPresentation = Animation.spring(
        response: 0.5,
        dampingFraction: 0.9,
        blendDuration: 0
    )
    
    // MARK: - 列表动画
    static let listItemAppear = Animation.easeOut(duration: 0.4)
    static let listItemDisappear = Animation.easeIn(duration: 0.2)
    
    // MARK: - 按钮动画
    static let buttonPress = Animation.easeInOut(duration: 0.1)
    static let buttonRelease = Animation.easeOut(duration: 0.15)
    
    // MARK: - 加载动画
    static let loadingRotation = Animation.linear(duration: 1.0).repeatForever(autoreverses: false)
    static let loadingPulse = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)
    
    // MARK: - 错误/成功状态动画
    static let errorShake = Animation.spring(
        response: 0.2,
        dampingFraction: 0.3,
        blendDuration: 0
    )
    
    static let successBounce = Animation.spring(
        response: 0.4,
        dampingFraction: 0.7,
        blendDuration: 0
    )
}

// MARK: - 转场效果
struct SlideTransition {
    let edge: Edge
    
    var transition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: edge).combined(with: .opacity),
            removal: .move(edge: edge.opposite).combined(with: .opacity)
        )
    }
}

extension Edge {
    var opposite: Edge {
        switch self {
        case .top: return .bottom
        case .bottom: return .top
        case .leading: return .trailing
        case .trailing: return .leading
        }
    }
}

// MARK: - 弹性按钮样式
struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(AnimationUtils.buttonPress, value: configuration.isPressed)
    }
}

// MARK: - 卡片悬停效果
struct CardHoverStyle: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(radius: isHovered ? 8 : 4)
            .animation(AnimationUtils.smooth, value: isHovered)
            .onTapGesture {
                withAnimation(AnimationUtils.buttonPress) {
                    isHovered.toggle()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(AnimationUtils.buttonRelease) {
                        isHovered = false
                    }
                }
            }
    }
}

// MARK: - 加载状态视图
struct LoadingAnimationView: View {
    @State private var isAnimating = false
    let color: Color
    let size: CGFloat
    
    init(color: Color = .accentColor, size: CGFloat = 20) {
        self.color = color
        self.size = size
    }
    
    var body: some View {
        Circle()
            .stroke(lineWidth: 2)
            .frame(width: size, height: size)
            .foregroundColor(color.opacity(0.3))
            .overlay(
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [color.opacity(0), color]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
            )
            .onAppear {
                withAnimation(AnimationUtils.loadingRotation) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - 脉冲动画视图
struct PulseAnimationView: View {
    @State private var isPulsing = false
    let color: Color
    let size: CGFloat
    
    init(color: Color = .accentColor, size: CGFloat = 8) {
        self.color = color
        self.size = size
    }
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .onAppear {
                withAnimation(AnimationUtils.loadingPulse) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - 弹跳数字视图
struct BouncyNumberView: View {
    let number: Int
    @State private var displayedNumber: Int
    
    init(number: Int) {
        self.number = number
        self._displayedNumber = State(initialValue: number)
    }
    
    var body: some View {
        Text("\(displayedNumber)")
            .onChange(of: number) { newValue in
                withAnimation(AnimationUtils.springBouncy) {
                    displayedNumber = newValue
                }
            }
    }
}

// MARK: - 震动效果修饰器
struct ShakeEffect: ViewModifier {
    @State private var shakeOffset: CGFloat = 0
    let trigger: Bool
    
    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onChange(of: trigger) { _ in
                withAnimation(AnimationUtils.errorShake) {
                    shakeOffset = 10
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(AnimationUtils.errorShake) {
                        shakeOffset = -10
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(AnimationUtils.errorShake) {
                        shakeOffset = 0
                    }
                }
            }
    }
}

// MARK: - 成功状态修饰器
struct SuccessEffect: ViewModifier {
    @State private var scale: CGFloat = 1.0
    let trigger: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onChange(of: trigger) { _ in
                withAnimation(AnimationUtils.successBounce) {
                    scale = 1.2
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(AnimationUtils.smooth) {
                        scale = 1.0
                    }
                }
            }
    }
}

// MARK: - 视图扩展
extension View {
    func cardHover() -> some View {
        modifier(CardHoverStyle())
    }
    
    func shake(trigger: Bool) -> some View {
        modifier(ShakeEffect(trigger: trigger))
    }
    
    func successBounce(trigger: Bool) -> some View {
        modifier(SuccessEffect(trigger: trigger))
    }
    
    func slideTransition(from edge: Edge) -> some View {
        transition(SlideTransition(edge: edge).transition)
    }
}

// MARK: - 常用动画组合
extension Animation {
    static var listItem: Animation {
        AnimationUtils.listItemAppear
    }
    
    static var modal: Animation {
        AnimationUtils.modalPresentation
    }
    
    static var smooth: Animation {
        AnimationUtils.smooth
    }
}