import Foundation
import SwiftUI
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 日志管理器
class Logger {
    enum Level: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }
    
    static let shared = Logger()
    private let dateFormatter: DateFormatter
    
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }
    
    func log(_ message: String, level: Level = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(function) - \(message)"
        
        #if DEBUG
        print(logMessage)
        #endif
        
        // 在生产环境中，可以将日志发送到远程服务器或本地文件
    }
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
}

// MARK: - 存储管理器
class StorageManager {
    static let shared = StorageManager()
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - Generic Methods
    func set<T>(_ value: T, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
    
    func get<T>(_ type: T.Type, forKey key: String) -> T? {
        return userDefaults.object(forKey: key) as? T
    }
    
    func remove(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
    
    // MARK: - Codable Support
    func setCodable<T: Codable>(_ value: T, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            userDefaults.set(data, forKey: key)
        } catch {
            Logger.shared.error("Failed to encode value for key \(key): \(error)")
        }
    }
    
    func getCodable<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            Logger.shared.error("Failed to decode value for key \(key): \(error)")
            return nil
        }
    }
}

// MARK: - 验证工具
struct ValidationUtils {
    /// 验证订阅URL格式
    static func isValidSubscriptionURL(_ url: String) -> Bool {
        guard !url.trimmed.isEmpty else { return false }
        guard let nsURL = URL(string: url) else { return false }
        return nsURL.scheme == "http" || nsURL.scheme == "https"
    }
    
    /// 验证订阅名称
    static func isValidSubscriptionName(_ name: String) -> Bool {
        let trimmed = name.trimmed
        return !trimmed.isEmpty && trimmed.count <= 50
    }
    
    /// 验证GitHub Token格式
    static func isValidGitHubToken(_ token: String) -> Bool {
        let trimmed = token.trimmed
        // GitHub Personal Access Token 通常以 ghp_ 开头，长度为40个字符
        return trimmed.hasPrefix("ghp_") && trimmed.count == 40
    }
    
    /// 验证Gist ID格式
    static func isValidGistID(_ gistID: String) -> Bool {
        let trimmed = gistID.trimmed
        // Gist ID 通常是32个字符的十六进制字符串
        return trimmed.count == 32 && trimmed.allSatisfy { $0.isHexDigit }
    }
}

// MARK: - 网络状态监测
import Network

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = true
    @Published var connectionType: NWInterface.InterfaceType?
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - 错误处理
enum AppError: LocalizedError {
    case networkError(String)
    case dataParsingError(String)
    case validationError(String)
    case storageError(String)
    case syncError(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "网络错误: \(message)"
        case .dataParsingError(let message):
            return "数据解析错误: \(message)"
        case .validationError(let message):
            return "验证错误: \(message)"
        case .storageError(let message):
            return "存储错误: \(message)"
        case .syncError(let message):
            return "同步错误: \(message)"
        case .unknownError(let message):
            return "未知错误: \(message)"
        }
    }
}

// MARK: - 加密工具
struct CryptoUtils {
    /// 生成MD5哈希
    static func md5(string: String) -> String {
        let digest = Insecure.MD5.hash(data: string.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    /// 生成SHA256哈希
    static func sha256(string: String) -> String {
        let digest = SHA256.hash(data: string.data(using: .utf8) ?? Data())
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// 生成随机字符串
    static func randomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
}

// MARK: - 设备信息工具
struct DeviceUtils {
    /// 获取设备型号
    static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String.init(validatingUTF8: ptr)
            }
        }
        return modelCode ?? "Unknown"
    }
    
    /// 获取iOS版本
    static var iOSVersion: String {
        #if canImport(UIKit)
        return UIDevice.current.systemVersion
        #else
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }
    
    /// 获取应用版本
    static var appVersion: String {
        return Bundle.main.appVersion
    }
    
    /// 检查是否为iPad
    static var isPad: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
    
    /// 检查是否为iPhone
    static var isPhone: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }
}