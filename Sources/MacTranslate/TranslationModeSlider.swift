import SwiftUI

struct TranslationModeSlider: View {
    let modes: [TranslationMode]
    let selectedMode: TranslationMode
    let isResolvingModes: Bool
    let notice: String?
    let onSelect: (TranslationMode) -> Void

    @State private var isEditing = false
    @State private var previewMode: TranslationMode?
    @State private var labelDismissTask: Task<Void, Never>?

    private let knobDiameter: CGFloat = 25
    private let horizontalInset: CGFloat = 17

    private var isInteractive: Bool {
        !isResolvingModes && modes.count > 1
    }

    var body: some View {
        VStack(spacing: 1) {
            ZStack {
                if isEditing, let previewMode {
                    modeLabel(previewMode.title)
                        .transition(.opacity)
                } else if let notice {
                    modeLabel(notice)
                        .transition(.opacity)
                }
            }
            .frame(height: 25)

            GeometryReader { geometry in
                let width = geometry.size.width
                let activeMode = previewMode ?? selectedMode
                let activeIndex = modes.firstIndex(of: activeMode) ?? 0
                let activePosition = stopPosition(activeIndex, count: modes.count, width: width)
                let centerY = geometry.size.height / 2

                ZStack {
                    Capsule()
                        .fill(Color.black.opacity(0.46))
                        .frame(height: 11)
                        .glassEffect(
                            .regular.tint(Color.black.opacity(0.48)),
                            in: Capsule()
                        )
                        .position(x: width / 2, y: centerY)

                    if modes.count > 1 {
                        ForEach(modes.indices, id: \.self) { index in
                            Circle()
                                .fill(Color.white.opacity(index == activeIndex ? 0.22 : 0.72))
                                .frame(width: 5, height: 5)
                                .position(x: stopPosition(index, count: modes.count, width: width), y: centerY)
                        }
                    }

                    if isResolvingModes {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.75)
                            .position(x: width / 2, y: centerY)
                    } else if !modes.isEmpty {
                        Circle()
                            .fill(Color(white: 0.12))
                            .frame(width: knobDiameter, height: knobDiameter)
                            .glassEffect(.regular.tint(Color.black.opacity(0.72)), in: Circle())
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.72), lineWidth: 1)
                            }
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 1)
                            .position(x: activePosition, y: centerY)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard isInteractive else { return }
                            let index = index(at: value.location.x, width: width, count: modes.count)
                            guard modes.indices.contains(index) else { return }
                            let mode = modes[index]
                            guard previewMode != mode || !isEditing else { return }
                            withAnimation(.easeOut(duration: 0.12)) {
                                isEditing = true
                                previewMode = mode
                            }
                        }
                        .onEnded { value in
                            guard isInteractive else { return }
                            let index = index(at: value.location.x, width: width, count: modes.count)
                            guard modes.indices.contains(index) else {
                                finishEditing()
                                return
                            }
                            finishEditing(selecting: modes[index])
                        },
                    isEnabled: isInteractive
                )
            }
            .frame(height: 30)
        }
        .frame(width: 168, height: 56)
        .accessibilityElement()
        .accessibilityLabel("Translation mode")
        .accessibilityValue(accessibilityValue)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                adjustSelection(by: 1)
            case .decrement:
                adjustSelection(by: -1)
            @unknown default:
                break
            }
        }
        .focusable(isInteractive)
        .onKeyPress(.leftArrow) {
            adjustSelection(by: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            adjustSelection(by: 1)
            return .handled
        }
        .onDisappear {
            labelDismissTask?.cancel()
        }
    }

    private var accessibilityValue: String {
        if isResolvingModes {
            return "Checking available modes"
        }
        if modes.count == 1, let onlyMode = modes.first {
            return onlyMode.title
        }
        return selectedMode.title
    }

    private func modeLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .minimumScaleFactor(0.78)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func stopPosition(_ index: Int, count: Int, width: CGFloat) -> CGFloat {
        guard count > 1 else { return width / 2 }
        let trackWidth = max(0, width - horizontalInset * 2)
        return horizontalInset + trackWidth * CGFloat(index) / CGFloat(count - 1)
    }

    private func index(at x: CGFloat, width: CGFloat, count: Int) -> Int {
        guard count > 1 else { return 0 }
        let trackWidth = max(1, width - horizontalInset * 2)
        let fraction = min(max((x - horizontalInset) / trackWidth, 0), 1)
        return Int((fraction * CGFloat(count - 1)).rounded())
    }

    private func finishEditing(selecting mode: TranslationMode? = nil) {
        withAnimation(.easeOut(duration: 0.16)) {
            if let mode, mode != selectedMode {
                onSelect(mode)
            }
            isEditing = false
            previewMode = nil
        }
    }

    private func adjustSelection(by offset: Int) {
        guard isInteractive else { return }
        let currentIndex = modes.firstIndex(of: selectedMode) ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), modes.count - 1)
        guard nextIndex != currentIndex else { return }

        let mode = modes[nextIndex]
        withAnimation(.easeOut(duration: 0.16)) {
            previewMode = mode
            isEditing = true
            onSelect(mode)
        }

        labelDismissTask?.cancel()
        labelDismissTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.12)) {
                isEditing = false
                previewMode = nil
            }
        }
    }
}
