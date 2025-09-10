//
//  LibraryViewModel.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//
// LibraryViewModel.swift
import SwiftData
import AppKit

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var store: LibraryStore = LibraryStore()
    private weak var context: ModelContext?

    func attach(context: ModelContext) {
        self.context = context
        store.attach(context: context)
    }

    func importFromPanel() {
        guard let ctx = context else { return }
        Task {
            _ = await Importer.runOpenPanelAndImport(context: ctx, strategy: .copy)
            // UX: 새로 들어온 최상위 폴더로 선택 이동(선택)
            if let last = BookmarkStore.listPaths().last,
               let name = last.split(separator: "/").last {
                let path = "/" + name
                if let f = store.folder(at: path) { store.selectFolder(f) }
            }
        }
    }
}
