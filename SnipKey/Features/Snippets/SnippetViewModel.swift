//
//  SnippetViewModel.swift
//  SnipKey
//
//  Created by Jonathan Taveras Vargas on 3/27/24.
//

import SwiftData
import SwiftUI

@Observable
class SnippetViewModel {
    var modelContext: ModelContext? = nil

    func fetchSnippets() -> [SnippetItem]? {
        let fetchDescriptor = FetchDescriptor<SnippetItem>()

        do {
            return try modelContext?.fetch(fetchDescriptor)
        } catch {
            print("FAILED TO FETCH SNIPPETS: \(error)")
            return []
        }
    }

    func setupInitialTags() {
        let fetchDescriptor = FetchDescriptor<SnipTag>()

        do {
            let tags = try modelContext?.fetch(fetchDescriptor)
            let containsWorkTag = tags?.contains { $0.name == "Work" } ?? false
            let containsPersonalTag = tags?.contains { $0.name == "Personal" } ?? false
            let containsNoneTag = tags?.contains { $0.name == "None" } ?? false

            if !(containsWorkTag && containsPersonalTag && containsNoneTag) {
                setupTags()
            }
        } catch {
            print("FAILED TO SETUP INITIAL TAGS MODEL: \(error)")
        }
    }

    func setupTags() {
        let newNoneTag = SnipTag(name: "None", imageTag: "tag.fill")
        let newPersonalTag = SnipTag(name: "Personal", imageTag: "person.fill")
        let newWorkTag = SnipTag(name: "Work", imageTag: "suitcase.fill")
        modelContext?.insert(newPersonalTag)
        modelContext?.insert(newWorkTag)
        modelContext?.insert(newNoneTag)
        saveContext()
    }

    func deleteItems(offsets: IndexSet, snippets: [SnippetItem]) {
        withAnimation {
            for index in offsets {
                modelContext?.delete(snippets[index])
            }
        }
        saveContext()
    }

    func deleteItem(snippet: SnippetItem) {
        withAnimation {
            modelContext?.delete(snippet)
        }
        saveContext()
    }

    func deleteSelectedItems(snippets: [SnippetItem]) {
        withAnimation {
            for snippet in snippets {
                modelContext?.delete(snippet)
            }
        }
        saveContext()
    }

    func deleteTag(offsets: IndexSet, tags: [SnipTag]) {
        for index in offsets {
            modelContext?.delete(tags[index])
        }
        saveContext()
    }

    func createTag(name: String, iconName: String) -> SnipTag {
        let newTag = SnipTag(name: name, imageTag: iconName)
        modelContext?.insert(newTag)
        saveContext()
        return newTag
    }

    func createData(type: FileType, data: Data, fileFormatType: String) -> SnippetFile {
        let newFile = SnippetFile(type: type, formatType: fileFormatType, fileData: data)
        modelContext?.insert(newFile)
        saveContext()
        return newFile
    }

    func trackSnippetUsage(snippet: SnippetItem) {
        snippet.lastTimeUsed = Date.now
        snippet.usedCount += 1
        saveContext()
    }

    func toggleFavorite(snippet: SnippetItem) {
        snippet.isFavorite.toggle()
        snippet.updatedDate = Date.now
        saveContext()
    }

    func updateSnippet(
        _ snippet: SnippetItem,
        title: String,
        content: String,
        type: SnipType? = nil
    ) {
        snippet.title = title
        snippet.content = content
        if let type {
            snippet.type = type
        }
        snippet.updatedDate = Date.now
        saveContext()
    }

    func findTagCreated(tagName: String) -> SnipTag? {
        let fetchDescriptor = FetchDescriptor<SnipTag>()

        do {
            let tags = try modelContext?.fetch(fetchDescriptor)
            return tags?.first { $0.name == tagName }
        } catch {
            print("FAILED TO FIND TAG: \(error)")
            return nil
        }
    }

    func findFileCreated(fileId: String) -> SnippetFile? {
        let fetchDescriptor = FetchDescriptor<SnippetFile>()

        do {
            let snippetFiles = try modelContext?.fetch(fetchDescriptor)
            return snippetFiles?.first { $0.id == fileId }
        } catch {
            print("FAILED TO FIND FILE CREATED: \(error)")
            return nil
        }
    }

    func deleteFile(fileId: String) {
        if let snippetFile = findFileCreated(fileId: fileId) {
            modelContext?.delete(snippetFile)
            saveContext()
        }
    }

    @discardableResult
    func createSnippet(
        _ title: String,
        content: String,
        type: SnipType?,
        isSecure: Bool
    ) -> SnippetItem {
        let newItem = SnippetItem(
            title: title,
            content: content,
            type: type ?? .txt,
            isSecure: isSecure
        )
        modelContext?.insert(newItem)
        saveContext()
        return newItem
    }

    private func saveContext() {
        do {
            try modelContext?.save()
        } catch {
            print("FAILED TO SAVE SNIPPET CONTEXT: \(error)")
        }
    }
}
