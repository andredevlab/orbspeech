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
            print("[OrbSpeech] resolver orchestrator: trying FoundationModelsCommandResolver with =\(transcript)")
            let foundationOrbCommand = try await foundationModelsCommandResolver.resolve(transcript)
            print("[OrbSpeech] resolver orchestrator: FoundationModelsCommandResolver resolved =\(foundationOrbCommand)")
            
            /// Orchestrator understand an unknown as an error to throw, so can try the next resolver in the sequence/pipeline
            if foundationOrbCommand.action == "unknown" {
                throw CommandResolverOrchestratorError.unknownCommand
            }
            
            return foundationOrbCommand
        } catch let error as CancellationError {
            print("[OrbSpeech] resolver orchestrator: FoundationModelsCommandResolver Cancelled")
            throw error
        } catch {
            print("[OrbSpeech] resolver orchestrator: FoundationModelsCommandResolver failed with =\(error.localizedDescription)")
        }
        
        do {
            print("[OrbSpeech] resolver orchestrator: trying CoreMLModelCommandResolver with =\(transcript)")
            let coreMLOrbCommand = try await coreMLModelCommandResolver.resolve(transcript)
            print("[OrbSpeech] resolver orchestrator: CoreMLModelCommandResolver resolved \(coreMLOrbCommand)")
            
            /// Orchestrator understand an unknown as an error to throw, so can try the next resolver in the sequence/pipeline
            if coreMLOrbCommand.action == "unknown" {
                throw CommandResolverOrchestratorError.unknownCommand
            }
            
            return coreMLOrbCommand
        } catch let error as CancellationError {
            print("[OrbSpeech] resolver orchestrator: CoreMLModelCommandResolver Cancelled")
            throw error
        }  catch {
            print("[OrbSpeech] resolver orchestrator: CoreMLModelCommandResolver failed with =\(error.localizedDescription)")
        }
        
        do {
            print("[OrbSpeech] resolver orchestrator: trying NetworkingResolver with =\(transcript)")
            let networkingOrbCommand = try await networkingResolver.resolve(transcript)
            print("[OrbSpeech] resolver orchestrator: NetworkingResolver resolved = \(networkingOrbCommand)")
            return networkingOrbCommand
        } catch let error as CancellationError {
            print("[OrbSpeech] resolver orchestrator: NetworkingResolver Cancelled")
            throw error
        }  catch {
            print("[OrbSpeech] resolver orchestrator: NetworkingResolver failed with =\(error.localizedDescription)")
        }
        
        return OrbCommand(id: UUID().uuidString, action: "unknown", value: nil)
    }
}
