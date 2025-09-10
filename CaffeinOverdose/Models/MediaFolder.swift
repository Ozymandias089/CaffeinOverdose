//
//  MediaFolder.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//

import Foundation
import SwiftData

@Model
final class MediaFolder {
    // Identifier
    @Attribute(.unique) var displayPath: String
    var name: String
    
    // Tree Relations
    @Relationship(inverse: \MediaFolder.subfolders) var parent: MediaFolder?
    @Relationship(deleteRule: .cascade) var subfolders: [MediaFolder] = []
    
    // Item Relations
    @Relationship(deleteRule: .cascade) var items: [MediaItem] = []
    
    init(displayPath: String, name: String, parent: MediaFolder? = nil) {
        self.displayPath = displayPath
        self.name = name
        self.parent = parent
    }
}

extension MediaFolder {
    static let rootPath = "/"
    var path: String { displayPath }
    var childrenOptional: [MediaFolder]? { subfolders } // 기존 SidebarView의 확장 그대로 보존
}
