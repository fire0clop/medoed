// Pages/ProfileView.swift

import SwiftUI

struct ProfileView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var tabRouter: TabRouter
    @StateObject private var vm = ProfileViewModel()

    @State private var original: ProfileDTO? = nil
    @State private var draft: ProfileDTO? = nil

    @State private var localError: String?
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    @FocusState private var focus: Field?

    enum Field: Hashable { case target, isf, b, l, d }

    // MARK: - Палитра

    private let darkText = Color(red: 0.204, green: 0.071, blue: 0.0)         // #341200
    private let peachTint = Color(red: 1.0, green: 0.706, blue: 0.549)         // #FFB48C
    private let cardBackground = Color.white
    private let cardBackgroundPeach = Color(red: 1.0, green: 0.706, blue: 0.549).opacity(0.22) // #FFB48C @ 22%

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // Фон — всегда на самом дне, перекрывается всем остальным
            background

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Топбар скроллится вместе с контентом, к верху не прилеплен
                    topBar

                    Spacer().frame(height: 30)

                    if vm.isLoading && draft == nil {
                        loadingState
                            .frame(maxWidth: .infinity, minHeight: 400)
                    } else if draft != nil {
                        VStack(spacing: 22) {
                            mainProfileCard
                            icRatioCard

                            Spacer().frame(height: 30)
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 28)
                        .ipadReadable()
                    } else {
                        emptyState
                            .padding(.horizontal, 18)
                            .ipadReadable()
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onTapGesture { focus = nil }
        .onAppear { Task { await load() } }
        // Автосохранение когда поле теряет фокус (тап мимо / клавиатура убирается)
        .onChange(of: focus) { oldValue, newValue in
            if oldValue != nil && newValue == nil {
                Task { await autoSaveIfChanged() }
            }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { (localError != nil) || (vm.errorMessage != nil) },
            set: { _ in localError = nil; vm.errorMessage = nil }
        )) {
            Button("Ок", role: .cancel) {}
        } message: {
            Text(localError ?? vm.errorMessage ?? "")
        }
        .alert("Удалить аккаунт?", isPresented: $showDeleteConfirm) {
            Button("Удалить", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Вы действительно хотите удалить свой аккаунт? Все данные будут безвозвратно удалены.")
        }
        .overlay {
            if isDeleting {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView().tint(.white).scaleEffect(1.3)
                        Text("Удаление аккаунта…")
                            .foregroundStyle(.white)
                            .font(.gilroy(15, weight: .medium))
                    }
                    .padding(28)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        // Фрейм фиксирован к размеру экрана — иначе при появлении клавиатуры
        // ZStack сжимается, .scaledToFill пересчитывает масштаб и картинка
        // визуально «отдаляется» («обратный зум»).
        Image("profile-background")
            .resizable()
            .scaledToFill()
            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            .clipped()
            .ignoresSafeArea()
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                focus = nil
                tabRouter.selected = .calculator
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: ds(11), weight: .regular))
                    Text("Назад")
                        .font(.gilroy(12, weight: .regular))
                }
                .foregroundStyle(darkText.opacity(0.4))
            }

            Spacer()

            // Индикатор сохранения (вместо кнопки «Редактировать»)
            if vm.isSaving {
                ProgressView()
                    .tint(darkText.opacity(0.4))
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 36)
        .padding(.top, 45)
        .padding(.bottom, 8)
    }

    // MARK: - Avatar

    private var avatarView: some View {
        ZStack {
            Circle()
                .stroke(darkText.opacity(0.4), lineWidth: 1)
                .frame(width: ds(135), height: ds(135))

            Circle()
                .fill(darkText)
                .frame(width: ds(120), height: ds(120))

            // силуэт человека из ассета (SVG), цвет #FFB48C @ 22%
            Image("profile")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(peachTint.opacity(0.92))
                .frame(width: ds(63.16), height: ds(79))
        }
        .frame(width: ds(135), height: ds(135))
    }

    // MARK: - Main card (avatar + name + общие параметры)

    private var mainProfileCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Spacer().frame(height: ds(70)) // место под выступающий аватар

                VStack(spacing: 4) {
                    Text("МЕДОЕД")
                        .font(.gilroy(25, weight: .semibold))
                        .foregroundStyle(darkText)

                    Text(appState.userEmail ?? "")
                        .font(.gilroy(18, weight: .regular))
                        .foregroundStyle(darkText.opacity(0.4))
                }

                Spacer().frame(height: ds(20))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Общие параметры")
                        .font(.gilroy(20, weight: .semibold))
                        .foregroundStyle(darkText)

                    Text("Цель и общая чувствительность")
                        .font(.gilroy(11, weight: .medium))
                        .foregroundStyle(darkText.opacity(0.4))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer().frame(height: ds(30)) // фиксированный зазор — значения опускаются ниже

                HStack(alignment: .top, spacing: 14) {
                    bigValueCell(
                        title: "Целевой сахар",
                        valueBinding: numberTextBinding(\.target_glucose_mmol),
                        unit: "ммоль/л",
                        placeholder: "6.0",
                        field: .target
                    )

                    bigValueCell(
                        title: "Чувствительность (ISF)",
                        valueBinding: numberTextBinding(\.insulin_sensitivity_factor),
                        unit: "ммоль/л\nна 1 ед.",
                        placeholder: "2.0",
                        field: .isf
                    )
                }

                Rectangle()
                    .fill(darkText.opacity(0.18))
                    .frame(height: 1)
                    .padding(.top, 2)
            }
            .padding(.horizontal, ds(22))
            .padding(.top, ds(18))
            .padding(.bottom, ds(18))
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBackground)
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 4)
        )
        .overlay(alignment: .top) {
            avatarView
                .offset(y: -ds(67))
        }
        .padding(.top, ds(67)) // компенсируем выступающий аватар
    }

    // MARK: - Big value cell (отображение или ввод)

    private func bigValueCell(
        title: String,
        valueBinding: Binding<String>,
        unit: String,
        placeholder: String,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(title)
                .font(.gilroy(13, weight: .semibold))
                .foregroundStyle(darkText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: ds(34), alignment: .topLeading)

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                ZStack(alignment: .leading) {
                    TextField(
                        "",
                        text: valueBinding,
                        prompt: Text(placeholder).foregroundColor(darkText.opacity(0.3))
                    )
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.gilroy(48, weight: .bold))
                    .foregroundStyle(darkText.opacity(0.4))
                    .tint(darkText)
                    .focused($focus, equals: field)
                    .frame(maxWidth: 110, alignment: .leading)
                    .fixedSize(horizontal: true, vertical: false)
                }
                .overlay(alignment: .bottom) {
                    // Подчёркивание — становится ярче когда поле в фокусе
                    Rectangle()
                        .fill(darkText.opacity(focus == field ? 0.5 : 0.18))
                        .frame(height: focus == field ? 1.5 : 1)
                        .offset(y: 4)
                }
                .animation(.easeInOut(duration: 0.2), value: focus)

                Text(unit)
                    .font(.gilroy(11, weight: .medium))
                    .foregroundStyle(darkText.opacity(0.4))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .padding(.bottom, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - IC ratio card

    private var icRatioCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("IC ratio")
                    .font(.gilroy(20, weight: .semibold))
                    .foregroundStyle(darkText)
                Text("Углеводы на 1 ед. инсулина")
                    .font(.gilroy(11, weight: .medium))
                    .foregroundStyle(darkText.opacity(0.4))
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 18)

            icRatioRow(iconAsset: "morning", iconSize: CGSize(width: 39, height: 20), title: "Завтрак", placeholder: "10", binding: numberTextBinding(\.ic_ratio_breakfast), field: .b)
            divider
            icRatioRow(iconAsset: "lunch",   iconSize: CGSize(width: 41, height: 41), title: "Обед",    placeholder: "12", binding: numberTextBinding(\.ic_ratio_lunch),     field: .l)
            divider
            icRatioRow(iconAsset: "evening", iconSize: CGSize(width: 33, height: 33), title: "Ужин",    placeholder: "14", binding: numberTextBinding(\.ic_ratio_dinner),    field: .d)

            // Большой воздух между IC ratio и блоком источников — это один общий блок
            Spacer().frame(height: 40)

            sourcesSection
                .padding(.horizontal, 22)

            // Кнопки внутри того же блока
            Spacer().frame(height: 32)

            VStack(spacing: 14) {
                actionButton(title: "Выход") {
                    focus = nil
                    appState.logout()
                }
                actionButton(title: "Удалить аккаунт") {
                    focus = nil
                    showDeleteConfirm = true
                }
            }
            .padding(.horizontal, 17) // (378-344)/2 = 17
            .padding(.bottom, 22)
        }
        .background(
            // Белая подложка + персиковый тинт сверху — фон страницы не просвечивает сквозь карточку
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(cardBackgroundPeach)
                )
                .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 4)
        )
    }

    // MARK: - Кнопка действия (Выход / Удалить аккаунт)

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.gilroy(13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 41)
                .background(
                    RoundedRectangle(cornerRadius: 20.5, style: .continuous)
                        .fill(darkText)
                )
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(darkText.opacity(0.10))
            .frame(height: 1)
            .padding(.horizontal, 22)
    }

    private func icRatioRow(
        iconAsset: String,
        iconSize: CGSize,
        title: String,
        placeholder: String,
        binding: Binding<String>,
        field: Field
    ) -> some View {
        HStack(spacing: 18) {
            // Контейнер 41×41 — выравнивает все строки одинаково независимо от размера иконки
            ZStack {
                Image(iconAsset)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(darkText)
                    .frame(width: iconSize.width, height: iconSize.height)
            }
            .frame(width: ds(41), height: ds(41))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.gilroy(13, weight: .semibold))
                    .foregroundStyle(darkText)
                Text("г / 1 ед.")
                    .font(.gilroy(11, weight: .medium))
                    .foregroundStyle(darkText.opacity(0.4))
            }

            Spacer()

            ZStack(alignment: .trailing) {
                TextField(
                    "",
                    text: binding,
                    prompt: Text(placeholder).foregroundColor(darkText.opacity(0.3))
                )
                .keyboardType(.decimalPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
                .font(.gilroy(24, weight: .bold))
                .foregroundStyle(darkText.opacity(0.55))
                .tint(darkText)
                .focused($focus, equals: field)
                .frame(width: 70)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(darkText.opacity(focus == field ? 0.5 : 0.18))
                    .frame(width: 60, height: focus == field ? 1.5 : 1)
                    .offset(y: 4)
            }
            .animation(.easeInOut(duration: 0.2), value: focus)
            .padding(.trailing, 10) // лёгкий сдвиг чисел влево
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    // MARK: - Sources card

    private var sourcesSection: some View {
        // Grid выравнивает левый край всех трёх текстовых блоков по одной вертикальной линии
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow(alignment: .center) {
                Image("book")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(darkText)
                    .frame(width: ds(32), height: ds(32))

                Text("Источники расчётов")
                    .font(.gilroy(20, weight: .semibold))
                    .foregroundStyle(darkText)
            }

            GridRow(alignment: .top) {
                Color.clear
                    .frame(width: 32, height: 1)

                Text("Методика расчётов (ISF, IC ratio) основана на клинических рекомендациях ФГБУ «НМИЦ эндокринологии» Минздрава России. Результаты носят информационный характер и не заменяют консультацию врача.")
                    .font(.gilroy(13, weight: .medium))
                    .lineSpacing(3)
                    .foregroundStyle(darkText.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
            }

            GridRow(alignment: .center) {
                Image("link")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(darkText)
                    .frame(width: ds(25), height: ds(27.27))

                Link(destination: URL(string: "https://www.endocrincentr.ru/sites/default/files/all/shkola_diabeta/saharnyj_diabet_1_tipa_rukovodstvo_dlya_pacientov.pdf")!) {
                    Text("Сахарный диабет 1 типа - руководство для пациентов")
                        .font(.gilroy(13, weight: .semibold))
                        .italic()
                        .underline()
                        .lineSpacing(3)
                        .foregroundStyle(Color.black.opacity(0.25)) // #00000040
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Loading / Empty

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().tint(darkText).scaleEffect(1.2)
            Text("Загрузка профиля…")
                .foregroundStyle(darkText.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 18)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: ds(46)))
                .foregroundStyle(darkText.opacity(0.85))

            Text("Не удалось загрузить профиль")
                .font(.gilroy(17, weight: .semibold))
                .foregroundStyle(darkText)

            if let msg = vm.errorMessage {
                Text(msg)
                    .foregroundStyle(darkText.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            Button("Повторить") {
                Task { await load() }
            }
            .buttonStyle(.borderedProminent)
            .tint(darkText)
            .foregroundStyle(.white)
            .controlSize(.large)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Logic

    private var canSave: Bool {
        guard let d = draft else { return false }
        return d.target_glucose_mmol > 0 &&
        d.insulin_sensitivity_factor > 0 &&
        d.ic_ratio_breakfast > 0 &&
        d.ic_ratio_lunch > 0 &&
        d.ic_ratio_dinner > 0
    }

    private var hasChanges: Bool {
        guard let o = original, let d = draft else { return false }
        return !approximatelyEqual(o, d)
    }

    private func approximatelyEqual(_ a: ProfileDTO, _ b: ProfileDTO) -> Bool {
        func eq(_ x: Double, _ y: Double) -> Bool { abs(x - y) < 0.0001 }
        return
            eq(a.target_glucose_mmol, b.target_glucose_mmol) &&
            eq(a.insulin_sensitivity_factor, b.insulin_sensitivity_factor) &&
            eq(a.ic_ratio_breakfast, b.ic_ratio_breakfast) &&
            eq(a.ic_ratio_lunch, b.ic_ratio_lunch) &&
            eq(a.ic_ratio_dinner, b.ic_ratio_dinner)
    }

    private func numberTextBinding(_ keyPath: WritableKeyPath<ProfileDTO, Double>) -> Binding<String> {
        Binding<String>(
            get: {
                guard let d = draft else { return "" }
                let v = d[keyPath: keyPath]
                if v == 0 { return "" }
                if v.truncatingRemainder(dividingBy: 1) == 0 {
                    return String(format: "%.1f", v)
                }
                let s = String(format: "%.2f", v)
                return s.replacingOccurrences(of: "0$", with: "", options: .regularExpression)
            },
            set: { newText in
                guard var d = draft else { return }
                let normalized = newText
                    .replacingOccurrences(of: ",", with: ".")
                    .filter { "0123456789.".contains($0) }

                let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
                let cleaned: String
                if parts.count <= 2 {
                    cleaned = normalized
                } else {
                    cleaned = parts.prefix(2).joined(separator: ".")
                }

                if let v = Double(cleaned) {
                    d[keyPath: keyPath] = v
                    draft = d
                } else if cleaned.isEmpty {
                    d[keyPath: keyPath] = 0
                    draft = d
                }
            }
        )
    }

    private func load() async {
        localError = nil
        vm.errorMessage = nil

        await vm.load()
        if let p = vm.profile {
            original = p
            draft = p
        }

        if (vm.errorMessage ?? "").contains("Войдите снова") {
            appState.logout()
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        do {
            try await appState.deleteAccount()
        } catch {
            isDeleting = false
            localError = error.localizedDescription
        }
    }

    private func save() async {
        focus = nil
        localError = nil
        vm.errorMessage = nil

        guard let d = draft else { return }
        guard canSave else {
            localError = "Проверь значения — все поля должны быть больше нуля."
            return
        }

        await vm.save(updated: d)

        if vm.errorMessage == nil, let newProfile = vm.profile {
            original = newProfile
            draft = newProfile
        }

        if (vm.errorMessage ?? "").contains("Войдите снова") {
            appState.logout()
        }
    }

    /// Автосохранение при потере фокуса — тихо, без алертов.
    /// Сохраняем только если есть изменения и значения валидные.
    private func autoSaveIfChanged() async {
        guard let d = draft, hasChanges, canSave else { return }
        vm.errorMessage = nil
        await vm.save(updated: d)
        if vm.errorMessage == nil, let newProfile = vm.profile {
            original = newProfile
            draft = newProfile
        }
    }
}


