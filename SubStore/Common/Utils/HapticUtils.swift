import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import AudioToolbox

// MARK: - 触觉反馈管理器
class HapticManager: ObservableObject {
    static let shared = HapticManager()
    
    @Published var isEnabled: Bool = true
    
    private init() {
        // 从设置中读取触觉反馈启用状态
        loadSettings()
    }
    
    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "HapticFeedbackEnabled")
    }
    
    func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: "HapticFeedbackEnabled")
    }
    
    // MARK: - 触觉反馈类型
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if canImport(UIKit)
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        #if canImport(UIKit)
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
        #endif
    }
    
    func selection() {
        #if canImport(UIKit)
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
        #endif
    }
    
    // MARK: - 预定义触觉反馈
    func lightTap() {
        impact(.light)
    }
    
    func mediumTap() {
        impact(.medium)
    }
    
    func heavyTap() {
        impact(.heavy)
    }
    
    func success() {
        notification(.success)
    }
    
    func warning() {
        notification(.warning)
    }
    
    func error() {
        notification(.error)
    }
    
    func buttonPress() {
        impact(.light)
    }
    
    func buttonRelease() {
        impact(.rigid)
    }
    
    func cardTap() {
        impact(.light)
    }
    
    func switchToggle() {
        impact(.medium)
    }
    
    func listItemSelect() {
        selection()
    }
    
    func longPressStart() {
        impact(.medium)
    }
    
    func longPressActivate() {
        impact(.heavy)
    }
    
    func dragStart() {
        impact(.light)
    }
    
    func dragEnd() {
        impact(.medium)
    }
    
    func pullRefreshStart() {
        impact(.light)
    }
    
    func pullRefreshActivate() {
        impact(.medium)
    }
    
    func tabSwitch() {
        selection()
    }
    
    func pageTransition() {
        impact(.light)
    }
    
    func modalPresent() {
        impact(.medium)
    }
    
    func modalDismiss() {
        impact(.light)
    }
    
    func deleteAction() {
        impact(.heavy)
    }
    
    func editAction() {
        impact(.light)
    }
    
    func copyAction() {
        impact(.light)
    }
    
    func shareAction() {
        impact(.medium)
    }
    
    func networkConnected() {
        notification(.success)
    }
    
    func networkDisconnected() {
        notification(.warning)
    }
    
    func operationComplete() {
        notification(.success)
    }
    
    func operationFailed() {
        notification(.error)
    }
}

// MARK: - 触觉反馈修饰器
struct HapticFeedbackModifier: ViewModifier {
    let hapticType: HapticType
    let trigger: Bool
    
    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    performHaptic()
                }
            }
    }
    
    private func performHaptic() {
        let hapticManager = HapticManager.shared
        
        switch hapticType {
        #if canImport(UIKit)
        case .impact(let style):
            hapticManager.impact(style)
        case .notification(let type):
            hapticManager.notification(type)
        #endif
        case .selection:
            hapticManager.selection()
        case .custom(let action):
            action()
        }
    }
}

// MARK: - 触觉反馈类型
enum HapticType {
    #if canImport(UIKit)
    case impact(UIImpactFeedbackGenerator.FeedbackStyle)
    case notification(UINotificationFeedbackGenerator.FeedbackType)
    #endif
    case selection
    case custom(() -> Void)
}

// MARK: - 增强按钮样式（带触觉反馈）
struct HapticButtonStyle: ButtonStyle {
    let hapticType: HapticType
    let scaleEffect: CGFloat
    let animation: Animation
    
    init(
        hapticType: HapticType = .impact(.light),
        scaleEffect: CGFloat = 0.95,
        animation: Animation = AnimationUtils.buttonPress
    ) {
        self.hapticType = hapticType
        self.scaleEffect = scaleEffect
        self.animation = animation
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleEffect : 1.0)
            .animation(animation, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    performHaptic()
                }
            }
    }
    
    private func performHaptic() {
        let hapticManager = HapticManager.shared
        
        switch hapticType {
        #if canImport(UIKit)
        case .impact(let style):
            hapticManager.impact(style)
        case .notification(let type):
            hapticManager.notification(type)
        #endif
        case .selection:
            hapticManager.selection()
        case .custom(let action):
            action()
        }
    }
}

// MARK: - 开关控件（带触觉反馈）
struct HapticToggle: View {
    @Binding var isOn: Bool
    let title: String
    let hapticType: HapticType
    
    init(
        _ title: String,
        isOn: Binding<Bool>,
        hapticType: HapticType = .impact(.medium)
    ) {
        self.title = title
        self._isOn = isOn
        self.hapticType = hapticType
    }
    
    var body: some View {
        Toggle(title, isOn: $isOn)
            .onChange(of: isOn) { _, _ in
                performHaptic()
            }
    }
    
    private func performHaptic() {
        let hapticManager = HapticManager.shared
        
        switch hapticType {
        #if canImport(UIKit)
        case .impact(let style):
            hapticManager.impact(style)
        case .notification(let type):
            hapticManager.notification(type)
        #endif
        case .selection:
            hapticManager.selection()
        case .custom(let action):
            action()
        }
    }
}

// MARK: - 滑块控件（带触觉反馈）
struct HapticSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let title: String
    
    @State private var lastHapticValue: Double = 0
    
    init(
        _ title: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double = 1.0
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self._lastHapticValue = State(initialValue: value.wrappedValue)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Slider(value: $value, in: range, step: step)
                .onChange(of: value) { oldValue, newValue in
                    let stepDifference = abs(newValue - lastHapticValue)
                    if stepDifference >= step {
                        HapticManager.shared.selection()
                        lastHapticValue = newValue
                    }
                }
        }
    }
}

// MARK: - 音效管理器
class SoundManager: ObservableObject {
    static let shared = SoundManager()
    
    @Published var isEnabled: Bool = false
    
    private init() {
        loadSettings()
    }
    
    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "SoundEffectsEnabled")
    }
    
    func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: "SoundEffectsEnabled")
    }
    
    // MARK: - 系统音效
    func playSystemSound(_ soundID: SystemSoundID) {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(soundID)
    }
    
    // MARK: - 预定义音效
    func buttonClick() {
        playSystemSound(1104) // 键盘点击音
    }
    
    func switchToggle() {
        playSystemSound(1306) // 开关切换音
    }
    
    func notification() {
        playSystemSound(1315) // 通知音
    }
    
    func cameraShutter() {
        playSystemSound(1108) // 相机快门音
    }
    
    func lockSound() {
        playSystemSound(1100) // 锁定音
    }
    
    func unlockSound() {
        playSystemSound(1101) // 解锁音
    }
}

// MARK: - 视图扩展
extension View {
    func hapticFeedback(_ type: HapticType, trigger: Bool) -> some View {
        modifier(HapticFeedbackModifier(hapticType: type, trigger: trigger))
    }
    
    func hapticButton(
        _ type: HapticType = .impact(.light),
        scaleEffect: CGFloat = 0.95,
        animation: Animation = AnimationUtils.buttonPress
    ) -> some View {
        buttonStyle(HapticButtonStyle(hapticType: type, scaleEffect: scaleEffect, animation: animation))
    }
    
    func onTapGestureWithHaptic(
        _ hapticType: HapticType = .impact(.light),
        perform action: @escaping () -> Void
    ) -> some View {
        onTapGesture {
            let hapticManager = HapticManager.shared
            
            switch hapticType {
            case .impact(let style):
                hapticManager.impact(style)
            case .notification(let type):
                hapticManager.notification(type)
            case .selection:
                hapticManager.selection()
            case .custom(let hapticAction):
                hapticAction()
            }
            
            action()
        }
    }
}

// MARK: - 触觉反馈常量
extension HapticType {
    #if canImport(UIKit)
    static let lightTap = HapticType.impact(.light)
    static let mediumTap = HapticType.impact(.medium)
    static let heavyTap = HapticType.impact(.heavy)
    static let success = HapticType.notification(.success)
    static let warning = HapticType.notification(.warning)
    static let error = HapticType.notification(.error)
    static let buttonPress = HapticType.impact(.light)
    static let cardTap = HapticType.impact(.light)
    static let switchToggle = HapticType.impact(.medium)
    static let longPress = HapticType.impact(.heavy)
    static let delete = HapticType.impact(.heavy)
    #endif
    static let selection = HapticType.selection
}