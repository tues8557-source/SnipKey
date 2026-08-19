//
//  SnipKeyDataManager.swift
//  SnipKey
//
//  Created by Jonathan Taveras Vargas on 3/31/24.
//

import Foundation
import SwiftData

/// SwiftData configuration used by both the containing app and the keyboard extension.
///
/// Personal Team test builds do not include the App Groups capability, so each
/// target falls back to its own local store. If the App Group is restored on a
/// production branch, the same code automatically uses the shared store again.
final class SnipKeyDataManager {
    static let appGroupIdentifier = "group.com.tues8557.clipboardkeyboard"

    var sharedContainer: ModelContainer? = nil

    func makeSharedContainer() -> ModelContainer {
        let sharedModelContainer: ModelContainer = {
            let schema = Schema([
                SnippetItem.self,
                SettingsModel.self,
            ])
            let modelConfiguration = Self.makeConfiguration(for: schema)

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create local ModelContainer: \(error)")
            }
        }()

        self.sharedContainer = sharedModelContainer

        return sharedModelContainer
    }

    /// Build the shared `ModelContainer` off the main thread. This keeps the
    /// keyboard extension responsive while the local SQLite store is opened.
    static func makeSharedContainerAsync() async throws -> ModelContainer {
        try await Task.detached(priority: .userInitiated) {
            let schema = Schema([
                SnippetItem.self,
                SettingsModel.self,
            ])
            let modelConfiguration = Self.makeConfiguration(for: schema)
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        }.value
    }

    private static func makeConfiguration(for schema: Schema) -> ModelConfiguration {
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) != nil {
            return ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier(appGroupIdentifier),
                cloudKitDatabase: .none
            )
        }

        return ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
    }
}
