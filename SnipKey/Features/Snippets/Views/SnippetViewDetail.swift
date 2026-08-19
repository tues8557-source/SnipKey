//
//  SnippetViewDetail.swift
//  SnipKey
//
//  Created by Jonathan Taveras Vargas on 3/27/24.
//

import AlertToast
import SwiftData
import SwiftUI

struct SnippetViewDetail: View {
    @Environment(\.modelContext) private var modelContext

    private let deviceBiometrics = DeviceBiometrics()

    @State private var snippet: SnippetItem
    @State private var isUnlocked: Bool
    @State private var isEditFormVisible = false
    @State private var showToast = false
    @State private var toastText = "Copied!"

    init(item: SnippetItem) {
        _snippet = State(initialValue: item)
        _isUnlocked = State(initialValue: !item.isSecure)
    }

    var body: some View {
        Group {
            if snippet.isSecure && !isUnlocked {
                lockedView
            } else {
                snippetForm
            }
        }
        .navigationTitle(snippet.title ?? "Snippet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: toggleFavorite) {
                    Image(systemName: snippet.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(snippet.isFavorite ? .yellow : .primary)
                }
                .accessibilityLabel(snippet.isFavorite ? "Remove from Favorites" : "Add to Favorites")

                Button("Edit") {
                    isEditFormVisible = true
                }
                .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $isEditFormVisible) {
            NavigationStack {
                SnippetForm(snippet: snippet, isFormVisible: $isEditFormVisible)
            }
            .presentationBackground(Color.clear)
        }
        .toast(isPresenting: $showToast) {
            AlertToast(
                displayMode: .banner(.pop),
                type: .systemImage("doc.on.clipboard", .label),
                title: toastText,
                style: .style(
                    backgroundColor: Color.tertiarySystemBackground,
                    titleFont: .custom("IBMPlexMono-Medium", size: 14)
                )
            )
        }
    }

    private var lockedView: some View {
        ContentUnavailableView {
            Label("Snippet Locked", systemImage: "lock.fill")
        } description: {
            Text("Authenticate to view or edit this snippet.")
        } actions: {
            Button("Unlock") {
                unlockSnippet()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var snippetForm: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(snippet.title ?? "")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if snippet.isFavorite {
                            Label("Favorite", systemImage: "star.fill")
                                .labelStyle(.iconOnly)
                                .foregroundStyle(.yellow)
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: (snippet.type ?? .txt).snipTypeImage)
                        Text((snippet.type ?? .txt).displayText)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Section("Content") {
                SnippetContentViewDisplay(snippet: snippet)

                HStack {
                    if snippet.type == .url {
                        Button {
                            openURLContent()
                        } label: {
                            Label("Open URL", systemImage: "arrow.up.forward.app")
                        }
                    }

                    Spacer()

                    Button {
                        copyToClipboard()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }

            Section("Details") {
                if let tagName = snippet.customTag?.name, !tagName.isEmpty {
                    LabeledContent("Tag", value: tagName)
                }

                LabeledContent("Used", value: "\(snippet.usedCount) times")

                if let updatedDate = snippet.updatedDate {
                    LabeledContent("Updated", value: updatedDate.formatted(date: .abbreviated, time: .shortened))
                } else if let creationDate = snippet.creationDate {
                    LabeledContent("Created", value: creationDate.formatted(date: .abbreviated, time: .shortened))
                }

                if snippet.isSecure {
                    Label("Protected with device authentication", systemImage: "lock.shield.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func toggleFavorite() {
        snippet.isFavorite.toggle()
        snippet.updatedDate = Date.now
        try? modelContext.save()
    }

    private func unlockSnippet() {
        deviceBiometrics.authenticate(
            successHandler: {
                isUnlocked = true
            },
            unSuccessHandler: { _ in
                isUnlocked = false
            }
        )
    }

    private func openURLContent() {
        guard
            let content = snippet.content,
            !content.isEmpty,
            content.isValidURL(),
            let url = URL(string: content.getValidURLString())
        else { return }

        UIApplication.shared.open(url)
    }

    private func copyToClipboard() {
        let result: SnippetCopyResult

        switch snippet.type {
        case .file, .image:
            result = SnippetPasteboard.copyFile(
                data: snippet.file?.fileData,
                mimeType: snippet.file?.fileFormatType,
                hasFullAccess: true
            )
        default:
            result = SnippetPasteboard.copyText(snippet.content ?? "", hasFullAccess: true)
        }

        switch result {
        case .success:
            toastText = "Copied!"
        case .missingData:
            toastText = "File data missing."
        case .tooLarge:
            toastText = "File is over \(SnippetPasteboard.maxFileSizeDescription)."
        case .unsupportedType:
            toastText = "Unsupported file type."
        case .noFullAccess:
            toastText = "Copy failed."
        }

        showToast = true
    }
}

#Preview {
    NavigationStack {
        SnippetViewDetail(item: .dummy2)
    }
}
