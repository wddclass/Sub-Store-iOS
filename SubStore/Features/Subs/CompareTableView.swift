import SwiftUI

// MARK: - 节点信息模型
struct NodeInfo: Codable, Identifiable {
    let id: String
    let name: String
    let type: String
    let server: String?
    let port: Int?
    let localPort: Int?
    let udp: Bool?
    let tfo: Bool?
    let fastOpen: Bool?
    let skipCertVerify: Bool?
    let aead: Bool?
    let addresses: [String]?
    
    // 其他动态属性
    let extraProperties: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, server, port, udp, tfo, aead, addresses, extraProperties
        case localPort = "local-port"
        case fastOpen = "fast-open"
        case skipCertVerify = "skip-cert-verify"
    }
    
    var displayServer: String {
        return server ?? addresses?.joined(separator: ",") ?? ""
    }
    
    var displayPort: String {
        return "\(port ?? localPort ?? 0)"
    }
    
    var hasTFO: Bool {
        return tfo == true || fastOpen == true
    }
}

// MARK: - IP API 数据模型
struct IPApiData: Codable {
    let shareUrl: String
    let info: IPInfo
    
    struct IPInfo: Codable {
        let query: String
        let city: String
        let country: String
        let isp: String
        let org: String
        let timezone: String
        let lat: Double
        let lon: Double
    }
}

// MARK: - 对比数据模型
struct CompareData {
    let processed: [NodeInfo]
    let original: [NodeInfo]
    let name: String
}

// MARK: - 节点对比表格视图
struct CompareTableView: View {
    let compareData: CompareData
    @Binding var isPresented: Bool
    
    @State private var isProcessedVisible = true
    @State private var isOriginalVisible = true
    @State private var showingNodeInfo = false
    @State private var selectedNode: NodeInfo?
    @State private var selectedIPApiData: IPApiData?
    @State private var isLoadingNodeInfo = false
    
    private let columnTitles = ["名称", "UDP", "TFO", "跳过证书", "AEAD"]
    
    private var displayName: String {
        // 这里可以从订阅管理器获取显示名称
        return compareData.name
    }
    
    private var pairedData: [(processed: NodeInfo?, original: NodeInfo?)] {
        var result: [(processed: NodeInfo?, original: NodeInfo?)] = []
        var remainingOriginal = compareData.original
        
        // 配对处理后和原始节点
        for processed in compareData.processed {
            if let originalIndex = remainingOriginal.firstIndex(where: { $0.id == processed.id }) {
                let original = remainingOriginal.remove(at: originalIndex)
                result.append((processed: processed, original: original))
            } else {
                result.append((processed: processed, original: nil))
            }
        }
        
        return result
    }
    
    private var remainingOriginal: [NodeInfo] {
        let processedIds = Set(compareData.processed.map { $0.id })
        return compareData.original.filter { !processedIds.contains($0.id) }
    }
    
    private var remainDesc: String {
        let remainSize = compareData.processed.count
        let filterSize = remainingOriginal.count
        let totalSize = remainSize + filterSize
        
        if remainSize == 0 {
            return "0"
        }
        return filterSize > 0 ? "\(remainSize)/\(totalSize)" : "\(remainSize)"
    }
    
    private var filterDesc: String {
        let remainSize = compareData.processed.count
        let filterSize = remainingOriginal.count
        let totalSize = remainSize + filterSize
        
        if filterSize == 0 {
            return "0"
        }
        return remainSize > 0 ? "\(filterSize)/\(totalSize)" : "\(filterSize)"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // 保留节点部分
                    remainingNodesSection
                    
                    // 分隔线
                    if !remainingOriginal.isEmpty {
                        Divider()
                            .padding(.vertical, 20)
                            .overlay(
                                Text("被过滤的节点")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .background(Color(UIColor.systemBackground))
                                    .padding(.horizontal, 16)
                            )
                        
                        // 过滤节点部分
                        filteredNodesSection
                    }
                }
            }
            .navigationTitle("节点预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                }
            }
        }
        .sheet(isPresented: $showingNodeInfo) {
            if let node = selectedNode {
                NodeInfoView(
                    nodeInfo: node,
                    ipApiData: selectedIPApiData,
                    isPresented: $showingNodeInfo
                )
            }
        }
    }
    
    // MARK: - 保留节点部分
    private var remainingNodesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题和控制
            HStack {
                Text("保留节点(\(remainDesc))")
                    .font(.title3)
                    .fontWeight(.bold)
                
                if !remainingOriginal.isEmpty {
                    Button("过滤节点(\(filterDesc))") {
                        // 滚动到过滤节点部分
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            // 显示控制指示器
            HStack {
                Button(action: toggleProcessedVisible) {
                    HStack {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("处理后")
                            .font(.caption)
                    }
                }
                .foregroundColor(isProcessedVisible ? .primary : .secondary)
                
                Button(action: toggleOriginalVisible) {
                    HStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                        Text("原始")
                            .font(.caption)
                    }
                }
                .foregroundColor(isOriginalVisible ? .primary : .secondary)
                
                Spacer()
            }
            .padding(.horizontal)
            
            // 表格头
            tableHeader
            
            // 表格内容
            LazyVStack(spacing: 0) {
                ForEach(Array(pairedData.enumerated()), id: \.offset) { index, pair in
                    VStack(spacing: 0) {
                        // 处理后的节点
                        if isProcessedVisible, let processed = pair.processed {
                            nodeRow(node: processed, isProcessed: true)
                                .onTapGesture {
                                    loadNodeInfo(for: processed)
                                }
                        }
                        
                        // 原始节点
                        if isOriginalVisible, let original = pair.original {
                            nodeRow(node: original, isProcessed: false)
                                .onTapGesture {
                                    loadNodeInfo(for: original)
                                }
                        }
                        
                        if index < pairedData.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 过滤节点部分
    private var filteredNodesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Text("过滤节点(\(filterDesc))")
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)
            
            // 表格头
            tableHeader
            
            // 表格内容
            LazyVStack(spacing: 0) {
                ForEach(Array(remainingOriginal.enumerated()), id: \.offset) { index, node in
                    nodeRow(node: node, isProcessed: false)
                        .onTapGesture {
                            loadNodeInfo(for: node)
                        }
                    
                    if index < remainingOriginal.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
        }
    }
    
    // MARK: - 表格头
    private var tableHeader: some View {
        HStack {
            Text("名称")
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(columnTitles.dropFirst(), id: \.self) { title in
                Text(title)
                    .frame(width: 60)
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemGroupedBackground))
    }
    
    // MARK: - 节点行
    private func nodeRow(node: NodeInfo, isProcessed: Bool) -> some View {
        HStack {
            // 名称列
            HStack {
                Circle()
                    .fill(isProcessed ? Color.orange : Color.accentColor)
                    .frame(width: 6, height: 6)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(node.type.uppercased())
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                        
                        Text(node.name)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                    }
                    
                    Text("\(node.displayServer):\(node.displayPort)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 属性列
            checkboxColumn(isChecked: node.udp == true)
            checkboxColumn(isChecked: node.hasTFO)
            checkboxColumn(isChecked: node.skipCertVerify == true)
            checkboxColumn(isChecked: node.aead == true)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    // MARK: - 复选框列
    private func checkboxColumn(isChecked: Bool) -> some View {
        Group {
            if isChecked {
                Image(systemName: "checkmark")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 1)
                    .cornerRadius(1)
            }
        }
        .frame(width: 60)
    }
    
    // MARK: - 方法
    private func toggleProcessedVisible() {
        if isProcessedVisible && !isOriginalVisible {
            isOriginalVisible = true
        } else if isProcessedVisible && isOriginalVisible {
            isOriginalVisible = false
        } else if !isProcessedVisible && isOriginalVisible {
            isProcessedVisible = true
            isOriginalVisible = false
        }
    }
    
    private func toggleOriginalVisible() {
        if !isProcessedVisible && isOriginalVisible {
            isProcessedVisible = true
        } else if isProcessedVisible && isOriginalVisible {
            isProcessedVisible = false
        } else if isProcessedVisible && !isOriginalVisible {
            isProcessedVisible = false
            isOriginalVisible = true
        }
    }
    
    private func loadNodeInfo(for node: NodeInfo) {
        guard !isLoadingNodeInfo else { return }
        
        isLoadingNodeInfo = true
        selectedNode = node
        
        // 模拟API调用获取节点信息
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // 这里应该调用实际的API
            selectedIPApiData = IPApiData(
                shareUrl: "vmess://example", // 这里需要根据节点生成实际的分享链接
                info: IPApiData.IPInfo(
                    query: "192.168.1.1",
                    city: "Unknown",
                    country: "Unknown",
                    isp: "Unknown ISP",
                    org: "Unknown Org",
                    timezone: "UTC",
                    lat: 0.0,
                    lon: 0.0
                )
            )
            
            isLoadingNodeInfo = false
            showingNodeInfo = true
        }
    }
}

// MARK: - 节点信息详情视图
struct NodeInfoView: View {
    let nodeInfo: NodeInfo
    let ipApiData: IPApiData?
    @Binding var isPresented: Bool
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // 节点信息
                nodeInfoTab
                    .tabItem {
                        Label("节点信息", systemImage: "server.rack")
                    }
                    .tag(0)
                
                // IP 信息
                if let ipData = ipApiData {
                    ipInfoTab(ipData)
                        .tabItem {
                            Label("IP 信息", systemImage: "globe")
                        }
                        .tag(1)
                }
                
                // JSON 信息
                jsonInfoTab
                    .tabItem {
                        Label("JSON", systemImage: "doc.text")
                    }
                    .tag(2)
            }
            .navigationTitle("节点详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    // MARK: - 节点信息标签页
    private var nodeInfoTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 节点名称
                HStack {
                    Text(nodeInfo.type.uppercased())
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    
                    Text(nodeInfo.name)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // 节点属性
                LazyVStack(alignment: .leading, spacing: 12) {
                    infoRow("服务器", value: nodeInfo.displayServer)
                    infoRow("端口", value: nodeInfo.displayPort)
                    
                    if let udp = nodeInfo.udp {
                        infoRow("UDP 支持", value: udp ? "是" : "否")
                    }
                    
                    if nodeInfo.hasTFO {
                        infoRow("TCP Fast Open", value: "是")
                    }
                    
                    if let skipCert = nodeInfo.skipCertVerify {
                        infoRow("跳过证书验证", value: skipCert ? "是" : "否")
                    }
                    
                    if let aead = nodeInfo.aead {
                        infoRow("AEAD 加密", value: aead ? "是" : "否")
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - IP 信息标签页
    private func ipInfoTab(_ ipData: IPApiData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 节点名称
                Text(nodeInfo.name)
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                // IP 信息
                LazyVStack(alignment: .leading, spacing: 12) {
                    infoRow("IP 地址", value: ipData.info.query)
                    infoRow("地区", value: "\(ipData.info.country) - \(ipData.info.city)")
                    infoRow("ISP", value: ipData.info.isp)
                    infoRow("组织", value: ipData.info.org)
                    infoRow("时区", value: ipData.info.timezone)
                    infoRow("位置", value: "经度 \(ipData.info.lon) - 纬度 \(ipData.info.lat)")
                }
                .padding(.horizontal)
                
                // 二维码
                if selectedTab == 1 {
                    VStack {
                        Text("分享二维码")
                            .font(.headline)
                            .padding(.top)
                        
                        // 这里可以添加二维码生成
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 120)
                            .overlay(
                                VStack {
                                    Image(systemName: "qrcode")
                                        .font(.title)
                                    Text("二维码")
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                            )
                    }
                    .padding()
                }
            }
        }
    }
    
    // MARK: - JSON 信息标签页
    private var jsonInfoTab: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("节点 JSON 配置")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)
                
                // JSON 显示区域
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(formatNodeInfoAsJSON())
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - 辅助方法
    private func infoRow(_ key: String, value: String) -> some View {
        HStack {
            Text(key)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(":")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
    
    private func formatNodeInfoAsJSON() -> String {
        // 这里应该实现实际的 JSON 格式化
        return """
        {
          "id": "\(nodeInfo.id)",
          "name": "\(nodeInfo.name)",
          "type": "\(nodeInfo.type)",
          "server": "\(nodeInfo.server ?? "")",
          "port": \(nodeInfo.port ?? 0)
        }
        """
    }
}

#Preview {
    CompareTableView(
        compareData: CompareData(
            processed: [
                NodeInfo(
                    id: "1",
                    name: "测试节点1",
                    type: "vmess",
                    server: "example.com",
                    port: 443,
                    localPort: nil,
                    udp: true,
                    tfo: true,
                    fastOpen: nil,
                    skipCertVerify: false,
                    aead: true,
                    addresses: nil,
                    extraProperties: nil
                )
            ],
            original: [
                NodeInfo(
                    id: "2",
                    name: "测试节点2",
                    type: "ss",
                    server: "test.com",
                    port: 8080,
                    localPort: nil,
                    udp: false,
                    tfo: false,
                    fastOpen: nil,
                    skipCertVerify: true,
                    aead: false,
                    addresses: nil,
                    extraProperties: nil
                )
            ],
            name: "测试订阅"
        ),
        isPresented: .constant(true)
    )
}