import Observation

@MainActor
@Observable
final class ExhibitionListViewModel {
    enum VisitFilter: String, CaseIterable, Identifiable {
        case all
        case unvisited
        case visited

        var id: Self { self }

        var label: String {
            switch self {
            case .all: return "すべて"
            case .unvisited: return "未訪問"
            case .visited: return "訪問済み"
            }
        }
    }

    var visitFilter: VisitFilter = .unvisited
    var statusFilter: Exhibition.RunStatus?
    var searchText = ""

    func filteredExhibitions(from exhibitions: [Exhibition]) -> [Exhibition] {
        exhibitions.filter { exhibition in
            matchesVisitFilter(exhibition) &&
                matchesStatusFilter(exhibition) &&
                matchesSearchText(exhibition)
        }
    }

    func toggleVisited(_ exhibition: Exhibition) {
        exhibition.visited.toggle()
        exhibition.visitedAt = exhibition.visited ? .now : nil
    }

    private func matchesVisitFilter(_ exhibition: Exhibition) -> Bool {
        switch visitFilter {
        case .all: return true
        case .unvisited: return !exhibition.visited
        case .visited: return exhibition.visited
        }
    }

    private func matchesStatusFilter(_ exhibition: Exhibition) -> Bool {
        guard let statusFilter else { return true }
        return exhibition.runStatus == statusFilter
    }

    private func matchesSearchText(_ exhibition: Exhibition) -> Bool {
        guard !searchText.isEmpty else { return true }
        return exhibition.title.localizedCaseInsensitiveContains(searchText) ||
            exhibition.venue.localizedCaseInsensitiveContains(searchText)
    }
}
