import Flutter
import Foundation

/// Booking calls still waiting for Dart's reply.
///
/// If the Flutter engine detaches, Dart can never reply, so `failAll()` ends each
/// wait with an `engine_detached` error (the SDK reports it as `host_error`)
/// instead of leaving the continuation suspended forever.
@MainActor
final class PendingBookingReplies {
  /// Error code a wait ends with when the engine detached before Dart replied.
  static let engineDetachedCode = "engine_detached"

  private var continuations: [UUID: CheckedContinuation<Any?, Never>] = [:]

  /// True when no booking call is waiting for Dart.
  var isEmpty: Bool { continuations.isEmpty }

  /// Calls `send` with a one-shot responder and suspends until it is called
  /// (or `failAll()` runs). Later calls to the responder are ignored.
  func wait(_ send: (@escaping (Any?) -> Void) -> Void) async -> Any? {
    await withCheckedContinuation { continuation in
      let id = UUID()
      continuations[id] = continuation
      send { reply in
        // Flutter replies on the platform thread, which is not statically main-actor.
        Task { @MainActor in self.resolve(id, with: reply) }
      }
    }
  }

  /// Ends every wait with an `engine_detached` FlutterError.
  func failAll() {
    let detached = FlutterError(
      code: Self.engineDetachedCode, message: "Flutter engine detached", details: nil)
    for id in Array(continuations.keys) {
      resolve(id, with: detached)
    }
  }

  private func resolve(_ id: UUID, with reply: Any?) {
    continuations.removeValue(forKey: id)?.resume(returning: reply)
  }
}
