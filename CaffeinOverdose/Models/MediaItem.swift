//
//  MediaItem.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//

import Foundation
import AVFoundation

enum MediaKind: String, Codable {
    case image, video
}

struct MediaItem: Identifiable, Hashable, Codable {
    let id: UUID
    var url: URL
    var filename: String
    var kind: MediaKind
    var pixelWidth: Int
    var pixelHeight: Int
    var duration: Double? // for video
    var parentFolderPath: String
    
    init(id: UUID = UUID(), url: URL, filename: String, kind: MediaKind, pixelWidth: Int, pixelHeight: Int, duration: Double?, parentFolderPath: String) {
        self.id = id
        self.url = url
        self.filename = filename
        self.kind = kind
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.duration = duration
        self.parentFolderPath = parentFolderPath
    }
    
    var aspectRatio: CGFloat {
        guard pixelHeight > 0 else { return 1 }
        return CGFloat(pixelWidth) / CGFloat(pixelHeight)
    }
}

extension MediaItem {
    /// LibraryLocation.media를 기준으로 상대경로를 계산
    func toRecord() -> MediaRecord {
        let base = LibraryLocation.media
        let rel = url.path.replacingOccurrences(of: base.path + "/", with: "")
        return MediaRecord(
            id: id,
            relativePath: rel,
            filename: filename,
            kind: kind,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            duration: duration,
            parentFolderPath: parentFolderPath
        )
    }

    static func fromRecord(_ r: MediaRecord) -> MediaItem {
        let absURL = LibraryLocation.media.appendingPathComponent(r.relativePath)
        return MediaItem(
            url: absURL,
            filename: r.filename,
            kind: r.kind,
            pixelWidth: r.pixelWidth,
            pixelHeight: r.pixelHeight,
            duration: r.duration,
            parentFolderPath: r.parentFolderPath
        )
    }
    
    init(url: URL,
         kind: MediaKind,
         pixelWidth: Int,
         pixelHeight: Int,
         duration: Double? = nil,
         parentFolderPath: String)
    {
        self.init(
            id: UUID(),
            url: url,
            filename: url.lastPathComponent,
            kind: kind,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            duration: duration,
            parentFolderPath: parentFolderPath
        )
    }
}
