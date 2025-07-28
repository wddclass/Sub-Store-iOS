import SwiftUI
import Combine

// MARK: - 后端连接配置视图
struct BackendConfigView: View {
    @Binding var isPresented: Bool
    @State private var magicPath: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    @State private var showingError: Bool = false
    @State private var inputType: InputType = .path
    
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    
    enum InputType {
        case path      // 仅路径
        case host      // 主机+路径
        case full      // 完整URL
    }
    
    private var previewURL: String {
        let input = magicPath.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if input.isEmpty {
            return ""
        }
        
        if input.contains("://") {
            // 完整URL
            inputType = .full
            return input
        } else if input.matches(regex: #"^\d+\.\d+\.\d+\.\d+(:\d+)?$"#) || input.hasPrefix("localhost") {
            // IP地址或localhost
            inputType = .host
            let cleanInput = input.hasPrefix("localhost") ? input : input
            return "http://\(cleanInput)"
        } else {
            // 仅路径
            inputType = .path
            return "\(currentOrigin)/\(input)"
        }
    }
    
    private var currentOrigin: String {
        return settingsManager.currentHost ?? "http://localhost:3001"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 标题和描述
                VStack(spacing: 16) {
                    Text("后端连接配置")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("请输入 Sub-Store 后端服务地址，支持完整URL、IP地址或路径")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // 错误信息
                if !errorMessage.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // 输入框
                VStack(alignment: .leading, spacing: 12) {
                    TextField("输入后端地址", text: $magicPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        #if canImport(UIKit)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        #endif
                        .onSubmit {
                            handleConnect()
                        }
                    
                    // 实时预览
                    if !magicPath.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("预览:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Text(previewURL)
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                            
                            Text(inputTypeDescription)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // 操作按钮
                VStack(spacing: 12) {
                    Button(action: handleConnect) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            }
                            Text("连接")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(magicPath.isEmpty ? Color.gray : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(magicPath.isEmpty || isLoading)
                    
                    Button("跳过") {
                        handleSkip()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.clear)
                    .foregroundColor(.accentColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor, lineWidth: 1)
                    )
                }
                
                // 帮助信息
                VStack(spacing: 8) {
                    Text("提示:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• 支持完整URL: http://example.com:3001")
                        Text("• 支持IP地址: 192.168.1.100:3001")
                        Text("• 支持相对路径: api/v1")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
                .padding(.bottom)
            }
            .padding(.horizontal, 24)
            .navigationBarHidden(true)
        }
        .alert("连接失败", isPresented: $showingError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var inputTypeDescription: String {
        switch inputType {
        case .path:
            return "相对路径模式"
        case .host:
            return "主机地址模式"
        case .full:
            return "完整URL模式"
        }
    }
    
    private func handleConnect() {
        guard !magicPath.isEmpty else { return }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let success = try await testConnection()
                
                await MainActor.run {
                    if success {
                        // 保存配置
                        settingsManager.setBackendHost(previewURL)
                        settingsManager.setBackendConfigured(true)
                        
                        // 关闭对话框
                        isPresented = false
                    } else {
                        errorMessage = "连接失败，请检查地址是否正确"
                        showingError = true
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "连接错误: \(error.localizedDescription)"
                    showingError = true
                    isLoading = false
                }
            }
        }
    }
    
    private func handleSkip() {
        settingsManager.setBackendConfigured(true)
        isPresented = false
    }
    
    private func testConnection() async throws -> Bool {
        let urlString = previewURL + "/api/utils/env"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return false
        }
        
        // 验证响应格式
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = json["status"] as? String,
           status == "success" {
            return true
        }
        
        return false
    }
}

// MARK: - String扩展
extension String {
    func matches(regex: String) -> Bool {
        let predicate = NSPredicate(format: "SELF MATCHES %@", regex)
        return predicate.evaluate(with: self)
    }
}

#Preview {
    BackendConfigView(isPresented: .constant(true))
        .environmentObject(SettingsManager())
}