//
//  LibraryViewModel.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//

import SwiftUI

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var store: LibraryStore = LibraryStore()
    
    func importFromPanel() {
        Task {
            if let result = await Importer.runOpenPanelAndImport() {
                // ⬇️ 여기! Result → [MediaItem]
                store.addImportedItems(result.items)
            }
        }
    }
}
