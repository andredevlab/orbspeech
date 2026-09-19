import Foundation

struct OrbVisualState: Equatable {
    var xOffset: Double
    var yOffset: Double
    var baseRed: Double
    var baseGreen: Double
    var baseBlue: Double
    var edgeRed: Double
    var edgeGreen: Double
    var edgeBlue: Double
    var bounce: Double
    
    static let `default` = OrbVisualState(xOffset: 0,
                                          yOffset: 0,
                                          baseRed: 0.02,
                                          baseGreen: 0.07,
                                          baseBlue: 0.24,
                                          edgeRed: 0.20,
                                          edgeGreen: 0.45,
                                          edgeBlue: 1.0,
                                          bounce: 0)
}
