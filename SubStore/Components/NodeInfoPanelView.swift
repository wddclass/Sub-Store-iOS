import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - 节点信息面板视图
struct NodeInfoPanelView: View {
    let nodeInfo: NodeInfo
    let ipApiData: IPApiData?
    @Binding var isPresented: Bool
    
    @State private var selectedTab = 0
    @State private var qrCodeImage: UIImage?
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // 节点信息标签页
                nodeInfoTab
                    .tabItem {
                        Image(systemName: "server.rack")
                        Text("节点信息")
                    }
                    .tag(0)
                
                // IP 信息标签页
                if let ipData = ipApiData {
                    ipInfoTab(ipData)
                        .tabItem {
                            Image(systemName: "globe")
                            Text("IP 信息")
                        }
                        .tag(1)
                }
                
                // JSON 配置标签页
                jsonConfigTab
                    .tabItem {
                        Image(systemName: "doc.text")
                        Text("JSON")
                    }
                    .tag(ipApiData != nil ? 2 : 1)
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
        .onAppear {
            generateQRCode()
        }
    }
    
    // MARK: - 节点信息标签页
    private var nodeInfoTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 节点标题
                nodeHeaderView
                
                // 节点详细信息
                nodeDetailsView
                
                // 二维码（如果有分享链接）
                if selectedTab == 0, let qrImage = qrCodeImage {
                    qrCodeView(qrImage)
                }
            }
            .padding()
        }
    }
    
    // MARK: - 节点标题视图
    private var nodeHeaderView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 类型标签
                Text(nodeInfo.type.uppercased())
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                
                Spacer()
            }
            
            // 节点名称
            Text(nodeInfo.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(3)
        }
    }
    
    // MARK: - 节点详细信息视图
    private var nodeDetailsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(nodeInfoItems, id: \.key) { item in
                InfoRowView(key: item.key, value: item.value)
            }
        }
    }
    
    // MARK: - 计算节点信息项
    private var nodeInfoItems: [(key: String, value: String)] {
        var items: [(key: String, value: String)] = []
        
        // 基本信息
        if let server = nodeInfo.server {
            items.append((key: "服务器", value: server))
        }
        
        if let port = nodeInfo.port {
            items.append((key: "端口", value: "\(port)"))
        } else if let localPort = nodeInfo.localPort {
            items.append((key: "本地端口", value: "\(localPort)"))
        }
        
        if let addresses = nodeInfo.addresses, !addresses.isEmpty {
            items.append((key: "地址", value: addresses.joined(separator: ", ")))
        }
        
        // 功能支持
        if let udp = nodeInfo.udp {
            items.append((key: "UDP 支持", value: udp ? "是" : "否"))
        }
        
        if nodeInfo.hasTFO {
            items.append((key: "TCP Fast Open", value: "是"))
        }
        
        if let skipCert = nodeInfo.skipCertVerify {
            items.append((key: "跳过证书验证", value: skipCert ? "是" : "否"))
        }
        
        if let aead = nodeInfo.aead {
            items.append((key: "AEAD 加密", value: aead ? "是" : "否"))
        }
        
        return items
    }
    
    // MARK: - IP 信息标签页
    private func ipInfoTab(_ ipData: IPApiData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // IP 信息标题
                Text(nodeInfo.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                // IP 详细信息
                VStack(alignment: .leading, spacing: 12) {
                    InfoRowView(key: "IP 地址", value: ipData.info.query)
                    InfoRowView(key: "地区", value: cityString(from: ipData.info))
                    InfoRowView(key: "ISP", value: ipData.info.isp)
                    InfoRowView(key: "组织", value: ipData.info.org)
                    InfoRowView(key: "时区", value: ipData.info.timezone)
                    InfoRowView(
                        key: "位置",
                        value: "经度 \(ipData.info.lon) - 纬度 \(ipData.info.lat)"
                    )
                }
                .padding(.horizontal)
                
                // 二维码
                if selectedTab == 1, let qrImage = qrCodeImage {
                    qrCodeView(qrImage)
                }
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - JSON 配置标签页
    private var jsonConfigTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("节点 JSON 配置")
                    .font(.headline)
                    .padding(.horizontal)
                
                // JSON 内容
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(nodeInfoJSON)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                // 复制按钮
                Button(action: copyJSONToClipboard) {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                        Text("复制 JSON")
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - 二维码视图
    private func qrCodeView(_ qrImage: UIImage) -> some View {
        VStack(spacing: 12) {
            Text("分享二维码")
                .font(.headline)
            
            Image(uiImage: qrImage)
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .background(Color.white)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            Text("扫描二维码使用此节点")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - 辅助方法
    private func cityString(from info: IPApiData.IPInfo) -> String {
        return info.city == info.country ? info.city : "\(info.country) - \(info.city)"
    }
    
    private var nodeInfoJSON: String {
        // 创建一个简化的 JSON 表示
        var jsonDict: [String: Any] = [:]
        
        jsonDict["id"] = nodeInfo.id
        jsonDict["name"] = nodeInfo.name
        jsonDict["type"] = nodeInfo.type
        
        if let server = nodeInfo.server {
            jsonDict["server"] = server
        }
        
        if let port = nodeInfo.port {
            jsonDict["port"] = port
        }
        
        if let localPort = nodeInfo.localPort {
            jsonDict["local-port"] = localPort
        }
        
        if let addresses = nodeInfo.addresses {
            jsonDict["addresses"] = addresses
        }
        
        if let udp = nodeInfo.udp {
            jsonDict["udp"] = udp
        }
        
        if let tfo = nodeInfo.tfo {
            jsonDict["tfo"] = tfo
        }
        
        if let fastOpen = nodeInfo.fastOpen {
            jsonDict["fast-open"] = fastOpen
        }
        
        if let skipCert = nodeInfo.skipCertVerify {
            jsonDict["skip-cert-verify"] = skipCert
        }
        
        if let aead = nodeInfo.aead {
            jsonDict["aead"] = aead
        }
        
        // 转换为 JSON 字符串
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "JSON 生成失败"
        } catch {
            return "JSON 生成失败: \(error.localizedDescription)"
        }
    }
    
    private func generateQRCode() {
        guard let shareUrl = ipApiData?.shareUrl else { return }
        
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(shareUrl.utf8)
        
        if let outputImage = filter.outputImage {
            // 放大二维码图像以提高清晰度
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                qrCodeImage = UIImage(cgImage: cgImage)
            }
        }
    }
    
    private func copyJSONToClipboard() {
        UIPasteboard.general.string = nodeInfoJSON
        
        // 显示复制成功的通知
        NotificationHelper.showSuccess("已复制", content: "JSON 配置已复制到剪贴板")
    }
}

// MARK: - 信息行视图
struct InfoRowView: View {
    let key: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(key)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(":")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .textSelection(.enabled)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .cornerRadius(8)
    }
}

// MARK: - 浮动节点信息面板
struct FloatingNodeInfoPanel: View {
    let nodeInfo: NodeInfo
    let ipApiData: IPApiData?
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // 背景遮罩
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            // 面板内容
            NodeInfoPanelView(
                nodeInfo: nodeInfo,
                ipApiData: ipApiData,
                isPresented: $isPresented
            )
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 20)
            .padding()
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .scale.combined(with: .opacity)
            ))
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isPresented)
    }
}

#Preview {
    NodeInfoPanelView(
        nodeInfo: NodeInfo(
            id: "test-node-1",
            name: "测试节点",
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
        ),
        ipApiData: IPApiData(
            shareUrl: "vmess://example",
            info: IPApiData.IPInfo(
                query: "192.168.1.1",
                city: "Shanghai",
                country: "China",
                isp: "China Telecom",
                org: "CT-Shanghai",
                timezone: "Asia/Shanghai",
                lat: 31.2304,
                lon: 121.4737
            )
        ),
        isPresented: .constant(true)
    )
}