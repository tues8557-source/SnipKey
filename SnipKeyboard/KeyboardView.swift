//
//  KeyboardView.swift
//  SnipKeyboard
//
//  Clipboard-first keyboard surface for the personal SnipKey fork.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

enum CursorMoveCommand {
    case character(Int)
    case word(Int)
    case line(Int)
}

enum DeleteCommand {
    case character(Int)
    case word
    case line
}

struct KeyboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SnippetItem.creationDate, order: .reverse) private var snippets: [SnippetItem]

    var insertText: (String) -> Void = { _ in }
    var advanceToNextInputMode: () -> Void = {}
    var deleteBackward: (DeleteCommand) -> Void = { _ in }
    var moveCursor: (CursorMoveCommand) -> Void = { _ in }
    var insertReturn: () -> Void = {}

    @State private var favoritesOnly = false
    @State private var statusMessage: String?
    @State private var pendingDeleteSnippetID: String?
    @State private var editingSnippet: SnippetItem?
    @State private var editTitle = ""
    @State private var editContent = ""

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

            if editingSnippet != nil {
                snippetEditor
            } else {
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
                .foregroundStyle(favoritesOnly ? Color.yellow : Color.primary)
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

            if editingSnippet != nil {
                Button {
                    cancelEditing()
                } label: {
                    Label("Done", systemImage: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    saveCurrentClipboard()
                } label: {
                    Label("Save Clipboard", systemImage: "doc.on.clipboard.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
            }
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
                    .foregroundStyle(snippet.isFavorite ? Color.yellow : Color.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(snippet.isFavorite ? "Remove from Favorites" : "Add to Favorites")

            Button {
                beginEditing(snippet)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                    .frame(width: 34, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit Snippet")

            Button {
                requestDelete(snippet)
            } label: {
                Image(systemName: pendingDeleteSnippetID == snippetIdentity(snippet) ? "trash.fill" : "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(pendingDeleteSnippetID == snippetIdentity(snippet) ? Color.red : Color.secondary)
                    .frame(width: 34, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete Snippet")
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private var editingBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                controlButton(systemImage: "globe", accessibility: "Next Keyboard") {
                    advanceToNextInputMode()
                }

                repeatButton(systemImage: "arrow.uturn.backward", accessibility: "Move to Line Start") {
                    moveCursor(.line(-1))
                }

                repeatButton(systemImage: "backward.end", accessibility: "Move Word Left") {
                    moveCursor(.word(-1))
                }

                repeatButton(systemImage: "arrow.left", accessibility: "Move Cursor Left") {
                    moveCursor(.character(-1))
                }

                repeatButton(systemImage: "arrow.right", accessibility: "Move Cursor Right") {
                    moveCursor(.character(1))
                }

                repeatButton(systemImage: "forward.end", accessibility: "Move Word Right") {
                    moveCursor(.word(1))
                }

                repeatButton(systemImage: "arrow.uturn.forward", accessibility: "Move to Line End") {
                    moveCursor(.line(1))
                }
            }

            HStack(spacing: 6) {
                repeatButton(systemImage: "delete.left", accessibility: "Delete") {
                    deleteBackward(.character(1))
                }

                Button {
                    deleteBackward(.word)
                } label: {
                    Label("Word", systemImage: "delete.backward")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 78, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Delete Word")

                Button {
                    deleteBackward(.line)
                } label: {
                    Label("Line", systemImage: "text.badge.minus")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 78, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Delete Line")

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

                controlButton(systemImage: "return", accessibility: "Return") {
                    insertReturn()
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
    }

    private var snippetEditor: some View {
        VStack(spacing: 8) {
            TextField("Title", text: $editTitle)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, weight: .semibold))

            TextEditor(text: $editContent)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(minHeight: 80)

            HStack(spacing: 8) {
                Button {
                    loadClipboardIntoEditor()
                } label: {
                    Label("Paste", systemImage: "doc.on.clipboard")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    deleteEditingSnippet()
                } label: {
                    Label("Delete", systemImage: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    saveEditedSnippet()
                } label: {
                    Label("Save", systemImage: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(8)
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

    private func repeatButton(
        systemImage: String,
        accessibility: String,
        action: @escaping () -> Void
    ) -> some View {
        RepeatingIconButton(
            systemImage: systemImage,
            accessibility: accessibility,
            action: action
        )
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

    private func beginEditing(_ snippet: SnippetItem) {
        editingSnippet = snippet
        editTitle = snippet.title ?? suggestedTitle(for: snippet.content ?? "")
        editContent = snippet.content ?? ""
        pendingDeleteSnippetID = nil
    }

    private func cancelEditing() {
        editingSnippet = nil
        editTitle = ""
        editContent = ""
    }

    private func saveEditedSnippet() {
        guard let editingSnippet else { return }
        let trimmedContent = editContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            showStatus("Content is empty")
            return
        }

        let trimmedTitle = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        editingSnippet.title = trimmedTitle.isEmpty ? suggestedTitle(for: trimmedContent) : trimmedTitle
        editingSnippet.content = editContent
        editingSnippet.type = detectedType(for: trimmedContent)
        editingSnippet.updatedDate = Date.now
        try? modelContext.save()
        cancelEditing()
        showStatus("Updated")
    }

    private func loadClipboardIntoEditor() {
        guard let clipboardText = UIPasteboard.general.string,
              !clipboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            showStatus("Clipboard has no text")
            return
        }

        editContent = clipboardText
        if editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            editTitle = suggestedTitle(for: clipboardText)
        }
        showStatus("Loaded Clipboard")
    }

    private func deleteEditingSnippet() {
        guard let editingSnippet else { return }
        modelContext.delete(editingSnippet)
        try? modelContext.save()
        cancelEditing()
        showStatus("Deleted")
    }

    private func requestDelete(_ snippet: SnippetItem) {
        let identity = snippetIdentity(snippet)
        guard pendingDeleteSnippetID == identity else {
            pendingDeleteSnippetID = identity
            showStatus("Tap trash again")
            return
        }

        modelContext.delete(snippet)
        try? modelContext.save()
        pendingDeleteSnippetID = nil
        showStatus("Deleted")
    }

    private func snippetIdentity(_ snippet: SnippetItem) -> String {
        snippet.id ?? String(describing: snippet.persistentModelID)
    }

    private func detectedType(for text: String) -> SnipType {
        if let url = URL(string: text),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return .url
        }
        return .txt
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

private struct RepeatingIconButton: View {
    let systemImage: String
    let accessibility: String
    let action: () -> Void

    @State private var repeatTimer: Timer?

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 38, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(accessibility)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    startRepeating()
                }
                .onEnded { _ in
                    stopRepeating()
                }
        )
        .onDisappear(perform: stopRepeating)
    }

    private func startRepeating() {
        guard repeatTimer == nil else { return }

        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { _ in
            action()
        }
    }

    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}
