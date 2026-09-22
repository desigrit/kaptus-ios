import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var subRipText: UTType { UTType(filenameExtension: "srt") ?? .plainText }
}
enum Brand {
    static let yellow = Color(red: 1, green: 200 / 255, blue: 87 / 255)
    static let ink = Color(red: 23 / 255, green: 24 / 255, blue: 20 / 255)
    static let link = Color("LinkTint")
}
struct PrimaryAction: View {
    @Environment(\.dynamicTypeSize) private var dynamicType
    let title: LocalizedStringKey
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Group {
                if dynamicType.isAccessibilitySize { Text(title) }
                else { Label(title, systemImage: symbol) }
            }
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 28)
                .padding(.vertical, 12).padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Brand.ink)
        .background(Brand.yellow, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
struct SecondaryAction: View {
    @Environment(\.dynamicTypeSize) private var dynamicType
    let title: LocalizedStringKey
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Group {
                if dynamicType.isAccessibilitySize { Text(title) }
                else { Label(title, systemImage: symbol) }
            }
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
        }.buttonStyle(.bordered)
    }
}
struct Wordbird: View {
    var size: CGFloat = 72
    var body: some View {
        Image("Wordbird").resizable().scaledToFit().frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
struct EmptyState: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let symbol: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(.secondary).accessibilityHidden(true)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(28)
    }
}
