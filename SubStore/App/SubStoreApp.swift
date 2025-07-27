import SwiftUI

@main
struct SubStoreApp: App {
    let persistenceController = PersistenceController.shared
    
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var settingsManager = SettingsManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(themeManager)
                .environmentObject(settingsManager)
                .preferredColorScheme(themeManager.colorScheme)
        }
    }
}