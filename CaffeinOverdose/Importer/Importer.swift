//
//  Importer.swift
//  CaffeinOverdose
//
//  SwiftData-native importer:
//  - Open panel (MainActor)
//  - Bookmark the picked folders
//  - Copy OR Reference strategy
//  - Index into SwiftData (MediaFolder / MediaItem)
//

import Foundation
import AppKit
import AVFoundation
import SwiftData

enum Importer {

    enum Strategy {
        /// 복사: 원본을 ~/Pictures/CaffeinOverdose/<Top>/... 로 복사 후 인덱싱
        case copy
        /// 참조: 원본 위치를 그대로 참조 (권한은 BookmarkStore로 보존)
        case reference
    }

    struct Result: Sendable {
        let foldersIndexed: Int
        let itemsIndexed: Int
    }

    // MARK: - File selection panel

    /// 오픈패널을 띄우고 선택 폴더를 SwiftData로 인덱싱한다.
    /// - Parameters:
    ///   - context: SwiftData ModelContext
    ///   - strategy: .copy or .reference
    /// - Returns: 인덱싱 수치
    @MainActor
    static func runOpenPanelAndImport(context: ModelContext,
                                      strategy: Strategy = .copy) async -> Result? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Import"
        panel.message = "라이브러리에 추가할 폴더를 선택하세요."

        guard panel.runModal() == .OK else { return nil }
        let picked = panel.urls
        // 권한 북마크 저장
        picked.forEach { BookmarkStore.add(url: $0) }
        BookmarkStore.pruneMissingPaths()

        do { try LibraryLocation.ensureExists() } catch { print("ensureExists error:", error) }

        return await importFolders(context: context, roots: picked, strategy: strategy)
    }

    // MARK: - Importer
    /// 선택 폴더 배열을 인덱싱한다(복사/참조).
    @MainActor
    static func importFolders(context: ModelContext,
                              roots: [URL],
                              strategy: Strategy = .copy) async -> Result {
        // 루트 폴더 보장 (전부 MainActor에서 실행)
        do {
            if try fetchFolder(context: context, path: "/") == nil {
                context.insert(MediaFolder(displayPath: "/", name: "Library", parent: nil))
                try context.save() // ✅ 그냥 호출 (MainActor)
            }
        } catch { print("ensure root error:", error) }

        // 이 줄도 필요 없음: try? await MainActor.run { try context.save() }
        // (이미 함수 전체가 @MainActor)

        var dirRoots: [URL] = []
        var fileRoots: [URL] = []

        for r in roots {
            let isDir = (try? r.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir { dirRoots.append(r) } else { fileRoots.append(r) }
        }

        let flattenFilesToRoot = shouldFlattenToCommonParent(roots)

        var foldersCount = 0
        var itemsCount = 0

        // ⚠️ indexOneRoot / indexSingleFile 내부에서 파일 I/O는 백그라운드,
        // DB 반영은 ensureFolders/applyPendings(@MainActor)로 hop 하도록 이미 구성되어 있어야 함.
        for root in dirRoots {
            let counts = await indexOneRoot(context: context, root: root, strategy: strategy)
            foldersCount += counts.folders
            itemsCount += counts.items
        }

        for file in fileRoots {
            let added = await indexSingleFile(context: context,
                                              file: file,
                                              strategy: strategy,
                                              placeAtLibraryRoot: flattenFilesToRoot)
            itemsCount += added
        }

        do {
            try context.save() // ✅ MainActor에서 직접 save
        } catch {
            print("context.save error:", error)
        }

        return Result(foldersIndexed: foldersCount, itemsIndexed: itemsCount)
    }
}
