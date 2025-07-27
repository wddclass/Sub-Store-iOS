import CoreData
import Foundation

// MARK: - SubscriptionEntity Extensions
extension SubscriptionEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SubscriptionEntity> {
        return NSFetchRequest<SubscriptionEntity>(entityName: "SubscriptionEntity")
    }
    
    @NSManaged public var id: String
    @NSManaged public var name: String
    @NSManaged public var url: String
    @NSManaged public var type: String
    @NSManaged public var tags: String?
    @NSManaged public var platform: String?
    @NSManaged public var icon: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var isEnabled: Bool
    @NSManaged public var flowInfo: FlowInfoEntity?
    
    // 转换为 Domain Model
    func toDomainModel() -> Subscription {
        let tagsArray = tags?.components(separatedBy: ",").filter { !$0.isEmpty } ?? []
        let flow = flowInfo?.toDomainModel()
        
        return Subscription(
            id: id,
            name: name,
            url: url,
            type: SubscriptionType(rawValue: type) ?? .single,
            tags: tagsArray,
            platform: platform,
            flow: flow,
            icon: icon,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isEnabled: isEnabled
        )
    }
    
    // 从 Domain Model 更新
    func updateFromDomainModel(_ subscription: Subscription) {
        id = subscription.id
        name = subscription.name
        url = subscription.url
        type = subscription.type.rawValue
        tags = subscription.tags.joined(separator: ",")
        platform = subscription.platform
        icon = subscription.icon
        createdAt = subscription.createdAt
        updatedAt = subscription.updatedAt
        isEnabled = subscription.isEnabled
        
        if let flow = subscription.flow {
            if flowInfo == nil {
                flowInfo = FlowInfoEntity(context: managedObjectContext!)
            }
            flowInfo?.updateFromDomainModel(flow)
        }
    }
    
    // 创建新实体
    static func create(from subscription: Subscription, in context: NSManagedObjectContext) -> SubscriptionEntity {
        let entity = SubscriptionEntity(context: context)
        entity.updateFromDomainModel(subscription)
        return entity
    }
}

// MARK: - FlowInfoEntity Extensions
extension FlowInfoEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<FlowInfoEntity> {
        return NSFetchRequest<FlowInfoEntity>(entityName: "FlowInfoEntity")
    }
    
    @NSManaged public var total: Int64
    @NSManaged public var used: Int64
    @NSManaged public var remaining: Int64
    @NSManaged public var percentage: Double
    @NSManaged public var resetDate: Date?
    @NSManaged public var isUnlimited: Bool
    @NSManaged public var subscription: SubscriptionEntity?
    
    // 转换为 Domain Model
    func toDomainModel() -> FlowInfo {
        return FlowInfo(
            total: total == 0 ? nil : total,
            used: used == 0 ? nil : used,
            remaining: remaining == 0 ? nil : remaining,
            percentage: percentage == 0 ? nil : percentage,
            resetDate: resetDate,
            isUnlimited: isUnlimited
        )
    }
    
    // 从 Domain Model 更新
    func updateFromDomainModel(_ flowInfo: FlowInfo) {
        total = flowInfo.total ?? 0
        used = flowInfo.used ?? 0
        remaining = flowInfo.remaining ?? 0
        percentage = flowInfo.percentage ?? 0
        resetDate = flowInfo.resetDate
        isUnlimited = flowInfo.isUnlimited
    }
}

// MARK: - ArtifactEntity Extensions
extension ArtifactEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ArtifactEntity> {
        return NSFetchRequest<ArtifactEntity>(entityName: "ArtifactEntity")
    }
    
    @NSManaged public var id: String
    @NSManaged public var name: String
    @NSManaged public var type: String
    @NSManaged public var source: String
    @NSManaged public var content: String
    @NSManaged public var syncURL: String?
    @NSManaged public var lastSyncDate: Date?
    @NSManaged public var isAutoSync: Bool
    @NSManaged public var tags: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var isEnabled: Bool
    
    // 转换为 Domain Model
    func toDomainModel() -> Artifact {
        let tagsArray = tags?.components(separatedBy: ",").filter { !$0.isEmpty } ?? []
        
        return Artifact(
            id: id,
            name: name,
            type: ArtifactType(rawValue: type) ?? .rule,
            source: ArtifactSource(rawValue: source) ?? .local,
            content: content,
            syncURL: syncURL,
            lastSyncDate: lastSyncDate,
            isAutoSync: isAutoSync,
            tags: tagsArray,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isEnabled: isEnabled
        )
    }
    
    // 从 Domain Model 更新
    func updateFromDomainModel(_ artifact: Artifact) {
        id = artifact.id
        name = artifact.name
        type = artifact.type.rawValue
        source = artifact.source.rawValue
        content = artifact.content
        syncURL = artifact.syncURL
        lastSyncDate = artifact.lastSyncDate
        isAutoSync = artifact.isAutoSync
        tags = artifact.tags.joined(separator: ",")
        createdAt = artifact.createdAt
        updatedAt = artifact.updatedAt
        isEnabled = artifact.isEnabled
    }
    
    // 创建新实体
    static func create(from artifact: Artifact, in context: NSManagedObjectContext) -> ArtifactEntity {
        let entity = ArtifactEntity(context: context)
        entity.updateFromDomainModel(artifact)
        return entity
    }
}

// MARK: - FileEntity Extensions
extension FileEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<FileEntity> {
        return NSFetchRequest<FileEntity>(entityName: "FileEntity")
    }
    
    @NSManaged public var id: String
    @NSManaged public var name: String
    @NSManaged public var type: String
    @NSManaged public var content: String
    @NSManaged public var size: Int64
    @NSManaged public var language: String?
    @NSManaged public var tags: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var isReadOnly: Bool
    
    // 转换为 Domain Model
    func toDomainModel() -> SubStoreFile {
        let tagsArray = tags?.components(separatedBy: ",").filter { !$0.isEmpty } ?? []
        
        return SubStoreFile(
            id: id,
            name: name,
            type: FileType(rawValue: type) ?? .general,
            content: content,
            size: size,
            language: language,
            tags: tagsArray,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isReadOnly: isReadOnly
        )
    }
    
    // 从 Domain Model 更新
    func updateFromDomainModel(_ file: SubStoreFile) {
        id = file.id
        name = file.name
        type = file.type.rawValue
        content = file.content
        size = file.size
        language = file.language
        tags = file.tags.joined(separator: ",")
        createdAt = file.createdAt
        updatedAt = file.updatedAt
        isReadOnly = file.isReadOnly
    }
    
    // 创建新实体
    static func create(from file: SubStoreFile, in context: NSManagedObjectContext) -> FileEntity {
        let entity = FileEntity(context: context)
        entity.updateFromDomainModel(file)
        return entity
    }
}

// MARK: - ShareEntity Extensions
extension ShareEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ShareEntity> {
        return NSFetchRequest<ShareEntity>(entityName: "ShareEntity")
    }
    
    @NSManaged public var id: String
    @NSManaged public var name: String
    @NSManaged public var token: String
    @NSManaged public var type: String
    @NSManaged public var targetID: String
    @NSManaged public var targetName: String
    @NSManaged public var expirationDate: Date?
    @NSManaged public var isEnabled: Bool
    @NSManaged public var accessCount: Int32
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    
    // 转换为 Domain Model
    func toDomainModel() -> Share {
        return Share(
            id: id,
            name: name,
            token: token,
            type: ShareType(rawValue: type) ?? .subscription,
            targetID: targetID,
            targetName: targetName,
            expirationDate: expirationDate,
            isEnabled: isEnabled,
            accessCount: Int(accessCount),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    // 从 Domain Model 更新
    func updateFromDomainModel(_ share: Share) {
        id = share.id
        name = share.name
        token = share.token
        type = share.type.rawValue
        targetID = share.targetID
        targetName = share.targetName
        expirationDate = share.expirationDate
        isEnabled = share.isEnabled
        accessCount = Int32(share.accessCount)
        createdAt = share.createdAt
        updatedAt = share.updatedAt
    }
    
    // 创建新实体
    static func create(from share: Share, in context: NSManagedObjectContext) -> ShareEntity {
        let entity = ShareEntity(context: context)
        entity.updateFromDomainModel(share)
        return entity
    }
}