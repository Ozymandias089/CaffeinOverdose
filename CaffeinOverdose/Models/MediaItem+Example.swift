//
//  MediaItem+Example.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//

import Foundation
import CoreGraphics

extension MediaItem {
    static func example(kind: MediaKind = .image, w: Int = 1600, h: Int = 1200, name: String = "example.jpg", parent: String = "/") -> MediaItem {
        let fakeURL = URL(fileURLWithPath: "/tmp/\(name)") // 미리보기 용도
        return MediaItem(
            url: fakeURL,
            filename: name,
            kind: kind,
            pixelWidth: w,
            pixelHeight: h,
            duration: kind == .video ? 3.2 : nil,
            parentFolderPath: parent
        )
    }

    static func examples() -> [MediaItem] {
        [
            .example(w: 800,  h: 1200, name: "portrait_1.jpg", parent: "/Untitled"),
            .example(w: 1600, h: 900,  name: "landscape_1.jpg", parent: "/Untitled"),
            .example(kind: .video, w: 1920, h: 1080, name: "clip_1.mov", parent: "/Untitled2"),
            .example(w: 1080, h: 1080, name: "square_1.jpg", parent: "/"),
        ]
    }
}
