// Pages/DishCreateView.swift
import SwiftUI
import UIKit
import Combine

/// Полноэкранное создание/редактирование блюда.
/// Ингредиенты работают как чек на калькуляторе: заполняешь форму → «Добавить» → улетает в чек,
/// свайп влево — удалить, тап — загрузить в форму для редактирования.
struct DishCreateView: View {

    let screenTitle: String
    let initial: DishDTO?
    let onSave: (_ title: String, _ isPublic: Bool, _ ingredients: [IngredientDTO]) async -> Bool

    @Environment(\.dismiss) private var dismiss

    private let darkText = Color(red: 0.204, green: 0.071, blue: 0.0)            // #341200
    private let peachLight = Color(red: 1.0, green: 0.706, blue: 0.549).opacity(0.22) // #FFB48C 22%
    private let orange = Color(red: 1.0, green: 0.592, blue: 0.0)               // #FF9700

    // Имя блюда + флаг публичности
    @State private var dishName = ""
    @State private var isPublic = false

    // Чек ингредиентов
    struct IngredientItem: Identifiable, Hashable {
        let id = UUID()
        var name: String
        var weight: String
        var carbsPer100: String
    }
    @State private var ingredients: [IngredientItem] = []

    // Черновик ингредиента
    @State private var draftName = ""
    @State private var draftWeight = ""
    @State private var draftCarbs = ""
    @State private var editingId: UUID? = nil

    @State private var isSaving = false
    @State private var errorText: String?

    // Анимация-«печатная машинка» для placeholder названия блюда
    private let nameExamples = ["Блин с бананом", "Овсянка", "Паста с сыром", "Салат", "Творог"]
    @State private var phText = ""
    @State private var phIndex = 0
    @State private var phCharCount = 0
    @State private var phDeleting = false
    @State private var phHold = 0
    private let phTimer = Timer.publish(every: 0.14, on: .main, in: .common).autoconnect()

    @FocusState private var focus: Field?
    enum Field: Hashable { case dishName, draftName, draftWeight, draftCarbs }

    var body: some View {
        ZStack {
            background

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    headerBlock
                        .padding(.horizontal, 30)
                    dishIcon
                        .padding(.bottom, -90)   // белая карточка заезжает под иконку
                        .zIndex(1)
                    whiteCard
                }
                .ipadReadable()
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .contentShape(Rectangle())
        .onTapGesture { focus = nil }
        .onAppear(perform: loadInitial)
    }

    // MARK: - Background

    private var background: some View {
        Image("profile-background")
            .resizable()
            .scaledToFill()
            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
            .clipped()
            .overlay(Color.white.opacity(0.34))
            .ignoresSafeArea()
    }

    // MARK: - Header (название блюда)

    private var headerBlock: some View {
        VStack(spacing: 4) {
            Text(screenTitle)
                .font(.gilroy(15, weight: .semibold))
                .foregroundStyle(darkText.opacity(0.4))

            ZStack {
                if dishName.isEmpty && focus != .dishName {
                    HStack(spacing: 2) {
                        Text(phText)
                            .font(.gilroy(32, weight: .semibold))
                            .foregroundStyle(darkText.opacity(0.4))
                        BlinkingCaret(height: 34, color: darkText.opacity(0.4))
                    }
                }
                TextField("", text: $dishName)
                    .font(.gilroy(32, weight: .semibold))
                    .foregroundStyle(darkText.opacity(0.4))
                    .tint(darkText)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .dishName)
            }
            .onReceive(phTimer) { _ in advancePlaceholder() }
        }
        .padding(.top, 80)
    }

    /// «Печатная машинка»: печатает пример названия, держит паузу, стирает, следующий.
    private func advancePlaceholder() {
        guard dishName.isEmpty, focus != .dishName else { return }
        if phHold > 0 { phHold -= 1; return }

        let example = nameExamples[phIndex]
        if !phDeleting {
            if phCharCount < example.count {
                phCharCount += 1
            } else {
                phHold = 8
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

    private var dishIcon: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: ds(226), height: ds(226))
            Image("dish-cover")
                .resizable()
                .scaledToFit()
                .frame(width: ds(175.73), height: ds(139))
        }
        .padding(.top, 16)
    }

    // MARK: - Белая карточка (форма + чек)

    private var whiteCard: some View {
        VStack(spacing: 0) {
            ingredientForm
            addButton
            checkBlock
        }
        .padding(.horizontal, 30)
        .padding(.top, 100)   // место под выступающую иконку
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous)
                .fill(Color.white)
                .padding(.bottom, -1000)
        )
    }

    // MARK: - Ingredient form (черновик)

    private var ingredientForm: some View {
        VStack(spacing: 18) {
            HStack {
                Text("Ингредиенты")
                    .font(.gilroy(20, weight: .semibold))
                    .foregroundStyle(darkText)
                Spacer()
            }

            // Название ингредиента (с подчёркиванием)
            ZStack(alignment: .leading) {
                if draftName.isEmpty {
                    Text("Банан")
                        .font(.gilroy(16, weight: .semibold))
                        .foregroundStyle(darkText.opacity(0.4))
                }
                TextField("", text: $draftName)
                    .font(.gilroy(16, weight: .semibold))
                    .foregroundStyle(darkText.opacity(0.4))
                    .tint(darkText)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .draftName)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle().fill(darkText.opacity(0.18)).frame(height: 1).offset(y: 8)
            }
            .padding(.bottom, 8)

            // Вес + Уг/100 — белые карточки
            valueCard(title: "Вес, г.", text: $draftWeight, focusKey: .draftWeight)
            valueCard(title: "Уг/100 г.", text: $draftCarbs, focusKey: .draftCarbs)
        }
    }

    private func valueCard(title: String, text: Binding<String>, focusKey: Field) -> some View {
        HStack {
            Text(title)
                .font(.gilroy(20, weight: .semibold))
                .foregroundStyle(darkText)
            Spacer()
            ZStack(alignment: .trailing) {
                if text.wrappedValue.isEmpty {
                    Text("0")
                        .font(.gilroy(32, weight: .semibold))
                        .foregroundStyle(darkText.opacity(0.4))
                }
                TextField("", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.gilroy(32, weight: .semibold))
                    .foregroundStyle(darkText.opacity(0.4))
                    .tint(darkText)
                    .focused($focus, equals: focusKey)
                    .onChange(of: text.wrappedValue) { _, v in
                        let cleaned = v.replacingOccurrences(of: ",", with: ".").filter { "0123456789.".contains($0) }
                        if cleaned != v { text.wrappedValue = cleaned }
                    }
                    .frame(maxWidth: 120)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 53)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.12), radius: 5, x: 2, y: 3)
        )
    }

    private var addButton: some View {
        Button { commitDraft() } label: {
            Text(editingId != nil ? "Сохранить изменения" : "Добавить")
                .font(.gilroy(16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 47)
                .background(
                    RoundedRectangle(cornerRadius: 23.5, style: .continuous)
                        .fill(canAddDraft ? orange : orange.opacity(0.45))
                )
        }
        .buttonStyle(.plain)
        .disabled(!canAddDraft)
        .padding(.top, 18)
        .padding(.bottom, 22)
    }

    // MARK: - Чек

    private var checkBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Чек")
                .font(.gilroy(20, weight: .semibold))
                .foregroundStyle(darkText)
                .padding(.bottom, 16)

            if ingredients.isEmpty {
                Text("Добавьте ингредиенты")
                    .font(.gilroy(13, weight: .medium))
                    .foregroundStyle(darkText.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            } else {
                ForEach(Array(ingredients.enumerated()), id: \.element.id) { index, ing in
                    SwipeDeleteRow(
                        onTap: { startEditing(ing) },
                        onDelete: { deleteIngredient(ing) }
                    ) {
                        ingredientRow(ing)
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))

                    if index < ingredients.count - 1 {
                        Rectangle().fill(darkText.opacity(0.12)).frame(height: 1).padding(.vertical, 10)
                    }
                }
            }

            // Итого — углеводы на 100г блюда
            HStack {
                Text("Итого:")
                    .font(.gilroy(20, weight: .semibold))
                    .foregroundStyle(darkText)
                Spacer()
                Text("\(fmt(totalCarbsPer100)) угл/100 г.")
                    .font(.gilroy(20, weight: .semibold))
                    .foregroundStyle(darkText)
            }
            .padding(.top, 22)

            if let errorText {
                Text(errorText)
                    .font(.gilroy(12, weight: .medium))
                    .foregroundStyle(.red)
                    .padding(.top, 10)
            }

            saveButton
                .padding(.top, 18)

            cancelButton
                .padding(.top, 12)

            Spacer().frame(height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 25, topTrailingRadius: 25, style: .continuous)
                .fill(peachLight)
                .padding(.bottom, -1000)
        )
    }

    private func ingredientRow(_ ing: IngredientItem) -> some View {
        HStack(alignment: .center) {
            Text(ing.name)
                .font(.gilroy(13, weight: .medium))
                .foregroundStyle(darkText)
                .lineLimit(1)
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 0) {
                Text("Углеводы: \(fmt(carbsFor(ing))) г.")
                Text("Вес: \(ing.weight.isEmpty ? "0" : ing.weight) г.")
            }
            .font(.gilroy(12, weight: .medium))
            .foregroundStyle(Color.black.opacity(0.25))
            .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 33)
        .contentShape(Rectangle())
    }

    private var saveButton: some View {
        Button { Task { await save() } } label: {
            Text("Сохранить блюдо")
                .font(.gilroy(16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 47)
                .background(
                    RoundedRectangle(cornerRadius: 23.5, style: .continuous).fill(orange)
                )
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .padding(.horizontal, 8)
    }

    private var cancelButton: some View {
        Button { dismiss() } label: {
            Text("Отмена")
                .font(.gilroy(16, weight: .semibold))
                .foregroundStyle(darkText.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 47)
                .background(
                    RoundedRectangle(cornerRadius: 23.5, style: .continuous).fill(darkText.opacity(0.10))
                )
        }
        .padding(.horizontal, 8)
        .buttonStyle(.plain)
    }

    // MARK: - Logic

    private var canAddDraft: Bool {
        !draftName.trimmed.isEmpty &&
        (Double(draftWeight.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0 &&
        (Double(draftCarbs.replacingOccurrences(of: ",", with: ".")) ?? 0) >= 0 &&
        !draftCarbs.trimmed.isEmpty
    }

    private func carbsFor(_ ing: IngredientItem) -> Double {
        guard let w = Double(ing.weight.replacingOccurrences(of: ",", with: ".")),
              let c = Double(ing.carbsPer100.replacingOccurrences(of: ",", with: ".")) else { return 0 }
        return (w * c / 100.0 * 100).rounded() / 100
    }

    private var totalCarbsPer100: Double {
        let totalW = ingredients.reduce(0.0) { $0 + (Double($1.weight.replacingOccurrences(of: ",", with: ".")) ?? 0) }
        let totalC = ingredients.reduce(0.0) { $0 + carbsFor($1) }
        guard totalW > 0 else { return 0 }
        return (totalC / totalW * 100 * 100).rounded() / 100
    }

    private func commitDraft() {
        if let id = editingId, let idx = ingredients.firstIndex(where: { $0.id == id }) {
            ingredients[idx].name = draftName.trimmed
            ingredients[idx].weight = draftWeight
            ingredients[idx].carbsPer100 = draftCarbs
        } else {
            ingredients.append(.init(name: draftName.trimmed, weight: draftWeight, carbsPer100: draftCarbs))
        }
        clearDraft()
    }

    private func clearDraft() {
        draftName = ""
        draftWeight = ""
        draftCarbs = ""
        editingId = nil
        focus = nil
    }

    private func startEditing(_ ing: IngredientItem) {
        draftName = ing.name
        draftWeight = ing.weight
        draftCarbs = ing.carbsPer100
        editingId = ing.id
    }

    private func deleteIngredient(_ ing: IngredientItem) {
        withAnimation(.easeOut(duration: 0.2)) {
            ingredients.removeAll { $0.id == ing.id }
        }
        if editingId == ing.id { clearDraft() }
    }

    private func loadInitial() {
        guard let initial else { return }
        dishName = initial.title
        isPublic = initial.is_public
        ingredients = initial.ingredients.map {
            .init(name: $0.name, weight: fmt($0.weight_g), carbsPer100: fmt($0.carbs_per_100g))
        }
    }

    private func save() async {
        focus = nil
        errorText = nil

        let cleanTitle = dishName.trimmed
        guard !cleanTitle.isEmpty else { errorText = "Введите название блюда"; return }
        guard !ingredients.isEmpty else { errorText = "Добавьте хотя бы один ингредиент"; return }

        var dto: [IngredientDTO] = []
        for ing in ingredients {
            guard let w = Double(ing.weight.replacingOccurrences(of: ",", with: ".")), w > 0,
                  let c = Double(ing.carbsPer100.replacingOccurrences(of: ",", with: ".")), c >= 0 else {
                errorText = "Проверьте значения ингредиентов"
                return
            }
            dto.append(.init(name: ing.name.trimmed, weight_g: w, carbs_per_100g: c))
        }

        isSaving = true
        defer { isSaving = false }
        let ok = await onSave(cleanTitle, isPublic, dto)
        if ok { dismiss() }
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

// MARK: - Swipe-to-delete строка (локальная)

private struct SwipeDeleteRow<Content: View>: View {
    let onTap: () -> Void
    let onDelete: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var offset: CGFloat = 0
    private let threshold: CGFloat = 90
    private let maxReveal: CGFloat = 96

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.red.opacity(0.92))
                .overlay(alignment: .trailing) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.trailing, 20)
                        .opacity(-offset > 30 ? 1 : 0)
                }
                .frame(width: min(maxReveal, max(0, -offset)))

            content()
                .contentShape(Rectangle())
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 14)
                        .onChanged { v in if v.translation.width < 0 { offset = max(v.translation.width, -maxReveal) } }
                        .onEnded { v in
                            if v.translation.width < -threshold { onDelete() }
                            else { withAnimation(.easeOut(duration: 0.2)) { offset = 0 } }
                        }
                )
                .onTapGesture { onTap() }
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

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
