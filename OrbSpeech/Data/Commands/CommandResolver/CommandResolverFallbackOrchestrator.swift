import Foundation

actor CommandResolverFallbackOrchestrator: CommandResolver {
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
            print("[OrbSpeech] resolver fallback orchestrator: FoundationModelsCommandResolver prewarmed")
        } catch {
            print("[OrbSpeech] resolver fallback orchestrator: FoundationModelsCommandResolver unavailable during prewarm - \(error.localizedDescription)")
        }
        
        try await coreMLModelCommandResolver.prewarm()
        print("[OrbSpeech] resolver fallback orchestrator: CoreMLModelCommandResolver prewarmed")
    }
    
    func resolve(_ transcript: String) async throws -> OrbCommand {
        do {
            print("[OrbSpeech] resolver fallback orchestrator: trying FoundationModelsCommandResolver with =\(transcript)")
            let foundationOrbCommand = try await foundationModelsCommandResolver.resolve(transcript)
            print("[OrbSpeech] resolver fallback orchestrator: FoundationModelsCommandResolver resolved =\(foundationOrbCommand)")
            
            /// Treat unknown as a fallback signal so the next resolver can try.
            if foundationOrbCommand.action == .unknown {
                throw CommandResolverFallbackOrchestratorError.unknownCommand
            }
            
            return foundationOrbCommand
        } catch let error as CancellationError {
            print("[OrbSpeech] resolver fallback orchestrator: FoundationModelsCommandResolver Cancelled")
            throw error
        } catch {
            print("[OrbSpeech] resolver fallback orchestrator: FoundationModelsCommandResolver failed with =\(error.localizedDescription)")
        }
        
        do {
            print("[OrbSpeech] resolver fallback orchestrator: trying CoreMLModelCommandResolver with =\(transcript)")
            let coreMLOrbCommand = try await coreMLModelCommandResolver.resolve(transcript)
            print("[OrbSpeech] resolver fallback orchestrator: CoreMLModelCommandResolver resolved \(coreMLOrbCommand)")
            
            /// Treat unknown as a fallback signal so the next resolver can try.
            if coreMLOrbCommand.action == .unknown {
                throw CommandResolverFallbackOrchestratorError.unknownCommand
            }
            
            return coreMLOrbCommand
        } catch let error as CancellationError {
            print("[OrbSpeech] resolver fallback orchestrator: CoreMLModelCommandResolver Cancelled")
            throw error
        }  catch {
            print("[OrbSpeech] resolver fallback orchestrator: CoreMLModelCommandResolver failed with =\(error.localizedDescription)")
        }
        
        do {
            print("[OrbSpeech] resolver fallback orchestrator: trying NetworkingResolver with =\(transcript)")
            let networkingOrbCommand = try await networkingResolver.resolve(transcript)
            print("[OrbSpeech] resolver fallback orchestrator: NetworkingResolver resolved = \(networkingOrbCommand)")
            return networkingOrbCommand
        } catch let error as CancellationError {
            print("[OrbSpeech] resolver fallback orchestrator: NetworkingResolver Cancelled")
            throw error
        }  catch {
            print("[OrbSpeech] resolver fallback orchestrator: NetworkingResolver failed with =\(error.localizedDescription)")
        }
        
        return OrbCommand(action: .unknown)
    }
}
