import SwiftUI

struct MealRow: View {
    let meal: MealSummary
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: meal.thumbnailURL.map(Self.previewURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.secondary.opacity(0.15)
            }
            .frame(width: 60, height: 60)
            .clipShape(.rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name)
                    .font(.headline)
                    .lineLimit(2)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// TheMealDB serves small thumbnails by appending "/preview" to the image URL.
    private static func previewURL(_ url: URL) -> URL {
        url.appending(path: "preview")
    }
}
