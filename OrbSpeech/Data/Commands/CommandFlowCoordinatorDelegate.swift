import Foundation

@MainActor
protocol CommandFlowCoordinatorDelegate: AnyObject {
    func commandFlowCoordinatorDidStartProcessing()
    func commandFlowCoordinatorDidReset()
    func commandFlowCoordinatorDidStartActing()
    func commandFlowCoordinatorDidSettle(statusText: String?)
    func commandFlowCoordinatorDidUpdateStatus(_ status: String)
    func commandFlowCoordinatorDidUpdateVisualState(_ visualState: OrbVisualState)
    func commandFlowCoordinatorDidLog(_ message: String)
}
