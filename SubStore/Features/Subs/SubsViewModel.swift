import Foundation
import Combine
import SwiftUI

// MARK: - Subscription Use Cases
class GetSubscriptionsUseCaseImpl: GetSubscriptionsUseCase {
    private let repository: SubscriptionRepositoryProtocol
    
    init(repository: SubscriptionRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute() -> AnyPublisher<[Subscription], Error> {
        return repository.getAll()
    }
}

class CreateSubscriptionUseCaseImpl: CreateSubscriptionUseCase {
    private let repository: SubscriptionRepositoryProtocol
    
    init(repository: SubscriptionRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(subscription: Subscription) -> AnyPublisher<Subscription, Error> {
        return repository.create(subscription)
    }
}

class UpdateSubscriptionUseCaseImpl: UpdateSubscriptionUseCase {
    private let repository: SubscriptionRepositoryProtocol
    
    init(repository: SubscriptionRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(subscription: Subscription) -> AnyPublisher<Subscription, Error> {
        return repository.update(subscription)
    }
}

class DeleteSubscriptionUseCaseImpl: DeleteSubscriptionUseCase {
    private let repository: SubscriptionRepositoryProtocol
    
    init(repository: SubscriptionRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(subscriptionID: String) -> AnyPublisher<Bool, Error> {
        return repository.delete(subscriptionID)
    }
}

// MARK: - Subscription ViewModel
@MainActor
class SubsViewModel: BaseViewModel {
    // MARK: - Published Properties
    @Published var subscriptions: [Subscription] = []
    @Published var collections: [Subscription] = []
    @Published var filteredSubscriptions: [Subscription] = []
    @Published var availableTags: [String] = ["全部"]
    @Published var selectedTag: String = "全部"
    @Published var searchText: String = ""
    @Published var showingAddSheet: Bool = false
    @Published var showingImportSheet: Bool = false
    @Published var editingSubscription: Subscription? = nil
    
    // 增强搜索功能
    @Published var selectedTypes: Set<SubscriptionType> = []
    @Published var selectedTags: Set<String> = []
    @Published var enabledOnly: Bool = false
    @Published var hasFlowInfo: Bool = false
    @Published var showingAdvancedSearch: Bool = false
    
    // 批量操作
    @Published var selectedSubscriptions: Set<String> = []
    @Published var showingBatchOperations: Bool = false
    @Published var showingStats: Bool = false
    
    // MARK: - Private Properties
    private let getSubscriptionsUseCase: GetSubscriptionsUseCase
    private let createSubscriptionUseCase: CreateSubscriptionUseCase
    private let updateSubscriptionUseCase: UpdateSubscriptionUseCase
    private let deleteSubscriptionUseCase: DeleteSubscriptionUseCase
    private let repository: SubscriptionRepositoryProtocol
    
    private var flowUpdateTimer: Timer?
    
    // MARK: - Initialization
    init(
        getSubscriptionsUseCase: GetSubscriptionsUseCase? = nil,
        createSubscriptionUseCase: CreateSubscriptionUseCase? = nil,
        updateSubscriptionUseCase: UpdateSubscriptionUseCase? = nil,
        deleteSubscriptionUseCase: DeleteSubscriptionUseCase? = nil,
        repository: SubscriptionRepositoryProtocol? = nil
    ) {
        let defaultRepository = repository ?? SubscriptionRepository()
        
        self.repository = defaultRepository
        self.getSubscriptionsUseCase = getSubscriptionsUseCase ?? GetSubscriptionsUseCaseImpl(repository: defaultRepository)
        self.createSubscriptionUseCase = createSubscriptionUseCase ?? CreateSubscriptionUseCaseImpl(repository: defaultRepository)
        self.updateSubscriptionUseCase = updateSubscriptionUseCase ?? UpdateSubscriptionUseCaseImpl(repository: defaultRepository)
        self.deleteSubscriptionUseCase = deleteSubscriptionUseCase ?? DeleteSubscriptionUseCaseImpl(repository: defaultRepository)
        
        super.init()
        
        setupObservers()
        startFlowUpdateTimer()
    }
    
    deinit {
        flowUpdateTimer?.invalidate()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        // 监听搜索文本和筛选条件变化
        Publishers.CombineLatest($subscriptions, $searchText)
            .combineLatest($selectedTag, $selectedTypes, $selectedTags, $enabledOnly, $hasFlowInfo)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] args, selectedTag, selectedTypes, selectedTags, enabledOnly, hasFlowInfo in
                let (subscriptions, searchText) = args
                self?.updateFilteredSubscriptions(
                    subscriptions: subscriptions,
                    searchText: searchText,
                    selectedTag: selectedTag,
                    selectedTypes: selectedTypes,
                    selectedTags: selectedTags,
                    enabledOnly: enabledOnly,
                    hasFlowInfo: hasFlowInfo
                )
            }
            .store(in: &cancellables)
        
        // 监听订阅变化，更新标签
        $subscriptions
            .sink { [weak self] subscriptions in
                self?.updateAvailableTags(from: subscriptions)
            }
            .store(in: &cancellables)
    }
    
    private func startFlowUpdateTimer() {
        flowUpdateTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateFlowInfo()
            }
        }
    }
    
    // MARK: - Public Methods
    func loadSubscriptions() {
        Task {
            await performAsyncTask { [weak self] in
                guard let self = self else { return }
                
                let subscriptions = try await self.getSubscriptionsUseCase.execute().async()
                
                // 分离单条订阅和组合订阅
                self.subscriptions = subscriptions.filter { $0.type == .single }
                self.collections = subscriptions.filter { $0.type == .collection }
                
                Logger.shared.info("Loaded \(self.subscriptions.count) subscriptions and \(self.collections.count) collections")
            }
        }
    }
    
    func refreshSubscriptions() {
        clearError()
        loadSubscriptions()
    }
    
    func addSubscription(_ subscription: Subscription) {
        Task {
            await performAsyncTask { [weak self] in
                guard let self = self else { return }
                
                let newSubscription = try await self.createSubscriptionUseCase.execute(subscription: subscription).async()
                
                if newSubscription.type == .single {
                    self.subscriptions.append(newSubscription)
                } else {
                    self.collections.append(newSubscription)
                }
                
                Logger.shared.info("Added subscription: \(newSubscription.name)")
            }
        }
    }
    
    func updateSubscription(_ subscription: Subscription) {
        Task {
            await performAsyncTask { [weak self] in
                guard let self = self else { return }
                
                let updatedSubscription = try await self.updateSubscriptionUseCase.execute(subscription: subscription).async()
                
                if updatedSubscription.type == .single {
                    if let index = self.subscriptions.firstIndex(where: { $0.id == updatedSubscription.id }) {
                        self.subscriptions[index] = updatedSubscription
                    }
                } else {
                    if let index = self.collections.firstIndex(where: { $0.id == updatedSubscription.id }) {
                        self.collections[index] = updatedSubscription
                    }
                }
                
                Logger.shared.info("Updated subscription: \(updatedSubscription.name)")
            }
        }
    }
    
    func deleteSubscriptions(at offsets: IndexSet) {
        let subscriptionsToDelete = offsets.map { filteredSubscriptions[$0] }
        
        Task {
            for subscription in subscriptionsToDelete {
                await performAsyncTask { [weak self] in
                    guard let self = self else { return }
                    
                    let success = try await self.deleteSubscriptionUseCase.execute(subscriptionID: subscription.id).async()
                    
                    if success {
                        if subscription.type == .single {
                            self.subscriptions.removeAll { $0.id == subscription.id }
                        } else {
                            self.collections.removeAll { $0.id == subscription.id }
                        }
                        
                        Logger.shared.info("Deleted subscription: \(subscription.name)")
                    } else {
                        throw AppError.unknownError("Failed to delete subscription")
                    }
                }
            }
        }
    }
    
    func moveSubscriptions(from source: IndexSet, to destination: Int) {
        var currentSubscriptions = subscriptions
        currentSubscriptions.move(fromOffsets: source, toOffset: destination)
        
        // 更新订阅顺序
        for (index, subscription) in currentSubscriptions.enumerated() {
            var updatedSubscription = subscription
            updatedSubscription.priority = index
            updateSubscription(updatedSubscription)
        }
        
        subscriptions = currentSubscriptions
    }
    
    func testSubscription(_ subscription: Subscription) {
        Task {
            await performAsyncTask { [weak self] in
                guard let self = self else { return }
                
                let isValid = try await self.repository.testConnection(for: subscription).async()
                
                if isValid {
                    // 显示成功消息
                    Logger.shared.info("Subscription test successful: \(subscription.name)")
                } else {
                    throw AppError.networkError("订阅连接测试失败")
                }
            }
        }
    }
    
    func toggleSubscriptionStatus(_ subscription: Subscription) {
        var updatedSubscription = subscription
        updatedSubscription.isEnabled = !subscription.isEnabled
        updatedSubscription.updatedAt = Date()
        updateSubscription(updatedSubscription)
    }
    
    func importSubscriptions(from url: URL) {
        Task {
            await performAsyncTask { [weak self] in
                guard let self = self else { return }
                
                let importedSubscriptions = try await self.repository.importSubscriptions(from: url).async()
                
                for subscription in importedSubscriptions {
                    let newSubscription = try await self.createSubscriptionUseCase.execute(subscription: subscription).async()
                    
                    if newSubscription.type == .single {
                        self.subscriptions.append(newSubscription)
                    } else {
                        self.collections.append(newSubscription)
                    }
                }
                
                Logger.shared.info("Imported \(importedSubscriptions.count) subscriptions")
            }
        }
    }
    
    func exportSubscriptions() -> URL? {
        let allSubscriptions = subscriptions + collections
        
        do {
            let data = try JSONEncoder().encode(allSubscriptions)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent("subscriptions_export_\(Date().timeIntervalSince1970).json")
            
            try data.write(to: fileURL)
            Logger.shared.info("Exported subscriptions to: \(fileURL.path)")
            return fileURL
        } catch {
            Logger.shared.error("Failed to export subscriptions: \(error)")
            showError("导出失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    func updateFlowInfo() async {
        let enabledSubscriptions = (subscriptions + collections).filter { $0.isEnabled }
        
        await withTaskGroup(of: Void.self) { group in
            for subscription in enabledSubscriptions {
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    
                    do {
                        if let flowInfo = try await self.repository.getFlowInfo(for: subscription.id).async() {
                            await MainActor.run {
                                self.updateSubscriptionFlowInfo(subscriptionID: subscription.id, flowInfo: flowInfo)
                            }
                        }
                    } catch {
                        Logger.shared.warning("Failed to update flow info for \(subscription.name): \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Batch Operations
    func performBatchOperation(_ operation: BatchOperationView.BatchOperation, on subscriptionIDs: Set<String>) {
        Task {
            switch operation {
            case .enable:
                await batchToggleStatus(subscriptionIDs, enabled: true)
            case .disable:
                await batchToggleStatus(subscriptionIDs, enabled: false)
            case .delete:
                await batchDelete(subscriptionIDs)
            case .updateFlow:
                await batchUpdateFlow(subscriptionIDs)
            case .export:
                await batchExport(subscriptionIDs)
            case .addTag(let tag):
                await batchAddTag(subscriptionIDs, tag: tag)
            case .removeTag(let tag):
                await batchRemoveTag(subscriptionIDs, tag: tag)
            }
        }
    }
    
    private func batchToggleStatus(_ subscriptionIDs: Set<String>, enabled: Bool) async {
        let subscriptionsToUpdate = (subscriptions + collections).filter { subscriptionIDs.contains($0.id) }
        
        for subscription in subscriptionsToUpdate {
            var updatedSubscription = subscription
            updatedSubscription.isEnabled = enabled
            updatedSubscription.updatedAt = Date()
            updateSubscription(updatedSubscription)
        }
        
        selectedSubscriptions.removeAll()
        Logger.shared.info("Batch \(enabled ? "enabled" : "disabled") \(subscriptionsToUpdate.count) subscriptions")
    }
    
    private func batchDelete(_ subscriptionIDs: Set<String>) async {
        for subscriptionID in subscriptionIDs {
            await performAsyncTask { [weak self] in
                guard let self = self else { return }
                
                let success = try await self.deleteSubscriptionUseCase.execute(subscriptionID: subscriptionID).async()
                
                if success {
                    self.subscriptions.removeAll { $0.id == subscriptionID }
                    self.collections.removeAll { $0.id == subscriptionID }
                } else {
                    throw AppError.unknownError("Failed to delete subscription")
                }
            }
        }
        
        selectedSubscriptions.removeAll()
        Logger.shared.info("Batch deleted \(subscriptionIDs.count) subscriptions")
    }
    
    private func batchUpdateFlow(_ subscriptionIDs: Set<String>) async {
        let subscriptionsToUpdate = (subscriptions + collections).filter { 
            subscriptionIDs.contains($0.id) && $0.isEnabled 
        }
        
        await withTaskGroup(of: Void.self) { group in
            for subscription in subscriptionsToUpdate {
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    
                    do {
                        if let flowInfo = try await self.repository.getFlowInfo(for: subscription.id).async() {
                            await MainActor.run {
                                self.updateSubscriptionFlowInfo(subscriptionID: subscription.id, flowInfo: flowInfo)
                            }
                        }
                    } catch {
                        Logger.shared.warning("Failed to update flow info for \(subscription.name): \(error)")
                    }
                }
            }
        }
        
        Logger.shared.info("Batch updated flow info for \(subscriptionsToUpdate.count) subscriptions")
    }
    
    private func batchExport(_ subscriptionIDs: Set<String>) async {
        let subscriptionsToExport = (subscriptions + collections).filter { subscriptionIDs.contains($0.id) }
        
        do {
            let data = try JSONEncoder().encode(subscriptionsToExport)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent("batch_export_\(Date().timeIntervalSince1970).json")
            
            try data.write(to: fileURL)
            Logger.shared.info("Batch exported \(subscriptionsToExport.count) subscriptions to: \(fileURL.path)")
            
            // 这里可以触发分享界面
        } catch {
            Logger.shared.error("Failed to batch export subscriptions: \(error)")
            showError("批量导出失败: \(error.localizedDescription)")
        }
    }
    
    private func batchAddTag(_ subscriptionIDs: Set<String>, tag: String) async {
        let subscriptionsToUpdate = (subscriptions + collections).filter { subscriptionIDs.contains($0.id) }
        
        for subscription in subscriptionsToUpdate {
            var updatedSubscription = subscription
            if !updatedSubscription.tags.contains(tag) {
                updatedSubscription.tags.append(tag)
            }
            updatedSubscription.updatedAt = Date()
            updateSubscription(updatedSubscription)
        }
        
        Logger.shared.info("Batch added tag '\(tag)' to \(subscriptionsToUpdate.count) subscriptions")
    }
    
    private func batchRemoveTag(_ subscriptionIDs: Set<String>, tag: String) async {
        let subscriptionsToUpdate = (subscriptions + collections).filter { subscriptionIDs.contains($0.id) }
        
        for subscription in subscriptionsToUpdate {
            var updatedSubscription = subscription
            updatedSubscription.tags.removeAll { $0 == tag }
            updatedSubscription.updatedAt = Date()
            updateSubscription(updatedSubscription)
        }
        
        Logger.shared.info("Batch removed tag '\(tag)' from \(subscriptionsToUpdate.count) subscriptions")
    }
    
    // MARK: - Advanced Search
    func resetAdvancedSearch() {
        searchText = ""
        selectedTypes.removeAll()
        selectedTags.removeAll()
        enabledOnly = false
        hasFlowInfo = false
        selectedTag = "全部"
    }
    
    func toggleSubscriptionSelection(_ subscriptionID: String) {
        if selectedSubscriptions.contains(subscriptionID) {
            selectedSubscriptions.remove(subscriptionID)
        } else {
            selectedSubscriptions.insert(subscriptionID)
        }
    }
    
    func selectAllSubscriptions() {
        if selectedSubscriptions.count == filteredSubscriptions.count {
            selectedSubscriptions.removeAll()
        } else {
            selectedSubscriptions = Set(filteredSubscriptions.map { $0.id })
        }
    }
    
    // MARK: - Quick Actions
    func performQuickAction(_ action: QuickActionView.QuickAction, on subscription: Subscription) {
        switch action {
        case .test:
            testSubscription(subscription)
        case .edit:
            editingSubscription = subscription
        case .toggle:
            toggleSubscriptionStatus(subscription)
        case .delete:
            Task {
                await performAsyncTask { [weak self] in
                    guard let self = self else { return }
                    
                    let success = try await self.deleteSubscriptionUseCase.execute(subscriptionID: subscription.id).async()
                    
                    if success {
                        if subscription.type == .single {
                            self.subscriptions.removeAll { $0.id == subscription.id }
                        } else {
                            self.collections.removeAll { $0.id == subscription.id }
                        }
                        Logger.shared.info("Deleted subscription: \(subscription.name)")
                    } else {
                        throw AppError.unknownError("Failed to delete subscription")
                    }
                }
            }
        case .copy:
            UIPasteboard.general.string = subscription.url
            Logger.shared.info("Copied subscription URL to clipboard")
        case .share:
            // 这里可以触发分享界面
            break
        case .updateFlow:
            Task {
                await updateFlowInfoForSubscription(subscription)
            }
        }
    }
    
    private func updateFlowInfoForSubscription(_ subscription: Subscription) async {
        do {
            if let flowInfo = try await repository.getFlowInfo(for: subscription.id).async() {
                await MainActor.run {
                    updateSubscriptionFlowInfo(subscriptionID: subscription.id, flowInfo: flowInfo)
                }
            }
        } catch {
            Logger.shared.warning("Failed to update flow info for \(subscription.name): \(error)")
            showError("更新流量信息失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    private func updateFilteredSubscriptions(
        subscriptions: [Subscription], 
        searchText: String, 
        selectedTag: String, 
        selectedTypes: Set<SubscriptionType>, 
        selectedTags: Set<String>, 
        enabledOnly: Bool, 
        hasFlowInfo: Bool
    ) {
        var filtered = subscriptions
        
        // 类型筛选
        if !selectedTypes.isEmpty {
            filtered = filtered.filter { selectedTypes.contains($0.type) }
        }
        
        // 标签筛选（旧版本兼容）
        if selectedTag != "全部" {
            switch selectedTag {
            case "单条订阅":
                filtered = filtered.filter { $0.type == .single }
            case "组合订阅":
                filtered = filtered.filter { $0.type == .collection }
            case "启用":
                filtered = filtered.filter { $0.isEnabled }
            case "禁用":
                filtered = filtered.filter { !$0.isEnabled }
            default:
                filtered = filtered.filter { $0.tags.contains(selectedTag) }
            }
        }
        
        // 高级标签筛选
        if !selectedTags.isEmpty {
            filtered = filtered.filter { subscription in
                selectedTags.isSubset(of: Set(subscription.tags))
            }
        }
        
        // 启用状态筛选
        if enabledOnly {
            filtered = filtered.filter { $0.isEnabled }
        }
        
        // 流量信息筛选
        if hasFlowInfo {
            filtered = filtered.filter { $0.flow != nil }
        }
        
        // 搜索筛选
        if !searchText.isEmpty {
            filtered = filtered.filter { subscription in
                subscription.name.localizedCaseInsensitiveContains(searchText) ||
                subscription.url.localizedCaseInsensitiveContains(searchText) ||
                subscription.tags.joined().localizedCaseInsensitiveContains(searchText) ||
                (subscription.platform?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        filteredSubscriptions = filtered
    }
    
    private func updateAvailableTags(from subscriptions: [Subscription]) {
        var tags = Set<String>(["全部", "单条订阅", "组合订阅", "启用", "禁用"])
        
        subscriptions.forEach { subscription in
            subscription.tags.forEach { tag in
                tags.insert(tag)
            }
        }
        
        availableTags = Array(tags).sorted()
    }
    
    private func updateSubscriptionFlowInfo(subscriptionID: String, flowInfo: FlowInfo) {
        // 更新单条订阅
        if let index = subscriptions.firstIndex(where: { $0.id == subscriptionID }) {
            var subscription = subscriptions[index]
            subscription.flow = flowInfo
            subscriptions[index] = subscription
        }
        
        // 更新组合订阅
        if let index = collections.firstIndex(where: { $0.id == subscriptionID }) {
            var collection = collections[index]
            collection.flow = flowInfo
            collections[index] = collection
        }
    }
}

// MARK: - Publisher Extension for async/await
extension Publisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = self
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                        cancellable?.cancel()
                    }
                )
        }
    }
}