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
    @MainActor
    func importFolderFromFilesystem(source: URL) async throws {
        precondition(context != nil, "LibraryStore.attach(context:) must be called before importing.")

        // 1) 라이브러리 폴더 보장 + 소스 폴더를 라이브러리로 복사
        let base = LibraryLocation.media
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        let dest = base.appendingPathComponent(source.lastPathComponent, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.copyItem(at: source, to: dest)
        }

        // 2) 루트 보장은 LibraryStore가 담당 (Importer는 루트 생성 안 함)
        try ensureRootFolder()

        // 3) 인덱싱은 Importer 한 곳에서만 수행 (관계 한쪽 갱신 + fetch-first 내부 적용)
        _ = await Importer.indexOneRoot(context: context, root: dest, strategy: .reference)

        // 4) 저장
        try context.save()

        // 5) UX: 방금 들여온 최상위 폴더 선택
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
