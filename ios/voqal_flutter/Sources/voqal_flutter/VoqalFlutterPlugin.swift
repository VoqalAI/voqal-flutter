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
    registrar.addMethodCallDelegate(VoqalFlutterPlugin(), channel: channel)
  }

  /// Latest credentials pushed from Dart. The SDK delegate may read these off
  /// the main thread, so access is lock-guarded for cross-thread visibility.
  /// In-memory only — never persisted.
  private static let cacheLock = NSLock()
  private static var cachedToken = ""
  private static var cachedMetadata: String?

  private static func cacheCredentials(token: String, metadata: String?) {
    cacheLock.lock()
    cachedToken = token
    cachedMetadata = metadata
    cacheLock.unlock()
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
    return configuration
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
  final class Coordinator: NSObject, VocalButtonDelegate {
    func getToken() -> String { VoqalFlutterPlugin.currentToken() }
    func getMetaData() -> String? { VoqalFlutterPlugin.currentMetadata() }
    func getViewController() -> UIViewController {
      UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
        .first?.voqalTopmost ?? UIViewController()
    }
    func voqalButton(didUploadRecording result: String) {}
    func voqalButton(didFailWith error: Error) {
      #if DEBUG
        NSLog("[VoqalFlutter] error: \(error)")
      #endif
    }
  }
}

private extension UIViewController {
  /// The controller actually on screen, so the sheet presents over Flutter's UI.
  var voqalTopmost: UIViewController {
    presentedViewController?.voqalTopmost ?? self
  }
}
