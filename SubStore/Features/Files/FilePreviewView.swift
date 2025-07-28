import SwiftUI
import UniformTypeIdentifiers

// MARK: - 文件预览数据模型
struct FilePreviewData {
    let processed: String?
    let original: String?
    let name: String
    let url: String?
    
    init(processed: String? = nil, original: String? = nil, name: String, url: String? = nil) {
        self.processed = processed
        self.original = original
        self.name = name
        self.url = url
    }
}

// MARK: - 文件预览视图
struct FilePreviewView: View {
    let previewData: FilePreviewData
    @Binding var isPresented: Bool
    
    @State private var content: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingCopyAlert = false
    @State private var showingExportSheet = false
    @State private var isEditing = false
    @State private var editableContent: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // URL 信息区域（如果有URL）
                if let url = previewData.url {
                    urlInfoSection(url)
                }
                
                // 内容编辑器
                contentEditor
            }
            .navigationTitle("文件预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    if previewData.url == nil {
                        Button("关闭") {
                            isPresented = false
                        }
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingExportSheet = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(content.isEmpty)
                    
                    if previewData.url == nil {
                        Button(isEditing ? "完成" : "编辑") {
                            toggleEditMode()
                        }
                    }
                }
            }
        }
        .onAppear {
            loadContent()
        }
        .alert("复制成功", isPresented: $showingCopyAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            if let url = previewData.url {
                Text("链接已复制到剪贴板：\n\(url)")
            } else {
                Text("内容已复制到剪贴板")
            }
        }
        .alert("加载错误", isPresented: .constant(errorMessage != nil)) {
            Button("确定", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            exportSheet
        }
    }
    
    // MARK: - URL 信息区域
    private func urlInfoSection(_ url: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: {
                    copyToClipboard(url)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.caption)
                        Text("点击复制，在外部资源中使用："
                        )
                            .font(.caption)
                    }
                    .foregroundColor(.accentColor)
                }
                
                Spacer()
            }
            
            Button(action: {
                copyToClipboard(url)
            }) {
                HStack {
                    Text(url)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .underline()
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(UIColor.separator)),
            alignment: .bottom
        )
    }
    
    // MARK: - 内容编辑器
    private var contentEditor: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer()
            } else {
                if isEditing {
                    TextEditor(text: $editableContent)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                } else {
                    ScrollView {
                        HStack {
                            Text(content)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer()
                        }
                        .padding()
                    }
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
    
    // MARK: - 导出界面
    private var exportSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                    
                    Text("导出文件")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("选择导出方式")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 12) {
                    exportButton(
                        title: "复制到剪贴板",
                        systemImage: "doc.on.clipboard",
                        action: {
                            copyToClipboard(content)
                            showingExportSheet = false
                        }
                    )
                    
                    exportButton(
                        title: "保存到文件",
                        systemImage: "square.and.arrow.down",
                        action: {
                            saveToFiles()
                        }
                    )
                    
                    if let url = previewData.url {
                        exportButton(
                            title: "复制链接",
                            systemImage: "link",
                            action: {
                                copyToClipboard(url)
                                showingExportSheet = false
                            }
                        )
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("导出")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        showingExportSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - 导出按钮
    private func exportButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - 方法
    private func loadContent() {
        if let url = previewData.url {
            loadFromURL(url)
        } else if let processed = previewData.processed {
            content = processed
            editableContent = processed
        } else if let original = previewData.original {
            content = original
            editableContent = original
        }
    }
    
    private func loadFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            errorMessage = "无效的URL"
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                await MainActor.run {
                    if let string = String(data: data, encoding: .utf8) {
                        content = string
                        editableContent = string
                    } else {
                        errorMessage = "无法解析文件内容"
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "加载失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func toggleEditMode() {
        if isEditing {
            // 保存编辑内容
            content = editableContent
        }
        isEditing.toggle()
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        showingCopyAlert = true
    }
    
    private func saveToFiles() {
        let fileName = "\(previewData.name).txt"
        let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try content.write(to: temporaryURL, atomically: true, encoding: .utf8)
            
            let activityViewController = UIActivityViewController(
                activityItems: [temporaryURL],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController?.present(activityViewController, animated: true)
            }
            
            showingExportSheet = false
        } catch {
            errorMessage = "保存失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - 代码语法高亮视图（简化版）
struct CodeHighlightView: View {
    let code: String
    let language: String?
    
    var body: some View {
        ScrollView {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(code.components(separatedBy: "\n").enumerated()), id: \.offset) { lineNumber, line in
                        HStack(alignment: .top, spacing: 8) {
                            // 行号
                            Text("\(lineNumber + 1)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .trailing)
                            
                            // 代码内容
                            Text(line.isEmpty ? " " : line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                Spacer()
            }
            .padding()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - 文件类型识别
extension FilePreviewView {
    private func detectFileType(_ content: String) -> String? {
        // 简单的文件类型检测
        if content.hasPrefix("{") || content.hasPrefix("[") {
            return "json"
        } else if content.contains("<!DOCTYPE html") || content.contains("<html") {
            return "html"
        } else if content.contains("function ") || content.contains("const ") || content.contains("let ") {
            return "javascript"
        } else if content.contains("def ") || content.contains("import ") {
            return "python"
        }
        return nil
    }
}

#Preview {
    FilePreviewView(
        previewData: FilePreviewData(
            processed: """
            {
              "name": "测试配置",
              "rules": [
                {
                  "type": "DOMAIN",
                  "payload": "example.com",
                  "proxy": "DIRECT"
                }
              ]
            }
            """,
            name: "test-config",
            url: nil
        ),
        isPresented: Binding.constant(true)
    )
}