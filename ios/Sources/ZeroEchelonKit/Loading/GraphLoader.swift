import Foundation

public enum GraphLoader {
    public static func load(from data: Data) throws -> ProtocolGraph {
        let decoder = JSONDecoder()
        let graph = try decoder.decode(ProtocolGraph.self, from: data)
        guard graph.commercial == false else {
            throw ProtocolGraphError.commercialInvariant
        }
        return graph
    }

    public static func load(from url: URL) throws -> ProtocolGraph {
        let data = try Data(contentsOf: url)
        return try load(from: data)
    }

    public static func loadBundledGraph(
        name: String = "graph",
        extension fileExtension: String = "json",
        bundle: Bundle = .main
    ) throws -> ProtocolGraph {
        guard let url = bundle.url(forResource: name, withExtension: fileExtension) else {
            throw ProtocolGraphError.invalidData
        }
        return try load(from: url)
    }
}
