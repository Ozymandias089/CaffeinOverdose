// MARK: - ViewModel
//  DetailViewViewModel.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/12/25.
//  Swift 6 / macOS 15.6

import SwiftUI
import AVKit
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
    @Published var player: AVPlayer?
    @Published var errorMessage: String?

    // MARK: - Lifecycle / DI
    init() {}

    /// Call once (or whenever the data set changes) after the view has an Environment `ModelContext`.
    func configure(context: ModelContext, itemIDs: [UUID], index: Int) {
        self.context = context
        self.itemIDs = itemIDs
        self.index = min(max(0, index), max(0, itemIDs.count - 1))
        print("VM.configure → itemIDs.count=\(itemIDs.count), index=\(self.index)")
        loadCurrent()
    }

    // MARK: - Derived
    var canGoPrev: Bool { index > 0 }
    var canGoNext: Bool { index < itemIDs.count - 1 }

    // MARK: - Navigation
    func setIndex(_ newIndex: Int) {
        let clamped = min(max(0, newIndex), max(0, itemIDs.count - 1))
        guard clamped != index else { return }
        index = clamped
        loadCurrent()
    }

    func prev() { guard canGoPrev else { return }; index -= 1; loadCurrent() }
    func next() { guard canGoNext else { return }; index += 1; loadCurrent() }

    // MARK: - Playback
    func togglePlay() {
        guard let p = player else { return }
        (p.timeControlStatus == .playing) ? p.pause() : p.play()
    }

    func stopPlayer() {
        player?.pause()
        player = nil
    }

    // MARK: - Loading
    func loadCurrent() {
        print("VM.loadCurrent → index=\(index), bounds=\(itemIDs.count)")
        guard itemIDs.indices.contains(index) else {
            loadedItem = nil
            stopPlayer()
            print("VM.loadCurrent → index out of bounds")
            return
        }
        let id = itemIDs[index]
        print("VM.loadCurrent → will fetch uuid=\(id)")
        loadedItem = fetchItem(by: id)

        if let it = loadedItem {
            if it.kind == .video {
                stopPlayer()
                player = AVPlayer(url: it.url)
            } else {
                stopPlayer()
            }
        } else {
            stopPlayer()
        }
    }

    private func fetchItem(by id: UUID) -> MediaItem? {
        guard let context else {
            print("VM.fetchItem → no context")
            return nil
        }
        let needle = id
        let pred = #Predicate<MediaItem> { $0.uuid == needle }
        var fd = FetchDescriptor<MediaItem>(predicate: pred)
        fd.fetchLimit = 1
        
        do {
            let r = try context.fetch(fd)
            print("VM.fetchItem → by uuid count=\(r.count) uuid=\(id)")
            if let first = r.first { return first }

            // 🔎 추가 진단: DB에 뭐가 있나 샘플 덤프
            var all = FetchDescriptor<MediaItem>()
            all.fetchLimit = 5
            let sample = try context.fetch(all)
            print("VM.fetchItem → sample \(sample.count) items:")
            for s in sample {
                print("  • uuid=\(s.uuid) filename=\(s.filename) rel=\(s.relativePath)")
            }
            return nil
        } catch {
            print("VM.fetchItem → error for uuid=\(id):", error)
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - View Hooks
    func onAppear() { /* no-op, kept for symmetry */ }
    func onDisappear() { stopPlayer() }
}
