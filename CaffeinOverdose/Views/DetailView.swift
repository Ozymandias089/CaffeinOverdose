//
//  DetailView.swift
//  CaffeinOverdose
//
//  Swift 6 / macOS 15.6
//

import SwiftUI
import AVKit
import AppKit
import SwiftData

struct DetailView: View {
    let itemIDs: [UUID]                 // 모델 대신 식별자만 전달
    @Binding var index: Int
    var onClose: () -> Void

    @Environment(\.modelContext) private var context
    @State private var player: AVPlayer?
    @State private var keyMonitor: Any?

    // 현재 로드된 아이템을 상태로 보관 (fetch 실패 시 nil)
    @State private var loadedItem: MediaItem?

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            if let item = loadedItem {
                VStack(spacing: 12) {
                    // 상단 바
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

                    // 콘텐츠
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
                            VideoPlayer(player: player)
                                .frame(minHeight: 420)
                        }
                    }
                    .padding(.horizontal)

                    // 하단 컨트롤
                    HStack {
                        Button { prev() } label: { Label("이전", systemImage: "chevron.left") }
                            .keyboardShortcut(.leftArrow, modifiers: [])

                        Button { next() } label: { Label("다음", systemImage: "chevron.right") }
                            .keyboardShortcut(.rightArrow, modifiers: [])

                        Spacer()

                        if item.kind == .video {
                            Button { togglePlay() } label: { Label("재생/일시정지", systemImage: "playpause") }
                                .keyboardShortcut(.space, modifiers: [])
                        }
                    }
                    .padding([.horizontal, .bottom])
                }
                .foregroundStyle(.white)
            } else {
                Text("항목을 불러올 수 없습니다.")
                    .foregroundStyle(.white)
            }
        }
        .onAppear {
            setupKeyMonitor()
            loadCurrent()
        }
        .onDisappear { teardownKeyMonitor() }
        .task(id: index) {               // 인덱스가 바뀔 때마다 다시 로드
            loadCurrent()
        }
    }

    // MARK: - Data Loading

    private func loadCurrent() {
        guard itemIDs.indices.contains(index) else {
            loadedItem = nil
            stopPlayer()
            return
        }
        let id = itemIDs[index]
        loadedItem = fetchItem(by: id)

        if let it = loadedItem {
            if it.kind == .video {
                stopPlayer()
                player = AVPlayer(url: it.url)
            } else {
                stopPlayer()
            }
        } else {
            stopPlayer()
        }
    }

    private func fetchItem(by id: UUID) -> MediaItem? {
        let pred = #Predicate<MediaItem> { $0.id == id }
        var fd = FetchDescriptor<MediaItem>(predicate: pred)
        fd.fetchLimit = 1
        do {
            let r = try context.fetch(fd)
            // 디버그 로그
            print("DetailView: fetch count=\(r.count) for id=\(id)")
            return r.first
        } catch {
            print("DetailView: fetch error for id=\(id) ->", error)
            return nil
        }
    }

    // MARK: - Controls

    private func prev() { if index > 0 { index -= 1 } }
    private func next() { if index < itemIDs.count - 1 { index += 1 } }

    private func togglePlay() {
        guard let p = player else { return }
        p.timeControlStatus == .playing ? p.pause() : p.play()
    }

    private func stopPlayer() {
        player?.pause()
        player = nil
    }

    // MARK: - Keyboard

    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            switch e.keyCode {
            case 53:  onClose(); return nil          // esc
            case 123: prev(); return nil             // ←
            case 124: next(); return nil             // →
            case 49:  togglePlay(); return nil       // space
            default:  break
            }
            return e
        }
    }

    private func teardownKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        keyMonitor = nil
        stopPlayer()
    }
}

// MARK: - Preview (동일)
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
        root.subfolders.append(folder)

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
        folder.items.append(contentsOf: [imgItem, vidItem])

        ctx.insert(root)
        try? ctx.save()

        self.itemIDs = [imgItem.id, vidItem.id]
    }

    var body: some View {
        DetailView(itemIDs: itemIDs, index: $idx, onClose: {})
            .frame(width: 1000, height: 700)
            .background(.black)
            .modelContainer(container)
    }
}
#endif
