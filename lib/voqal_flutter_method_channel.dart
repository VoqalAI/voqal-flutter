import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

import 'voqal_flutter_platform_interface.dart';

/// [MethodChannel]-based implementation of [VoqalFlutterPlatform].
///
/// Arguments are passed straight through and are **never logged** here — the
/// payload of [setCredentials] is sensitive and must not surface in any log,
/// in Dart or in the native handlers.
class MethodChannelVoqalFlutter extends VoqalFlutterPlatform {
  /// The channel shared with the native iOS/Android plugins.
  @visibleForTesting
  final MethodChannel methodChannel = const MethodChannel('voqal_flutter');

  bool _handlerRegistered = false;

  /// Registers the native→Dart handler exactly once, lazily — NOT in the constructor.
  /// `VoqalFlutterPlatform.instance` is accessed (e.g. in tests) before the binary
  /// messenger binding is initialized, and `setMethodCallHandler` asserts on that. Every
  /// outbound call registers first, and native only calls back after setup/present, so the
  /// handler is always in place before any inbound call can arrive.
  @visibleForTesting
  void ensureHandlerRegistered() {
    if (_handlerRegistered) return;
    _handlerRegistered = true;
    methodChannel.setMethodCallHandler(_handleNativeCall);
  }

  /// Routes native-initiated calls to the matching Dart handler. Currently only
  /// `onActionButtonTapped`; unknown methods are ignored so older Dart keeps working.
  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onActionButtonTapped') {
      onActionButtonTapped?.call();
    }
    return null;
  }

  @override
  Future<void> setup(Map<String, Object?> config) {
    ensureHandlerRegistered();
    return methodChannel.invokeMethod<void>('setup', config);
  }

  @override
  Future<void> setCredentials(String token, String? metadataJson) {
    ensureHandlerRegistered();
    return methodChannel.invokeMethod<void>('setCredentials', <String, Object?>{
      'token': token,
      'metadata': metadataJson,
    });
  }

  @override
  Future<void> prewarm() {
    ensureHandlerRegistered();
    return methodChannel.invokeMethod<void>('prewarm');
  }

  @override
  Future<void> present() {
    ensureHandlerRegistered();
    return methodChannel.invokeMethod<void>('present');
  }
}
