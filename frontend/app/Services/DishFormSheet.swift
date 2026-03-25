// Services/DishFormSheet.swift
import SwiftUI

struct DishFormSheet: View {

    let title: String
    let initial: DishDTO?
    let onSave: (_ title: String, _ isPublic: Bool, _ ingredients: [IngredientDTO]) async -> Bool

    // UI palette
    private let sheetPrimary = Color.white
    private let sheetSecondary = Color.white.opacity(0.72)
    private let sheetAccent = Color.purple.opacity(0.92)
    private let sheetFieldBg = Color.white.opacity(0.12)
    private let sheetStroke = Color.white.opacity(0.18)
    private let placeholder = Color.white.opacity(0.4)

    @State private var dishTitle: String = ""
    @State private var isPublic: Bool = false
    @State private var errorText: String?

    @State private var ingredients: [IngredientForm] = [IngredientForm()]

    @State private var isSaving = false

    @FocusState private var focus: FocusField?
    enum FocusField: Hashable {
        case title
        case ingName(UUID)
        case ingWeight(UUID)
        case ingCarbs(UUID)
    }

    struct IngredientForm: Identifiable, Hashable {
        let id = UUID()
        var name: String = ""
        var weight: String = ""
        var carbsPer100: String = ""
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                background
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 32) {
                        headerBlock
                        titleCard
                        ingredientsCard
                        visibilityCard
                        errorBlock
                        saveButton
                    }
                    .padding(.horizontal, 34)
                    .padding(.top, 28)
                    .padding(.bottom, 48)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture { dismissKeyboard() }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(sheetAccent)
        .onAppear {
            loadInitialData()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                focus = .title
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.95),
                    Color.purple.opacity(0.85),
                    Color.black.opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.40)],
                center: .center,
                startRadius: 120,
                endRadius: 520
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 30)
                .offset(x: -130, y: -240)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 340, height: 340)
                .blur(radius: 38)
                .offset(x: 150, y: -140)

            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 430, height: 430)
                .blur(radius: 42)
                .offset(x: 40, y: 300)
        }
    }

    // MARK: - Header

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(sheetPrimary)

            Text(initial == nil ? "Собери рецепт из ингредиентов" : "Обнови состав и видимость блюда")
                .font(.headline)
                .fontWeight(.regular)
                .foregroundStyle(sheetSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Cards

    private var titleCard: some View {
        darkCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Название")
                    .font(.headline)
                    .foregroundStyle(sheetPrimary)

                TextField("", text: $dishTitle, prompt: Text("Например: Овсянка с бананом").foregroundColor(placeholder))
                    .foregroundStyle(sheetPrimary)
                    .tint(sheetPrimary)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .title)
                    .padding(.vertical, 14)
                    .overlay(
                        Rectangle().fill(sheetStroke).frame(height: 1.5),
                        alignment: .bottom
                    )
            }
        }
    }

    private var ingredientsCard: some View {
        darkCard {
            VStack(alignment: .leading, spacing: 28) {
                HStack {
                    Text("Ингредиенты")
                        .font(.headline)
                        .foregroundStyle(sheetPrimary)

                    Spacer()

                    Button {
                        addIngredient()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(sheetPrimary)
                            .frame(width: 44, height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(sheetStroke, lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 24) {
                    ForEach($ingredients) { $ing in
                        ingredientRow($ing)
                    }
                }

                Divider()
                    .background(sheetStroke)
                    .padding(.vertical, 8)

                HStack {
                    Text("Всего углеводов")
                        .font(.headline)
                        .foregroundStyle(sheetSecondary)
                    Spacer()
                    Text("\(fmtNum(totalCarbs)) г")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(sheetPrimary)
                }
            }
        }
    }

    private func ingredientRow(_ ing: Binding<IngredientForm>) -> some View {
        let id = ing.wrappedValue.id

        return VStack(spacing: 18) {
            // Строка с названием и кнопкой удаления
            HStack(spacing: 14) {
                TextField("", text: ing.name, prompt: Text("Название").foregroundColor(placeholder))
                    .foregroundStyle(sheetPrimary)
                    .tint(sheetPrimary)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .ingName(id))
                    .padding(.vertical, 12)
                    .overlay(
                        Rectangle().fill(sheetStroke).frame(height: 1.5),
                        alignment: .bottom
                    )

                Button {
                    removeIngredient(id)
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.95))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .disabled(ingredients.count <= 1)
                .opacity(ingredients.count <= 1 ? 0.3 : 1)
            }
            
            // Строка с числами - переделана на Grid для лучшего распределения
            Grid(horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    // Заголовки
                    Text("Вес, г")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(sheetSecondary)
                        .gridColumnAlignment(.leading)
                    
                    Text("Угл/100г")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(sheetSecondary)
                        .gridColumnAlignment(.leading)
                    
                    Text("Углеводы")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(sheetSecondary)
                        .gridColumnAlignment(.trailing)
                }
                
                GridRow {
                    // Поле Вес
                    TextField("", text: ing.weight, prompt: Text("200").foregroundColor(placeholder))
                        .keyboardType(.decimalPad)
                        .foregroundStyle(sheetPrimary)
                        .tint(sheetPrimary)
                        .focused($focus, equals: .ingWeight(id))
                        .onChange(of: ing.wrappedValue.weight) { _, v in
                            let cleaned = sanitizeNumber(v)
                            if cleaned != v { ing.weight.wrappedValue = cleaned }
                        }
                        .padding(.vertical, 10)
                        .overlay(
                            Rectangle().fill(sheetStroke).frame(height: 1.5),
                            alignment: .bottom
                        )
                    
                    // Поле Угл/100г
                    TextField("", text: ing.carbsPer100, prompt: Text("10").foregroundColor(placeholder))
                        .keyboardType(.decimalPad)
                        .foregroundStyle(sheetPrimary)
                        .tint(sheetPrimary)
                        .focused($focus, equals: .ingCarbs(id))
                        .onChange(of: ing.wrappedValue.carbsPer100) { _, v in
                            let cleaned = sanitizeNumber(v)
                            if cleaned != v { ing.carbsPer100.wrappedValue = cleaned }
                        }
                        .padding(.vertical, 10)
                        .overlay(
                            Rectangle().fill(sheetStroke).frame(height: 1.5),
                            alignment: .bottom
                        )
                    
                    // Результат
                    Text("\(fmtNum(carbsFor(ing.wrappedValue))) г")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(sheetPrimary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.01))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1.5)
        )
    }

    private var visibilityCard: some View {
        darkCard {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Публичное блюдо")
                        .font(.headline)
                        .foregroundStyle(sheetPrimary)
                    Text("Появится в общем доступе")
                        .font(.subheadline)
                        .foregroundStyle(sheetSecondary)
                }

                Spacer()

                Toggle("", isOn: $isPublic)
                    .labelsHidden()
                    .tint(sheetAccent)
                    .scaleEffect(1.0)
            }
        }
    }

    @ViewBuilder
    private var errorBlock: some View {
        if let errorText, !errorText.isEmpty {
            HStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 18))
                
                Text(errorText)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.red.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.red.opacity(0.35), lineWidth: 1.5)
            )
        }
    }

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            HStack(spacing: 12) {
                if isSaving {
                    ProgressView()
                        .tint(.purple)
                        .scaleEffect(1.0)
                }
                Text(isSaving ? "Сохранение..." : "Сохранить")
                    .font(.system(size: 20, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(isValid ? Color.white : Color.white.opacity(0.3))
            )
            .foregroundStyle(isValid ? .purple.opacity(0.9) : .gray.opacity(0.7))
        }
        .buttonStyle(.plain)
        .disabled(isSaving || !isValid)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
    
    private var isValid: Bool {
        let title = dishTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        
        for ing in ingredients {
            let name = ing.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return false }
            guard let w = parseNumber(ing.weight), w > 0 else { return false }
            guard let c = parseNumber(ing.carbsPer100), c >= 0 else { return false }
        }
        return true
    }

    // MARK: - Reusable Card Style

    private func darkCard(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            content()
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.black.opacity(0.35))
                .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
        )
    }

    // MARK: - Logic

    private var totalCarbs: Double {
        ingredients.reduce(0) { $0 + carbsFor($1) }.rounded2()
    }

    private func carbsFor(_ ing: IngredientForm) -> Double {
        guard let w = parseNumber(ing.weight), let c = parseNumber(ing.carbsPer100) else { return 0 }
        if w < 0 || c < 0 { return 0 }
        return (w * c / 100.0).rounded2()
    }

    private func addIngredient() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            ingredients.append(IngredientForm())
        }
    }

    private func removeIngredient(_ id: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            ingredients.removeAll { $0.id == id }
            if ingredients.isEmpty {
                ingredients = [IngredientForm()]
            }
        }
    }

    private func loadInitialData() {
        if let initial {
            dishTitle = initial.title
            isPublic = initial.is_public
            ingredients = initial.ingredients.map {
                IngredientForm(
                    name: $0.name,
                    weight: fmtNum($0.weight_g),
                    carbsPer100: fmtNum($0.carbs_per_100g)
                )
            }
            if ingredients.isEmpty { ingredients = [IngredientForm()] }
        }
    }

    private func save() async {
        dismissKeyboard()
        errorText = nil

        let cleanTitle = dishTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanTitle.isEmpty {
            errorText = "Введите название блюда"
            focus = .title
            return
        }

        var dto: [IngredientDTO] = []
        for ing in ingredients {
            let name = ing.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                errorText = "У ингредиента нет названия"
                return
            }
            guard let w = parseNumber(ing.weight), w > 0 else {
                errorText = "Вес ингредиента должен быть > 0"
                return
            }
            guard let c = parseNumber(ing.carbsPer100), c >= 0 else {
                errorText = "Углеводы/100г должны быть ≥ 0"
                return
            }
            dto.append(.init(name: name, weight_g: w, carbs_per_100g: c))
        }

        isSaving = true
        defer { isSaving = false }

        let ok = await onSave(cleanTitle, isPublic, dto)
        if ok {
            dismiss()
        }
    }

    private func dismissKeyboard() {
        focus = nil
        UIApplication.shared.endEditing()
    }

    private func sanitizeNumber(_ text: String) -> String {
        let v = text
            .replacingOccurrences(of: ",", with: ".")
            .filter { "0123456789.".contains($0) }

        var out = ""
        var dotUsed = false
        for ch in v {
            if ch == "." {
                if dotUsed { continue }
                dotUsed = true
            }
            out.append(ch)
        }
        return out
    }

    private func parseNumber(_ text: String) -> Double? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        let normalized = t.replacingOccurrences(of: ",", with: ".")
        let v = Double(normalized)
        return (v?.isFinite == true) ? v : nil
    }

    private func fmtNum(_ v: Double) -> String {
        let s = String(format: "%.2f", v)
        var out = s
        while out.contains(".") && (out.hasSuffix("0") || out.hasSuffix(".")) {
            if out.hasSuffix("0") { out.removeLast() }
            else if out.hasSuffix(".") { out.removeLast() }
        }
        return out
    }
}

private extension Double {
    func rounded2() -> Double {
        let d = pow(10.0, 2.0)
        return (self * d).rounded() / d
    }
}

private extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
