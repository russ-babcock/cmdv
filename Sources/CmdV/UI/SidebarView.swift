import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarFilter

    var body: some View {
        List(SidebarFilter.allCases, selection: $selection) { filter in
            Label(filter.rawValue, systemImage: filter.systemImage)
                .tag(filter)
        }
        .listStyle(.sidebar)
    }
}
