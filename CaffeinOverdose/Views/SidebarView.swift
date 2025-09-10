//
//  SidebarView.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//

import SwiftUI

// OutlineGroup에 Optional children이 필요하므로 보조 프로퍼티
extension MediaFolder {
    var childrenOptional: [MediaFolder]? { subfolders }
}

struct SidebarView: View {
    @ObservedObject var libraryStore: LibraryStore

    var body: some View {
        List {
            OutlineGroup([libraryStore.root], children: \.childrenOptional) { folder in
                SidebarRow(
                    title: folder.name,
                    isSelected: libraryStore.selectedFolder?.path == folder.path,
                    systemImage: "folder"
                ) {
                    // ✅ 클릭 시 명시적으로 선택 폴더 갱신
                    libraryStore.selectedFolder = folder
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220) // 사이드바 폭 보정(선택)
    }
}

// 사이드바 행 컴포넌트: Button으로 확실하게 클릭 처리
private struct SidebarRow: View {
    let title: String
    let isSelected: Bool
    let systemImage: String
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)                // 사이드바 느낌 유지
        .contentShape(Rectangle())          // 클릭 히트영역 넓히기
        .listRowBackground(                 // 선택 시 하이라이트
            isSelected ? Color.accentColor.opacity(0.15) : Color.clear
        )
    }
}


// 프리뷰 래퍼
private struct Preview_SidebarView: View {
    let store: LibraryStore = {
        let s = LibraryStore()
        s.root = .exampleTree()
        s.selectedFolder = s.root
        return s
    }()

    var body: some View {
        SidebarView(libraryStore: store)
            .frame(width: 300, height: 600)
    }
}

#Preview {
    Preview_SidebarView()
}
