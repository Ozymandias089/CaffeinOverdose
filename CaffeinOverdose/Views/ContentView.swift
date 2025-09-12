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
    @State private var viewerIndex = 0
    @State private var viewer: ViewerPayload? = nil

    // 현재 폴더 아이템
    private var items: [MediaItem] {
        vm.store.selectedFolder?.items ?? []
    }
    
    private struct ViewerPayload: Identifiable, Equatable {
        let ids: [UUID]
        let startIndex: Int
        // ids와 시작 인덱스를 함께 키로 써서 뷰 아이덴티티 고정
        var id: String { ids.map(\.uuidString).joined(separator: "|") + "#\(startIndex)" }
    }

    // MARK: - View
    var body: some View {
        NavigationSplitView() {
            SidebarView(libraryStore: vm.store)
                .navigationTitle("Library")
        } detail: {
            MasonryGridView(libraryStore: vm.store) { tappedIndex in
                let ids = (vm.store.selectedFolder?.items ?? []).map(\.uuid)
                viewerIndex = tappedIndex
                // payload를 세팅하면 sheet가 뜸 (.sheet(item:) 사용)
                viewer = ViewerPayload(ids: ids, startIndex: tappedIndex)
                
                // 🔎 컨텍스트/배열/프리플라이트 체크
                #if DEBUG
                print("🎯 Present viewer: tappedIndex=\(tappedIndex), ids.count=\(ids.count)")
                print("CTX ContentView:", Unmanaged.passUnretained(context).toOpaque())
                #endif
                if tappedIndex < ids.count {
                    let testId = ids[tappedIndex]
                    do {
                        var fd = FetchDescriptor<MediaItem>(predicate: #Predicate { $0.uuid == testId })
                        fd.fetchLimit = 1
                        let hit = try context.fetch(fd).first != nil
                        #if DEBUG
                        print("Preflight fetch in ContentView: uuid=\(testId) exists? \(hit)")
                        #endif
                    } catch {
                        #if DEBUG
                        print("Preflight fetch error:", error)
                        #endif
                    }
                } else {
                    #if DEBUG
                    print("Preflight: tappedIndex out of bounds for ids")
                    #endif
                }
            }
        }
        .sheet(item: $viewer) { payload in
            DetailView(itemIDs: payload.ids, index: $viewerIndex, initialIndex: payload.startIndex) {
                viewer = nil
            }
            .environment(\.modelContext, context)   // ✅ 부모와 동일한 컨텍스트 강제 주입
            .id(payload.id)
            .frame(minWidth: 900, minHeight: 600)
            
            #if DEBUG
            .onAppear {
                print("🧩 Detail sheet appear: itemIDs.count=\(payload.ids.count), index=\(viewerIndex)")
                print("CTX Detail(sheet env):", Unmanaged.passUnretained(context).toOpaque())
            }
            #endif
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
#if DEBUG
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

        let sampleItem = MediaItem(
            filename: "sample.jpg",
            relativePath: "Sample/sample.jpg",
            kindRaw: MediaKind.image.rawValue,
            pixelWidth: 800,
            pixelHeight: 600,
            duration: nil,
            folder: sample
        )

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
#endif
