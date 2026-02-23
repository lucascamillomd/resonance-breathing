import XCTest
import SwiftData
@testable import ResonanceBreathing

@MainActor
final class UserSettingsBootstrapperTests: XCTestCase {
    func testEnsureSettingsCreatesOnlyOneSettingsRow() throws {
        let container = try ModelContainer(
            for: UserSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        let first = try UserSettingsBootstrapper.ensureSettings(modelContext: context)
        let second = try UserSettingsBootstrapper.ensureSettings(modelContext: context)

        let allSettings = try context.fetch(FetchDescriptor<UserSettings>())
        XCTAssertEqual(allSettings.count, 1)
        XCTAssertEqual(first.persistentModelID, second.persistentModelID)
    }
}
