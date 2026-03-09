import SwiftUI

enum DashboardSort: String, CaseIterable {
    case manual = "Workspace Order"
    case activity = "By Activity"

    func sorted(_ agents: [Agent]) -> [Agent] {
        switch self {
        case .manual:
            return agents
        case .activity:
            return agents.sorted { $0.lastStatusChange > $1.lastStatusChange }
        }
    }
}

struct DashboardSortPicker: View {
    @Binding var sort: DashboardSort

    var body: some View {
        Picker("", selection: $sort) {
            ForEach(DashboardSort.allCases, id: \.self) { sort in
                Text(sort.rawValue)
            }
        }
        .pickerStyle(.menu)
        .fixedSize()
    }
}
