//
//  ThumbnailProvider.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//

import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif

/// 썸네일을 생성/캐시하는 프로바이더.
/// 무거운 연산은 백그라운드(Task.detached, .userInitiated)에서 수행하고,
/// 반환은 Sendable한 `Data?`(PNG)로 제공한다.
final class ThumbnailProvider {
    static let shared = ThumbnailProvider()
    private let fm = FileManager.default

    private lazy var cacheDir: URL = {
        do { try LibraryLocation.ensureExists() } catch { print(error) }
        let dir = LibraryLocation.thumbs
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private func thumbURL(for item: MediaItem, width: Int) -> URL {
        let w = max(1, width)
        return cacheDir.appendingPathComponent("\(item.id.uuidString)_w\(w).png")
    }

    /// PNG 썸네일 데이터(캐시)를 반환한다.
    /// - Note: Sendable 결과를 반환하므로 Actor 경계 문제나 QoS 역전 없이 안전하다.
    func thumbnailData(for item: MediaItem, width: Int) async -> Data? {
        let out = thumbURL(for: item, width: width)

        // 캐시가 있으면 즉시 반환
        if let data = try? Data(contentsOf: out) {
            return data
        }

        // 백그라운드에서 생성
        let data: Data? = await Task.detached(priority: .utility) { [item] in
            switch item.kind {
            case .image:
                return Self.makeImageThumbnailPNG(from: item.url, maxPixel: width * 2)
            case .video:
                guard let cg = await Self.videoFrameCGImage(from: item.url) else { return nil }
                let scaled = Self.cgScaled(cg, toMaxWidth: CGFloat(width*2)) ?? cg
                return Self.pngData(from: scaled)
            }
        }.value

        // 캐시 저장
        if let data { try? data.write(to: out, options: .atomic) }
        return data
    }
}

// MARK: - Private CG/ImageIO helpers
private extension ThumbnailProvider {
    /// 원본 이미지에서 최대 변 크기가 `maxPixel`인 썸네일을 만들어 PNG로 인코딩.
    static func makeImageThumbnailPNG(from url: URL, maxPixel: Int) -> Data? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixel),
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCache: false
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        return pngData(from: cg)
    }

    /// 비디오 첫 프레임(CGImage)을 비동기로 추출.
    static func videoFrameCGImage(from url: URL) async -> CGImage? {
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        // 원하면 gen.maximumSize = CGSize(width: 1024, height: 1024)

        let time = CMTime(seconds: 0.1, preferredTimescale: 600)

        return await withCheckedContinuation { cont in
            gen.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { _, cg, _, result, _ in
                if result == .succeeded, let cg {
                    cont.resume(returning: cg)
                } else {
                    cont.resume(returning: nil)
                }
            }
        }
    }

    /// CGImage → PNG Data
    static func pngData(from cg: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            data,
            (UTType.png.identifier as CFString),
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImage(dest, cg, nil)
        CGImageDestinationFinalize(dest)
        return data as Data
    }

    /// 가로 최대 w로 다운스케일 (고정비율)
    static func cgScaled(_ cg: CGImage, toMaxWidth w: CGFloat) -> CGImage? {
        let width = CGFloat(cg.width), height = CGFloat(cg.height)
        guard width > 0, height > 0, w > 0 else { return cg }
        if width <= w { return cg }

        let scale = w / width
        let newW = Int(width * scale)
        let newH = Int(height * scale)

        guard let ctx = CGContext(
            data: nil,
            width: newW,
            height: newH,
            bitsPerComponent: cg.bitsPerComponent,
            bytesPerRow: 0,
            space: cg.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: cg.bitmapInfo.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: newW, height: newH))
        return ctx.makeImage()
    }
}
