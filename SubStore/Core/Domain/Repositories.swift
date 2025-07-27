import Foundation
import Combine

// MARK: - Base Repository Protocol
protocol BaseRepositoryProtocol {
    associatedtype Entity
    
    func getAll() -> AnyPublisher<[Entity], Error>
    func getById(_ id: String) -> AnyPublisher<Entity?, Error>
    func create(_ entity: Entity) -> AnyPublisher<Entity, Error>
    func update(_ entity: Entity) -> AnyPublisher<Entity, Error>
    func delete(_ id: String) -> AnyPublisher<Bool, Error>
}

// MARK: - Subscription Repository Protocol
protocol SubscriptionRepositoryProtocol: BaseRepositoryProtocol where Entity == Subscription {
    func getSubscriptions() -> AnyPublisher<[Subscription], Error>
    func getCollections() -> AnyPublisher<[Subscription], Error>
    func getFlowInfo(for subscriptionID: String) -> AnyPublisher<FlowInfo?, Error>
    func updateFlowInfo(subscriptionID: String, flowInfo: FlowInfo) -> AnyPublisher<Bool, Error>
    func importSubscriptions(from url: URL) -> AnyPublisher<[Subscription], Error>
    func exportSubscriptions(_ subscriptions: [Subscription]) -> AnyPublisher<Data, Error>
    func testConnection(for subscription: Subscription) -> AnyPublisher<Bool, Error>
}

// MARK: - Artifact Repository Protocol
protocol ArtifactRepositoryProtocol: BaseRepositoryProtocol where Entity == Artifact {
    func getAll() -> AnyPublisher<[Artifact], Error>
    func getByID(_ id: String) -> AnyPublisher<Artifact?, Error>
    func create(_ artifact: Artifact) -> AnyPublisher<Artifact, Error>
    func update(_ artifact: Artifact) -> AnyPublisher<Artifact, Error>
    func delete(_ id: String) -> AnyPublisher<Bool, Error>
    func sync(_ artifact: Artifact, to provider: SyncProvider) -> AnyPublisher<SyncResult, Error>
    func fetchFromSync(_ syncConfig: SyncConfig) -> AnyPublisher<[Artifact], Error>
    func testArtifact(_ artifact: Artifact) -> AnyPublisher<ArtifactTestResult, Error>
    func validateContent(_ content: String, type: ArtifactType) -> AnyPublisher<ValidationResult, Error>
}

// MARK: - File Repository Protocol
protocol FileRepositoryProtocol: BaseRepositoryProtocol where Entity == SubStoreFile {
    func getFileContent(_ fileID: String) -> AnyPublisher<String, Error>
    func updateFileContent(fileID: String, content: String) -> AnyPublisher<Bool, Error>
    func validateFile(_ file: SubStoreFile) -> AnyPublisher<Bool, Error>
    func formatFile(_ file: SubStoreFile) -> AnyPublisher<String, Error>
}

// MARK: - Share Repository Protocol
protocol ShareRepositoryProtocol: BaseRepositoryProtocol where Entity == Share {
    func generateShareToken(for targetID: String, type: ShareType) -> AnyPublisher<String, Error>
    func validateShareToken(_ token: String) -> AnyPublisher<Bool, Error>
    func getSharedContent(token: String) -> AnyPublisher<Data, Error>
    func incrementAccessCount(token: String) -> AnyPublisher<Bool, Error>
}

// MARK: - Settings Repository Protocol
protocol SettingsRepositoryProtocol {
    func getSettings() -> AnyPublisher<AppSettings, Error>
    func updateSettings(_ settings: AppSettings) -> AnyPublisher<AppSettings, Error>
    func syncSettings(to platform: SyncPlatform, settings: AppSettings) -> AnyPublisher<Bool, Error>
    func downloadSettings(from platform: SyncPlatform) -> AnyPublisher<AppSettings, Error>
    func resetSettings() -> AnyPublisher<Bool, Error>
}

// MARK: - Use Case Protocols
protocol GetSubscriptionsUseCase {
    func execute() -> AnyPublisher<[Subscription], Error>
}

protocol CreateSubscriptionUseCase {
    func execute(subscription: Subscription) -> AnyPublisher<Subscription, Error>
}

protocol UpdateSubscriptionUseCase {
    func execute(subscription: Subscription) -> AnyPublisher<Subscription, Error>
}

protocol DeleteSubscriptionUseCase {
    func execute(subscriptionID: String) -> AnyPublisher<Bool, Error>
}

// MARK: - Artifact Use Cases
protocol GetArtifactsUseCase {
    func execute() -> AnyPublisher<[Artifact], Error>
}

protocol CreateArtifactUseCase {
    func execute(artifact: Artifact) -> AnyPublisher<Artifact, Error>
}

protocol UpdateArtifactUseCase {
    func execute(artifact: Artifact) -> AnyPublisher<Artifact, Error>
}

protocol DeleteArtifactUseCase {
    func execute(artifactID: String) -> AnyPublisher<Bool, Error>
}

protocol SyncArtifactUseCase {
    func execute(artifact: Artifact, to provider: SyncProvider) -> AnyPublisher<SyncResult, Error>
}

protocol SyncArtifactsUseCase {
    func execute() -> AnyPublisher<[Artifact], Error>
}

protocol ManageFilesUseCase {
    func createFile(_ file: SubStoreFile) -> AnyPublisher<SubStoreFile, Error>
    func updateFile(_ file: SubStoreFile) -> AnyPublisher<SubStoreFile, Error>
    func deleteFile(_ fileID: String) -> AnyPublisher<Bool, Error>
}

protocol ShareManagementUseCase {
    func createShare(targetID: String, type: ShareType, name: String) -> AnyPublisher<Share, Error>
    func deleteShare(_ shareID: String) -> AnyPublisher<Bool, Error>
    func getShareURL(_ shareID: String) -> AnyPublisher<String, Error>
}