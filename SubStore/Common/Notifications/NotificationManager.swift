import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 通知类型
enum NotificationType {
    case primary
    case success
    case danger
    case warning
    case info
    
    var color: Color {
        switch self {
        case .primary:
            return .accentColor
        case .success:
            return .green
        case .danger:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .primary:
            return "info.circle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .danger:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
}

// MARK: - 通知模型
struct AppNotification: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let content: String?
    let type: NotificationType
    let duration: TimeInterval
    let createdAt: Date
    
    init(title: String, content: String? = nil, type: NotificationType = .primary, duration: TimeInterval = 2.5) {
        self.title = title
        self.content = content
        self.type = type
        self.duration = duration
        self.createdAt = Date()
    }
}

// MARK: - 通知设置
struct NotifySettings {
    let title: String
    let content: String?
    let type: NotificationType
    let duration: TimeInterval?
    
    init(title: String, content: String? = nil, type: NotificationType = .primary, duration: TimeInterval? = nil) {
        self.title = title
        self.content = content
        self.type = type
        self.duration = duration
    }
}

// MARK: - 全局通知管理器
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var notifications: [AppNotification] = []
    @Published var isVisible = false
    
    private var cancellables = Set<AnyCancellable>()
    private let maxNotifications = 5
    
    private init() {
        // 监听通知数组变化，自动显示/隐藏
        $notifications
            .map { !$0.isEmpty }
            .removeDuplicates()
            .assign(to: \.isVisible, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - 公共方法
    func showNotify(_ settings: NotifySettings) {
        let notification = AppNotification(
            title: settings.title,
            content: settings.content,
            type: settings.type,
            duration: settings.duration ?? 2.5
        )
        
        showNotification(notification)
    }
    
    func showSuccess(_ title: String, content: String? = nil) {
        showNotify(NotifySettings(title: title, content: content, type: .success))
    }
    
    func showError(_ title: String, content: String? = nil) {
        showNotify(NotifySettings(title: title, content: content, type: .danger))
    }
    
    func showWarning(_ title: String, content: String? = nil) {
        showNotify(NotifySettings(title: title, content: content, type: .warning))
    }
    
    func showInfo(_ title: String, content: String? = nil) {
        showNotify(NotifySettings(title: title, content: content, type: .info))
    }
    
    func showPrimary(_ title: String, content: String? = nil) {
        showNotify(NotifySettings(title: title, content: content, type: .primary))
    }
    
    // MARK: - 私有方法
    private func showNotification(_ notification: AppNotification) {
        DispatchQueue.main.async {
            // 限制通知数量
            if self.notifications.count >= self.maxNotifications {
                self.notifications.removeFirst()
            }
            
            self.notifications.append(notification)
            
            // 自动移除通知
            DispatchQueue.main.asyncAfter(deadline: .now() + notification.duration) {
                self.removeNotification(notification)
            }
            
            // 添加震动反馈
            self.addHapticFeedback(for: notification.type)
        }
    }
    
    func removeNotification(_ notification: AppNotification) {
        withAnimation(.easeOut(duration: 0.3)) {
            notifications.removeAll { $0.id == notification.id }
        }
    }
    
    private func addHapticFeedback(for type: NotificationType) {
        #if canImport(UIKit)
        switch type {
        case .success:
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
        case .danger:
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.error)
        case .warning:
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.warning)
        default:
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
        #endif
    }
    
    func clearAll() {
        withAnimation(.easeOut(duration: 0.3)) {
            notifications.removeAll()
        }
    }
}

// MARK: - 通知容器视图
struct NotificationContainerView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(notificationManager.notifications) { notification in
                NotificationItemView(notification: notification) {
                    notificationManager.removeNotification(notification)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .padding(.horizontal)
        #if canImport(UIKit)
        .padding(.top, getSafeAreaInsets().top + 8)
        #else
        .padding(.top, getSafeAreaInsets() + 8)
        #endif
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: notificationManager.notifications)
    }
    
    #if canImport(UIKit)
    private func getSafeAreaInsets() -> UIEdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIEdgeInsets()
        }
        return window.safeAreaInsets
    }
    #else
    private func getSafeAreaInsets() -> CGFloat {
        return 0
    }
    #endif
}

// MARK: - 单个通知视图
struct NotificationItemView: View {
    let notification: AppNotification
    let onDismiss: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(systemName: notification.type.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(notification.type.color)
                .frame(width: 20)
            
            // 内容
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                if let content = notification.content {
                    Text(content)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
            
            Spacer()
            
            // 关闭按钮
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(notification.type.color.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(x: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width > 0 {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.width > 100 {
                        withAnimation(.easeOut(duration: 0.3)) {
                            #if canImport(UIKit)
                            dragOffset = UIScreen.main.bounds.width
                            #else
                            dragOffset = 400  // Default width for macOS
                            #endif
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss()
                        }
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }
}

// MARK: - 通知工具类
class NotificationHelper {
    static func showSuccess(_ title: String, content: String? = nil) {
        NotificationManager.shared.showSuccess(title, content: content)
    }
    
    static func showError(_ title: String, content: String? = nil) {
        NotificationManager.shared.showError(title, content: content)
    }
    
    static func showWarning(_ title: String, content: String? = nil) {
        NotificationManager.shared.showWarning(title, content: content)
    }
    
    static func showInfo(_ title: String, content: String? = nil) {
        NotificationManager.shared.showInfo(title, content: content)
    }
    
    static func showPrimary(_ title: String, content: String? = nil) {
        NotificationManager.shared.showPrimary(title, content: content)
    }
}

// MARK: - View 扩展，用于显示通知
extension View {
    func withNotifications() -> some View {
        ZStack {
            self
            
            VStack {
                NotificationContainerView()
                Spacer()
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - 加载中通知管理器
class LoadingNotificationManager: ObservableObject {
    static let shared = LoadingNotificationManager()
    
    @Published var isLoading = false
    @Published var loadingTitle = ""
    @Published var loadingContent: String?
    
    private var loadingTasks: Set<String> = []
    
    private init() {}
    
    func showLoading(_ title: String, content: String? = nil, id: String = "default") {
        DispatchQueue.main.async {
            self.loadingTasks.insert(id)
            self.loadingTitle = title
            self.loadingContent = content
            self.isLoading = true
        }
    }
    
    func hideLoading(id: String = "default") {
        DispatchQueue.main.async {
            self.loadingTasks.remove(id)
            if self.loadingTasks.isEmpty {
                self.isLoading = false
            }
        }
    }
    
    func hideAllLoading() {
        DispatchQueue.main.async {
            self.loadingTasks.removeAll()
            self.isLoading = false
        }
    }
}

// MARK: - 加载中视图
struct LoadingOverlayView: View {
    @StateObject private var loadingManager = LoadingNotificationManager.shared
    
    var body: some View {
        if loadingManager.isLoading {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    
                    Text(loadingManager.loadingTitle)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    if let content = loadingManager.loadingContent {
                        Text(content)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                        .shadow(radius: 20)
                )
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: loadingManager.isLoading)
        }
    }
}

// MARK: - View 扩展，用于显示加载中
extension View {
    func withLoadingOverlay() -> some View {
        ZStack {
            self
            LoadingOverlayView()
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        Button("成功通知") {
            NotificationHelper.showSuccess("操作成功", content: "订阅已成功添加到列表中")
        }
        
        Button("错误通知") {
            NotificationHelper.showError("操作失败", content: "网络连接超时，请检查网络设置后重试")
        }
        
        Button("警告通知") {
            NotificationHelper.showWarning("注意事项", content: "当前操作可能会影响现有配置")
        }
        
        Button("信息通知") {
            NotificationHelper.showInfo("提示信息", content: "发现新版本可用，建议及时更新")
        }
        
        Button("显示加载") {
            LoadingNotificationManager.shared.showLoading("正在同步", content: "正在从云端下载配置...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                LoadingNotificationManager.shared.hideLoading()
                NotificationHelper.showSuccess("同步完成")
            }
        }
    }
    .padding()
    .withNotifications()
    .withLoadingOverlay()
}