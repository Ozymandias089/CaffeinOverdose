//
//  CaffeinOverdoseApp.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//

import SwiftUI
import SwiftData

@main
struct CaffeinOverdoseApp: App {
    @Environment(\.scenePhase) private var phase
    @StateObject private var vm = LibraryViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView(vm: vm)
                .onAppear {
                    do { try LibraryLocation.ensureExists() }
                    catch { print("Library ensure error:", error) }
                }
        }
        .modelContainer(for: [MediaFolder.self, MediaItem.self])
        .onChange(of: phase) { _, newValue in
            if newValue == .background {
                // macOS에선 생략해도 되지만 명시적으로 정리 가능
                let urls = BookmarkStore.restoreAll()
                BookmarkStore.stopAccessing(urls: urls)
            }
        }
        .windowStyle(.titleBar)
    }
}
