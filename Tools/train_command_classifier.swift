import CreateML
import Foundation

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let toolsDirectory = scriptURL.deletingLastPathComponent()
let projectDirectory = toolsDirectory.deletingLastPathComponent()

let trainingDataURL = toolsDirectory.appendingPathComponent("orb_command_training.csv")
let outputURL = projectDirectory
    .appendingPathComponent("OrbSpeech")
    .appendingPathComponent("Resources")
    .appendingPathComponent("OrbCommandClassifier.mlmodel")

let trainingData = try MLDataTable(contentsOf: trainingDataURL)
let parameters = MLTextClassifier.ModelParameters(validation: .none)
let classifier = try MLTextClassifier(trainingData: trainingData,
                                      textColumn: "text",
                                      labelColumn: "label",
                                      parameters: parameters)

let metadata = MLModelMetadata(
    author: "Andre Lara",
    shortDescription: "Classifies short orb speech commands into supported command labels.",
    license: nil,
    version: "2.0",
    additional: [
        "cancel_training": "Cancel examples are intentionally single-word control intents."
    ]
)

try classifier.write(to: outputURL, metadata: metadata)

print("Wrote \(outputURL.path)")
