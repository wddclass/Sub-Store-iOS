import Foundation

struct AppConstants {
    
    // MARK: - App Information
    struct App {
        static let name = "Sub-Store"
        static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        static let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.substore.ios"
    }
    
    // MARK: - API Configuration
    struct API {
        static let defaultBaseURL = "http://localhost:3000"
        static let defaultTimeout: TimeInterval = 30.0
        static let defaultRetryCount = 3
        
        // API Endpoints
        struct Endpoints {
            static let subs = "/api/subs"
            static let collections = "/api/collections"
            static let artifacts = "/api/artifacts"
            static let files = "/api/files"
            static let share = "/api/share"
            static let settings = "/api/settings"
            static let download = "/api/download"
            static let sync = "/api/sync"
        }
    }
    
    // MARK: - Storage Keys
    struct StorageKeys {
        static let baseURL = "SubStore.BaseURL"
        static let theme = "SubStore.Theme"
        static let language = "SubStore.Language"
        static let syncPlatform = "SubStore.SyncPlatform"
        static let gistToken = "SubStore.GistToken"
        static let githubUser = "SubStore.GitHubUser"
        static let firstLaunch = "SubStore.FirstLaunch"
        static let lastSyncTime = "SubStore.LastSyncTime"
    }
    
    // MARK: - UI Constants
    struct UI {
        static let cornerRadius: CGFloat = 12.0
        static let shadowRadius: CGFloat = 4.0
        static let animationDuration: Double = 0.3
        static let hapticFeedbackIntensity: CGFloat = 0.7
        
        struct Spacing {
            static let tiny: CGFloat = 4.0
            static let small: CGFloat = 8.0
            static let medium: CGFloat = 16.0
            static let large: CGFloat = 24.0
            static let extraLarge: CGFloat = 32.0
        }
        
        struct Icon {
            static let small: CGFloat = 16.0
            static let medium: CGFloat = 24.0
            static let large: CGFloat = 32.0
            static let extraLarge: CGFloat = 48.0
        }
    }
    
    // MARK: - Supported Platforms
    struct Platform {
        static let supported = ["QX", "Loon", "Surge", "Stash", "Clash", "ShadowRocket"]
    }
    
    // MARK: - File Types
    struct FileTypes {
        static let supported = ["json", "yaml", "yml", "txt", "conf"]
        static let codeEditorSupported = ["js", "javascript", "json", "yaml", "yml"]
    }
}