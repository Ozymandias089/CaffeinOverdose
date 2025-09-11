//
//  MasonryGridView.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//
import SwiftUI
import WaterfallGrid
import AppKit
import SwiftData

struct MasonryGridView: View {
    @ObservedObject var libraryStore: LibraryStore
    var onTileTap: (Int) -> Void = { _ in }

    private let columns = 4
    private let spacing: CGFloat = 8

    private var items: [MediaItem] {
        libraryStore.selectedFolder?.items ?? []
    }

    private func thumbWidth(_ proxy: GeometryProxy) -> CGFloat {
        max(80, proxy.size.width / CGFloat(columns) - spacing * 2)
    }
// MARK: - View
    var body: some View {
        GeometryReader { geo in
            ScrollView {
                // ✅ ViewBuilder 내부에 let/var 선언 안 함
                WaterfallGrid(Array(items.enumerated()), id: \.element.id) { pair in
                    GridCellView(
                        item: pair.element,
                        width: thumbWidth(geo),
                        onTap: { onTileTap(pair.offset) }
                    )
                }
                .gridStyle(columns: columns, spacing: spacing)      // ← animation 파라미터 제거
                .transaction { t in t.disablesAnimations = true }    // ← 레이아웃 변경 애니메이션 차단
                .padding(spacing)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MasonryGridPreviewWrapper()
}

private struct MasonryGridPreviewWrapper: View {
    // 미리 구성해 두고 body에서 사용
    let container: ModelContainer
    let store: LibraryStore

    init() {
        // 1) 인메모리 SwiftData 컨테이너
        container = try! ModelContainer(
            for: MediaFolder.self, MediaItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = ModelContext(container)

        // 2) 샘플 트리 + 아이템 시딩
        let root   = MediaFolder(displayPath: "/", name: "Library")
        let album  = MediaFolder(displayPath: "/Preview", name: "Preview", parent: root)
        root.subfolders.append(album)

        // 몇 개의 가짜 항목(파일 없어도 레이아웃 확인 용도 OK)
        let samples: [MediaItem] = [
            MediaItem(filename: "portrait_1.jpg", relativePath: "Preview/portrait_1.jpg", kindRaw: MediaKind.image.rawValue, pixelWidth: 800,  pixelHeight: 1200, duration: nil, folder: album),
            MediaItem(filename: "landscape_1.jpg",relativePath: "Preview/landscape_1.jpg",kindRaw: MediaKind.image.rawValue, pixelWidth: 1600, pixelHeight: 900,  duration: nil, folder: album),
            MediaItem(filename: "square_1.jpg",   relativePath: "Preview/square_1.jpg",   kindRaw: MediaKind.image.rawValue, pixelWidth: 1080, pixelHeight: 1080, duration: nil, folder: album),
            MediaItem(filename: "clip_1.webm",    relativePath: "Preview/clip_1.webm",    kindRaw: MediaKind.video.rawValue, pixelWidth: 1920, pixelHeight: 1080, duration: 3.2, folder: album),
        ]
        album.items.append(contentsOf: samples)

        ctx.insert(root); ctx.insert(album)
        samples.forEach { ctx.insert($0) }
        try? ctx.save()

        // 3) LibraryStore 연결
        let s = LibraryStore()
        s.attach(context: ctx)
        s.selectFolder(album)

        self.store = s
    }

    var body: some View {
        MasonryGridView(libraryStore: store) { _ in }
            .modelContainer(container)
            .frame(width: 900, height: 600)
    }
}
