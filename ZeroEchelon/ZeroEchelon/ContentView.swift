import SwiftUI

@Observable
final class AppModel {
    var engine: ProtocolEngine?
    var loadError: String?
    var speech = SpeechController()
    var speakOnAppear = true

    func load() {
        do {
            let graph = try GraphLoader.loadBundledGraph()
            let engine = try ProtocolEngine(graph: graph, locale: .uk)
            try engine.skipEntrySplashIfNeeded()
            self.engine = engine
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

struct ContentView: View {
    @State private var model = AppModel()

    var body: some View {
        Group {
            if let engine = model.engine {
                NodeFrameView(
                    engine: engine,
                    speech: model.speech,
                    speakOnAppear: $model.speakOnAppear
                )
            } else if let loadError = model.loadError {
                ContentUnavailableView(
                    "Граф не завантажився",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else {
                ProgressView("Завантаження протоколу…")
            }
        }
        .task { model.load() }
    }
}

#Preview {
    ContentView()
}
