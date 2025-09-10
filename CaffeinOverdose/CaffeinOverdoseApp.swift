//
//  CaffeinOverdoseApp.swift
//  CaffeinOverdose
//
//  Created by 최영훈 on 9/10/25.
//

import SwiftUI

@main
struct CaffeinOverdoseApp: App {
    @StateObject private var vm = LibraryViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView(vm: vm)
                .onAppear {
                    do { try LibraryLocation.ensureExists() }
                    catch { print("Library ensure error:", error) }
                }
        }
        .windowStyle(.titleBar)
    }
}
