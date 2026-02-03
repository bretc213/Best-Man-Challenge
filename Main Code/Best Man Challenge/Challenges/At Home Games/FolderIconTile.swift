import SwiftUI

struct FolderIconTile: View {
    let title: String
    let systemImage: String?
    let assetImage: String?

    // Normalization knobs (tweak later if you want)
    private let tileIconPlateSize: CGFloat = 88
    private let tileIconSize: CGFloat = 64

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

                // Subtle "plate" behind the logo so dark logos still read well
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: tileIconPlateSize, height: tileIconPlateSize)

                if let assetImage, UIImage(named: assetImage) != nil {
                    Image(assetImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: tileIconSize, height: tileIconSize)
                        .accessibilityLabel(Text(title))
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.accent)
                        .accessibilityLabel(Text(title))
                } else {
                    // Fallback if assetImage is missing/typo OR neither is provided
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color.accent.opacity(0.7))
                        .accessibilityLabel(Text(title))
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
        FolderIconTile(title: "Missing Asset", assetImage: "DOES_NOT_EXIST") // shows trophy fallback
    }
    .padding()
    .background(Color.background)
}
