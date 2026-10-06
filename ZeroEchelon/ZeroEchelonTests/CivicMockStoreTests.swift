import Foundation
import Testing
@testable import ZeroEchelon

@MainActor
struct CivicMockStoreTests {
    private func mockJSONURL() -> URL {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        return testsDir
            .deletingLastPathComponent()
            .appendingPathComponent("ZeroEchelon/Civic/civic-mock.json")
    }

    private func loadCatalog() throws -> CivicMockCatalog {
        if let bundled = try? CivicMockStore.loadBundled(bundle: .main) {
            return bundled
        }
        return try CivicMockStore.loadForTests(from: mockJSONURL())
    }

    @Test func mockCatalogHasExpectedSectionCounts() throws {
        let catalog = try loadCatalog()

        #expect(catalog.version == "2026-09-28-mock")
        #expect(catalog.consultations.count == 2)
        #expect(catalog.clinics.count == 2)
        #expect(catalog.pharmacies.count == 2)
        #expect(catalog.donationCenters.count == 1)
    }

    @Test func pharmaciesIncludeOneNightDuty() throws {
        let catalog = try loadCatalog()
        let duty = catalog.pharmacies.filter(\.isDutyNight)
        #expect(duty.count == 1)
        #expect(duty.first?.id == "pharm-lesya")
    }

    @Test func localizedFieldsResolveForBothLocales() throws {
        let catalog = try loadCatalog()
        let consult = try #require(catalog.consultations.first)
        #expect(!consult.specialtyText(for: .uk).isEmpty)
        #expect(!consult.specialtyText(for: .en).isEmpty)
        #expect(consult.specialtyText(for: .uk) != consult.specialtyText(for: .en))

        let clinic = try #require(catalog.clinics.first)
        #expect(clinic.hoursText(for: .uk).contains("пн"))
        #expect(clinic.hoursText(for: .en).lowercased().contains("mon"))
    }

    @Test func loadForTestsThrowsOnMissingFile() {
        let missing = URL(fileURLWithPath: "/tmp/civic-mock-missing-\(UUID().uuidString).json")
        #expect(throws: CivicMockStoreError.self) {
            try CivicMockStore.loadForTests(from: missing)
        }
    }
}
