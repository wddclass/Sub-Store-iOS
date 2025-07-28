import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 加载指示器
struct LoadingView: View {
    let message: String?
    
    init(message: String? = nil) {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: AppConstants.UI.Spacing.medium) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle())
            
            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if canImport(UIKit)
        .background(Color(UIColor.systemBackground))
        #else
        .background(Color(.white))
        #endif
    }
}

// MARK: - 错误视图
struct ErrorView: View {
    let error: String
    let onRetry: (() -> Void)?
    
    init(error: String, onRetry: (() -> Void)? = nil) {
        self.error = error
        self.onRetry = onRetry
    }
    
    var body: some View {
        VStack(spacing: AppConstants.UI.Spacing.large) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: AppConstants.UI.Icon.extraLarge))
                .foregroundColor(.orange)
            
            Text("出现错误")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let onRetry = onRetry {
                Button("重试") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if canImport(UIKit)
        .background(Color(UIColor.systemBackground))
        #else
        .background(Color(.white))
        #endif
    }
}

// MARK: - 空状态视图
struct EmptyStateView: View {
    let title: String
    let description: String
    let systemImage: String
    let action: (() -> Void)?
    let actionTitle: String?
    
    init(
        title: String,
        description: String,
        systemImage: String = "tray",
        action: (() -> Void)? = nil,
        actionTitle: String? = nil
    ) {
        self.title = title
        self.description = description
        self.systemImage = systemImage
        self.action = action
        self.actionTitle = actionTitle
    }
    
    var body: some View {
        VStack(spacing: AppConstants.UI.Spacing.large) {
            Image(systemName: systemImage)
                .font(.system(size: AppConstants.UI.Icon.extraLarge))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if let action = action, let actionTitle = actionTitle {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if canImport(UIKit)
        .background(Color(UIColor.systemBackground))
        #else
        .background(Color(.white))
        #endif
    }
}

// MARK: - 卡片视图
struct CardView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            #if canImport(UIKit)
            .background(Color(UIColor.systemBackground))
            #else
            .background(Color(.white))
            #endif
            .cornerRadius(AppConstants.UI.cornerRadius)
            .shadow(radius: AppConstants.UI.shadowRadius)
    }
}

// MARK: - 设置行视图
struct SettingsRowView<Destination: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let value: String?
    let destination: Destination?
    let action: (() -> Void)?
    
    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        value: String? = nil,
        destination: Destination? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.value = value
        self.destination = destination
        self.action = action
    }
    
    var body: some View {
        if let destination = destination {
            NavigationLink(destination: destination) {
                rowContent
            }
        } else {
            Button(action: action ?? {}) {
                rowContent
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var rowContent: some View {
        HStack(spacing: AppConstants.UI.Spacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: AppConstants.UI.Icon.medium))
                .foregroundColor(.accentColor)
                .frame(width: AppConstants.UI.Icon.large)
            
            VStack(alignment: .leading, spacing: AppConstants.UI.Spacing.tiny) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let value = value {
                Text(value)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            if destination != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: AppConstants.UI.Icon.small))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, AppConstants.UI.Spacing.small)
    }
}

// MARK: - 流量信息视图
struct FlowInfoView: View {
    let flowInfo: FlowInfo
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        if settingsManager.settings.appearance.showFlowInfo {
            VStack(alignment: .trailing, spacing: AppConstants.UI.Spacing.tiny) {
                if !flowInfo.isUnlimited {
                    // 进度条
                    if let percentage = flowInfo.percentage {
                        HStack(spacing: AppConstants.UI.Spacing.tiny) {
                            ProgressView(value: percentage / 100.0)
                                .progressViewStyle(LinearProgressViewStyle(tint: flowInfo.status.color))
                                .frame(width: 80, height: 4)
                            
                            // 状态指示器
                            Circle()
                                .fill(flowInfo.status.color)
                                .frame(width: 6, height: 6)
                        }
                    }
                    
                    // 流量文本
                    HStack(spacing: AppConstants.UI.Spacing.tiny) {
                        Text(flowInfo.usedFormatted)
                            .font(.caption2)
                            .foregroundColor(.primary)
                        
                        Text("/")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(flowInfo.totalFormatted)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // 百分比
                    if let percentage = flowInfo.percentage {
                        Text("\(Int(percentage))%")
                            .font(.caption2)
                            .foregroundColor(flowInfo.status.color)
                            .fontWeight(.medium)
                    }
                } else {
                    HStack(spacing: AppConstants.UI.Spacing.tiny) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                        
                        Text("无限制")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                }
            }
        }
    }
}

// MARK: - 订阅图标视图
struct SubscriptionIconView: View {
    let subscription: Subscription
    let size: CGFloat
    @EnvironmentObject var settingsManager: SettingsManager
    
    init(subscription: Subscription, size: CGFloat = AppConstants.UI.Icon.medium) {
        self.subscription = subscription
        self.size = size
    }
    
    var body: some View {
        if settingsManager.settings.appearance.showSubscriptionIcons {
            Group {
                if let icon = subscription.icon, let url = URL(string: icon) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        defaultIcon
                    }
                } else {
                    defaultIcon
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
        } else {
            defaultIcon
                .frame(width: size, height: size)
        }
    }
    
    private var defaultIcon: some View {
        Image(systemName: subscription.source == .remote ? "link" : "link.badge.plus")
            .font(.system(size: size * 0.6))
            .foregroundColor(.accentColor)
            .frame(width: size, height: size)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
    }
}

// MARK: - 标签视图
struct TagView: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.caption)
                .padding(.horizontal, AppConstants.UI.Spacing.small)
                .padding(.vertical, AppConstants.UI.Spacing.tiny)
                .background({
                    #if canImport(UIKit)
                    return isSelected ? Color.accentColor : Color(UIColor.systemGray5)
                    #else
                    return isSelected ? Color.accentColor : Color.gray.opacity(0.3)
                    #endif
                }())
                .foregroundColor(
                    isSelected ? .white : .primary
                )
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 搜索栏视图
struct SearchBarView: View {
    @Binding var searchText: String
    let placeholder: String
    
    init(searchText: Binding<String>, placeholder: String = "搜索") {
        self._searchText = searchText
        self.placeholder = placeholder
    }
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button("清除") {
                    searchText = ""
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, AppConstants.UI.Spacing.small)
        #if canImport(UIKit)
        .background(Color(UIColor.systemGray6))
        #else
        .background(Color.gray.opacity(0.2))
        #endif
        .cornerRadius(AppConstants.UI.cornerRadius)
    }
}

// MARK: - 浮动操作按钮
struct FloatingActionButton: View {
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: AppConstants.UI.Icon.medium, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(radius: AppConstants.UI.shadowRadius)
        }
        .scaleEffect(1.0)
        .animation(.easeInOut(duration: AppConstants.UI.animationDuration), value: true)
    }
}