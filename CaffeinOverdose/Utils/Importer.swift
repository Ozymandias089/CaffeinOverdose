//
//  Importer.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//

import Foundation
import AppKit
import AVFoundation

enum Importer {
    struct Result { let items: [MediaItem] }

    // UI 접근: MainActor에서
    @MainActor
    static func runOpenPanelAndImport() async -> Result? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Import"

        // 동기 API이므로 메인에서 호출
        guard panel.runModal() == .OK else { return nil }
        // 선택된 폴더들을 비동기 임포트
        return await importFolders(panel.urls)
    }

    // 파일 작업 & AV 메타 로딩: async
    static func importFolders(_ roots: [URL]) async -> Result? {
        do { try LibraryLocation.ensureExists() } catch { print(error) }

        var out: [MediaItem] = []
        let fm = FileManager.default

        for root in roots {
            // NSEnumerator 는 async for-in 불가 → 배열에 복사 후 사용
            var discovered: [URL] = []
            if let en = fm.enumerator(at: root,
                                      includingPropertiesForKeys: [.isDirectoryKey],
                                      options: [.skipsHiddenFiles]) {
                while let obj = en.nextObject() {
                    if let u = obj as? URL { discovered.append(u) }
                }
            }

            for src in discovered {
                let rv = try? src.resourceValues(forKeys: [.isDirectoryKey])
                if rv?.isDirectory == true { continue }

                let ext = src.pathExtension.lowercased()
                let isVideo = ["mp4","mov","m4v"].contains(ext)
                let isImage = ["heic","heif","jpg","jpeg","png","gif","bmp","tiff"].contains(ext)
                guard isVideo || isImage else { continue }

                // media/ 아래에 "선택 루트폴더명/상대경로" 유지 복사
                let relPath: String = {
                    let base = root.path.hasSuffix("/") ? root.path : root.path + "/"
                    if src.path.hasPrefix(base) {
                        return String(src.path.dropFirst(base.count))
                    } else {
                        return src.lastPathComponent
                    }
                }()

                let dst = LibraryLocation.media
                    .appendingPathComponent(root.lastPathComponent, isDirectory: true)
                    .appendingPathComponent(relPath, isDirectory: false)

                // 상위 디렉터리 생성 (오류 로깅)
                do {
                    try fm.createDirectory(at: dst.deletingLastPathComponent(),
                                           withIntermediateDirectories: true)
                } catch {
                    print("Importer: createDirectory error for \(dst.deletingLastPathComponent().path):", error)
                }

                if fm.fileExists(atPath: dst.path) == false {
                    do { try fm.copyItem(at: src, to: dst) }
                    catch { print("Importer: copyItem error \(src.path) -> \(dst.path):", error) }
                }

                // 메타 읽기 (최신 async API)
                let (w, h, dur): (Int, Int, Double?) = await {
                    if isVideo {
                        let asset = AVURLAsset(url: dst)

                        // duration
                        let duration: CMTime = (try? await asset.load(.duration)) ?? .zero

                        // 첫 비디오 트랙
                        guard let track = (try? await asset.loadTracks(withMediaType: .video))?.first else {
                            return (0, 0, duration.seconds)
                        }

                        // 크기 & 변환
                        let naturalSize = (try? await track.load(.naturalSize)) ?? .zero
                        let transform = (try? await track.load(.preferredTransform)) ?? .identity
                        let size = naturalSize.applying(transform)

                        return (Int(abs(size.width)), Int(abs(size.height)), duration.seconds)
                    } else {
                        if let img = NSImage(contentsOf: dst) {
                            return (Int(img.size.width), Int(img.size.height), nil)
                        }
                        return (0, 0, nil)
                    }
                }()

                // parentFolderPath: "/<루트폴더명>/<subdirs>"
                let relParentRaw = dst.deletingLastPathComponent().path
                    .replacingOccurrences(of: LibraryLocation.media.path, with: "")
                let displayParent = relParentRaw.isEmpty ? "/" : (relParentRaw.hasPrefix("/") ? relParentRaw : "/" + relParentRaw)

                let item = MediaItem(url: dst,
                                     kind: isVideo ? .video : .image,
                                     pixelWidth: w,
                                     pixelHeight: h,
                                     duration: dur,
                                     parentFolderPath: displayParent)
                out.append(item)
            }
        }

        return Result(items: out)
    }
}
