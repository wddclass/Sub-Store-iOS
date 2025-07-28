import CoreData
import Foundation

// MARK: - SubscriptionEntity
@objc(SubscriptionEntity)
public class SubscriptionEntity: NSManagedObject {
    
}

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
    
    // MARK: - Domain Model Conversion
    func updateFromDomainModel(_ subscription: Subscription) {
        self.id = subscription.id
        self.name = subscription.name
        self.url = subscription.url ?? ""
        self.type = subscription.source.rawValue
        self.tags = subscription.tags.joined(separator: ",")
        self.icon = subscription.icon
        self.createdAt = subscription.createdAt
        self.updatedAt = subscription.updatedAt
        self.isEnabled = subscription.isEnabled
        
        // Update flow info if present
        if let flow = subscription.flow {
            if self.flowInfo == nil {
                self.flowInfo = FlowInfoEntity(context: self.managedObjectContext!)
            }
            self.flowInfo?.updateFromDomainModel(flow)
        }
    }
    
    func toDomainModel() -> Subscription {
        return Subscription(
            id: self.id,
            name: self.name,
            displayName: nil,
            url: self.url.isEmpty ? nil : self.url,
            content: nil,
            source: SubscriptionSource(rawValue: self.type) ?? .remote,
            icon: self.icon,
            isIconColor: false,
            tags: self.tags?.components(separatedBy: ",").filter { !$0.isEmpty } ?? [],
            mergeSources: .none,
            userAgent: nil,
            passThroughUA: false,
            proxy: nil,
            subUserinfo: nil,
            remark: nil,
            priority: 0,
            isEnabled: self.isEnabled,
            ignoreFailed: false,
            subscriptionTags: [],
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            flow: self.flowInfo?.toDomainModel()
        )
    }
    
}

// MARK: - ArtifactEntity
@objc(ArtifactEntity)
public class ArtifactEntity: NSManagedObject {
    
}

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
    
}

// MARK: - ShareEntity
@objc(ShareEntity)
public class ShareEntity: NSManagedObject {
    
}

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
    
}

// MARK: - FlowInfoEntity
@objc(FlowInfoEntity)
public class FlowInfoEntity: NSManagedObject {
    
}

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
    
    // MARK: - Domain Model Conversion
    func updateFromDomainModel(_ flow: FlowInfo) {
        self.total = flow.total ?? 0
        self.used = flow.used ?? 0
        self.remaining = flow.remaining ?? 0
        self.percentage = flow.percentage ?? 0.0
        self.resetDate = flow.resetDate
        self.isUnlimited = flow.isUnlimited
    }
    
    func toDomainModel() -> FlowInfo {
        return FlowInfo(
            total: self.total == 0 ? nil : self.total,
            used: self.used == 0 ? nil : self.used,
            remaining: self.remaining == 0 ? nil : self.remaining,
            percentage: self.percentage == 0.0 ? nil : self.percentage,
            resetDate: self.resetDate,
            isUnlimited: self.isUnlimited
        )
    }
    
}

// MARK: - FileEntity
@objc(FileEntity)
public class FileEntity: NSManagedObject {
    
}

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
    
}