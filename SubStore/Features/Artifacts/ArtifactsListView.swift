import SwiftUI

// MARK: - 规则列表视图
struct ArtifactsListView: View {
    @StateObject private var viewModel = ArtifactsViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchAndFilterSection
                mainContentSection
            }
            .navigationTitle("规则管理")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                leadingToolbarItem
                trailingToolbarItem
            }
            .sheet(isPresented: $viewModel.showingAddSheet) {
                // TODO: Implement ArtifactEditorView
                Text("创建规则功能开发中...")
                    .padding()
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
                // TODO: Implement ArtifactEditorView
                VStack {
                    Text("编辑规则功能开发中...")
                    Text("规则名称: \(artifact.name)")
                }
                .padding()
            }
            .overlay(alignment: .bottom) {
                syncProgressOverlay
            }
        }
        .onAppear {
            viewModel.loadArtifacts()
        }
    }
    
    // MARK: - View Components
    private var searchAndFilterSection: some View {
        VStack(spacing: AppConstants.UI.Spacing.small) {
            SearchBarView(searchText: $viewModel.searchText, placeholder: "搜索规则")
            
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
        #if canImport(UIKit)
        .background(Color(.systemGray6))
        #else
        .background(Color.gray.opacity(0.1))
        #endif
    }
    
    private var mainContentSection: some View {
        Group {
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
                artifactsList
            }
        }
    }
    
    private var artifactsList: some View {
        List {
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
        #if os(iOS)
        .environment(\.editMode, .constant(viewModel.selectedArtifacts.isEmpty ? .inactive : .active))
        #endif
    }
    
    @ToolbarContentBuilder
    private var leadingToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if !viewModel.selectedArtifacts.isEmpty {
                Button("取消选择") {
                    viewModel.selectedArtifacts.removeAll()
                }
            }
        }
    }
    
    @ToolbarContentBuilder
    private var trailingToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
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
    
    private var syncProgressOverlay: some View {
        Group {
            if viewModel.syncInProgress {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("同步中...")
                        .font(.caption)
                }
                .padding()
                #if canImport(UIKit)
                .background(Color(.systemBackground))
                #else
                .background(Color.white)
                #endif
                .cornerRadius(20)
                .shadow(radius: 4)
                .padding()
            }
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
            // TODO: Implement ArtifactDetailView
            VStack {
                Text("规则详情")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("规则名称: \(artifact.name)")
                Text("规则类型: \(artifact.type.displayName)")
                Button("关闭") {
                    showingDetail = false
                }
                .padding()
            }
            .padding()
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
        #if canImport(UIKit)
        .background(Color(.systemGray6))
        #else
        .background(Color.gray.opacity(0.1))
        #endif
        .cornerRadius(AppConstants.UI.cornerRadius)
        .disabled(selectedArtifacts.isEmpty)
    }
}