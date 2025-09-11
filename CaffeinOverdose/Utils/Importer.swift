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

    // MARK: - Public entrypoints

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

    // MARK: - entrypoints.importFolders()
    /// 선택 폴더 배열을 인덱싱한다(복사/참조).
    static func importFolders(context: ModelContext,
                              roots: [URL],
                              strategy: Strategy = .copy) async -> Result {
        // 루트 폴더 보장
        do {
            if try fetchFolder(context: context, path: "/") == nil {
                context.insert(MediaFolder(displayPath: "/", name: "Library", parent: nil))
                try context.save()
            }
        } catch { print("ensure root error:", error) }

        
        var dirRoots: [URL] = []
        var fileRoots: [URL] = []
        
        for r in roots {
            let isDir = (try? r.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if isDir { dirRoots.append(r) } else { fileRoots.append(r) }
        }

        let flattenFilesToRoot = shouldFlattenToCommonParent(roots)
        
        var foldersCount = 0
        var itemsCount = 0
        
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

        do { try context.save() } catch { print("context.save error:", error) }

        return Result(foldersIndexed: foldersCount, itemsIndexed: itemsCount)
    }

    // MARK: - CORE Root Folder Indexing

    /// 한 개의 최상위 폴더를 인덱싱
    private static func indexOneRoot(context: ModelContext,
                                     root: URL,
                                     strategy: Strategy) async -> (folders: Int, items: Int) {
        let base = LibraryLocation.media
        let fm = FileManager.default

        // COPY 전략이면 대상 최상위 경로 계산 및 생성
        let copyTop: URL = base.appendingPathComponent(root.lastPathComponent, isDirectory: true)
        if strategy == .copy {
            do { try fm.createDirectory(at: copyTop, withIntermediateDirectories: true) }
            catch { print("mkdir copyTop error:", error) }
        }

        // SwiftData: 캐시 (displayPath → MediaFolder)
        var folderCache: [String: MediaFolder] = [:]
        do {
            if let r = try fetchFolder(context: context, path: "/") {
                folderCache["/"] = r
            }
        } catch {
            print("fetchFolder(/) error:", error)
        }
        
        @discardableResult
        func ensureFolder(_ displayPath: String) throws -> MediaFolder {
            if let f = folderCache[displayPath] { return f }
            if displayPath == "/" { return folderCache["/"]! }

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

        // 최상위 폴더의 displayPath 보장
        let topDisplay: String = "/" + root.lastPathComponent
        do { _ = try ensureFolder(topDisplay) } catch { print("ensure top folder error:", error) }

        // 열거
        let keys: Set<URLResourceKey> = [.isDirectoryKey]
        var discovered: [URL] = []
        if let en = fm.enumerator(at: root, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) {
            while let obj = en.nextObject() as? URL { discovered.append(obj) }
        }

        var foldersAdded = 0
        var itemsAdded = 0

        // 폴더 먼저 보장
        for src in discovered {
            if (try? src.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                let rel = relativePath(of: src, under: root)
                let disp = topDisplay + (rel.isEmpty ? "" : "/" + rel)
                do {
                    if try fetchFolder(context: context, path: disp) == nil {
                        _ = try ensureFolder(disp); foldersAdded += 1
                    }
                } catch { print("ensure folder error:", error) }
            }
        }

        // 파일 인덱싱
        await withTaskGroup(of: Void.self) { group in
            for src in discovered {
                let isDir = (try? src.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if isDir { continue }

                let ext = src.pathExtension.lowercased()
                let isVideo = videoExts.contains(ext)
                let isImage = imageExts.contains(ext)
                if !(isVideo || isImage) { continue }

                group.addTask {
                    do {
                        let (dst, relToLibrary): (URL, String) = {
                            switch strategy {
                            case .copy:
                                let relUnderRoot = relativePath(of: src, under: root) // "a/b/c.jpg"
                                let dst = copyTop.appendingPathComponent(relUnderRoot, isDirectory: false)
                                // 상위 생성
                                try? fm.createDirectory(at: dst.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                                if !fm.fileExists(atPath: dst.path) {
                                    do { try fm.copyItem(at: src, to: dst) }
                                    catch { print("copyItem error \(src.path) -> \(dst.path):", error) }
                                }
                                let relToLibrary = root.lastPathComponent + (relUnderRoot.isEmpty ? "" : "/\(relUnderRoot)")
                                return (dst, relToLibrary)

                            case .reference:
                                // 참조는 파일을 복사하지 않고 원본을 라이브러리 상대경로로 매핑
                                // 상대경로는 "<Top>/<...>" 형식으로 구성
                                let relUnderRoot = relativePath(of: src, under: root)
                                let relToLibrary = root.lastPathComponent + (relUnderRoot.isEmpty ? "" : "/\(relUnderRoot)")
                                let dst = src // 실제 파일 위치
                                return (dst, relToLibrary)
                            }
                        }()

                        // 메타 추출
                        let meta = await probe(url: dst, isVideo: isVideo)

                        // 표시용 부모 경로: "/<Top>/<subdirs>"
                        let parentDisplay: String = {
                            let comps = relToLibrary.split(separator: "/")
                            if comps.count <= 1 { return topDisplay }
                            return "/" + comps.dropLast().joined(separator: "/")
                        }()

                        // SwiftData 폴더 보장
                        let folder = try ensureFolder(parentDisplay)

                        // 중복 방지 (relativePath = 라이브러리 기준)
                        var fd = FetchDescriptor<MediaItem>(predicate: #Predicate { $0.relativePath == relToLibrary })
                        fd.fetchLimit = 1
                        if try context.fetch(fd).first == nil {
                            let item = MediaItem(
                                filename: (dst.lastPathComponent),
                                relativePath: relToLibrary,
                                kindRaw: (isVideo ? MediaKind.video : .image).rawValue,
                                pixelWidth: meta.w,
                                pixelHeight: meta.h,
                                duration: meta.dur,
                                folder: folder
                            )
                            context.insert(item)
                            itemsAdded += 1
                        }
                    } catch {
                        print("index file error:", error)
                    }
                }
            }

            // 모든 파일 작업 완료 기다림
            await group.waitForAll()
        }

        return (foldersAdded, itemsAdded)
    }
    
    // MARK: - CORE Single File indexing
    
    private static func indexSingleFile(context: ModelContext,
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

    
    // MARK: - Helpers

    private static let videoExts: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv", "webm"]
    private static let imageExts: Set<String> = ["heic","heif","jpg","jpeg","png","gif","bmp","tiff","tif"]

    private static func relativePath(of url: URL, under root: URL) -> String {
        let base = root.path.hasSuffix("/") ? root.path : root.path + "/"
        if url.path.hasPrefix(base) { return String(url.path.dropFirst(base.count)) }
        return url.lastPathComponent
    }

    private static func fetchFolder(context: ModelContext, path: String) throws -> MediaFolder? {
        var fd = FetchDescriptor<MediaFolder>(predicate: #Predicate { $0.displayPath == path })
        fd.fetchLimit = 1
        return try context.fetch(fd).first
    }

    private static func probe(url: URL, isVideo: Bool) async -> (w: Int, h: Int, dur: Double?) {
        if isVideo {
            let asset = AVURLAsset(url: url)
            let duration: CMTime = (try? await asset.load(.duration)) ?? .zero
            if let track = (try? await asset.loadTracks(withMediaType: .video))?.first {
                let naturalSize = (try? await track.load(.naturalSize)) ?? .zero
                let transform  = (try? await track.load(.preferredTransform)) ?? .identity
                let size = naturalSize.applying(transform)
                return (Int(abs(size.width)), Int(abs(size.height)), duration.seconds)
            } else {
                return (0, 0, duration.seconds)
            }
        } else {
            #if canImport(AppKit)
            if let img = NSImage(contentsOf: url) {
                return (Int(img.size.width), Int(img.size.height), nil)
            }
            #endif
            return (0, 0, nil)
        }
    }
    
    private static func shouldFlattenToCommonParent(_ urls: [URL]) -> Bool {
        guard !urls.isEmpty else { return false }
        // 모든 선택 항목의 "직접 부모"가 동일하면 true (부모 자체를 선택한 건 아님)
        let parents = Set(urls.map { $0.deletingLastPathComponent() })
        return parents.count == 1
    }

}
