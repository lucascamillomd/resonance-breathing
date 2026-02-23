import SwiftData

@MainActor
enum UserSettingsBootstrapper {
    static func ensureSettings(modelContext: ModelContext) throws -> UserSettings {
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1

        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }

        let settings = UserSettings()
        modelContext.insert(settings)
        return settings
    }
}
