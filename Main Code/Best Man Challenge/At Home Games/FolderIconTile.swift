import SwiftUI

struct FolderIconTile: View {
    let title: String
    let systemImage: String?
    let assetImage: String?

    init(title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
        self.assetImage = nil
    }

    init(title: String, assetImage: String) {
        self.title = title
        self.assetImage = assetImage
        self.systemImage = nil
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 96)

                if let assetImage {
                    Image(assetImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.accent)
                }
            }

            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(12)
        .background(Color.black.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

#Preview {
    VStack(spacing: 20) {
        FolderIconTile(title: "CFB Bracket", assetImage: "CFPLogo")
        FolderIconTile(title: "Future Game", systemImage: "gamecontroller.fill")
    }
    .padding()
    .background(Color.background)
}
