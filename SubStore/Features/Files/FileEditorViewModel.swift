import SwiftUI
import Combine

// MARK: - 文件编辑器 ViewModel
@MainActor
class FileEditorViewModel: BaseViewModel {
    @Published var form = FileEditorForm()
    @Published var previewData: FilePreviewData?
    @Published var savedFile: SubStoreFile?
    @Published var editingFile: SubStoreFile?
    
    private let fileRepository: any FileRepositoryProtocol
    private let subsRepository: any SubscriptionRepositoryProtocol
    
    var isValidForm: Bool {
        !form.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        validateName(form.name) &&
        (form.source != "remote" || validateURL(form.url))
    }
    
    var fileIcon: String {
        if !form.icon.isEmpty {
            return form.icon
        } else {
            switch form.type {
            case .mihomoProfile:
                return "https://example.com/clashmeta_icon.png" // Mihomo 图标
            default:
                return "https://example.com/default_icon.png" // 默认图标
            }
        }
    }
    
    init(fileRepository: any FileRepositoryProtocol,
         subsRepository: any SubscriptionRepositoryProtocol) {
        self.fileRepository = fileRepository
        self.subsRepository = subsRepository
        super.init()
    }
    
    // MARK: - 数据加载
    func loadFile(_ file: SubStoreFile) {
        editingFile = file
        form.name = file.name
        form.displayName = file.name
        form.remark = ""
        form.icon = ""
        form.isIconColor = true
        form.source = "local"
        form.type = file.type
        form.content = file.content
        form.download = true // 从 file 中获取
        
        // 根据文件类型设置其他属性
        if file.type == .mihomoProfile {
            form.sourceType = .collection // 从 file 中获取
            form.sourceName = "" // 从 file 中获取
        } else {
            form.url = "" // 从 file 中获取
            form.ua = "" // 从 file 中获取
        }
        
        form.subInfoUrl = ""
        form.subInfoUserAgent = ""
        form.proxy = ""
        form.mergeSources = ""
        form.ignoreFailedRemoteFile = "disabled"
    }
    
    func initializeNewFile() {
        form = FileEditorForm()
        
        // 根据创建类型设置默认内容
        if form.type == .mihomoProfile {
            form.content = """
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
        } else {
            form.content = "// " + "文件内容占位符" + "\\n"
        }
    }
    
    // MARK: - 表单验证
    func validateForm() -> Bool {
        clearError()
        
        // 名称验证
        guard !form.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError("名称不能为空")
            return false
        }
        
        guard validateName(form.name) else {
            showError("名称格式无效")
            return false
        }
        
        // URL 验证（远程文件）
        if form.source == "remote" {
            guard validateURL(form.url) else {
                showError("URL 格式无效")
                return false
            }
        }
        
        // 订阅名称验证（Mihomo Profile）
        if form.type == .mihomoProfile && form.sourceType != .none {
            guard !form.sourceName.isEmpty else {
                showError("请选择订阅")
                return false
            }
        }
        
        return true
    }
    
    private func validateName(_ name: String) -> Bool {
        // 检查是否为保留名称
        guard !["UNTITLED", "UNTITLED-mihomoProfile"].contains(name) else {
            return false
        }
        
        // 检查是否包含非法字符
        guard !name.contains("/") else {
            return false
        }
        
        return true
    }
    
    private func validateURL(_ url: String) -> Bool {
        if url.contains("\\n") {
            // 多行 URL 验证
            let urls = url.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            return urls.allSatisfy { urlString in
                isValidURLString(urlString)
            }
        } else {
            return isValidURLString(url)
        }
    }
    
    private func isValidURLString(_ urlString: String) -> Bool {
        // HTTP/HTTPS URL
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return URL(string: urlString) != nil
        }
        
        // API 路径
        if urlString.hasPrefix("/api/file/") || urlString.hasPrefix("/api/module/") {
            return true
        }
        
        // 相对路径
        if urlString.hasPrefix("/") {
            return true
        }
        
        return false
    }
    
    // MARK: - 文件操作
    func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            Task {
                await importFileContent(from: url)
            }
            
        case .failure(let error):
            NotificationHelper.showError("导入失败", content: error.localizedDescription)
        }
    }
    
    private func importFileContent(from url: URL) async {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                throw FileImportError.accessDenied
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let data = try Data(contentsOf: url)
            guard let content = String(data: data, encoding: .utf8) else {
                throw FileImportError.invalidEncoding
            }
            
            form.content = content
            NotificationHelper.showSuccess("导入成功", content: "文件内容已导入")
            
        } catch {
            NotificationHelper.showError("导入失败", content: error.localizedDescription)
        }
    }
    
    // MARK: - 预览生成
    func generatePreview() async {
        isLoading = true
        
        // 简化预览功能
        let fileData = createFileData()
        previewData = FilePreviewData(
            original: fileData.content,
            name: fileData.name,
            url: form.source == "remote" ? form.url : nil
        )
        NotificationHelper.showSuccess("预览生成成功")
        isLoading = false
    }
    
    // MARK: - 文件保存
    func saveFile() async -> Bool {
        guard validateForm() else {
            return false
        }
        
        isLoading = true
        
        // 创建 SubStoreFile 对象
        let fileToSave = SubStoreFile(
            id: editingFile?.id ?? UUID().uuidString,
            name: form.name,
            type: form.type,
            content: form.content,
            size: Int64(form.content.utf8.count),
            language: form.language,
            tags: form.tags.isEmpty ? [] : form.tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
            createdAt: editingFile?.createdAt ?? Date(),
            updatedAt: Date(),
            isReadOnly: false
        )
        
        // 使用 Publisher 方式保存
        var success = false
        if editingFile != nil {
            fileRepository.update(fileToSave)
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            self.savedFile = fileToSave
                            NotificationHelper.showSuccess("文件保存成功")
                            success = true
                        case .failure(let error):
                            NotificationHelper.showError("保存失败", content: error.localizedDescription)
                        }
                        self.isLoading = false
                    },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
        } else {
            fileRepository.create(fileToSave)
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            self.savedFile = fileToSave
                            NotificationHelper.showSuccess("文件创建成功")
                            success = true
                        case .failure(let error):
                            NotificationHelper.showError("创建失败", content: error.localizedDescription)
                        }
                        self.isLoading = false
                    },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
        }
        
        return success
    }
    
    private func createFileData() -> FileData {
        return FileData(
            id: UUID().uuidString,
            name: form.name,
            displayName: form.displayName.isEmpty ? nil : form.displayName,
            type: form.type,
            content: form.content,
            source: form.source,
            url: form.url.isEmpty ? nil : form.url,
            remark: form.remark.isEmpty ? nil : form.remark,
            icon: form.icon.isEmpty ? nil : form.icon,
            isIconColor: form.isIconColor,
            download: form.download,
            proxy: form.proxy.isEmpty ? nil : form.proxy,
            ua: form.ua.isEmpty ? nil : form.ua,
            mergeSources: form.mergeSources.isEmpty ? nil : form.mergeSources,
            ignoreFailedRemoteFile: form.ignoreFailedRemoteFile,
            subInfoUrl: form.subInfoUrl.isEmpty ? nil : form.subInfoUrl,
            subInfoUserAgent: form.subInfoUserAgent.isEmpty ? nil : form.subInfoUserAgent,
            sourceType: form.sourceType,
            sourceName: form.sourceName.isEmpty ? nil : form.sourceName,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

// MARK: - 文件编辑器表单
struct FileEditorForm {
    var name: String = ""
    var displayName: String = ""
    var remark: String = ""
    var icon: String = ""
    var isIconColor: Bool = true
    var source: String = "local"
    var type: FileType = .general
    var content: String = ""
    var download: Bool = true
    
    // 远程文件相关
    var url: String = ""
    var ua: String = ""
    var proxy: String = ""
    var mergeSources: String = ""
    var ignoreFailedRemoteFile: String = "disabled"
    
    // 订阅信息相关
    var subInfoUrl: String = ""
    var subInfoUserAgent: String = ""
    
    // Mihomo Profile 相关
    var sourceType: FileSource = .collection
    var sourceName: String = ""
    
    // 编辑器相关
    var language: String? = nil
    var tags: String = ""
}

// MARK: - 文件来源枚举
enum FileSource: String, CaseIterable {
    case subscription = "subscription"
    case collection = "collection"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .subscription:
            return "单条订阅"
        case .collection:
            return "组合订阅"
        case .none:
            return "无"
        }
    }
}

// MARK: - 文件导入错误
enum FileImportError: LocalizedError {
    case accessDenied
    case invalidEncoding
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "无法访问文件"
        case .invalidEncoding:
            return "文件编码无效"
        }
    }
}

// MARK: - 文件数据模型
struct FileData {
    let id: String
    let name: String
    let displayName: String?
    let type: FileType
    let content: String
    let source: String
    let url: String?
    let remark: String?
    let icon: String?
    let isIconColor: Bool
    let download: Bool
    let proxy: String?
    let ua: String?
    let mergeSources: String?
    let ignoreFailedRemoteFile: String
    let subInfoUrl: String?
    let subInfoUserAgent: String?
    let sourceType: FileSource
    let sourceName: String?
    let createdAt: Date
    let updatedAt: Date
}