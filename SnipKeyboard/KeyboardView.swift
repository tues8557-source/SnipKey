//
//  KeyboardView.swift
//  SnipKeyboard
//
//  Clipboard-first keyboard surface for the personal SnipKey fork.
//

import SwiftData
import SwiftUI
import UIKit

struct KeyboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SnippetItem.creationDate, order: .reverse) private var snippets: [SnippetItem]

    var insertText: (String) -> Void = { _ in }
    var advanceToNextInputMode: () -> Void = {}
    var deleteBackward: () -> Void = {}
    var moveCursor: (Int) -> Void = { _ in }
    var insertReturn: () -> Void = {}

    @State private var favoritesOnly = false
    @State private var statusMessage: String?

    private var visibleSnippets: [SnippetItem] {
        snippets
            .filter { snippet in
                guard !snippet.isSecure else { return false }
                guard snippet.type == .txt || snippet.type == .url else { return false }
                guard let content = snippet.content else { return false }
                guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
                return !favoritesOnly || snippet.isFavorite
            }
            .sorted { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite {
                    return lhs.isFavorite && !rhs.isFavorite
                }

                let lhsDate = lhs.lastTimeUsed ?? lhs.updatedDate ?? lhs.creationDate ?? .distantPast
                let rhsDate = rhs.lastTimeUsed ?? rhs.updatedDate ?? rhs.creationDate ?? .distantPast
                return lhsDate > rhsDate
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()

            if visibleSnippets.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 7) {
                        ForEach(visibleSnippets, id: \.persistentModelID) { snippet in
                            snippetRow(snippet)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
            }

            Divider()
            editingBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Button {
                favoritesOnly.toggle()
            } label: {
                Label(
                    favoritesOnly ? "Favorites" : "Recent",
                    systemImage: favoritesOnly ? "star.fill" : "clock"
                )
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(favoritesOnly ? .yellow : .primary)
            }
            .buttonStyle(.bordered)

            Spacer(minLength: 4)

            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .transition(.opacity)
            }

            Button {
                saveCurrentClipboard()
            } label: {
                Label("Save Clipboard", systemImage: "doc.on.clipboard.fill")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 8)

            Image(systemName: favoritesOnly ? "star" : "clipboard")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)

            Text(favoritesOnly ? "No favorite snippets" : "No saved text yet")
                .font(.system(size: 14, weight: .semibold))

            Text(favoritesOnly
                 ? "Tap the star beside a snippet to pin it here."
                 : "Copy text, then tap Save Clipboard above.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func snippetRow(_ snippet: SnippetItem) -> some View {
        HStack(spacing: 8) {
            Button {
                insert(snippet)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: snippet.type == .url ? "link" : "text.alignleft")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text(snippet.title ?? suggestedTitle(for: snippet.content ?? ""))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    Text(preview(for: snippet.content ?? ""))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                toggleFavorite(snippet)
            } label: {
                Image(systemName: snippet.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(snippet.isFavorite ? .yellow : .secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(snippet.isFavorite ? "Remove from Favorites" : "Add to Favorites")
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var editingBar: some View {
        HStack(spacing: 6) {
            controlButton(systemImage: "globe", accessibility: "Next Keyboard") {
                advanceToNextInputMode()
            }

            controlButton(systemImage: "arrow.left", accessibility: "Move Cursor Left") {
                moveCursor(-1)
            }

            controlButton(systemImage: "arrow.right", accessibility: "Move Cursor Right") {
                moveCursor(1)
            }

            Button {
                insertText(" ")
            } label: {
                Image(systemName: "space")
                    .font(.system(size: 16, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Space")

            controlButton(systemImage: "delete.left", accessibility: "Delete") {
                deleteBackward()
            }

            controlButton(systemImage: "return", accessibility: "Return") {
                insertReturn()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
    }

    private func controlButton(
        systemImage: String,
        accessibility: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 38, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(accessibility)
    }

    private func insert(_ snippet: SnippetItem) {
        guard let content = snippet.content, !content.isEmpty else { return }

        insertText(content)
        snippet.lastTimeUsed = Date.now
        snippet.usedCount += 1
        try? modelContext.save()
        showStatus("Inserted")
    }

    private func toggleFavorite(_ snippet: SnippetItem) {
        snippet.isFavorite.toggle()
        snippet.updatedDate = Date.now
        try? modelContext.save()
        showStatus(snippet.isFavorite ? "Added to Favorites" : "Removed from Favorites")
    }

    private func saveCurrentClipboard() {
        guard let clipboardText = UIPasteboard.general.string else {
            showStatus("Clipboard has no text")
            return
        }

        let trimmed = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showStatus("Clipboard is empty")
            return
        }

        if let existing = snippets.first(where: { $0.content == clipboardText }) {
            existing.lastTimeUsed = Date.now
            existing.updatedDate = Date.now
            try? modelContext.save()
            showStatus("Already saved")
            return
        }

        let type: SnipType
        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            type = .url
        } else {
            type = .txt
        }

        let item = SnippetItem(
            title: suggestedTitle(for: clipboardText),
            content: clipboardText,
            type: type,
            isSecure: false
        )
        item.lastTimeUsed = Date.now
        modelContext.insert(item)
        try? modelContext.save()
        showStatus("Saved")
    }

    private func suggestedTitle(for text: String) -> String {
        let firstUsefulLine = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "Clipboard"

        let compact = firstUsefulLine.replacingOccurrences(of: "\t", with: " ")
        if compact.count <= 32 { return compact }
        return String(compact.prefix(32)) + "…"
    }

    private func preview(for text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func showStatus(_ message: String) {
        withAnimation(.easeInOut(duration: 0.15)) {
            statusMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard statusMessage == message else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                statusMessage = nil
            }
        }
    }
}

#Preview {
    KeyboardView()
        .frame(height: 340)
}
