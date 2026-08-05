import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'voqal_flutter_method_channel.dart';

/// The interface every `voqal_flutter` platform implementation conforms to.
///
/// The surface is intentionally **push-only**: there is no method that returns
/// the auth token, the engine session token, the device key, or any request
/// proof. The host pushes credentials down via [setCredentials]; the native
/// delegate caches and serves them synchronously. Nothing sensitive is ever
/// handed back to Dart.
abstract class VoqalFlutterPlatform extends PlatformInterface {
  /// Constructs a [VoqalFlutterPlatform].
  VoqalFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static VoqalFlutterPlatform _instance = MethodChannelVoqalFlutter();

  /// The default instance to use (the method-channel implementation).
  static VoqalFlutterPlatform get instance => _instance;

  /// Platform-specific implementations set this with their own class.
  static set instance(VoqalFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Invoked when the user taps the native action button (see
  /// [VoqalConfig.actionButtonEnabled]). The host wires navigation here. Delivered
  /// from native over the method channel; null when the host hasn't set a handler.
  void Function()? onActionButtonTapped;

  /// Provider of the host's developer headers to forward to its own backend,
  /// wired from [VoqalConfig.forwardedHeaders] at [setup]. Read live before each
  /// turn-serving native call, its output namespaced and pushed down. Null (the
  /// default) forwards nothing, so existing integrations are unaffected. Stored
  /// process-globally like [onActionButtonTapped].
  Map<String, String> Function()? forwardedHeaders;

  /// Configures the SDK once at launch. [config] is a primitives-only map.
  Future<void> setup(Map<String, Object?> config) {
    throw UnimplementedError('setup() has not been implemented.');
  }

  /// Pushes the live auth [token] (+ optional [metadataJson]) into the native
  /// cache. The native delegate serves it synchronously on every request.
  Future<void> setCredentials(String token, String? metadataJson) {
    throw UnimplementedError('setCredentials() has not been implemented.');
  }

  /// Pushes the already-namespaced forwarded [headers] into the native cache. The
  /// native delegate serves them synchronously on every turn-serving request, so
  /// the wrapper never issues them itself. Keys are the full `X-Voqal-Forward-*`
  /// wire names produced by [VoqalForwardedHeaders.namespaced].
  Future<void> setForwardedHeaders(Map<String, String> headers) {
    throw UnimplementedError('setForwardedHeaders() has not been implemented.');
  }

  /// Warms the engine connection in the background.
  Future<void> prewarm() {
    throw UnimplementedError('prewarm() has not been implemented.');
  }

  /// Presents the assistant. The native SDK owns the entire UI.
  Future<void> present() {
    throw UnimplementedError('present() has not been implemented.');
  }
}
