import Foundation
import VoqalSDK

/// What the plugin forwards to Dart's `Voqal.onError`: codes, ids, and type
/// names only, never an error's message (it may carry user data).
enum ErrorReport {
  /// The `onError` payload for `error`, or nil when it must not be forwarded:
  /// the bridge's own booking failures are already reported in Dart, with the
  /// card's confirm id.
  static func arguments(for error: Error) -> [String: Any]? {
    if error is BookingReply.Failure { return nil }
    if let report = error as? VoqalOutcomeReportError {
      return outcomeReportArguments(
        outcomeStatus: report.outcomeStatus, code: report.code, confirmId: report.confirmId)
    }
    return ["type": "sdk", "detail": String(describing: type(of: error))]
  }

  /// The payload for an outcome that couldn't be reported to Voqal.
  static func outcomeReportArguments(
    outcomeStatus: String, code: String, confirmId: String?
  ) -> [String: Any] {
    [
      "type": "outcome_report",
      "outcomeStatus": outcomeStatus,
      "code": code,
      "confirmId": confirmId.map { $0 as Any } ?? NSNull(),
      "detail": "VoqalOutcomeReportError",
    ]
  }
}
