//
//  Importer+Helpers.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/11/25.
//

import Foundation
import AVFoundation
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

extension Importer {
    static let videoExts: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv", "webm"]
    static let imageExts: Set<String> = ["heic","heif","jpg","jpeg","png","gif","bmp","tiff","tif"]

    // MARK: - relativePath()
    static func relativePath(of url: URL, under root: URL) -> String {
        let base = root.path.hasSuffix("/") ? root.path : root.path + "/"
        if url.path.hasPrefix(base) { return String(url.path.dropFirst(base.count)) }
        return url.lastPathComponent
    }

    // MARK: - fetchFolder()
    static func fetchFolder(context: ModelContext, path: String) throws -> MediaFolder? {
        var fd = FetchDescriptor<MediaFolder>(predicate: #Predicate { $0.displayPath == path })
        fd.fetchLimit = 1
        return try context.fetch(fd).first
    }

    // MARK: - probe()
    static func probe(url: URL, isVideo: Bool) async -> (w: Int, h: Int, dur: Double?) {
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
    
    // MARK: - shouldFlattenToCommonParent()
    static func shouldFlattenToCommonParent(_ urls: [URL]) -> Bool {
        guard !urls.isEmpty else { return false }
        // 모든 선택 항목의 "직접 부모"가 동일하면 true (부모 자체를 선택한 건 아님)
        let parents = Set(urls.map { $0.deletingLastPathComponent() })
        return parents.count == 1
    }
    
    // MARK: - ensureFolders()
    // 디렉터리 보장: 전달된 displayPath들을 보장하고, 새로 만든 개수를 리턴
    @MainActor
    static func ensureFolders(_ displayPaths: [String], context: ModelContext) -> Int {
        do {
            var ensurer = try FolderEnsurer(context: context)
            for path in displayPaths {
                do { _ = try ensurer.ensure(path) }
                catch { print("ensureFolders ensure(\(path)) error:", error) }
            }
            return ensurer.createdCount
        } catch {
            print("ensureFolders init error:", error)
            return 0
        }
    }

    // MARK: - applyPendings()
    // 파일 삽입: Pending 배열을 적용하고, 실제로 insert된 item 수를 리턴
    @MainActor
    static func applyPendings(_ pendings: [Pending], context: ModelContext) -> Int {
        var inserted = 0
        do {
            var ensurer = try FolderEnsurer(context: context)
            for p in pendings {
                do {
                    let folder = try ensurer.ensure(p.parentDisplay)
                    
                    let rel = p.relToLibrary

                    // relativePath로 중복 방지
                    var fd = FetchDescriptor<MediaItem>(predicate: #Predicate { $0.relativePath == rel })
                    fd.fetchLimit = 1
                    if try context.fetch(fd).first == nil {
                        let item = MediaItem(
                            filename: p.filename,
                            relativePath: rel,
                            kindRaw: (p.isVideo ? MediaKind.video : .image).rawValue,
                            pixelWidth: p.metaW,
                            pixelHeight: p.metaH,
                            duration: p.metaDur,
                            folder: folder
                        )
                        context.insert(item)
                        inserted += 1
                    }
                } catch {
                    print("applyPendings error:", error)
                }
            }
        } catch {
            print("applyPendings init error:", error)
        }
        return inserted
    }
}

// MARK: - Extensions
extension Importer {
    // 경로 정규화(선택) — leading "/" 보장, trailing "/" 제거(루트 제외)
    @inline(__always)
    fileprivate static func normalizeDisplayPath(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return "/" }
        if !s.hasPrefix("/") { s = "/" + s }
        if s.count > 1, s.hasSuffix("/") { s.removeLast() }
        return s
    }

    // MARK: - struct FolderEnsurer
    // 폴더 보장 헬퍼: 캐시 + fetch-first + child만 parent 지정
    @MainActor
    struct FolderEnsurer {
        private(set) var createdCount = 0
        private var cache: [String: MediaFolder] = [:]
        private let context: ModelContext

        init(context: ModelContext) throws {
            self.context = context
            // 루트는 LibraryStore가 보장 — 여기선 fetch-only
            guard let root = try Importer.fetchFolder(context: context, path: "/") else {
                assertionFailure("Root folder (/) is missing. Ensure LibraryStore.attach() ran.")
                throw NSError(domain: "Importer", code: 500, userInfo: [NSLocalizedDescriptionKey: "Missing root /"])
            }
            cache["/"] = root
        }

        // MARK: - func ensure()
        mutating func ensure(_ rawPath: String) throws -> MediaFolder {
            let displayPath = Importer.normalizeDisplayPath(rawPath)
            if let f = cache[displayPath] { return f }
            if displayPath == "/" { return cache["/"]! }

            // 1) fetch-first (중복 생성 방지)
            var fd = FetchDescriptor<MediaFolder>(predicate: #Predicate { $0.displayPath == displayPath })
            fd.fetchLimit = 1
            if let existing = try context.fetch(fd).first {
                cache[displayPath] = existing
                return existing
            }

            // 2) 부모부터 보장
            let comps = displayPath.split(separator: "/")
            let parentPath = comps.dropLast().isEmpty ? "/" : "/" + comps.dropLast().joined(separator: "/")
            let parent = try ensure(parentPath)
            let name = comps.last.map(String.init) ?? "Untitled"

            // 3) child에서 parent만 지정 (양쪽 갱신 금지)
            let node = MediaFolder(displayPath: displayPath, name: name, parent: parent)
            context.insert(node)

            cache[displayPath] = node
            createdCount += 1
            return node
        }
    }
}

