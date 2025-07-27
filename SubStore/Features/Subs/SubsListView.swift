import SwiftUI

// MARK: - 订阅列表视图
struct SubsListView: View {
    @StateObject private var viewModel = SubsViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏
                SearchBarView(searchText: $viewModel.searchText, placeholder: "搜索订阅")
                    .padding(.horizontal)
                    .padding(.top)
                
                // 标签筛选
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppConstants.UI.Spacing.small) {
                        ForEach(viewModel.availableTags, id: \.self) { tag in
                            TagView(
                                tag: tag,
                                isSelected: viewModel.selectedTag == tag
                            ) {
                                viewModel.selectedTag = tag
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, AppConstants.UI.Spacing.small)
                
                // 订阅列表
                if viewModel.isLoading {
                    LoadingView(message: "加载订阅中...")
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(error: errorMessage) {
                        viewModel.loadSubscriptions()
                    }
                } else if viewModel.filteredSubscriptions.isEmpty {
                    EmptyStateView(
                        title: "暂无订阅",
                        description: "点击右上角的 + 按钮添加您的第一个订阅",
                        systemImage: "link",
                        action: {
                            viewModel.showingAddSheet = true
                        },
                        actionTitle: "添加订阅"
                    )
                } else {
                    List {
                        ForEach(viewModel.filteredSubscriptions) { subscription in
                            SubRowView(subscription: subscription, viewModel: viewModel)
                        }
                        .onDelete(perform: viewModel.deleteSubscriptions)
                        .onMove(perform: viewModel.moveSubscriptions)
                    }
                    .refreshable {
                        viewModel.refreshSubscriptions()
                    }
                }
            }
            .navigationTitle("订阅")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("添加订阅") {
                            viewModel.showingAddSheet = true
                        }
                        
                        Button("导入订阅") {
                            viewModel.showingImportSheet = true
                        }
                        
                        Button("导出订阅") {
                            if let url = viewModel.exportSubscriptions() {
                                // 显示分享界面
                            }
                        }
                        
                        Button("刷新流量") {
                            Task {
                                await viewModel.updateFlowInfo()
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $viewModel.showingAddSheet) {
                SubEditorView(subscription: nil, editType: .subscription) { subscription in
                    viewModel.addSubscription(subscription)
                }
            }
            .sheet(item: $viewModel.editingSubscription) { subscription in
                SubEditorView(subscription: subscription, editType: .subscription) { updatedSubscription in
                    viewModel.updateSubscription(updatedSubscription)
                    viewModel.editingSubscription = nil
                }
            }
            .sheet(isPresented: $viewModel.showingImportSheet) {
                DocumentPicker { url in
                    viewModel.importSubscriptions(from: url)
                }
            }
        }
        .onAppear {
            viewModel.loadSubscriptions()
        }
    }
}

// MARK: - 订阅行视图
struct SubRowView: View {
    let subscription: Subscription
    let viewModel: SubsViewModel
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showingDetail = false
    @State private var showingActionSheet = false
    @State private var isLongPressing = false
    
    var body: some View {
        HStack(spacing: AppConstants.UI.Spacing.medium) {
            // 订阅图标
            SubscriptionIconView(subscription: subscription)
                .scaleEffect(isLongPressing ? 1.1 : 1.0)
                .animation(AnimationUtils.springBouncy, value: isLongPressing)
            
            // 订阅信息
            VStack(alignment: .leading, spacing: AppConstants.UI.Spacing.tiny) {
                HStack {
                    Text(subscription.displayName ?? subscription.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if !subscription.isEnabled {
                        Image(systemName: "pause.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .scaleEffect(isLongPressing ? 1.2 : 1.0)
                            .animation(AnimationUtils.springBouncy, value: isLongPressing)
                    }
                    
                    Spacer()
                }
                
                if let url = subscription.url {
                    Text(url.truncated(limit: 50))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if subscription.source == .local {
                    Text("本地内容")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 标签
                if !subscription.tags.isEmpty {
                    HStack {
                        ForEach(subscription.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundColor(.accentColor)
                                .clipShape(Capsule())
                                .scaleEffect(isLongPressing ? 1.05 : 1.0)
                                .animation(AnimationUtils.springBouncy.delay(Double(subscription.tags.firstIndex(of: tag) ?? 0) * 0.1), value: isLongPressing)
                        }
                        
                        if subscription.tags.count > 3 {
                            Text("+\(subscription.tags.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
            }
            
            // 流量信息
            if let flow = subscription.flow {
                FlowInfoView(flowInfo: flow)
                    .scaleEffect(isLongPressing ? 1.05 : 1.0)
                    .animation(AnimationUtils.springBouncy.delay(0.1), value: isLongPressing)
            }
        }
        .padding(.vertical, AppConstants.UI.Spacing.small)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: isLongPressing ? .accentColor.opacity(0.3) : .clear, radius: isLongPressing ? 8 : 0)
        )
        .contentShape(Rectangle())
        .cardHover()
        .onTapGesture {
            showingDetail = true
        }
        .longPressGesture(
            config: .quick,
            onLongPress: {
                showingActionSheet = true
                isLongPressing = false
            }
        )
        .swipeActions(
            left: [
                .init(title: "测试", icon: "checkmark.shield", color: .purple) {
                    viewModel.testSubscription(subscription)
                },
                .copy {
                    UIPasteboard.general.string = subscription.url ?? subscription.content ?? ""
                }
            ],
            right: [
                .init(title: subscription.isEnabled ? "禁用" : "启用", 
                      icon: subscription.isEnabled ? "pause" : "play", 
                      color: subscription.isEnabled ? .orange : .green) {
                    viewModel.toggleSubscriptionStatus(subscription)
                },
                .edit {
                    viewModel.editingSubscription = subscription
                },
                .delete {
                    // 删除逻辑将通过 ActionSheet 确认
                    showingActionSheet = true
                }
            ],
            config: .light
        )
        .sheet(isPresented: $showingDetail) {
            SubDetailView(subscription: subscription, viewModel: viewModel)
                .transition(.modal)
        }
        .confirmationDialog("订阅操作", isPresented: $showingActionSheet) {
            Button("测试连接") {
                viewModel.testSubscription(subscription)
            }
            
            Button("编辑订阅") {
                viewModel.editingSubscription = subscription
            }
            
            Button("复制链接") {
                UIPasteboard.general.string = subscription.url ?? subscription.content ?? ""
            }
            
            Button(subscription.isEnabled ? "禁用订阅" : "启用订阅") {
                viewModel.toggleSubscriptionStatus(subscription)
            }
            
            Button("删除订阅", role: .destructive) {
                if let index = viewModel.subscriptions.firstIndex(where: { $0.id == subscription.id }) {
                    viewModel.deleteSubscriptions(at: IndexSet([index]))
                }
            }
            
            Button("取消", role: .cancel) {}
        } message: {
            Text("选择要执行的操作")
        }
        .onChange(of: isLongPressing) { _, newValue in
            if newValue {
                // 长按开始时的触觉反馈已在修饰器中处理
            }
        }
    }
}

// MARK: - 订阅详情视图
struct SubDetailView: View {
    let subscription: Subscription
    let viewModel: SubsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("基本信息") {
                    DetailRowView(title: "名称", value: subscription.displayName ?? subscription.name)
                    DetailRowView(title: "状态", value: subscription.isEnabled ? "启用" : "禁用")
                    DetailRowView(title: "来源", value: subscription.source.displayName)
                    if !subscription.tags.isEmpty {
                        DetailRowView(title: "标签", value: subscription.tags.joined(separator: ", "))
                    }
                }
                
                if subscription.source == .remote, let url = subscription.url {
                    Section("订阅链接") {
                        Text(url)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                } else if subscription.source == .local, let content = subscription.content {
                    Section("本地内容") {
                        Text(content.prefix(200) + (content.count > 200 ? "..." : ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                
                if let flow = subscription.flow {
                    Section("流量信息") {
                        if !flow.isUnlimited {
                            DetailRowView(title: "已用流量", value: flow.usedFormatted)
                            DetailRowView(title: "总流量", value: flow.totalFormatted)
                            DetailRowView(title: "剩余流量", value: flow.remainingFormatted)
                            
                            if let percentage = flow.percentage {
                                HStack {
                                    Text("使用率")
                                    Spacer()
                                    ProgressView(value: percentage / 100.0)
                                        .frame(width: 100)
                                    Text("\(Int(percentage))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let resetDate = flow.resetDate {
                                DetailRowView(title: "重置时间", value: resetDate.detailFormatted)
                            }
                        } else {
                            Text("无限流量")
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Section("时间信息") {
                    DetailRowView(title: "创建时间", value: subscription.createdAt.detailFormatted)
                    DetailRowView(title: "更新时间", value: subscription.updatedAt.detailFormatted)
                }
                
                Section("操作") {
                    Button("测试连接") {
                        viewModel.testSubscription(subscription)
                    }
                    
                    Button("编辑订阅") {
                        viewModel.editingSubscription = subscription
                        dismiss()
                    }
                    
                    Button(subscription.isEnabled ? "禁用订阅" : "启用订阅") {
                        viewModel.toggleSubscriptionStatus(subscription)
                    }
                    .foregroundColor(subscription.isEnabled ? .orange : .green)
                }
            }
            .navigationTitle(subscription.displayName ?? subscription.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 详情行视图
struct DetailRowView: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - 文档选择器
struct DocumentPicker: UIViewControllerRepresentable {
    let onPicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onPicked(url)
        }
    }
}