//  DetailViewViewModel.swift
//  CaffeinOverdose
//
//  Swift 6 / macOS 15.6

import SwiftUI
import SwiftData
import AppKit

@MainActor
final class DetailViewViewModel: ObservableObject {
    // Dependencies
    private var context: ModelContext?

    // Inputs
    @Published var itemIDs: [UUID] = []
    @Published var index: Int = 0

    // State
    @Published var loadedItem: MediaItem?
    @Published var errorMessage: String?

    init() {}

    func configure(context: ModelContext, itemIDs: [UUID], index: Int) {
        self.context = context
        self.itemIDs = itemIDs
        self.index = clamp(index, 0, max(0, itemIDs.count - 1))
        loadCurrent()
    }

    // Derived
    var canGoPrev: Bool { index > 0 }
    var canGoNext: Bool { index < itemIDs.count - 1 }

    // Navigation
    func setIndex(_ newIndex: Int) {
        let clamped = clamp(newIndex, 0, max(0, itemIDs.count - 1))
        guard clamped != index else { return }
        index = clamped
        loadCurrent()
    }

    func prev() { guard canGoPrev else { return }; index -= 1; loadCurrent() }
    func next() { guard canGoNext else { return }; index += 1; loadCurrent() }

    // Loading
    func loadCurrent() {
        guard itemIDs.indices.contains(index) else {
            loadedItem = nil
            return
        }
        loadedItem = fetchItem(by: itemIDs[index])
    }

    private func fetchItem(by id: UUID) -> MediaItem? {
        guard let context else { return nil }
        let pred = #Predicate<MediaItem> { $0.uuid == id }
        var fd = FetchDescriptor<MediaItem>(predicate: pred)
        fd.fetchLimit = 1
        do { return try context.fetch(fd).first }
        catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // URLs
    func urlForItem(uuid: UUID) -> URL? {
        guard let it = fetchItem(by: uuid) else { return nil }
        return it.url
    }

    func urlsForItems() -> [URL]? {
        let out = itemIDs.compactMap { urlForItem(uuid: $0) }
        return out.isEmpty ? nil : out
    }

    // External player for WEBM
    func openInIINA(_ url: URL) {
        let cfg = NSWorkspace.OpenConfiguration()
        let iinaURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.colliderli.iina")
        NSWorkspace.shared.open([url],
                                withApplicationAt: iinaURL ?? URL(fileURLWithPath: "/Applications/IINA.app"),
                                configuration: cfg) { _, error in
            if let error { print("IINA open error:", error) }
        }
    }

    func onAppear() {}
    func onDisappear() {}
}

// small util
private func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T {
    return min(max(v, lo), hi)
}
