import SwiftUI

// MARK: - 规则列表视图
struct ArtifactsListView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                title: "规则功能开发中",
                description: "规则配置和同步功能正在开发中，敬请期待",
                systemImage: "gear"
            )
            .navigationTitle("规则")
        }
    }
}

// MARK: - 文件列表视图
struct FilesListView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                title: "文件功能开发中",
                description: "文件管理功能正在开发中，敬请期待",
                systemImage: "doc.text"
            )
            .navigationTitle("文件")
        }
    }
}

// MARK: - 分享列表视图
struct ShareListView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                title: "分享功能开发中",
                description: "分享管理功能正在开发中，敬请期待",
                systemImage: "square.and.arrow.up"
            )
            .navigationTitle("分享")
        }
    }
}

// MARK: - 设置视图
struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showingAbout = false
    
    var body: some View {
        NavigationStack {
            List {
                // 外观设置
                Section("外观") {
                    SettingsRowView(
                        title: "主题模式",
                        systemImage: "paintbrush",
                        value: themeManager.currentTheme.mode.displayName,
                        destination: ThemeSettingsView()
                    )
                    
                    SettingsRowView(
                        title: "显示流量信息",
                        systemImage: "chart.bar",
                        action: {
                            settingsManager.settings.appearance.showFlowInfo.toggle()
                            settingsManager.saveSettings()
                        }
                    )
                    
                    SettingsRowView(
                        title: "显示订阅图标",
                        systemImage: "photo",
                        action: {
                            settingsManager.settings.appearance.showSubscriptionIcons.toggle()
                            settingsManager.saveSettings()
                        }
                    )
                }
                
                // 同步设置
                Section("同步") {
                    SettingsRowView(
                        title: "云端同步",
                        subtitle: "使用 GitHub Gist 或 GitLab Snippet 同步配置",
                        systemImage: "icloud",
                        value: settingsManager.settings.sync.platform.displayName,
                        destination: SyncSettingsView()
                    )
                    
                    if settingsManager.settings.sync.platform != .none {
                        SettingsRowView(
                            title: "自动同步",
                            systemImage: "arrow.clockwise",
                            action: {
                                settingsManager.settings.sync.autoSync.toggle()
                                settingsManager.saveSettings()
                            }
                        )
                    }
                }
                
                // 网络设置
                Section("网络") {
                    SettingsRowView(
                        title: "后端地址",
                        systemImage: "server.rack",
                        value: settingsManager.settings.network.baseURL,
                        destination: NetworkSettingsView()
                    )
                    
                    SettingsRowView(
                        title: "请求超时",
                        systemImage: "clock",
                        value: "\(settingsManager.settings.network.timeout)秒"
                    )
                }
                
                // 关于
                Section("关于") {
                    SettingsRowView(
                        title: "关于 Sub-Store",
                        systemImage: "info.circle",
                        destination: AboutView()
                    )
                    
                    SettingsRowView(
                        title: "版本",
                        systemImage: "tag",
                        value: AppConstants.App.version
                    )
                }
                
                // 高级设置
                Section("高级") {
                    SettingsRowView(
                        title: "重置设置",
                        systemImage: "arrow.counterclockwise",
                        action: {
                            settingsManager.resetToDefaults()
                        }
                    )
                }
            }
            .navigationTitle("设置")
        }
    }
}

// MARK: - 主题设置视图
struct ThemeSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        List {
            Section("主题模式") {
                ForEach(ThemeMode.allCases, id: \.self) { mode in
                    HStack {
                        Text(mode.displayName)
                        Spacer()
                        if themeManager.currentTheme.mode == mode {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        themeManager.setThemeMode(mode)
                    }
                }
            }
            
            Section("强调色") {
                Toggle("使用系统强调色", isOn: Binding(
                    get: { themeManager.currentTheme.useSystemAccentColor },
                    set: { themeManager.useSystemAccentColor($0) }
                ))
                
                if !themeManager.currentTheme.useSystemAccentColor {
                    // 这里可以添加自定义颜色选择器
                    Text("自定义颜色选择器")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("主题设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 同步设置视图
struct SyncSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        List {
            Section("同步平台") {
                ForEach(SyncPlatform.allCases, id: \.self) { platform in
                    HStack {
                        Text(platform.displayName)
                        Spacer()
                        if settingsManager.settings.sync.platform == platform {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        settingsManager.settings.sync.platform = platform
                        settingsManager.saveSettings()
                    }
                }
            }
            
            if settingsManager.settings.sync.platform == .gist {
                Section("GitHub 设置") {
                    TextField("GitHub 用户名", text: Binding(
                        get: { settingsManager.settings.sync.githubUser },
                        set: {
                            settingsManager.settings.sync.githubUser = $0
                            settingsManager.saveSettings()
                        }
                    ))
                    
                    SecureField("Gist Token", text: Binding(
                        get: { settingsManager.settings.sync.gistToken },
                        set: {
                            settingsManager.settings.sync.gistToken = $0
                            settingsManager.saveSettings()
                        }
                    ))
                }
            }
        }
        .navigationTitle("同步设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 网络设置视图
struct NetworkSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        List {
            Section("服务器配置") {
                TextField("后端地址", text: Binding(
                    get: { settingsManager.settings.network.baseURL },
                    set: {
                        settingsManager.settings.network.baseURL = $0
                        settingsManager.saveSettings()
                    }
                ))
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                
                Stepper("请求超时: \(settingsManager.settings.network.timeout)秒", 
                       value: Binding(
                        get: { settingsManager.settings.network.timeout },
                        set: {
                            settingsManager.settings.network.timeout = $0
                            settingsManager.saveSettings()
                        }
                       ),
                       in: 5...60,
                       step: 5)
            }
        }
        .navigationTitle("网络设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 关于视图
struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: AppConstants.UI.Spacing.medium) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                    
                    Text("Sub-Store")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("高级订阅管理器")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("版本 \(AppConstants.App.version) (\(AppConstants.App.build))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            
            Section("功能特性") {
                Text("• 支持多种订阅格式转换")
                Text("• 强大的订阅格式化功能")
                Text("• 多订阅聚合管理")
                Text("• 规则管理和云端同步")
                Text("• 文件管理和编辑")
            }
            
            Section("开源项目") {
                Link("GitHub 仓库", destination: URL(string: "https://github.com/sub-store-org/Sub-Store")!)
                Link("前端项目", destination: URL(string: "https://github.com/sub-store-org/Sub-Store-Front-End")!)
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}