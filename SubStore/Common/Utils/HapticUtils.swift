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
    
    #if canImport(UIKit)
    // MARK: - 触觉反馈类型
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    #endif
    
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
        #if canImport(UIKit)
        impact(.light)
        #else
        selection()
        #endif
    }
    
    func mediumTap() {
        #if canImport(UIKit)
        impact(.medium)
        #else
        selection()
        #endif
    }
    
    func heavyTap() {
        #if canImport(UIKit)
        impact(.heavy)
        #else
        selection()
        #endif
    }
    
    func success() {
        #if canImport(UIKit)
        notification(.success)
        #else
        selection()
        #endif
    }
    
    func warning() {
        #if canImport(UIKit)
        notification(.warning)
        #else
        selection()
        #endif
    }
    
    func error() {
        #if canImport(UIKit)
        notification(.error)
        #else
        selection()
        #endif
    }
    
    func buttonPress() {
        #if canImport(UIKit)
        impact(.light)
        #else
        selection()
        #endif
    }
    
    func buttonRelease() {
        #if canImport(UIKit)
        impact(.rigid)
        #else
        selection()
        #endif
    }
    
    func cardTap() {
        #if canImport(UIKit)
        impact(.light)
        #else
        selection()
        #endif
    }
    
    func switchToggle() {
        #if canImport(UIKit)
        impact(.medium)
        #else
        selection()
        #endif
    }
    
    func listItemSelect() {
        selection()
    }
    
    func longPressStart() {
        #if canImport(UIKit)
        impact(.medium)
        #else
        selection()
        #endif
    }
    
    func longPressActivate() {
        #if canImport(UIKit)
        impact(.heavy)
        #else
        selection()
        #endif
    }
    
    func dragStart() {
        #if canImport(UIKit)
        impact(.light)
        #else
        selection()
        #endif
    }
    
    func dragEnd() {
        #if canImport(UIKit)
        impact(.medium)
        #else
        selection()
        #endif
    }
    
    func pullRefreshStart() {
        #if canImport(UIKit)
        impact(.light)
        #else
        selection()
        #endif
    }
    
    func pullRefreshActivate() {
        #if canImport(UIKit)
        impact(.medium)
        #else
        selection()
        #endif
    }
    
    func tabSwitch() {
        selection()
    }
    
    func pageTransition() {
        #if canImport(UIKit)
        impact(.light)
        #else
        selection()
        #endif
    }
    
    func modalPresent() {
        #if canImport(UIKit)
        impact(.medium)
        #else
        selection()
        #endif
    }
    
    func modalDismiss() {
        #if canImport(UIKit)
        impact(.light)
        #else
        selection()
        #endif
    }
    
    func deleteAction() {
        #if canImport(UIKit)
        impact(.heavy)
        #else
        selection()
        #endif
    }
    
    func editAction() {
        #if canImport(UIKit)
        impact(.light)
        #else
        selection()
        #endif
    }
    
    func copyAction() {
        #if canImport(UIKit)
        impact(.light)
        #else
        selection()
        #endif
    }
    
    func shareAction() {
        #if canImport(UIKit)
        impact(.medium)
        #else
        selection()
        #endif
    }
    
    func networkConnected() {
        #if canImport(UIKit)
        notification(.success)
        #else
        selection()
        #endif
    }
    
    func networkDisconnected() {
        #if canImport(UIKit)
        notification(.warning)
        #else
        selection()
        #endif
    }
    
    func operationComplete() {
        #if canImport(UIKit)
        notification(.success)
        #else
        selection()
        #endif
    }
    
    func operationFailed() {
        #if canImport(UIKit)
        notification(.error)
        #else
        selection()
        #endif
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
        hapticType: HapticType,
        scaleEffect: CGFloat = 0.95,
        animation: Animation = AnimationUtils.buttonPress
    ) {
        self.hapticType = hapticType
        self.scaleEffect = scaleEffect
        self.animation = animation
    }
    
    init(
        scaleEffect: CGFloat = 0.95,
        animation: Animation = AnimationUtils.buttonPress
    ) {
        #if canImport(UIKit)
        self.hapticType = .impact(.light)
        #else
        self.hapticType = .selection
        #endif
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
        hapticType: HapticType
    ) {
        self.title = title
        self._isOn = isOn
        self.hapticType = hapticType
    }
    
    init(
        _ title: String,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self._isOn = isOn
        #if canImport(UIKit)
        self.hapticType = .impact(.medium)
        #else
        self.hapticType = .selection
        #endif
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
                .onChange(of: value) { _, newValue in
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
        _ type: HapticType,
        scaleEffect: CGFloat = 0.95,
        animation: Animation = AnimationUtils.buttonPress
    ) -> some View {
        buttonStyle(HapticButtonStyle(hapticType: type, scaleEffect: scaleEffect, animation: animation))
    }
    
    func hapticButton(
        scaleEffect: CGFloat = 0.95,
        animation: Animation = AnimationUtils.buttonPress
    ) -> some View {
        #if canImport(UIKit)
        buttonStyle(HapticButtonStyle(hapticType: .impact(.light), scaleEffect: scaleEffect, animation: animation))
        #else
        buttonStyle(HapticButtonStyle(hapticType: .selection, scaleEffect: scaleEffect, animation: animation))
        #endif
    }
    
    func onTapGestureWithHaptic(
        _ hapticType: HapticType,
        perform action: @escaping () -> Void
    ) -> some View {
        onTapGesture {
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
            case .custom(let hapticAction):
                hapticAction()
            }
            
            action()
        }
    }
    
    func onTapGestureWithHaptic(
        perform action: @escaping () -> Void
    ) -> some View {
        #if canImport(UIKit)
        onTapGestureWithHaptic(.impact(.light), perform: action)
        #else
        onTapGestureWithHaptic(.selection, perform: action)
        #endif
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
}