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

    static func relativePath(of url: URL, under root: URL) -> String {
        let base = root.path.hasSuffix("/") ? root.path : root.path + "/"
        if url.path.hasPrefix(base) { return String(url.path.dropFirst(base.count)) }
        return url.lastPathComponent
    }

    static func fetchFolder(context: ModelContext, path: String) throws -> MediaFolder? {
        var fd = FetchDescriptor<MediaFolder>(predicate: #Predicate { $0.displayPath == path })
        fd.fetchLimit = 1
        return try context.fetch(fd).first
    }

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
    
    static func shouldFlattenToCommonParent(_ urls: [URL]) -> Bool {
        guard !urls.isEmpty else { return false }
        // 모든 선택 항목의 "직접 부모"가 동일하면 true (부모 자체를 선택한 건 아님)
        let parents = Set(urls.map { $0.deletingLastPathComponent() })
        return parents.count == 1
    }
    
    // 디렉터리 보장: 전달된 displayPath들을 보장하고, 새로 만든 개수를 리턴
    @MainActor
    static func ensureFolders(_ displayPaths: [String],
                              context: ModelContext) -> Int {
        var cache: [String: MediaFolder] = [:]
        var created = 0

        // 루트 캐시
        if let root = try? fetchFolder(context: context, path: "/") {
            cache["/"] = root
        } else {
            let root = MediaFolder(displayPath: "/", name: "Library", parent: nil)
            context.insert(root)
            cache["/"] = root
            created += 1
        }

        func ensure(_ displayPath: String) throws -> MediaFolder {
            if let f = cache[displayPath] { return f }
            if displayPath == "/" { return cache["/"]! }

            let comps = displayPath.split(separator: "/")
            let parentPath = comps.dropLast().isEmpty ? "/" : "/" + comps.dropLast().joined(separator: "/")
            let parent = try ensure(parentPath)
            let name = comps.last.map(String.init) ?? "Untitled"

            let node = MediaFolder(displayPath: displayPath, name: name, parent: parent)
            parent.subfolders.append(node)
            context.insert(node)
            cache[displayPath] = node
            created += 1
            return node
        }

        for path in displayPaths {
            do { _ = try ensure(path) } catch { print("ensureFolders error:", error) }
        }
        return created
    }

    // 파일 삽입: Pending 배열을 적용하고, 실제로 insert된 item 수를 리턴
    @MainActor
    static func applyPendings(_ pendings: [Pending],
                              context: ModelContext) -> Int {
        var cache: [String: MediaFolder] = [:]
        if let root = try? fetchFolder(context: context, path: "/") { cache["/"] = root }

        func ensure(_ displayPath: String) throws -> MediaFolder {
            if let f = cache[displayPath] { return f }
            if displayPath == "/" { return cache["/"]! }

            let comps = displayPath.split(separator: "/")
            let parentPath = comps.dropLast().isEmpty ? "/" : "/" + comps.dropLast().joined(separator: "/")
            let parent = try ensure(parentPath)
            let name = comps.last.map(String.init) ?? "Untitled"

            let node = MediaFolder(displayPath: displayPath, name: name, parent: parent)
            parent.subfolders.append(node)
            context.insert(node)
            cache[displayPath] = node
            return node
        }

        var inserted = 0
        for p in pendings {
            do {
                let folder = try ensure(p.parentDisplay)
                
                let rel = p.relToLibrary
                
                var fd = FetchDescriptor<MediaItem>(predicate: #Predicate { $0.relativePath == rel })
                fd.fetchLimit = 1
                if try context.fetch(fd).first == nil {
                    let item = MediaItem(
                        filename: p.filename,
                        relativePath: p.relToLibrary,
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
        return inserted
    }
}
