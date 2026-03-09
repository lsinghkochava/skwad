import SwiftUI

struct HeaderTitleView: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundColor(Theme.secondaryText)
    }
}
