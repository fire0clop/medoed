// Services/DishDetailSheet.swift
import SwiftUI

struct DishDetailSheet: View {

    let dish: DishDTO
    let onEdit: () -> Void
    let onDelete: () -> Void

    // UI palette
    private let sheetPrimary = Color.white
    private let sheetSecondary = Color.white.opacity(0.72)
    private let sheetStroke = Color.white.opacity(0.14)
    private let sheetAccent = Color.purple.opacity(0.92)
    private let sheetPlaceholder = Color.white.opacity(0.40)

    @Environment(\.dismiss) private var dismiss
    @State private var pendingEdit = false

    // Profile (как в калькуляторе)
    @StateObject private var vm = CalculatorVM()

    // Время суток (как в калькуляторе)
    private enum Meal: Hashable, CaseIterable {
        case breakfast, lunch, dinner

        var title: String {
            switch self {
            case .breakfast: return "Завтрак"
            case .lunch: return "Обед"
            case .dinner: return "Ужин"
            }
        }

        var icon: String {
            switch self {
            case .breakfast: return "sunrise.fill"
            case .lunch: return "sun.max.fill"
            case .dinner: return "moon.stars.fill"
            }
        }
    }

    @State private var meal: Meal = DishDetailSheet.guessMealByTime()

    // Меняем только текущий сахар
    @State private var sugarText: String = ""

    @FocusState private var focus: Focus?
    private enum Focus: Hashable { case sugar }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        headerBlock
                        metricsBlock        // ✅ порядок: header -> параметры
                        ingredientsBlock    // ✅ затем ингредиенты
                        insulinBlock        // ✅ затем инсулин
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .contentShape(Rectangle())
                .onTapGesture { dismissKeyboard() }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Редактировать") {
                            pendingEdit = true
                            dismiss()
                        }

                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(12)
                            .contentShape(Rectangle())
                    }
                }
            }
        }
        .task { await vm.loadProfile() }
        .onChange(of: vm.profile?.target_glucose_mmol) { _, newValue in
            if sugarText.trimmed.isEmpty, let t = newValue {
                sugarText = fmt(t)
            }
        }
        .onDisappear {
            if pendingEdit {
                pendingEdit = false
                onEdit()
            }
        }
        .tint(sheetAccent)
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
            HStack(alignment: .top) {
                Text(dish.title)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(sheetPrimary)

                Spacer()

                if dish.is_public {
                    Text("public")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.white))
                }
            }

            Text("Состав и пищевая ценность")
                .font(.subheadline)
                .foregroundStyle(sheetSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Metrics Card

    private var metricsBlock: some View {
        darkCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Параметры")
                    .font(.headline)
                    .foregroundStyle(sheetPrimary)

                HStack(spacing: 16) {
                    metricItem(title: "Углеводы", value: "\(fmt(dish.totalCarbs)) г")
                    metricItem(title: "Вес", value: "\(fmt(dish.totalWeight)) г")
                    metricItem(title: "Ингр.", value: "\(dish.ingredients.count)")
                }
            }
        }
    }

    private func metricItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(sheetSecondary)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(sheetPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Ingredients Card

    private var ingredientsBlock: some View {
        darkCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ингредиенты")
                    .font(.headline)
                    .foregroundStyle(sheetPrimary)

                if dish.ingredients.isEmpty {
                    Text("Нет ингредиентов")
                        .foregroundStyle(sheetSecondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 10) {
                        ForEach(dish.ingredients.indices, id: \.self) { index in
                            ingredientRow(dish.ingredients[index])
                        }
                    }
                }
            }
        }
    }

    private func ingredientRow(_ ing: IngredientDTO) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ing.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(sheetPrimary)

                Text("\(fmt(ing.weight_g)) г • \(fmt(ing.carbs_per_100g)) г/100г")
                    .font(.caption)
                    .foregroundStyle(sheetSecondary)
            }

            Spacer(minLength: 8)

            Text("\(fmt(ing.carbsTotal)) г")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(sheetPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.12)))
                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(sheetStroke, lineWidth: 0.5)
        )
    }

    // MARK: - Insulin Block

    private var insulinBlock: some View {
        let r = insulinRes()
        let target = vm.profile?.target_glucose_mmol ?? 6.5

        return darkCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Расчёт по формуле")
                        .font(.headline)
                        .foregroundStyle(sheetPrimary)
                    Spacer()
                    Text(meal.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(sheetSecondary)
                }

                mealSegment  // ✅ активный сегмент белый

                sugarField(
                    title: "Сахар до еды",
                    placeholderText: fmt(target),
                    suffix: "ммоль/л",
                    text: $sugarText
                )

                Text("\(fmt2(r.total)) ед.")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(sheetPrimary)

                HStack(spacing: 10) {
                    chip(title: "На еду", value: "\(fmt2(r.food)) ед.")
                    chip(title: "Коррекция", value: "\(fmt2(r.corr)) ед.")
                }

                Text("Информационный расчёт. Уточняйте у врача.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(sheetSecondary)

                HStack(spacing: 10) {
                    chip(title: "Цель", value: "\(fmt(target)) ммоль/л")
                    chip(title: "Углеводы", value: "\(fmt(dish.totalCarbs)) г")
                }
            }
        }
    }

    private var mealSegment: some View {
        HStack(spacing: 10) {
            ForEach(Meal.allCases, id: \.self) { m in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { meal = m }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: m.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(m.title)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(meal == m ? .black : sheetPrimary)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(meal == m ? .white : Color.white.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sugarField(
        title: String,
        placeholderText: String,
        suffix: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(sheetSecondary)
                Spacer()
                Button("Цель") {
                    text.wrappedValue = placeholderText
                    focus = .sugar
                }
                .disabled(vm.profile == nil)
                .foregroundStyle(vm.profile == nil ? sheetSecondary : sheetAccent)
            }

            HStack(spacing: 10) {
                TextField(
                    "",
                    text: text,
                    prompt: Text(placeholderText).foregroundColor(sheetPlaceholder)
                )
                .keyboardType(.decimalPad)
                .foregroundStyle(sheetPrimary)
                .tint(sheetPrimary)
                .focused($focus, equals: .sugar)
                .onChange(of: text.wrappedValue) { _, v in
                    let cleaned = sanitizeNumber(v)
                    if cleaned != v { text.wrappedValue = cleaned }
                }

                Text(suffix)
                    .foregroundStyle(sheetSecondary)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.vertical, 6)
            .overlay(alignment: .bottom) {
                Rectangle().fill(sheetSecondary.opacity(0.22)).frame(height: 1)
            }
        }
    }

    private func chip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(sheetSecondary)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(sheetPrimary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Reusable Card Style

    private func darkCard(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.22))
            )
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 12)
    }

    // MARK: - Insulin logic (как в калькуляторе)

    private struct InsulinRes {
        let food: Double
        let corr: Double
        let total: Double
    }

    private func insulinRes() -> InsulinRes {
        let carbs = max(0, dish.totalCarbs)

        guard let sugar = parseNumber(sugarText) else {
            return .init(food: 0, corr: 0, total: 0)
        }

        let (target, isf, k) = paramsForMeal()

        // ✅ ТВОЯ формула (не меняю):
        // Доза = ((carbs / 11) * k) + ((sugar - target) / isf)
        let food = ((carbs / 11.0) * k).rounded(toPlaces: 2)
        let corr = ((sugar - target) / isf).rounded(toPlaces: 2)
        let total = (food + corr).rounded(toPlaces: 2)

        return .init(food: food, corr: corr, total: total)
    }

    private func paramsForMeal() -> (target: Double, isf: Double, k: Double) {
        if let p = vm.profile {
            let target = p.target_glucose_mmol
            let isf = max(0.01, p.insulin_sensitivity_factor)

            // ✅ K берём из профиля (твое требование)
            let k: Double
            switch meal {
            case .breakfast: k = p.ic_ratio_breakfast
            case .lunch:     k = p.ic_ratio_lunch
            case .dinner:    k = p.ic_ratio_dinner
            }

            return (target, isf, max(0.01, k))
        } else {
            // фоллбек пока профиль не загрузился
            return (6.5, 3.0, 1.0)
        }
    }


    private static func guessMealByTime() -> Meal {
        let h = Calendar.current.component(.hour, from: Date())
        if h >= 4 && h < 12 { return .breakfast }
        if h >= 12 && h < 17 { return .lunch }
        return .dinner
    }

    // MARK: - Helpers

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
