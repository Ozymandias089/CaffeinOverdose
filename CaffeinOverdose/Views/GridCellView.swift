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
    }
}

#Preview {
    GridCellView(
        item: MediaItem(
            filename: "portrait_1.jpg",
            relativePath: "Preview/portrait_1.jpg",
            kindRaw: MediaKind.image.rawValue,
            pixelWidth: 800,
            pixelHeight: 1200,
            duration: nil,
            folder: nil
        ),
        width: 200,
        onTap: { print("Tapped!") }
    )
    .frame(width: 200)
    .padding()
}
