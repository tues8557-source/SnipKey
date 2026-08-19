//
//  Item.swift
//  SnipKey
//
//  Created by Jonathan Taveras Vargas on 3/25/24.
//

import Foundation
import SwiftData

enum SnipType: String, CaseIterable, Identifiable, Codable {
    case txt
    case url
    case file
    case image

    var id: String { rawValue }

    var displayText: String {
        switch self {
        case .txt: return "Text"
        case .url: return "URL"
        case .file: return "PDF"
        case .image: return "Image"
        }
    }

    var snipTypeImage: String {
        switch self {
        case .txt: return "character.cursor.ibeam"
        case .url: return "link.circle"
        case .file: return "doc.circle.fill"
        case .image: return "photo.circle.fill"
        }
    }
}

enum FileType: String, CaseIterable, Identifiable, Codable {
    case document, image

    var id: String { rawValue }

    var displayText: String {
        switch self {
        case .document: return "Document"
        case .image: return "Image"
        }
    }

    var imageFile: String {
        switch self {
        case .document: return "doc.circle.fill"
        case .image: return "photo.artframe.circle.fill"
        }
    }
}

enum Tags: String, CaseIterable, Identifiable, Codable {
    case none, personal, work

    var id: String { rawValue }

    var displayText: String {
        switch self {
        case .none: return "None"
        case .personal: return "Personal"
        case .work: return "Work"
        }
    }

    var imageTag: String {
        switch self {
        case .none: return "tag.slash.fill"
        case .personal: return "person.text.rectangle.fill"
        case .work: return "case.fill"
        }
    }
}

// MARK: - Tag Color Palette

enum TagColor: String, CaseIterable, Identifiable {
    case red, orange, yellow, green, mint, teal, blue, indigo, purple, pink, brown, gray

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    var hexValue: String {
        switch self {
        case .red: return "#FF3B30"
        case .orange: return "#FF9500"
        case .yellow: return "#FFCC00"
        case .green: return "#34C759"
        case .mint: return "#00C7BE"
        case .teal: return "#30B0C7"
        case .blue: return "#007AFF"
        case .indigo: return "#5856D6"
        case .purple: return "#AF52DE"
        case .pink: return "#FF2D55"
        case .brown: return "#A2845E"
        case .gray: return "#8E8E93"
        }
    }

    static func from(hex: String?) -> TagColor? {
        guard let hex else { return nil }
        return allCases.first { $0.hexValue.lowercased() == hex.lowercased() }
    }
}

@Model
final class SnipTag {
    var creationDate: Date = Date.now
    var name: String?
    var imageTag: String?
    var id: String?
    var colorHex: String?

    @Relationship(inverse: \SnippetItem.customTag)
    var snippets: [SnippetItem]?

    init(name: String, imageTag: String, colorHex: String? = nil) {
        id = UUID().uuidString
        self.name = name
        self.imageTag = imageTag
        self.colorHex = colorHex
    }
}

@Model
final class SnippetFile {
    var id: String?
    var fileType: FileType?
    var fileFormatType: String?
    @Attribute(.externalStorage) var fileData: Data?

    @Relationship(inverse: \SnippetItem.file)
    var snippet: [SnippetItem]?

    init(type: FileType = .image, formatType: String, fileData: Data) {
        id = UUID().uuidString
        fileType = type
        fileFormatType = formatType
        self.fileData = fileData
    }
}

@Model
final class SnippetItem {
    var creationDate: Date?
    var updatedDate: Date?
    var id: String?
    var title: String?
    var content: String?
    var customTag: SnipTag?
    var type: SnipType?
    var isSecure: Bool = false

    /// Pinned snippets are shown before recent items in the clipboard keyboard.
    /// A default value keeps the SwiftData/CloudKit migration compatible with
    /// existing SnipKey stores that predate this property.
    var isFavorite: Bool = false

    var lastTimeUsed: Date?
    var usedCount: Int = 0

    var file: SnippetFile?

    init(
        title: String,
        content: String,
        type: SnipType,
        isSecure: Bool,
        isFavorite: Bool = false
    ) {
        let now = Date.now
        creationDate = now
        updatedDate = now
        id = UUID().uuidString
        self.title = title
        self.content = content
        self.type = type
        self.isSecure = isSecure
        self.isFavorite = isFavorite
    }
}

private let previewText = "A reusable clipboard snippet for previewing the interface."

extension SnippetItem {
    static var dummy: SnippetItem {
        .init(title: "Example", content: previewText, type: .txt, isSecure: false)
    }

    static var dummy2: SnippetItem {
        .init(title: "Favorite command", content: "ssh user@example.local", type: .txt, isSecure: false, isFavorite: true)
    }
}
