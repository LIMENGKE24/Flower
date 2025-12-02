//
//  VerifyEmailView.swift
//  flower
//
//  Created by Mengke Li on 12/9/25.
//

import SwiftUI
import FirebaseAuth

struct VerifyEmailView: View {
    // 仅出错时显示红字
    @State private var errorMessage: String? = nil
    // 独立忙碌状态：各自只影响各自按钮
    @State private var isChecking = false      // “我已完成邮箱验证”
    @State private var isResending = false     // “重新发送验证邮件”
    @EnvironmentObject var session: AppSession

    var body: some View {
        NavigationStack {
            Form {
                // 功能区（按钮）+ 提示（footer）
                Section(
                    header: Text("验证邮箱").foregroundColor(.blue),
                    footer:
                        VStack(alignment: .leading, spacing: 4) {
                            if let msg = errorMessage, !msg.isEmpty {
                                Text(msg).foregroundColor(.red)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("• 请到邮箱点击验证链接")
                                Text("• 如果没收到邮件，可点击上方“重新发送验证邮件”")
                                Text("• 点击验证链接后，回到此页点“我已完成邮箱验证”")
                            }
                            .foregroundColor(.secondary)
                        }
                        .font(.footnote)
                ) {
                    // 我已完成邮箱验证（仅自身文字变化与禁用）
                    Button {
                        Task { await reloadAndCheck() }
                    } label: {
                        Label(isChecking ? "正在检查…" : "我已完成邮箱验证", systemImage: "checkmark.circle")
                    }
                    .disabled(isChecking || Auth.auth().currentUser == nil)

                    // 重新发送验证邮件（仅自身文字变化与禁用）
                    Button {
                        Task { await resendEmail() }
                    } label: {
                        Label(isResending ? "正在发送…" : "重新发送验证邮件", systemImage: "arrow.clockwise")
                    }
                    .disabled(isResending || Auth.auth().currentUser == nil)

                    // 退出登录（蓝色普通按钮）
                    Button {
                        signOut()
                    } label: {
                        Label("退出", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .tint(.blue)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("验证")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
        }
    }

    // 重新发送验证邮件（只影响 isResending）
    private func resendEmail() async {
        guard let user = Auth.auth().currentUser else { return }
        await setResending(true)
        do {
            try await user.sendEmailVerification()
            await setError(nil)
        } catch {
            await setError("发送失败：\(error.localizedDescription)")
        }
        await setResending(false)
    }

    // 刷新并检查是否已验证（只影响 isChecking）
    private func reloadAndCheck() async {
        guard Auth.auth().currentUser != nil else { return }
        await setChecking(true)
        do {
            try await Auth.auth().currentUser?.reload()
            if Auth.auth().currentUser?.isEmailVerified == true {
                await setError(nil)
                // 刷新会话，让 RootView 跳转
                await session.reloadUser()
            } else {
                await setError("仍未验证，请先到邮箱点击验证链接，然后再点“我已完成邮箱验证”。")
            }
        } catch {
            await setError("刷新失败：\(error.localizedDescription)")
        }
        await setChecking(false)
    }

    // 退出登录
    private func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            Task { await setError("退出失败：\(error.localizedDescription)") }
        }
    }

    // 辅助：主线程更新 UI 状态
    @MainActor private func setError(_ t: String?) { errorMessage = t }
    @MainActor private func setChecking(_ v: Bool) { isChecking = v }
    @MainActor private func setResending(_ v: Bool) { isResending = v }
}
