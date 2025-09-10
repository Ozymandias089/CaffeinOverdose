//
//  LibraryStore.swift
//  CaffeinOverdose
//
//  v1: 로컬 JSON 카탈로그 방식 (~/Pictures/CaffeinOverdose.coffeelib/db.json)
//  - 플랫 배열로 저장/로드
//  - 앱 시작 시 트리 재구성
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
final class LibraryStore: ObservableObject {

    // MARK: - SwiftData
    private var context: ModelContext!

    // MARK: - Published UI State (unchanged for compatibility)
    @Published var root: MediaFolder = .init(displayPath: "/", name: "Library", parent: nil)
    @Published var selectedFolder: MediaFolder?

    // MARK: - Lifecycle
    init() { }

    /// Must be called once (e.g., in ContentView.task { vm.attach(context:) })
    // LibraryStore.attach(context:)
    func attach(context: ModelContext) {
        self.context = context

        // ✅ 앱 시작 시 bookmarked 폴더 접근권한 복원
        _ = BookmarkStore.restoreAndStartAccessingAll()
        BookmarkStore.pruneMissingPaths()

        do { try LibraryLocation.ensureExists() } catch { print(error) }
        do { try ensureRootFolder() } catch { print(error) }
        do { if let r = try fetchFolder(path: "/") { self.root = r } } catch { print(error) }

        if selectedFolder == nil { selectedFolder = root }
    }


    // MARK: - Public API used by UI

    func selectFolder(_ folder: MediaFolder?) {
        selectedFolder = folder
    }

    func folder(at path: String) -> MediaFolder? {
        try? fetchFolder(path: path)
    }

    /// Copies a picked folder into the library root and indexes it into SwiftData.
    func importFolderFromFilesystem(source: URL) throws {
        precondition(context != nil, "LibraryStore.attach(context:) must be called before importing.")

        let base = LibraryLocation.media
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        let dest = base.appendingPathComponent(source.lastPathComponent, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.copyItem(at: source, to: dest)
        }

        try ensureRootFolder()
        let root = try fetchOrCrash(path: "/")

        // Cache: displayPath → MediaFolder
        var folderCache: [String: MediaFolder] = ["/": root]

        @discardableResult
        func ensureFolder(_ displayPath: String) throws -> MediaFolder {
            if let f = folderCache[displayPath] { return f }
            if displayPath == "/" { return root }

            let comps = displayPath.split(separator: "/")
            let parentPath = comps.dropLast().isEmpty ? "/" : "/" + comps.dropLast().joined(separator: "/")
            let parent = try ensureFolder(parentPath)
            let name = comps.last.map(String.init) ?? "Untitled"

            let node = MediaFolder(displayPath: displayPath, name: name, parent: parent)
            parent.subfolders.append(node)
            context.insert(node)
            folderCache[displayPath] = node
            return node
        }

        // Ensure the top-level imported folder exists
        let topRel = dest.path.replacingOccurrences(of: base.path, with: "")
        let topDisplay = topRel.isEmpty ? "/" : topRel
        _ = try ensureFolder(topDisplay)

        // Enumerate and index
        let keys: Set<URLResourceKey> = [.isDirectoryKey]
        guard let en = FileManager.default.enumerator(
            at: dest,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            try context.save()
            return
        }

        for case let url as URL in en {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let rel = url.path.replacingOccurrences(of: base.path + "/", with: "")

            if isDir {
                _ = try ensureFolder("/" + rel)
            } else {
                let displayPath = "/" + rel.split(separator: "/").dropLast().joined(separator: "/")
                let folder = try ensureFolder(displayPath.isEmpty ? "/" : displayPath)

                // Dedup by relativePath
                var fd = FetchDescriptor<MediaItem>(predicate: #Predicate { $0.relativePath == rel })
                fd.fetchLimit = 1
                if try context.fetch(fd).first == nil {
                    let filename = url.lastPathComponent
                    let kind = inferKind(fromExtension: url.pathExtension)

                    let item = MediaItem(
                        filename: filename,
                        relativePath: rel,
                        kindRaw: kind.rawValue,
                        pixelWidth: 0,
                        pixelHeight: 0,
                        duration: kind == .video ? 0 : nil,
                        folder: folder
                    )
                    context.insert(item)
                }
            }
        }

        try context.save()

        // Move selection to imported folder (nice UX)
        if let newFolder = try fetchFolder(path: "/" + source.lastPathComponent) {
            self.selectedFolder = newFolder
        }
    }

    // MARK: - Private (SwiftData helpers)

    private func ensureRootFolder() throws {
        if try fetchFolder(path: "/") == nil {
            let r = MediaFolder(displayPath: "/", name: "Library", parent: nil)
            context.insert(r)
            try context.save()
        }
    }

    private func fetchFolder(path: String) throws -> MediaFolder? {
        var fd = FetchDescriptor<MediaFolder>(predicate: #Predicate { $0.displayPath == path })
        fd.fetchLimit = 1
        return try context.fetch(fd).first
    }

    private func fetchOrCrash(path: String) throws -> MediaFolder {
        if let f = try fetchFolder(path: path) { return f }
        throw NSError(domain: "LibraryStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Folder not found: \(path)"])
    }

    private func inferKind(fromExtension ext: String) -> MediaKind {
        let e = ext.lowercased()
        let videos = ["mp4","mov","m4v","avi","mkv","webm"]
        return videos.contains(e) ? .video : .image
    }
}
