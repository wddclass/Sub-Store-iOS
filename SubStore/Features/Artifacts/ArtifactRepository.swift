import Foundation
import Combine

// MARK: - Artifact Repository Implementation
class ArtifactRepository: ArtifactRepositoryProtocol {
    private let networkService: NetworkServiceProtocol
    private let coreDataService: CoreDataServiceProtocol
    
    init(networkService: NetworkServiceProtocol = NetworkService(), 
         coreDataService: CoreDataServiceProtocol = CoreDataService()) {
        self.networkService = networkService
        self.coreDataService = coreDataService
    }
    
    func getAll() -> AnyPublisher<[Artifact], Error> {
        // 先从本地获取数据
        let localArtifacts = coreDataService.fetchArtifacts()
        
        // 然后从网络同步
        return networkService.request(.getArtifacts)
            .catch { [weak self] error -> AnyPublisher<[Artifact], Error> in
                Logger.shared.warning("Failed to fetch artifacts from network: \(error)")
                // 网络失败时返回本地数据
                return Just(localArtifacts)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
            .map { [weak self] networkArtifacts in
                // 保存到本地
                self?.coreDataService.saveArtifacts(networkArtifacts)
                return networkArtifacts
            }
            .eraseToAnyPublisher()
    }
    
    func getByID(_ id: String) -> AnyPublisher<Artifact?, Error> {
        // 先从本地查找
        if let localArtifact = coreDataService.fetchArtifact(by: id) {
            return Just(localArtifact)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // 本地没有则从网络获取
        return networkService.request(.getArtifact(id))
            .map { [weak self] artifact in
                self?.coreDataService.saveArtifact(artifact)
                return artifact
            }
            .eraseToAnyPublisher()
    }
    
    func create(_ artifact: Artifact) -> AnyPublisher<Artifact, Error> {
        return networkService.request(.createArtifact(artifact))
            .map { [weak self] createdArtifact in
                self?.coreDataService.saveArtifact(createdArtifact)
                return createdArtifact
            }
            .eraseToAnyPublisher()
    }
    
    func update(_ artifact: Artifact) -> AnyPublisher<Artifact, Error> {
        return networkService.request(.updateArtifact(artifact))
            .map { [weak self] updatedArtifact in
                self?.coreDataService.saveArtifact(updatedArtifact)
                return updatedArtifact
            }
            .eraseToAnyPublisher()
    }
    
    func delete(_ id: String) -> AnyPublisher<Bool, Error> {
        return networkService.request(.deleteArtifact(id))
            .map { [weak self] success in
                if success {
                    self?.coreDataService.deleteArtifact(by: id)
                }
                return success
            }
            .eraseToAnyPublisher()
    }
    
    func sync(_ artifact: Artifact, to provider: SyncProvider) -> AnyPublisher<SyncResult, Error> {
        return networkService.request(.syncArtifact(artifact, provider))
            .map { syncResult in
                Logger.shared.info("Synced artifact \(artifact.name) to \(provider)")
                return syncResult
            }
            .eraseToAnyPublisher()
    }
    
    func fetchFromSync(_ syncConfig: SyncConfig) -> AnyPublisher<[Artifact], Error> {
        return networkService.request(.fetchFromSync(syncConfig))
            .map { [weak self] artifacts in
                // 保存同步获取的规则
                self?.coreDataService.saveArtifacts(artifacts)
                return artifacts
            }
            .eraseToAnyPublisher()
    }
    
    func testArtifact(_ artifact: Artifact) -> AnyPublisher<ArtifactTestResult, Error> {
        return networkService.request(.testArtifact(artifact))
            .eraseToAnyPublisher()
    }
    
    func validateContent(_ content: String, type: ArtifactType) -> AnyPublisher<ValidationResult, Error> {
        return networkService.request(.validateArtifactContent(content, type))
            .eraseToAnyPublisher()
    }
}

// MARK: - Artifact Use Cases
class GetArtifactsUseCaseImpl: GetArtifactsUseCase {
    private let repository: ArtifactRepositoryProtocol
    
    init(repository: ArtifactRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute() -> AnyPublisher<[Artifact], Error> {
        return repository.getAll()
    }
}

class CreateArtifactUseCaseImpl: CreateArtifactUseCase {
    private let repository: ArtifactRepositoryProtocol
    
    init(repository: ArtifactRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(artifact: Artifact) -> AnyPublisher<Artifact, Error> {
        return repository.create(artifact)
    }
}

class UpdateArtifactUseCaseImpl: UpdateArtifactUseCase {
    private let repository: ArtifactRepositoryProtocol
    
    init(repository: ArtifactRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(artifact: Artifact) -> AnyPublisher<Artifact, Error> {
        return repository.update(artifact)
    }
}

class DeleteArtifactUseCaseImpl: DeleteArtifactUseCase {
    private let repository: ArtifactRepositoryProtocol
    
    init(repository: ArtifactRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(artifactID: String) -> AnyPublisher<Bool, Error> {
        return repository.delete(artifactID)
    }
}

class SyncArtifactUseCaseImpl: SyncArtifactUseCase {
    private let repository: ArtifactRepositoryProtocol
    
    init(repository: ArtifactRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(artifact: Artifact, to provider: SyncProvider) -> AnyPublisher<SyncResult, Error> {
        return repository.sync(artifact, to: provider)
    }
}

// MARK: - Sync Related Models
enum SyncProvider: String, CaseIterable, Codable {
    case githubGist = "github_gist"
    case gitlabSnippet = "gitlab_snippet"
    
    var displayName: String {
        switch self {
        case .githubGist:
            return "GitHub Gist"
        case .gitlabSnippet:
            return "GitLab Snippet"
        }
    }
    
    var iconName: String {
        switch self {
        case .githubGist:
            return "github"
        case .gitlabSnippet:
            return "gitlab"
        }
    }
}

struct SyncConfig: Codable, Identifiable {
    let id: String
    let provider: SyncProvider
    let token: String
    let repositoryURL: String?
    let isEnabled: Bool
    let lastSync: Date?
    let syncInterval: TimeInterval // 自动同步间隔（秒）
    
    init(
        id: String = UUID().uuidString,
        provider: SyncProvider,
        token: String,
        repositoryURL: String? = nil,
        isEnabled: Bool = true,
        lastSync: Date? = nil,
        syncInterval: TimeInterval = 3600 // 默认1小时
    ) {
        self.id = id
        self.provider = provider
        self.token = token
        self.repositoryURL = repositoryURL
        self.isEnabled = isEnabled
        self.lastSync = lastSync
        self.syncInterval = syncInterval
    }
}

struct SyncResult: Codable {
    let success: Bool
    let syncedArtifacts: [String] // artifact IDs
    let conflicts: [SyncConflict]
    let message: String?
    let syncTime: Date
    
    init(success: Bool, syncedArtifacts: [String] = [], conflicts: [SyncConflict] = [], message: String? = nil) {
        self.success = success
        self.syncedArtifacts = syncedArtifacts
        self.conflicts = conflicts
        self.message = message
        self.syncTime = Date()
    }
}

struct SyncConflict: Codable, Identifiable {
    let id: String
    let artifactID: String
    let conflictType: ConflictType
    let localVersion: String
    let remoteVersion: String
    let description: String
    
    enum ConflictType: String, Codable, CaseIterable {
        case contentDifference = "content_difference"
        case deletionConflict = "deletion_conflict"
        case creationConflict = "creation_conflict"
        
        var displayName: String {
            switch self {
            case .contentDifference:
                return "内容冲突"
            case .deletionConflict:
                return "删除冲突"
            case .creationConflict:
                return "创建冲突"
            }
        }
    }
}

struct ArtifactTestResult: Codable {
    let success: Bool
    let message: String
    let errors: [String]
    let warnings: [String]
    let performance: TestPerformance?
    let testTime: Date
    
    init(success: Bool, message: String, errors: [String] = [], warnings: [String] = [], performance: TestPerformance? = nil) {
        self.success = success
        self.message = message
        self.errors = errors
        self.warnings = warnings
        self.performance = performance
        self.testTime = Date()
    }
}

struct TestPerformance: Codable {
    let executionTime: TimeInterval // 执行时间（毫秒）
    let memoryUsage: Int64 // 内存使用（字节）
    let ruleCount: Int // 规则数量
    let complexity: ComplexityLevel
    
    enum ComplexityLevel: String, Codable, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case extreme = "extreme"
        
        var displayName: String {
            switch self {
            case .low: return "低"
            case .medium: return "中"
            case .high: return "高"
            case .extreme: return "极高"
            }
        }
        
        var color: String {
            switch self {
            case .low: return "green"
            case .medium: return "yellow"
            case .high: return "orange"
            case .extreme: return "red"
            }
        }
    }
}

struct ValidationResult: Codable {
    let isValid: Bool
    let errors: [ValidationError]
    let warnings: [ValidationWarning]
    let suggestions: [String]
    
    init(isValid: Bool, errors: [ValidationError] = [], warnings: [ValidationWarning] = [], suggestions: [String] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
        self.suggestions = suggestions
    }
}

struct ValidationError: Codable, Identifiable {
    let id: String
    let line: Int?
    let column: Int?
    let message: String
    let severity: Severity
    
    enum Severity: String, Codable, CaseIterable {
        case error = "error"
        case warning = "warning"
        case info = "info"
        
        var displayName: String {
            switch self {
            case .error: return "错误"
            case .warning: return "警告"
            case .info: return "信息"
            }
        }
    }
    
    init(id: String = UUID().uuidString, line: Int? = nil, column: Int? = nil, message: String, severity: Severity = .error) {
        self.id = id
        self.line = line
        self.column = column
        self.message = message
        self.severity = severity
    }
}

struct ValidationWarning: Codable, Identifiable {
    let id: String
    let line: Int?
    let column: Int?
    let message: String
    let suggestion: String?
    
    init(id: String = UUID().uuidString, line: Int? = nil, column: Int? = nil, message: String, suggestion: String? = nil) {
        self.id = id
        self.line = line
        self.column = column
        self.message = message
        self.suggestion = suggestion
    }
}