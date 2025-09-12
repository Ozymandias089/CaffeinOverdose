//
//  QLPreviewRepresentable.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/12/25.
//

import SwiftUI
import AppKit
import QuickLookUI   // QLPreviewView

struct QLPreviewRepresentable: NSViewRepresentable {
    let urls: [URL]
    @Binding var index: Int

    func makeNSView(context: Context) -> QLPreviewHostingView {
        let v = QLPreviewHostingView()
        if let u = urls[safe: index] {
            v.setItem(u)
        }
        return v
    }

    func updateNSView(_ nsView: QLPreviewHostingView, context: Context) {
        if let u = urls[safe: index] {
            nsView.setItem(u)
        } else {
            nsView.clear()
        }
    }
}

final class QLPreviewHostingView: NSView {
    // failable init 보완: 옵셔널로 보관
    private let preview: QLPreviewView?

    override init(frame frameRect: NSRect) {
        self.preview = QLPreviewView(frame: .zero, style: .normal)
        super.init(frame: frameRect)

        if let p = preview {
            p.translatesAutoresizingMaskIntoConstraints = false
            addSubview(p)
            NSLayoutConstraint.activate([
                p.leadingAnchor.constraint(equalTo: leadingAnchor),
                p.trailingAnchor.constraint(equalTo: trailingAnchor),
                p.topAnchor.constraint(equalTo: topAnchor),
                p.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setItem(_ url: URL) {
        preview?.previewItem = url as NSURL
    }

    func clear() {
        preview?.previewItem = nil
    }
}

// 안전 인덱싱
private extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
