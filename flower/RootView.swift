//
//  Untitled.swift
//  flower
//
//  Created by Mengke Li on 12/9/25.
//

import SwiftUI
import FirebaseAuth

final class AppSession: ObservableObject {
    @Published var user: User? = Auth.auth().currentUser
    private var handle: AuthStateDidChangeListenerHandle?

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
        }
    }
    deinit {
        if let h = handle { Auth.auth().removeStateDidChangeListener(h) }
    }

    // 新增：主动刷新当前用户并发布
    func reloadUser() async {
        do { try await Auth.auth().currentUser?.reload() } catch { }
        await MainActor.run {
            self.user = Auth.auth().currentUser
        }
    }
}

struct RootView: View {
    @StateObject private var session = AppSession()
    private let coupleId = "demo-couple"

    var body: some View {
        Group {
            if let u = session.user {
                if u.isEmailVerified {
                    WateringView(userId: u.uid, coupleId: coupleId)
                } else {
                    VerifyEmailView()
                }
            } else {
                AuthView()
            }
        }
        .environmentObject(session)
    }
}
