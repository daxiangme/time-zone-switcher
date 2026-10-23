import SwiftUI
import TimeZoneCore

/// Replaces the clock list while adding: every zone is listed up front like the macOS
/// "closest city" picker, and typing narrows it. ↑/↓ move, Return adds, Esc clears or goes back.
struct AddTimeZoneView: View {
    static let height: CGFloat = 460

    @ObservedObject var viewModel: TimeZoneBarViewModel
    let onClose: () -> Void

    @State private var query = ""
    @State private var selection: String?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        let sections = self.sections
        let selectable = selectableItems(in: sections)

        VStack(spacing: 0) {
            searchBar(selectable: selectable)
            Divider()
            if sections.isEmpty {
                noResults
            } else {
                resultList(sections)
            }
        }
        .frame(height: Self.height)
        .onAppear {
            selection = selectableItems(in: self.sections).first?.id
            DispatchQueue.main.async { isSearchFocused = true }
        }
        .onChange(of: query) {
            selection = selectableItems(in: self.sections).first?.id
        }
    }

    // MARK: - Search bar

    private func searchBar(selectable: [Item]) -> some View {
        HStack(spacing: 6) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(viewModel.localized("Back"))

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(viewModel.localized("Search cities, countries or time zones"), text: $query)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit { addSelection() }
                    .onExitCommand {
                        if query.isEmpty {
                            onClose()
                        } else {
                            query = ""
                        }
                    }
                    .onKeyPress(.downArrow) {
                        moveSelection(by: 1, in: selectable)
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        moveSelection(by: -1, in: selectable)
                        return .handled
                    }
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    // MARK: - Results

    private func resultList(_ sections: [Section]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(sections) { section in
                        SwiftUI.Section {
                            ForEach(section.items) { item in
                                PlaceRow(
                                    place: item.place,
                                    preview: viewModel.previewRow(for: item.place.identifier),
                                    isSaved: viewModel.isSaved(item.place.identifier),
                                    isSelected: selection == item.id,
                                    localized: viewModel.localized
                                ) {
                                    add(item.place)
                                }
                                .id(item.id)
                                .onHover { hovering in
                                    if hovering, !viewModel.isSaved(item.place.identifier) {
                                        selection = item.id
                                    }
                                }
                            }
                        } header: {
                            if let title = section.title {
                                Text(title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.top, 8)
                                    .padding(.bottom, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.regularMaterial)
                            }
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
            .onChange(of: selection) { _, id in
                guard let id else { return }
                proxy.scrollTo(id)
            }
        }
    }

    private var noResults: some View {
        VStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.secondary)
            Text(viewModel.localized("No matching time zones"))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data

    private struct Item: Identifiable {
        let id: String
        let place: TimeZonePlace
    }

    private struct Section: Identifiable {
        let id: String
        let title: String?
        let items: [Item]
    }

    /// No query: common cities, then everything grouped by area. With a query: one ranked list.
    private var sections: [Section] {
        let index = viewModel.placeIndex
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else {
            let items = index.search(trimmed).map { Item(id: "result/\($0.identifier)", place: $0) }
            return items.isEmpty ? [] : [Section(id: "results", title: nil, items: items)]
        }

        var sections = [Section(
            id: "suggested",
            title: viewModel.localized("Suggested"),
            items: index.suggestions.map { Item(id: "suggested/\($0.identifier)", place: $0) }
        )]
        let grouped = Dictionary(grouping: index.places, by: \.area)
        for area in TimeZoneArea.allCases {
            guard let places = grouped[area], !places.isEmpty else { continue }
            sections.append(Section(
                id: area.rawValue,
                title: viewModel.localized("Area \(area.rawValue)"),
                items: places.map { Item(id: "\(area.rawValue)/\($0.identifier)", place: $0) }
            ))
        }
        return sections
    }

    private func selectableItems(in sections: [Section]) -> [Item] {
        sections.flatMap(\.items).filter { !viewModel.isSaved($0.place.identifier) }
    }

    private func moveSelection(by step: Int, in selectable: [Item]) {
        guard !selectable.isEmpty else { return }
        let current = selectable.firstIndex { $0.id == selection } ?? (step > 0 ? -1 : selectable.count)
        let next = min(max(current + step, 0), selectable.count - 1)
        selection = selectable[next].id
    }

    private func addSelection() {
        guard let selection,
              let item = sections.flatMap(\.items).first(where: { $0.id == selection })
        else {
            return
        }
        add(item.place)
    }

    private func add(_ place: TimeZonePlace) {
        guard !viewModel.isSaved(place.identifier) else { return }
        viewModel.add(place.identifier)
        if viewModel.errorMessage == nil {
            onClose()
        }
    }
}

private struct PlaceRow: View {
    let place: TimeZonePlace
    let preview: ClockRowModel?
    let isSaved: Bool
    let isSelected: Bool
    let localized: (String) -> String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(place.city)
                            .font(.body)
                            .lineLimit(1)
                        if let country = place.country, country != place.city {
                            Text(country)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Text("\(place.zoneName) · \(place.identifier)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)

                if isSaved {
                    Label(localized("Already added"), systemImage: "checkmark")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let preview {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(preview.timeText)
                            .font(.callout.monospacedDigit().weight(.semibold))
                        Text(preview.relativeText(localized: localized))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 44)
            .background(
                isSelected ? Color.accentColor.opacity(0.18) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .contentShape(Rectangle())
            .opacity(isSaved ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isSaved)
    }
}
