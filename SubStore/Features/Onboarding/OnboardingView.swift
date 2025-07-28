import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 用户引导视图
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var dragOffset: CGSize = .zero
    @State private var isButtonAnimating = false
    
    private let pages = [
        OnboardingPage(
            title: "欢迎使用 Sub-Store",
            description: "强大的订阅管理工具，支持多种代理工具和订阅格式",
            imageName: "app.logo",
            systemImage: "link.circle.fill"
        ),
        OnboardingPage(
            title: "订阅管理",
            description: "轻松管理您的订阅，支持流量监控、批量操作和智能分类",
            imageName: nil,
            systemImage: "link.badge.plus"
        ),
        OnboardingPage(
            title: "规则配置",
            description: "创建和管理重写规则、脚本等，支持云端同步和实时预览",
            imageName: nil,
            systemImage: "doc.text.fill"
        ),
        OnboardingPage(
            title: "文件编辑",
            description: "内置代码编辑器，支持语法高亮和多种文件格式",
            imageName: nil,
            systemImage: "folder.fill"
        ),
        OnboardingPage(
            title: "开始使用",
            description: "立即开始管理您的订阅和规则，享受更好的网络体验",
            imageName: nil,
            systemImage: "star.fill"
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // 页面内容
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index], pageIndex: index, currentPage: currentPage)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .onChange(of: currentPage) { _ in
                // 添加触觉反馈
                #if canImport(UIKit)
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                #endif
            }
            
            // 底部控制区域
            VStack(spacing: AppConstants.UI.Spacing.large) {
                // 页面指示器
                AnimatedPageIndicator(currentPage: currentPage, pageCount: pages.count)
                
                // 按钮
                HStack(spacing: AppConstants.UI.Spacing.medium) {
                    // 跳过按钮
                    if currentPage < pages.count - 1 {
                        Button("跳过") {
                            withAnimation(AnimationUtils.pageTransition) {
                                dismiss()
                            }
                        }
                        .foregroundColor(.secondary)
                        .scaleEffect(isButtonAnimating ? 0.95 : 1.0)
                        .transition(.slide)
                    }
                    
                    Spacer()
                    
                    // 下一步/开始使用按钮
                    Button(currentPage == pages.count - 1 ? "开始使用" : "下一步") {
                        withAnimation(AnimationUtils.buttonPress) {
                            isButtonAnimating = true
                        }
                        
                        // 添加触觉反馈
                        #if canImport(UIKit)
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        #endif
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if currentPage == pages.count - 1 {
                                withAnimation(AnimationUtils.modalPresentation) {
                                    dismiss()
                                }
                            } else {
                                withAnimation(AnimationUtils.pageTransition) {
                                    currentPage += 1
                                }
                            }
                            isButtonAnimating = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .scaleEffect(isButtonAnimating ? 0.95 : 1.0)
                    .successBounce(trigger: currentPage == pages.count - 1)
                }
                .padding(.horizontal, AppConstants.UI.Spacing.large)
            }
            .padding(.bottom, AppConstants.UI.Spacing.extraLarge)
        }
        .background {
            #if canImport(UIKit)
            Color(.systemBackground)
            #else
            Color(NSColor.controlBackgroundColor)
            #endif
        }
        .transition(.opacity)
    }
}

// MARK: - 引导页面数据
struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String?
    let systemImage: String
}

// MARK: - 单页引导视图
struct OnboardingPageView: View {
    let page: OnboardingPage
    let pageIndex: Int
    let currentPage: Int
    @State private var isVisible = false
    @State private var iconScale: CGFloat = 0.5
    @State private var textOffset: CGFloat = 50
    
    var body: some View {
        VStack(spacing: AppConstants.UI.Spacing.extraLarge) {
            Spacer()
            
            // 图标
            Group {
                if let imageName = page.imageName {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                } else {
                    Image(systemName: page.systemImage)
                        .font(.system(size: 80))
                        .foregroundColor(.accentColor)
                }
            }
            .scaleEffect(iconScale)
            .opacity(isVisible ? 1.0 : 0.0)
            .animation(AnimationUtils.springBouncy.delay(0.2), value: iconScale)
            .animation(AnimationUtils.easeOut.delay(0.1), value: isVisible)
            
            Spacer()
            
            // 文本内容
            VStack(spacing: AppConstants.UI.Spacing.medium) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .offset(y: textOffset)
                    .opacity(isVisible ? 1.0 : 0.0)
                    .animation(AnimationUtils.springDefault.delay(0.4), value: textOffset)
                
                Text(page.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, AppConstants.UI.Spacing.large)
                    .offset(y: textOffset)
                    .opacity(isVisible ? 1.0 : 0.0)
                    .animation(AnimationUtils.springDefault.delay(0.6), value: textOffset)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            if pageIndex == currentPage {
                startAnimation()
            }
        }
        .onChange(of: currentPage) { _, newValue in
            if newValue == pageIndex {
                startAnimation()
            } else {
                resetAnimation()
            }
        }
    }
    
    private func startAnimation() {
        isVisible = true
        iconScale = 1.0
        textOffset = 0
    }
    
    private func resetAnimation() {
        isVisible = false
        iconScale = 0.5
        textOffset = 50
    }
}

// MARK: - 动画页面指示器
struct AnimatedPageIndicator: View {
    let currentPage: Int
    let pageCount: Int
    @State private var indicatorWidth: CGFloat = 8
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: index == currentPage ? indicatorWidth * 2 : indicatorWidth, height: indicatorWidth)
                    .scaleEffect(index == currentPage ? 1.0 : 0.8)
                    .animation(AnimationUtils.springBouncy, value: currentPage)
            }
        }
        .onAppear {
            withAnimation(AnimationUtils.springDefault.delay(0.5)) {
                indicatorWidth = 8
            }
        }
    }
}

// MARK: - 页面指示器 (保留原版本作为备选)
struct PageIndicator: View {
    let currentPage: Int
    let pageCount: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentPage ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: currentPage)
            }
        }
    }
}

// MARK: - 预览
#Preview {
    OnboardingView()
}