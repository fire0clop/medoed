// Pages/AuthView.swift

import SwiftUI
import AuthenticationServices

struct AuthView: View {

    @EnvironmentObject var appState: AppState
    @StateObject private var authService = AuthService()

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var code = ""

    @State private var activeTab: AuthTab = .login
    @State private var isCodeStep = false

    @State private var showPassword = false
    @State private var showConfirmPassword = false

    @State private var localError: String?

    @FocusState private var focus: FocusField?

    private let primary = Color(red: 0.204, green: 0.071, blue: 0)          // #341200
    private let salmonBg = Color(red: 1.0, green: 0.706, blue: 0.549)       // #FFB48C
    private let footerGray = Color(red: 0.486, green: 0.486, blue: 0.486)   // #7C7C7C
    private let placeholderGray = Color(red: 0.851, green: 0.851, blue: 0.851) // #D9D9D9

    enum AuthTab { case login, register }
    enum FocusField: Hashable { case email, password, confirmPassword, code }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if isCodeStep {
                        codeContent
                            .padding(.top, 32)
                    } else {
                        mainContent
                    }

                    Spacer(minLength: 40)

                    Text("Продолжая, вы соглашаетесь с политикой конфиденциальности.")
                        .font(.gilroy(12))
                        .foregroundColor(footerGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                }
                .frame(minHeight: UIScreen.main.bounds.height - 100)
                .ipadReadable()
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture { focus = nil }
        }
        .onChange(of: authService.mode) { _, newValue in
            if newValue == .confirmCode {
                withAnimation { isCodeStep = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    focus = .code
                }
            }
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: 0) {
            tabSwitcher
                .padding(.top, 24)
                .padding(.horizontal, 24)

            Text("Вход по Email")
                .font(.gilroy(18, weight: .bold))
                .foregroundColor(primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, activeTab == .login ? 80 : 40)

            emailField
                .padding(.horizontal, 24)
                .padding(.top, 20)

            Text("Пароль")
                .font(.gilroy(18, weight: .bold))
                .foregroundColor(primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 18)

            passwordField(
                show: $showPassword,
                text: $password,
                field: .password,
                submitLabel: activeTab == .register ? .next : .done,
                onSubmit: { activeTab == .register ? (focus = .confirmPassword) : (focus = nil) }
            )
            .padding(.horizontal, 24)
            .padding(.top, 12)

            if activeTab == .register {
                Text("Повторите пароль")
                    .font(.gilroy(18, weight: .bold))
                    .foregroundColor(primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 18)

                passwordField(
                    show: $showConfirmPassword,
                    text: $confirmPassword,
                    field: .confirmPassword,
                    submitLabel: .done,
                    onSubmit: { focus = nil }
                )
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }

            if let msg = localError ?? authService.errorMessage {
                errorRow(msg)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
            }

            primaryButton(title: activeTab == .login ? "Войти" : "Зарегистрироваться")
                .padding(.horizontal, 24)
                .padding(.top, 24)

            socialDivider
                .padding(.horizontal, 24)
                .padding(.top, activeTab == .login ? 90 : 50)

            googleButton
                .padding(.horizontal, 24)
                .padding(.top, 24)

            appleButton
                .padding(.horizontal, 24)
                .padding(.top, 12)
        }
    }

    // MARK: - Code step

    private var codeContent: some View {
        VStack(spacing: 0) {
            Text("Подтверждение email")
                .font(.gilroy(20, weight: .bold))
                .foregroundColor(primary)
                .padding(.horizontal, 24)

            Text("Введите код из письма на \(email)")
                .font(.gilroy(14))
                .foregroundColor(primary.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 6)

            codeField
                .padding(.horizontal, 24)
                .padding(.top, 24)

            if let msg = localError ?? authService.errorMessage {
                errorRow(msg)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
            }

            primaryButton(title: "Подтвердить и войти")
                .padding(.horizontal, 24)
                .padding(.top, 24)

            Button("Отправить код повторно") {
                Task {
                    localError = nil
                    await authService.startRegistration(email: email)
                }
            }
            .font(.gilroy(14))
            .foregroundColor(primary.opacity(0.55))
            .padding(.top, 16)
        }
    }

    // MARK: - Tab switcher (пропорции 125:225 как в SVG; белая капсула меняет ширину)

    private var tabSwitcher: some View {
        GeometryReader { geo in
            // SVG: контейнер 368, левый отступ пилюли 15, правый 12.
            // Доступная ширина для табов = totalW - 18 (~ 9 паддинг с каждой стороны),
            // делится в пропорции 125:225 = 0.357:0.643
            let totalW = geo.size.width
            let innerLeading: CGFloat = 9
            let availableW = totalW - 18
            let loginW = availableW * 125.0 / 350.0
            let registerW = availableW * 225.0 / 350.0
            // Pill touches the outer capsule edge: login → left edge, register → right edge
            let pillW = activeTab == .login ? (loginW + innerLeading) : (registerW + innerLeading)
            let pillOffsetX = activeTab == .login ? 0 : (innerLeading + loginW)

            ZStack(alignment: .leading) {
                Capsule().fill(salmonBg.opacity(0.22))

                Capsule()
                    .fill(Color.white)
                    .frame(width: pillW)
                    .offset(x: pillOffsetX)
                    .animation(.easeInOut(duration: 0.22), value: activeTab)

                HStack(spacing: 0) {
                    tabLabel("Войти", tab: .login)
                        .frame(width: loginW)
                    tabLabel("Зарегистрироваться", tab: .register)
                        .frame(width: registerW)
                }
                .padding(.leading, innerLeading)
            }
        }
        .frame(height: ds(54))
    }

    private func tabLabel(_ title: String, tab: AuthTab) -> some View {
        Text(title)
            .font(.gilroy(18, weight: activeTab == tab ? .medium : .regular))
            .foregroundColor(primary)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.22)) { activeTab = tab }
                localError = nil
                authService.errorMessage = nil
                authService.mode = tab == .login ? .login : .register
            }
    }

    // MARK: - Fields

    private var emailField: some View {
        // Ручной плейсхолдер; verbatim + foregroundStyle отключают авто-стиль ссылки на email
        ZStack(alignment: .leading) {
            if email.isEmpty {
                Text(verbatim: "medoed@mail.ru")
                    .font(.gilroy(18))
                    .foregroundStyle(placeholderGray)
                    .allowsHitTesting(false)
            }
            TextField("", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .email)
                .submitLabel(.next)
                .foregroundColor(primary)
                .tint(primary)
                .onSubmit { focus = .password }
                .font(.gilroy(18))
        }
        .padding(.horizontal, 22)
        .frame(height: 50)
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(primary.opacity(0.4), lineWidth: 1)
        )
    }

    private func passwordField(
        show: Binding<Bool>,
        text: Binding<String>,
        field: FocusField,
        submitLabel: SubmitLabel,
        onSubmit: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 0) {
            Group {
                if show.wrappedValue {
                    TextField(
                        "",
                        text: text,
                        prompt: Text("••••••").foregroundColor(placeholderGray)
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                } else {
                    SecureField(
                        "",
                        text: text,
                        prompt: Text("••••••").foregroundColor(placeholderGray)
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }
            }
            .focused($focus, equals: field)
            .font(.gilroy(18))
            .foregroundColor(primary)
            .tint(primary)
            .submitLabel(submitLabel)
            .onSubmit(onSubmit)
            .padding(.leading, 22)

            // Вертикальный разделитель перед иконкой глаза
            Rectangle()
                .fill(primary.opacity(0.4))
                .frame(width: 1, height: 34)
                .padding(.leading, 12)

            Button {
                show.wrappedValue.toggle()
                focus = field
            } label: {
                Image(systemName: show.wrappedValue ? "eye" : "eye.slash")
                    .font(.gilroy(16))
                    .foregroundColor(primary.opacity(0.4))
                    .frame(width: ds(52), height: ds(50))
            }
            .buttonStyle(.plain)
        }
        .frame(height: 50)
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(primary.opacity(0.4), lineWidth: 1)
        )
    }

    private var codeField: some View {
        HStack {
            TextField(
                "",
                text: $code,
                prompt: Text("Код (6 цифр)").foregroundColor(primary.opacity(0.4))
            )
            .keyboardType(.numberPad)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focus, equals: .code)
            .foregroundColor(primary)
            .tint(primary)
            .font(.gilroy(14))
            .onChange(of: code) { _, newValue in
                let digits = newValue.filter(\.isNumber)
                if digits != newValue { code = digits }
                if code.count > 6 { code = String(code.prefix(6)) }
            }

            if !code.isEmpty {
                Button {
                    code = ""
                    focus = .code
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(primary.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 22)
        .frame(height: 50)
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(primary.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Buttons

    private func primaryButton(title: String) -> some View {
        Button {
            Task { await handlePrimary() }
        } label: {
            Group {
                if authService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(title)
                        .font(.gilroy(18, weight: .medium))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 51)
        }
        .background(RoundedRectangle(cornerRadius: 25.5).fill(primary))
        .foregroundColor(.white)
        .buttonStyle(.plain)
    }

    private var socialDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(primary.opacity(0.4))
                .frame(height: 1)
            Text("Войти с помощью")
                .font(.gilroy(18))
                .foregroundColor(primary.opacity(0.4))
                .fixedSize()
            Rectangle()
                .fill(primary.opacity(0.4))
                .frame(height: 1)
        }
    }

    private var googleButton: some View {
        Button {
            Task {
                localError = nil
                if await authService.loginWithGoogle() {
                    appState.setUserEmail(authService.lastLoggedInEmail)
                    appState.isAuthorized = true
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image("google")
                    .resizable()
                    .scaledToFit()
                    .frame(width: ds(20), height: ds(20))
                Text("Google")
                    .font(.gilroy(18, weight: .medium))
                    .foregroundColor(primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(primary.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var appleButton: some View {
        Button {
            Task {
                localError = nil
                if await authService.loginWithApple() {
                    appState.setUserEmail(authService.lastLoggedInEmail)
                    appState.isAuthorized = true
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image("apple")
                    .resizable()
                    .scaledToFit()
                    .frame(width: ds(20), height: ds(20))
                Text("Apple ID")
                    .font(.gilroy(18, weight: .medium))
                    .foregroundColor(primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(primary.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Error

    private func errorRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red.opacity(0.85))
            Text(text)
                .font(.gilroy(13, weight: .regular))
                .foregroundColor(.red.opacity(0.85))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.red.opacity(0.08))
        )
    }

    // MARK: - Actions

    private func handlePrimary() async {
        localError = nil
        authService.errorMessage = nil

        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanConfirm = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCode = String(code.trimmingCharacters(in: .whitespacesAndNewlines).filter { $0.isNumber })

        if isCodeStep {
            guard !cleanEmail.isEmpty else { localError = "Введите email"; return }
            guard cleanPassword.count >= 8 else { localError = "Пароль должен быть минимум 8 символов"; return }
            guard cleanCode.count >= 4 else { localError = "Введите код"; focus = .code; return }
            if await authService.confirmRegistration(email: cleanEmail, password: cleanPassword, code: cleanCode) {
                appState.setUserEmail(authService.lastLoggedInEmail)
                appState.isAuthorized = true
            }
            return
        }

        switch activeTab {
        case .login:
            guard !cleanEmail.isEmpty else { localError = "Введите email"; focus = .email; return }
            guard !cleanPassword.isEmpty else { localError = "Введите пароль"; focus = .password; return }
            if await authService.login(email: cleanEmail, password: cleanPassword) {
                appState.setUserEmail(authService.lastLoggedInEmail)
                appState.isAuthorized = true
            }

        case .register:
            guard !cleanEmail.isEmpty else { localError = "Введите email"; focus = .email; return }
            guard cleanPassword.count >= 8 else { localError = "Пароль должен быть минимум 8 символов"; focus = .password; return }
            guard cleanPassword == cleanConfirm else { localError = "Пароли не совпадают"; focus = .confirmPassword; return }
            await authService.startRegistration(email: cleanEmail)
        }
    }
}
