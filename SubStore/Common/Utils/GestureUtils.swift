import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 手势工具类
struct GestureUtils {
    
    // MARK: - 拖拽手势配置
    struct DragConfig {
        let sensitivity: CGFloat
        let threshold: CGFloat
        let hapticFeedback: Bool
        let animation: Animation
        
        static let `default` = DragConfig(
            sensitivity: 1.0,
            threshold: 50.0,
            hapticFeedback: true,
            animation: AnimationUtils.smooth
        )
        
        static let light = DragConfig(
            sensitivity: 0.8,
            threshold: 30.0,
            hapticFeedback: true,
            animation: AnimationUtils.easeOut
        )
        
        static let heavy = DragConfig(
            sensitivity: 1.2,
            threshold: 80.0,
            hapticFeedback: true,
            animation: AnimationUtils.springBouncy
        )
    }
    
    // MARK: - 长按手势配置
    struct LongPressConfig {
        let minimumDuration: Double
        let hapticFeedback: Bool
        let visualFeedback: Bool
        
        static let `default` = LongPressConfig(
            minimumDuration: 0.5,
            hapticFeedback: true,
            visualFeedback: true
        )
        
        static let quick = LongPressConfig(
            minimumDuration: 0.3,
            hapticFeedback: true,
            visualFeedback: true
        )
        
        static let slow = LongPressConfig(
            minimumDuration: 1.0,
            hapticFeedback: true,
            visualFeedback: true
        )
    }
}

// MARK: - 拖拽排序视图修饰器
struct DragToReorderModifier<Item: Identifiable>: ViewModifier {
    @Binding var items: [Item]
    let config: GestureUtils.DragConfig
    let onReorder: ((Int, Int) -> Void)?
    
    @State private var draggedItem: Item?
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isDragging ? 1.05 : 1.0)
            .opacity(isDragging ? 0.8 : 1.0)
            .offset(dragOffset)
            .animation(config.animation, value: isDragging)
            .animation(config.animation, value: dragOffset)
    }
}

// MARK: - 滑动手势视图
struct SwipeGestureView<Content: View>: View {
    let content: Content
    let leftActions: [SwipeAction]
    let rightActions: [SwipeAction]
    let config: GestureUtils.DragConfig
    
    @State private var offset: CGFloat = 0
    @State private var isPresentingActions = false
    @State private var currentSide: SwipeSide = .none
    
    enum SwipeSide {
        case none, left, right
    }
    
    init(
        config: GestureUtils.DragConfig = .default,
        leftActions: [SwipeAction] = [],
        rightActions: [SwipeAction] = [],
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.leftActions = leftActions
        self.rightActions = rightActions
        self.config = config
    }
    
    var body: some View {
        ZStack {
            // 背景动作按钮
            HStack {
                if currentSide == .left && !leftActions.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(leftActions.indices, id: \.self) { index in
                            SwipeActionButton(action: leftActions[index])
                        }
                        Spacer()
                    }
                } else if currentSide == .right && !rightActions.isEmpty {
                    HStack(spacing: 0) {
                        Spacer()
                        ForEach(rightActions.indices, id: \.self) { index in
                            SwipeActionButton(action: rightActions[index])
                        }
                    }
                }
            }
            
            // 主内容
            content
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            handleDragChanged(value)
                        }
                        .onEnded { value in
                            handleDragEnded(value)
                        }
                )
        }
        .clipped()
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        let translation = value.translation.width * config.sensitivity
        
        // 确定滑动方向
        if translation > 0 && !leftActions.isEmpty {
            currentSide = .left
            offset = min(translation, CGFloat(leftActions.count * 80))
        } else if translation < 0 && !rightActions.isEmpty {
            currentSide = .right
            offset = max(translation, -CGFloat(rightActions.count * 80))
        }
        
        // 触觉反馈
        if config.hapticFeedback && abs(translation) > config.threshold && !isPresentingActions {
            #if canImport(UIKit)
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            #endif
            isPresentingActions = true
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let translation = value.translation.width * config.sensitivity
        let velocity = value.velocity.width
        
        withAnimation(config.animation) {
            if abs(translation) > config.threshold || abs(velocity) > 500 {
                // 保持动作显示状态
                if currentSide == .left {
                    offset = CGFloat(leftActions.count * 80)
                } else if currentSide == .right {
                    offset = -CGFloat(rightActions.count * 80)
                }
            } else {
                // 回到原位
                offset = 0
                currentSide = .none
                isPresentingActions = false
            }
        }
    }
    
    func resetOffset() {
        withAnimation(config.animation) {
            offset = 0
            currentSide = .none
            isPresentingActions = false
        }
    }
}

// MARK: - 滑动动作
struct SwipeAction {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    static func delete(action: @escaping () -> Void) -> SwipeAction {
        SwipeAction(title: "删除", icon: "trash", color: .red, action: action)
    }
    
    static func edit(action: @escaping () -> Void) -> SwipeAction {
        SwipeAction(title: "编辑", icon: "pencil", color: .blue, action: action)
    }
    
    static func archive(action: @escaping () -> Void) -> SwipeAction {
        SwipeAction(title: "归档", icon: "archivebox", color: .orange, action: action)
    }
    
    static func copy(action: @escaping () -> Void) -> SwipeAction {
        SwipeAction(title: "复制", icon: "doc.on.doc", color: .green, action: action)
    }
}

// MARK: - 滑动动作按钮
struct SwipeActionButton: View {
    let action: SwipeAction
    @State private var isPressed = false
    
    var body: some View {
        Button {
            // 触觉反馈
            #if canImport(UIKit)
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
            #endif
            
            action.action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: action.icon)
                    .font(.system(size: 16, weight: .medium))
                
                Text(action.title)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .frame(width: 80)
            .frame(maxHeight: .infinity)
            .background(action.color)
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

// MARK: - 长按手势修饰器
struct LongPressGestureModifier: ViewModifier {
    let config: GestureUtils.LongPressConfig
    let onLongPress: () -> Void
    
    @State private var isPressed = false
    @State private var pressTimer: Timer?
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && config.visualFeedback ? 0.95 : 1.0)
            .opacity(isPressed && config.visualFeedback ? 0.8 : 1.0)
            .animation(AnimationUtils.buttonPress, value: isPressed)
            .onLongPressGesture(
                minimumDuration: config.minimumDuration,
                pressing: { pressing in
                    isPressed = pressing
                    
                    if pressing {
                        if config.hapticFeedback {
                            #if canImport(UIKit)
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            #endif
                        }
                        
                        pressTimer = Timer.scheduledTimer(withTimeInterval: config.minimumDuration, repeats: false) { _ in
                            if config.hapticFeedback {
                                #if canImport(UIKit)
                                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                                impactFeedback.impactOccurred()
                                #endif
                            }
                        }
                    } else {
                        pressTimer?.invalidate()
                        pressTimer = nil
                    }
                },
                perform: onLongPress
            )
    }
}

// MARK: - 拉取刷新手势
struct PullToRefreshModifier: ViewModifier {
    let onRefresh: () async -> Void
    let threshold: CGFloat
    
    @State private var offset: CGFloat = 0
    @State private var isRefreshing = false
    
    init(threshold: CGFloat = 100, onRefresh: @escaping () async -> Void) {
        self.threshold = threshold
        self.onRefresh = onRefresh
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RefreshIndicator(
                    offset: offset,
                    threshold: threshold,
                    isRefreshing: isRefreshing
                ),
                alignment: .top
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 && !isRefreshing {
                            offset = min(value.translation.height, threshold * 1.5)
                        }
                    }
                    .onEnded { value in
                        if offset >= threshold && !isRefreshing {
                            performRefresh()
                        } else {
                            withAnimation(AnimationUtils.smooth) {
                                offset = 0
                            }
                        }
                    }
            )
    }
    
    private func performRefresh() {
        withAnimation(AnimationUtils.smooth) {
            isRefreshing = true
            offset = threshold
        }
        
        Task {
            await onRefresh()
            
            await MainActor.run {
                withAnimation(AnimationUtils.smooth) {
                    isRefreshing = false
                    offset = 0
                }
            }
        }
    }
}

// MARK: - 刷新指示器
struct RefreshIndicator: View {
    let offset: CGFloat
    let threshold: CGFloat
    let isRefreshing: Bool
    
    var body: some View {
        VStack {
            if offset > 0 || isRefreshing {
                HStack {
                    if isRefreshing {
                        LoadingAnimationView(color: .accentColor, size: 20)
                    } else {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 16, weight: .medium))
                            .rotationEffect(.degrees(offset >= threshold ? 180 : 0))
                            .animation(AnimationUtils.smooth, value: offset >= threshold)
                    }
                    
                    Text(isRefreshing ? "刷新中..." : offset >= threshold ? "松开刷新" : "下拉刷新")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .opacity(min(offset / threshold, 1.0))
                .offset(y: max(0, min(offset, threshold)) - threshold)
            }
        }
        .frame(height: 0)
    }
}

// MARK: - 视图扩展
extension View {
    func swipeActions(
        left: [SwipeAction] = [],
        right: [SwipeAction] = [],
        config: GestureUtils.DragConfig = .default
    ) -> some View {
        SwipeGestureView(
            config: config,
            leftActions: left,
            rightActions: right
        ) {
            self
        }
    }
    
    func longPressGesture(
        config: GestureUtils.LongPressConfig = .default,
        onLongPress: @escaping () -> Void
    ) -> some View {
        modifier(LongPressGestureModifier(config: config, onLongPress: onLongPress))
    }
    
    func pullToRefresh(
        threshold: CGFloat = 100,
        onRefresh: @escaping () async -> Void
    ) -> some View {
        modifier(PullToRefreshModifier(threshold: threshold, onRefresh: onRefresh))
    }
}