import Foundation

enum CivicMockStoreError: Error, LocalizedError, Sendable {
    case resourceMissing(name: String)
    case decodeFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .resourceMissing(let name):
            return "Civic mock JSON «\(name)» is missing from the app bundle."
        case .decodeFailed(let underlying):
            return "Civic mock JSON could not be decoded: \(underlying.localizedDescription)"
        }
    }
}

enum CivicMockStore {
    static let resourceName = "civic-mock"
    static let resourceExtension = "json"

    static func loadBundled(bundle: Bundle = .main) throws -> CivicMockCatalog {
        guard let url = bundle.url(
            forResource: resourceName,
            withExtension: resourceExtension
        ) else {
            throw CivicMockStoreError.resourceMissing(
                name: "\(resourceName).\(resourceExtension)"
            )
        }
        return try load(from: url)
    }

    /// Package-friendly loader for unit tests that resolve JSON by file URL.
    static func loadForTests(from url: URL) throws -> CivicMockCatalog {
        try load(from: url)
    }

    static func load(from url: URL) throws -> CivicMockCatalog {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw CivicMockStoreError.decodeFailed(underlying: error)
        }
        return try decode(data)
    }

    static func load(from data: Data) throws -> CivicMockCatalog {
        try decode(data)
    }

    private static func decode(_ data: Data) throws -> CivicMockCatalog {
        do {
            return try JSONDecoder().decode(CivicMockCatalog.self, from: data)
        } catch {
            throw CivicMockStoreError.decodeFailed(underlying: error)
        }
    }
}
