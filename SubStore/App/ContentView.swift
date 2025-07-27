import SwiftUI

struct ContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var showingOnboarding = false
    @State private var isTabChanging = false
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    var body: some View {
        ZStack {
            // 主要内容
            TabView(selection: $selectedTab) {
                // 订阅管理
                SubsListView()
                    .tabItem {
                        AnimatedTabIcon(
                            systemName: "link.circle",
                            isSelected: selectedTab == 0,
                            text: "订阅"
                        )
                    }
                    .tag(0)
                
                // 规则管理
                ArtifactsListView()
                    .tabItem {
                        AnimatedTabIcon(
                            systemName: "doc.text",
                            isSelected: selectedTab == 1,
                            text: "规则"
                        )
                    }
                    .tag(1)
                
                // 文件管理
                FilesListView()
                    .tabItem {
                        AnimatedTabIcon(
                            systemName: "folder",
                            isSelected: selectedTab == 2,
                            text: "文件"
                        )
                    }
                    .tag(2)
                
                // 分享管理
                ShareListView()
                    .tabItem {
                        AnimatedTabIcon(
                            systemName: "square.and.arrow.up",
                            isSelected: selectedTab == 3,
                            text: "分享"
                        )
                    }
                    .tag(3)
                
                // 设置
                SettingsView()
                    .tabItem {
                        AnimatedTabIcon(
                            systemName: "gearshape",
                            isSelected: selectedTab == 4,
                            text: "设置"
                        )
                    }
                    .tag(4)
            }
            .accentColor(themeManager.accentColor)
            .onAppear {
                setupTabBarAppearance()
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                withAnimation(AnimationUtils.pageTransition) {
                    previousTab = oldValue
                    isTabChanging = true
                }
                
                // 添加触觉反馈
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isTabChanging = false
                }
            }
            
            // 网络状态指示器
            if !networkMonitor.isConnected {
                VStack {
                    Spacer()
                    NetworkStatusBanner()
                        .padding()
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
                .allowsHitTesting(false)
                .animation(AnimationUtils.smooth, value: networkMonitor.isConnected)
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView()
                .transition(.modal)
        }
        .onAppear {
            checkFirstLaunch()
        }
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        
        if themeManager.currentTheme == .dark {
            appearance.backgroundColor = UIColor.systemBackground
        } else {
            appearance.backgroundColor = UIColor.systemBackground
        }
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    private func checkFirstLaunch() {
        if !UserDefaults.standard.bool(forKey: "HasLaunchedBefore") {
            showingOnboarding = true
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
        }
    }
}

// MARK: - 动画标签图标
struct AnimatedTabIcon: View {
    let systemName: String
    let isSelected: Bool
    let text: String
    @State private var isAnimating = false
    
    var body: some View {
        VStack {
            Image(systemName: isSelected ? "\(systemName).fill" : systemName)
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(AnimationUtils.springBouncy, value: isSelected)
            Text(text)
        }
        .foregroundColor(isSelected ? .accentColor : .secondary)
        .onChange(of: isSelected) { _, newValue in
            if newValue {
                withAnimation(AnimationUtils.successBounce) {
                    isAnimating = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isAnimating = false
                }
            }
        }
    }
}

// MARK: - 网络状态横幅
struct NetworkStatusBanner: View {
    @State private var isVisible = false
    
    var body: some View {
        HStack {
            LoadingAnimationView(color: .white, size: 16)
            
            Text("网络连接已断开")
                .font(.caption)
                .foregroundColor(.white)
                .transition(.opacity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.red)
                .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            withAnimation(AnimationUtils.springBouncy.delay(0.1)) {
                isVisible = true
            }
        }
        .onDisappear {
            withAnimation(AnimationUtils.easeIn) {
                isVisible = false
            }
        }
    }
}

// MARK: - 网络监控
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    @Published var isConnected = true
    @Published var connectionType: String = "WiFi"
    
    private init() {
        // 这里可以实现真实的网络监控逻辑
        // 使用 Network framework 或 Alamofire 的 NetworkReachabilityManager
        simulateNetworkChanges()
    }
    
    // 模拟网络状态变化（仅用于演示）
    private func simulateNetworkChanges() {
        #if DEBUG
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.isConnected.toggle()
            }
        }
        #endif
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager())
        .environmentObject(SettingsManager())
}