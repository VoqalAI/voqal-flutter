import Flutter
import UIKit
import VoqalSDK
import XCTest

@testable import voqal_flutter

/// Decoding Dart's reply to `onBookingConfirmed` into the SDK's result type.
final class BookingReplyTests: XCTestCase {

  func testNilReplyMeansNoResult() throws {
    XCTAssertNil(try BookingReply.result(from: nil))
  }

  func testNSNullReplyMeansNoResult() throws {
    XCTAssertNil(try BookingReply.result(from: NSNull()))
  }

  func testNotImplementedReplyMeansNoResult() throws {
    XCTAssertNil(try BookingReply.result(from: FlutterMethodNotImplemented))
  }

  func testSuccessMapBuildsTheResult() throws {
    let reply: [String: Any] = ["status": "success", "message": "Booked!", "reference": "8812"]

    let result = try BookingReply.result(from: reply)

    XCTAssertEqual(result, VoqalBookingResult(status: .success, message: "Booked!", reference: "8812"))
  }

  func testFlutterErrorThrowsHostErrorWithDartsCode() {
    let reply = FlutterError(code: "host_error", message: "StateError", details: nil)

    XCTAssertThrowsError(try BookingReply.result(from: reply)) { error in
      XCTAssertEqual(error as? BookingReply.Failure, .hostError(code: "host_error"))
    }
  }

  func testUnknownStatusThrowsMalformedReply() {
    XCTAssertThrowsError(try BookingReply.result(from: ["status": "ok"])) { error in
      XCTAssertEqual(error as? BookingReply.Failure, .malformedReply)
    }
  }

  func testNonMapReplyThrowsMalformedReply() {
    XCTAssertThrowsError(try BookingReply.result(from: "success")) { error in
      XCTAssertEqual(error as? BookingReply.Failure, .malformedReply)
    }
  }
}

/// Booking calls waiting for Dart must always end, even if the engine detaches.
@MainActor
final class PendingBookingRepliesTests: XCTestCase {

  func testWaitReturnsDartsReply() async {
    let pending = PendingBookingReplies()

    let reply = await pending.wait { respond in respond(["status": "success"]) }

    XCTAssertEqual((reply as? [String: Any])?["status"] as? String, "success")
  }

  func testFailAllEndsAWaitWithEngineDetached() async {
    let pending = PendingBookingReplies()

    let reply = await pending.wait { _ in pending.failAll() }

    XCTAssertEqual((reply as? FlutterError)?.code, PendingBookingReplies.engineDetachedCode)
  }

  func testASettledWaitIsNoLongerTracked() async {
    let pending = PendingBookingReplies()

    _ = await pending.wait { respond in respond(nil) }

    XCTAssertTrue(pending.isEmpty)
  }

  func testAReplyAfterFailAllIsIgnored() async {
    let pending = PendingBookingReplies()
    var lateRespond: ((Any?) -> Void)?

    _ = await pending.wait { respond in
      lateRespond = respond
      pending.failAll()
    }
    lateRespond?(["status": "success"])

    XCTAssertTrue(pending.isEmpty)
  }
}

/// What the plugin forwards to Dart's `Voqal.onError`.
final class ErrorReportTests: XCTestCase {

  private struct SampleError: Error {}

  // VoqalOutcomeReportError has no public initializer, so the payload builder it
  // maps through is tested directly.
  func testOutcomeReportPayloadCarriesStatusCodeAndConfirmId() {
    let arguments = ErrorReport.outcomeReportArguments(
      outcomeStatus: "success", code: "confirm_not_found", confirmId: "c-1")

    XCTAssertEqual(arguments["type"] as? String, "outcome_report")
    XCTAssertEqual(arguments["outcomeStatus"] as? String, "success")
    XCTAssertEqual(arguments["code"] as? String, "confirm_not_found")
    XCTAssertEqual(arguments["confirmId"] as? String, "c-1")
  }

  func testOutcomeReportPayloadSendsNullForAMissingConfirmId() {
    let arguments = ErrorReport.outcomeReportArguments(
      outcomeStatus: "unknown", code: "transport", confirmId: nil)

    XCTAssertTrue(arguments["confirmId"] is NSNull)
  }

  func testOtherErrorSendsOnlyTheTypeName() throws {
    let arguments = try XCTUnwrap(ErrorReport.arguments(for: SampleError()))

    XCTAssertEqual(arguments.count, 2)
    XCTAssertEqual(arguments["detail"] as? String, "SampleError")
  }

  func testBridgeBookingErrorIsNotForwarded() {
    XCTAssertNil(ErrorReport.arguments(for: BookingReply.Failure.hostError(code: "host_error")))
  }
}
