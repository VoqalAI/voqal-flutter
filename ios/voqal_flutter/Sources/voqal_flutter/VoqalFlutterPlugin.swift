import Flutter
import UIKit
import VoqalSDK

/// Thin Flutter bridge over the native VoqalSDK.
///
/// The SDK presents its own full-screen experience, so this bridge only carries
/// configuration, pushed credentials, and the prewarm/present calls — no view
/// embedding. The MethodChannel is async but the SDK's delegate reads the token
/// synchronously, so Dart pushes credentials down (and refreshes them on
/// rotation) and the delegate serves a native cache. The token is never logged,
/// persisted, or returned across the channel.
public class VoqalFlutterPlugin: NSObject, FlutterPlugin {

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "voqal_flutter", binaryMessenger: registrar.messenger())
    Self.channel = channel
    registrar.addMethodCallDelegate(VoqalFlutterPlugin(), channel: channel)
  }

  /// Retained so the native delegate can call back into Dart (e.g. action-button taps).
  /// Used on the main thread only. Single-engine assumption (matches the static `coordinator`
  /// and `VoqalSDKManager.shared`): in a multi-engine/add-to-app host the last-registered
  /// engine's channel wins. Not a concern for a standard single-FlutterEngine app.
  private static var channel: FlutterMethodChannel?

  /// Latest credentials pushed from Dart. The SDK delegate may read these off
  /// the main thread, so access is lock-guarded for cross-thread visibility.
  /// In-memory only — never persisted.
  private static let cacheLock = NSLock()
  private static var cachedToken = ""
  private static var cachedMetadata: String?

  /// Latest forwarded headers pushed from Dart, under the developer's own names;
  /// the native SDK adds `X-Voqal-Forward-` once on the wire. In-memory only,
  /// guarded like the credential cache.
  /// The `Coordinator.voqalForwardedHeaders()` delegate hook (VoqalSDK 2.0.0) serves
  /// these to the native SDK per request (see the cross-platform PROTOCOL.md).
  private static var cachedForwardedHeaders: [String: String] = [:]

  private static func cacheCredentials(token: String, metadata: String?) {
    cacheLock.lock()
    cachedToken = token
    cachedMetadata = metadata
    cacheLock.unlock()
  }

  private static func cacheForwardedHeaders(_ headers: [String: String]) {
    cacheLock.lock()
    cachedForwardedHeaders = headers
    cacheLock.unlock()
  }

  private static func currentForwardedHeaders() -> [String: String] {
    cacheLock.lock()
    defer { cacheLock.unlock() }
    return cachedForwardedHeaders
  }

  private static func currentToken() -> String {
    cacheLock.lock()
    defer { cacheLock.unlock() }
    return cachedToken
  }

  private static func currentMetadata() -> String? {
    cacheLock.lock()
    defer { cacheLock.unlock() }
    return cachedMetadata
  }

  /// Booking calls waiting for Dart; ended on engine detach so none hangs forever.
  @MainActor static let pendingBookingReplies = PendingBookingReplies()

  /// Dart can't reply once the engine is gone: end the pending booking waits.
  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    Task { @MainActor in VoqalFlutterPlugin.pendingBookingReplies.failAll() }
  }

  /// Retained delegate — prewarm's background work needs it alive.
  private static let coordinator = Coordinator()

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setup":
      guard let config = call.arguments as? [String: Any] else {
        result(badArgs("setup expects a configuration map"))
        return
      }
      DispatchQueue.main.async {
        VoqalSDKManager.shared.setup(configuration: Self.configuration(from: config))
        result(nil)
      }

    case "setCredentials":
      guard let args = call.arguments as? [String: Any],
        let token = args["token"] as? String
      else {
        result(badArgs("setCredentials expects a token"))
        return
      }
      Self.cacheCredentials(token: token, metadata: args["metadata"] as? String)
      result(nil)

    case "setForwardedHeaders":
      let headers = (call.arguments as? [String: Any])?["headers"] as? [String: String]
      Self.cacheForwardedHeaders(headers ?? [:])
      result(nil)

    case "prewarm":
      DispatchQueue.main.async {
        VoqalSDKManager.shared.prewarm(delegate: Self.coordinator)
        result(nil)
      }

    case "present":
      DispatchQueue.main.async {
        VoqalSDKManager.shared.presentChat(
          from: Self.coordinator.getViewController(),
          delegate: Self.coordinator,
          animated: true)
        result(nil)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Builds a `FlutterError` that never embeds caller-supplied credentials.
  private func badArgs(_ message: String) -> FlutterError {
    FlutterError(code: "bad_args", message: message, details: nil)
  }

  // MARK: - Config mapping

  private static func configuration(from config: [String: Any]) -> VoqalSDKConfiguration {
    var configuration = VoqalSDKConfiguration(
      requestId: config["requestId"] as? String ?? "prod-flutter")

    if let key = config["apiKey"] as? String { configuration.apiKey = key }
    if let urlString = config["agentUrl"] as? String, let url = URL(string: urlString) {
      configuration.agentURL = url
    }
    if let haptics = config["hapticsEnabled"] as? Bool {
      configuration.hapticsEnabled = haptics
    }
    if let timeout = config["conversationTimeoutSeconds"] as? Double {
      configuration.conversationTimeout = timeout
    } else if let timeout = config["conversationTimeoutSeconds"] as? Int {
      configuration.conversationTimeout = Double(timeout)
    }
    configuration.theme = theme(from: config["theme"] as? [String: Any])
    configuration.home = home(from: config["home"] as? [String: Any])
    configuration.observability = observability(from: config["observability"] as? [String: Any])
    switch config["presentationStyle"] as? String {
    case "fullScreen": configuration.presentationStyle = .fullScreen
    default: configuration.presentationStyle = .sheet
    }
    if let title = config["headerTitle"] as? String {
      configuration.strings.chatHeaderTitle = title
    }
    if let base64 = config["headerIconPngBase64"] as? String,
      let data = Data(base64Encoded: base64),
      let image = UIImage(data: data)
    {
      configuration.icons.chatHeaderIcon = image
    }
    if config["actionButtonEnabled"] as? Bool == true {
      var button = VoqalActionButton()
      if let dismiss = config["actionButtonDismissOnTap"] as? Bool { button.dismissOnTap = dismiss }
      if let base64 = config["actionButtonIconPngBase64"] as? String,
        let data = Data(base64Encoded: base64),
        let image = UIImage(data: data)
      {
        button.icon = image
      }
      configuration.actionButton = button
    }
    if let version = config["wrapperVersion"] as? String {
      configuration.wrapper = VoqalWrapper(name: wrapperName, version: version)
    }
    applyBooking(from: config, to: &configuration)
    return configuration
  }

  /// The platform name the engine records for requests from this plugin.
  private static let wrapperName = "flutter"

  /// Maps the 2.2.0 booking keys. Missing or invalid values keep the SDK defaults.
  private static func applyBooking(
    from config: [String: Any], to configuration: inout VoqalSDKConfiguration
  ) {
    if let mode = (config["bookingMode"] as? String).flatMap(VoqalBookingMode.init(rawValue:)) {
      configuration.bookingMode = mode
    }
    if let title = config["addFundsButtonTitle"] as? [String: Any],
      let english = title["en"] as? String, !english.isEmpty,
      let arabic = title["ar"] as? String, !arabic.isEmpty
    {
      configuration.addFundsButtonTitle = VoqalLocalizedText(en: english, ar: arabic)
    }
    if let dismiss = config["dismissOnAddFunds"] as? Bool {
      configuration.dismissOnAddFunds = dismiss
    }
    if let timeout = (config["hostActionTimeoutSeconds"] as? NSNumber)?.doubleValue, timeout > 0 {
      configuration.hostActionTimeoutSeconds = timeout
    }
  }

  private static func theme(from dictionary: [String: Any]?) -> VoqalTheme {
    guard let dictionary else { return VoqalTheme() }
    let appearance: VoqalTheme.Appearance
    switch dictionary["appearance"] as? String {
    case "light": appearance = .light
    case "dark": appearance = .dark
    default: appearance = .auto
    }
    let radius: CGFloat
    if let value = dictionary["radius"] as? Double { radius = CGFloat(value) } else { radius = 20 }
    // VoqalSDK 1.3.3 replaced `fontName: String?` with `font: UIFont?`. Keep the Flutter API the
    // same (a font-family name string) and map it to a UIFont here — the SDK uses its family.
    let font = (dictionary["fontName"] as? String).flatMap { UIFont(name: $0, size: 16) }
    return VoqalTheme(
      accent: dictionary["accent"] as? String ?? "#2d5bff",
      accent2: dictionary["accent2"] as? String,
      appearance: appearance,
      font: font,
      radius: radius)
  }

  private static func home(from dictionary: [String: Any]?) -> VoqalHome {
    guard let dictionary else { return VoqalHome() }
    return VoqalHome(
      userName: dictionary["userName"] as? String,
      pinnedCTAs: dictionary["pinnedCTAs"] as? [String] ?? [],
      showAgentGlance: dictionary["showAgentGlance"] as? Bool ?? true)
  }

  private static func observability(from dictionary: [String: Any]?) -> VoqalObservabilityOptions {
    var options = VoqalObservabilityOptions()
    guard let dictionary else { return options }
    if let dsn = dictionary["dsn"] as? String { options.dsn = dsn }
    if let enabled = dictionary["enabled"] as? Bool { options.enabled = enabled }
    if let scrub = dictionary["scrubPII"] as? Bool { options.scrubPII = scrub }
    if let rate = dictionary["tracesSampleRate"] as? Double { options.tracesSampleRate = rate }
    if let environment = dictionary["environment"] as? String { options.environment = environment }
    return options
  }

  // MARK: - Delegate

  /// Serves the pushed credentials synchronously and resolves the on-screen
  /// view controller. Logs errors only — never the token.
  final class Coordinator: NSObject, VocalButtonDelegate, VoqalBookingHandler, VoqalAddFundsHandler {
    func getToken() -> String { VoqalFlutterPlugin.currentToken() }
    func getMetaData() -> String? { VoqalFlutterPlugin.currentMetadata() }
    func getViewController() -> UIViewController {
      UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
        .first?.voqalTopmost ?? UIViewController()
    }
    func voqalForwardedHeaders() -> [String: String] { VoqalFlutterPlugin.currentForwardedHeaders() }
    func voqalButton(didUploadRecording result: String) {}
    func voqalButton(didFailWith error: Error) {
      #if DEBUG
        NSLog("[VoqalFlutter] error: \(error)")
      #endif
      guard let arguments = ErrorReport.arguments(for: error) else { return }
      DispatchQueue.main.async {
        VoqalFlutterPlugin.channel?.invokeMethod("onError", arguments: arguments)
      }
    }
    func voqalDidTapActionButton() {
      // Forward to Dart so the Flutter app can navigate (Navigator.push).
      DispatchQueue.main.async {
        VoqalFlutterPlugin.channel?.invokeMethod("onActionButtonTapped", arguments: nil)
      }
    }

    /// Hands the booking to Dart's `Voqal.onBookingConfirmed` and awaits its reply.
    /// The SDK bounds the wait (`hostActionTimeoutSeconds`) and cancels this task on
    /// timeout; a reply that arrives later is ignored by the SDK. No Dart handler
    /// (or a null reply) is a failed booking, the same outcome Android reports.
    @MainActor
    func voqalDidConfirmBooking(_ details: VoqalBookingDetails) async throws -> VoqalBookingResult {
      let arguments = details.dictionary
      let reply: Any? = await VoqalFlutterPlugin.pendingBookingReplies.wait { respond in
        guard let channel = VoqalFlutterPlugin.channel else {
          respond(nil)
          return
        }
        channel.invokeMethod("onBookingConfirmed", arguments: arguments, result: respond)
      }
      return try BookingReply.result(from: reply)
        ?? VoqalBookingResult(status: .failed, code: BookingReply.noResultCode)
    }

    @MainActor
    func voqalDidTapAddFunds(amount: Double?, currency: String?) {
      let arguments: [String: Any] = [
        "amount": amount.map { $0 as Any } ?? NSNull(),
        "currency": currency.map { $0 as Any } ?? NSNull(),
      ]
      VoqalFlutterPlugin.channel?.invokeMethod("onAddFundsTapped", arguments: arguments)
    }
  }
}

/// Decodes Dart's reply to `onBookingConfirmed` into the SDK's result type.
enum BookingReply {
  /// Outcome code when Dart has no booking handler or it returned null. Matches
  /// the code the native SDKs use for a missing host result.
  static let noResultCode = "host_no_result"

  /// Why a reply could not become a booking result. The SDK reports any of these
  /// to the engine as a failed booking (`host_error`).
  enum Failure: Error, Equatable {
    /// The Dart handler threw; carries the error code Dart sent.
    case hostError(code: String)
    /// The reply was not a result map, or its `status` was not success/failed.
    case malformedReply
  }

  /// nil (Dart had no handler or declined) or `FlutterMethodNotImplemented` (an
  /// older Dart side) both mean "no result"; the SDK reports that as a failed
  /// booking (`host_no_result`) in host mode.
  static func result(from reply: Any?) throws -> VoqalBookingResult? {
    guard let reply, !(reply is NSNull) else { return nil }
    if (reply as AnyObject) === FlutterMethodNotImplemented { return nil }
    if let error = reply as? FlutterError { throw Failure.hostError(code: error.code) }
    guard let map = reply as? [String: Any],
      let status = (map["status"] as? String).flatMap(VoqalBookingStatus.init(rawValue:))
    else { throw Failure.malformedReply }
    return VoqalBookingResult(
      status: status,
      message: map["message"] as? String,
      code: map["code"] as? String,
      reference: map["reference"] as? String)
  }
}

private extension UIViewController {
  /// The controller actually on screen, so the sheet presents over Flutter's UI.
  var voqalTopmost: UIViewController {
    presentedViewController?.voqalTopmost ?? self
  }
}
