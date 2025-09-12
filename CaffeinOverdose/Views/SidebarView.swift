//
//  SidebarView.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//

import SwiftUI
import SwiftData

struct SidebarView: View {
    @ObservedObject var libraryStore: LibraryStore
// MARK: - View
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

// MARK: - Sidebar row Component
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

// MARK: - Preview
#if DEBUG
#Preview {
    SidebarPreviewWrapper()
}

private struct SidebarPreviewWrapper: View {
    // 미리 만들어 두고 body에서 사용
    let container: ModelContainer
    let store: LibraryStore

    init() {
        // 1) 인메모리 SwiftData 컨테이너
        container = try! ModelContainer(
            for: MediaFolder.self, MediaItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = ModelContext(container)

        // 2) 샘플 트리 시딩
        let root = MediaFolder(displayPath: "/", name: "Library")
        let f1   = MediaFolder(displayPath: "/Untitled",  name: "Untitled",  parent: root)
        let f2   = MediaFolder(displayPath: "/Untitled2", name: "Untitled2", parent: root)

        ctx.insert(root); ctx.insert(f1); ctx.insert(f2)
        try? ctx.save()

        // 3) 스토어 준비/연결
        let s = LibraryStore()
        s.attach(context: ctx)
        s.selectFolder(f1)

        self.store = s
    }

    var body: some View {
        SidebarView(libraryStore: store)
            .modelContainer(container)
            .frame(width: 300, height: 600)
    }
}
#endif
