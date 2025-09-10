//
//  MasonryGridView.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//
import SwiftUI
import WaterfallGrid
import AppKit

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

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                // ✅ ViewBuilder 내부에 let/var 선언 안 함
                WaterfallGrid(Array(items.enumerated()), id: \.element.id) { pair in
                    ThumbCell(
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

private struct ThumbCell: View {
    let item: MediaItem
    let width: CGFloat
    var onTap: () -> Void

    @State private var image: NSImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(item.aspectRatio, contentMode: .fit)
                    .onTapGesture { onTap() }
            } else {
                Rectangle().opacity(0.08)
                    .aspectRatio(item.aspectRatio, contentMode: .fit)
                    .overlay { ProgressView().padding() }
            }
            if item.kind == .video {
                Image(systemName: "play.circle.fill")
                    .imageScale(.large)
                    .padding(6)
            }
        }
        .task(id: "\(item.id.uuidString)_\(Int(width))") {
            guard FileManager.default.fileExists(atPath: item.url.path) else { return }
            if let img = await ThumbnailProvider.shared.thumbnailImage(for: item, width: width) {
                // 변경: 애니메이션 없이 상태 반영
                withAnimation(.none) { self.image = img }
            } else {
                withAnimation(.none) { self.image = nil } // or 실패 상태 표시
            }
        }
    }
}

private struct Preview_MasonryGridView: View {
    let store: LibraryStore = {
        let s = LibraryStore()
        s.root = .exampleTree()
        s.selectedFolder = s.root.subfolders.first ?? s.root
        return s
    }()

    var body: some View {
        MasonryGridView(libraryStore: store)
            .frame(width: 900, height: 600)
    }
}

#Preview { Preview_MasonryGridView() }
