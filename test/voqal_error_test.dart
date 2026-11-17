import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voqal_flutter/voqal_flutter.dart';
import 'package:voqal_flutter/voqal_flutter_method_channel.dart';
import 'package:voqal_flutter/voqal_flutter_platform_interface.dart';

const StandardMethodCodec _codec = StandardMethodCodec();

/// Simulates native invoking [method] on the plugin channel; returns Dart's raw reply.
Future<ByteData?> _callFromNative(String method, [Object? arguments]) async {
  ByteData? reply;
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        'voqal_flutter',
        _codec.encodeMethodCall(MethodCall(method, arguments)),
        (ByteData? data) => reply = data,
      );
  return reply;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Voqal voqal;
  final List<VoqalError> received = <VoqalError>[];

  setUp(() {
    final MethodChannelVoqalFlutter platform = MethodChannelVoqalFlutter();
    VoqalFlutterPlatform.instance = platform;
    platform.ensureHandlerRegistered();
    voqal = Voqal()..onError = received.add;
  });

  tearDown(() {
    received.clear();
    voqal.onError = null;
    voqal.onBookingConfirmed = null;
  });

  group('VoqalError.fromMap', () {
    test('reads an outcome-report failure', () {
      final VoqalError error = VoqalError.fromMap(<Object?, Object?>{
        'type': 'outcome_report',
        'outcomeStatus': 'success',
        'code': 'confirm_not_found',
        'confirmId': 'c-1',
      });

      expect(
        <Object?>[error.type, error.outcomeStatus, error.code, error.confirmId],
        <Object?>[
          VoqalErrorType.outcomeReport,
          'success',
          'confirm_not_found',
          'c-1',
        ],
      );
    });

    test('reads an SDK error with its native type name', () {
      final VoqalError error = VoqalError.fromMap(<Object?, Object?>{
        'type': 'sdk',
        'detail': 'URLError',
      });

      expect(<Object?>[error.type, error.detail], <Object?>[
        VoqalErrorType.sdk,
        'URLError',
      ]);
    });

    test('treats an unknown type as an SDK error', () {
      final VoqalError error = VoqalError.fromMap(<Object?, Object?>{
        'type': 'from_the_future',
      });

      expect(error.type, VoqalErrorType.sdk);
    });

    test('ignores mistyped fields', () {
      final VoqalError error = VoqalError.fromMap(<Object?, Object?>{
        'type': 'outcome_report',
        'code': 42,
      });

      expect(error.code, isNull);
    });
  });

  test('native onError reaches the Dart handler', () async {
    await _callFromNative('onError', <String, Object?>{
      'type': 'outcome_report',
      'outcomeStatus': 'failed',
      'code': 'transport',
      'confirmId': 'c-2',
    });

    expect(received.single.confirmId, 'c-2');
  });

  test('native onError with no handler is a safe no-op', () async {
    voqal.onError = null;

    final ByteData? reply = await _callFromNative('onError', <String, Object?>{
      'type': 'sdk',
    });

    expect(_codec.decodeEnvelope(reply!), isNull);
  });

  test('a throwing booking handler is reported as a bookingHandler error', () async {
    final FlutterExceptionHandler? previous = FlutterError.onError;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = previous);
    voqal.onBookingConfirmed = (_) async => throw StateError('declined');

    await _callFromNative('onBookingConfirmed', <String, Object?>{
      'confirm_id': 'c-3',
    });

    expect(
      <Object?>[
        received.single.type,
        received.single.code,
        received.single.confirmId,
        received.single.detail,
      ],
      <Object?>[VoqalErrorType.bookingHandler, 'host_error', 'c-3', 'StateError'],
    );
  });

  test('an onError handler that throws never breaks the booking reply', () async {
    final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
    final FlutterExceptionHandler? previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);
    voqal.onError = (_) => throw StateError('handler bug');
    voqal.onBookingConfirmed = (_) async => throw StateError('declined');

    final ByteData? reply = await _callFromNative('onBookingConfirmed');

    expect(
      () => _codec.decodeEnvelope(reply!),
      throwsA(
        isA<PlatformException>().having(
          (PlatformException e) => e.code,
          'code',
          'host_error',
        ),
      ),
    );
  });
}
