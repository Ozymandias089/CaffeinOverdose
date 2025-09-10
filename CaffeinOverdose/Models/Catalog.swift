//
//  Catalog.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//

import Foundation

/// db.json v1 포맷 (플랫 레코드)
struct CatalogV1: Codable {
    var version: Int = 1
    var items: [MediaRecord] = []
}

/// MediaItem을 저장할 때 사용하는 직렬화용 레코드
struct MediaRecord: Codable, Hashable {
    var id: UUID
    var relativePath: String   // LibraryLocation.media 기준 상대경로 (예: "Untitled/IMG_1733.HEIC")
    var filename: String
    var kind: MediaKind
    var pixelWidth: Int
    var pixelHeight: Int
    var duration: Double?
    var parentFolderPath: String // 디스플레이용 경로 (예: "/Untitled" "/Untitled2/Untitled")
}
