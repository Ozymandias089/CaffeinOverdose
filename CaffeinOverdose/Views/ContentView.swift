//
//  ContentView.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//
import SwiftUI

struct ContentView: View {
    @ObservedObject var vm: LibraryViewModel

    // 모달(라이트박스)
    @State private var isViewerPresented = false
    @State private var viewerIndex = 0

    // 현재 폴더 아이템
    private var items: [MediaItem] {
        vm.store.selectedFolder?.items ?? []
    }

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
    }
}

#Preview {
    let vm = LibraryViewModel()
    vm.store.root = .exampleTree()
    vm.store.selectedFolder = vm.store.root.subfolders.first ?? vm.store.root
    return ContentView(vm: vm).frame(width: 1100, height: 700)
}
