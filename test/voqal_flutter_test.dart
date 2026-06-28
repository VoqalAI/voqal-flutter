import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:voqal_flutter/voqal_flutter.dart';
import 'package:voqal_flutter/voqal_flutter_method_channel.dart';
import 'package:voqal_flutter/voqal_flutter_platform_interface.dart';

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
}
