//
//  ContentView.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//
import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @ObservedObject var vm: LibraryViewModel

    // 모달(라이트박스)
    @State private var isViewerPresented = false
    @State private var viewerIndex = 0

    // 현재 폴더 아이템
    private var items: [MediaItem] {
        vm.store.selectedFolder?.items ?? []
    }

    // MARK: - View
    var body: some View {
        NavigationSplitView() {
            SidebarView(libraryStore: vm.store)
                .navigationTitle("Library")
        } detail: {
            MasonryGridView(libraryStore: vm.store) { tappedIndex in
                viewerIndex = tappedIndex
                isViewerPresented = true
            }
        }
        .sheet(isPresented: $isViewerPresented) {
            DetailView(items: items, index: $viewerIndex) {
                isViewerPresented = false
            }
            .frame(minWidth: 900, minHeight: 600)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    vm.importFromPanel()
                } label: {
                    Label("폴더 가져오기", systemImage: "folder.badge.plus")
                }
            }
        }
        // (원하면) split 스타일 조정
        .navigationSplitViewStyle(.balanced)
        .task {
            vm.attach(context: context)
            await MainActor.run {
                if vm.store.selectedFolder == nil {
                    var fd = FetchDescriptor<MediaFolder>(predicate: #Predicate { $0.displayPath == "/" })
                    fd.fetchLimit = 1
                    if let root = try? context.fetch(fd).first {   // ✅ 여기!
                        vm.store.selectFolder(root)
                    }
                }
            }

        }
    }
}

// MARK: - Preview
#Preview {
    do {
        // 1) 인메모리 컨테이너 생성
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MediaFolder.self, MediaItem.self,
            configurations: config
        )
        let ctx = ModelContext(container)

        // 2) 샘플 데이터 시딩 (SwiftData 엔티티)
        let root = MediaFolder(displayPath: "/", name: "Library")
        let sample = MediaFolder(displayPath: "/Sample", name: "Sample", parent: root)
        root.subfolders.append(sample)

        let sampleItem = MediaItem(
            filename: "sample.jpg",
            relativePath: "Sample/sample.jpg",
            kindRaw: MediaKind.image.rawValue,
            pixelWidth: 800,
            pixelHeight: 600,
            duration: nil,
            folder: sample
        )
        sample.items.append(sampleItem)

        ctx.insert(root)
        ctx.insert(sample)
        ctx.insert(sampleItem)
        try ctx.save()

        // 3) 뷰모델 준비 + 컨텍스트 주입
        let vm = LibraryViewModel()
        vm.attach(context: ctx)

        // 4) 뷰 반환 (컨테이너 환경 주입 필수)
        return ContentView(vm: vm)
            .modelContainer(container)
            .frame(width: 1100, height: 700)

    } catch {
        return Text("Preview error: \(error.localizedDescription)")
            .frame(width: 600, height: 200)
    }
}

