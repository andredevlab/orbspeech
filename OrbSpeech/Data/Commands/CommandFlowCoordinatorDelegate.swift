import Foundation

@MainActor
protocol CommandFlowCoordinatorDelegate: AnyObject {
    func commandFlowCoordinatorDidStartProcessing()
    func commandFlowCoordinatorDidReset()
    func commandFlowCoordinatorDidStartActing()
    func commandFlowCoordinatorDidSettle(statusText: String?)
    func commandFlowCoordinatorDidUpdateStatus(_ status: CommandOutcomeStatus)
    func commandFlowCoordinatorDidUpdateVisualPresentation(state: OrbVisualState,
                                                           transition: OrbVisualTransition?)
    func commandFlowCoordinatorDidLog(_ message: String)
}
