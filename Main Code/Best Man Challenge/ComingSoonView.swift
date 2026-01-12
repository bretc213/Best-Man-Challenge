import SwiftUI

struct ComingSoonView: View {
    let title: String

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Text(title)
                .font(.title2)
                .bold()

            Text("Coming Soon")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        ComingSoonView(title: "Vegas Odds")
    }
}
