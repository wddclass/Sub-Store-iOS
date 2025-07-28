import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedTab = 0
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 简化的测试视图
            VStack {
                Text("订阅管理")
                    .font(.title)
                Text("应用启动成功！")
                    .foregroundColor(.green)
            }
            .tabItem {
                Image(systemName: "link.circle")
                Text("订阅")
            }
            .tag(0)
            
            VStack {
                Text("规则管理")
                    .font(.title)
                Text("Core Data: \(networkMonitor.isConnected ? "已连接" : "未连接")")
                    .foregroundColor(.blue)
            }
            .tabItem {
                Image(systemName: "doc.text")
                Text("规则")
            }
            .tag(1)
            
            VStack {
                Text("设置")
                    .font(.title)
                Button("测试主题") {
                    themeManager.setTheme(.dark)
                }
            }
            .tabItem {
                Image(systemName: "gearshape")
                Text("设置")
            }
            .tag(2)
        }
        .accentColor(themeManager.accentColor)
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager())
        .environmentObject(SettingsManager())
}