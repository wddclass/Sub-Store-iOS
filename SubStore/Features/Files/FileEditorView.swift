import SwiftUI
import Highlightr

// MARK: - 文件编辑器视图
struct FileEditorView: View {
    let file: SubStoreFile?
    let onSave: (SubStoreFile) -> Void
    
    @StateObject private var viewModel = FileEditorViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var showingIconPicker = false
    @State private var showingSourcePicker = false
    @State private var showingFileImporter = false
    @State private var showingFullScreenEditor = false
    @State private var showingPreview = false
    @State private var isSubmitting = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                if showingFullScreenEditor {
                    fullScreenEditor
                } else {
                    mainEditor
                }
                
                // 底部操作按钮
                bottomActionButtons
            }
        }
        .onAppear {
            if let file = file {
                viewModel.loadFile(file)
            } else {
                viewModel.initializeNewFile()
            }
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedIcon: $viewModel.form.icon)
        }
        .sheet(isPresented: $showingSourcePicker) {
            SourcePickerView(
                sourceType: viewModel.form.sourceType,
                selectedSource: $viewModel.form.sourceName
            )
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.text, .json, .yaml],
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleFileImport(result)
        }
        .sheet(isPresented: $showingPreview) {
            FilePreviewView(
                previewData: viewModel.previewData,
                isPresented: $showingPreview
            )
        }
        .withNotifications()
    }
    
    // MARK: - 主编辑界面
    private var mainEditor: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 图标显示
                if settingsManager.settings.appearance.showIcon {
                    fileIconView
                }
                
                // 基础表单
                basicFormSection
                
                // 文件类型特定配置
                typeSpecificSection
                
                // Mihomo Profile 提示
                if viewModel.form.type == .mihomoProfile {
                    mihomoProfileTips
                }
                
                // 操作块（如果是 Mihomo Profile）
                if viewModel.form.type == .mihomoProfile {
                    actionBlocksSection
                }
                
                Spacer(minLength: 120) // 为底部按钮留空间
            }
            .padding()
        }
        .navigationTitle(file == nil ? "创建文件" : "编辑文件")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("取消") {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - 全屏编辑器
    private var fullScreenEditor: some View {
        VStack(spacing: 0) {
            // 全屏编辑器工具栏
            HStack {
                Button("退出全屏") {
                    showingFullScreenEditor = false
                }
                .padding()
                
                Spacer()
            }
            .background(Color(UIColor.systemBackground))
            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
            
            // 代码编辑器
            CodeEditorView(
                content: $viewModel.form.content,
                language: viewModel.form.language ?? "text"
            )
        }
    }
    
    // MARK: - 图标视图
    private var fileIconView: some View {
        Button(action: {
            showingIconPicker = true
        }) {
            AsyncImage(url: URL(string: viewModel.fileIcon)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "doc")
                    .font(.system(size: 30))
                    .foregroundColor(.accentColor)
            }
            .frame(width: 70, height: 70)
            .background(Color(UIColor.tertiarySystemGroupedBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - 基础表单
    private var basicFormSection: some View {
        VStack(spacing: 16) {
            // 名称
            FormRowView(title: "名称") {
                TextField("文件名称", text: $viewModel.form.name)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            
            // 显示名称
            FormRowView(title: "显示名称") {
                TextField("显示名称（可选）", text: $viewModel.form.displayName)
                    .textFieldStyle(.roundedBorder)
            }
            
            // 备注
            FormRowView(title: "备注") {
                TextField("备注信息（可选）", text: $viewModel.form.remark, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
            }
            
            // 下载开关
            FormRowView(title: "下载") {
                Toggle("", isOn: $viewModel.form.download)
                    .labelsHidden()
            }
            
            // 图标URL
            FormRowView(title: "图标") {
                HStack {
                    TextField("图标链接", text: $viewModel.form.icon)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button("选择") {
                        showingIconPicker = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            // 图标彩色
            FormRowView(title: "彩色图标") {
                Toggle("", isOn: $viewModel.form.isIconColor)
                    .labelsHidden()
            }
            
            // 订阅信息URL（仅限文件类型）
            if viewModel.form.type != .mihomoProfile {
                FormRowView(title: "订阅信息URL") {
                    TextField("订阅信息链接", text: $viewModel.form.subInfoUrl)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                FormRowView(title: "订阅信息User-Agent") {
                    TextField("User-Agent", text: $viewModel.form.subInfoUserAgent)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            
            // 文件类型
            FormRowView(title: "类型") {
                Picker("文件类型", selection: $viewModel.form.type) {
                    Text("Mihomo Profile").tag(FileType.mihomoProfile)
                    Text("文件").tag(FileType.general)
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - 类型特定配置
    private var typeSpecificSection: some View {
        VStack(spacing: 16) {
            if viewModel.form.type == .mihomoProfile {
                mihomoProfileSection
            } else {
                generalFileSection
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.top, 16)
    }
    
    // MARK: - Mihomo Profile 配置
    private var mihomoProfileSection: some View {
        VStack(spacing: 16) {
            // 来源类型
            FormRowView(title: "来源") {
                Picker("来源类型", selection: $viewModel.form.sourceType) {
                    Text("单条订阅").tag(SubscriptionSource.subscription)
                    Text("组合订阅").tag(SubscriptionSource.collection)
                    Text("无").tag(SubscriptionSource.none)
                }
                .pickerStyle(.segmented)
            }
            
            // 订阅名称（如果不是"无"）
            if viewModel.form.sourceType != .none {
                FormRowView(title: "订阅名称") {
                    HStack {
                        TextField("选择订阅", text: $viewModel.form.sourceName)
                            .textFieldStyle(.roundedBorder)
                            .disabled(true)
                        
                        Button("选择") {
                            showingSourcePicker = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
    
    // MARK: - 普通文件配置
    private var generalFileSection: some View {
        VStack(spacing: 16) {
            // 来源
            FormRowView(title: "来源") {
                Picker("文件来源", selection: $viewModel.form.source) {
                    Text("远程").tag("remote")
                    Text("本地").tag("local")
                }
                .pickerStyle(.segmented)
            }
            
            if viewModel.form.source == "remote" {
                // 远程URL
                FormRowView(title: "URL") {
                    TextField("远程文件链接", text: $viewModel.form.url, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                // User-Agent
                FormRowView(title: "User-Agent") {
                    TextField("User-Agent（可选）", text: $viewModel.form.ua)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            } else {
                // 本地内容
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button("全屏编辑") {
                            showingFullScreenEditor = true
                        }
                        .buttonStyle(.bordered)
                        
                        Button("从文件导入") {
                            showingFileImporter = true
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // 内容预览/编辑区域
                    VStack(alignment: .leading, spacing: 8) {
                        Text("文件内容")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView {
                            CodeEditorView(
                                content: $viewModel.form.content,
                                language: viewModel.form.language ?? "text",
                                isCompact: true
                            )
                            .frame(minHeight: 200, maxHeight: 300)
                        }
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(UIColor.separator), lineWidth: 1)
                        )
                    }
                }
            }
            
            // 代理设置
            FormRowView(title: "代理") {
                HStack {
                    TextField("代理设置（可选）", text: $viewModel.form.proxy)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button("提示") {
                        showProxyTips()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            // 合并来源
            FormRowView(title: "合并来源") {
                Picker("合并策略", selection: $viewModel.form.mergeSources) {
                    Text("不合并").tag("")
                    Text("本地优先").tag("localFirst")
                    Text("远程优先").tag("remoteFirst")
                }
                .pickerStyle(.segmented)
            }
            
            // 忽略失败的远程文件
            FormRowView(title: "忽略失败的远程文件") {
                Picker("处理策略", selection: $viewModel.form.ignoreFailedRemoteFile) {
                    Text("禁用").tag("disabled")
                    Text("静默").tag("quiet")
                    Text("启用").tag("enabled")
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    // MARK: - Mihomo Profile 提示
    private var mihomoProfileTips: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.accentColor)
                
                Text("Mihomo Profile 覆写文档")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Link("查看文档", destination: URL(string: "https://mihomo.party/docs/guide/override")!)
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(8)
        .padding(.top, 16)
    }
    
    // MARK: - 操作块
    private var actionBlocksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("操作配置")
                .font(.headline)
                .fontWeight(.medium)
            
            // 这里应该实现 ActionBlock 组件
            // 由于比较复杂，暂时用简化版本
            Text("操作块功能开发中...")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.top, 16)
    }
    
    // MARK: - 底部操作按钮
    private var bottomActionButtons: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                // 预览按钮
                Button(action: {
                    generatePreview()
                }) {
                    HStack {
                        Image(systemName: "eye")
                        Text("预览")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
                .frame(width: 100)
                
                // 保存按钮
                Button(action: {
                    saveFile()
                }) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text("保存")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isSubmitting || !viewModel.isValidForm)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: -2)
        }
    }
    
    // MARK: - 方法
    private func generatePreview() {
        guard viewModel.validateForm() else {
            NotificationHelper.showError("表单验证失败", content: "请检查输入的信息")
            return
        }
        
        Task {
            await viewModel.generatePreview()
            if viewModel.previewData != nil {
                showingPreview = true
            }
        }
    }
    
    private func saveFile() {
        guard viewModel.validateForm() else {
            NotificationHelper.showError("表单验证失败", content: "请检查输入的信息")
            return
        }
        
        isSubmitting = true
        
        Task {
            let success = await viewModel.saveFile()
            
            DispatchQueue.main.async {
                isSubmitting = false
                
                if success {
                    if let savedFile = viewModel.savedFile {
                        onSave(savedFile)
                    }
                    dismiss()
                }
            }
        }
    }
    
    private func showProxyTips() {
        let alert = UIAlertController(
            title: "通过代理/节点/策略获取远程文件",
            message: """
            1. Surge: 可设置节点代理或策略/节点
            2. Loon: 指定节点或策略组
            3. Stash/Shadowrocket/QX: 可设置策略/节点
            4. Node.js版: 支持 http/https/socks5
            
            例: socks5://a:b@127.0.0.1:7890
            """,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "知道了", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
}

// MARK: - 表单行视图
struct FormRowView<Content: View>: View {
    let title: String
    let content: () -> Content
    
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            content()
        }
    }
}

// MARK: - 代码编辑器视图
struct CodeEditorView: View {
    @Binding var content: String
    let language: String
    let isCompact: Bool
    
    @State private var highlighter = Highlightr()
    
    init(content: Binding<String>, language: String, isCompact: Bool = false) {
        self._content = content
        self.language = language
        self.isCompact = isCompact
    }
    
    var body: some View {
        VStack {
            if isCompact {
                TextEditor(text: $content)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
            } else {
                GeometryReader { geometry in
                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - 来源选择器视图
struct SourcePickerView: View {
    let sourceType: SubscriptionSource
    @Binding var selectedSource: String
    @Environment(\.dismiss) private var dismiss
    
    // 模拟数据，实际应该从 Store 获取
    private let mockSources = [
        "示例订阅1",
        "示例订阅2",
        "示例组合订阅1"
    ]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(mockSources, id: \.self) { source in
                    Button(source) {
                        selectedSource = source
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("选择\(sourceType == .subscription ? "订阅" : "组合订阅")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    FileEditorView(file: nil) { _ in }
        .environmentObject(ThemeManager())
        .environmentObject(SettingsManager())
}