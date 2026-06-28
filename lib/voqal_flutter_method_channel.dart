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

  @override
  Future<void> setup(Map<String, Object?> config) =>
      methodChannel.invokeMethod<void>('setup', config);

  @override
  Future<void> setCredentials(String token, String? metadataJson) =>
      methodChannel.invokeMethod<void>('setCredentials', <String, Object?>{
        'token': token,
        'metadata': metadataJson,
      });

  @override
  Future<void> prewarm() => methodChannel.invokeMethod<void>('prewarm');

  @override
  Future<void> present() => methodChannel.invokeMethod<void>('present');
}
