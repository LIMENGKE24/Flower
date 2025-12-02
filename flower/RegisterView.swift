//
//  RegisterView.swift
//  flower
//
//  Created by Mengke Li on 12/9/25.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct RegisterView: View {
    // 输入
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    // 状态与错误显示
    @State private var isBusy: Bool = false
    @State private var triedSubmit: Bool = false          // 是否尝试提交（控制何时显示校验错误）
    @State private var basicError: String? = nil          // 基本信息区错误（用户名占用、邮箱无效等）
    @State private var passwordError: String? = nil       // 密码区错误（过短、不一致等）

    // 按压反馈（Form 内自定义）
    @GestureState private var createPressed = false

    private let db = Firestore.firestore()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section(
                header: Text("基本信息").foregroundColor(.blue),
                footer:
                    VStack(alignment: .leading, spacing: 4) {
                        // 红字错误（服务端/占用等）
                        if let msg = basicError, !msg.isEmpty {
                            Text(msg).foregroundColor(.red)
                        }
                        // 红字错误（本地校验）：输入非空且不合法，或已经点过创建按钮且校验不通过
                        if (!username.isEmpty && !usernameValid) || (triedSubmit && !usernameValid) {
                            Text("用户名需为 3–20 位字母、数字或下划线").foregroundColor(.red)
                        }
                        if (!email.isEmpty && !emailValid) || (triedSubmit && !emailValid) {
                            Text("邮箱格式看起来不正确").foregroundColor(.red)
                        }
                        // 灰色提示（仅当没有红色错误时显示）
                        if (basicError == nil || basicError!.isEmpty)
                            && (username.isEmpty || usernameValid)
                            && (email.isEmpty || emailValid) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("• 用户名要求：3–20 个字符，仅限字母、数字或下划线")
                                Text("• 邮箱将用于接收验证邮件")
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    .font(.footnote)
            ) {
                TextField("用户名", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

                TextField("邮箱地址", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
            
            Section(
                header: Text("设置密码").foregroundColor(.blue),
                footer:
                    VStack(alignment: .leading, spacing: 4) {
                        // 红字错误（服务端/弱密码等）
                        if let msg = passwordError, !msg.isEmpty {
                            Text(msg).foregroundColor(.red)
                        }
                        // 红字错误（本地校验）
                        if (!password.isEmpty && !passwordValid) || (triedSubmit && !passwordValid) {
                            Text("密码至少 6 位").foregroundColor(.red)
                        }
                        if (!confirmPassword.isEmpty && !confirmValid) || (triedSubmit && !confirmValid) {
                            Text("两次输入的密码不一致").foregroundColor(.red)
                        }
                        // 灰色提示（无红字时显示）
                        if (passwordError == nil || passwordError!.isEmpty)
                            && (password.isEmpty || passwordValid)
                            && (confirmPassword.isEmpty || confirmValid) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("• 密码要求：至少 6 位")
                                Text("• 确认密码需与上方密码一致")
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    .font(.footnote)
            ) {
                SecureField("密码", text: $password)
                SecureField("确认密码", text: $confirmPassword)
            }

            // 创建账号按钮（与登录按钮一致的视觉与按压反馈）
            Section {
                Button {
                    Task { await register() }
                } label: {
                    Text(isBusy ? "正在创建…" : "创建账号")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundColor(.white)
                        .background(createPressed ? Color.blue.opacity(0.6) : Color.blue) // 按下变色
                        .cornerRadius(10)
                        .scaleEffect(createPressed ? 0.98 : 1.0)                           // 轻微缩放
                        .animation(.easeInOut(duration: 0.1), value: createPressed)
                }
                .buttonStyle(.plain)                           // 避免 Form 默认高亮干扰
                .disabled(isBusy || !allValid)
                .listRowBackground(Color.clear)                // 去除行底色干扰
                .gesture(DragGesture(minimumDistance: 0)       // 跟踪按压状态
                    .updating($createPressed) { _, state, _ in
                        state = true
                    }
                )
            }
        }
        .navigationTitle("注册新账号")
    }

    // MARK: - 本地校验
    private var usernameValid: Bool {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let regex = try! NSRegularExpression(pattern: "^[A-Za-z0-9_]{3,20}$")
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        return regex.firstMatch(in: trimmed, options: [], range: range) != nil
    }
    private var emailValid: Bool {
        let t = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.contains("@") && t.contains(".")
    }
    private var passwordValid: Bool { password.count >= 6 }
    private var confirmValid: Bool { !confirmPassword.isEmpty && confirmPassword == password }
    private var allValid: Bool { usernameValid && emailValid && passwordValid && confirmValid }

    // MARK: - 注册流程（Firebase）
    private func register() async {
        triedSubmit = true
        basicError = nil
        passwordError = nil

        // 本地校验不通过，直接显示各区错误
        guard allValid else { return }

        await setBusy(true)

        let unameRaw = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let unameLC = unameRaw.lowercased()
        let emailTrimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            // 1) 用户名占用检查（允许未登录读取）
            let unameRef = db.collection("usernames").document(unameLC)
            let unameDoc = try await unameRef.getDocument()
            if unameDoc.exists {
                basicError = "该用户名已被占用，请换一个"
                await setBusy(false)
                return
            }

            // 2) 创建 Auth 账号（邮箱+密码）
            let result = try await Auth.auth().createUser(withEmail: emailTrimmed, password: password)
            let uid = result.user.uid

            // 3) 设置显示名（昵称）
            let change = result.user.createProfileChangeRequest()
            change.displayName = unameRaw
            try await change.commitChanges()

            // 4) 写入 users/{uid}
            try await db.collection("users").document(uid).setData([
                "username": unameRaw,
                "username_lc": unameLC,
                "email": emailTrimmed,
                "createdAt": FieldValue.serverTimestamp()
            ])

            // 5) 占位 usernames/{uname_lc}（冗余 email 便于“用户名登录”）
            try await unameRef.setData([
                "uid": uid,
                "email": emailTrimmed,
                "createdAt": FieldValue.serverTimestamp()
            ])

            // 6) 发送验证邮件
            try await result.user.sendEmailVerification()

            // 可选：自动返回登录页，也可以保持当前页提示用户去邮箱验证
            await setBusy(false)
            // 返回上一页（登录页），由 RootView 分流到“验证邮箱页”
            await MainActor.run { dismiss() }

        } catch {
            await setBusy(false)
            // 将错误归类到对应分区展示
            let ns = error as NSError
            switch ns.code {
            case AuthErrorCode.emailAlreadyInUse.rawValue:
                basicError = "该邮箱已被注册"
            case AuthErrorCode.invalidEmail.rawValue:
                basicError = "邮箱格式不正确"
            case AuthErrorCode.weakPassword.rawValue:
                passwordError = "密码过于简单，请至少 6 位"
            default:
                basicError = ns.localizedDescription
            }
        }
    }

    @MainActor private func setBusy(_ v: Bool) { self.isBusy = v }
}
