//
//  ContentView.swift
//  flower
//
//  Created by Mengke Li on 11/9/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AuthView: View {
    // 输入
    @State private var emailOrUsername: String = ""
    @State private var password: String = ""

    // 状态
    @State private var isBusy = false
    @State private var errorMessage: String? = nil   // 只在出错时显示
    
    @GestureState private var loginPressed = false
    
    private let db = Firestore.firestore()

    var body: some View {
        NavigationStack {
            Form {
                // 账户信息输入区
                Section(header: Text("账户信息").foregroundColor(.blue)) {
                    TextField("邮箱 或 用户名", text: $emailOrUsername)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    SecureField("密码", text: $password)

                    // 只在出错时显示
                    if let msg = errorMessage, !msg.isEmpty {
                        Text(msg)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }

                    // 登录按钮（紧跟输入框）
                    Button {
                        Task { await signIn() }
                    } label: {
                        Text(isBusy ? "正在登录…" : "登录")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundColor(.white)
                            .background(loginPressed ? Color.blue.opacity(0.6) : Color.blue) // 按下变色
                            .cornerRadius(10)
                            .scaleEffect(loginPressed ? 0.98 : 1.0)                           // 轻微缩放反馈
                            .animation(.easeInOut(duration: 0.1), value: loginPressed)
                    }
                    .buttonStyle(.plain)                           // 避免 Form 的默认高亮干扰
                    .disabled(isBusy || emailOrUsername.isEmpty || password.isEmpty)
                    .listRowBackground(Color.clear)                // 去掉行底色干扰
                    .gesture(DragGesture(minimumDistance: 0)       // 跟踪“按下”状态
                        .updating($loginPressed) { _, state, _ in
                            state = true
                        }
                    )
                    .padding(.top, 8)
                }

                // 注册入口（放在下方，附带提示小字）
                Section(header: Text("还未创建账号？").foregroundColor(.blue)) { NavigationLink { RegisterView() } label: { Text("去注册新账号") .frame(maxWidth: .infinity, alignment: .center) } }

            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 中间的 Logo：更大，并稍微向下偏一点
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Image("FLOWERLOGO")
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 40)      // 原 56，改成 84（大 1.5 倍），可再调
                            .padding(.top, 6)       // 让 Logo 在导航栏里稍微下移，避开灵动岛
                    }
                }
            }
        }
    }

    // 登录：支持“用户名 或 邮箱”
    private func signIn() async {
        // 每次尝试登录前清空错误提示
        await setError(nil)

        guard !emailOrUsername.isEmpty, !password.isEmpty else { return }
        await setBusy(true)
        do {
            let resolvedEmail = try await resolveEmail(from: emailOrUsername)
            _ = try await Auth.auth().signIn(withEmail: resolvedEmail, password: password)
            // 成功后不显示任何状态提示，RootView 会负责跳转逻辑
        } catch {
            await setError(humanReadableAuthError(error))
        }
        await setBusy(false)
    }

    // 把“用户名或邮箱”解析为邮箱（仅读 usernames 集合）
    private func resolveEmail(from input: String) async throws -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("@") {
            return trimmed
        } else {
            let unameLc = trimmed.lowercased()
            let doc = try await db.collection("usernames").document(unameLc).getDocument()
            guard let email = doc.data()?["email"] as? String else {
                throw NSError(domain: "auth", code: 404, userInfo: [NSLocalizedDescriptionKey: "未找到该用户名或该用户名未绑定邮箱"])
            }
            return email
        }
    }

    // 将 Firebase 的错误转成人能理解的提示
    private func humanReadableAuthError(_ error: Error) -> String {
        let ns = error as NSError
        switch AuthErrorCode(_bridgedNSError: ns)?.code {
        case .wrongPassword:
            return "密码错误，请重试"
        case .invalidEmail:
            return "邮箱格式不正确"
        case .userNotFound:
            return "用户不存在"
        case .userDisabled:
            return "该账号已被停用"
        case .tooManyRequests:
            return "尝试次数过多，请稍后再试"
        default:
            return ns.localizedDescription
        }
    }

    @MainActor private func setError(_ text: String?) { self.errorMessage = text }
    @MainActor private func setBusy(_ busy: Bool) { self.isBusy = busy }
}

// 自定义蓝色填充按钮，带按压反馈
// 自定义蓝色填充按钮，按下有明显颜色与缩放反馈
private struct FilledBlueButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(configuration.isPressed ? Color.blue.opacity(0.6) : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0) // 轻微缩放反馈
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .contentShape(Rectangle()) // 提升可点击区域
    }
}
