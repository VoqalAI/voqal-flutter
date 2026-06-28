import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voqal_flutter/voqal_flutter_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelVoqalFlutter platform = MethodChannelVoqalFlutter();
  const MethodChannel channel = MethodChannel('voqal_flutter');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          log.add(call);
          return null;
        });
  });

  tearDown(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('setup forwards the config map', () async {
    await platform.setup(<String, Object?>{
      'apiKey': 'pk_test',
      'requestId': 'prod-flutter',
    });
    expect(log.single.method, 'setup');
    final Map<Object?, Object?> args =
        log.single.arguments as Map<Object?, Object?>;
    expect(args['apiKey'], 'pk_test');
    expect(args['requestId'], 'prod-flutter');
  });

  test('setCredentials forwards token and metadata', () async {
    await platform.setCredentials('tok', '{"user_id":"1"}');
    expect(log.single.method, 'setCredentials');
    final Map<Object?, Object?> args =
        log.single.arguments as Map<Object?, Object?>;
    expect(args['token'], 'tok');
    expect(args['metadata'], '{"user_id":"1"}');
  });

  test('prewarm and present invoke their methods with no arguments', () async {
    await platform.prewarm();
    await platform.present();
    expect(log.map((MethodCall c) => c.method).toList(), <String>[
      'prewarm',
      'present',
    ]);
    expect(log.every((MethodCall c) => c.arguments == null), isTrue);
  });
}
