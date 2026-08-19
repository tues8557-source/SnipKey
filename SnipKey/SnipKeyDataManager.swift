//
//  SnipKeyDataManager.swift
//  SnipKey
//
//  Created by Jonathan Taveras Vargas on 3/31/24.
//

import Foundation
import SwiftData

/// Shared SwiftData configuration used by both the containing app and the
/// keyboard extension.
///
/// Personal Team test builds deliberately use a local App Group store only.
/// CloudKit is disabled on this branch so the project can be provisioned
/// without the paid Apple Developer Program. The production/iCloud branch can
/// switch `cloudKitDatabase` back to `.automatic` later without changing the
/// model types or UI.
final class SnipKeyDataManager {
    static let appGroupIdentifier = "group.com.tues8557.clipboardkeyboard"

    var sharedContainer: ModelContainer? = nil

    func makeSharedContainer() -> ModelContainer {
        let sharedModelContainer: ModelContainer = {
            let schema = Schema([
                SnippetItem.self,
                SettingsModel.self,
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier(Self.appGroupIdentifier),
                cloudKitDatabase: .none
            )

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create local shared ModelContainer: \(error)")
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
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier(Self.appGroupIdentifier),
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        }.value
    }
}
