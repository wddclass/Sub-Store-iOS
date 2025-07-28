import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 规则详情视图
struct ArtifactDetailView: View {
    let artifact: Artifact
    let viewModel: ArtifactsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingContentView = false
    @State private var showingSyncOptions = false
    
    var body: some View {
        NavigationView {
            List {
                Section("基本信息") {
                    DetailRowView(title: "名称", value: artifact.name)
                    DetailRowView(title: "类型", value: artifact.type.displayName)
                    DetailRowView(title: "状态", value: artifact.isEnabled ? "启用" : "禁用")
                    
                    if let platform = artifact.platform {
                        DetailRowView(title: "平台", value: platform)
                    }
                    
                    if let source = artifact.source {
                        DetailRowView(title: "来源", value: source)
                    }
                }
                
                Section("规则内容") {
                    Button("查看代码") {
                        showingContentView = true
                    }
                    .foregroundColor(.accentColor)
                    
                    HStack {
                        Text("内容长度")
                        Spacer()
                        Text("\(artifact.content.count) 字符")
                            .foregroundColor(.secondary)
                    }
                    
                    if !artifact.content.isEmpty {
                        Text(artifact.content.prefix(200) + (artifact.content.count > 200 ? "..." : ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    }
                }
                
                if !artifact.tags.isEmpty {
                    Section("标签") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(artifact.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.1))
                                        .foregroundColor(.accentColor)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // 测试结果
                if let testResult = viewModel.testResults[artifact.id] {
                    Section("测试结果") {
                        TestResultDetailView(result: testResult)
                    }
                }
                
                // 同步信息
                if artifact.syncURL != nil || artifact.lastSync != nil {
                    Section("同步信息") {
                        if let syncURL = artifact.syncURL {
                            DetailRowView(title: "同步链接", value: syncURL)
                        }
                        
                        if let lastSync = artifact.lastSync {
                            DetailRowView(title: "最后同步", value: lastSync.detailFormatted)
                        }
                    }
                }
                
                Section("时间信息") {
                    DetailRowView(title: "创建时间", value: artifact.createdAt.detailFormatted)
                    DetailRowView(title: "更新时间", value: artifact.updatedAt.detailFormatted)
                }
                
                Section("操作") {
                    Button("测试规则") {
                        viewModel.testArtifact(artifact)
                    }
                    
                    Button("编辑规则") {
                        viewModel.editingArtifact = artifact
                        dismiss()
                    }
                    
                    Button("同步规则") {
                        showingSyncOptions = true
                    }
                    
                    Button(artifact.isEnabled ? "禁用规则" : "启用规则") {
                        var updatedArtifact = artifact
                        updatedArtifact = Artifact(
                            id: artifact.id,
                            name: artifact.name,
                            type: artifact.type,
                            content: artifact.content,
                            platform: artifact.platform,
                            source: artifact.source,
                            syncURL: artifact.syncURL,
                            tags: artifact.tags,
                            isEnabled: !artifact.isEnabled,
                            createdAt: artifact.createdAt,
                            updatedAt: Date(),
                            lastSync: artifact.lastSync
                        )
                        viewModel.updateArtifact(updatedArtifact)
                    }
                    .foregroundColor(artifact.isEnabled ? .orange : .green)
                }
            }
            .navigationTitle(artifact.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingContentView) {
                ArtifactContentView(artifact: artifact)
            }
            .actionSheet(isPresented: $showingSyncOptions) {
                ActionSheet(
                    title: Text("选择同步提供商"),
                    buttons: viewModel.syncConfigs.filter { $0.isEnabled }.map { config in
                        .default(Text(config.provider.displayName)) {
                            viewModel.syncToProvider(artifact, provider: config.provider)
                        }
                    } + [.cancel()]
                )
            }
        }
    }
}

// MARK: - 规则内容查看视图
struct ArtifactContentView: View {
    let artifact: Artifact
    @Environment(\.dismiss) private var dismiss
    @State private var showingShare = false
    
    var body: some View {
        NavigationView {
            VStack {
                // 工具栏
                HStack {
                    Text("\(artifact.content.count) 字符")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("复制") {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = artifact.content
                        #endif
                    }
                    .foregroundColor(.accentColor)
                    
                    Button("分享") {
                        showingShare = true
                    }
                    .foregroundColor(.accentColor)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // 内容显示
                ScrollView {
                    Text(artifact.content)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle(artifact.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShare) {
                ShareSheet(items: [artifact.content])
            }
        }
    }
}

// MARK: - 测试结果详情视图
struct TestResultDetailView: View {
    let result: ArtifactTestResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppConstants.UI.Spacing.small) {
            // 状态指示器
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.success ? .green : .red)
                
                Text(result.success ? "测试通过" : "测试失败")
                    .font(.headline)
                    .foregroundColor(result.success ? .green : .red)
                
                Spacer()
                
                Text(result.testTime.relativeFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 消息
            if !result.message.isEmpty {
                Text(result.message)
                    .font(.body)
                    .foregroundColor(.primary)
            }
            
            // 错误列表
            if !result.errors.isEmpty {
                VStack(alignment: .leading, spacing: AppConstants.UI.Spacing.tiny) {
                    Text("错误:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                    
                    ForEach(result.errors, id: \.self) { error in
                        HStack(alignment: .top) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            
            // 警告列表
            if !result.warnings.isEmpty {
                VStack(alignment: .leading, spacing: AppConstants.UI.Spacing.tiny) {
                    Text("警告:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    
                    ForEach(result.warnings, id: \.self) { warning in
                        HStack(alignment: .top) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(warning)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            
            // 性能信息
            if let performance = result.performance {
                VStack(alignment: .leading, spacing: AppConstants.UI.Spacing.tiny) {
                    Text("性能信息:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    HStack {
                        Text("执行时间:")
                        Spacer()
                        Text("\(performance.executionTime, specifier: "%.2f")ms")
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("内存使用:")
                        Spacer()
                        Text(ByteFormatter.formatted(bytes: performance.memoryUsage))
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("规则数量:")
                        Spacer()
                        Text("\(performance.ruleCount)")
                    }
                    .font(.caption)
                    
                    HStack {
                        Text("复杂度:")
                        Spacer()
                        Text(performance.complexity.displayName)
                            .foregroundColor(Color(performance.complexity.color))
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(AppConstants.UI.cornerRadius)
    }
}

// MARK: - 同步配置视图
struct SyncConfigurationView: View {
    @Binding var syncConfigs: [SyncConfig]
    let onConfigAdded: (SyncConfig) -> Void
    let onConfigUpdated: (SyncConfig) -> Void
    let onConfigDeleted: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddConfig = false
    @State private var editingConfig: SyncConfig?
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("同步提供商")) {
                    ForEach(syncConfigs) { config in
                        SyncConfigRowView(
                            config: config,
                            onEdit: { editingConfig = config },
                            onDelete: { onConfigDeleted(config.id) },
                            onToggle: { 
                                var updatedConfig = config
                                updatedConfig = SyncConfig(
                                    id: config.id,
                                    provider: config.provider,
                                    token: config.token,
                                    repositoryURL: config.repositoryURL,
                                    isEnabled: !config.isEnabled,
                                    lastSync: config.lastSync,
                                    syncInterval: config.syncInterval
                                )
                                onConfigUpdated(updatedConfig)
                            }
                        )
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            onConfigDeleted(syncConfigs[index].id)
                        }
                    }
                }
                
                Section(footer: Text("添加同步配置后，规则将自动同步到指定的云端存储服务。")) {
                    Button("添加同步配置") {
                        showingAddConfig = true
                    }
                    .foregroundColor(.accentColor)
                }
            }
            .navigationTitle("同步设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddConfig) {
                SyncConfigEditorView(config: nil) { config in
                    onConfigAdded(config)
                }
            }
            .sheet(item: $editingConfig) { config in
                SyncConfigEditorView(config: config) { updatedConfig in
                    onConfigUpdated(updatedConfig)
                }
            }
        }
    }
}

// MARK: - 同步配置行视图
struct SyncConfigRowView: View {
    let config: SyncConfig
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            // 提供商图标
            Image(systemName: config.provider.iconName)
                .font(.system(size: AppConstants.UI.Icon.medium))
                .foregroundColor(.accentColor)
                .frame(width: AppConstants.UI.Icon.large)
            
            VStack(alignment: .leading, spacing: AppConstants.UI.Spacing.tiny) {
                Text(config.provider.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let lastSync = config.lastSync {
                    Text("最后同步: \(lastSync.relativeFormatted)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("尚未同步")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("每 \(Int(config.syncInterval / 3600)) 小时自动同步")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 状态切换
            Toggle("", isOn: .constant(config.isEnabled))
                .onTapGesture {
                    onToggle()
                }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("删除", role: .destructive) {
                onDelete()
            }
            
            Button("编辑") {
                onEdit()
            }
            .tint(.blue)
        }
    }
}

// MARK: - 同步配置编辑视图
struct SyncConfigEditorView: View {
    let config: SyncConfig?
    let onSave: (SyncConfig) -> Void
    
    @State private var selectedProvider: SyncProvider = .githubGist
    @State private var token: String = ""
    @State private var repositoryURL: String = ""
    @State private var isEnabled: Bool = true
    @State private var syncInterval: Double = 3600 // 1小时
    
    @Environment(\.dismiss) private var dismiss
    
    init(config: SyncConfig?, onSave: @escaping (SyncConfig) -> Void) {
        self.config = config
        self.onSave = onSave
        
        if let config = config {
            _selectedProvider = State(initialValue: config.provider)
            _token = State(initialValue: config.token)
            _repositoryURL = State(initialValue: config.repositoryURL ?? "")
            _isEnabled = State(initialValue: config.isEnabled)
            _syncInterval = State(initialValue: config.syncInterval)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("同步服务") {
                    Picker("提供商", selection: $selectedProvider) {
                        ForEach(SyncProvider.allCases, id: \.self) { provider in
                            HStack {
                                Image(systemName: provider.iconName)
                                Text(provider.displayName)
                            }
                            .tag(provider)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("认证信息") {
                    SecureField("访问令牌", text: $token)
                        #if canImport(UIKit)
                        .textContentType(.password)
                        #endif
                    
                    TextField("仓库链接 (可选)", text: $repositoryURL)
                        #if canImport(UIKit)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        #endif
                }
                
                Section("同步设置") {
                    Toggle("启用自动同步", isOn: $isEnabled)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("同步间隔")
                            Spacer()
                            Text("\(Int(syncInterval / 3600)) 小时")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $syncInterval, in: 1800...86400, step: 1800) // 30分钟到24小时
                            .onChange(of: syncInterval) { value in
                                // 确保值是30分钟的倍数
                                syncInterval = round(value / 1800) * 1800
                            }
                    }
                }
                
                Section(footer: syncConfigurationInstructions) {
                    EmptyView()
                }
            }
            .navigationTitle(config == nil ? "添加同步配置" : "编辑同步配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveSyncConfig()
                    }
                    .disabled(token.isEmpty)
                }
            }
        }
    }
    
    private var syncConfigurationInstructions: some View {
        VStack(alignment: .leading, spacing: AppConstants.UI.Spacing.small) {
            switch selectedProvider {
            case .githubGist:
                Text("GitHub Gist 配置说明:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("1. 访问 GitHub Settings > Developer settings > Personal access tokens")
                Text("2. 创建新的 token，勾选 'gist' 权限")
                Text("3. 将生成的 token 粘贴到上方输入框")
            case .gitlabSnippet:
                Text("GitLab Snippet 配置说明:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("1. 访问 GitLab User Settings > Access Tokens")
                Text("2. 创建新的 token，勾选 'api' 权限")
                Text("3. 将生成的 token 粘贴到上方输入框")
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
    
    private func saveSyncConfig() {
        let newConfig = SyncConfig(
            id: config?.id ?? UUID().uuidString,
            provider: selectedProvider,
            token: token,
            repositoryURL: repositoryURL.isEmpty ? nil : repositoryURL,
            isEnabled: isEnabled,
            lastSync: config?.lastSync,
            syncInterval: syncInterval
        )
        
        onSave(newConfig)
        dismiss()
    }
}

#if canImport(UIKit)
// MARK: - 分享视图
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif