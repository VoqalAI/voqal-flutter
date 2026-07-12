import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:voqal_flutter/voqal_flutter.dart';
import 'package:voqal_flutter/voqal_flutter_method_channel.dart';
import 'package:voqal_flutter/voqal_flutter_platform_interface.dart';

/// Simulates the native side invoking a method back into Dart on the plugin channel.
Future<void> _sendNativeCall(String method) async {
  const StandardMethodCodec codec = StandardMethodCodec();
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        'voqal_flutter',
        codec.encodeMethodCall(MethodCall(method)),
        (_) {},
      );
}

class _FakeVoqalPlatform extends VoqalFlutterPlatform
    with MockPlatformInterfaceMixin {
  final List<String> calls = <String>[];
  Map<String, Object?>? lastConfig;
  String? lastToken;
  String? lastMetadata;

  @override
  Future<void> setup(Map<String, Object?> config) async {
    calls.add('setup');
    lastConfig = config;
  }

  @override
  Future<void> setCredentials(String token, String? metadataJson) async {
    calls.add('setCredentials');
    lastToken = token;
    lastMetadata = metadataJson;
  }

  @override
  Future<void> prewarm() async => calls.add('prewarm');

  @override
  Future<void> present() async => calls.add('present');
}

void main() {
  test('default platform instance is the method channel', () {
    expect(VoqalFlutterPlatform.instance, isA<MethodChannelVoqalFlutter>());
  });

  test(
    'Voqal forwards each call to the platform with the right data',
    () async {
      final _FakeVoqalPlatform fake = _FakeVoqalPlatform();
      VoqalFlutterPlatform.instance = fake;
      final Voqal voqal = Voqal();

      await voqal.setup(const VoqalConfig(apiKey: 'pk_test'));
      await voqal.setCredentials('tok', metadataJson: '{"user_id":"1"}');
      await voqal.prewarm();
      await voqal.present();

      expect(fake.calls, <String>[
        'setup',
        'setCredentials',
        'prewarm',
        'present',
      ]);
      expect(fake.lastConfig!['apiKey'], 'pk_test');
      // A missing requestId must never silently route to staging.
      expect(fake.lastConfig!['requestId'], 'prod-flutter');
      expect(fake.lastToken, 'tok');
      expect(fake.lastMetadata, '{"user_id":"1"}');
    },
  );

  test('config never serializes a token (push-only surface)', () {
    final Map<String, Object?> map = const VoqalConfig(
      apiKey: 'pk_test',
    ).toMap();
    expect(map.containsKey('token'), isFalse);
    expect(map.toString().contains('token'), isFalse);
  });

  test('presentationStyle defaults to sheet and serializes the wire value', () {
    expect(
      const VoqalConfig(apiKey: 'pk').toMap()['presentationStyle'],
      'sheet',
    );
    expect(
      const VoqalConfig(
        apiKey: 'pk',
        presentationStyle: VoqalPresentationStyle.fullScreen,
      ).toMap()['presentationStyle'],
      'fullScreen',
    );
  });

  test('headerTitle is omitted when null and serialized when set', () {
    expect(
      const VoqalConfig(apiKey: 'pk').toMap().containsKey('headerTitle'),
      isFalse,
    );
    expect(
      const VoqalConfig(
        apiKey: 'pk',
        headerTitle: 'Rabbit',
      ).toMap()['headerTitle'],
      'Rabbit',
    );
  });

  test('action button keys are omitted when disabled', () {
    final Map<String, Object?> map = const VoqalConfig(apiKey: 'pk').toMap();
    expect(map.containsKey('actionButtonEnabled'), isFalse);
    expect(map.containsKey('actionButtonDismissOnTap'), isFalse);
  });

  test('action button keys are serialized when enabled', () {
    final Map<String, Object?> map = const VoqalConfig(
      apiKey: 'pk',
      actionButtonEnabled: true,
      actionButtonDismissOnTap: false,
    ).toMap();
    expect(map['actionButtonEnabled'], true);
    expect(map['actionButtonDismissOnTap'], false);
  });

  test('native onActionButtonTapped call routes to the Dart handler', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final MethodChannelVoqalFlutter platform = MethodChannelVoqalFlutter();
    VoqalFlutterPlatform.instance = platform;
    platform.ensureHandlerRegistered();

    int fired = 0;
    final Voqal voqal = Voqal();
    voqal.onActionButtonTapped = () => fired++;

    await _sendNativeCall('onActionButtonTapped');
    expect(fired, 1);

    // Unknown inbound methods are ignored so older Dart keeps working.
    await _sendNativeCall('someFutureMethod');
    expect(fired, 1);

    // A null handler is a safe no-op (no throw).
    voqal.onActionButtonTapped = null;
    await _sendNativeCall('onActionButtonTapped');
    expect(fired, 1);
  });
}
