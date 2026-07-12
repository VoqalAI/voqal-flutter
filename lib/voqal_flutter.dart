import 'src/voqal_config.dart';
import 'src/voqal_image.dart';
import 'voqal_flutter_platform_interface.dart';

export 'src/voqal_config.dart';
export 'src/voqal_image.dart';

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
  ///
  /// A [VoqalConfig.headerIcon] is resolved to bytes here (it may read from the
  /// asset bundle) and sent alongside the config map as base64.
  Future<void> setup(VoqalConfig config) async {
    final Map<String, Object?> map = config.toMap();
    final VoqalImage? icon = config.headerIcon;
    if (icon != null) {
      map['headerIconPngBase64'] = await icon.resolveBase64();
    }
    final VoqalImage? actionIcon = config.actionButtonIcon;
    if (config.actionButtonEnabled && actionIcon != null) {
      map['actionButtonIconPngBase64'] = await actionIcon.resolveBase64();
    }
    await _platform.setup(map);
  }

  /// Called when the user taps the native action button (enabled via
  /// [VoqalConfig.actionButtonEnabled]). Set this to navigate from your Flutter app
  /// — e.g. `Navigator.push(...)` to a checkout page. When the button's
  /// `actionButtonDismissOnTap` is true (the default), the native sheet has already
  /// been dismissed by the time this fires.
  ///
  /// Note: this handler is stored **process-globally** (all [Voqal] instances share it),
  /// so setting it twice replaces the previous handler. If you capture a `BuildContext`
  /// or `State` in the closure, clear it (`voqal.onActionButtonTapped = null`) in your
  /// widget's `dispose()` to avoid retaining a disposed subtree for the process lifetime.
  set onActionButtonTapped(void Function()? handler) =>
      _platform.onActionButtonTapped = handler;

  /// The current action-button tap handler, if any.
  void Function()? get onActionButtonTapped => _platform.onActionButtonTapped;

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
