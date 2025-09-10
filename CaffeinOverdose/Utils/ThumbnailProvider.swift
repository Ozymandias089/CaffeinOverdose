//
//  ThumbnailProvider.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//
import Foundation
import AppKit
import AVFoundation

@MainActor
final class ThumbnailProvider {
    static let shared = ThumbnailProvider()
    private let fm = FileManager.default

    private lazy var cacheDir: URL = {
        do { try LibraryLocation.ensureExists() } catch { print(error) }
        let dir = LibraryLocation.thumbs
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private func thumbURL(for item: MediaItem, width: CGFloat) -> URL {
        let w = max(1, Int(width.rounded()))
        return cacheDir.appendingPathComponent("\(item.id.uuidString)_w\(w).png")
    }

    /// 최신 API 기반 async 썸네일 생성/로드
    func thumbnailImage(for item: MediaItem, width: CGFloat) async -> NSImage? {
        let out = thumbURL(for: item, width: width)

        if fm.fileExists(atPath: out.path), let cached = NSImage(contentsOf: out) {
            return cached
        }

        let produced: NSImage?
        switch item.kind {
        case .image:
            produced = resizeImage(from: item.url, targetWidth: width)
        case .video:
            produced = await videoFrameThumbnail(from: item.url, targetWidth: width)
        }

        if let png = produced?.pngData() {
            try? png.write(to: out, options: .atomic)
        }
        return produced
    }

    // MARK: - Image

    private func resizeImage(from url: URL, targetWidth: CGFloat) -> NSImage? {
        guard let src = NSImage(contentsOf: url), src.size.width > 0 else { return nil }
        return resize(image: src, targetWidth: targetWidth)
    }

    private func resize(image: NSImage, targetWidth: CGFloat) -> NSImage? {
        guard image.size.width > 0 else { return nil }
        let ratio = image.size.height > 0 ? image.size.width / image.size.height : 1
        let targetSize = NSSize(width: targetWidth, height: targetWidth / ratio)
        let out = NSImage(size: targetSize)
        out.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: targetSize),
                   from: .zero, operation: .copy, fraction: 1.0)
        out.unlockFocus()
        return out
    }

    // MARK: - Video (최신 비동기 API)

    private func videoFrameThumbnail(from url: URL, targetWidth: CGFloat) async -> NSImage? {
        let asset = AVURLAsset(url: url) // ✅ 최신
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true

        let time = CMTime(seconds: 0.1, preferredTimescale: 600)

        guard let cg = await generateCGImageAsync(generator: gen, time: time) else {
            return nil
        }
        let frame = NSImage(cgImage: cg, size: .zero)
        return resize(image: frame, targetWidth: targetWidth)
    }

    /// `copyCGImage`의 최신 대안: 비동기 생성 래핑
    private func generateCGImageAsync(generator: AVAssetImageGenerator, time: CMTime) async -> CGImage? {
        await withCheckedContinuation { cont in
            // 배열 버전은 여전히 최신 OS에서 사용 가능하고 안정적입니다.
            generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) {
                // completionHandler 시그니처: (requestedTime, cgImage, actualTime, result, error)
                _, cgImage, _, result, error in
                if let cgImage, error == nil, result == .succeeded {
                    cont.resume(returning: cgImage)
                } else {
                    cont.resume(returning: nil)
                }
            }
        }
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let tiff = self.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
