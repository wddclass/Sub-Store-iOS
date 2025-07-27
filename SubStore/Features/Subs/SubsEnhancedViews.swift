import SwiftUI
import Combine

// MARK: - 批量操作视图
struct BatchOperationView: View {
    @Binding var selectedSubscriptions: Set<String>
    let allSubscriptions: [Subscription]
    let onBatchOperation: (BatchOperation, Set<String>) -> Void
    
    enum BatchOperation {
        case enable
        case disable
        case delete
        case updateFlow
        case export
        case addTag(String)
        case removeTag(String)
    }
    
    var body: some View {
        VStack(spacing: AppConstants.UI.Spacing.medium) {
            // 选择统计
            HStack {
                Text("已选择 \(selectedSubscriptions.count) 项")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("全选") {
                    if selectedSubscriptions.count == allSubscriptions.count {
                        selectedSubscriptions.removeAll()
                    } else {
                        selectedSubscriptions = Set(allSubscriptions.map { $0.id })
                    }
                }
                .foregroundColor(.accentColor)
            }
            
            // 操作按钮
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: AppConstants.UI.Spacing.medium) {
                BatchOperationButton(
                    title: "启用",
                    systemImage: "checkmark.circle",
                    color: .green
                ) {
                    onBatchOperation(.enable, selectedSubscriptions)
                }
                
                BatchOperationButton(
                    title: "禁用",
                    systemImage: "pause.circle",
                    color: .orange
                ) {
                    onBatchOperation(.disable, selectedSubscriptions)
                }
                
                BatchOperationButton(
                    title: "删除",
                    systemImage: "trash",
                    color: .red
                ) {
                    onBatchOperation(.delete, selectedSubscriptions)
                }
                
                BatchOperationButton(
                    title: "更新流量",
                    systemImage: "arrow.clockwise",
                    color: .blue
                ) {
                    onBatchOperation(.updateFlow, selectedSubscriptions)
                }
                
                BatchOperationButton(
                    title: "导出",
                    systemImage: "square.and.arrow.up",
                    color: .purple
                ) {
                    onBatchOperation(.export, selectedSubscriptions)
                }
                
                BatchOperationButton(
                    title: "添加标签",
                    systemImage: "tag.fill",
                    color: .cyan
                ) {
                    // 这里可以显示标签选择器
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .disabled(selectedSubscriptions.isEmpty)
    }
}

// MARK: - 批量操作按钮
struct BatchOperationButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AppConstants.UI.Spacing.small) {
                Image(systemName: systemImage)
                    .font(.system(size: AppConstants.UI.Icon.medium))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppConstants.UI.Spacing.small)
            .background(Color(.systemBackground))
            .cornerRadius(AppConstants.UI.cornerRadius / 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 高级搜索视图
struct AdvancedSearchView: View {
    @Binding var searchText: String
    @Binding var selectedTypes: Set<SubscriptionType>
    @Binding var selectedTags: Set<String>
    @Binding var enabledOnly: Bool
    @Binding var hasFlowInfo: Bool
    
    let availableTags: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppConstants.UI.Spacing.medium) {
            // 搜索栏
            SearchBarView(searchText: $searchText, placeholder: "搜索订阅名称或链接")
            
            // 类型筛选
            VStack(alignment: .leading, spacing: AppConstants.UI.Spacing.small) {
                Text("订阅类型")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    ForEach(SubscriptionType.allCases, id: \.self) { type in
                        FilterChip(
                            title: type.displayName,
                            isSelected: selectedTypes.contains(type)
                        ) {
                            if selectedTypes.contains(type) {
                                selectedTypes.remove(type)
                            } else {
                                selectedTypes.insert(type)
                            }
                        }
                    }
                    
                    Spacer()
                }
            }
            
            // 标签筛选
            if !availableTags.isEmpty {
                VStack(alignment: .leading, spacing: AppConstants.UI.Spacing.small) {
                    Text("标签")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(availableTags.filter { $0 != "全部" }, id: \.self) { tag in
                                FilterChip(
                                    title: tag,
                                    isSelected: selectedTags.contains(tag)
                                ) {
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            // 状态筛选
            VStack(alignment: .leading, spacing: AppConstants.UI.Spacing.small) {
                Text("状态筛选")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: AppConstants.UI.Spacing.tiny) {
                    Toggle("仅显示启用的订阅", isOn: $enabledOnly)
                    Toggle("仅显示有流量信息的订阅", isOn: $hasFlowInfo)
                }
            }
            
            // 重置按钮
            HStack {
                Spacer()
                
                Button("重置筛选") {
                    searchText = ""
                    selectedTypes.removeAll()
                    selectedTags.removeAll()
                    enabledOnly = false
                    hasFlowInfo = false
                }
                .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius)
    }
}

// MARK: - 筛选片段
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, AppConstants.UI.Spacing.small)
                .padding(.vertical, AppConstants.UI.Spacing.tiny)
                .background(
                    isSelected ? Color.accentColor : Color(.systemGray5)
                )
                .foregroundColor(
                    isSelected ? .white : .primary
                )
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 订阅统计视图
struct SubscriptionStatsView: View {
    let subscriptions: [Subscription]
    
    private var stats: SubscriptionStats {
        let enabled = subscriptions.filter { $0.isEnabled }.count
        let disabled = subscriptions.count - enabled
        let withFlow = subscriptions.filter { $0.flow != nil }.count
        let totalUsed = subscriptions.compactMap { $0.flow?.used }.reduce(0, +)
        let totalLimit = subscriptions.compactMap { $0.flow?.total }.reduce(0, +)
        
        return SubscriptionStats(
            total: subscriptions.count,
            enabled: enabled,
            disabled: disabled,
            withFlow: withFlow,
            totalUsed: totalUsed,
            totalLimit: totalLimit
        )
    }
    
    var body: some View {
        VStack(spacing: AppConstants.UI.Spacing.medium) {
            Text("订阅统计")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: AppConstants.UI.Spacing.medium) {
                StatCard(title: "总数", value: "\(stats.total)", icon: "link", color: .blue)
                StatCard(title: "启用", value: "\(stats.enabled)", icon: "checkmark.circle", color: .green)
                StatCard(title: "禁用", value: "\(stats.disabled)", icon: "pause.circle", color: .orange)
                StatCard(title: "有流量", value: "\(stats.withFlow)", icon: "chart.bar", color: .purple)
            }
            
            if stats.totalLimit > 0 {
                VStack(spacing: AppConstants.UI.Spacing.small) {
                    Text("总流量使用情况")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Text(ByteFormatter.formatted(bytes: stats.totalUsed))
                            .font(.caption)
                            .foregroundColor(.primary)
                        
                        Text("/")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(ByteFormatter.formatted(bytes: stats.totalLimit))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: Double(stats.totalUsed) / Double(stats.totalLimit))
                        .progressViewStyle(LinearProgressViewStyle())
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(AppConstants.UI.cornerRadius)
    }
}

// MARK: - 统计卡片
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: AppConstants.UI.Spacing.small) {
            Image(systemName: icon)
                .font(.system(size: AppConstants.UI.Icon.medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(AppConstants.UI.cornerRadius / 2)
    }
}

// MARK: - 订阅统计数据
struct SubscriptionStats {
    let total: Int
    let enabled: Int
    let disabled: Int
    let withFlow: Int
    let totalUsed: Int64
    let totalLimit: Int64
}

// MARK: - 订阅快速操作视图
struct QuickActionView: View {
    let subscription: Subscription
    let onAction: (QuickAction) -> Void
    
    enum QuickAction {
        case test
        case edit
        case toggle
        case delete
        case copy
        case share
        case updateFlow
    }
    
    var body: some View {
        HStack(spacing: AppConstants.UI.Spacing.large) {
            QuickActionButton(
                icon: "play.circle",
                color: .purple,
                action: { onAction(.test) }
            )
            
            QuickActionButton(
                icon: "pencil.circle",
                color: .blue,
                action: { onAction(.edit) }
            )
            
            QuickActionButton(
                icon: subscription.isEnabled ? "pause.circle" : "play.circle",
                color: subscription.isEnabled ? .orange : .green,
                action: { onAction(.toggle) }
            )
            
            QuickActionButton(
                icon: "doc.on.doc",
                color: .cyan,
                action: { onAction(.copy) }
            )
            
            QuickActionButton(
                icon: "square.and.arrow.up",
                color: .indigo,
                action: { onAction(.share) }
            )
            
            QuickActionButton(
                icon: "trash",
                color: .red,
                action: { onAction(.delete) }
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(AppConstants.UI.cornerRadius)
    }
}

// MARK: - 快速操作按钮
struct QuickActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: AppConstants.UI.Icon.medium))
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(Color(.systemBackground))
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}