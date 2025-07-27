import Foundation
import SwiftUI

// MARK: - Bundle Extensions
extension Bundle {
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    var displayName: String {
        return infoDictionary?["CFBundleDisplayName"] as? String ?? "SubStore"
    }
}

// MARK: - String Extensions
extension String {
    /// 验证是否为有效的URL
    var isValidURL: Bool {
        guard let url = URL(string: self) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    
    /// 验证是否为有效的HTTP/HTTPS URL
    var isValidHTTPURL: Bool {
        guard let url = URL(string: self) else { return false }
        return url.scheme == "http" || url.scheme == "https"
    }
    
    /// 截取字符串
    func truncated(limit: Int, trailing: String = "...") -> String {
        return count > limit ? String(prefix(limit)) + trailing : self
    }
    
    /// 移除首尾空白字符
    var trimmed: String {
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 是否为空或只包含空白字符
    var isBlankOrEmpty: Bool {
        return trimmed.isEmpty
    }
}

// MARK: - Date Extensions
extension Date {
    /// 格式化为相对时间字符串
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// 格式化为短日期字符串
    var shortFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    /// 格式化为详细日期时间字符串
    var detailFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

// MARK: - View Extensions
extension View {
    /// 条件修饰符
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// 隐藏视图但保持布局
    @ViewBuilder
    func hidden(_ hidden: Bool) -> some View {
        if hidden {
            self.opacity(0)
        } else {
            self
        }
    }
    
    /// 添加圆角和阴影
    func cardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(AppConstants.UI.cornerRadius)
            .shadow(radius: AppConstants.UI.shadowRadius)
    }
    
    /// 触觉反馈
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.onTapGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: style)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
    }
}

// MARK: - Color Extensions
extension Color {
    /// 从十六进制字符串创建颜色
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// 转换为十六进制字符串
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)
        
        if components.count >= 4 {
            a = Float(components[3])
        }
        
        if a != Float(1.0) {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(a * 255), lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
}

// MARK: - Array Extensions
extension Array {
    /// 安全访问数组元素
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
    
    /// 移除符合条件的元素
    mutating func removeAll(where predicate: (Element) throws -> Bool) rethrows {
        self = try filter { try !predicate($0) }
    }
}

// MARK: - URL Extensions
extension URL {
    /// 获取URL的域名
    var domainName: String? {
        return host?.replacingOccurrences(of: "www.", with: "")
    }
    
    /// 验证URL是否可达
    func isReachable(completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: self)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5.0
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            completion(response != nil)
        }.resume()
    }
}

// MARK: - FlowInfo Extensions
extension FlowInfo {
    /// 格式化使用流量
    var usedFormatted: String {
        return ByteFormatter.formatted(bytes: used)
    }
    
    /// 格式化总流量
    var totalFormatted: String {
        return isUnlimited ? "无限制" : ByteFormatter.formatted(bytes: total)
    }
    
    /// 格式化剩余流量
    var remainingFormatted: String {
        return isUnlimited ? "无限制" : ByteFormatter.formatted(bytes: remaining)
    }
    
    /// 使用百分比
    var percentage: Double? {
        guard !isUnlimited && total > 0 else { return nil }
        return (Double(used) / Double(total)) * 100.0
    }
    
    /// 剩余流量
    var remaining: Int64 {
        return isUnlimited ? Int64.max : max(0, total - used)
    }
    
    /// 流量状态
    var status: FlowStatus {
        guard !isUnlimited else { return .unlimited }
        
        let percentage = self.percentage ?? 0
        if percentage >= 90 {
            return .critical
        } else if percentage >= 70 {
            return .warning
        } else {
            return .normal
        }
    }
}

// MARK: - FlowStatus Enum
enum FlowStatus {
    case normal
    case warning
    case critical
    case unlimited
    
    var color: Color {
        switch self {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        case .unlimited: return .blue
        }
    }
    
    var description: String {
        switch self {
        case .normal: return "正常"
        case .warning: return "警告"
        case .critical: return "紧急"
        case .unlimited: return "无限制"
        }
    }
}

// MARK: - ByteFormatter
struct ByteFormatter {
    static func formatted(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - SubscriptionType Extensions
extension SubscriptionType {
    var displayName: String {
        switch self {
        case .single:
            return "单条订阅"
        case .collection:
            return "组合订阅"
        }
    }
    
    var iconName: String {
        switch self {
        case .single:
            return "link"
        case .collection:
            return "link.badge.plus"
        }
    }
}