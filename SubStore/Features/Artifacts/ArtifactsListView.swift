import SwiftUI

// MARK: - 规则列表视图
struct ArtifactsListView: View {
    @StateObject private var viewModel = ArtifactsViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索和筛选栏
                VStack(spacing: AppConstants.UI.Spacing.small) {
                    SearchBarView(searchText: $viewModel.searchText, placeholder: "搜索规则")
                    
                    // 类型筛选
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppConstants.UI.Spacing.small) {
                            FilterChip(
                                title: "全部",
                                isSelected: viewModel.selectedType == nil
                            ) {
                                viewModel.selectedType = nil
                            }
                            
                            ForEach(ArtifactType.allCases, id: \.self) { type in
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
                }
                .padding()
                .background(Color(.systemGray6))
                
                // 主内容区域
                if viewModel.isLoading {
                    LoadingView(message: "加载规则中...")
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(error: errorMessage) {
                        viewModel.loadArtifacts()
                    }
                } else if viewModel.filteredArtifacts.isEmpty {
                    EmptyStateView(
                        title: "暂无规则",
                        description: "点击右上角的 + 按钮创建您的第一个规则",
                        systemImage: "doc.text",
                        action: {
                            viewModel.showingAddSheet = true
                        },
                        actionTitle: "创建规则"
                    )
                } else {
                    List {
                        // 批量操作栏
                        if !viewModel.selectedArtifacts.isEmpty {
                            Section {
                                ArtifactBatchOperationView(
                                    selectedArtifacts: $viewModel.selectedArtifacts,
                                    allArtifacts: viewModel.filteredArtifacts
                                ) { operation in
                                    viewModel.performBatchOperation(operation, on: viewModel.selectedArtifacts)
                                }
                            }
                        }
                        
                        // 规则列表
                        Section {
                            ForEach(viewModel.filteredArtifacts) { artifact in
                                ArtifactRowView(
                                    artifact: artifact,
                                    viewModel: viewModel,
                                    isSelected: viewModel.selectedArtifacts.contains(artifact.id)
                                ) {
                                    viewModel.toggleArtifactSelection(artifact.id)
                                }
                            }
                            .onDelete(perform: viewModel.deleteArtifacts)
                        }
                    }
                    .refreshable {
                        viewModel.refreshArtifacts()
                    }
                    .environment(\.editMode, .constant(viewModel.selectedArtifacts.isEmpty ? .inactive : .active))
                }
            }
            .navigationTitle("规则管理")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !viewModel.selectedArtifacts.isEmpty {
                        Button("取消选择") {
                            viewModel.selectedArtifacts.removeAll()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("创建规则") {
                            viewModel.showingAddSheet = true
                        }
                        
                        Button("同步设置") {
                            viewModel.showingSyncSheet = true
                        }
                        
                        Button("全部同步") {
                            viewModel.syncAllArtifacts()
                        }
                        .disabled(viewModel.syncConfigs.filter { $0.isEnabled }.isEmpty)
                        
                        Button("测试全部") {
                            Task {
                                for artifact in viewModel.artifacts {
                                    viewModel.testArtifact(artifact)
                                }
                            }
                        }
                        
                        Button(viewModel.selectedArtifacts.isEmpty ? "全选" : "全部取消") {
                            viewModel.selectAllArtifacts()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingAddSheet) {
                ArtifactEditorView(artifact: nil) { artifact in
                    viewModel.addArtifact(artifact)
                }
            }
            .sheet(isPresented: $viewModel.showingSyncSheet) {
                SyncConfigurationView(
                    syncConfigs: $viewModel.syncConfigs,
                    onConfigAdded: viewModel.addSyncConfig,
                    onConfigUpdated: viewModel.updateSyncConfig,
                    onConfigDeleted: viewModel.deleteSyncConfig
                )
            }
            .sheet(item: $viewModel.editingArtifact) { artifact in
                ArtifactEditorView(artifact: artifact) { updatedArtifact in
                    viewModel.updateArtifact(updatedArtifact)
                }
            }
            .overlay(alignment: .bottom) {
                // 同步状态指示器
                if viewModel.syncInProgress {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("同步中...")
                            .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(radius: 4)
                    .padding()
                }
            }
        }
        .onAppear {
            viewModel.loadArtifacts()
        }
    }
}

// MARK: - 规则行视图
struct ArtifactRowView: View {
    let artifact: Artifact
    let viewModel: ArtifactsViewModel
    let isSelected: Bool
    let onSelectionToggle: () -> Void
    
    @State private var showingDetail = false
    
    var body: some View {
        HStack(spacing: AppConstants.UI.Spacing.medium) {
            // 选择指示器
            Button(action: onSelectionToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 20))
            }
            .buttonStyle(PlainButtonStyle())
            
            // 规则图标
            ArtifactIconView(artifact: artifact)
            
            // 规则信息
            VStack(alignment: .leading, spacing: AppConstants.UI.Spacing.tiny) {
                HStack {
                    Text(artifact.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if !artifact.isEnabled {
                        Image(systemName: "pause.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    // 测试状态
                    if let testResult = viewModel.testResults[artifact.id] {
                        TestStatusView(result: testResult)
                    }
                }
                
                Text(artifact.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // 标签
                if !artifact.tags.isEmpty {
                    HStack {
                        ForEach(artifact.tags.prefix(2), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundColor(.accentColor)
                                .clipShape(Capsule())
                        }
                        
                        if artifact.tags.count > 2 {
                            Text("+\(artifact.tags.count - 2)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                
                // 同步状态
                if let lastSync = artifact.lastSync {
                    HStack {
                        Image(systemName: "cloud.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        
                        Text("最后同步: \(lastSync.relativeFormatted)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(.vertical, AppConstants.UI.Spacing.small)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isSelected {
                showingDetail = true
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("删除", role: .destructive) {
                // 删除操作会在列表的 onDelete 中处理
            }
            
            Button("编辑") {
                viewModel.editingArtifact = artifact
            }
            .tint(.blue)
            
            Button(artifact.isEnabled ? "禁用" : "启用") {
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
            .tint(artifact.isEnabled ? .orange : .green)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button("测试") {
                viewModel.testArtifact(artifact)
            }
            .tint(.purple)
            
            Button("同步") {
                // 显示同步选项
            }
            .tint(.cyan)
        }
        .sheet(isPresented: $showingDetail) {
            ArtifactDetailView(artifact: artifact, viewModel: viewModel)
        }
    }
}

// MARK: - 规则图标视图
struct ArtifactIconView: View {
    let artifact: Artifact
    let size: CGFloat
    
    init(artifact: Artifact, size: CGFloat = AppConstants.UI.Icon.medium) {
        self.artifact = artifact
        self.size = size
    }
    
    var body: some View {
        Image(systemName: artifact.type.iconName)
            .font(.system(size: size * 0.6))
            .foregroundColor(.accentColor)
            .frame(width: size, height: size)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
    }
}

// MARK: - 测试状态视图
struct TestStatusView: View {
    let result: ArtifactTestResult
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption2)
                .foregroundColor(result.success ? .green : .red)
            
            Text(result.success ? "通过" : "失败")
                .font(.caption2)
                .foregroundColor(result.success ? .green : .red)
        }
    }
}

// MARK: - 批量操作视图
struct ArtifactBatchOperationView: View {
    @Binding var selectedArtifacts: Set<String>
    let allArtifacts: [Artifact]
    let onBatchOperation: (ArtifactBatchOperation) -> Void
    
    var body: some View {
        VStack(spacing: AppConstants.UI.Spacing.medium) {
            // 选择统计
            HStack {
                Text("已选择 \(selectedArtifacts.count) 项")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("全选") {
                    if selectedArtifacts.count == allArtifacts.count {
                        selectedArtifacts.removeAll()
                    } else {
                        selectedArtifacts = Set(allArtifacts.map { $0.id })
                    }
                }
                .foregroundColor(.accentColor)
            }
            
            // 操作按钮
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: AppConstants.UI.Spacing.small) {
                BatchOperationButton(
                    title: "启用",
                    systemImage: "checkmark.circle",
                    color: .green
                ) {
                    onBatchOperation(.enable)
                }
                
                BatchOperationButton(
                    title: "禁用",
                    systemImage: "pause.circle",
                    color: .orange
                ) {
                    onBatchOperation(.disable)
                }
                
                BatchOperationButton(
                    title: "测试",
                    systemImage: "play.circle",
                    color: .purple
                ) {
                    onBatchOperation(.test)
                }
                
                BatchOperationButton(
                    title: "删除",
                    systemImage: "trash",
                    color: .red
                ) {
                    onBatchOperation(.delete)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(AppConstants.UI.cornerRadius)
        .disabled(selectedArtifacts.isEmpty)
    }
}

// MARK: - 规则编辑视图
struct ArtifactEditorView: View {
    let artifact: Artifact?
    let onSave: (Artifact) -> Void
    
    @State private var name: String = ""
    @State private var type: ArtifactType = .rewrite
    @State private var content: String = ""
    @State private var platform: String = ""
    @State private var source: String = ""
    @State private var syncURL: String = ""
    @State private var tags: String = ""
    @State private var isEnabled: Bool = true
    
    @State private var showingContentEditor = false
    @Environment(\.dismiss) private var dismiss
    
    init(artifact: Artifact?, onSave: @escaping (Artifact) -> Void) {
        self.artifact = artifact
        self.onSave = onSave
        
        if let artifact = artifact {
            _name = State(initialValue: artifact.name)
            _type = State(initialValue: artifact.type)
            _content = State(initialValue: artifact.content)
            _platform = State(initialValue: artifact.platform ?? "")
            _source = State(initialValue: artifact.source ?? "")
            _syncURL = State(initialValue: artifact.syncURL ?? "")
            _tags = State(initialValue: artifact.tags.joined(separator: ", "))
            _isEnabled = State(initialValue: artifact.isEnabled)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("规则名称", text: $name)
                    
                    Picker("规则类型", selection: $type) {
                        ForEach(ArtifactType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    Toggle("启用规则", isOn: $isEnabled)
                }
                
                Section("规则内容") {
                    HStack {
                        Text("规则代码")
                        Spacer()
                        Button("编辑") {
                            showingContentEditor = true
                        }
                        .foregroundColor(.accentColor)
                    }
                    
                    if !content.isEmpty {
                        Text(content.prefix(100) + (content.count > 100 ? "..." : ""))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    }
                }
                
                Section("扩展信息") {
                    TextField("平台", text: $platform)
                    TextField("来源", text: $source)
                    TextField("同步链接", text: $syncURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextField("标签 (用逗号分隔)", text: $tags)
                }
                
                if let artifact = artifact {
                    Section("规则信息") {
                        HStack {
                            Text("创建时间")
                            Spacer()
                            Text(artifact.createdAt.detailFormatted)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("更新时间")
                            Spacer()
                            Text(artifact.updatedAt.detailFormatted)
                                .foregroundColor(.secondary)
                        }
                        
                        if let lastSync = artifact.lastSync {
                            HStack {
                                Text("最后同步")
                                Spacer()
                                Text(lastSync.detailFormatted)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(artifact == nil ? "创建规则" : "编辑规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveArtifact()
                    }
                    .disabled(name.isEmpty || content.isEmpty)
                }
            }
            .sheet(isPresented: $showingContentEditor) {
                CodeEditorView(
                    content: $content,
                    language: type.codeLanguage,
                    title: "编辑规则内容"
                )
            }
        }
    }
    
    private func saveArtifact() {
        let tagsArray = tags.components(separatedBy: ",").map { $0.trimmed }.filter { !$0.isEmpty }
        
        let newArtifact = Artifact(
            id: artifact?.id ?? UUID().uuidString,
            name: name,
            type: type,
            content: content,
            platform: platform.isEmpty ? nil : platform,
            source: source.isEmpty ? nil : source,
            syncURL: syncURL.isEmpty ? nil : syncURL,
            tags: tagsArray,
            isEnabled: isEnabled,
            createdAt: artifact?.createdAt ?? Date(),
            updatedAt: Date(),
            lastSync: artifact?.lastSync
        )
        
        onSave(newArtifact)
        dismiss()
    }
}

// MARK: - 代码编辑器视图
struct CodeEditorView: View {
    @Binding var content: String
    let language: String
    let title: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                // 工具栏
                HStack {
                    Button("格式化") {
                        // 实现代码格式化
                    }
                    .foregroundColor(.accentColor)
                    
                    Spacer()
                    
                    Text("\(content.count) 字符")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // 编辑器
                TextEditor(text: $content)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}