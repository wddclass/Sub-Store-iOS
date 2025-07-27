import SwiftUI
import Combine

// MARK: - 主题管理器
@MainActor
class ThemeManager: ObservableObject {
    @Published var currentTheme: Theme = .system
    @Published var accentColor: Color = .blue
    @Published var isDarkMode: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    enum Theme: String, CaseIterable {
        case light = "light"
        case dark = "dark"
        case system = "system"
        
        var displayName: String {
            switch self {
            case .light: return "浅色"
            case .dark: return "深色"
            case .system: return "跟随系统"
            }
        }
    }
    
    var colorScheme: ColorScheme? {
        switch currentTheme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
    
    init() {
        loadThemeSettings()
        setupSystemThemeObserver()
    }
    
    // MARK: - 主题切换
    func setTheme(_ theme: Theme) {
        currentTheme = theme
        saveThemeSettings()
        updateDarkModeStatus()
    }
    
    func setAccentColor(_ colorHex: String) {
        accentColor = Color(hex: colorHex)
        saveThemeSettings()
    }
    
    func setAccentColor(_ color: Color) {
        accentColor = color
        saveThemeSettings()
    }
    
    // MARK: - 私有方法
    private func loadThemeSettings() {
        let themeString = UserDefaults.standard.string(forKey: "app_theme") ?? Theme.system.rawValue
        currentTheme = Theme(rawValue: themeString) ?? .system
        
        let colorHex = UserDefaults.standard.string(forKey: "app_accent_color") ?? "#007AFF"
        accentColor = Color(hex: colorHex)
        
        updateDarkModeStatus()
    }
    
    private func saveThemeSettings() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "app_theme")
        UserDefaults.standard.set(accentColor.toHex(), forKey: "app_accent_color")
    }
    
    private func setupSystemThemeObserver() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.updateDarkModeStatus()
            }
            .store(in: &cancellables)
    }
    
    private func updateDarkModeStatus() {
        switch currentTheme {
        case .light:
            isDarkMode = false
        case .dark:
            isDarkMode = true
        case .system:
            isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
        }
    }
}