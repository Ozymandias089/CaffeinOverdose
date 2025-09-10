//
//  MediaFolder+Example.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//

import Foundation

extension MediaFolder {
    static func exampleTree() -> MediaFolder {
        let root = MediaFolder(name: "Library", path: "/")
        let untitled = MediaFolder(name: "Untitled", path: "/Untitled")
        let untitled2 = MediaFolder(name: "Untitled2", path: "/Untitled2")
        let child = MediaFolder(name: "Untitled", path: "/Untitled2/Untitled")

        untitled.items = [
            MediaItem.example(w: 1200, h: 800, name: "IMG_1733.HEIC", parent: "/Untitled"),
            MediaItem.example(w: 800,  h: 1200, name: "IMG_1734.HEIC", parent: "/Untitled"),
        ]
        child.items = [
            MediaItem.example(w: 1600, h: 900, name: "IMG_0058.jpg", parent: "/Untitled2/Untitled"),
            MediaItem.example(w: 1536, h: 2048, name: "IMG_1619.heic", parent: "/Untitled2/Untitled"),
        ]
        untitled2.subfolders = [child]
        untitled2.items = [
            MediaItem.example(w: 1920, h: 1080, name: "IMG_1678.jpg", parent: "/Untitled2"),
            MediaItem.example(kind: .video, w: 1920, h: 1080, name: "IMG_1730.mp4", parent: "/Untitled2"),
        ]

        root.subfolders = [untitled, untitled2]
        root.items = [
            MediaItem.example(w: 1440, h: 900, name: "스크린샷.png", parent: "/"),
        ]
        return root
    }
}
