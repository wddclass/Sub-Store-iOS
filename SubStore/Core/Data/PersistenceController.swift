import CoreData
import Foundation

class PersistenceController {
    static let shared = PersistenceController()
    
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // 创建预览数据
        let sampleSubscription = SubscriptionEntity(context: viewContext)
        sampleSubscription.id = UUID().uuidString
        sampleSubscription.name = "示例订阅"
        sampleSubscription.url = "https://example.com/subscription"
        sampleSubscription.type = "single"
        sampleSubscription.createdAt = Date()
        sampleSubscription.updatedAt = Date()
        sampleSubscription.isEnabled = true
        
        do {
            try viewContext.save()
        } catch {
            Logger.shared.error("Failed to save preview data: \(error)")
        }
        
        return result
    }()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SubStore")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                Logger.shared.error("Core Data failed to load store: \(error)")
                fatalError("Unresolved Core Data error \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    func save() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                Logger.shared.error("Failed to save Core Data context: \(error)")
            }
        }
    }
    
    func saveContext() {
        save()
    }
}