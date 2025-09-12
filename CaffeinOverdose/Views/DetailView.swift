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

    init(itemIDs: [UUID], index: Binding<Int>, initialIndex: Int? = nil, onClose: @escaping () -> Void) {
        self.itemIDs = itemIDs
        self._index = index
        self.initialIndex = initialIndex
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.96).ignoresSafeArea()

            VStack(spacing: 12) {
                // Top bar (심플)
                HStack {
                    Text(vm.loadedItem?.filename ?? "—")
                        .foregroundStyle(.white)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button { onClose() } label: {
                        Image(systemName: "xmark.circle.fill").font(.title2)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.horizontal)

                // ✅ 네이티브 Quick Look 뷰를 "그대로" 임베드
                Group {
                    if !vm.itemIDs.isEmpty, let urls = vm.urlsForItems() {
                        QLPreviewRepresentable( urls: urls, index: Binding( get: { vm.index }, set: { vm.setIndex($0) }))
                            .background(.black)
                            // ← 여기서 스와이프(좌/우) 제스처를 SwiftUI로 처리
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 20)
                                    .onEnded { v in
                                        if v.translation.width < -60 { vm.next() }
                                        else if v.translation.width > 60 { vm.prev() }
                                    }
                            )
                    } else {
                        Text(vm.errorMessage ?? "항목을 불러올 수 없습니다.")
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom bar (필요 최소)
                HStack {
                    Button { vm.prev() } label: { Label("이전", systemImage: "chevron.left") }
                        .keyboardShortcut(.leftArrow, modifiers: [])
                        .disabled(!vm.canGoPrev)

                    Button { vm.next() } label: { Label("다음", systemImage: "chevron.right") }
                        .keyboardShortcut(.rightArrow, modifiers: [])
                        .disabled(!vm.canGoNext)

                    Spacer()

                    // WEBM 외부 열기
                    if let u = vm.loadedItem?.url, u.pathExtension.lowercased() == "webm" {
                        Button { vm.openInIINA(u) } label: {
                            Label("IINA로 열기", systemImage: "film")
                        }
                    }
                }
                .padding([.horizontal, .bottom])
                .foregroundStyle(.white)
            }
            .foregroundStyle(.white)
        }
        .onAppear {
            setupKeyMonitor()
            vm.onAppear()
        }
        .task(id: itemIDs) {
            guard !itemIDs.isEmpty else { return }
            let start = (!didApplyInitialIndex && initialIndex != nil) ? initialIndex! : index
            vm.configure(context: context, itemIDs: itemIDs, index: start)
            didApplyInitialIndex = true
            // 부모 바인딩으로 반영
            if vm.index != index { index = vm.index }
        }
        .task(id: index) {
            // 부모에서 인덱스 변경 시 반영
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
