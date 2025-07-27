import SwiftUI

// MARK: - 分享列表视图
struct ShareListView: View {
    @StateObject private var viewModel = ShareViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 筛选栏
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppConstants.UI.Spacing.small) {
                        FilterChip(
                            title: "全部",
                            isSelected: viewModel.selectedType == nil
                        ) {
                            viewModel.selectedType = nil
                        }
                        
                        ForEach(ShareType.allCases, id: \.self) { type in
                            FilterChip(
                                title: type.displayName,
                                isSelected: viewModel.selectedType == type
                            ) {
                                viewModel.selectedType = viewModel.selectedType == type ? nil : type
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, AppConstants.UI.Spacing.small)
                .background(Color(.systemGray6))
                
                // 主内容区域
                if viewModel.isLoading {
                    LoadingView(message: "加载分享中...")
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(error: errorMessage) {
                        viewModel.loadShares()
                    }
                } else if viewModel.filteredShares.isEmpty {
                    EmptyStateView(
                        title: "暂无分享",
                        description: "分享您的订阅、规则或文件给其他用户",
                        systemImage: "square.and.arrow.up",
                        action: {
                            viewModel.showingAddSheet = true
                        },
                        actionTitle: "创建分享"
                    )
                } else {
                    List {
                        ForEach(viewModel.filteredShares) { share in
                            ShareRowView(share: share, viewModel: viewModel)
                        }
                        .onDelete(perform: viewModel.deleteShares)
                    }
                    .refreshable {
                        viewModel.refreshShares()
                    }
                }
            }
            .navigationTitle("分享管理")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingAddSheet) {
                ShareCreatorView { share in
                    viewModel.addShare(share)
                }
            }
            .sheet(item: $viewModel.editingShare) { share in
                ShareEditorView(share: share) { updatedShare in
                    viewModel.updateShare(updatedShare)
                }
            }
        }
        .onAppear {
            viewModel.loadShares()
        }
    }
}

// MARK: - 分享行视图
struct ShareRowView: View {
    let share: Share
    let viewModel: ShareViewModel
    @State private var showingDetail = false
    @State private var showingQRCode = false
    
    var body: some View {
        HStack(spacing: AppConstants.UI.Spacing.medium) {
            // 类型图标
            ShareTypeIconView(type: share.type)
            
            // 分享信息
            VStack(alignment: .leading, spacing: AppConstants.UI.Spacing.tiny) {
                HStack {
                    Text(share.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if !share.isEnabled {
                        Image(systemName: "pause.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    if share.isExpired {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                }
                
                Text(share.targetName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(share.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(share.accessCount) 次访问")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let expirationDate = share.expirationDate {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("到期: \(expirationDate.shortFormatted)")
                            .font(.caption)
                            .foregroundColor(share.isExpired ? .red : .secondary)
                    }
                }
            }
            
            // 状态指示器
            ShareStatusIndicator(share: share)
        }
        .padding(.vertical, AppConstants.UI.Spacing.small)
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetail = true
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("删除", role: .destructive) {
                // 删除操作
            }
            
            Button("编辑") {
                viewModel.editingShare = share
            }
            .tint(.blue)
            
            Button(share.isEnabled ? "禁用" : "启用") {
                viewModel.toggleShareStatus(share)
            }
            .tint(share.isEnabled ? .orange : .green)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button("复制链接") {
                UIPasteboard.general.string = share.shareURL
            }
            .tint(.cyan)
            
            Button("二维码") {
                showingQRCode = true
            }
            .tint(.purple)
        }
        .sheet(isPresented: $showingDetail) {
            ShareDetailView(share: share, viewModel: viewModel)
        }
        .sheet(isPresented: $showingQRCode) {
            QRCodeView(content: share.shareURL, title: share.name)
        }
    }
}

// MARK: - 分享类型图标视图
struct ShareTypeIconView: View {
    let type: ShareType
    let size: CGFloat
    
    init(type: ShareType, size: CGFloat = AppConstants.UI.Icon.medium) {
        self.type = type
        self.size = size
    }
    
    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: size * 0.6))
            .foregroundColor(.accentColor)
            .frame(width: size, height: size)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
    }
    
    private var iconName: String {
        switch type {
        case .subscription:
            return "link"
        case .collection:
            return "link.badge.plus"
        case .artifact:
            return "doc.text"
        case .file:
            return "doc"
        }
    }
}

// MARK: - 分享状态指示器
struct ShareStatusIndicator: View {
    let share: Share
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption2)
                .foregroundColor(statusColor)
        }
    }
    
    private var statusColor: Color {
        if share.isExpired {
            return .red
        } else if !share.isEnabled {
            return .orange
        } else {
            return .green
        }
    }
    
    private var statusText: String {
        if share.isExpired {
            return "已过期"
        } else if !share.isEnabled {
            return "已禁用"
        } else {
            return "活跃"
        }
    }
}

// MARK: - 分享创建视图
struct ShareCreatorView: View {
    let onSave: (Share) -> Void
    
    @State private var name: String = ""
    @State private var selectedType: ShareType = .subscription
    @State private var selectedTargetID: String = ""
    @State private var selectedTargetName: String = ""
    @State private var hasExpiration: Bool = false
    @State private var expirationDate: Date = Date().addingTimeInterval(86400 * 7) // 7天后
    @State private var isEnabled: Bool = true
    
    // 模拟数据源
    @State private var availableTargets: [(id: String, name: String, type: ShareType)] = [
        ("1", "主要订阅", .subscription),
        ("2", "备用订阅", .subscription),
        ("3", "重写规则集", .artifact),
        ("4", "配置文件", .file)
    ]
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("分享名称", text: $name)
                    
                    Picker("分享类型", selection: $selectedType) {
                        ForEach(ShareType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                }
                
                Section("选择内容") {
                    Picker("选择要分享的内容", selection: $selectedTargetID) {
                        ForEach(filteredTargets, id: \.id) { target in
                            Text(target.name).tag(target.id)
                        }
                    }
                    .onChange(of: selectedTargetID) { targetID in
                        if let target = filteredTargets.first(where: { $0.id == targetID }) {
                            selectedTargetName = target.name
                            if name.isEmpty {
                                name = "分享 - \(target.name)"
                            }
                        }
                    }
                }
                
                Section("分享设置") {
                    Toggle("启用分享", isOn: $isEnabled)
                    
                    Toggle("设置过期时间", isOn: $hasExpiration)
                    
                    if hasExpiration {
                        DatePicker("过期时间", selection: $expirationDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("创建分享")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("创建") {
                        createShare()
                    }
                    .disabled(name.isEmpty || selectedTargetID.isEmpty)
                }
            }
        }
        .onAppear {
            if let firstTarget = filteredTargets.first {
                selectedTargetID = firstTarget.id
                selectedTargetName = firstTarget.name
                name = "分享 - \(firstTarget.name)"
            }
        }
    }
    
    private var filteredTargets: [(id: String, name: String, type: ShareType)] {
        return availableTargets.filter { $0.type == selectedType }
    }
    
    private func createShare() {
        let newShare = Share(
            name: name,
            type: selectedType,
            targetID: selectedTargetID,
            targetName: selectedTargetName,
            expirationDate: hasExpiration ? expirationDate : nil,
            isEnabled: isEnabled
        )
        
        onSave(newShare)
        dismiss()
    }
}

// MARK: - 分享编辑视图
struct ShareEditorView: View {
    let share: Share
    let onSave: (Share) -> Void
    
    @State private var name: String
    @State private var hasExpiration: Bool
    @State private var expirationDate: Date
    @State private var isEnabled: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    init(share: Share, onSave: @escaping (Share) -> Void) {
        self.share = share
        self.onSave = onSave
        
        _name = State(initialValue: share.name)
        _hasExpiration = State(initialValue: share.expirationDate != nil)
        _expirationDate = State(initialValue: share.expirationDate ?? Date().addingTimeInterval(86400 * 7))
        _isEnabled = State(initialValue: share.isEnabled)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("分享名称", text: $name)
                    
                    HStack {
                        Text("分享类型")
                        Spacer()
                        Text(share.type.displayName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("分享内容")
                        Spacer()
                        Text(share.targetName)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("分享设置") {
                    Toggle("启用分享", isOn: $isEnabled)
                    
                    Toggle("设置过期时间", isOn: $hasExpiration)
                    
                    if hasExpiration {
                        DatePicker("过期时间", selection: $expirationDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                Section("统计信息") {
                    HStack {
                        Text("访问次数")
                        Spacer()
                        Text("\(share.accessCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("创建时间")
                        Spacer()
                        Text(share.createdAt.shortFormatted)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("编辑分享")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveShare()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveShare() {
        let updatedShare = Share(
            id: share.id,
            name: name,
            token: share.token,
            type: share.type,
            targetID: share.targetID,
            targetName: share.targetName,
            expirationDate: hasExpiration ? expirationDate : nil,
            isEnabled: isEnabled,
            accessCount: share.accessCount,
            createdAt: share.createdAt,
            updatedAt: Date()
        )
        
        onSave(updatedShare)
        dismiss()
    }
}

// MARK: - 分享详情视图
struct ShareDetailView: View {
    let share: Share
    let viewModel: ShareViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingQRCode = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("分享信息") {
                    DetailRowView(title: "名称", value: share.name)
                    DetailRowView(title: "类型", value: share.type.displayName)
                    DetailRowView(title: "内容", value: share.targetName)
                    DetailRowView(title: "状态", value: share.isEnabled ? "启用" : "禁用")
                }
                
                Section("分享链接") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(share.shareURL)
                            .font(.caption)
                            .textSelection(.enabled)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Button("复制链接") {
                                UIPasteboard.general.string = share.shareURL
                            }
                            .buttonStyle(.bordered)
                            
                            Button("显示二维码") {
                                showingQRCode = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                Section("访问统计") {
                    DetailRowView(title: "访问次数", value: "\(share.accessCount)")
                    
                    if let expirationDate = share.expirationDate {
                        DetailRowView(title: "过期时间", value: expirationDate.detailFormatted)
                        DetailRowView(title: "状态", value: share.isExpired ? "已过期" : "有效")
                    } else {
                        DetailRowView(title: "过期时间", value: "永不过期")
                    }
                }
                
                Section("时间信息") {
                    DetailRowView(title: "创建时间", value: share.createdAt.detailFormatted)
                    DetailRowView(title: "更新时间", value: share.updatedAt.detailFormatted)
                }
                
                Section("操作") {
                    Button("编辑分享") {
                        viewModel.editingShare = share
                        dismiss()
                    }
                    
                    Button(share.isEnabled ? "禁用分享" : "启用分享") {
                        viewModel.toggleShareStatus(share)
                    }
                    .foregroundColor(share.isEnabled ? .orange : .green)
                    
                    Button("重新生成令牌") {
                        viewModel.regenerateToken(share)
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle(share.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingQRCode) {
                QRCodeView(content: share.shareURL, title: share.name)
            }
        }
    }
}

// MARK: - 二维码视图
struct QRCodeView: View {
    let content: String
    let title: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("扫描二维码分享")
                    .font(.headline)
                
                // 这里应该生成真实的二维码
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .frame(width: 250, height: 250)
                    .overlay {
                        Text("QR Code\n\(title)")
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                
                Text(content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                Button("保存到相册") {
                    // 保存二维码到相册
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("分享二维码")
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

// MARK: - 分享 ViewModel
@MainActor
class ShareViewModel: BaseViewModel {
    @Published var shares: [Share] = []
    @Published var filteredShares: [Share] = []
    @Published var selectedType: ShareType? = nil
    @Published var showingAddSheet: Bool = false
    @Published var editingShare: Share? = nil
    
    override init() {
        super.init()
        setupObservers()
    }
    
    private func setupObservers() {
        Publishers.CombineLatest($shares, $selectedType)
            .sink { [weak self] shares, selectedType in
                self?.updateFilteredShares(shares: shares, selectedType: selectedType)
            }
            .store(in: &cancellables)
    }
    
    func loadShares() {
        Task {
            await performAsyncTask { [weak self] in
                // 模拟加载分享
                let mockShares = [
                    Share(name: "分享 - 主要订阅", type: .subscription, targetID: "1", targetName: "主要订阅"),
                    Share(name: "分享 - 重写规则", type: .artifact, targetID: "2", targetName: "重写规则集"),
                    Share(name: "分享 - 配置文件", type: .file, targetID: "3", targetName: "配置文件.yaml")
                ]
                self?.shares = mockShares
                Logger.shared.info("Loaded \(mockShares.count) shares")
            }
        }
    }
    
    func refreshShares() {
        clearError()
        loadShares()
    }
    
    func addShare(_ share: Share) {
        shares.append(share)
        Logger.shared.info("Added share: \(share.name)")
    }
    
    func updateShare(_ share: Share) {
        if let index = shares.firstIndex(where: { $0.id == share.id }) {
            shares[index] = share
            Logger.shared.info("Updated share: \(share.name)")
        }
    }
    
    func deleteShares(at offsets: IndexSet) {
        let sharesToDelete = offsets.map { filteredShares[$0] }
        
        for share in sharesToDelete {
            shares.removeAll { $0.id == share.id }
            Logger.shared.info("Deleted share: \(share.name)")
        }
    }
    
    func toggleShareStatus(_ share: Share) {
        let updatedShare = Share(
            id: share.id,
            name: share.name,
            token: share.token,
            type: share.type,
            targetID: share.targetID,
            targetName: share.targetName,
            expirationDate: share.expirationDate,
            isEnabled: !share.isEnabled,
            accessCount: share.accessCount,
            createdAt: share.createdAt,
            updatedAt: Date()
        )
        updateShare(updatedShare)
    }
    
    func regenerateToken(_ share: Share) {
        let updatedShare = Share(
            id: share.id,
            name: share.name,
            token: CryptoUtils.randomString(length: 32),
            type: share.type,
            targetID: share.targetID,
            targetName: share.targetName,
            expirationDate: share.expirationDate,
            isEnabled: share.isEnabled,
            accessCount: 0, // 重置访问计数
            createdAt: share.createdAt,
            updatedAt: Date()
        )
        updateShare(updatedShare)
        Logger.shared.info("Regenerated token for share: \(share.name)")
    }
    
    private func updateFilteredShares(shares: [Share], selectedType: ShareType?) {
        if let selectedType = selectedType {
            filteredShares = shares.filter { $0.type == selectedType }
        } else {
            filteredShares = shares
        }
    }
}