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

  /// Configures the SDK once at launch. [config] is a primitives-only map.
  Future<void> setup(Map<String, Object?> config) {
    throw UnimplementedError('setup() has not been implemented.');
  }

  /// Pushes the live auth [token] (+ optional [metadataJson]) into the native
  /// cache. The native delegate serves it synchronously on every request.
  Future<void> setCredentials(String token, String? metadataJson) {
    throw UnimplementedError('setCredentials() has not been implemented.');
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
