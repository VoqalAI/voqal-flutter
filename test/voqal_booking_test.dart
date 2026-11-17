import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voqal_flutter/voqal_flutter.dart';
import 'package:voqal_flutter/voqal_flutter_method_channel.dart';
import 'package:voqal_flutter/voqal_flutter_platform_interface.dart';

const StandardMethodCodec _codec = StandardMethodCodec();

/// Simulates native invoking [method] on the plugin channel and returns Dart's
/// decoded reply. Throws [PlatformException] when Dart replied with an error.
Future<Object?> _callFromNative(String method, [Object? arguments]) async {
  ByteData? reply;
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        'voqal_flutter',
        _codec.encodeMethodCall(MethodCall(method, arguments)),
        (ByteData? data) => reply = data,
      );
  return _codec.decodeEnvelope(reply!);
}

/// The details map as the iOS bridge sends it: every JSON number is a double.
const Map<String, Object?> _iosDetails = <String, Object?>{
  'action': 'create_booking',
  'confirm_id': '3f2b8c1e-5d4a-4e6b-9c7d-1a2b3c4d5e6f',
  'venue': 'Zamalek',
  'court': 'Court B',
  'provider_id': 206.0,
  'space_id': 1322.0,
  'area_id': 43.0,
  'date': '2026-11-17',
  'start': '21:00',
  'end': '22:00',
  'duration_minutes': 60.0,
  'price': null,
  'deposit': 30.0,
  'currency': 'EGP',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelVoqalFlutter platform;
  late Voqal voqal;

  setUp(() {
    platform = MethodChannelVoqalFlutter();
    VoqalFlutterPlatform.instance = platform;
    platform.ensureHandlerRegistered();
    voqal = Voqal();
  });

  group('VoqalConfig booking fields', () {
    test('default to server mode, the default title, dismiss, and 300s', () {
      final Map<String, Object?> map = const VoqalConfig(apiKey: 'pk').toMap();

      expect(map['bookingMode'], 'server');
      expect(map['addFundsButtonTitle'], <String, Object?>{
        'en': 'Add funds',
        'ar': 'إضافة رصيد',
      });
      expect(map['dismissOnAddFunds'], true);
      expect(map['hostActionTimeoutSeconds'], 300);
    });

    test('serialize host mode and custom values', () {
      final Map<String, Object?> map = const VoqalConfig(
        apiKey: 'pk',
        bookingMode: VoqalBookingMode.host,
        addFundsButtonTitle: VoqalLocalizedText(en: 'Top up', ar: 'اشحن'),
        dismissOnAddFunds: false,
        hostActionTimeoutSeconds: 120,
      ).toMap();

      expect(map['bookingMode'], 'host');
      expect(map['addFundsButtonTitle'], <String, Object?>{
        'en': 'Top up',
        'ar': 'اشحن',
      });
      expect(map['dismissOnAddFunds'], false);
      expect(map['hostActionTimeoutSeconds'], 120);
    });

    test('a non-positive timeout fails fast in debug', () {
      expect(
        () => VoqalConfig(apiKey: 'pk', hostActionTimeoutSeconds: 0),
        throwsAssertionError,
      );
    });
  });

  group('VoqalBookingDetails.fromMap', () {
    test('reads the iOS double-typed ids as ints', () {
      final VoqalBookingDetails details = VoqalBookingDetails.fromMap(
        _iosDetails,
      );

      expect(
        <Object?>[
          details.providerId,
          details.spaceId,
          details.areaId,
          details.durationMinutes,
        ],
        <Object?>[206, 1322, 43, 60],
      );
    });

    test('reads strings, nullable money, and the currency', () {
      final VoqalBookingDetails details = VoqalBookingDetails.fromMap(
        _iosDetails,
      );

      expect(
        <Object?>[
          details.action,
          details.venue,
          details.court,
          details.date,
          details.start,
          details.end,
          details.price,
          details.deposit,
          details.currency,
        ],
        <Object?>[
          'create_booking',
          'Zamalek',
          'Court B',
          '2026-11-17',
          '21:00',
          '22:00',
          null,
          30.0,
          'EGP',
        ],
      );
    });

    test('reads the confirm id the engine binds the outcome to', () {
      final VoqalBookingDetails details = VoqalBookingDetails.fromMap(
        _iosDetails,
      );

      expect(details.confirmId, '3f2b8c1e-5d4a-4e6b-9c7d-1a2b3c4d5e6f');
    });

    test('accepts numeric strings and rejects fractional ids', () {
      final VoqalBookingDetails details = VoqalBookingDetails.fromMap(
        <Object?, Object?>{'provider_id': '206', 'space_id': 13.5},
      );

      expect(<int?>[details.providerId, details.spaceId], <int?>[206, null]);
    });

    test('keeps unknown fields and drops non-string keys', () {
      final VoqalBookingDetails details = VoqalBookingDetails.fromMap(
        <Object?, Object?>{'extra': 'kept', 7: 'dropped'},
      );

      expect(details.fields, <String, Object?>{'extra': 'kept'});
    });

    test('mistyped values become null instead of throwing', () {
      final VoqalBookingDetails details = VoqalBookingDetails.fromMap(
        <Object?, Object?>{
          'venue': <int>[1],
          'deposit': true,
        },
      );

      expect(<Object?>[details.venue, details.deposit], <Object?>[null, null]);
    });
  });

  test('VoqalBookingResult.toMap omits null fields', () {
    const VoqalBookingResult result = VoqalBookingResult(
      status: VoqalBookingStatus.failed,
      code: 'DEPOSIT_REQUIRED',
    );

    expect(result.toMap(), <String, Object?>{
      'status': 'failed',
      'code': 'DEPOSIT_REQUIRED',
    });
  });

  group('native onBookingConfirmed', () {
    tearDown(() => voqal.onBookingConfirmed = null);

    test('with no handler replies null (native reports host_no_result)', () async {
      final Object? reply = await _callFromNative(
        'onBookingConfirmed',
        _iosDetails,
      );

      expect(reply, isNull);
    });

    test('passes parsed details to the handler', () async {
      VoqalBookingDetails? received;
      voqal.onBookingConfirmed = (VoqalBookingDetails details) async {
        received = details;
        return null;
      };

      await _callFromNative('onBookingConfirmed', _iosDetails);

      expect(received?.spaceId, 1322);
    });

    test('replies with the handler result as a map', () async {
      voqal.onBookingConfirmed = (_) async => const VoqalBookingResult(
        status: VoqalBookingStatus.success,
        message: 'Booked! Ref #8812',
        reference: '8812',
      );

      final Object? reply = await _callFromNative(
        'onBookingConfirmed',
        _iosDetails,
      );

      expect(reply, <String, Object?>{
        'status': 'success',
        'message': 'Booked! Ref #8812',
        'reference': '8812',
      });
    });

    test('replies null when the handler declines', () async {
      voqal.onBookingConfirmed = (_) async => null;

      final Object? reply = await _callFromNative(
        'onBookingConfirmed',
        _iosDetails,
      );

      expect(reply, isNull);
    });

    test('a throwing handler replies host_error with only the type', () async {
      final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
      final FlutterExceptionHandler? previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);
      voqal.onBookingConfirmed = (_) async =>
          throw StateError('card 4111 declined');

      final Future<Object?> reply = _callFromNative(
        'onBookingConfirmed',
        _iosDetails,
      );

      await expectLater(
        reply,
        throwsA(
          isA<PlatformException>()
              .having((PlatformException e) => e.code, 'code', 'host_error')
              .having(
                (PlatformException e) => e.message,
                'message',
                'StateError',
              ),
        ),
      );
      expect(reported.single.exception, isA<StateError>());
    });

    test('a non-map argument still reaches the handler', () async {
      VoqalBookingDetails? received;
      voqal.onBookingConfirmed = (VoqalBookingDetails details) async {
        received = details;
        return null;
      };

      await _callFromNative('onBookingConfirmed');

      expect(received?.fields, isEmpty);
    });
  });

  group('native onAddFundsTapped', () {
    tearDown(() => voqal.onAddFundsTapped = null);

    test('delivers amount as a double and the currency', () async {
      final List<Object?> received = <Object?>[];
      voqal.onAddFundsTapped = (double? amount, String? currency) =>
          received.addAll(<Object?>[amount, currency]);

      await _callFromNative('onAddFundsTapped', <String, Object?>{
        'amount': 30,
        'currency': 'EGP',
      });

      expect(received, <Object?>[30.0, 'EGP']);
    });

    test('delivers nulls when the shortfall is unknown', () async {
      final List<Object?> received = <Object?>[];
      voqal.onAddFundsTapped = (double? amount, String? currency) =>
          received.addAll(<Object?>[amount, currency]);

      await _callFromNative('onAddFundsTapped', <String, Object?>{});

      expect(received, <Object?>[null, null]);
    });

    test('with no handler is a safe no-op', () async {
      final Object? reply = await _callFromNative('onAddFundsTapped');

      expect(reply, isNull);
    });
  });

  test('setup reports the plugin version for the wrapper identity', () async {
    final List<MethodCall> sent = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(platform.methodChannel, (
          MethodCall call,
        ) async {
          sent.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(platform.methodChannel, null),
    );

    await voqal.setup(const VoqalConfig(apiKey: 'pk'));

    final Map<Object?, Object?> args =
        sent.single.arguments as Map<Object?, Object?>;
    expect(args['wrapperVersion'], voqalFlutterVersion);
  });

  test('the wrapper version matches pubspec.yaml', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final String? version = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);

    expect(version, voqalFlutterVersion);
  });
}
