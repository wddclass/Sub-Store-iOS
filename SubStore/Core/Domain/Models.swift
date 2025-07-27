import Foundation

// MARK: - Subscription Model
struct Subscription: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var displayName: String?
    var url: String?
    var content: String?
    var source: SubscriptionSource
    var icon: String?
    var isIconColor: Bool
    var tags: [String]
    var mergeSources: MergeSources
    var userAgent: String?
    var passThroughUA: Bool
    var proxy: String?
    var subUserinfo: String?
    var remark: String?
    var priority: Int
    var isEnabled: Bool
    var ignoreFailed: Bool
    var subscriptionTags: [String]
    var createdAt: Date
    var updatedAt: Date
    var flow: FlowInfo?
    
    init(
        id: String = UUID().uuidString,
        name: String,
        displayName: String? = nil,
        url: String? = nil,
        content: String? = nil,
        source: SubscriptionSource = .remote,
        icon: String? = nil,
        isIconColor: Bool = true,
        tags: [String] = [],
        mergeSources: MergeSources = .none,
        userAgent: String? = nil,
        passThroughUA: Bool = false,
        proxy: String? = nil,
        subUserinfo: String? = nil,
        remark: String? = nil,
        priority: Int = 0,
        isEnabled: Bool = true,
        ignoreFailed: Bool = false,
        subscriptionTags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        flow: FlowInfo? = nil
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.url = url
        self.content = content
        self.source = source
        self.icon = icon
        self.isIconColor = isIconColor
        self.tags = tags
        self.mergeSources = mergeSources
        self.userAgent = userAgent
        self.passThroughUA = passThroughUA
        self.proxy = proxy
        self.subUserinfo = subUserinfo
        self.remark = remark
        self.priority = priority
        self.isEnabled = isEnabled
        self.ignoreFailed = ignoreFailed
        self.subscriptionTags = subscriptionTags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.flow = flow
    }
}

// MARK: - Subscription Source
enum SubscriptionSource: String, Codable, CaseIterable {
    case remote = "remote"
    case local = "local"
    
    var displayName: String {
        switch self {
        case .remote:
            return "远程订阅"
        case .local:
            return "本地内容"
        }
    }
}

// MARK: - Merge Sources
enum MergeSources: String, Codable, CaseIterable {
    case none = ""
    case localFirst = "localFirst"
    case remoteFirst = "remoteFirst"
    
    var displayName: String {
        switch self {
        case .none:
            return "不合并"
        case .localFirst:
            return "本地优先"
        case .remoteFirst:
            return "远程优先"
        }
    }
}

// MARK: - Subscription Type
enum SubscriptionType: String, Codable, CaseIterable {
    case single = "single"
    case collection = "collection"
    
    var displayName: String {
        switch self {
        case .single:
            return "单条订阅"
        case .collection:
            return "组合订阅"
        }
    }
}

// MARK: - Flow Information
struct FlowInfo: Codable, Hashable {
    let total: Int64?
    let used: Int64?
    let remaining: Int64?
    let percentage: Double?
    let resetDate: Date?
    let isUnlimited: Bool
    
    init(
        total: Int64? = nil,
        used: Int64? = nil,
        remaining: Int64? = nil,
        percentage: Double? = nil,
        resetDate: Date? = nil,
        isUnlimited: Bool = false
    ) {
        self.total = total
        self.used = used
        self.remaining = remaining
        self.percentage = percentage
        self.resetDate = resetDate
        self.isUnlimited = isUnlimited
    }
    
    var usedFormatted: String {
        guard let used = used else { return "未知" }
        return ByteCountFormatter.string(fromByteCount: used, countStyle: .binary)
    }
    
    var totalFormatted: String {
        guard let total = total else { return "未知" }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .binary)
    }
    
    var remainingFormatted: String {
        guard let remaining = remaining else { return "未知" }
        return ByteCountFormatter.string(fromByteCount: remaining, countStyle: .binary)
    }
}

// MARK: - Artifact Model
struct Artifact: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var type: ArtifactType
    var content: String
    var platform: String?
    var source: String?
    var syncURL: String?
    var tags: [String]
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date
    var lastSync: Date?
    
    init(
        id: String = UUID().uuidString,
        name: String,
        type: ArtifactType,
        content: String = "",
        platform: String? = nil,
        source: String? = nil,
        syncURL: String? = nil,
        tags: [String] = [],
        isEnabled: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastSync: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.content = content
        self.platform = platform
        self.source = source
        self.syncURL = syncURL
        self.tags = tags
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastSync = lastSync
    }
}

// MARK: - Artifact Type
enum ArtifactType: String, CaseIterable, Codable {
    case rewrite = "rewrite"
    case redirect = "redirect"
    case headerRewrite = "header_rewrite"
    case script = "script"
    case mitm = "mitm"
    case cron = "cron"
    case dns = "dns"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .rewrite:
            return "重写规则"
        case .redirect:
            return "重定向规则"
        case .headerRewrite:
            return "请求头重写"
        case .script:
            return "脚本规则"
        case .mitm:
            return "MITM 规则"
        case .cron:
            return "定时任务"
        case .dns:
            return "DNS 规则"
        case .general:
            return "通用配置"
        }
    }
    
    var iconName: String {
        switch self {
        case .rewrite:
            return "arrow.triangle.2.circlepath"
        case .redirect:
            return "arrow.turn.up.right"
        case .headerRewrite:
            return "text.and.command.macwindow"
        case .script:
            return "terminal"
        case .mitm:
            return "lock.shield"
        case .cron:
            return "clock"
        case .dns:
            return "network"
        case .general:
            return "gearshape"
        }
    }
    
    var codeLanguage: String {
        switch self {
        case .rewrite, .redirect, .headerRewrite, .mitm, .dns, .general:
            return "plaintext"
        case .script:
            return "javascript"
        case .cron:
            return "yaml"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .rewrite, .redirect, .headerRewrite, .mitm, .dns:
            return "txt"
        case .script:
            return "js"
        case .cron, .general:
            return "yaml"
        }
    }
}

// MARK: - File Model
struct SubStoreFile: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var type: FileType
    var content: String
    var size: Int64
    var language: String?
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var isReadOnly: Bool
    
    init(
        id: String = UUID().uuidString,
        name: String,
        type: FileType,
        content: String = "",
        size: Int64 = 0,
        language: String? = nil,
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isReadOnly: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.content = content
        self.size = size
        self.language = language
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isReadOnly = isReadOnly
    }
    
    var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - File Type
enum FileType: String, Codable, CaseIterable {
    case general = "general"
    case mihomoProfile = "mihomo-profile"
    case json = "json"
    case yaml = "yaml"
    case javascript = "javascript"
    case text = "text"
    
    var displayName: String {
        switch self {
        case .general:
            return "通用文件"
        case .mihomoProfile:
            return "Mihomo Profile"
        case .json:
            return "JSON"
        case .yaml:
            return "YAML"
        case .javascript:
            return "JavaScript"
        case .text:
            return "文本"
        }
    }
    
    var icon: String {
        switch self {
        case .general:
            return "doc"
        case .mihomoProfile:
            return "doc.text"
        case .json:
            return "doc.text.fill"
        case .yaml:
            return "doc.plaintext"
        case .javascript:
            return "doc.text"
        case .text:
            return "doc.plaintext.fill"
        }
    }
}

// MARK: - Share Model
struct Share: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var token: String
    var type: ShareType
    var targetID: String
    var targetName: String
    var expirationDate: Date?
    var isEnabled: Bool
    var accessCount: Int
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: String = UUID().uuidString,
        name: String,
        token: String = CryptoUtils.randomString(length: 32),
        type: ShareType,
        targetID: String,
        targetName: String,
        expirationDate: Date? = nil,
        isEnabled: Bool = true,
        accessCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.token = token
        self.type = type
        self.targetID = targetID
        self.targetName = targetName
        self.expirationDate = expirationDate
        self.isEnabled = isEnabled
        self.accessCount = accessCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var isExpired: Bool {
        guard let expirationDate = expirationDate else { return false }
        return Date() > expirationDate
    }
    
    var shareURL: String {
        return "\(AppConstants.API.defaultBaseURL)/api/share/\(token)"
    }
}

// MARK: - Share Type
enum ShareType: String, Codable, CaseIterable {
    case subscription = "subscription"
    case collection = "collection"
    case artifact = "artifact"
    case file = "file"
    
    var displayName: String {
        switch self {
        case .subscription:
            return "订阅"
        case .collection:
            return "组合订阅"
        case .artifact:
            return "规则"
        case .file:
            return "文件"
        }
    }
}