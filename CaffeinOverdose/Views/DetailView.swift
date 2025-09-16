//  DetailView.swift
//  CaffeinOverdose
//
//  Swift 6 / macOS 15.6

import SwiftUI
import AppKit
import SwiftData
import QuickLookUI   // QLPreviewView 임베드

struct DetailView: View {
    // Inputs
    let itemIDs: [UUID]
    @Binding var index: Int
    let initialIndex: Int?
    var onClose: () -> Void

    // Env
    @Environment(\.modelContext) private var context

    // VM
    @StateObject private var vm = DetailViewViewModel()

    // Local
    @State private var didApplyInitialIndex: Bool = false
    @State private var keyMonitor: Any?

    // Window sizing preferences
    var preferredWindowSize: NSSize = NSSize(width: 1100, height: 740)
    var minimumWindowSize: NSSize = NSSize(width: 720, height: 480)

    init(itemIDs: [UUID], index: Binding<Int>, initialIndex: Int? = nil, onClose: @escaping () -> Void) {
        self.itemIDs = itemIDs
        self._index = index
        self.initialIndex = initialIndex
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .underWindowBackground)
                .ignoresSafeArea()

            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Top-left filename capsule overlay
                .overlay(alignment: .topLeading) {
                    if let name = vm.loadedItem?.filename, !name.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .imageScale(.medium)
                            Text(name)
                                .font(.headline.weight(.semibold))
                                .shadow(color: .black.opacity(0.6), radius: 1, x: 0, y: 0)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.thinMaterial)
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                                    .blur(radius: 8)
                            }
                        )
                        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 6)
                        .padding(12)
                    }
                }
            // Center left/right chevrons overlay
                .overlay(alignment: .center) {
                    HStack {
                        Button(action: { vm.prev() }) {
                            Image(systemName: "chevron.compact.left")
                        }
                        .buttonStyle(LiquidGlassCircleButtonStyle())
                        .tint(.white)
                        .keyboardShortcut(.leftArrow, modifiers: [])
                        .disabled(!vm.canGoPrev)
                        .padding(.leading, 12)

                        Spacer(minLength: 0)

                        Button(action: { vm.next() }) {
                            Image(systemName: "chevron.compact.right")
                        }
                        .buttonStyle(LiquidGlassCircleButtonStyle())
                        .tint(.white)
                        .keyboardShortcut(.rightArrow, modifiers: [])
                        .disabled(!vm.canGoNext)
                        .padding(.trailing, 12)
                    }
                    .frame(maxWidth: .infinity)
                }
            // Top-right close button overlay
                .overlay(alignment: .topTrailing) {
                    Button(role: .cancel) { onClose() } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(LiquidGlassCircleButtonStyle())
                    .tint(.white)
                    .keyboardShortcut(.escape, modifiers: [])
                    .padding(12)
                }
            // Bottom-right external open (optional)
                .overlay(alignment: .bottomTrailing) {
                    if let u = vm.loadedItem?.url, u.pathExtension.lowercased() == "webm" {
                        Button { vm.openInIINA(u) } label: {
                            Image(systemName: "film")
                        }
                        .buttonStyle(LiquidGlassCircleButtonStyle())
                        .tint(.white)
                        .padding(12)
                    }
                }
        }
        .onAppear {
            setupKeyMonitor()
            vm.onAppear()
            applyWindowSizing()
        }
        .task(id: itemIDs) {
            guard !itemIDs.isEmpty else { return }
            let start = (!didApplyInitialIndex && initialIndex != nil) ? initialIndex! : index
            vm.configure(context: context, itemIDs: itemIDs, index: start)
            didApplyInitialIndex = true
            if vm.index != index { index = vm.index }
        }
        .task(id: index) {
            vm.setIndex(index)
        }
        .onDisappear {
            teardownKeyMonitor()
            vm.onDisappear()
        }
        .onReceive(vm.$index) { new in
            if new != index { index = new }
        }
    }

    // MARK: - Encapsulated Content
    @ViewBuilder
    private var contentArea: some View {
        Group {
            if !vm.itemIDs.isEmpty, let urls = vm.urlsForItems() {
                QLPreviewRepresentable(
                    urls: urls,
                    index: Binding(get: { vm.index }, set: { vm.setIndex($0) })
                )
                .background(Color.clear)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { v in
                            if v.translation.width < -60 { vm.next() }
                            else if v.translation.width > 60 { vm.prev() }
                        }
                )
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 40, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text(vm.errorMessage ?? "항목을 불러올 수 없습니다.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
            }
        }
    }

    @ViewBuilder
    private func externalOpenButton() -> some View {
        if let u = vm.loadedItem?.url, u.pathExtension.lowercased() == "webm" {
            Button {
                vm.openInIINA(u)
            } label: {
                Label("IINA로 열기", systemImage: "film")
            }
            .buttonStyle(.borderless)
            .help("WEBM 파일을 IINA로 열기")
        } else {
            EmptyView()
        }
    }

    // MARK: - Keyboard
    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            switch e.keyCode {
            case 53:  onClose(); return nil          // esc
            case 123: vm.prev(); return nil          // ←
            case 124: vm.next(); return nil          // →
            default:  break
            }
            return e
        }
    }

    private func teardownKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        keyMonitor = nil
    }

    // MARK: - Window sizing helpers
    private func applyWindowSizing() {
        // Intentionally no-op here. Window sizing should be controlled by the presenting window/controller.
        // Keeping this function to avoid call-site changes.
        return
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

private struct LiquidGlassCircleButtonStyle: ButtonStyle {
    var iconSize: CGFloat = 20
    var padding: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        LiquidGlassButtonBody(
            label: AnyView(configuration.label),
            iconSize: iconSize,
            padding: padding,
            pressed: configuration.isPressed
        )
    }

    private struct LiquidGlassButtonBody: View {
        let label: AnyView
        var iconSize: CGFloat
        var padding: CGFloat
        var pressed: Bool
        @State private var hovering: Bool = false

        var body: some View {
            label
                .font(.system(size: iconSize, weight: Font.Weight.semibold))
                .foregroundStyle(Color.white.opacity(0.9))
                .padding(padding)
                .background(
                    ZStack {
                        // 1) Nearly transparent base to maximize background sampling
                        Circle().fill(Material.ultraThin)

                        // 2) Very thin outer rim
                        Circle()
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.6)

                        // 3) Long, thin top specular highlight for glassy feel
                        Circle()
                            .trim(from: 0.50, to: 0.98)
                            .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                            .rotationEffect(.degrees(180))
                            .blur(radius: 0.2)

                        // 4) Minimal inner glow (visible slightly more on hover)
                        Circle()
                            .fill(Color.white.opacity(hovering ? 0.04 : 0.02))
                            .blur(radius: 0.2)
                            .scaleEffect(1.08)
                    }
                )
                .shadow(color: Color.black.opacity(0.16), radius: 6, x: 0, y: 4)
                .scaleEffect(pressed ? 0.95 : 1.0)
                .onHover { hovering = $0 }
                .animation(Animation.easeOut(duration: 0.12), value: pressed)
                .animation(Animation.easeOut(duration: 0.18), value: hovering)
        }
    }
}


// MARK: - Preview (updated to use ViewModel.configure)
#if DEBUG
#Preview {
    DetailPreviewWrapper()
}

@MainActor
private struct DetailPreviewWrapper: View {
    @State private var idx: Int = 0
    private let itemIDs: [UUID]
    private let container: ModelContainer

    init() {
        self.container = try! ModelContainer(
            for: MediaFolder.self, MediaItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = ModelContext(container)

        let root = MediaFolder(displayPath: "/", name: "Library")
        let folder = MediaFolder(displayPath: "/Preview", name: "Preview", parent: root)

        let imgItem = MediaItem(
            filename: "portrait_1.jpg",
            relativePath: "Preview/portrait_1.jpg",
            kindRaw: MediaKind.image.rawValue,
            pixelWidth: 800,
            pixelHeight: 1200,
            duration: nil,
            folder: folder
        )
        let vidItem = MediaItem(
            filename: "clip_1.webm",
            relativePath: "Preview/clip_1.webm",
            kindRaw: MediaKind.video.rawValue,
            pixelWidth: 1920,
            pixelHeight: 1080,
            duration: 3.2,
            folder: folder
        )

        ctx.insert(root)
        try? ctx.save()

        self.itemIDs = [imgItem.uuid, vidItem.uuid]
    }

    var body: some View {
        DetailView(itemIDs: itemIDs, index: $idx, onClose: {})
            .frame(width: 1000, height: 700)
            .background(.black)
            .modelContainer(container)
    }
}
#endif

