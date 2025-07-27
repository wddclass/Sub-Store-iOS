import SwiftUI

// MARK: - 微交互组件库
struct MicroInteractionComponents {
    
    // MARK: - 浮动动作按钮
    struct FloatingActionButton: View {
        let icon: String
        let action: () -> Void
        let size: CGFloat
        let expandedActions: [FloatingAction]
        
        @State private var isExpanded = false
        @State private var dragOffset: CGSize = .zero
        @State private var rotation: Double = 0
        
        init(
            icon: String,
            size: CGFloat = 56,
            expandedActions: [FloatingAction] = [],
            action: @escaping () -> Void
        ) {
            self.icon = icon
            self.action = action
            self.size = size
            self.expandedActions = expandedActions
        }
        
        var body: some View {
            ZStack {
                // 展开的动作按钮
                if isExpanded && !expandedActions.isEmpty {
                    ForEach(expandedActions.indices, id: \.self) { index in
                        FloatingActionItem(
                            action: expandedActions[index],
                            index: index,
                            isExpanded: isExpanded
                        )
                    }
                }
                
                // 主按钮
                Button {
                    if expandedActions.isEmpty {
                        action()
                        HapticManager.shared.mediumTap()
                    } else {
                        withAnimation(AnimationUtils.springBouncy) {
                            isExpanded.toggle()
                        }
                        HapticManager.shared.lightTap()
                    }
                } label: {
                    Image(systemName: icon)
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: size, height: size)
                        .background(
                            Circle()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [.accentColor, .accentColor.opacity(0.8)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .shadow(color: .accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                        .rotationEffect(.degrees(rotation))
                }
                .scaleEffect(isExpanded ? 1.1 : 1.0)
                .offset(dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { _ in
                            withAnimation(AnimationUtils.springBouncy) {
                                dragOffset = .zero
                            }
                        }
                )
                .onAppear {
                    withAnimation(
                        Animation.linear(duration: 8.0)
                            .repeatForever(autoreverses: false)
                    ) {
                        rotation = 360
                    }
                }
            }
        }
    }
    
    // MARK: - 浮动动作项
    struct FloatingActionItem: View {
        let action: FloatingAction
        let index: Int
        let isExpanded: Bool
        
        @State private var isVisible = false
        
        var body: some View {
            Button {
                action.action()
                HapticManager.shared.lightTap()
            } label: {
                HStack {
                    Text(action.title)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(.systemBackground))
                                .shadow(radius: 2)
                        )
                        .opacity(isVisible ? 1 : 0)
                    
                    Image(systemName: action.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(action.color)
                                .shadow(color: action.color.opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                }
            }
            .offset(y: isVisible ? -CGFloat((index + 1) * 60) : 0)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.3)
            .animation(
                AnimationUtils.springBouncy
                    .delay(Double(index) * 0.1),
                value: isVisible
            )
            .onChange(of: isExpanded) { _, newValue in
                isVisible = newValue
            }
        }
    }
    
    // MARK: - 脉冲点
    struct PulseView: View {
        let color: Color
        let size: CGFloat
        let pulseCount: Int
        
        @State private var isPulsing = false
        
        init(color: Color = .accentColor, size: CGFloat = 20, pulseCount: Int = 3) {
            self.color = color
            self.size = size
            self.pulseCount = pulseCount
        }
        
        var body: some View {
            ZStack {
                ForEach(0..<pulseCount, id: \.self) { index in
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: 2)
                        .frame(width: size, height: size)
                        .scaleEffect(isPulsing ? 2.0 : 1.0)
                        .opacity(isPulsing ? 0.0 : 1.0)
                        .animation(
                            Animation.easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.5),
                            value: isPulsing
                        )
                }
                
                Circle()
                    .fill(color)
                    .frame(width: size * 0.3, height: size * 0.3)
            }
            .onAppear {
                isPulsing = true
            }
        }
    }
    
    // MARK: - 计数器动画
    struct AnimatedCounter: View {
        let count: Int
        let duration: Double
        let formatter: (Int) -> String
        
        @State private var animatedCount: Int = 0
        
        init(
            count: Int,
            duration: Double = 1.0,
            formatter: @escaping (Int) -> String = { "\($0)" }
        ) {
            self.count = count
            self.duration = duration
            self.formatter = formatter
        }
        
        var body: some View {
            Text(formatter(animatedCount))
                .font(.system(.title2, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
                .onAppear {
                    animateCount()
                }
                .onChange(of: count) { _, _ in
                    animateCount()
                }
        }
        
        private func animateCount() {
            let steps = 30
            let stepDuration = duration / Double(steps)
            let increment = count / steps
            
            for i in 0...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                    withAnimation(.easeOut(duration: stepDuration)) {
                        if i == steps {
                            animatedCount = count
                        } else {
                            animatedCount = increment * i
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 进度环
    struct ProgressRing: View {
        let progress: Double
        let lineWidth: CGFloat
        let size: CGFloat
        let color: Color
        let backgroundColor: Color
        
        @State private var animatedProgress: Double = 0
        
        init(
            progress: Double,
            lineWidth: CGFloat = 8,
            size: CGFloat = 60,
            color: Color = .accentColor,
            backgroundColor: Color = Color.gray.opacity(0.3)
        ) {
            self.progress = progress
            self.lineWidth = lineWidth
            self.size = size
            self.color = color
            self.backgroundColor = backgroundColor
        }
        
        var body: some View {
            ZStack {
                // 背景环
                Circle()
                    .stroke(backgroundColor, lineWidth: lineWidth)
                    .frame(width: size, height: size)
                
                // 进度环
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [color.opacity(0.3), color]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                
                // 中心文本
                Text("\(Int(animatedProgress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
            .onAppear {
                withAnimation(AnimationUtils.easeOut.delay(0.2)) {
                    animatedProgress = progress
                }
            }
            .onChange(of: progress) { _, newValue in
                withAnimation(AnimationUtils.smooth) {
                    animatedProgress = newValue
                }
            }
        }
    }
    
    // MARK: - 弹性卡片
    struct BouncyCard<Content: View>: View {
        let content: Content
        let cornerRadius: CGFloat
        let action: (() -> Void)?
        
        @State private var isPressed = false
        @State private var isHovered = false
        
        init(
            cornerRadius: CGFloat = 16,
            action: (() -> Void)? = nil,
            @ViewBuilder content: () -> Content
        ) {
            self.content = content()
            self.cornerRadius = cornerRadius
            self.action = action
        }
        
        var body: some View {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color(.systemBackground))
                        .shadow(
                            color: .black.opacity(isHovered ? 0.15 : 0.1),
                            radius: isHovered ? 12 : 8,
                            x: 0,
                            y: isHovered ? 6 : 4
                        )
                )
                .scaleEffect(isPressed ? 0.95 : (isHovered ? 1.02 : 1.0))
                .animation(AnimationUtils.springBouncy, value: isPressed)
                .animation(AnimationUtils.smooth, value: isHovered)
                .onTapGesture {
                    if let action = action {
                        withAnimation(AnimationUtils.buttonPress) {
                            isPressed = true
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(AnimationUtils.buttonRelease) {
                                isPressed = false
                            }
                            action()
                        }
                        
                        HapticManager.shared.cardTap()
                    }
                }
                .onLongPressGesture(
                    minimumDuration: 0.0,
                    maximumDistance: .infinity,
                    pressing: { pressing in
                        withAnimation(AnimationUtils.smooth) {
                            isHovered = pressing
                        }
                    },
                    perform: {}
                )
        }
    }
    
    // MARK: - 粒子效果
    struct ParticleEffect: View {
        let particleCount: Int
        let colors: [Color]
        let size: CGFloat
        
        @State private var particles: [Particle] = []
        
        init(particleCount: Int = 20, colors: [Color] = [.accentColor], size: CGFloat = 4) {
            self.particleCount = particleCount
            self.colors = colors
            self.size = size
        }
        
        var body: some View {
            ZStack {
                ForEach(particles.indices, id: \.self) { index in
                    Circle()
                        .fill(particles[index].color)
                        .frame(width: size, height: size)
                        .offset(particles[index].position)
                        .opacity(particles[index].opacity)
                        .scaleEffect(particles[index].scale)
                }
            }
            .onAppear {
                createParticles()
                animateParticles()
            }
        }
        
        private func createParticles() {
            particles = (0..<particleCount).map { _ in
                Particle(
                    position: CGSize(
                        width: Double.random(in: -100...100),
                        height: Double.random(in: -100...100)
                    ),
                    color: colors.randomElement() ?? .accentColor,
                    opacity: Double.random(in: 0.3...1.0),
                    scale: Double.random(in: 0.5...1.5)
                )
            }
        }
        
        private func animateParticles() {
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 2.0)) {
                    for index in particles.indices {
                        particles[index].position = CGSize(
                            width: Double.random(in: -150...150),
                            height: Double.random(in: -150...150)
                        )
                        particles[index].opacity = Double.random(in: 0.1...0.8)
                        particles[index].scale = Double.random(in: 0.3...1.8)
                    }
                }
            }
        }
    }
}

// MARK: - 辅助结构
struct FloatingAction {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
}

struct Particle {
    var position: CGSize
    let color: Color
    var opacity: Double
    var scale: Double
}

// MARK: - 高级动画修饰器
struct SpringScaleModifier: ViewModifier {
    let trigger: Bool
    let scale: CGFloat
    let duration: Double
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(trigger ? scale : 1.0)
            .animation(
                .spring(response: duration, dampingFraction: 0.6, blendDuration: 0),
                value: trigger
            )
    }
}

struct WaveEffectModifier: ViewModifier {
    let trigger: Bool
    let amplitude: CGFloat
    let frequency: Double
    
    @State private var phase: Double = 0
    
    func body(content: Content) -> some View {
        content
            .offset(y: trigger ? sin(phase) * amplitude : 0)
            .onAppear {
                if trigger {
                    withAnimation(
                        .linear(duration: 1.0 / frequency)
                            .repeatForever(autoreverses: false)
                    ) {
                        phase = .pi * 2
                    }
                }
            }
    }
}

struct GlowEffectModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let intensity: Double
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(intensity), radius: radius)
            .shadow(color: color.opacity(intensity * 0.8), radius: radius * 0.6)
            .shadow(color: color.opacity(intensity * 0.6), radius: radius * 0.3)
    }
}

// MARK: - 视图扩展
extension View {
    func springScale(trigger: Bool, scale: CGFloat = 1.2, duration: Double = 0.3) -> some View {
        modifier(SpringScaleModifier(trigger: trigger, scale: scale, duration: duration))
    }
    
    func waveEffect(trigger: Bool, amplitude: CGFloat = 10, frequency: Double = 2) -> some View {
        modifier(WaveEffectModifier(trigger: trigger, amplitude: amplitude, frequency: frequency))
    }
    
    func glowEffect(color: Color = .accentColor, radius: CGFloat = 10, intensity: Double = 0.8) -> some View {
        modifier(GlowEffectModifier(color: color, radius: radius, intensity: intensity))
    }
    
    func bouncyCard(cornerRadius: CGFloat = 16, action: (() -> Void)? = nil) -> some View {
        MicroInteractionComponents.BouncyCard(cornerRadius: cornerRadius, action: action) {
            self
        }
    }
}