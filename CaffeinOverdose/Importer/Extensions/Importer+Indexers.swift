//
//  Importer+Indexers.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/11/25.
//

import Foundation
import SwiftData

// MARK: - struct Pending
struct Pending: Sendable {
    let relToLibrary: String
    let parentDisplay: String
    let filename: String
    let isVideo: Bool
    let metaW: Int
    let metaH: Int
    let metaDur: Double?
}

extension Importer {
    
    // MARK: - Directories indexing
    static func indexOneRoot(context: ModelContext,
                             root: URL,
                             strategy: Strategy) async -> (folders: Int, items: Int) {
        let base = LibraryLocation.media
        let fm = FileManager.default

        // COPY 전략이면 대상 최상위 경로 계산 및 생성
        let copyTop: URL = base.appendingPathComponent(root.lastPathComponent, isDirectory: true)
        if strategy == .copy {
            try? fm.createDirectory(at: copyTop, withIntermediateDirectories: true)
        }

        // 최상위 displayPath
        let topDisplay: String = "/" + root.lastPathComponent

        // 🔹 열거
        let keys: Set<URLResourceKey> = [.isDirectoryKey]
        var discovered: [URL] = []
        if let en = fm.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) {
            while let obj = en.nextObject() as? URL { discovered.append(obj) }
        }

        // 🔹 "보장해야 할 디렉터리" 수집 (top 포함)
        var folderPathsToEnsure: Set<String> = [topDisplay]
        for src in discovered {
            if (try? src.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                let rel = relativePath(of: src, under: root)
                let disp = topDisplay + (rel.isEmpty ? "" : "/" + rel)
                folderPathsToEnsure.insert(disp)
            }
        }

        // 🔹 먼저 디렉터리 보장 (@MainActor)
        let foldersAdded = await Importer.ensureFolders(Array(folderPathsToEnsure), context: context)
        
        var pendings: [Pending] = []

        await withTaskGroup(of: Pending?.self) { group in
            for src in discovered {
                let isDir = (try? src.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir { continue }

                let ext = src.pathExtension.lowercased()
                let isVideo = videoExts.contains(ext)
                let isImage = imageExts.contains(ext)
                if !(isVideo || isImage) { continue }

                group.addTask {
                    // 1) 파일 복사/참조
                    let relUnderRoot = relativePath(of: src, under: root)   // "a/b/c.jpg" 또는 ""
                    let relToLibrary = root.lastPathComponent + (relUnderRoot.isEmpty ? "" : "/\(relUnderRoot)")

                    let dst: URL = {
                        switch strategy {
                        case .copy:
                            let d = copyTop.appendingPathComponent(relUnderRoot, isDirectory: false)
                            try? fm.createDirectory(at: d.deletingLastPathComponent(), withIntermediateDirectories: true)
                            if !fm.fileExists(atPath: d.path) {
                                try? fm.copyItem(at: src, to: d)
                            }
                            return d
                        case .reference:
                            return src
                        }
                    }()

                    // 2) 메타 추출
                    let meta = await probe(url: dst, isVideo: isVideo)

                    // 3) 부모 displayPath
                    let parentDisplay: String = {
                        let comps = relToLibrary.split(separator: "/")
                        if comps.count <= 1 { return topDisplay }
                        return "/" + comps.dropLast().joined(separator: "/")
                    }()

                    return Pending(
                        relToLibrary: relToLibrary,
                        parentDisplay: parentDisplay,
                        filename: dst.lastPathComponent,
                        isVideo: isVideo,
                        metaW: meta.w, metaH: meta.h, metaDur: meta.dur
                    )
                }
            }

            for await p in group {
                if let p { pendings.append(p) }
            }
        }

        // 🔹 마지막에 한 번에 DB 반영 (@MainActor)
        let itemsAdded = await Importer.applyPendings(pendings, context: context)

        return (foldersAdded, itemsAdded)
    }

    
    // MARK: - Single File indexing
    
    static func indexSingleFile(context: ModelContext,
                                        file: URL,
                                        strategy: Strategy,
                                        placeAtLibraryRoot: Bool = false) async -> Int {
        let fm = FileManager.default
        let base = LibraryLocation.media

        let parentName = file.deletingLastPathComponent().lastPathComponent
        // ✅ 평탄화면 루트(/), 아니면 기존처럼 부모명 아래
        let topName: String? = placeAtLibraryRoot ? nil : (parentName.isEmpty ? "Imports" : parentName)

        let relToLibrary: String = {
            if let t = topName { return "\(t)/\(file.lastPathComponent)" }
            else { return file.lastPathComponent } // 루트로
        }()

        let topDisplay: String = {
            if let t = topName { return "/" + t }
            else { return "/" } // 루트 폴더
        }()

        // SwiftData 폴더 보장 (루트 또는 "/<top>")
        func ensureFolder(_ displayPath: String) throws -> MediaFolder {
            if let existing = try fetchFolder(context: context, path: displayPath) {
                return existing
            }
            // 루트("/")는 importFolders 시작에서 이미 보장함
            let comps = displayPath.split(separator: "/")
            let parentPath = comps.dropLast().isEmpty ? "/" : "/" + comps.dropLast().joined(separator: "/")
            let parent = (try fetchFolder(context: context, path: parentPath)) ??
                         { let p = MediaFolder(displayPath: "/", name: "Library", parent: nil); context.insert(p); return p }()
            let name = comps.last.map(String.init) ?? "Library"
            let node = MediaFolder(displayPath: displayPath, name: name, parent: parent)
            parent.subfolders.append(node)
            context.insert(node)
            return node
        }

        do {
            let dst: URL = {
                switch strategy {
                case .copy:
                    let dst = base.appendingPathComponent(relToLibrary, isDirectory: false)
                    try? fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
                    if !fm.fileExists(atPath: dst.path) {
                        do { try fm.copyItem(at: file, to: dst) } catch { print("copyItem error:", error) }
                    }
                    return dst
                case .reference:
                    return file
                }
            }()

            let isVideo = videoExts.contains(file.pathExtension.lowercased())
            let meta = await probe(url: dst, isVideo: isVideo)

            let folder = try ensureFolder(topDisplay)

            var fd = FetchDescriptor<MediaItem>(predicate: #Predicate { $0.relativePath == relToLibrary })
            fd.fetchLimit = 1
            if try context.fetch(fd).first == nil {
                let item = MediaItem(
                    filename: dst.lastPathComponent,
                    relativePath: relToLibrary,
                    kindRaw: (isVideo ? MediaKind.video : .image).rawValue,
                    pixelWidth: meta.w,
                    pixelHeight: meta.h,
                    duration: meta.dur,
                    folder: folder
                )
                context.insert(item)
                return 1
            }
        } catch {
            print("indexSingleFile error:", error)
        }
        return 0
    }
}
