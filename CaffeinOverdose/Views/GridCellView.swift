//
//  GridCellView.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/11/25.
//

import SwiftUI

struct GridCellView: View {
    let item: MediaItem
    let width: CGFloat
    var onTap: () -> Void
    
    var cornerRadius: CGFloat = 10

    @State private var image: NSImage?
    
    private var tileSize: CGSize {
        let ar = max(0.01, CGFloat(item.aspectRatio))
        let h = width / ar
        return CGSize(width: width, height: max(40, h)) // 최소 높이 가드
    }

    private var onePixel: CGFloat {
        #if canImport(AppKit)
        1.0 / (NSScreen.main?.backingScaleFactor ?? 2.0)
        #else
        1.0
        #endif
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
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
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(.separator.opacity(0.25), lineWidth: onePixel)
        }
        .frame(width: tileSize.width, height: tileSize.height)
        .clipped()
        .task(id: "\(item.uuid.uuidString)_\(Int(width))") {
            guard FileManager.default.fileExists(atPath: item.url.path) else { return }

            let currentID = item.id
            let w = Int(width.rounded())

            if Task.isCancelled { return }
            let data = await ThumbnailProvider.shared.thumbnailData(for: item, width: w)
            if Task.isCancelled { return }

            await MainActor.run {
                guard currentID == item.id else { return }   // 최신 셀만 반영
                withAnimation(.none) {
                    self.image = data.flatMap { NSImage(data: $0) }
                }
            }
        }
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
}

#if DEBUG
#Preview {
    let root = MediaFolder(displayPath: "/", name: "Library")
    let previewFolder = MediaFolder(displayPath: "/Preview", name: "Preview", parent: root)
    
    GridCellView(
        item: MediaItem(
            filename: "portrait_1.jpg",
            relativePath: "Preview/portrait_1.jpg",
            kindRaw: MediaKind.image.rawValue,
            pixelWidth: 800,
            pixelHeight: 1200,
            duration: nil,
            folder: previewFolder
        ),
        width: 200,
        onTap: { print("Tapped!") }
    )
    .frame(width: 200)
    .padding()
}
#endif
