import Foundation

struct ProtocolPackage: Sendable {
    var graph: ProtocolGraph
    var rules: EngineRules
}

enum GraphLoader {
    static func load(from data: Data) throws -> ProtocolGraph {
        let decoder = JSONDecoder()
        let graph = try decoder.decode(ProtocolGraph.self, from: data)
        guard graph.commercial == false else {
            throw ProtocolGraphError.commercialInvariant
        }
        return graph
    }

    static func load(from url: URL) throws -> ProtocolGraph {
        let data = try Data(contentsOf: url)
        return try load(from: data)
    }

    static func loadRules(from data: Data) throws -> EngineRules {
        try JSONDecoder().decode(EngineRules.self, from: data)
    }

    static func loadRules(from url: URL) throws -> EngineRules {
        try loadRules(from: Data(contentsOf: url))
    }

    static func loadBundledGraph(
        name: String = "graph",
        extension fileExtension: String = "json",
        bundle: Bundle = .main
    ) throws -> ProtocolGraph {
        guard let url = bundle.url(forResource: name, withExtension: fileExtension) else {
            throw ProtocolGraphError.invalidData
        }
        return try load(from: url)
    }

    static func loadBundledRules(
        name: String = "engine-rules",
        extension fileExtension: String = "json",
        bundle: Bundle = .main
    ) throws -> EngineRules {
        guard let url = bundle.url(forResource: name, withExtension: fileExtension) else {
            throw ProtocolGraphError.invalidData
        }
        return try loadRules(from: url)
    }

    static func loadBundledPackage(bundle: Bundle = .main) throws -> ProtocolPackage {
        ProtocolPackage(
            graph: try loadBundledGraph(bundle: bundle),
            rules: try loadBundledRules(bundle: bundle)
        )
    }
}
