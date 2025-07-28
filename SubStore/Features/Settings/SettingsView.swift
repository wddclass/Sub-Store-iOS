import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 设置视图
struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    // 存储模式相关状态
    @State private var storageType: StorageType = .gist
    @State private var isEditing = false
    @State private var isEditLoading = false
    @State private var showingAbout = false
    @State private var showingFilePicker = false
    @State private var showingExportSheet = false
    @State private var showingDocumentPicker = false
    
    // 编辑字段状态
    @State private var userInput = ""
    @State private var tokenInput = ""
    @State private var uaInput = ""
    @State private var proxyInput = ""
    @State private var timeoutInput = ""
    @State private var cacheThresholdInput = ""
    
    // 同步状态
    @State private var uploadIsLoading = false
    @State private var downloadIsLoading = false
    @State private var restoreIsLoading = false
    
    enum StorageType: String, CaseIterable {
        case gist = "gist"
        case manual = "manual"
        
        var displayName: String {
            switch self {
            case .gist:
                return "GitHub Gist"
            case .manual:
                return "手动备份"
            }
        }
        
        var info: String {
            switch self {
            case .gist:
                return "云端同步"
            case .manual:
                return "本地文件"
            }
        }
    }
    
    private var syncIsDisabled: Bool {
        uploadIsLoading || downloadIsLoading || 
        settingsManager.settings.sync.gistToken.isEmpty || 
        settingsManager.settings.sync.githubUser.isEmpty
    }
    
    private var desText: [String] {
        if settingsManager.settings.sync.gistToken.isEmpty || settingsManager.settings.sync.githubUser.isEmpty {
            return ["未配置同步"]
        } else {
            return ["已配置同步", "点击编辑修改设置"]
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 存储类型选择
                    HStack {
                        ForEach(StorageType.allCases, id: \.self) { type in
                            Button(action: {
                                withAnimation {
                                    storageType = type
                                }
                            }) {
                                VStack(spacing: 4) {
                                    Text(type.displayName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    
                                    Rectangle()
                                        .fill(storageType == type ? Color.accentColor : Color.clear)
                                        .frame(height: 2)
                                }
                            }
                            .foregroundColor(storageType == type ? .accentColor : .secondary)
                        }
                        
                        Spacer()
                        
                        Text(storageType.info)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // 用户信息区域
                    profileSection
                    
                    // 配置卡片
                    configSection
                    
                    // 其他设置
                    otherSettingsSection
                }
                .padding(.vertical)
            }
            .navigationTitle("设置")
        }
        .fileImporter(
            isPresented: $showingDocumentPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .onAppear {
            loadEditingValues()
        }
    }
    
    // MARK: - Profile Section
    private var profileSection: some View {
        HStack(spacing: 16) {
            // 头像
            AsyncImage(url: URL(string: "https://github.com/\(settingsManager.settings.sync.githubUser).png")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
            }
            .frame(width: 72, height: 72)
            .clipShape(Circle())
            
            // 用户信息
            VStack(alignment: .leading, spacing: 4) {
                if storageType == .manual {
                    Text("手动备份")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("本地文件备份和恢复")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(settingsManager.settings.sync.githubUser.isEmpty ? "未配置用户" : settingsManager.settings.sync.githubUser)
                        .font(.title3)
                        .fontWeight(.bold)
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(desText, id: \.self) { text in
                            Text(text)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // 操作按钮
            actionButtons
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if storageType == .manual {
                // 恢复按钮
                Button(action: {
                    showingDocumentPicker = true
                }) {
                    HStack(spacing: 8) {
                        if restoreIsLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "cloud.fill")
                        }
                        Text("恢复")
                            .font(.caption)
                    }
                    .foregroundColor(.accentColor)
                    .frame(width: 100, height: 32)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(restoreIsLoading)
                
                // 备份按钮
                Button(action: {
                    showingExportSheet = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                        Text("备份")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 100, height: 32)
                    .background(Color.accentColor)
                    .cornerRadius(8)
                }
            } else {
                // 上传按钮
                Button(action: uploadSettings) {
                    HStack(spacing: 8) {
                        if uploadIsLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "cloud.fill")
                        }
                        Text("上传")
                            .font(.caption)
                    }
                    .foregroundColor(.accentColor)
                    .frame(width: 100, height: 32)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(syncIsDisabled)
                
                // 下载按钮
                Button(action: downloadSettings) {
                    HStack(spacing: 8) {
                        if downloadIsLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text("下载")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(width: 100, height: 32)
                    .background(Color.accentColor)
                    .cornerRadius(8)
                }
                .disabled(syncIsDisabled)
            }
        }
    }
    
    // MARK: - Config Section
    private var configSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("配置")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Spacer()
                
                HStack(spacing: 8) {
                    if isEditing {
                        Button("取消") {
                            exitEditMode()
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .disabled(isEditLoading)
                    }
                    
                    Button(isEditing ? "保存" : "编辑") {
                        toggleEditMode()
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                    .disabled(isEditLoading)
                }
            }
            
            VStack(spacing: 12) {
                if storageType == .gist {
                    ConfigInputView(
                        title: "GitHub 用户名",
                        text: $userInput,
                        placeholder: "GitHub 用户名",
                        isEditing: isEditing,
                        systemImage: "person"
                    )
                    
                    ConfigInputView(
                        title: "Gist Token",
                        text: $tokenInput,
                        placeholder: "Gist Token",
                        isEditing: isEditing,
                        systemImage: "key",
                        isSecure: true
                    )
                }
                
                ConfigInputView(
                    title: "默认代理",
                    text: $proxyInput,
                    placeholder: "默认代理设置",
                    isEditing: isEditing,
                    systemImage: "network"
                )
                
                ConfigInputView(
                    title: "User-Agent",
                    text: $uaInput,
                    placeholder: "默认 User-Agent",
                    isEditing: isEditing,
                    systemImage: "globe"
                )
                
                ConfigInputView(
                    title: "请求超时",
                    text: $timeoutInput,
                    placeholder: "超时时间(毫秒)",
                    isEditing: isEditing,
                    systemImage: "clock",
                    keyboardType: {
                        #if canImport(UIKit)
                        return .numberPad
                        #else
                        return .default
                        #endif
                    }()
                )
                
                ConfigInputView(
                    title: "缓存阈值",
                    text: $cacheThresholdInput,
                    placeholder: "缓存大小阈值",
                    isEditing: isEditing,
                    systemImage: "memorychip",
                    keyboardType: {
                        #if canImport(UIKit)
                        return .numberPad
                        #else
                        return .default
                        #endif
                    }()
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Other Settings Section
    private var otherSettingsSection: some View {
        VStack(spacing: 0) {
            SettingsRowView(
                title: "主题模式",
                systemImage: "paintbrush",
                value: themeManager.currentTheme.displayName,
                destination: ThemeSettingsView()
            )
            
            SettingsRowView(
                title: "网络设置",
                systemImage: "server.rack",
                value: settingsManager.settings.network.baseURL,
                destination: NetworkSettingsView()
            )
            
            SettingsRowView(
                title: "关于 Sub-Store",
                systemImage: "info.circle",
                destination: AboutView()
            )
            
            SettingsRowView<EmptyView>(
                title: "版本",
                systemImage: "tag",
                value: AppConstants.App.version,
                destination: nil
            )
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Methods
    private func loadEditingValues() {
        userInput = settingsManager.settings.sync.githubUser
        tokenInput = settingsManager.settings.sync.gistToken.isEmpty ? "" : "******"
        uaInput = settingsManager.settings.network.userAgent
        proxyInput = "" // 这里需要从后端获取
        timeoutInput = "\(settingsManager.settings.network.timeout)"
        cacheThresholdInput = "1024" // 默认值
    }
    
    private func toggleEditMode() {
        if isEditing {
            saveSettings()
        } else {
            isEditing = true
            // 重新加载实际值用于编辑
            tokenInput = settingsManager.settings.sync.gistToken
        }
    }
    
    private func exitEditMode() {
        isEditing = false
        loadEditingValues()
    }
    
    private func saveSettings() {
        isEditLoading = true
        
        // 更新设置
        settingsManager.settings.sync.githubUser = userInput
        if !tokenInput.isEmpty && tokenInput != "******" {
            settingsManager.settings.sync.gistToken = tokenInput
        }
        settingsManager.settings.network.userAgent = uaInput
        if let timeout = Int(timeoutInput) {
            settingsManager.settings.network.timeout = timeout
        }
        
        settingsManager.saveSettings()
        
        isEditLoading = false
        isEditing = false
        loadEditingValues()
    }
    
    private func uploadSettings() {
        uploadIsLoading = true
        // 这里实现上传逻辑
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            uploadIsLoading = false
        }
    }
    
    private func downloadSettings() {
        downloadIsLoading = true
        // 这里实现下载逻辑
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            downloadIsLoading = false
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard urls.first != nil else { return }
            restoreIsLoading = true
            
            // 这里实现文件导入逻辑
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                restoreIsLoading = false
            }
            
        case .failure(let error):
            print("File import failed: \(error)")
        }
    }
}

// MARK: - Config Input View
struct ConfigInputView: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let isEditing: Bool
    let systemImage: String
    var isSecure: Bool = false
    #if canImport(UIKit)
    var keyboardType: UIKeyboardType = .default
    #endif
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Group {
                if isSecure && !isEditing {
                    Text(text.isEmpty ? placeholder : text)
                        .foregroundColor(text.isEmpty ? .secondary : .primary)
                } else if isEditing {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                            #if canImport(UIKit)
                            .keyboardType(keyboardType)
                            #endif
                    }
                } else {
                    Text(text.isEmpty ? placeholder : text)
                        .foregroundColor(text.isEmpty ? .secondary : .primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.tertiarySystemGroupedBackground))
            .cornerRadius(8)
        }
    }
}

// MARK: - 主题设置视图
struct ThemeSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        List {
            Section("主题模式") {
                ForEach(ThemeManager.Theme.allCases, id: \.self) { theme in
                    HStack {
                        Text(theme.displayName)
                        Spacer()
                        if themeManager.currentTheme == theme {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        themeManager.setTheme(theme)
                    }
                }
            }
            
            Section("强调色") {
                // 简化的强调色设置
                SwiftUI.ColorPicker("强调色", selection: $themeManager.accentColor)
                
                HStack {
                    Text("当前强调色")
                    Spacer()
                    Rectangle()
                        .fill(themeManager.accentColor)
                        .frame(width: 30, height: 20)
                        .cornerRadius(4)
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
                #if canImport(UIKit)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                #endif
                
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