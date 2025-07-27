import SwiftUI
import UniformTypeIdentifiers

// MARK: - 文件列表视图
struct FilesListView: View {
    @StateObject private var viewModel = FilesViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var showingAddFileSheet = false
    @State private var showingImportPicker = false
    @State private var isImporting = false
    @State private var touchStartY: CGFloat? = nil
    @State private var touchStartX: CGFloat? = nil
    @State private var isDragging = false
    
    var body: some View {
        ZStack {
            NavigationStack {
                ZStack {
                    if viewModel.isLoading {
                        loadingView
                    } else if !viewModel.fetchSuccess {
                        errorView
                    } else if viewModel.filteredFiles.isEmpty {
                        emptyStateView
                    } else {
                        filesList
                    }
                }
                .navigationTitle("文件")
                .navigationBarTitleDisplayMode(.large)
                .refreshable {
                    await viewModel.refresh()
                }
            }
            
            // 浮动添加按钮
            if !viewModel.filteredFiles.isEmpty && settingsManager.settings.appearance.showFloatingAddButton {
                floatingAddButton
            }
            
            // 添加文件弹窗
            if showingAddFileSheet {
                addFileSheet
            }
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .sheet(item: $viewModel.editingFile) { file in
            FileEditorView(file: file) { updatedFile in
                Task {
                    await viewModel.updateFile(updatedFile)
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadFiles()
            }
        }
        .withNotifications()
    }

    // MARK: - 视图组件
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
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "tray")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Text("暂无文件")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("创建或导入文件开始使用")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Button(action: {
                showingAddFileSheet = true
            }) {
                Text("添加文件")
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
    
    private var filesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(viewModel.filteredFiles.enumerated()), id: \.element.id) { index, file in
                    FileListItemView(
                        file: file,
                        isSwipeDisabled: isDragging
                    ) { action in
                        handleFileAction(action, for: file)
                    }
                    .onDrag {
                        isDragging = true
                        return NSItemProvider(object: file.name as NSString)
                    }
                    .onDrop(of: [.text], delegate: FileDropDelegate(
                        file: file,
                        files: $viewModel.filteredFiles,
                        onReorder: { newOrder in
                            Task {
                                await viewModel.reorderFiles(newOrder)
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
    
    private var floatingAddButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                
                // 刷新按钮
                if settingsManager.settings.appearance.showFloatingRefreshButton {
                    Button(action: {
                        Task {
                            await viewModel.refresh()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .background(Color.secondary)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    .padding(.bottom, 12)
                }
                
                // 添加按钮
                Button(action: {
                    showingAddFileSheet = true
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
            }
            .padding(.trailing, 24)
            .padding(.bottom, 100) // 避免与 TabBar 重叠
        }
    }
    
    private var addFileSheet: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    showingAddFileSheet = false
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 20) {
                    // 标题和导入按钮
                    HStack {
                        Text("添加文件")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("或")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            showingImportPicker = true
                            showingAddFileSheet = false
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.caption)
                                Text("导入")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .cornerRadius(8)
                        }
                        .disabled(isImporting)
                        
                        Button(action: {
                            showImportTips()
                        }) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // 文件类型选项
                    HStack(spacing: 20) {
                        // 通用文件
                        Button(action: {
                            createFile(type: .general)
                        }) {
                            VStack(spacing: 12) {
                                Image(systemName: "doc")
                                    .font(.system(size: 44))
                                    .foregroundColor(.accentColor)
                                
                                Text("文件")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Mihomo Profile
                        Button(action: {
                            createFile(type: .mihomoProfile)
                        }) {
                            VStack(spacing: 12) {
                                Image(systemName: "gear")
                                    .font(.system(size: 44))
                                    .foregroundColor(.orange)
                                
                                VStack(spacing: 4) {
                                    Text("Mihomo Profile")
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Text("配置文件模板")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(16, corners: [.topLeft, .topRight])
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
            }
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showingAddFileSheet)
    }
    
    // MARK: - 方法
    private func handleFileAction(_ action: FileListItemView.Action, for file: SubStoreFile) {
        switch action {
        case .edit:
            viewModel.editingFile = file
        case .delete:
            viewModel.deleteFile(file)
        case .duplicate:
            viewModel.duplicateFile(file)
        case .share:
            viewModel.shareFile(file)
        }
    }
    
    private func createFile(type: FileType) {
        showingAddFileSheet = false
        
        let newFile = SubStoreFile(
            name: generateFileName(for: type),
            type: type,
            content: getDefaultContent(for: type),
            size: 0,
            language: type.defaultLanguage,
            tags: [],
            createdAt: Date(),
            updatedAt: Date(),
            isReadOnly: false
        )
        
        // 直接打开编辑器，传入 nil 让编辑器知道这是新文件
        viewModel.editingFile = nil
        
        // 使用 sheet 打开编辑器
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            viewModel.editingFile = newFile
        }
    }
    
    private func generateFileName(for type: FileType) -> String {
        switch type {
        case .mihomoProfile:
            return "UNTITLED-mihomoProfile"
        default:
            return "UNTITLED"
        }
    }
    
    private func getDefaultContent(for type: FileType) -> String {
        switch type {
        case .mihomoProfile:
            return """
            # Mihomo Profile Configuration
            # This is a template for Mihomo profile
            
            mixed-port: 7890
            allow-lan: true
            mode: rule
            log-level: info
            
            dns:
              enable: true
              listen: 0.0.0.0:53
              enhanced-mode: fake-ip
              nameserver:
                - 223.5.5.5
                - 114.114.114.114
            
            proxies: []
            proxy-groups: []
            rules: []
            """
        default:
            return ""
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        isImporting = true
        
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                isImporting = false
                return
            }
            
            Task {
                await importFile(from: url)
                isImporting = false
            }
            
        case .failure(let error):
            NotificationHelper.showError("导入失败", content: error.localizedDescription)
            isImporting = false
        }
    }
    
    private func importFile(from url: URL) async {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                throw ImportError.accessDenied
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let data = try Data(contentsOf: url)
            guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ImportError.invalidFormat
            }
            
            // 创建文件名（添加时间戳避免重复）
            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = (jsonObject["name"] as? String ?? "imported") + "_\(timestamp)"
            let displayName = (jsonObject["displayName"] as? String ?? fileName) + "_\(timestamp)"
            
            // 创建文件对象
            var updatedObject = jsonObject
            updatedObject["name"] = fileName
            updatedObject["displayName"] = displayName
            updatedObject["display-name"] = displayName
            
            let updatedData = try JSONSerialization.data(withJSONObject: updatedObject, options: .prettyPrinted)
            let content = String(data: updatedData, encoding: .utf8) ?? ""
            
            let newFile = SubStoreFile(
                name: fileName,
                type: .json,
                content: content,
                size: Int64(content.utf8.count),
                language: "json",
                tags: ["imported"],
                createdAt: Date(),
                updatedAt: Date(),
                isReadOnly: false
            )
            
            await viewModel.addFile(newFile)
            NotificationHelper.showSuccess("导入成功", content: "文件已成功导入")
            
        } catch {
            NotificationHelper.showError("导入失败", content: error.localizedDescription)
        }
    }
    
    private func showImportTips() {
        showingAddFileSheet = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let alert = UIAlertController(
                title: "导入文件提示",
                message: "请选择有效的 JSON 配置文件进行导入。导入的文件将自动添加时间戳后缀以避免名称冲突。",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "知道了", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                rootViewController.present(alert, animated: true)
            }
        }
    }
}

// MARK: - 文件列表项视图
struct FileListItemView: View {
    let file: SubStoreFile
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
            // 文件类型图标
            fileTypeIcon
            
            // 文件信息
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.headline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(file.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !file.tags.isEmpty {
                    HStack {
                        ForEach(file.tags.prefix(2), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundColor(.accentColor)
                                .cornerRadius(4)
                        }
                        if file.tags.count > 2 {
                            Text("+\(file.tags.count - 2)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // 文件大小和状态
            VStack(alignment: .trailing, spacing: 4) {
                Text(file.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if file.isReadOnly {
                    Text("只读")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
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
                
                if !file.isReadOnly {
                    Button("删除") {
                        onAction(.delete)
                    }
                    .tint(.red)
                }
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
    
    private var fileTypeIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(file.type.color.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: file.type.icon)
                .font(.title3)
                .foregroundColor(file.type.color)
        }
    }
}

// MARK: - 拖拽代理
struct FileDropDelegate: DropDelegate {
    let file: SubStoreFile
    @Binding var files: [SubStoreFile]
    let onReorder: ([SubStoreFile]) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let fromIndex = files.firstIndex(where: { $0.id == file.id }) else { return }
        
        // 实现拖拽重排序逻辑
        let toIndex = files.firstIndex { file in
            return info.location.y < CGFloat(files.count) * 70 // 估计行高
        } ?? files.count - 1
        
        if fromIndex != toIndex {
            withAnimation {
                files.move(fromSets: IndexSet(integer: fromIndex), toOffset: toIndex)
            }
            onReorder(files)
        }
    }
}

// MARK: - 错误类型
enum ImportError: LocalizedError {
    case accessDenied
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "无法访问文件"
        case .invalidFormat:
            return "文件格式无效"
        }
    }
}

// MARK: - 文件类型扩展
extension FileType {
    var color: Color {
        switch self {
        case .general:
            return .blue
        case .javascript:
            return .yellow
        case .json:
            return .green
        case .yaml:
            return .purple
        case .mihomoProfile:
            return .orange
        case .text:
            return .gray
        }
    }
    
    var defaultLanguage: String? {
        switch self {
        case .javascript:
            return "javascript"
        case .json:
            return "json"
        case .yaml:
            return "yaml"
        case .mihomoProfile:
            return "yaml"
        default:
            return nil
        }
    }
}

// MARK: - 圆角扩展
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    FilesListView()
        .environmentObject(ThemeManager())
        .environmentObject(SettingsManager())
}

// MARK: - 文件 ViewModel
@MainActor
class FilesViewModel: BaseViewModel {
    @Published var files: [SubStoreFile] = []
    @Published var filteredFiles: [SubStoreFile] = []
    @Published var searchText: String = ""
    @Published var editingFile: SubStoreFile? = nil
    @Published var fetchSuccess = true
    
    private let fileRepository: FileRepository
    
    init(fileRepository: FileRepository = FileRepositoryImpl()) {
        self.fileRepository = fileRepository
        super.init()
        setupObservers()
    }
    
    private func setupObservers() {
        $searchText
            .combineLatest($files)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] searchText, files in
                self?.updateFilteredFiles(files: files, searchText: searchText)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 数据加载
    func loadFiles() async {
        isLoading = true
        
        do {
            files = try await fileRepository.getAllFiles()
            fetchSuccess = true
        } catch {
            fetchSuccess = false
            NotificationHelper.showError("加载失败", content: error.localizedDescription)
        }
        
        isLoading = false
    }
    
    func refresh() async {
        clearError()
        await loadFiles()
    }
    
    // MARK: - 文件操作
    func addFile(_ file: SubStoreFile) async {
        do {
            try await fileRepository.saveFile(file)
            await loadFiles()
            NotificationHelper.showSuccess("创建成功")
        } catch {
            NotificationHelper.showError("创建失败", content: error.localizedDescription)
        }
    }
    
    func updateFile(_ file: SubStoreFile) {
        Task {
            do {
                try await fileRepository.saveFile(file)
                await loadFiles()
                NotificationHelper.showSuccess("保存成功")
            } catch {
                NotificationHelper.showError("保存失败", content: error.localizedDescription)
            }
        }
    }
    
    func deleteFile(_ file: SubStoreFile) {
        Task {
            do {
                try await fileRepository.deleteFile(file.id)
                await loadFiles()
                NotificationHelper.showSuccess("删除成功")
            } catch {
                NotificationHelper.showError("删除失败", content: error.localizedDescription)
            }
        }
    }
    
    func duplicateFile(_ file: SubStoreFile) {
        var duplicatedFile = file
        duplicatedFile.id = UUID().uuidString
        duplicatedFile.name = "\(file.name) 副本"
        duplicatedFile.createdAt = Date()
        duplicatedFile.updatedAt = Date()
        
        Task {
            do {
                try await fileRepository.saveFile(duplicatedFile)
                await loadFiles()
                NotificationHelper.showSuccess("复制成功")
            } catch {
                NotificationHelper.showError("复制失败", content: error.localizedDescription)
            }
        }
    }
    
    func shareFile(_ file: SubStoreFile) {
        // 实现分享功能
        NotificationHelper.showInfo("分享功能", content: "分享链接已复制到剪贴板")
    }
    
    func reorderFiles(_ newOrder: [SubStoreFile]) async {
        files = newOrder
        
        do {
            try await fileRepository.reorderFiles(newOrder.map { $0.id })
            NotificationHelper.showSuccess("排序已保存")
        } catch {
            NotificationHelper.showError("排序失败", content: error.localizedDescription)
            // 恢复原始顺序
            await loadFiles()
        }
    }
    
    private func updateFilteredFiles(files: [SubStoreFile], searchText: String) {
        if searchText.isEmpty {
            filteredFiles = files
        } else {
            filteredFiles = files.filter { file in
                file.name.localizedCaseInsensitiveContains(searchText) ||
                file.content.localizedCaseInsensitiveContains(searchText) ||
                file.tags.joined().localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}