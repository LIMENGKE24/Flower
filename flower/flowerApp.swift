//
//  flowerApp.swift
//  flower
//
//  Created by Mengke Li on 11/9/25.
//

import SwiftUI
import FirebaseCore

@main
struct flowerApp: App {
    init() {
        FirebaseApp.configure()
    }
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
