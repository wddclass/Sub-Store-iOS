import SwiftUI

// MARK: - 文件列表视图
struct FilesListView: View {
    @StateObject private var viewModel = FilesViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索栏
                SearchBarView(searchText: $viewModel.searchText, placeholder: "搜索文件")
                    .padding()
                    .background(Color(.systemGray6))
                
                // 主内容区域
                if viewModel.isLoading {
                    LoadingView(message: "加载文件中...")
                } else if let errorMessage = viewModel.errorMessage {
                    ErrorView(error: errorMessage) {
                        viewModel.loadFiles()
                    }
                } else if viewModel.filteredFiles.isEmpty {
                    EmptyStateView(
                        title: "暂无文件",
                        description: "点击右上角的 + 按钮创建您的第一个文件",
                        systemImage: "doc",
                        action: {
                            viewModel.showingAddSheet = true
                        },
                        actionTitle: "创建文件"
                    )
                } else {
                    List {
                        ForEach(viewModel.filteredFiles) { file in
                            FileRowView(file: file, viewModel: viewModel)
                        }
                        .onDelete(perform: viewModel.deleteFiles)
                    }
                    .refreshable {
                        viewModel.refreshFiles()
                    }
                }
            }
            .navigationTitle("文件管理")
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
                FileEditorView(file: nil) { file in
                    viewModel.addFile(file)
                }
            }
            .sheet(item: $viewModel.editingFile) { file in
                FileEditorView(file: file) { updatedFile in
                    viewModel.updateFile(updatedFile)
                }
            }
        }
        .onAppear {
            viewModel.loadFiles()
        }
    }
}

// MARK: - 文件行视图
struct FileRowView: View {
    let file: SubStoreFile
    let viewModel: FilesViewModel
    @State private var showingDetail = false
    
    var body: some View {
        HStack(spacing: AppConstants.UI.Spacing.medium) {
            // 文件图标
            Image(systemName: file.type.icon)
                .font(.system(size: AppConstants.UI.Icon.medium))
                .foregroundColor(.accentColor)
                .frame(width: AppConstants.UI.Icon.large)
            
            // 文件信息
            VStack(alignment: .leading, spacing: AppConstants.UI.Spacing.tiny) {
                Text(file.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Text(file.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(file.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if file.isReadOnly {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("只读")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Text("更新于 \(file.updatedAt.relativeFormatted)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, AppConstants.UI.Spacing.small)
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetail = true
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !file.isReadOnly {
                Button("删除", role: .destructive) {
                    // 删除操作
                }
                
                Button("编辑") {
                    viewModel.editingFile = file
                }
                .tint(.blue)
            }
            
            Button("复制") {
                UIPasteboard.general.string = file.content
            }
            .tint(.green)
        }
        .sheet(isPresented: $showingDetail) {
            FileDetailView(file: file, viewModel: viewModel)
        }
    }
}

// MARK: - 文件编辑视图
struct FileEditorView: View {
    let file: SubStoreFile?
    let onSave: (SubStoreFile) -> Void
    
    @State private var name: String = ""
    @State private var type: FileType = .general
    @State private var content: String = ""
    @State private var language: String = ""
    @State private var tags: String = ""
    
    @Environment(\.dismiss) private var dismiss
    
    init(file: SubStoreFile?, onSave: @escaping (SubStoreFile) -> Void) {
        self.file = file
        self.onSave = onSave
        
        if let file = file {
            _name = State(initialValue: file.name)
            _type = State(initialValue: file.type)
            _content = State(initialValue: file.content)
            _language = State(initialValue: file.language ?? "")
            _tags = State(initialValue: file.tags.joined(separator: ", "))
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("文件名称", text: $name)
                    
                    Picker("文件类型", selection: $type) {
                        ForEach(FileType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    TextField("编程语言 (可选)", text: $language)
                    TextField("标签 (用逗号分隔)", text: $tags)
                }
                
                Section("文件内容") {
                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle(file == nil ? "创建文件" : "编辑文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveFile()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveFile() {
        let tagsArray = tags.components(separatedBy: ",").map { $0.trimmed }.filter { !$0.isEmpty }
        
        let newFile = SubStoreFile(
            id: file?.id ?? UUID().uuidString,
            name: name,
            type: type,
            content: content,
            size: Int64(content.utf8.count),
            language: language.isEmpty ? nil : language,
            tags: tagsArray,
            createdAt: file?.createdAt ?? Date(),
            updatedAt: Date(),
            isReadOnly: file?.isReadOnly ?? false
        )
        
        onSave(newFile)
        dismiss()
    }
}

// MARK: - 文件详情视图
struct FileDetailView: View {
    let file: SubStoreFile
    let viewModel: FilesViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("文件信息") {
                    DetailRowView(title: "名称", value: file.name)
                    DetailRowView(title: "类型", value: file.type.displayName)
                    DetailRowView(title: "大小", value: file.formattedSize)
                    
                    if let language = file.language {
                        DetailRowView(title: "语言", value: language)
                    }
                    
                    DetailRowView(title: "状态", value: file.isReadOnly ? "只读" : "可编辑")
                }
                
                if !file.tags.isEmpty {
                    Section("标签") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(file.tags, id: \.self) { tag in
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
                
                Section("时间信息") {
                    DetailRowView(title: "创建时间", value: file.createdAt.detailFormatted)
                    DetailRowView(title: "更新时间", value: file.updatedAt.detailFormatted)
                }
                
                Section("操作") {
                    Button("查看内容") {
                        // 显示内容
                    }
                    
                    if !file.isReadOnly {
                        Button("编辑文件") {
                            viewModel.editingFile = file
                            dismiss()
                        }
                    }
                    
                    Button("复制内容") {
                        UIPasteboard.general.string = file.content
                    }
                    
                    Button("分享文件") {
                        // 分享功能
                    }
                }
            }
            .navigationTitle(file.name)
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

// MARK: - 文件 ViewModel
@MainActor
class FilesViewModel: BaseViewModel {
    @Published var files: [SubStoreFile] = []
    @Published var filteredFiles: [SubStoreFile] = []
    @Published var searchText: String = ""
    @Published var showingAddSheet: Bool = false
    @Published var editingFile: SubStoreFile? = nil
    
    override init() {
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
    
    func loadFiles() {
        Task {
            await performAsyncTask { [weak self] in
                // 模拟加载文件
                let mockFiles = [
                    SubStoreFile(name: "配置文件.yaml", type: .yaml, content: "# 配置内容"),
                    SubStoreFile(name: "脚本.js", type: .javascript, content: "// JavaScript 代码"),
                    SubStoreFile(name: "数据.json", type: .json, content: "{}")
                ]
                self?.files = mockFiles
                Logger.shared.info("Loaded \(mockFiles.count) files")
            }
        }
    }
    
    func refreshFiles() {
        clearError()
        loadFiles()
    }
    
    func addFile(_ file: SubStoreFile) {
        files.append(file)
        Logger.shared.info("Added file: \(file.name)")
    }
    
    func updateFile(_ file: SubStoreFile) {
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index] = file
            Logger.shared.info("Updated file: \(file.name)")
        }
    }
    
    func deleteFiles(at offsets: IndexSet) {
        let filesToDelete = offsets.map { filteredFiles[$0] }
        
        for file in filesToDelete {
            files.removeAll { $0.id == file.id }
            Logger.shared.info("Deleted file: \(file.name)")
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