//
//  MediaFolder.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//

import Foundation

final class MediaFolder: Identifiable, ObservableObject, Hashable {
    static func == (lhs: MediaFolder, rhs: MediaFolder) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    let id = UUID()
    let name: String
    let path: String  // display path
    @Published var subfolders: [MediaFolder] = []
    @Published var items: [MediaItem] = []

    init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}
