import Foundation
import Combine
import CoreData
import Alamofire

// MARK: - Subscription Repository Implementation
class SubscriptionRepository: SubscriptionRepositoryProtocol {
    private let networkService: NetworkServiceProtocol
    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext
    
    init(
        networkService: NetworkServiceProtocol = NetworkService.shared,
        persistenceController: PersistenceController = .shared
    ) {
        self.networkService = networkService
        self.persistenceController = persistenceController
        self.context = persistenceController.container.viewContext
    }
    
    // MARK: - Base Repository Methods
    func getAll() -> AnyPublisher<[Subscription], Error> {
        return getSubscriptions()
            .combineLatest(getCollections())
            .map { subs, collections in
                return subs + collections
            }
            .eraseToAnyPublisher()
    }
    
    func getById(_ id: String) -> AnyPublisher<Subscription?, Error> {
        let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(AppError.unknownError("Repository deallocated")))
                return
            }
            
            do {
                let entities = try self.context.fetch(request)
                let subscription = entities.first?.toDomainModel()
                promise(.success(subscription))
            } catch {
                promise(.failure(AppError.storageError(error.localizedDescription)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func create(_ entity: Subscription) -> AnyPublisher<Subscription, Error> {
        let request = APIRequest(
            method: .post,
            path: APIEndpoints.createSub.path,
            parameters: try? entity.asDictionary(),
            encoding: JSONEncoding.default
        )
        
        return networkService.request(request, responseType: APIResponse<Subscription>.self)
            .tryMap { response in
                guard let subscription = response.data else {
                    throw AppError.dataParsingError("No subscription data in response")
                }
                return subscription
            }
            .handleEvents(receiveOutput: { [weak self] subscription in
                self?.saveToLocal(subscription)
            })
            .mapError { error in
                if error is NetworkError {
                    return error
                } else {
                    return AppError.unknownError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func update(_ entity: Subscription) -> AnyPublisher<Subscription, Error> {
        let request = APIRequest(
            method: .put,
            path: APIEndpoints.updateSub(entity.id).path,
            parameters: try? entity.asDictionary(),
            encoding: JSONEncoding.default
        )
        
        return networkService.request(request, responseType: APIResponse<Subscription>.self)
            .tryMap { response in
                guard let subscription = response.data else {
                    throw AppError.dataParsingError("No subscription data in response")
                }
                return subscription
            }
            .handleEvents(receiveOutput: { [weak self] subscription in
                self?.saveToLocal(subscription)
            })
            .mapError { error in
                if error is NetworkError {
                    return error
                } else {
                    return AppError.unknownError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
    
    func delete(_ id: String) -> AnyPublisher<Bool, Error> {
        let request = APIRequest(
            method: .delete,
            path: APIEndpoints.deleteSub(id).path
        )
        
        return networkService.request(request, responseType: APIResponse<Bool>.self)
            .map { $0.success }
            .handleEvents(receiveOutput: { [weak self] success in
                if success {
                    self?.deleteFromLocal(id)
                }
            })
            .mapError { error in
                return AppError.networkError(error.localizedDescription)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Subscription Specific Methods
    func getSubscriptions() -> AnyPublisher<[Subscription], Error> {
        let request = APIRequest(
            method: .get,
            path: APIEndpoints.getSubs.path
        )
        
        return networkService.request(request, responseType: APIResponse<[Subscription]>.self)
            .tryMap { response in
                guard let subscriptions = response.data else {
                    throw AppError.dataParsingError("No subscriptions data in response")
                }
                return subscriptions
            }
            .handleEvents(receiveOutput: { [weak self] subscriptions in
                self?.saveSubscriptionsToLocal(subscriptions)
            })
            .catch { [weak self] error -> AnyPublisher<[Subscription], Error> in
                // 网络失败时从本地获取
                return self?.getSubscriptionsFromLocal() ?? Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func getCollections() -> AnyPublisher<[Subscription], Error> {
        let request = APIRequest(
            method: .get,
            path: APIEndpoints.getCollections.path
        )
        
        return networkService.request(request, responseType: APIResponse<[Subscription]>.self)
            .tryMap { response in
                guard let collections = response.data else {
                    throw AppError.dataParsingError("No collections data in response")
                }
                return collections
            }
            .handleEvents(receiveOutput: { [weak self] collections in
                self?.saveSubscriptionsToLocal(collections)
            })
            .catch { [weak self] error -> AnyPublisher<[Subscription], Error> in
                // 网络失败时从本地获取
                return self?.getCollectionsFromLocal() ?? Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func getFlowInfo(for subscriptionID: String) -> AnyPublisher<FlowInfo?, Error> {
        let request = APIRequest(
            method: .get,
            path: APIEndpoints.getSubFlow(subscriptionID).path
        )
        
        return networkService.request(request, responseType: APIResponse<FlowInfo>.self)
            .map { response in
                return response.data
            }
            .handleEvents(receiveOutput: { [weak self] flowInfo in
                if let flowInfo = flowInfo {
                    self?.updateFlowInfoLocal(subscriptionID: subscriptionID, flowInfo: flowInfo)
                }
            })
            .catch { _ in
                Just(nil).setFailureType(to: Error.self)
            }
            .eraseToAnyPublisher()
    }
    
    func updateFlowInfo(subscriptionID: String, flowInfo: FlowInfo) -> AnyPublisher<Bool, Error> {
        // 更新本地流量信息
        updateFlowInfoLocal(subscriptionID: subscriptionID, flowInfo: flowInfo)
        return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func importSubscriptions(from url: URL) -> AnyPublisher<[Subscription], Error> {
        return Future { promise in
            do {
                let data = try Data(contentsOf: url)
                let subscriptions = try JSONDecoder().decode([Subscription].self, from: data)
                promise(.success(subscriptions))
            } catch {
                promise(.failure(AppError.dataParsingError(error.localizedDescription)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func exportSubscriptions(_ subscriptions: [Subscription]) -> AnyPublisher<Data, Error> {
        return Future { promise in
            do {
                let data = try JSONEncoder().encode(subscriptions)
                promise(.success(data))
            } catch {
                promise(.failure(AppError.dataParsingError(error.localizedDescription)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func testConnection(for subscription: Subscription) -> AnyPublisher<Bool, Error> {
        guard let urlString = subscription.url, !urlString.isEmpty else {
            return Fail(error: AppError.validationError("Invalid subscription URL"))
                .eraseToAnyPublisher()
        }
        
        return networkService.download(from: urlString)
            .map { _ in true }
            .catch { _ in Just(false) }
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    private func saveToLocal(_ subscription: Subscription) {
        let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", subscription.id)
        
        do {
            let entities = try context.fetch(request)
            let entity = entities.first ?? SubscriptionEntity(context: context)
            entity.updateFromDomainModel(subscription)
            persistenceController.save()
        } catch {
            Logger.shared.error("Failed to save subscription to local: \(error)")
        }
    }
    
    private func saveSubscriptionsToLocal(_ subscriptions: [Subscription]) {
        subscriptions.forEach { saveToLocal($0) }
    }
    
    private func deleteFromLocal(_ id: String) {
        let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        
        do {
            let entities = try context.fetch(request)
            entities.forEach { context.delete($0) }
            persistenceController.save()
        } catch {
            Logger.shared.error("Failed to delete subscription from local: \(error)")
        }
    }
    
    private func getSubscriptionsFromLocal() -> AnyPublisher<[Subscription], Error> {
        let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "type == %@", SubscriptionType.single.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(AppError.unknownError("Repository deallocated")))
                return
            }
            
            do {
                let entities = try self.context.fetch(request)
                let subscriptions = entities.map { $0.toDomainModel() }
                promise(.success(subscriptions))
            } catch {
                promise(.failure(AppError.storageError(error.localizedDescription)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func getCollectionsFromLocal() -> AnyPublisher<[Subscription], Error> {
        let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "type == %@", SubscriptionType.collection.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(AppError.unknownError("Repository deallocated")))
                return
            }
            
            do {
                let entities = try self.context.fetch(request)
                let collections = entities.map { $0.toDomainModel() }
                promise(.success(collections))
            } catch {
                promise(.failure(AppError.storageError(error.localizedDescription)))
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func updateFlowInfoLocal(subscriptionID: String, flowInfo: FlowInfo) {
        let request: NSFetchRequest<SubscriptionEntity> = SubscriptionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", subscriptionID)
        
        do {
            let entities = try context.fetch(request)
            if let entity = entities.first {
                if entity.flowInfo == nil {
                    entity.flowInfo = FlowInfoEntity(context: context)
                }
                entity.flowInfo?.updateFromDomainModel(flowInfo)
                persistenceController.save()
            }
        } catch {
            Logger.shared.error("Failed to update flow info: \(error)")
        }
    }
}

// MARK: - Codable Extension for Dictionary Conversion
extension Encodable {
    func asDictionary() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw NSError()
        }
        return dictionary
    }
}