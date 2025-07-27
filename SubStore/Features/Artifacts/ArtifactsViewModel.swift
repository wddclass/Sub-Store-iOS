import Foundation
import Combine
import SwiftUI

// MARK: - Artifacts ViewModel
@MainActor
class ArtifactsViewModel: BaseViewModel {
    // MARK: - Published Properties
    @Published var artifacts: [Artifact] = []
    @Published var filteredArtifacts: [Artifact] = []
    @Published var searchText: String = ""
    @Published var selectedType: ArtifactType? = nil
    @Published var showingAddSheet: Bool = false
    @Published var showingSyncSheet: Bool = false
    @Published var editingArtifact: Artifact? = nil
    @Published var selectedArtifacts: Set<String> = []
    
    // Sync related
    @Published var syncConfigs: [SyncConfig] = []
    @Published var lastSyncTime: Date? = nil
    @Published var syncInProgress: Bool = false
    @Published var syncResults: [SyncResult] = []
    
    // Testing and Validation
    @Published var testResults: [String: ArtifactTestResult] = [:]
    @Published var validationResults: [String: ValidationResult] = [:]
    
    // MARK: - Private Properties
    private let getArtifactsUseCase: GetArtifactsUseCase
    private let createArtifactUseCase: CreateArtifactUseCase
    private let updateArtifactUseCase: UpdateArtifactUseCase
    private let deleteArtifactUseCase: DeleteArtifactUseCase
    private let syncArtifactUseCase: SyncArtifactUseCase
    private let repository: ArtifactRepositoryProtocol
    
    private var syncTimer: Timer?
    
    // MARK: - Initialization
    init(
        getArtifactsUseCase: GetArtifactsUseCase? = nil,
        createArtifactUseCase: CreateArtifactUseCase? = nil,
        updateArtifactUseCase: UpdateArtifactUseCase? = nil,
        deleteArtifactUseCase: DeleteArtifactUseCase? = nil,
        syncArtifactUseCase: SyncArtifactUseCase? = nil,
        repository: ArtifactRepositoryProtocol? = nil
    ) {
        let defaultRepository = repository ?? ArtifactRepository()
        
        self.repository = defaultRepository
        self.getArtifactsUseCase = getArtifactsUseCase ?? GetArtifactsUseCaseImpl(repository: defaultRepository)
        self.createArtifactUseCase = createArtifactUseCase ?? CreateArtifactUseCaseImpl(repository: defaultRepository)
        self.updateArtifactUseCase = updateArtifactUseCase ?? UpdateArtifactUseCaseImpl(repository: defaultRepository)
        self.deleteArtifactUseCase = deleteArtifactUseCase ?? DeleteArtifactUseCaseImpl(repository: defaultRepository)
        self.syncArtifactUseCase = syncArtifactUseCase ?? SyncArtifactUseCaseImpl(repository: defaultRepository)
        
        super.init()
        
        setupObservers()
        startAutoSync()
        loadSyncConfigs()
    }
    
    deinit {
        syncTimer?.invalidate()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // 监听搜索和筛选条件变化
        Publishers.CombineLatest3($artifacts, $searchText, $selectedType)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] artifacts, searchText, selectedType in
                self?.updateFilteredArtifacts(artifacts: artifacts, searchText: searchText, selectedType: selectedType)
            }
            .store(in: &cancellables)
    }
    
    private func startAutoSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.autoSyncArtifacts()
            }
        }
    }
    
    // MARK: - Public Methods
    func loadArtifacts() {
        Task {
            await performAsyncTask { [weak self] in
                guard let self = self else { return }
                
                let artifacts = try await self.getArtifactsUseCase.execute().async()
                self.artifacts = artifacts
                
                Logger.shared.info("Loaded \(artifacts.count) artifacts")
            }
        }
    }
    
    func refreshArtifacts() {
        clearError()
        loadArtifacts()
    }
    
    func addArtifact(_ artifact: Artifact) {
        Task {
            await performAsyncTask { [weak self] in
                guard let self = self else { return }
                
                let newArtifact = try await self.createArtifactUseCase.execute(artifact: artifact).async()
                self.artifacts.append(newArtifact)
                
                Logger.shared.info("Added artifact: \(newArtifact.name)")
            }
        }
    }
    
    func updateArtifact(_ artifact: Artifact) {
        Task {
            await performAsyncTask { [weak self] in
                guard let self = self else { return }
                
                let updatedArtifact = try await self.updateArtifactUseCase.execute(artifact: artifact).async()
                
                if let index = self.artifacts.firstIndex(where: { $0.id == updatedArtifact.id }) {
                    self.artifacts[index] = updatedArtifact
                }
                
                Logger.shared.info("Updated artifact: \(updatedArtifact.name)")
            }
        }
    }
    
    func deleteArtifacts(at offsets: IndexSet) {
        let artifactsToDelete = offsets.map { filteredArtifacts[$0] }
        
        Task {
            for artifact in artifactsToDelete {
                await performAsyncTask { [weak self] in
                    guard let self = self else { return }
                    
                    let success = try await self.deleteArtifactUseCase.execute(artifactID: artifact.id).async()
                    
                    if success {
                        self.artifacts.removeAll { $0.id == artifact.id }
                        Logger.shared.info("Deleted artifact: \(artifact.name)")
                    } else {
                        throw AppError.unknownError("Failed to delete artifact")
                    }
                }
            }
        }
    }
    
    func testArtifact(_ artifact: Artifact) {
        Task {
            await performAsyncTask { [weak self] in
                guard let self = self else { return }
                
                let testResult = try await self.repository.testArtifact(artifact).async()
                self.testResults[artifact.id] = testResult
                
                if testResult.success {
                    Logger.shared.info("Artifact test successful: \(artifact.name)")
                } else {
                    Logger.shared.warning("Artifact test failed: \(artifact.name) - \(testResult.message)")
                }
            }
        }
    }
    
    func validateArtifactContent(_ content: String, type: ArtifactType) {
        Task {
            await performAsyncTask { [weak self] in
                guard let self = self else { return }
                
                let validationResult = try await self.repository.validateContent(content, type: type).async()
                // 这里可以存储验证结果或直接返回给UI
                
                Logger.shared.info("Content validation completed: \(validationResult.isValid ? "Valid" : "Invalid")")
            }
        }
    }
    
    // MARK: - Sync Methods
    func loadSyncConfigs() {
        // 从 UserDefaults 或 Core Data 加载同步配置
        if let data = UserDefaults.standard.data(forKey: "ArtifactSyncConfigs"),
           let configs = try? JSONDecoder().decode([SyncConfig].self, from: data) {
            syncConfigs = configs
        }
    }
    
    func saveSyncConfigs() {
        if let data = try? JSONEncoder().encode(syncConfigs) {
            UserDefaults.standard.set(data, forKey: "ArtifactSyncConfigs")
        }
    }
    
    func addSyncConfig(_ config: SyncConfig) {
        syncConfigs.append(config)
        saveSyncConfigs()
        Logger.shared.info("Added sync config for \(config.provider.displayName)")
    }
    
    func updateSyncConfig(_ config: SyncConfig) {
        if let index = syncConfigs.firstIndex(where: { $0.id == config.id }) {
            syncConfigs[index] = config
            saveSyncConfigs()
            Logger.shared.info("Updated sync config for \(config.provider.displayName)")
        }
    }
    
    func deleteSyncConfig(_ configID: String) {
        syncConfigs.removeAll { $0.id == configID }
        saveSyncConfigs()
        Logger.shared.info("Deleted sync config")
    }
    
    func syncToProvider(_ artifact: Artifact, provider: SyncProvider) {
        guard let config = syncConfigs.first(where: { $0.provider == provider && $0.isEnabled }) else {
            showError("未找到 \(provider.displayName) 的同步配置")
            return
        }
        
        Task {
            await performAsyncTask { [weak self] in
                guard let self = self else { return }
                
                self.syncInProgress = true
                
                let result = try await self.syncArtifactUseCase.execute(artifact: artifact, to: provider).async()
                self.syncResults.append(result)
                self.lastSyncTime = Date()
                
                if result.success {
                    Logger.shared.info("Successfully synced artifact \(artifact.name) to \(provider.displayName)")
                } else {
                    throw AppError.syncError("同步失败: \(result.message ?? "未知错误")")
                }
                
                self.syncInProgress = false
            }
        }
    }
    
    func syncAllArtifacts() {
        let enabledConfigs = syncConfigs.filter { $0.isEnabled }
        
        guard !enabledConfigs.isEmpty else {
            showError("没有启用的同步配置")
            return
        }
        
        Task {
            await performAsyncTask { [weak self] in
                guard let self = self else { return }
                
                self.syncInProgress = true
                var allResults: [SyncResult] = []
                
                for config in enabledConfigs {
                    for artifact in self.artifacts {
                        do {
                            let result = try await self.syncArtifactUseCase.execute(artifact: artifact, to: config.provider).async()
                            allResults.append(result)
                        } catch {
                            Logger.shared.error("Failed to sync artifact \(artifact.name) to \(config.provider.displayName): \(error)")
                        }
                    }
                }
                
                self.syncResults.append(contentsOf: allResults)
                self.lastSyncTime = Date()
                self.syncInProgress = false
                
                let successCount = allResults.filter { $0.success }.count
                Logger.shared.info("Batch sync completed: \(successCount)/\(allResults.count) successful")
            }
        }
    }
    
    private func autoSyncArtifacts() async {
        let autoSyncConfigs = syncConfigs.filter { config in
            config.isEnabled && 
            (config.lastSync == nil || Date().timeIntervalSince(config.lastSync!) >= config.syncInterval)
        }
        
        guard !autoSyncConfigs.isEmpty else { return }
        
        await performAsyncTask { [weak self] in
            guard let self = self else { return }
            
            for config in autoSyncConfigs {
                for artifact in self.artifacts {
                    do {
                        let result = try await self.syncArtifactUseCase.execute(artifact: artifact, to: config.provider).async()
                        if result.success {
                            // 更新最后同步时间
                            var updatedConfig = config
                            updatedConfig = SyncConfig(
                                id: config.id,
                                provider: config.provider,
                                token: config.token,
                                repositoryURL: config.repositoryURL,
                                isEnabled: config.isEnabled,
                                lastSync: Date(),
                                syncInterval: config.syncInterval
                            )
                            self.updateSyncConfig(updatedConfig)
                        }
                    } catch {
                        Logger.shared.warning("Auto sync failed for \(artifact.name): \(error)")
                    }
                }
            }
            
            Logger.shared.info("Auto sync completed for \(autoSyncConfigs.count) configurations")
        }
    }
    
    func fetchFromSync(_ config: SyncConfig) {
        Task {
            await performAsyncTask { [weak self] in
                guard let self = self else { return }
                
                let fetchedArtifacts = try await self.repository.fetchFromSync(config).async()
                
                // 合并或替换本地规则
                for fetchedArtifact in fetchedArtifacts {
                    if let existingIndex = self.artifacts.firstIndex(where: { $0.id == fetchedArtifact.id }) {
                        // 检查是否有冲突
                        let existing = self.artifacts[existingIndex]
                        if existing.updatedAt > fetchedArtifact.updatedAt {
                            // 本地更新，需要处理冲突
                            Logger.shared.warning("Sync conflict detected for artifact: \(existing.name)")
                        } else {
                            // 远程更新，使用远程版本
                            self.artifacts[existingIndex] = fetchedArtifact
                        }
                    } else {
                        // 新规则，直接添加
                        self.artifacts.append(fetchedArtifact)
                    }
                }
                
                Logger.shared.info("Fetched \(fetchedArtifacts.count) artifacts from \(config.provider.displayName)")
            }
        }
    }
    
    // MARK: - Batch Operations
    func performBatchOperation(_ operation: ArtifactBatchOperation, on artifactIDs: Set<String>) {
        Task {
            switch operation {
            case .enable:
                await batchToggleStatus(artifactIDs, enabled: true)
            case .disable:
                await batchToggleStatus(artifactIDs, enabled: false)
            case .delete:
                await batchDelete(artifactIDs)
            case .test:
                await batchTest(artifactIDs)
            case .sync(let provider):
                await batchSync(artifactIDs, to: provider)
            case .export:
                await batchExport(artifactIDs)
            }
        }
    }
    
    private func batchToggleStatus(_ artifactIDs: Set<String>, enabled: Bool) async {
        let artifactsToUpdate = artifacts.filter { artifactIDs.contains($0.id) }
        
        for artifact in artifactsToUpdate {
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
                isEnabled: enabled,
                createdAt: artifact.createdAt,
                updatedAt: Date(),
                lastSync: artifact.lastSync
            )
            updateArtifact(updatedArtifact)
        }
        
        selectedArtifacts.removeAll()
        Logger.shared.info("Batch \(enabled ? "enabled" : "disabled") \(artifactsToUpdate.count) artifacts")
    }
    
    private func batchDelete(_ artifactIDs: Set<String>) async {
        for artifactID in artifactIDs {
            await performAsyncTask { [weak self] in
                guard let self = self else { return }
                
                let success = try await self.deleteArtifactUseCase.execute(artifactID: artifactID).async()
                
                if success {
                    self.artifacts.removeAll { $0.id == artifactID }
                } else {
                    throw AppError.unknownError("Failed to delete artifact")
                }
            }
        }
        
        selectedArtifacts.removeAll()
        Logger.shared.info("Batch deleted \(artifactIDs.count) artifacts")
    }
    
    private func batchTest(_ artifactIDs: Set<String>) async {
        let artifactsToTest = artifacts.filter { artifactIDs.contains($0.id) }
        
        await withTaskGroup(of: Void.self) { group in
            for artifact in artifactsToTest {
                group.addTask { [weak self] in
                    await self?.testArtifact(artifact)
                }
            }
        }
        
        Logger.shared.info("Batch tested \(artifactsToTest.count) artifacts")
    }
    
    private func batchSync(_ artifactIDs: Set<String>, to provider: SyncProvider) async {
        let artifactsToSync = artifacts.filter { artifactIDs.contains($0.id) }
        
        for artifact in artifactsToSync {
            syncToProvider(artifact, provider: provider)
        }
        
        Logger.shared.info("Batch synced \(artifactsToSync.count) artifacts to \(provider.displayName)")
    }
    
    private func batchExport(_ artifactIDs: Set<String>) async {
        let artifactsToExport = artifacts.filter { artifactIDs.contains($0.id) }
        
        do {
            let data = try JSONEncoder().encode(artifactsToExport)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent("artifacts_export_\(Date().timeIntervalSince1970).json")
            
            try data.write(to: fileURL)
            Logger.shared.info("Batch exported \(artifactsToExport.count) artifacts to: \(fileURL.path)")
            
            // 这里可以触发分享界面
        } catch {
            Logger.shared.error("Failed to batch export artifacts: \(error)")
            showError("批量导出失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Selection Management
    func toggleArtifactSelection(_ artifactID: String) {
        if selectedArtifacts.contains(artifactID) {
            selectedArtifacts.remove(artifactID)
        } else {
            selectedArtifacts.insert(artifactID)
        }
    }
    
    func selectAllArtifacts() {
        if selectedArtifacts.count == filteredArtifacts.count {
            selectedArtifacts.removeAll()
        } else {
            selectedArtifacts = Set(filteredArtifacts.map { $0.id })
        }
    }
    
    // MARK: - Private Methods
    private func updateFilteredArtifacts(artifacts: [Artifact], searchText: String, selectedType: ArtifactType?) {
        var filtered = artifacts
        
        // 类型筛选
        if let selectedType = selectedType {
            filtered = filtered.filter { $0.type == selectedType }
        }
        
        // 搜索筛选
        if !searchText.isEmpty {
            filtered = filtered.filter { artifact in
                artifact.name.localizedCaseInsensitiveContains(searchText) ||
                artifact.content.localizedCaseInsensitiveContains(searchText) ||
                artifact.tags.joined().localizedCaseInsensitiveContains(searchText)
            }
        }
        
        filteredArtifacts = filtered
    }
}

// MARK: - Batch Operation Enum
enum ArtifactBatchOperation {
    case enable
    case disable
    case delete
    case test
    case sync(SyncProvider)
    case export
}