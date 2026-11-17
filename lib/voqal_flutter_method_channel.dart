import 'package:flutter/foundation.dart'
    show ErrorDescription, FlutterError, FlutterErrorDetails, visibleForTesting;
import 'package:flutter/services.dart';

import 'src/voqal_booking.dart';
import 'src/voqal_forwarded_headers.dart';
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

  /// Error code native receives when the host's booking handler throws. The
  /// native SDK reports it to the engine as a failed booking (`host_error`).
  @visibleForTesting
  static const String hostErrorCode = 'host_error';

  /// Routes native-initiated calls to the matching Dart handler. Unknown methods
  /// return null so a newer native SDK keeps working with older Dart.
  Future<Object?> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onActionButtonTapped':
        onActionButtonTapped?.call();
        return null;
      case 'onBookingConfirmed':
        return _confirmBooking(call.arguments);
      case 'onAddFundsTapped':
        _tapAddFunds(call.arguments);
        return null;
    }
    return null;
  }

  /// Runs the host's booking handler and returns its result as a map, or null
  /// when no handler is set or it declines; native reports null as a failed
  /// booking (`host_no_result`).
  ///
  /// A throwing handler is reported in Dart with its full stack, then surfaces
  /// to native as [hostErrorCode] carrying only the error's type, so nothing the
  /// host's error message contains reaches native logs or telemetry.
  Future<Map<String, Object?>?> _confirmBooking(Object? arguments) async {
    final Future<VoqalBookingResult?> Function(VoqalBookingDetails)? handler =
        onBookingConfirmed;
    if (handler == null) return null;
    final Map<Object?, Object?> details = arguments is Map
        ? arguments.cast<Object?, Object?>()
        : const <Object?, Object?>{};
    try {
      final VoqalBookingResult? result = await handler(
        VoqalBookingDetails.fromMap(details),
      );
      return result?.toMap();
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'voqal_flutter',
          context: ErrorDescription('while running Voqal.onBookingConfirmed'),
        ),
      );
      throw PlatformException(
        code: hostErrorCode,
        message: '${error.runtimeType}',
      );
    }
  }

  void _tapAddFunds(Object? arguments) {
    final Map<Object?, Object?> args = arguments is Map
        ? arguments.cast<Object?, Object?>()
        : const <Object?, Object?>{};
    final Object? amount = args['amount'];
    final Object? currency = args['currency'];
    onAddFundsTapped?.call(
      amount is num ? amount.toDouble() : null,
      currency is String ? currency : null,
    );
  }

  @override
  Future<void> setup(Map<String, Object?> config) async {
    ensureHandlerRegistered();
    await methodChannel.invokeMethod<void>('setup', config);
    await _syncForwardedHeaders();
  }

  @override
  Future<void> setCredentials(String token, String? metadataJson) async {
    ensureHandlerRegistered();
    await methodChannel.invokeMethod<void>('setCredentials', <String, Object?>{
      'token': token,
      'metadata': metadataJson,
    });
    await _syncForwardedHeaders();
  }

  @override
  Future<void> setForwardedHeaders(Map<String, String> headers) {
    ensureHandlerRegistered();
    return methodChannel.invokeMethod<void>(
      'setForwardedHeaders',
      <String, Object?>{'headers': headers},
    );
  }

  @override
  Future<void> prewarm() async {
    ensureHandlerRegistered();
    await _syncForwardedHeaders();
    await methodChannel.invokeMethod<void>('prewarm');
  }

  @override
  Future<void> present() async {
    ensureHandlerRegistered();
    await _syncForwardedHeaders();
    await methodChannel.invokeMethod<void>('present');
  }

  /// Reads the live [forwardedHeaders] provider, filters its output (names
  /// unchanged; native adds the `X-Voqal-Forward-` prefix once), and pushes the
  /// result to native so the next turn carries the current set. It runs before
  /// warming (`prewarm`/`present`) and after each `setup`/`setCredentials`, so a
  /// rotating header is captured at every touchpoint that precedes a turn.
  ///
  /// A no-op when no provider is set, so integrations that never opt in issue no
  /// extra channel traffic and behave byte-identically to the pre-2.0 plugin.
  Future<void> _syncForwardedHeaders() {
    final Map<String, String> Function()? provider = forwardedHeaders;
    if (provider == null) return Future<void>.value();
    return setForwardedHeaders(VoqalForwardedHeaders.filtered(provider()));
  }
}
