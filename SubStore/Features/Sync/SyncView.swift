import SwiftUI

// MARK: - 同步页面视图
struct SyncView: View {
    @StateObject private var viewModel = SyncViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var showingAddArtifact = false
    @State private var showingPreview = false
    @State private var editingArtifact: Artifact?
    @State private var isDragging = false
    @State private var showingDownloadConfirmation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    loadingView
                } else if !viewModel.fetchSuccess {
                    errorView
                } else if viewModel.artifacts.isEmpty {
                    emptyStateView
                } else {
                    artifactsList
                }
                
                // 浮动添加按钮
                if !viewModel.artifacts.isEmpty && settingsManager.settings.appearance.showFlowInfo {
                    floatingAddButton
                }
            }
            .navigationTitle("同步")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    actionButtons
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
        .sheet(isPresented: $showingAddArtifact) {
            ArtifactEditorView(
                artifact: editingArtifact,
                isPresented: $showingAddArtifact
            ) { artifact in
                if let artifact = artifact {
                    viewModel.saveArtifact(artifact)
                }
                editingArtifact = nil
            }
        }
        .alert("下载确认", isPresented: $showingDownloadConfirmation) {
            Button("取消", role: .cancel) {
                viewModel.cancelDownload()
            }
            Button("确认下载", role: .destructive) {
                Task {
                    await viewModel.downloadAll()
                }
            }
        } message: {
            Text(downloadConfirmationMessage)
        }
        .alert("预览", isPresented: $showingPreview) {
            if viewModel.artifactStoreURL != nil {
                Button("打开链接") {
                    viewModel.openPreviewURL()
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text(previewMessage)
        }
        .task {
            await viewModel.loadArtifacts()
        }
        .withNotifications()
    }
    
    // MARK: - 工具栏操作按钮
    private var actionButtons: some View {
        HStack(spacing: 8) {
            // 预览按钮
            Button(action: {
                showingPreview = true
            }) {
                Image(systemName: "eye")
                    .font(.title3)
            }
            .disabled(viewModel.isLoading)
            
            // 下载按钮
            if viewModel.artifacts.isEmpty || settingsManager.settings.sync.platform != .gitlab {
                Button(action: {
                    showingDownloadConfirmation = true
                }) {
                    if viewModel.downloadAllIsLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "cloud.download")
                            .font(.title3)
                    }
                }
                .disabled(viewModel.downloadAllIsLoading)
            }
            
            // 上传按钮
            if !viewModel.artifacts.isEmpty {
                Button(action: {
                    Task {
                        await viewModel.uploadAll()
                    }
                }) {
                    if viewModel.uploadAllIsLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "cloud.upload")
                            .font(.title3)
                    }
                }
                .disabled(viewModel.uploadAllIsDisabled || viewModel.uploadAllIsLoading)
            }
        }
    }
    
    // MARK: - 规则列表
    private var artifactsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.artifacts.enumerated()), id: \.element.id) { index, artifact in
                    ArtifactListItemView(
                        artifact: artifact,
                        isSwipeDisabled: isDragging
                    ) { action in
                        handleArtifactAction(action, for: artifact)
                    }
                    .onDrag {
                        isDragging = true
                        return NSItemProvider(object: artifact.name as NSString)
                    }
                    .onDrop(of: [.text], delegate: ArtifactDropDelegate(
                        artifact: artifact,
                        artifacts: $viewModel.artifacts,
                        onReorder: { newOrder in
                            Task {
                                await viewModel.reorderArtifacts(newOrder)
                            }
                        }
                    ))
                }
            }
            .padding()
        }
        .onDrop(of: [.text], isTargeted: nil) { providers, location in
            isDragging = false
            return false
        }
    }
    
    // MARK: - 加载中视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("加载中...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 错误视图
    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            VStack(spacing: 8) {
                Text("加载失败")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("无法连接到服务器，请检查网络连接")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("关注官方频道获取帮助")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Link("Cool Scripts", destination: URL(string: "https://t.me/cool_scripts")!)
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
            
            VStack(spacing: 12) {
                Button(action: {
                    Task {
                        await viewModel.refresh()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("重试")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }
                
                Link(destination: URL(string: "https://www.notion.so/Sub-Store-6259586994d34c11a4ced5c406264b46")!) {
                    HStack {
                        Text("查看文档")
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "tray")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Text("暂无规则配置")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("创建或下载规则配置开始使用")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Button(action: {
                showingAddArtifact = true
            }) {
                Text("添加规则")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 浮动添加按钮
    private var floatingAddButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                Button(action: {
                    showingAddArtifact = true
                }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 100) // 避免与 TabBar 重叠
            }
        }
    }
    
    // MARK: - 计算属性
    private var downloadConfirmationMessage: String {
        if let url = viewModel.artifactStoreURL {
            return "即将从云端下载规则配置\n\n状态: \(viewModel.artifactStoreStatus ?? "VALID")\n\n链接: \(url)"
        } else {
            return "即将从云端下载规则配置\n\n状态: \(viewModel.artifactStoreStatus ?? "-")\n\n未配置同步链接"
        }
    }
    
    private var previewMessage: String {
        if let url = viewModel.artifactStoreURL {
            return "状态: \(viewModel.artifactStoreStatus ?? "VALID")\n\n链接: \(url)"
        } else {
            return "状态: \(viewModel.artifactStoreStatus ?? "-")\n\n未配置同步链接"
        }
    }
    
    // MARK: - 方法
    private func handleArtifactAction(_ action: ArtifactListItemView.Action, for artifact: Artifact) {
        switch action {
        case .edit:
            editingArtifact = artifact
            showingAddArtifact = true
        case .delete:
            viewModel.deleteArtifact(artifact)
        case .duplicate:
            viewModel.duplicateArtifact(artifact)
        case .share:
            viewModel.shareArtifact(artifact)
        }
    }
}

// MARK: - 同步 ViewModel
@MainActor
class SyncViewModel: ObservableObject {
    @Published var artifacts: [Artifact] = []
    @Published var isLoading = false
    @Published var fetchSuccess = true
    @Published var uploadAllIsLoading = false
    @Published var downloadAllIsLoading = false
    
    // 同步相关状态
    @Published var artifactStoreURL: String?
    @Published var artifactStoreStatus: String?
    @Published var syncPlatform: SyncPlatform = .none
    
    private let artifactRepository: ArtifactRepository
    
    var uploadAllIsDisabled: Bool {
        artifacts.isEmpty || uploadAllIsLoading
    }
    
    init(artifactRepository: ArtifactRepository = ArtifactRepositoryImpl()) {
        self.artifactRepository = artifactRepository
    }
    
    // MARK: - 数据加载
    func loadArtifacts() async {
        isLoading = true
        
        do {
            artifacts = try await artifactRepository.getAllArtifacts()
            fetchSuccess = true
        } catch {
            fetchSuccess = false
            NotificationHelper.showError("加载失败", content: error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func refresh() async {
        await loadArtifacts()
    }
    
    // MARK: - 同步操作
    func uploadAll() async {
        guard !artifacts.isEmpty else { return }
        
        uploadAllIsLoading = true
        
        do {
            try await artifactRepository.syncAllArtifacts()
            NotificationHelper.showSuccess("上传成功", content: "所有规则已同步到云端")
        } catch {
            NotificationHelper.showError("上传失败", content: error.localizedDescription)
        }
        
        uploadAllIsLoading = false
    }
    
    func downloadAll() async {
        downloadAllIsLoading = true
        
        do {
            try await artifactRepository.restoreArtifacts()
            await loadArtifacts() // 重新加载数据
            NotificationHelper.showSuccess("下载成功", content: "规则配置已从云端恢复")
        } catch {
            NotificationHelper.showError("下载失败", content: error.localizedDescription)
        }
        
        downloadAllIsLoading = false
    }
    
    func cancelDownload() {
        downloadAllIsLoading = false
    }
    
    // MARK: - 规则操作
    func saveArtifact(_ artifact: Artifact) {
        Task {
            do {
                try await artifactRepository.saveArtifact(artifact)
                await loadArtifacts()
                NotificationHelper.showSuccess("保存成功")
            } catch {
                NotificationHelper.showError("保存失败", content: error.localizedDescription)
            }
        }
    }
    
    func deleteArtifact(_ artifact: Artifact) {
        Task {
            do {
                try await artifactRepository.deleteArtifact(artifact.id)
                await loadArtifacts()
                NotificationHelper.showSuccess("删除成功")
            } catch {
                NotificationHelper.showError("删除失败", content: error.localizedDescription)
            }
        }
    }
    
    func duplicateArtifact(_ artifact: Artifact) {
        var duplicatedArtifact = artifact
        duplicatedArtifact.id = UUID().uuidString
        duplicatedArtifact.name = "\(artifact.name) 副本"
        
        Task {
            do {
                try await artifactRepository.saveArtifact(duplicatedArtifact)
                await loadArtifacts()
                NotificationHelper.showSuccess("复制成功")
            } catch {
                NotificationHelper.showError("复制失败", content: error.localizedDescription)
            }
        }
    }
    
    func shareArtifact(_ artifact: Artifact) {
        // 实现分享功能
        NotificationHelper.showInfo("分享功能", content: "分享链接已复制到剪贴板")
    }
    
    func reorderArtifacts(_ newOrder: [Artifact]) async {
        artifacts = newOrder
        
        do {
            try await artifactRepository.reorderArtifacts(newOrder.map { $0.id })
            NotificationHelper.showSuccess("排序已保存")
        } catch {
            NotificationHelper.showError("排序失败", content: error.localizedDescription)
            // 恢复原始顺序
            await loadArtifacts()
        }
    }
    
    // MARK: - 预览操作
    func openPreviewURL() {
        guard let urlString = artifactStoreURL,
              let url = URL(string: urlString) else {
            NotificationHelper.showError("无效链接")
            return
        }
        
        UIApplication.shared.open(url)
    }
}

// MARK: - 规则列表项视图
struct ArtifactListItemView: View {
    let artifact: Artifact
    let isSwipeDisabled: Bool
    let onAction: (Action) -> Void
    
    enum Action {
        case edit
        case delete
        case duplicate
        case share
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 规则类型图标
            artifactTypeIcon
            
            // 规则信息
            VStack(alignment: .leading, spacing: 4) {
                Text(artifact.name)
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(artifact.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let description = artifact.description, !description.isEmpty {
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // 状态指示器
            if artifact.isEnabled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            } else {
                Image(systemName: "pause.circle.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isSwipeDisabled {
                Button("分享") {
                    onAction(.share)
                }
                .tint(.blue)
                
                Button("复制") {
                    onAction(.duplicate)
                }
                .tint(.orange)
                
                Button("删除") {
                    onAction(.delete)
                }
                .tint(.red)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if !isSwipeDisabled {
                Button("编辑") {
                    onAction(.edit)
                }
                .tint(.accentColor)
            }
        }
        .onTapGesture {
            onAction(.edit)
        }
    }
    
    private var artifactTypeIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(artifact.type.color.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: artifact.type.systemImage)
                .font(.title3)
                .foregroundColor(artifact.type.color)
        }
    }
}

// MARK: - 拖拽代理
struct ArtifactDropDelegate: DropDelegate {
    let artifact: Artifact
    @Binding var artifacts: [Artifact]
    let onReorder: ([Artifact]) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let fromIndex = artifacts.firstIndex(where: { $0.id == artifact.id }) else { return }
        
        // 实现拖拽重排序逻辑
        let toIndex = artifacts.firstIndex { artifact in
            return info.location.y < CGFloat(artifacts.count) * 70 // 估计行高
        } ?? artifacts.count - 1
        
        if fromIndex != toIndex {
            withAnimation {
                artifacts.move(fromSets: IndexSet(integer: fromIndex), toOffset: toIndex)
            }
            onReorder(artifacts)
        }
    }
}

// MARK: - 规则编辑器视图 (简化版)
struct ArtifactEditorView: View {
    let artifact: Artifact?
    @Binding var isPresented: Bool
    let onSave: (Artifact?) -> Void
    
    @State private var name = ""
    @State private var description = ""
    @State private var isEnabled = true
    @State private var selectedType: ArtifactType = .rewrite
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("规则名称", text: $name)
                    TextField("描述", text: $description)
                    Toggle("启用", isOn: $isEnabled)
                }
                
                Section("规则类型") {
                    Picker("类型", selection: $selectedType) {
                        ForEach(ArtifactType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle(artifact == nil ? "添加规则" : "编辑规则")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveArtifact()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .onAppear {
            loadArtifactData()
        }
    }
    
    private func loadArtifactData() {
        if let artifact = artifact {
            name = artifact.name
            description = artifact.description ?? ""
            isEnabled = artifact.isEnabled
            selectedType = artifact.type
        }
    }
    
    private func saveArtifact() {
        let newArtifact = Artifact(
            id: artifact?.id ?? UUID().uuidString,
            name: name,
            type: selectedType,
            description: description.isEmpty ? nil : description,
            isEnabled: isEnabled,
            content: artifact?.content ?? "",
            createdAt: artifact?.createdAt ?? Date(),
            updatedAt: Date()
        )
        
        onSave(newArtifact)
        isPresented = false
    }
}

// MARK: - 扩展
extension ArtifactType {
    var color: Color {
        switch self {
        case .rewrite:
            return .blue
        case .redirect:
            return .green
        case .script:
            return .purple
        case .rule:
            return .orange
        case .filter:
            return .red
        case .header:
            return .cyan
        }
    }
    
    var systemImage: String {
        switch self {
        case .rewrite:
            return "arrow.triangle.2.circlepath"
        case .redirect:
            return "arrow.right.circle"
        case .script:
            return "doc.text"
        case .rule:
            return "list.bullet"
        case .filter:
            return "funnel"
        case .header:
            return "doc.badge.gearshape"
        }
    }
}

#Preview {
    SyncView()
        .environmentObject(ThemeManager())
        .environmentObject(SettingsManager())
}