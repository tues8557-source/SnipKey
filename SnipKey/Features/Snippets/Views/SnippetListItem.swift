//
//  SnippetListItem.swift
//  SnipKey
//
//  Created by Jonathan Taveras Vargas on 3/27/24.
//

import SwiftUI

struct SnippetImage: View {
    let type: SnipType

    var body: some View {
        Image(systemName: type.snipTypeImage)
            .foregroundStyle(Color.label)
    }
}

struct SnippetListItem: View {
    let item: SnippetItem

    var body: some View {
        HStack(spacing: 10) {
            SnippetImage(type: item.type ?? .txt)
                .frame(width: 35, height: 35)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title ?? "")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(Color.label)
                    .font(.custom("IBMPlexMono-Medium", size: 14))
                    .fontWeight(.semibold)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text("#\(item.customTag?.name ?? "None")")
                        .foregroundColor(Color.secondaryLabel)
                        .font(.subheadline)
                    TagColorIndicator(colorHex: item.customTag?.colorHex, size: 8)
                }
            }

            if item.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favorite")
            }

            if item.isSecure {
                Image(systemName: "lock")
                    .foregroundStyle(Color.label.gradient)
            }
        }
    }
}

struct SnippetListItemMinimal: View {
    let item: SnippetItem
    var isDark: Bool = false

    private var previewText: String? {
        if item.isSecure { return "••••••" }

        switch item.type ?? .txt {
        case .txt, .url:
            guard let content = item.content else { return nil }
            let head = String(content.prefix(120))
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)
            return head.isEmpty ? nil : head
        case .image, .file:
            return (item.type ?? .txt).displayText
        }
    }

    var body: some View {
        let shadow = KeyStyle.keyShadow(isDark: isDark)

        return HStack(spacing: 12) {
            Image(systemName: item.type?.snipTypeImage ?? "doc.text")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(KeyStyle.secondaryGlyph(isDark: isDark))
                .frame(width: 32, height: 32)
                .background(Circle().fill(KeyStyle.iconWell(isDark: isDark)))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(item.title ?? "")
                        .font(.custom("IBMPlexMono-Medium", size: 14))
                        .foregroundStyle(KeyStyle.glyph(isDark: isDark))
                        .lineLimit(1)

                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.yellow)
                    }
                }

                Text(previewText ?? " ")
                    .font(.custom("IBMPlexMono-Regular", size: 11))
                    .foregroundStyle(KeyStyle.tertiaryGlyph(isDark: isDark))
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 4) {
                    if let tagName = item.customTag?.name {
                        Text("#\(tagName)")
                            .font(.custom("IBMPlexMono-Regular", size: 11))
                            .foregroundStyle(KeyStyle.secondaryGlyph(isDark: isDark))
                        TagColorIndicator(colorHex: item.customTag?.colorHex, size: 6)
                    }

                    if item.isSecure {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(KeyStyle.secondaryGlyph(isDark: isDark))
                    }

                    if item.customTag?.name == nil && !item.isSecure {
                        Text(" ")
                            .font(.custom("IBMPlexMono-Regular", size: 11))
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: KeyStyle.cornerRadius, style: .continuous)
                .fill(KeyStyle.keyBackground(isDark: isDark))
                .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
        )
    }
}

#Preview {
    VStack {
        SnippetListItemMinimal(item: .dummy2)
        SnippetListItemMinimal(item: .dummy)
    }
    .padding()
}
