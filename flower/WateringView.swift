//
//  WateringView.swift
//  flower
//
//  Created by Mengke Li on 12/9/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UIKit

struct WateringView: View {
    let userId: String
    let coupleId: String

    private let db = Firestore.firestore()

    // 今日统计
    @State private var myTodayCount = 0
    @State private var herTodayCount = 0

    // 最近一次记录/时间与干枯状态
    @State private var lastEvent: WaterEvent? = nil
    @State private var lastWateringAt: Date? = nil
    @State private var isDry: Bool = false
    @State private var hasLoadedRecent = false

    // 监听器
    @State private var listener: ListenerRegistration? = nil

    // 浇水动效（按钮按压反馈 + 下落水滴）
    @GestureState private var waterPressed = false
    @State private var showFallingDrop = false
    @State private var dropOffsetY: CGFloat = -140
    @State private var dropOpacity: Double = 0.0
    @State private var dropScale: CGFloat = 1.0
    @State private var dropXShift: CGFloat = 0.0

    // 用户名缓存：uid -> username（只显示注册用户名）
    @State private var usernameCache: [String: String] = [:]

    // 每分钟校正一次“干枯判定”
    private let dryCheckTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 玫瑰图
                    ZStack {
                        Image(isDry ? "rose_dry" : "rose_water")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 4)

                        // 下落水滴动画
                        if showFallingDrop {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 54))
                                .foregroundColor(.blue)
                                .scaleEffect(dropScale)
                                .opacity(dropOpacity)
                                .offset(x: dropXShift, y: dropOffsetY)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal)

                    // 浇水按钮（震动 + 按压反馈）
                    Button {
                        Task { await waterOnceWithFeedback() }
                    } label: {
                        Text("给花浇水")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundColor(.white)
                            .background(waterPressed ? Color.blue.opacity(0.6) : Color.blue)
                            .cornerRadius(12)
                            .scaleEffect(waterPressed ? 0.98 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: waterPressed)
                            .shadow(color: .blue.opacity(0.2), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .updating($waterPressed) { _, state, _ in state = true }
                    )
                    .padding(.horizontal)

                    // 今日统计（实时）
                    VStack(alignment: .leading, spacing: 8) {
                        Text("今日统计").font(.headline)
                        HStack {
                            statCard(title: "我今天", value: myTodayCount, color: .blue)
                            statCard(title: "Ta 今天", value: herTodayCount, color: .pink)
                        }
                    }
                    .padding(.horizontal)

                    // 最近一次记录（用户名 + 时间）
                    VStack(alignment: .leading, spacing: 8) {
                        Text("最近一次记录").font(.headline)
                        if let e = lastEvent {
                            HStack {
                                Text(displayName(for: e.userId)) // 只显示用户名
                                    .font(.subheadline)
                                Spacer()
                                Text(e.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else if hasLoadedRecent {
                            Text("还没有记录").foregroundColor(.secondary)
                        } else {
                            ProgressView().progressViewStyle(.circular)
                        }
                    }
                    .padding(.horizontal)

                    // 原来
                    // Spacer(minLength: 24)

                    // 替换为
                    Text("3 小时没人浇水玫瑰就会枯萎，请多多浇水！")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    Spacer(minLength: 8)
                }
                .padding(.top, 12)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("我们的花")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("退出登录") { signOut() }
                }
            }
        }
        .onAppear {
            preloadMyDisplayName()
            startListening()
        }
        .onDisappear { stopListening() }
        .onReceive(dryCheckTimer) { _ in updateDryState() }
    }

    // 小卡片
    private func statCard(title: String, value: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.subheadline).foregroundColor(.secondary)
            Text("\(value)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // 模型
    struct WaterEvent: Identifiable {
        let id: String
        let userId: String
        let timestamp: Date
    }

    // 浇水（震动 + 下落水滴 + 乐观更新）
    private func waterOnceWithFeedback() async {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        if isDry {
            await MainActor.run {
                isDry = false
                let now = Date()
                let optimistic = WaterEvent(id: "local-\(now.timeIntervalSince1970)", userId: userId, timestamp: now)
                lastEvent = optimistic
                lastWateringAt = now
                myTodayCount += 1
            }
        }

        await MainActor.run {
            dropXShift = CGFloat([-12, -6, 0, 6, 12].randomElement()!)
            dropScale = 1.0
            dropOpacity = 1.0
            dropOffsetY = -140
            showFallingDrop = true
            withAnimation(.easeOut(duration: 0.75)) {
                dropOffsetY = 120
                dropOpacity = 0.0
                dropScale = 0.9
            }
        }
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run { showFallingDrop = false }
        }

        await waterOnce()
    }

    private func waterOnce() async {
        let data: [String: Any] = [
            "userId": userId,
            "timestamp": FieldValue.serverTimestamp()
        ]
        do {
            try await db.collection("couples")
                .document(coupleId)
                .collection("waterings")
                .addDocument(data: data)
        } catch {
            print("写入失败：\(error.localizedDescription)")
        }
    }

    private func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            print("退出失败：\(error.localizedDescription)")
        }
    }

    // 实时监听
    private func startListening() {
        stopListening()

        // A. 今日统计
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let todayListener = db.collection("couples")
            .document(coupleId)
            .collection("waterings")
            .whereField("timestamp", isGreaterThan: startOfToday)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("监听统计出错：\(error.localizedDescription)")
                    return
                }
                guard let docs = snapshot?.documents else { return }
                let mine = docs.filter { ($0["userId"] as? String) == userId }
                let hers = docs.filter { ($0["userId"] as? String) != userId }
                Task { @MainActor in
                    self.myTodayCount = mine.count
                    self.herTodayCount = hers.count
                }
            }

        // B. 最近一次
        let recentListener = db.collection("couples")
            .document(coupleId)
            .collection("waterings")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("监听最近出错：\(error.localizedDescription)")
                    return
                }
                if let doc = snapshot?.documents.first,
                   let uid = doc.data()["userId"] as? String,
                   let ts = doc.data()["timestamp"] as? Timestamp {
                    let e = WaterEvent(id: doc.documentID, userId: uid, timestamp: ts.dateValue())
                    Task { @MainActor in
                        self.lastEvent = e
                        self.lastWateringAt = e.timestamp
                        self.updateDryState()
                        self.hasLoadedRecent = true
                        self.ensureUsernameCached(for: uid)  // 只读 profiles/{uid}.username
                    }
                } else {
                    Task { @MainActor in
                        if !self.hasLoadedRecent {
                            self.lastEvent = nil
                            self.lastWateringAt = nil
                            self.isDry = true
                            self.hasLoadedRecent = true
                        }
                    }
                }
            }

        self.listener = CompositeListener(listeners: [todayListener, recentListener])
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
    }

    // 干枯判定
    private func updateDryState() {
        guard let last = lastWateringAt else {
            isDry = true
            return
        }
        let threeHoursAgo = Calendar.current.date(byAdding: .hour, value: -3, to: Date())!
        isDry = last < threeHoursAgo
    }

    // 只返回“注册时的用户名”，不显示任何 UID/前缀/占位
    private func displayName(for uid: String) -> String {
        if let name = usernameCache[uid] {
            return name
        }
        // 触发异步拉取（profiles/{uid}.username），首次显示为空字符串避免“加载中/占位”
        ensureUsernameCached(for: uid)
        return ""
    }

    // 预加载：把我自己的用户名写入 profiles 并缓存
    private func preloadMyDisplayName() {
        if let dn = Auth.auth().currentUser?.displayName {
            usernameCache[userId] = dn
            // 确保 profiles/{uid} 也有（若缺失则写入）
            Task {
                do {
                    let ref = db.collection("profiles").document(userId)
                    let snap = try await ref.getDocument()
                    if !(snap.exists) {
                        try await ref.setData(["username": dn])
                    }
                } catch {
                    // 忽略
                }
            }
        } else {
            // 兜底：如果 Auth 没有 displayName，可从 users/{uid} 读一次写到 profiles（本人写入是允许的）
            Task {
                do {
                    let usersDoc = try await db.collection("users").document(userId).getDocument()
                    if let name = usersDoc.data()?["username"] as? String {
                        await MainActor.run { usernameCache[userId] = name }
                        let ref = db.collection("profiles").document(userId)
                        try await ref.setData(["username": name], merge: true)
                    }
                } catch {
                    // 忽略
                }
            }
        }
    }

    // 确保某 uid 的用户名在缓存里：读取 profiles/{uid}.username（允许所有已登录用户读取）
    private func ensureUsernameCached(for uid: String) {
        if usernameCache[uid] != nil { return }
        Task {
            do {
                let doc = try await db.collection("profiles").document(uid).getDocument()
                if let name = doc.data()?["username"] as? String {
                    await MainActor.run { usernameCache[uid] = name }
                }
            } catch {
                // 忽略；下一次监听仍会调用
            }
        }
    }
}

// 复合 ListenerRegistration，便于一次性移除多个监听
private final class CompositeListener: NSObject, ListenerRegistration {
    private let listeners: [ListenerRegistration]
    init(listeners: [ListenerRegistration]) { self.listeners = listeners }
    func remove() { listeners.forEach { $0.remove() } }
}
