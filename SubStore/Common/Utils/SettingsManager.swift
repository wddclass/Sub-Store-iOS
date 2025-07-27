import SwiftUI
import Combine

// MARK: - App Settings Model
struct AppSettings: Codable {
    var theme: ThemeSettings
    var sync: SyncSettings
    var network: NetworkSettings
    var appearance: AppearanceSettings
    
    init() {
        self.theme = ThemeSettings()
        self.sync = SyncSettings()
        self.network = NetworkSettings()
        self.appearance = AppearanceSettings()
    }
}

// MARK: - Theme Settings
struct ThemeSettings: Codable {
    var mode: ThemeMode
    var accentColor: String
    var useSystemAccentColor: Bool
    
    init(
        mode: ThemeMode = .system,
        accentColor: String = "#007AFF",
        useSystemAccentColor: Bool = true
    ) {
        self.mode = mode
        self.accentColor = accentColor
        self.useSystemAccentColor = useSystemAccentColor
    }
}

enum ThemeMode: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light:
            return "浅色模式"
        case .dark:
            return "深色模式"
        case .system:
            return "跟随系统"
        }
    }
}

// MARK: - Sync Settings
struct SyncSettings: Codable {
    var platform: SyncPlatform
    var gistToken: String
    var githubUser: String
    var autoSync: Bool
    var syncInterval: Int // minutes
    
    init(
        platform: SyncPlatform = .none,
        gistToken: String = "",
        githubUser: String = "",
        autoSync: Bool = false,
        syncInterval: Int = 60
    ) {
        self.platform = platform
        self.gistToken = gistToken
        self.githubUser = githubUser
        self.autoSync = autoSync
        self.syncInterval = syncInterval
    }
}

enum SyncPlatform: String, Codable, CaseIterable {
    case none = "none"
    case gist = "gist"
    case gitlab = "gitlab"
    
    var displayName: String {
        switch self {
        case .none:
            return "不同步"
        case .gist:
            return "GitHub Gist"
        case .gitlab:
            return "GitLab Snippet"
        }
    }
}

// MARK: - Network Settings
struct NetworkSettings: Codable {
    var baseURL: String
    var timeout: Int
    var retryCount: Int
    var userAgent: String
    
    init(
        baseURL: String = AppConstants.API.defaultBaseURL,
        timeout: Int = 30,
        retryCount: Int = 3,
        userAgent: String = "SubStore-iOS/\(AppConstants.App.version)"
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.retryCount = retryCount
        self.userAgent = userAgent
    }
}

// MARK: - Appearance Settings
struct AppearanceSettings: Codable {
    var showFlowInfo: Bool
    var showSubscriptionIcons: Bool
    var compactMode: Bool
    var animationsEnabled: Bool
    var hapticFeedbackEnabled: Bool
    
    init(
        showFlowInfo: Bool = true,
        showSubscriptionIcons: Bool = true,
        compactMode: Bool = false,
        animationsEnabled: Bool = true,
        hapticFeedbackEnabled: Bool = true
    ) {
        self.showFlowInfo = showFlowInfo
        self.showSubscriptionIcons = showSubscriptionIcons
        self.compactMode = compactMode
        self.animationsEnabled = animationsEnabled
        self.hapticFeedbackEnabled = hapticFeedbackEnabled
    }
}

// MARK: - Settings Manager
class SettingsManager: ObservableObject {
    @Published var settings: AppSettings
    @Published var isBackendConfigured: Bool = false
    @Published var currentHost: String?
    
    private let storageManager = StorageManager.shared
    
    init() {
        // 从本地存储加载设置
        self.settings = AppSettings()
        loadSettings()
        loadBackendConfig()
    }
    
    func loadSettings() {
        if let savedSettings = storageManager.getCodable(AppSettings.self, forKey: "AppSettings") {
            settings = savedSettings
        }
    }
    
    private func loadBackendConfig() {
        isBackendConfigured = UserDefaults.standard.bool(forKey: "backendConfigured")
        currentHost = UserDefaults.standard.string(forKey: "currentBackendHost")
    }
    
    func saveSettings() {
        storageManager.setCodable(settings, forKey: "AppSettings")
    }
    
    func setBackendHost(_ host: String) {
        currentHost = host
        settings.network.baseURL = host
        UserDefaults.standard.set(host, forKey: "currentBackendHost")
        saveSettings()
    }
    
    func setBackendConfigured(_ configured: Bool) {
        isBackendConfigured = configured
        UserDefaults.standard.set(configured, forKey: "backendConfigured")
    }
    
    func resetBackendConfig() {
        isBackendConfigured = false
        currentHost = nil
        UserDefaults.standard.removeObject(forKey: "backendConfigured")
        UserDefaults.standard.removeObject(forKey: "currentBackendHost")
        settings.network.baseURL = AppConstants.API.defaultBaseURL
        saveSettings()
    }
    
    func updateThemeSettings(_ themeSettings: ThemeSettings) {
        settings.theme = themeSettings
        saveSettings()
    }
    
    func updateSyncSettings(_ syncSettings: SyncSettings) {
        settings.sync = syncSettings
        saveSettings()
    }
    
    func updateNetworkSettings(_ networkSettings: NetworkSettings) {
        settings.network = networkSettings
        saveSettings()
    }
    
    func updateAppearanceSettings(_ appearanceSettings: AppearanceSettings) {
        settings.appearance = appearanceSettings
        saveSettings()
    }
    
    func resetToDefaults() {
        settings = AppSettings()
        saveSettings()
    }
}