import Foundation

@MainActor
protocol CommandRunnerDelegate: AnyObject {
    func commandRunnerDidStartProcessing()
    func commandRunnerDidReset()
    func commandRunnerDidStartActing()
    func commandRunnerDidSettle(statusText: String?)
    func commandRunnerDidUpdateStatus(_ status: String)
    func commandRunnerDidUpdateVisualState(_ visualState: OrbVisualState)
    func commandRunnerDidLog(_ message: String)
}
