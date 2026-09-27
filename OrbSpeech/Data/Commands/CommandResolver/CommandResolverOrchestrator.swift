import Foundation

actor CommandResolverOrchestrator: CommandResolver {
    private let networkingResolver: NetworkingResolver
    private let foundationModelsCommandResolver: FoundationModelsCommandResolver
    private let coreMLModelCommandResolver: CoreMLModelCommandResolver

    init() {
        self.networkingResolver = NetworkingResolver()
        self.foundationModelsCommandResolver = FoundationModelsCommandResolver()
        self.coreMLModelCommandResolver = CoreMLModelCommandResolver()
    }

    init(networkingResolver: NetworkingResolver,
         foundationModelsCommandResolver: FoundationModelsCommandResolver,
         coreMLModelCommandResolver: CoreMLModelCommandResolver) {
        self.networkingResolver = networkingResolver
        self.foundationModelsCommandResolver = foundationModelsCommandResolver
        self.coreMLModelCommandResolver = coreMLModelCommandResolver
    }

    func prewarm() async throws {
        do {
            try await foundationModelsCommandResolver.prewarm()
            print("[OrbSpeech] resolver orchestrator: FoundationModelsCommandResolver prewarmed")
        } catch {
            print("[OrbSpeech] resolver orchestrator: FoundationModelsCommandResolver unavailable during prewarm - \(error.localizedDescription)")
        }

        try await coreMLModelCommandResolver.prewarm()
        print("[OrbSpeech] resolver orchestrator: CoreMLModelCommandResolver prewarmed")
    }

    func resolve(_ transcript: String) async throws -> OrbCommand {
        do {
            print("[OrbSpeech] resolver orchestrator: trying NetworkingResolver")
            return try await networkingResolver.resolve(transcript)
        } catch {
            print("[OrbSpeech] resolver orchestrator: NetworkingResolver failed, trying FoundationModelsCommandResolver - \(error.localizedDescription)")
        }

        do {
            return try await foundationModelsCommandResolver.resolve(transcript)
        } catch {
            print("[OrbSpeech] resolver orchestrator: FoundationModelsCommandResolver failed, trying CoreMLModelCommandResolver - \(error.localizedDescription)")
        }

        return try await coreMLModelCommandResolver.resolve(transcript)
    }
}
