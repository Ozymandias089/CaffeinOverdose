//
//  MediaItem.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//

import Foundation
import SwiftData
import AVFoundation

@Model
final class MediaItem {
    // Identifier
    @Attribute(.unique) var uuid: UUID
    
    // File Metadata
    var filename: String
    var relativePath: String    // LibraryLocation.media 기준 String으로 저장 권장
    var kindRaw: String // enum 저장은 row
    var pixelWidth: Int
    var pixelHeight: Int
    var duration: Double? // for video
    
    // Folder Relations
    @Relationship var folder: MediaFolder
    
    // Timestamp
    var createdAt: Date
    var updatedAt: Date
    
    init(
        uuid: UUID = UUID(),
        filename: String,
        relativePath: String,
        kindRaw: String,
        pixelWidth: Int,
        pixelHeight: Int,
        duration: Double? = nil,
        folder: MediaFolder
    ) {
        self.uuid = uuid
        self.filename = filename
        self.relativePath = relativePath
        self.kindRaw = kindRaw
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.duration = duration
        self.folder = folder
        self.createdAt = .now
        self.updatedAt = .now
    }
}

extension MediaItem {
    var kind: MediaKind { MediaKind(rawValue: kindRaw) ?? .image }
    var url: URL { LibraryLocation.media.appendingPathComponent(relativePath) }
    var aspectRatio: Double { pixelHeight > 0 ? Double(pixelWidth) / Double(pixelHeight) : 1.0 }
    var absoluteURL: URL { LibraryLocation.media.appendingPathComponent(relativePath) }
}
