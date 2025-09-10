//
//  DetailView.swift
//  CaffeinOverdose
//
//  Swift 6 / macOS 15.6
//

import SwiftUI
import AVKit
import AppKit

struct DetailView: View {
    /// 현재 폴더의 아이템 배열(이미지/영상 혼합 가능)
    let items: [MediaItem]
    /// 현재 보고 있는 인덱스(좌우 이동용)
    @Binding var index: Int
    /// 닫기 액션(시트/윈도우 등 외부에서 넘김)
    var onClose: () -> Void

    @State private var player: AVPlayer? = nil
    @State private var keyMonitor: Any?

    private var currentItem: MediaItem? {
        guard items.indices.contains(index) else { return nil }
        return items[index]
    }

    var body: some View {
        ZStack {
            // 배경
            Color.black.opacity(0.92).ignoresSafeArea()

            if let item = currentItem {
                VStack(spacing: 12) {
                    // 상단 바
                    HStack {
                        Text(item.filename)
                            .foregroundStyle(.white)
                            .font(.headline)
                        Spacer()
                        Button {
                            onClose()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                        .keyboardShortcut(.escape, modifiers: [])
                    }
                    .padding(.horizontal)

                    // 콘텐츠
                    Group {
                        if item.kind == .image {
                            if let img = NSImage(contentsOf: item.url) {
                                Image(nsImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                Text("이미지를 불러올 수 없습니다.")
                                    .foregroundStyle(.white)
                            }
                        } else {
                            VideoPlayer(player: player)
                                .frame(minHeight: 420)
                        }
                    }
                    .padding(.horizontal)

                    // 하단 컨트롤
                    HStack {
                        Button {
                            prev()
                        } label: { Label("이전", systemImage: "chevron.left") }
                        .keyboardShortcut(.leftArrow, modifiers: [])

                        Button {
                            next()
                        } label: { Label("다음", systemImage: "chevron.right") }
                        .keyboardShortcut(.rightArrow, modifiers: [])

                        Spacer()

                        if item.kind == .video {
                            Button {
                                togglePlay()
                            } label: { Label("재생/일시정지", systemImage: "playpause") }
                            .keyboardShortcut(.space, modifiers: [])
                        }
                    }
                    .padding([.horizontal, .bottom])
                }
                .foregroundStyle(.white)
                // 인덱스가 바뀔 때 플레이어 새로 로드(이미지는 nil)
                .task(id: index) {
                    if items.indices.contains(index) {
                        let it = items[index]
                        if it.kind == .video {
                            player?.pause()
                            player = AVPlayer(url: it.url)
                        } else {
                            player?.pause()
                            player = nil
                        }
                    } else {
                        player?.pause()
                        player = nil
                    }
                }
            } else {
                Text("항목을 불러올 수 없습니다.")
                    .foregroundStyle(.white)
            }
        }
        .onAppear { setupKeyMonitor() }
        .onDisappear { teardownKeyMonitor() }
    }

    // MARK: - Controls

    private func prev() { if index > 0 { index -= 1 } }
    private func next() { if index < items.count - 1 { index += 1 } }
    private func togglePlay() {
        guard let p = player else { return }
        p.timeControlStatus == .playing ? p.pause() : p.play()
    }

    // MARK: - Keyboard

    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { e in
            switch e.keyCode {
            case 53:  // esc
                onClose(); return nil
            case 123: // ←
                prev(); return nil
            case 124: // →
                next(); return nil
            case 49:  // space
                togglePlay(); return nil
            default:
                break
            }
            return e
        }
    }

    private func teardownKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
        keyMonitor = nil
        player?.pause()
        player = nil
    }
}

private struct Preview_DetailView: View {
    @State private var idx: Int = 0
    private let sample = MediaItem.examples()

    var body: some View {
        DetailView(items: sample, index: $idx, onClose: {})
            .frame(width: 1000, height: 700)
    }
}

#Preview {
    Preview_DetailView()
}
