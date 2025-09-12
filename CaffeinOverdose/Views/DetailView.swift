//  DetailView.swift
//  CaffeinOverdose
//
//  Swift 6 / macOS 15.6

import SwiftUI
import AVKit
import AppKit
import SwiftData

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

    // Local UI state
    @State private var didApplyInitialIndex: Bool = false
    @State private var keyMonitor: Any?
    
    init(itemIDs: [UUID], index: Binding<Int>, initialIndex: Int? = nil, onClose: @escaping () -> Void) {
        self.itemIDs = itemIDs
        self._index = index
        self.initialIndex = initialIndex
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            if let item = vm.loadedItem {
                VStack(spacing: 12) {
                    // Top bar
                    HStack {
                        Text(item.filename)
                            .foregroundStyle(.white)
                            .font(.headline)
                        Spacer()
                        Button { onClose() } label: {
                            Image(systemName: "xmark.circle.fill").font(.title2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .keyboardShortcut(.escape, modifiers: [])
                    }
                    .padding(.horizontal)

                    // Content
                    Group {
                        if item.kind == .image {
                            if let img = NSImage(contentsOf: item.url) {
                                Image(nsImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                Text("이미지를 불러올 수 없습니다.")
                                    .foregroundStyle(.white)
                            }
                        } else {
                            VideoPlayer(player: vm.player)
                                .frame(minHeight: 420)
                        }
                    }
                    .padding(.horizontal)

                    // Bottom controls
                    HStack {
                        Button { vm.prev() } label: { Label("이전", systemImage: "chevron.left") }
                            .keyboardShortcut(.leftArrow, modifiers: [])
                            .disabled(!vm.canGoPrev)

                        Button { vm.next() } label: { Label("다음", systemImage: "chevron.right") }
                            .keyboardShortcut(.rightArrow, modifiers: [])
                            .disabled(!vm.canGoNext)

                        Spacer()

                        if item.kind == .video {
                            Button { vm.togglePlay() } label: { Label("재생/일시정지", systemImage: "playpause") }
                                .keyboardShortcut(.space, modifiers: [])
                        }
                    }
                    .padding([.horizontal, .bottom])
                }
                .foregroundStyle(.white)
            } else {
                Text(vm.errorMessage ?? "항목을 불러올 수 없습니다.")
                    .foregroundStyle(.white)
            }
        }
        .onAppear {
            setupKeyMonitor()
            vm.onAppear()
        }
        // ✅ itemIDs가 (처음 전달되거나) 바뀔 때만 configure
        .task(id: itemIDs) {
            #if DEBUG
            print("⚙️ Detail.task(itemIDs) count=\(itemIDs.count), index=\(index)")
            #endif
            
            guard !itemIDs.isEmpty else { return }
            let start = (!didApplyInitialIndex && initialIndex != nil) ? initialIndex! : index
            vm.configure(context: context, itemIDs: itemIDs, index: start)
            didApplyInitialIndex = true
        }
        .task(id: index) {
            // External index binding changed from parent
            vm.setIndex(index)
        }
        .onDisappear {
            teardownKeyMonitor()
            vm.onDisappear()
        }
        .onReceive(vm.$index) { new in
            // Propagate VM navigation back to parent binding
            if new != index { index = new }
        }
    }

    // MARK: - Keyboard
    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            switch e.keyCode {
            case 53:  onClose(); return nil          // esc
            case 123: vm.prev(); return nil          // ←
            case 124: vm.next(); return nil          // →
            case 49:  vm.togglePlay(); return nil    // space
            default:  break
            }
            return e
        }
    }

    private func teardownKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        keyMonitor = nil
        vm.stopPlayer()
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
