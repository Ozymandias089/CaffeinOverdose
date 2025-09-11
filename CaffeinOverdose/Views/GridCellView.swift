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
            if let img = await ThumbnailProvider.shared.thumbnailImage(for: item, width: width) {
                // 변경: 애니메이션 없이 상태 반영
                withAnimation(.none) { self.image = img }
            } else {
                withAnimation(.none) { self.image = nil } // or 실패 상태 표시
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
