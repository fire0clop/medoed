// Pages/CalculatorView.swift
import SwiftUI
import UIKit
import Combine

struct CalculatorView: View {

    @StateObject private var vm = CalculatorVM()
    @EnvironmentObject private var tabRouter: TabRouter

    @Environment(\.scenePhase) private var scenePhase

    private let darkText = Color(red: 0.204, green: 0.071, blue: 0.0) // #341200

    // MARK: - UI state

    @State private var meal: Meal = Self.guessMealByTime()
    @State private var sugarText: String = ""
    /// Флаг: значение было автозаполнено из профиля — при следующем фокусе очистить
    @State private var sugarIsAutoFilled = false

    // MARK: - Draft product (inline-карточка на главном экране)

    enum FoodCategory: String, CaseIterable, Identifiable {
        case meat, vegetable, fruit, grain, dairy, sweet
        case drink   // напитки — отдельный вариант ввода, не показывается в ряду выбора
        case carbs   // прямой ввод суммы углеводов — отдельный вариант
        case dish    // готовое блюдо из «Мои блюда»
        var id: String { rawValue }

        /// Категории, доступные для выбора иконки в карточке продукта (без drink/carbs/dish)
        static var pickerCases: [FoodCategory] { [.meat, .vegetable, .fruit, .grain, .dairy, .sweet] }

        var asset: String {
            switch self {
            case .meat:      return "meet"
            case .vegetable: return "carrot"
            case .fruit:     return "food-apple"
            case .grain:     return "seed"
            case .dairy:     return "milk"
            case .sweet:     return "chocolate"
            case .drink:     return "drink"
            case .carbs:     return "rice"
            case .dish:      return "dish"
            }
        }
        var label: String {
            switch self {
            case .meat:      return "Мясо/рыба"
            case .vegetable: return "Овощи"
            case .fruit:     return "Фрукты"
            case .grain:     return "Крупы/хлеб"
            case .dairy:     return "Молочное"
            case .sweet:     return "Сладкое"
            case .drink:     return "Напитки"
            case .carbs:     return "Углеводы"
            case .dish:      return "Блюдо"
            }
        }
    }

    /// Имя продукта: если задан явно (из базы) — используем его, иначе будем подставлять label категории.
    @State private var draftName: String = ""
    @State private var draftIsFromCatalog: Bool = false
    @State private var draftCarbsPer100: String = ""
    @State private var draftWeight: String = ""
    @State private var draftCategory: FoodCategory? = nil
    /// id редактируемой записи из чека (nil = добавляем новую)
    @State private var editingItemID: UUID? = nil

    /// Показывать блок результата (после нажатия «Расчитать»)
    @State private var showResult = false

    // Свайпер вариантов ввода
    @State private var inputPage = 0
    @State private var pageHeights: [Int: CGFloat] = [:]
    @State private var swiperHeight: CGFloat = 300
    @State private var swiperHeightReady = false

    // Вариант «Напитки»
    @State private var drinkCarbs: String = ""
    @State private var drinkWeight: String = ""

    // Вариант «Углеводы» (прямой ввод суммы)
    @State private var carbsName: String = ""
    @State private var carbsValue: String = ""

    // Вариант «Мои блюда» (поиск готового блюда + вес)
    @StateObject private var dishesVM = DishesViewModel()
    @State private var dishSearchQuery: String = ""
    @State private var selectedDish: DishDTO? = nil
    @State private var dishWeight: String = ""
    @State private var showCreateDish = false

    // Анимация-«печатная машинка» для placeholder названия (когда вводят вручную)
    private let nameExamples = ["Банан", "Гречка", "Шоколад", "Морковь", "Творог", "Яблоко"]
    @State private var phText: String = ""
    @State private var phIndex = 0
    @State private var phCharCount = 0
    @State private var phDeleting = false
    @State private var phHold = 0
    private let phTimer = Timer.publish(every: 0.14, on: .main, in: .common).autoconnect()

    // Отдельная «печатная машинка» для поиска блюд (другие примеры)
    private let dishExamples = ["Сырники", "Овсянка", "Паста с сыром", "Салат", "Творог со сметаной"]
    @State private var dishPhText: String = ""
    @State private var dishPhIndex = 0
    @State private var dishPhCharCount = 0
    @State private var dishPhDeleting = false
    @State private var dishPhHold = 0


    // products mode
    struct ProductItem: Identifiable, Hashable {
        let id = UUID()
        var name: String = ""          // показываем только если не пустое (из базы)
        var carbsPer100: String = ""
        var weight: String = ""
        var unit: String = "g"         // "g" или "ml" (в UI не выводим)
        var category: FoodCategory? = nil  // иконка для блока «Чек»
        /// true → в carbsPer100 лежит уже итоговая сумма углеводов (без веса)
        var isDirectCarbs: Bool = false
    }
    @State private var items: [ProductItem] = [
        .init(name: "", carbsPer100: "", weight: "", unit: "g")
    ]

    // ✅ Catalog (products.json)
    struct FoodProduct: Identifiable, Codable, Hashable {
        let id: String
        let name_ru: String
        let xe_per_100: Double
        let unit: String // "g" или "ml"
        let category: String? // "fruit", "vegetable", "meat", "grain", "dairy", "sweet"

        // ХЕ -> углеводы (г) на 100г/100мл
        var carbsPer100: Double { xe_per_100 * 11.0 }

        // Категория для иконки
        var foodCategory: FoodCategory? {
            guard let category else { return nil }
            return FoodCategory(rawValue: category)
        }
    }

    @State private var catalog: [FoodProduct] = []
    @State private var catalogLoaded = false
    @State private var showCatalogSheet = false
    @State private var catalogQuery: String = ""

    // Щит «Мои блюда»
    @State private var showDishesSheet = false

    @FocusState private var focus: Focus?

    enum Focus: Hashable {
        case sugar
        case pCarbs(Int)   // индекс в массиве items
        case pWeight(Int)  // индекс в массиве items
        case draftCarbs
        case draftWeight
        case draftName
        case drinkCarbs
        case drinkWeight
        case carbsName
        case carbsValue
        case dishSearch
        case dishWeight
    }

    // MARK: - Флаг активности экрана
    @State private var isViewActive = false

    /// После долгого фона SwiftUI иногда ломается на вложенных sheet + FocusState; возвращаем на «корень» калькулятора.
    @State private var enteredBackgroundAt: Date?
    /// Не сбрасывать при быстром переключении в другое приложение; типичные вылеты — после долгой паузы (часы).
    private static let backgroundResetAfterSeconds: TimeInterval = 300

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            background

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    topNavBar
                    mainMealPicker
                    mainSugarCard
                    inputSwiper
                    checkCard
                        // за край экрана уезжает пустое пространство в конце чека (60pt filler),
                        // информационный контент остаётся видимым
                        .padding(.bottom, -60)
                }
                .padding(.horizontal, 18)
                .ipadReadable()
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .contentShape(Rectangle())
        .onTapGesture { focus = nil }          // тап мимо поля — скрыть клавиатуру
        // Sheet базы продуктов («из базы» в карточке продукта)
        .sheet(isPresented: $showCatalogSheet) {
            catalogSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        // Щит «Мои блюда» (кнопка «Блюда» сверху слева)
        .sheet(isPresented: $showDishesSheet) {
            DishesView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
        }
        // Создание нового блюда из режима «Мои блюда» в свайпере
        .fullScreenCover(isPresented: $showCreateDish, onDismiss: {
            Task { await dishesVM.reload() }
        }) {
            DishCreateView(
                screenTitle: "Новое блюдо",
                initial: nil,
                onSave: { title, isPublic, ingredients in
                    await dishesVM.create(title: title, isPublic: isPublic, ingredients: ingredients)
                }
            )
        }
        // ✅ Профиль — каждый раз при заходе на экран
        .onAppear {
            isViewActive = true
            
            if !catalogLoaded {
                loadCatalog()
                catalogLoaded = true
            }
            Task { await vm.loadProfile() } // 🔥 убрал force: true
            dishesVM.tab = .mine
            Task { await dishesVM.reload() }   // загружаем «Мои блюда» для свайпера
            
            // ✅ Если профиль уже есть при появлении — заполняем сахар
            if let target = vm.profile?.target_glucose_mmol, sugarText.trimmed.isEmpty {
                sugarText = fmt(target)
                sugarIsAutoFilled = true
            }
        }
        .onDisappear {
            isViewActive = false
            focus = nil   // 🔥 важно
        }
        // ✅ И ещё раз при возврате приложения в active
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                enteredBackgroundAt = Date()
                focus = nil
            }

            if newPhase == .active {
                focus = nil
                sanitizeFocus()

                var didLongBackgroundReset = false
                if let start = enteredBackgroundAt,
                   Date().timeIntervalSince(start) >= Self.backgroundResetAfterSeconds {
                    closeSheetsAndResetToBase()
                    didLongBackgroundReset = true
                }
                enteredBackgroundAt = nil

                if !showCatalogSheet {
                    meal = Self.guessMealByTime()
                }

                Task {
                    await vm.loadProfile(force: didLongBackgroundReset)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    guard isViewActive else { return }
                    focus = nil
                    sanitizeFocus()
                }
            }
        }
        .onChange(of: items.count) { _, _ in sanitizeFocus() }
        // ✅ При загрузке профиля заполняем сахар, если ещё пусто
        .onChange(of: vm.profile?.target_glucose_mmol) { _, target in
            if sugarText.trimmed.isEmpty, let t = target {
                sugarText = fmt(t)
                sugarIsAutoFilled = true
            }
        }
        // Очищаем автозаполненное значение при первом фокусе на поле
        .onChange(of: focus) { _, newFocus in
            if newFocus == .sugar, sugarIsAutoFilled {
                sugarText = ""
                sugarIsAutoFilled = false
            }
        }
    }

    // MARK: - Top nav (кнопки переключения экранов)

    private var topNavBar: some View {
        HStack {
            navIconButton(asset: "dish", title: "Блюда") {
                focus = nil
                showDishesSheet = true
            }
            Spacer()
            navIconButton(asset: "profile-nav", title: "Профиль") {
                tabRouter.selected = .profile
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 60)
    }

    // MARK: - Свайпер вариантов ввода

    private var inputSwiper: some View {
        VStack(spacing: 12) {
            TabView(selection: $inputPage) {
                mainProductCard
                    .padding(.vertical, 10)   // запас под тень, иначе TabView обрезает
                    .background(pageHeightReader(0))
                    .tag(0)
                drinksCard
                    .padding(.vertical, 10)
                    .background(pageHeightReader(1))
                    .tag(1)
                carbsCard
                    .padding(.vertical, 10)
                    .background(pageHeightReader(2))
                    .tag(2)
                dishSearchCard
                    .padding(.vertical, 10)
                    .background(pageHeightReader(3))
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: swiperHeight)
            .onPreferenceChange(PageHeightKey.self) { newValues in
                for (k, v) in newValues { pageHeights[k] = v }
                guard let h = pageHeights[inputPage] else { return }
                if !swiperHeightReady {
                    // первая инициализация — без анимации
                    swiperHeight = h
                    swiperHeightReady = true
                } else if abs(swiperHeight - h) > 0.5 {
                    // высота текущей страницы изменилась — мягко подстраиваемся
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { swiperHeight = h }
                }
            }
            .onChange(of: inputPage) { _, newPage in
                // плавно подстраиваем высоту под новую страницу — чек смещается мягко
                if let h = pageHeights[newPage] {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { swiperHeight = h }
                }
            }

            // Точки-индикатор
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i == inputPage ? darkText.opacity(0.55) : darkText.opacity(0.2))
                        .frame(width: ds(8), height: ds(8))
                }
            }
        }
    }

    private func pageHeightReader(_ page: Int) -> some View {
        GeometryReader { geo in
            Color.clear.preference(key: PageHeightKey.self, value: [page: geo.size.height])
        }
    }

    // MARK: - Product draft card (главный экран, под sugar)

    private var orangeAccent: Color { Color(red: 1.0, green: 0.592, blue: 0.0) } // #FF9700
    private var peachLight:   Color { Color(red: 1.0, green: 0.706, blue: 0.549).opacity(0.22) } // #FFB48C 22%

    private var canAddDraft: Bool {
        !draftName.trimmed.isEmpty &&
        draftCategory != nil &&
        (Double(draftCarbsPer100.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0 &&
        (Double(draftWeight.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    /// В форме что-то заполнено / выбрано — показываем крестик очистки
    private var draftHasContent: Bool {
        !draftName.trimmed.isEmpty ||
        !draftCarbsPer100.trimmed.isEmpty ||
        !draftWeight.trimmed.isEmpty ||
        draftCategory != nil ||
        editingItemID != nil
    }

    private func clearDraft() {
        draftName = ""
        draftIsFromCatalog = false
        draftCarbsPer100 = ""
        draftWeight = ""
        draftCategory = nil
        editingItemID = nil
        focus = nil
    }

    // MARK: - Вариант «Напитки»

    private var canAddDrink: Bool {
        (Double(drinkCarbs.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0 &&
        (Double(drinkWeight.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    private var drinksCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Заголовок: «Напитки» + фиксированная иконка
            HStack(alignment: .center) {
                Text("Напитки")
                    .font(.gilroy(20, weight: .semibold))
                    .foregroundStyle(darkText)

                Spacer()

                ZStack {
                    Circle()
                        .fill(peachLight)
                        .frame(width: ds(40), height: ds(40))
                    Image("drink")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(orangeAccent)
                        .frame(width: ds(20), height: ds(20))
                }
            }

            // Два числовых поля (вес в мл)
            HStack(alignment: .top, spacing: 16) {
                draftNumberField(
                    title: "Уг/100 г.",
                    text: $drinkCarbs,
                    placeholder: "0",
                    focusKey: .drinkCarbs
                )
                draftNumberField(
                    title: "Вес, мл.",
                    text: $drinkWeight,
                    placeholder: "0",
                    focusKey: .drinkWeight
                )
            }

            // Кнопка «Добавить» / «Сохранить изменения»
            Button {
                commitDrink()
            } label: {
                Text(editingItemID != nil ? "Сохранить изменения" : "Добавить")
                    .font(.gilroy(14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 23, style: .continuous)
                            .fill(canAddDrink ? orangeAccent : orangeAccent.opacity(0.45))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canAddDrink)
            .padding(.top, 4)
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 4)
        )
        .padding(.horizontal, 4)
    }

    private func commitDrink() {
        if let editID = editingItemID, let idx = items.firstIndex(where: { $0.id == editID }) {
            // Редактирование напитка
            items[idx].name = "Напитки"
            items[idx].carbsPer100 = drinkCarbs
            items[idx].weight = drinkWeight
            items[idx].unit = "ml"
            items[idx].category = .drink
        } else {
            let newItem = ProductItem(
                name: "Напитки",
                carbsPer100: drinkCarbs,
                weight: drinkWeight,
                unit: "ml",
                category: .drink
            )
            if items.count == 1, items[0].isEffectivelyEmpty {
                items[0] = newItem
            } else {
                items.append(newItem)
            }
        }
        drinkCarbs = ""
        drinkWeight = ""
        editingItemID = nil
        focus = nil
    }

    // MARK: - Вариант «Углеводы» (прямой ввод суммы)

    private var canAddCarbs: Bool {
        !carbsName.trimmed.isEmpty &&
        (Double(carbsValue.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    private var carbsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Заголовок: «Углеводы» + фиксированная иконка
            HStack(alignment: .center) {
                Text("Углеводы")
                    .font(.gilroy(20, weight: .semibold))
                    .foregroundStyle(darkText)

                Spacer()

                ZStack {
                    Circle()
                        .fill(peachLight)
                        .frame(width: ds(40), height: ds(40))
                    Image("rice")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(orangeAccent)
                        .frame(width: ds(20), height: ds(20))
                }
            }

            // Название с анимированным placeholder и мигающим курсором
            ZStack(alignment: .leading) {
                if carbsName.isEmpty && focus != .carbsName {
                    HStack(spacing: 2) {
                        Text(phText)
                            .font(.gilroy(13, weight: .medium))
                            .foregroundStyle(darkText.opacity(0.4))
                        BlinkingCaret(height: 15, color: darkText.opacity(0.4))
                    }
                }
                TextField("", text: $carbsName)
                    .font(.gilroy(13, weight: .medium))
                    .foregroundStyle(darkText.opacity(0.4))
                    .tint(darkText)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .carbsName)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle().fill(darkText.opacity(0.18)).frame(height: 1).offset(y: 6)
            }
            .padding(.bottom, 6)

            // Поле суммы углеводов (с суффиксом «г.»)
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                ZStack(alignment: .leading) {
                    if carbsValue.isEmpty {
                        Text("0")
                            .font(.gilroy(48, weight: .bold))
                            .foregroundStyle(darkText.opacity(0.4))
                    }
                    TextField("", text: $carbsValue)
                        .keyboardType(.decimalPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.gilroy(48, weight: .bold))
                        .foregroundStyle(darkText.opacity(0.4))
                        .tint(darkText)
                        .focused($focus, equals: .carbsValue)
                        .onChange(of: carbsValue) { _, v in
                            let cleaned = v.replacingOccurrences(of: ",", with: ".")
                                .filter { "0123456789.".contains($0) }
                            if cleaned != v { carbsValue = cleaned }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("г.")
                    .font(.gilroy(15, weight: .medium))
                    .foregroundStyle(darkText.opacity(0.4))
                    .padding(.bottom, 10)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(darkText.opacity(0.18)).frame(height: 1)
            }

            // Кнопка «Добавить» / «Сохранить изменения»
            Button {
                commitCarbs()
            } label: {
                Text(editingItemID != nil ? "Сохранить изменения" : "Добавить")
                    .font(.gilroy(14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 23, style: .continuous)
                            .fill(canAddCarbs ? orangeAccent : orangeAccent.opacity(0.45))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canAddCarbs)
            .padding(.top, 4)
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 4)
        )
        .padding(.horizontal, 4)
    }

    private func commitCarbs() {
        if let editID = editingItemID, let idx = items.firstIndex(where: { $0.id == editID }) {
            items[idx].name = carbsName.trimmed
            items[idx].carbsPer100 = carbsValue
            items[idx].weight = ""
            items[idx].unit = "g"
            items[idx].category = .carbs
            items[idx].isDirectCarbs = true
        } else {
            let newItem = ProductItem(
                name: carbsName.trimmed,
                carbsPer100: carbsValue,
                weight: "",
                unit: "g",
                category: .carbs,
                isDirectCarbs: true
            )
            if items.count == 1, items[0].isEffectivelyEmpty {
                items[0] = newItem
            } else {
                items.append(newItem)
            }
        }
        carbsName = ""
        carbsValue = ""
        editingItemID = nil
        focus = nil
    }

    // MARK: - Вариант «Мои блюда» (поиск + вес)

    private var foundDishes: [DishDTO] {
        let q = dishSearchQuery.trimmed.lowercased()
        guard !q.isEmpty else { return [] }   // пока ничего не введено — список пуст
        return dishesVM.visibleMine.filter { $0.title.lowercased().contains(q) }
    }

    private var canAddDish: Bool {
        selectedDish != nil && (Double(dishWeight.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
    }

    private var dishSearchCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Заголовок: «Мои блюда» + иконка
            HStack(alignment: .center) {
                Text("Мои блюда")
                    .font(.gilroy(20, weight: .semibold))
                    .foregroundStyle(darkText)
                Spacer()
                ZStack {
                    Circle().fill(peachLight).frame(width: ds(40), height: ds(40))
                    Image("dish")
                        .resizable().renderingMode(.template).scaledToFit()
                        .foregroundStyle(orangeAccent)
                        .frame(width: ds(22), height: ds(22))
                }
            }

            if let dish = selectedDish {
                dishSelectedState(dish)
            } else {
                dishSearchState
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 4)
        )
        .padding(.horizontal, 4)
    }

    // Состояние поиска
    @ViewBuilder
    private var dishSearchState: some View {
        // Поисковая строка с анимированным placeholder
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: ds(13), weight: .medium))
                .foregroundStyle(darkText.opacity(0.4))
            ZStack(alignment: .leading) {
                if dishSearchQuery.isEmpty && focus != .dishSearch {
                    HStack(spacing: 2) {
                        Text(dishPhText)
                            .font(.gilroy(15, weight: .medium))
                            .foregroundStyle(darkText.opacity(0.4))
                        BlinkingCaret(height: 17, color: darkText.opacity(0.4))
                    }
                }
                TextField("", text: $dishSearchQuery)
                    .font(.gilroy(15, weight: .medium))
                    .foregroundStyle(darkText)
                    .tint(darkText)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .dishSearch)
            }
        }
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) {
            Rectangle().fill(darkText.opacity(0.18)).frame(height: 1)
        }

        // Контент появляется только когда что-то введено
        if !dishSearchQuery.trimmed.isEmpty {
            if foundDishes.isEmpty {
                Text("Не найдено")
                    .font(.gilroy(13, weight: .medium))
                    .foregroundStyle(darkText.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
            } else {
                VStack(spacing: 10) {
                    ForEach(foundDishes) { dish in
                        Button {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                                selectedDish = dish
                                dishWeight = ""
                            }
                        } label: {
                            dishResultRow(dish)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Кнопка «Добавить новое блюдо»
            Button {
                focus = nil
                showCreateDish = true
            } label: {
                Text("Добавить новое блюдо")
                    .font(.gilroy(13, weight: .semibold))
                    .italic()
                    .foregroundStyle(orangeAccent)
                    .padding(.horizontal, 18)
                    .frame(height: 38)
                    .background(Capsule().fill(peachLight))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
    }

    private func dishResultRow(_ dish: DishDTO) -> some View {
        HStack(alignment: .center) {
            Text(dish.title)
                .font(.gilroy(15, weight: .semibold))
                .foregroundStyle(darkText)
                .lineLimit(1)
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 0) {
                Text("Углеводы: \(fmt(dish.totalCarbs)) г.")
                Text("Вес: \(fmt(dish.totalWeight)) г.")
            }
            .font(.gilroy(12, weight: .medium))
            .foregroundStyle(Color.black.opacity(0.25))
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.12), radius: 4, x: 2, y: 2)
        )
    }

    // Состояние выбранного блюда — ввод веса
    @ViewBuilder
    private func dishSelectedState(_ dish: DishDTO) -> some View {
        Text(dish.title)
            .font(.gilroy(20, weight: .semibold))
            .foregroundStyle(darkText)
            .lineLimit(1)
            .padding(.top, 4)

        // Поле веса (с суффиксом «г.»)
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            ZStack(alignment: .leading) {
                if dishWeight.isEmpty {
                    Text("0")
                        .font(.gilroy(48, weight: .bold))
                        .foregroundStyle(darkText.opacity(0.4))
                }
                TextField("", text: $dishWeight)
                    .keyboardType(.decimalPad)
                    .font(.gilroy(48, weight: .bold))
                    .foregroundStyle(darkText.opacity(0.4))
                    .tint(darkText)
                    .focused($focus, equals: .dishWeight)
                    .onChange(of: dishWeight) { _, v in
                        let cleaned = v.replacingOccurrences(of: ",", with: ".").filter { "0123456789.".contains($0) }
                        if cleaned != v { dishWeight = cleaned }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text("г.")
                .font(.gilroy(11, weight: .medium))
                .foregroundStyle(darkText.opacity(0.4))
                .padding(.bottom, 10)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(darkText.opacity(0.18)).frame(height: 1)
        }

        // Кнопка «Добавить» / «Сохранить изменения»
        Button { commitDish() } label: {
            Text(editingItemID != nil ? "Сохранить изменения" : "Добавить")
                .font(.gilroy(14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 23, style: .continuous)
                        .fill(canAddDish ? orangeAccent : orangeAccent.opacity(0.45))
                )
        }
        .buttonStyle(.plain)
        .disabled(!canAddDish)
        .padding(.top, 4)
    }

    private func commitDish() {
        guard let dish = selectedDish,
              let w = Double(dishWeight.replacingOccurrences(of: ",", with: ".")), w > 0 else { return }
        // Пропорциональный пересчёт углеводов от оригинального блюда
        let proportionalCarbs: Double
        if dish.totalWeight > 0 {
            proportionalCarbs = (dish.totalCarbs / dish.totalWeight * w * 100).rounded() / 100
        } else {
            proportionalCarbs = 0
        }
        if let editID = editingItemID, let idx = items.firstIndex(where: { $0.id == editID }) {
            items[idx].name = dish.title
            items[idx].carbsPer100 = fmt(proportionalCarbs)
            items[idx].weight = fmt(w)
            items[idx].unit = "g"
            items[idx].category = .dish
            items[idx].isDirectCarbs = true
        } else {
            let newItem = ProductItem(
                name: dish.title,
                carbsPer100: fmt(proportionalCarbs),
                weight: fmt(w),
                unit: "g",
                category: .dish,
                isDirectCarbs: true
            )
            if items.count == 1, items[0].isEffectivelyEmpty {
                items[0] = newItem
            } else {
                items.append(newItem)
            }
        }
        // Сброс
        selectedDish = nil
        dishWeight = ""
        dishSearchQuery = ""
        editingItemID = nil
        focus = nil
    }

    private var mainProductCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Заголовок: название слева + «из базы» справа
            HStack(alignment: .center) {
                draftNameField

                Spacer(minLength: 8)

                Button {
                    openCatalogFromInline()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: ds(14), weight: .medium))
                            .frame(width: ds(16), height: ds(16))
                        Text("Из базы")
                            .font(.gilroy(11, weight: .medium))
                    }
                    .foregroundStyle(darkText.opacity(0.4))
                    .frame(width: ds(90), height: ds(33))
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(peachLight)
                    )
                }
                .buttonStyle(.plain)
                .disabled(catalog.isEmpty)
                .opacity(catalog.isEmpty ? 0.5 : 1)

                // Крестик очистки — появляется когда форма заполнена
                if draftHasContent {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { clearDraft() }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: ds(12), weight: .semibold))
                            .foregroundStyle(darkText.opacity(0.4))
                            .frame(width: ds(33), height: ds(33))
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(peachLight)
                            )
                    }
                    .buttonStyle(.plain)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.15), value: draftHasContent)

            // Маленькая сноска под названием (только при ручном вводе)
            if !draftIsFromCatalog {
                Text("*Заполните название продукта")
                    .font(.gilroy(9, weight: .medium))
                    .foregroundStyle(darkText.opacity(0.4))
                    .padding(.top, -12)
            }

            // Два числовых поля
            HStack(alignment: .top, spacing: 16) {
                draftNumberField(
                    title: "Уг/100 г.",
                    text: $draftCarbsPer100,
                    placeholder: "0",
                    focusKey: .draftCarbs
                )
                draftNumberField(
                    title: "Вес, г.",
                    text: $draftWeight,
                    placeholder: "0",
                    focusKey: .draftWeight
                )
            }

            // Ряд категорий
            HStack(spacing: 8) {
                ForEach(FoodCategory.pickerCases) { cat in
                    categoryIcon(cat)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 2)

            // Кнопка «Добавить» / «Сохранить изменения»
            Button {
                commitDraft()
            } label: {
                Text(editingItemID != nil ? "Сохранить изменения" : "Добавить")
                    .font(.gilroy(14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 23, style: .continuous)
                            .fill(canAddDraft ? orangeAccent : orangeAccent.opacity(0.45))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canAddDraft)
            .padding(.top, 4)
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 4)
        )
        .padding(.horizontal, 4)
        .onReceive(phTimer) { _ in
            advancePlaceholder()
            advanceDishPlaceholder()
        }
    }

    /// «Печатная машинка»: набирает пример названия, держит паузу, стирает, переходит к следующему.
    private func advancePlaceholder() {
        // Анимируем пока есть видимый placeholder хотя бы в одном поле названия:
        // — карточка продукта (draftName), пусто, не из базы, не в фокусе
        // — карточка «Углеводы» (carbsName), пусто, не в фокусе
        let productNeeds = draftName.isEmpty && !draftIsFromCatalog && focus != .draftName
        let carbsNeeds   = carbsName.isEmpty && focus != .carbsName
        guard productNeeds || carbsNeeds else { return }

        if phHold > 0 { phHold -= 1; return }

        let example = nameExamples[phIndex]
        if !phDeleting {
            if phCharCount < example.count {
                phCharCount += 1
            } else {
                phHold = 8          // пауза ~1.1с на полном слове
                phDeleting = true
                return
            }
        } else {
            if phCharCount > 0 {
                phCharCount -= 1
            } else {
                phDeleting = false
                phIndex = (phIndex + 1) % nameExamples.count
            }
        }
        phText = String(nameExamples[phIndex].prefix(phCharCount))
    }

    /// «Печатная машинка» для поиска блюд — отдельные примеры
    private func advanceDishPlaceholder() {
        // Анимируем когда поле поиска пустое и не в фокусе (и selectedDish == nil)
        guard selectedDish == nil, dishSearchQuery.isEmpty, focus != .dishSearch else { return }

        if dishPhHold > 0 { dishPhHold -= 1; return }

        let example = dishExamples[dishPhIndex]
        if !dishPhDeleting {
            if dishPhCharCount < example.count {
                dishPhCharCount += 1
            } else {
                dishPhHold = 8
                dishPhDeleting = true
                return
            }
        } else {
            if dishPhCharCount > 0 {
                dishPhCharCount -= 1
            } else {
                dishPhDeleting = false
                dishPhIndex = (dishPhIndex + 1) % dishExamples.count
            }
        }
        dishPhText = String(dishExamples[dishPhIndex].prefix(dishPhCharCount))
    }

    @ViewBuilder
    private var draftNameField: some View {
        if draftIsFromCatalog {
            // Из базы — название не редактируется
            Text(draftName)
                .font(.gilroy(20, weight: .semibold))
                .foregroundStyle(darkText)
                .lineLimit(1)
                .truncationMode(.tail)
        } else {
            ZStack(alignment: .leading) {
                // Анимированный placeholder с мигающим курсором — пока пусто и не в фокусе
                if draftName.isEmpty && focus != .draftName {
                    HStack(spacing: 2) {
                        Text(phText)
                            .font(.gilroy(20, weight: .semibold))
                            .foregroundStyle(darkText.opacity(0.4)) // #34120066
                        BlinkingCaret(height: 22, color: darkText.opacity(0.4))
                    }
                }
                TextField("", text: $draftName)
                    .font(.gilroy(20, weight: .semibold))
                    .foregroundStyle(darkText)                  // #341200 когда заполнено
                    .tint(darkText)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .draftName)
                    .lineLimit(1)
            }
        }
    }

    private func draftNumberField(title: String, text: Binding<String>, placeholder: String, focusKey: Focus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.gilroy(11, weight: .medium))
                .foregroundStyle(darkText.opacity(0.4))

            ZStack(alignment: .leading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.gilroy(48, weight: .bold))
                        .foregroundStyle(darkText.opacity(0.4))
                }
                TextField("", text: text)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.gilroy(48, weight: .bold))
                    .foregroundStyle(darkText.opacity(0.4))
                    .tint(darkText)
                    .focused($focus, equals: focusKey)
                    .onChange(of: text.wrappedValue) { _, v in
                        let cleaned = v
                            .replacingOccurrences(of: ",", with: ".")
                            .filter { "0123456789.".contains($0) }
                        if cleaned != v { text.wrappedValue = cleaned }
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(darkText.opacity(0.18))
                    .frame(height: 1)
                    .offset(y: 4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func categoryIcon(_ cat: FoodCategory) -> some View {
        let active = (draftCategory == cat)
        // У продуктов из базы иконка фиксирована — менять нельзя.
        // Неактивные иконки в таком режиме тускнеют, чтобы было видно что выбор заблокирован.
        let locked = draftIsFromCatalog
        return Button {
            withAnimation(.easeOut(duration: 0.12)) { draftCategory = cat }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(active ? orangeAccent : peachLight)
                        .frame(width: ds(31), height: ds(31))
                    Image(cat.asset)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(active ? .white : orangeAccent)
                        .frame(width: ds(16), height: ds(16))
                }
                Text(cat.label)
                    .font(.gilroy(8, weight: .medium))
                    .foregroundStyle(darkText.opacity(0.4))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .opacity(locked && !active ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(locked)   // из базы — иконку не сменить
    }

    private func commitDraft() {
        if let editID = editingItemID, let idx = items.firstIndex(where: { $0.id == editID }) {
            // Режим редактирования — обновляем существующую запись, сохраняя id
            items[idx].name = draftName.trimmed
            items[idx].carbsPer100 = draftCarbsPer100
            items[idx].weight = draftWeight
            items[idx].category = draftCategory
        } else {
            // Добавление новой записи
            let newItem = ProductItem(
                name: draftName.trimmed,
                carbsPer100: draftCarbsPer100,
                weight: draftWeight,
                unit: "g",
                category: draftCategory
            )
            // Подменяем единственную пустую заготовку или добавляем
            if items.count == 1, items[0].isEffectivelyEmpty {
                items[0] = newItem
            } else {
                items.append(newItem)
            }
        }

        // Сброс черновика
        draftName = ""
        draftIsFromCatalog = false
        draftCarbsPer100 = ""
        draftWeight = ""
        draftCategory = nil
        editingItemID = nil
        focus = nil
    }

    // MARK: - Чек: редактирование и удаление

    private func startEditingCheckItem(_ item: ProductItem) {
        editingItemID = item.id

        let pageAnimation: Animation = .spring(response: 0.5, dampingFraction: 0.85)

        if item.category == .dish {
            // Запись-блюдо → 4-й режим («Мои блюда»), состояние выбранного блюда
            // Ищем оригинальное блюдо по названию (id в чеке не храним)
            if let original = dishesVM.visibleMine.first(where: { $0.title == item.name }) {
                selectedDish = original
            } else {
                // Блюдо удалено из «Мои блюда» — создаём фиктивный объект,
                // чтобы можно было хотя бы поправить вес (углеводы пересчитаются от него)
                selectedDish = nil
            }
            dishWeight = item.weight
            withAnimation(pageAnimation) { inputPage = 3 }
        } else if item.isDirectCarbs || item.category == .carbs {
            // Прямой ввод углеводов → вариант «Углеводы»
            carbsName = item.name
            carbsValue = item.carbsPer100
            withAnimation(pageAnimation) { inputPage = 2 }
        } else if item.category == .drink {
            // Запись-напиток → переключаемся на вариант «Напитки»
            drinkCarbs = item.carbsPer100
            drinkWeight = item.weight
            withAnimation(pageAnimation) { inputPage = 1 }
        } else {
            // Обычный продукт → вариант с продуктом
            draftName = item.name
            draftIsFromCatalog = false   // даём редактировать имя и иконку
            draftCarbsPer100 = item.carbsPer100
            draftWeight = item.weight
            draftCategory = item.category
            withAnimation(pageAnimation) { inputPage = 0 }
        }
    }

    private func deleteCheckItem(_ item: ProductItem) {
        withAnimation(.easeOut(duration: 0.2)) {
            items.removeAll { $0.id == item.id }
        }
        // Если удаляли как раз редактируемую — сбросить режим
        if editingItemID == item.id {
            clearDraft()
            drinkCarbs = ""
            drinkWeight = ""
            carbsName = ""
            carbsValue = ""
            selectedDish = nil
            dishWeight = ""
            dishSearchQuery = ""
        }
    }

    // MARK: - Чек (список добавленных продуктов)

    private var checkItems: [ProductItem] {
        items.filter { !$0.isEffectivelyEmpty }
    }

    private var checkTotalCarbs: Double {
        checkItems.reduce(0) { $0 + carbsFor($1) }.rounded(toPlaces: 2)
    }

    /// Расчёт по той же формуле, что и в шитах, но углеводы берём из чека.
    private func calcMain() -> CalcRes {
        let carbs = checkTotalCarbs
        guard carbs >= 0, let sugar = parseNumber(sugarText) else {
            return .init(food: 0, corr: 0, total: 0)
        }
        let (target, isf, k) = paramsForMeal()
        let food = ((carbs / 11.0) * k).rounded(toPlaces: 2)
        let corr = ((sugar - target) / isf).rounded(toPlaces: 2)
        let total = (food + corr).rounded(toPlaces: 2)
        return .init(food: food, corr: corr, total: total)
    }

    // MARK: - Блок результата

    @ViewBuilder
    private var resultMainBlock: some View {
        if showResult {
            let r = calcMain()
            VStack(spacing: 14) {
                Text("Расчёт по формуле:")
                    .font(.gilroy(20, weight: .semibold))
                    .foregroundStyle(darkText)               // #341200

                Text(r.totalText)
                    .font(.gilroy(48, weight: .bold))
                    .foregroundStyle(darkText.opacity(0.4))  // #34120066

                HStack(spacing: 14) {
                    resultChip(title: "На еду", value: r.foodText)
                    resultChip(title: "Коррекция", value: r.corrText)
                }
                .padding(.top, 4)

                Text("Носит информационный характер. Уточняйте дозу у лечащего врача.")
                    .font(.gilroy(11, weight: .medium))
                    .foregroundStyle(darkText.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 22)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func resultChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.gilroy(11, weight: .semibold))
                .foregroundStyle(darkText.opacity(0.4))      // #34120066
            Text(value)
                .font(.gilroy(20, weight: .bold))
                .foregroundStyle(darkText.opacity(0.4))      // #34120066
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 79, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(peachLight) // #FFB48C38
        )
    }

    private var checkCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Чек")
                .font(.gilroy(20, weight: .semibold))
                .foregroundStyle(darkText)
                .padding(.bottom, 18)

            if checkItems.isEmpty {
                // Пустое состояние — чтобы не выглядело как пустой шаблон
                VStack(spacing: 8) {
                    Image(systemName: "cart")
                        .font(.system(size: ds(26), weight: .regular))
                        .foregroundStyle(darkText.opacity(0.3))
                    Text("Здесь появятся добавленные продукты")
                        .font(.gilroy(13, weight: .medium))
                        .foregroundStyle(darkText.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            } else {
                ForEach(Array(checkItems.enumerated()), id: \.element.id) { index, item in
                    SwipeToDeleteRow(
                        onTap: { startEditingCheckItem(item) },
                        onDelete: { deleteCheckItem(item) }
                    ) {
                        checkRow(number: index + 1, item: item)
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))

                    if index < checkItems.count - 1 {
                        Rectangle()
                            .fill(darkText.opacity(0.18))
                            .frame(height: 1)
                            .padding(.vertical, 14)
                    }
                }
            }

            // Итого
            HStack {
                Text("Итого:")
                    .font(.gilroy(20, weight: .bold))
                    .foregroundStyle(darkText)
                Spacer()
                Text("\(fmt(checkTotalCarbs)) г.")
                    .font(.gilroy(20, weight: .bold))
                    .foregroundStyle(darkText)
            }
            .padding(.top, 34)

            // Кнопка «Расчитать»
            Button {
                focus = nil
                withAnimation(.easeOut(duration: 0.25)) { showResult = true }
            } label: {
                Text("Рассчитать")
                    .font(.gilroy(16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        Capsule(style: .continuous).fill(checkItems.isEmpty ? orangeAccent.opacity(0.45) : orangeAccent)
                    )
            }
            .buttonStyle(.plain)
            .disabled(checkItems.isEmpty)
            .padding(.top, 16)

            // Подпись-источник
            Text("Источник формул - НМИЦ эндокринологии")
                .font(.gilroy(11, weight: .medium))
                .italic()
                .foregroundStyle(darkText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 22)

            // Блок результата — внутри карточки чека
            resultMainBlock

            // Пустое пространство — именно оно уезжает за нижний край экрана,
            // чтобы информационный контент не срезался
            Spacer().frame(height: 60)
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(peachLight) // rgba(255, 180, 140, 0.22)
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 4)
        )
        .padding(.horizontal, 4)
    }

    private func checkRow(number: Int, item: ProductItem) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text("\(number).")
                .font(.gilroy(20, weight: .medium))
                .foregroundStyle(darkText)
                .frame(minWidth: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text("Углеводы: \(fmt(carbsFor(item))) г.")
                    .font(.gilroy(15, weight: .medium))
                    .foregroundStyle(darkText)
                // Для прямого ввода суммы веса нет — строку не показываем
                if !item.isDirectCarbs {
                    Text("Вес: \(item.weight.isEmpty ? "0" : item.weight) \(item.unit == "ml" ? "мл." : "г.")")
                        .font(.gilroy(15, weight: .medium))
                        .foregroundStyle(darkText)
                }
            }

            Spacer()

            // Иконка категории
            ZStack {
                Circle()
                    .fill(peachLight)
                    .frame(width: ds(49), height: ds(49))
                if let cat = item.category {
                    Image(cat.asset)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(orangeAccent)
                        .frame(width: ds(25), height: ds(25))
                }
            }
        }
    }

    /// Открытие базы продуктов из inline-карточки. По выбору товара
    /// заполнит draft и закроет шит.
    private func openCatalogFromInline() {
        dismissKeyboardHard()
        catalogQuery = ""
        showCatalogSheet = true
    }

    // MARK: - Sugar card (главный экран)

    private var mainSugarCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Строка заголовка
            HStack(alignment: .firstTextBaseline) {
                Text("Сахар до еды")
                    .font(.gilroy(20, weight: .semibold))
                    .foregroundStyle(darkText)

                Spacer()

                Button {
                    sugarText = fmt(vm.profile?.target_glucose_mmol ?? 6.5)
                    sugarIsAutoFilled = true
                    focus = .sugar
                } label: {
                    Text("Цель")
                        .font(.gilroy(11, weight: .medium))
                        .foregroundStyle(darkText.opacity(0.4))
                }
                .buttonStyle(.plain)
                .disabled(vm.profile == nil)
            }

            Spacer().frame(height: 18)

            // Поле ввода + единица измерения
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                ZStack(alignment: .leading) {
                    if sugarText.isEmpty {
                        Text("0")
                            .font(.gilroy(48, weight: .bold))
                            .foregroundStyle(darkText.opacity(0.4))
                    }
                    TextField(
                        "",
                        text: $sugarText
                    )
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.gilroy(48, weight: .bold))
                    .foregroundStyle(darkText.opacity(0.4))
                    .tint(darkText)
                    .focused($focus, equals: .sugar)
                    .onChange(of: sugarText) { _, v in
                        let cleaned = v
                            .replacingOccurrences(of: ",", with: ".")
                            .filter { "0123456789.".contains($0) }
                        if cleaned != v { sugarText = cleaned }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("ммоль/л")
                    .font(.gilroy(11, weight: .medium))
                    .foregroundStyle(darkText.opacity(0.4))
                    .padding(.bottom, 10)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(darkText.opacity(0.18))
                    .frame(height: 1)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 4)
        )
        .padding(.horizontal, 4)
    }

    // MARK: - Meal picker (главный экран)

    private var mainMealPicker: some View {
        HStack(spacing: 8) {
            ForEach(Meal.allCases, id: \.self) { m in
                let active = (meal == m)
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { meal = m }
                } label: {
                    HStack(spacing: 7) {
                        Image(m.asset)
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .foregroundStyle(active ? .white : darkText)
                            .frame(width: m.iconSize.width, height: m.iconSize.height)

                        Text(m.title)
                            .font(.gilroy(14, weight: .semibold))
                            .foregroundStyle(active ? .white : darkText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 23, style: .continuous)
                            .fill(active
                                  ? darkText
                                  : Color(red: 1.0, green: 0.706, blue: 0.549).opacity(0.22))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }

    private func navIconButton(asset: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(darkText.opacity(0.4), lineWidth: 1)
                        .frame(width: ds(46), height: ds(46))
                    Circle()
                        .fill(darkText)
                        .frame(width: ds(40), height: ds(40))
                    Image(asset)
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .foregroundStyle(.white)
                        .frame(width: ds(22), height: ds(22))
                }
                Text(title)
                    .font(.gilroy(11, weight: .semibold))
                    .foregroundStyle(darkText)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Background

    private var background: some View {
        // Один слой картинки во весь экран (как в профиле — без белой полоски сверху).
        // Эффект «66% прозрачности» делаем белым оверлеем 34% поверх непрозрачной картинки,
        // чтобы не было отдельной белой подложки с другим размером.
        // Фрейм фиксирован к экрану — стабильный масштаб при появлении клавиатуры.
        Image("profile-background")
            .resizable()
            .scaledToFill()
            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            .clipped()
            .overlay(Color.white.opacity(0.34))   // имитация 66% прозрачности картинки
            .ignoresSafeArea()
    }

    // MARK: - Actions

    private func dismissKeyboardHard() {
        focus = nil
        UIApplication.shared.endEditing()
    }

    // MARK: - Reset

    private func resetMainSheetInputs() {
        dismissKeyboardHard()

        sugarText = ""
        meal = Self.guessMealByTime()
        items = [.init(name: "", carbsPer100: "", weight: "", unit: "g")]

        // сброс черновиков всех вариантов ввода
        clearDraft()
        drinkCarbs = ""
        drinkWeight = ""
        carbsName = ""
        carbsValue = ""
        showResult = false
        catalogQuery = ""
    }

    /// Закрыть базу и сбросить ввод — безопасное состояние после долгого фона.
    private func closeSheetsAndResetToBase() {
        focus = nil
        showCatalogSheet = false
        resetMainSheetInputs()
    }

    /// Не держим Focus на индексе, которого уже нет в массиве items (краш SwiftUI после фона).
    private func sanitizeFocus() {
        guard let f = focus else { return }
        switch f {
        case .sugar:
            return
        case .draftCarbs, .draftWeight, .draftName, .drinkCarbs, .drinkWeight, .carbsName, .carbsValue, .dishSearch, .dishWeight:
            return
        case .pCarbs(let i), .pWeight(let i):
            if i >= 0 && i < items.count { return }
        }
        focus = nil
    }

    // MARK: - Calc

    private struct CalcRes {
        let food: Double
        let corr: Double
        let total: Double

        var foodText: String { "\(fmt2(food)) ед." }
        var corrText: String { "\(fmt2(corr)) ед." }
        var totalText: String { "\(fmt2(total)) ед." }

        private func fmt2(_ v: Double) -> String { String(format: "%.2f", v) }
    }

    private func paramsForMeal() -> (target: Double, isf: Double, k: Double) {
        if let p = vm.profile {
            let target = p.target_glucose_mmol
            let isf = max(0.01, p.insulin_sensitivity_factor)

            let k: Double
            switch meal {
            case .breakfast: k = p.ic_ratio_breakfast
            case .lunch:     k = p.ic_ratio_lunch
            case .dinner:    k = p.ic_ratio_dinner
            }

            return (target, isf, max(0.01, k))
        } else {
            // фоллбек пока профиль не загружен
            return (6.5, 3.0, 1.0)
        }
    }
    // MARK: - Products math

    private func carbsFor(_ it: ProductItem) -> Double {
        // Прямой ввод суммы — углеводы лежат прямо в carbsPer100
        if it.isDirectCarbs {
            return (parseNumber(it.carbsPer100) ?? 0).rounded(toPlaces: 2)
        }
        guard let per100 = parseNumber(it.carbsPer100), per100 >= 0,
              let w = parseNumber(it.weight), w >= 0 else { return 0 }
        return (per100 / 100.0 * w).rounded(toPlaces: 2)
    }

    // Выбор продукта из базы — заполняет inline-карточку продукта (draft)
    private func addItem(from product: FoodProduct) {
        draftName = product.name_ru
        draftIsFromCatalog = true
        draftCarbsPer100 = fmt(product.carbsPer100)
        draftCategory = product.foodCategory  // иконка из категории продукта
        showCatalogSheet = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            focus = .draftWeight
        }
    }

    // MARK: - Catalog loading

    private func loadCatalog() {
        guard let url = Bundle.main.url(forResource: "products", withExtension: "json") else {
            catalog = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            catalog = try JSONDecoder().decode([FoodProduct].self, from: data)
        } catch {
            catalog = []
        }
    }

    // MARK: - Catalog Sheet UI

    private var filteredCatalog: [FoodProduct] {
        let q = catalogQuery.trimmed.lowercased()
        guard !q.isEmpty else { return catalog }
        return catalog.filter {
            $0.name_ru.lowercased().contains(q) || $0.id.lowercased().contains(q)
        }
    }

    private var catalogSheet: some View {
        let darkText = Color(red: 0.204, green: 0.071, blue: 0.0)         // #341200
        let peach22  = Color(red: 1.0,   green: 0.706, blue: 0.549).opacity(0.22) // #FFB48C @ 22%

        return ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Заголовок
                VStack(spacing: 4) {
                    Text("База продуктов")
                        .font(.gilroy(20, weight: .semibold))
                        .foregroundStyle(darkText)
                    Text("Источник базы - НМИЦ эндокринологии")
                        .font(.gilroy(10, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.25)) // #00000040
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 50)

                // Поиск
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(darkText.opacity(0.55))
                        .font(.system(size: ds(14), weight: .medium))
                    TextField(
                        "",
                        text: $catalogQuery,
                        prompt: Text("Поиск")
                            .foregroundColor(darkText.opacity(0.35))
                            .font(.gilroy(14, weight: .medium))
                    )
                    .font(.gilroy(14, weight: .medium))
                    .foregroundStyle(darkText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }
                .padding(.horizontal, 18)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(peach22)
                )
                .padding(.horizontal, 20)
                .padding(.top, 24)

                // Лейбл "Углеводы" справа
                HStack {
                    Spacer()
                    Text("Углеводы")
                        .font(.gilroy(13, weight: .medium))
                        .foregroundStyle(darkText.opacity(0.5))
                }
                .padding(.horizontal, 36)
                .padding(.top, 14)
                .padding(.bottom, 4)

                // Список продуктов
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredCatalog, id: \.id) { p in
                            Button {
                                addItem(from: p)
                            } label: {
                                HStack {
                                    Text(p.name_ru)
                                        .font(.gilroy(20, weight: .semibold))
                                        .foregroundStyle(darkText)
                                        .lineLimit(1)

                                    Spacer()

                                    Text("\(fmt(p.carbsPer100)) г. / 100\(p.unit)")
                                        .font(.gilroy(20, weight: .medium))
                                        .foregroundStyle(darkText.opacity(0.4))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 22)
                                .frame(height: 65)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .fill(Color.white)
                                        .shadow(color: Color.black.opacity(0.25), radius: 4.8, x: 5, y: 3)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
        }
        .onAppear { catalogQuery = "" }
    }

    // MARK: - Utils

    private enum Meal: Hashable, CaseIterable {
        case breakfast, lunch, dinner
        var title: String {
            switch self {
            case .breakfast: return "Завтрак"
            case .lunch: return "Обед"
            case .dinner: return "Ужин"
            }
        }
        // SF Symbol для пикера внутри шита
        var icon: String {
            switch self {
            case .breakfast: return "sunrise.fill"
            case .lunch: return "sun.max.fill"
            case .dinner: return "moon.stars.fill"
            }
        }
        // SVG-ассет для пикера на главном экране
        var asset: String {
            switch self {
            case .breakfast: return "morning"
            case .lunch:     return "lunch"
            case .dinner:    return "evening"
            }
        }
        // Размер иконки по дизайну
        var iconSize: CGSize {
            switch self {
            case .breakfast: return CGSize(width: 21, height: 11)
            case .lunch:     return CGSize(width: 21, height: 21)
            case .dinner:    return CGSize(width: 20, height: 20)
            }
        }
    }

    private static func guessMealByTime() -> Meal {
        let h = Calendar.current.component(.hour, from: Date())
        if h >= 4 && h < 12 { return .breakfast }
        if h >= 12 && h < 17 { return .lunch }
        return .dinner
    }

    private func parseNumber(_ text: String) -> Double? {
        let t = text.trimmed
        if t.isEmpty { return nil }
        let normalized = t.replacingOccurrences(of: ",", with: ".")
        let v = Double(normalized)
        return (v?.isFinite == true) ? v : nil
    }

    private func fmt2(_ v: Double) -> String {
        String(format: "%.2f", v)
    }

    private func fmt(_ v: Double) -> String {
        let s = String(format: "%.2f", v)
        var out = s
        while out.contains(".") && (out.hasSuffix("0") || out.hasSuffix(".")) {
            if out.hasSuffix("0") { out.removeLast() }
            else if out.hasSuffix(".") { out.removeLast() }
        }
        return out
    }
}

// MARK: - ViewModel

@MainActor
final class CalculatorVM: ObservableObject {

    @Published var profile: ProfileDTO? = nil
    @Published var isLoading = false

    private let api = ProfileAPI()
    private let tokenService = TokenService()
    private let storage = ProfileStorage()

    private var lastLoadAt: Date? = nil

    func loadProfile(force: Bool = false) async {

        if !force, let t = lastLoadAt, Date().timeIntervalSince(t) < 10 {
            return
        }

        isLoading = true
        defer { isLoading = false }

        // ✅ Проверяем наличие userId
        guard let userId = tokenService.userId else {
            profile = nil
            return
        }

        // ✅ 1. Сначала грузим кэш
        if let cached = storage.load(userId: userId) {
            profile = cached
            lastLoadAt = Date() // 🔥 Важно: обновляем время загрузки
        }

        do {
            // ✅ 2. Пытаемся обновить с сервера
            let fresh = try await api.getProfile()
            profile = fresh
            storage.save(fresh, userId: userId)
            lastLoadAt = Date()

        } catch {
            // Сеть или 401 после неудачного refresh — `APIClient` уже пытался обновить токен; оставляем кэш.
        }
    }
}

// MARK: - Мигающий курсор (эффект набора текста)

private struct BlinkingCaret: View {
    var height: CGFloat
    var color: Color
    @State private var visible = true

    var body: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(color)
            .frame(width: 2, height: height)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}

// MARK: - PreferenceKey высоты страниц свайпера

private struct PageHeightKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] = [:]
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Swipe-to-delete строка чека

private struct SwipeToDeleteRow<Content: View>: View {
    let onTap: () -> Void
    let onDelete: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var offset: CGFloat = 0
    private let threshold: CGFloat = 90
    private let maxReveal: CGFloat = 96

    var body: some View {
        ZStack(alignment: .trailing) {
            // Красная зона удаления — её ширина равна величине свайпа,
            // граница «открывается» вслед за пальцем (эффект переворота страницы).
            // Контент прозрачный → показывает настоящий фон карточки (точное совпадение),
            // а красный виден только в открывшейся справа полосе.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.red.opacity(0.92))
                .overlay(alignment: .trailing) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: ds(18), weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.trailing, 26)
                        .opacity(-offset > 36 ? 1 : 0)
                }
                .frame(width: min(maxReveal, max(0, -offset)))

            content()
                .contentShape(Rectangle()) // тап ловится по всей строке, фон не трогаем
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 14)
                        .onChanged { value in
                            if value.translation.width < 0 {
                                offset = max(value.translation.width, -maxReveal)
                            }
                        }
                        .onEnded { value in
                            if value.translation.width < -threshold {
                                onDelete()   // удаление + сворачивание делает родитель (transition)
                            } else {
                                withAnimation(.easeOut(duration: 0.22)) { offset = 0 }
                            }
                        }
                )
                .onTapGesture { onTap() }
        }
    }
}

// MARK: - Helpers

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

private extension Double {
    func rounded(toPlaces p: Int) -> Double {
        let d = pow(10.0, Double(p))
        return (self * d).rounded() / d
    }
}

private extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private extension CalculatorView.ProductItem {
    var isEffectivelyEmpty: Bool {
        name.trimmed.isEmpty &&
        carbsPer100.trimmed.isEmpty &&
        weight.trimmed.isEmpty
    }
}
