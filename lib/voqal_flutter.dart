import 'src/voqal_config.dart';
import 'voqal_flutter_platform_interface.dart';

export 'src/voqal_config.dart';

/// Entry point for the Voqal voice assistant.
///
/// The native SDK is a self-contained shell: it presents its own full-screen
/// UI, performs all networking, and holds every secret. This class is a thin
/// façade over four platform calls — Flutter renders no Voqal UI.
///
/// ## Security
/// All cryptography lives in the native SDK. A hardware-bound P-256 device key
/// (iOS Secure Enclave / Android Keystore) signs every request with a
/// DPoP-style proof, and the engine-minted session token is held in memory
/// only. This wrapper never sees a private key, a session token, or a signing
/// secret — the only key it carries is the **publishable** `pk_live_…`, which
/// is public by design.
///
/// Credentials follow a **push model**: call [setCredentials] whenever the
/// host's auth token rotates. The token is cached natively and served
/// synchronously to the SDK; it is never persisted, logged, or returned to
/// Dart.
class Voqal {
  /// Creates a Voqal façade. Cheap to construct.
  Voqal();

  VoqalFlutterPlatform get _platform => VoqalFlutterPlatform.instance;

  /// Configures the SDK. Call once at app launch before [prewarm]/[present].
  Future<void> setup(VoqalConfig config) => _platform.setup(config.toMap());

  /// Pushes the live auth [token] (and optional [metadataJson], a JSON string
  /// such as `{"country_code":"EGY","user_id":"123"}`) into the native cache.
  ///
  /// Call again on every rotation. Do not retain the token in Dart beyond this
  /// call — the native delegate is the single source of truth.
  Future<void> setCredentials(String token, {String? metadataJson}) =>
      _platform.setCredentials(token, metadataJson);

  /// Opens the engine connection in the background so the first turn is fast.
  Future<void> prewarm() => _platform.prewarm();

  /// Presents the assistant over the current Flutter view. The SDK owns the UI.
  Future<void> present() => _platform.present();
}
