import SwiftUI

// MARK: - 订阅编辑视图
struct SubEditorView: View {
    let subscription: Subscription?
    let editType: EditType
    let onSave: (Subscription) -> Void
    
    @State private var form = SubscriptionForm()
    @State private var showingIconPicker = false
    @State private var showingTagPicker = false
    @State private var showingContentEditor = false
    @State private var showingAdvancedEditor = false
    @State private var isValid = false
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    enum EditType {
        case subscription
        case collection
    }
    
    init(subscription: Subscription?, editType: EditType = .subscription, onSave: @escaping (Subscription) -> Void) {
        self.subscription = subscription
        self.editType = editType
        self.onSave = onSave
        
        if let subscription = subscription {
            _form = State(initialValue: SubscriptionForm(from: subscription))
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 基本信息
                basicInfoSection
                
                // 订阅配置
                if editType == .subscription {
                    subscriptionConfigSection
                } else {
                    collectionConfigSection
                }
                
                // 高级设置
                advancedSettingsSection
                
                // 操作设置
                if editType == .subscription {
                    operationSettingsSection
                }
                
                // 预览信息
                if subscription != nil {
                    previewSection
                }
            }
            .navigationTitle(subscription == nil ? (editType == .subscription ? "创建订阅" : "创建组合") : (editType == .subscription ? "编辑订阅" : "编辑组合"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveSubscription()
                    }
                    .disabled(!isValid)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                validateForm()
            }
            .onChange(of: form) { _ in
                validateForm()
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerView(selectedIcon: $form.icon, isColorIcon: $form.isIconColor)
            }
            .sheet(isPresented: $showingTagPicker) {
                TagPickerView(selectedTags: $form.tags)
            }
            .sheet(isPresented: $showingContentEditor) {
                ContentEditorView(content: $form.content, title: "编辑订阅内容")
            }
            .sheet(isPresented: $showingAdvancedEditor) {
                AdvancedEditorView(form: $form)
            }
        }
    }
    
    // MARK: - 基本信息部分
    private var basicInfoSection: some View {
        Section("基本信息") {
            // 图标显示
            HStack {
                Text("图标")
                Spacer()
                Button(action: { showingIconPicker = true }) {
                    HStack {
                        if let iconURL = form.iconURL {
                            AsyncImage(url: iconURL) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Image(systemName: "link.circle")
                                    .foregroundColor(.accentColor)
                            }
                            .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "link.circle")
                                .foregroundColor(.accentColor)
                                .frame(width: 24, height: 24)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 名称
            TextField("订阅名称", text: $form.name)
                .textFieldStyle(PlainTextFieldStyle())
            
            // 显示名称
            TextField("显示名称（可选）", text: $form.displayName)
                .textFieldStyle(PlainTextFieldStyle())
            
            // 备注
            TextField("备注", text: $form.remark, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(PlainTextFieldStyle())
            
            // 标签
            HStack {
                Text("标签")
                Spacer()
                Button(action: { showingTagPicker = true }) {
                    HStack {
                        if form.tags.isEmpty {
                            Text("选择标签")
                                .foregroundColor(.secondary)
                        } else {
                            Text(form.tags.prefix(2).joined(separator: ", "))
                                .foregroundColor(.primary)
                            if form.tags.count > 2 {
                                Text("等\(form.tags.count)个")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 彩色图标开关
            Toggle("彩色图标", isOn: $form.isIconColor)
        }
    }
    
    // MARK: - 订阅配置部分
    private var subscriptionConfigSection: some View {
        Section("订阅配置") {
            // 来源类型
            Picker("来源", selection: $form.source) {
                Text("远程订阅").tag(SubscriptionSource.remote)
                Text("本地内容").tag(SubscriptionSource.local)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            // URL 或内容
            if form.source == .remote {
                VStack(alignment: .leading, spacing: 8) {
                    Text("订阅链接")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("请输入订阅链接", text: $form.url, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("订阅内容")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button("全屏编辑") {
                            showingContentEditor = true
                        }
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }
                    
                    TextEditor(text: $form.content)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
            }
            
            // 合并来源（仅远程订阅）
            if form.source == .remote {
                Picker("合并来源", selection: $form.mergeSources) {
                    Text("不合并").tag(MergeSources.none)
                    Text("本地优先").tag(MergeSources.localFirst)
                    Text("远程优先").tag(MergeSources.remoteFirst)
                }
            }
        }
    }
    
    // MARK: - 组合配置部分
    private var collectionConfigSection: some View {
        Section("组合配置") {
            // 订阅标签
            HStack {
                Text("包含标签")
                Spacer()
                Button("选择订阅") {
                    // 显示订阅选择器
                }
                .foregroundColor(.accentColor)
            }
            
            // 订阅列表预览
            if !form.subscriptionTags.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("包含的订阅:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(form.subscriptionTags, id: \.self) { tag in
                        Text("• \(tag)")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
    
    // MARK: - 高级设置部分
    private var advancedSettingsSection: some View {
        Section("高级设置") {
            if form.source == .remote {
                // User Agent
                TextField("User Agent", text: $form.userAgent)
                    .textFieldStyle(PlainTextFieldStyle())
                
                // 透传 UA
                Toggle("透传 User Agent", isOn: $form.passThroughUA)
            }
            
            // 代理设置
            TextField("代理设置", text: $form.proxy)
                .textFieldStyle(PlainTextFieldStyle())
            
            // 用户信息
            TextField("用户信息", text: $form.subUserinfo)
                .textFieldStyle(PlainTextFieldStyle())
            
            // 高级编辑器
            Button("高级编辑器") {
                showingAdvancedEditor = true
            }
            .foregroundColor(.accentColor)
        }
    }
    
    // MARK: - 操作设置部分
    private var operationSettingsSection: some View {
        Section("操作设置") {
            // 启用状态
            Toggle("启用订阅", isOn: $form.isEnabled)
            
            // 忽略失败
            Toggle("忽略失败", isOn: $form.ignoreFailed)
            
            // 优先级
            Stepper("优先级: \(form.priority)", value: $form.priority, in: 0...100)
        }
    }
    
    // MARK: - 预览信息部分
    private var previewSection: some View {
        Section("预览信息") {
            if let subscription = subscription {
                DetailRowView(title: "创建时间", value: subscription.createdAt.detailFormatted)
                DetailRowView(title: "更新时间", value: subscription.updatedAt.detailFormatted)
                
                if let flow = subscription.flow {
                    DetailRowView(title: "已用流量", value: ByteFormatter.formatted(bytes: flow.used))
                    DetailRowView(title: "总流量", value: ByteFormatter.formatted(bytes: flow.total))
                    DetailRowView(title: "剩余流量", value: ByteFormatter.formatted(bytes: flow.remaining))
                    if let expireDate = flow.expireDate {
                        DetailRowView(title: "到期时间", value: expireDate.detailFormatted)
                    }
                }
            }
        }
    }
    
    // MARK: - 验证表单
    private func validateForm() {
        var valid = true
        
        // 名称不能为空
        if form.name.isEmpty {
            valid = false
        }
        
        // 远程订阅需要URL
        if form.source == .remote && form.url.isEmpty {
            valid = false
        }
        
        // 本地订阅需要内容
        if form.source == .local && form.content.isEmpty {
            valid = false
        }
        
        // URL格式验证
        if form.source == .remote && !form.url.isEmpty {
            if !isValidURL(form.url) {
                valid = false
            }
        }
        
        isValid = valid
    }
    
    private func isValidURL(_ url: String) -> Bool {
        let urlRegex = "^https?://.*"
        let urlPredicate = NSPredicate(format: "SELF MATCHES %@", urlRegex)
        return urlPredicate.evaluate(with: url)
    }
    
    // MARK: - 保存订阅
    private func saveSubscription() {
        let newSubscription = Subscription(
            id: subscription?.id ?? UUID().uuidString,
            name: form.name,
            displayName: form.displayName.isEmpty ? nil : form.displayName,
            url: form.source == .remote ? form.url : nil,
            content: form.source == .local ? form.content : nil,
            source: form.source,
            icon: form.icon.isEmpty ? nil : form.icon,
            isIconColor: form.isIconColor,
            tags: form.tags,
            mergeSources: form.mergeSources,
            userAgent: form.userAgent.isEmpty ? nil : form.userAgent,
            passThroughUA: form.passThroughUA,
            proxy: form.proxy.isEmpty ? nil : form.proxy,
            subUserinfo: form.subUserinfo.isEmpty ? nil : form.subUserinfo,
            remark: form.remark.isEmpty ? nil : form.remark,
            priority: form.priority,
            isEnabled: form.isEnabled,
            ignoreFailed: form.ignoreFailed,
            subscriptionTags: form.subscriptionTags,
            createdAt: subscription?.createdAt ?? Date(),
            updatedAt: Date(),
            flow: subscription?.flow
        )
        
        onSave(newSubscription)
        dismiss()
    }
}

// MARK: - 订阅表单模型
struct SubscriptionForm {
    var name: String = ""
    var displayName: String = ""
    var url: String = ""
    var content: String = ""
    var source: SubscriptionSource = .remote
    var icon: String = ""
    var isIconColor: Bool = true
    var tags: [String] = []
    var mergeSources: MergeSources = .none
    var userAgent: String = ""
    var passThroughUA: Bool = false
    var proxy: String = ""
    var subUserinfo: String = ""
    var remark: String = ""
    var priority: Int = 0
    var isEnabled: Bool = true
    var ignoreFailed: Bool = false
    var subscriptionTags: [String] = []
    
    var iconURL: URL? {
        guard !icon.isEmpty else { return nil }
        return URL(string: icon)
    }
    
    init() {}
    
    init(from subscription: Subscription) {
        self.name = subscription.name
        self.displayName = subscription.displayName ?? ""
        self.url = subscription.url ?? ""
        self.content = subscription.content ?? ""
        self.source = subscription.source
        self.icon = subscription.icon ?? ""
        self.isIconColor = subscription.isIconColor
        self.tags = subscription.tags
        self.mergeSources = subscription.mergeSources
        self.userAgent = subscription.userAgent ?? ""
        self.passThroughUA = subscription.passThroughUA
        self.proxy = subscription.proxy ?? ""
        self.subUserinfo = subscription.subUserinfo ?? ""
        self.remark = subscription.remark ?? ""
        self.priority = subscription.priority
        self.isEnabled = subscription.isEnabled
        self.ignoreFailed = subscription.ignoreFailed
        self.subscriptionTags = subscription.subscriptionTags
    }
}

// MARK: - 图标选择器
struct IconPickerView: View {
    @Binding var selectedIcon: String
    @Binding var isColorIcon: Bool
    @Environment(\.dismiss) private var dismiss
    
    private let commonIcons = [
        "https://example.com/icon1.png",
        "https://example.com/icon2.png",
        "https://example.com/icon3.png"
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // 彩色图标开关
                Toggle("彩色图标", isOn: $isColorIcon)
                    .padding(.horizontal)
                
                // 图标网格
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                    ForEach(commonIcons, id: \.self) { iconURL in
                        IconSelectionCell(
                            iconURL: iconURL,
                            isSelected: selectedIcon == iconURL,
                            isColorIcon: isColorIcon
                        ) {
                            selectedIcon = iconURL
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // 自定义图标输入
                VStack(alignment: .leading, spacing: 8) {
                    Text("自定义图标链接")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("请输入图标链接", text: $selectedIcon)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .padding(.horizontal)
            }
            .navigationTitle("选择图标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 图标选择单元格
struct IconSelectionCell: View {
    let iconURL: String
    let isSelected: Bool
    let isColorIcon: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            AsyncImage(url: URL(string: iconURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .saturation(isColorIcon ? 1.0 : 0.0)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
            }
            .frame(width: 60, height: 60)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 标签选择器
struct TagPickerView: View {
    @Binding var selectedTags: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var newTag: String = ""
    
    private let commonTags = ["机场", "免费", "付费", "高速", "稳定", "国外", "国内"]
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // 新建标签
                VStack(alignment: .leading, spacing: 8) {
                    Text("新建标签")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        TextField("输入标签名称", text: $newTag)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("添加") {
                            addNewTag()
                        }
                        .disabled(newTag.isEmpty || selectedTags.contains(newTag))
                    }
                }
                .padding(.horizontal)
                
                // 常用标签
                VStack(alignment: .leading, spacing: 8) {
                    Text("常用标签")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(commonTags, id: \.self) { tag in
                            TagSelectionCell(
                                tag: tag,
                                isSelected: selectedTags.contains(tag)
                            ) {
                                toggleTag(tag)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // 已选择的标签
                if !selectedTags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("已选择的标签")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(selectedTags, id: \.self) { tag in
                                SelectedTagCell(tag: tag) {
                                    removeTag(tag)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("选择标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addNewTag() {
        let trimmedTag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTag.isEmpty && !selectedTags.contains(trimmedTag) {
            selectedTags.append(trimmedTag)
            newTag = ""
        }
    }
    
    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            removeTag(tag)
        } else {
            selectedTags.append(tag)
        }
    }
    
    private func removeTag(_ tag: String) {
        selectedTags.removeAll { $0 == tag }
    }
}

// MARK: - 标签选择单元格
struct TagSelectionCell: View {
    let tag: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(tag)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 已选择标签单元格
struct SelectedTagCell: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
                .foregroundColor(.white)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.accentColor)
        .clipShape(Capsule())
    }
}

// MARK: - 内容编辑器
struct ContentEditorView: View {
    @Binding var content: String
    let title: String
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                // 工具栏
                HStack {
                    Button("格式化") {
                        // 实现内容格式化
                    }
                    .foregroundColor(.accentColor)
                    
                    Spacer()
                    
                    Text("\(content.count) 字符")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                
                // 编辑器
                TextEditor(text: $content)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - 高级编辑器
struct AdvancedEditorView: View {
    @Binding var form: SubscriptionForm
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("网络设置") {
                    TextField("超时时间（秒）", value: .constant(30), format: .number)
                    TextField("重试次数", value: .constant(3), format: .number)
                    Toggle("跳过证书验证", isOn: .constant(false))
                }
                
                Section("解析设置") {
                    TextField("包含节点正则", text: .constant(""))
                    TextField("排除节点正则", text: .constant(""))
                    Toggle("启用UDP", isOn: .constant(true))
                    Toggle("启用TFO", isOn: .constant(false))
                }
                
                Section("其他设置") {
                    TextField("自定义参数", text: .constant(""))
                    TextField("扩展配置", text: .constant(""))
                }
            }
            .navigationTitle("高级设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SubEditorView(subscription: nil) { _ in }
        .environmentObject(ThemeManager())
}