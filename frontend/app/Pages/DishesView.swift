// Pages/DishesView.swift
import SwiftUI

struct DishesView: View {

    @StateObject private var vm = DishesViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var showCreate = false
    @State private var editDish: DishDTO? = nil
    @State private var expanded: Set<Int> = []
    @State private var deleteDish: DishDTO? = nil

    @FocusState private var isSearchFocused: Bool

    private let darkText = Color(red: 0.204, green: 0.071, blue: 0.0)        // #341200
    private let peachLight = Color(red: 1.0, green: 0.706, blue: 0.549).opacity(0.22) // #FFB48C 22%
    private let orange = Color(red: 1.0, green: 0.592, blue: 0.0)           // #FF9700

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                searchField
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                listContent
            }
            .ipadReadable()
        }
        .contentShape(Rectangle())
        .onTapGesture { isSearchFocused = false }
        .onAppear { vm.tab = .mine }
        .task { await vm.reload() }
        .fullScreenCover(isPresented: $showCreate) {
            DishCreateView(
                screenTitle: "Новое блюдо",
                initial: nil,
                onSave: { title, isPublic, ingredients in
                    let ok = await vm.create(title: title, isPublic: isPublic, ingredients: ingredients)
                    if ok { showCreate = false }
                    return ok
                }
            )
        }
        .fullScreenCover(item: $editDish) { dish in
            DishCreateView(
                screenTitle: "Редактирование",
                initial: dish,
                onSave: { title, isPublic, ingredients in
                    let ok = await vm.update(dishId: dish.id, title: title, isPublic: isPublic, ingredients: ingredients)
                    if ok { editDish = nil }
                    return ok
                }
            )
        }
        .confirmationDialog(
            "Удалить «\(deleteDish?.title ?? "")»?",
            isPresented: Binding(get: { deleteDish != nil }, set: { if !$0 { deleteDish = nil } }),
            titleVisibility: .visible
        ) {
            Button("Удалить", role: .destructive) {
                if let dish = deleteDish {
                    Task { await vm.delete(dishId: dish.id) }
                }
                deleteDish = nil
            }
            Button("Отмена", role: .cancel) { deleteDish = nil }
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Мои блюда")
                .font(.gilroy(20, weight: .semibold))
                .foregroundStyle(darkText)

            // Кнопка создания нового блюда — peach-квадрат с плюсиком
            HStack {
                Spacer()
                Button { showCreate = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(darkText.opacity(0.4))
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(peachLight)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 20)
        }
        .padding(.top, 38)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(darkText.opacity(0.4))

            TextField(
                "",
                text: $vm.query,
                prompt: Text("Поиск")
                    .font(.gilroy(11, weight: .medium))
                    .foregroundColor(darkText.opacity(0.4))
            )
            .font(.gilroy(11, weight: .medium))
            .foregroundStyle(darkText)
            .tint(darkText)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($isSearchFocused)

            if !vm.query.isEmpty {
                Button { vm.query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(darkText.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(peachLight)
        )
    }

    // MARK: - List

    @ViewBuilder
    private var listContent: some View {
        if vm.isLoading && vm.dishes.isEmpty {
            Spacer()
            ProgressView().tint(darkText)
            Spacer()
        } else if vm.visible.isEmpty {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 28))
                    .foregroundStyle(darkText.opacity(0.3))
                Text(vm.query.isEmpty ? "Пока нет блюд" : "Ничего не найдено")
                    .font(.gilroy(15, weight: .medium))
                    .foregroundStyle(darkText.opacity(0.4))
            }
            Spacer()
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 16) {
                    ForEach(vm.visible) { dish in
                        dishCard(dish)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Dish card

    private func dishCard(_ dish: DishDTO) -> some View {
        let isExpanded = expanded.contains(dish.id)

        // Белая шапка — полностью скруглённая карточка сверху;
        // peach-блок выезжает сзади-снизу (его верх прячется под шапкой).
        return VStack(spacing: 0) {
            // Шапка (белая): название + треугольник + «Ред.»
            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        if isExpanded { expanded.remove(dish.id) } else { expanded.insert(dish.id) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(dish.title)
                            .font(.gilroy(20, weight: .semibold))
                            .foregroundStyle(darkText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(darkText.opacity(0.4))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button { editDish = dish } label: {
                    Text("Ред.")
                        .font(.gilroy(12, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: ds(56), height: ds(28))
                        .background(Capsule().fill(orange))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .frame(height: ds(65))
            .frame(maxWidth: .infinity)
            .background(
                // тень — только на белом прямоугольнике, не на тексте/кнопках
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.25), radius: 4.8, x: 5, y: 3)
            )
            .zIndex(1)   // шапка всегда поверх peach-блока

            // Раскрывающийся peach-блок — выезжает из-под шапки вниз
            if isExpanded {
                HStack(spacing: 0) {
                    dishMetric(asset: "ric", iconSize: CGSize(width: 21.6, height: 21.6),
                               title: "Углеводы", value: "\(fmt(dish.totalCarbs)) г.")
                    Spacer(minLength: 12)
                    dishMetric(asset: "weight", iconSize: CGSize(width: 19.16, height: 22.63),
                               title: "Вес", value: "\(fmt(dish.totalWeight)) г.")
                    Spacer(minLength: 12)
                    dishMetric(asset: "ing", iconSize: CGSize(width: 21.6, height: 21.6),
                               title: "Ингр.", value: "\(dish.ingredients.count)")
                }
                .padding(.top, 18 + 22)   // 18 уходит под шапку + 22 видимый отступ
                .padding(.bottom, 22)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(peachLight)
                )
                .padding(.top, -18)        // прячем верхние 18pt под белую шапку
                .zIndex(0)
                .transition(.opacity)
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 1.0).onEnded { _ in deleteDish = dish }
        )
    }

    private func dishMetric(asset: String, iconSize: CGSize, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(asset)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(darkText)
                .frame(width: iconSize.width, height: iconSize.height)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.gilroy(14, weight: .semibold))
                    .foregroundStyle(darkText)                 // rgba(52,18,0,1)
                    .fixedSize(horizontal: true, vertical: false)
                Text(value)
                    .font(.gilroy(14, weight: .regular))
                    .foregroundStyle(darkText)                 // rgba(52,18,0,1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        // по размеру контента — промежутки распределяют Spacer-ы
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Helpers

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
