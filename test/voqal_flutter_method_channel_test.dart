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
    platform.forwardedHeaders = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Map<Object?, Object?> argsOf(MethodCall call) =>
      call.arguments as Map<Object?, Object?>;

  MethodCall callNamed(String method) =>
      log.firstWhere((MethodCall c) => c.method == method);

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

  test('no forwarded-header provider issues no setForwardedHeaders call', () async {
    await platform.setup(<String, Object?>{'apiKey': 'pk'});
    await platform.setCredentials('tok', null);
    await platform.prewarm();
    await platform.present();

    expect(
      log.any((MethodCall c) => c.method == 'setForwardedHeaders'),
      isFalse,
    );
  });

  test('prewarm pushes namespaced forwarded headers before warming', () async {
    platform.forwardedHeaders = () => <String, String>{
      'Authorization': 'Bearer xyz',
      'X-Tenant-Id': 't_42',
    };

    await platform.prewarm();

    // Headers must reach native before the warm call so the first turn carries them.
    expect(log.map((MethodCall c) => c.method).toList(), <String>[
      'setForwardedHeaders',
      'prewarm',
    ]);
    expect(argsOf(callNamed('setForwardedHeaders'))['headers'], <String, String>{
      'X-Voqal-Forward-Authorization': 'Bearer xyz',
      'X-Voqal-Forward-X-Tenant-Id': 't_42',
    });
  });

  test('present pushes namespaced forwarded headers before presenting', () async {
    platform.forwardedHeaders = () => <String, String>{'X-A': '1'};

    await platform.present();

    expect(log.map((MethodCall c) => c.method).toList(), <String>[
      'setForwardedHeaders',
      'present',
    ]);
  });

  test('setup and setCredentials push forwarded headers after their call', () async {
    platform.forwardedHeaders = () => <String, String>{'X-A': '1'};

    await platform.setup(<String, Object?>{'apiKey': 'pk'});
    await platform.setCredentials('tok', null);

    expect(log.map((MethodCall c) => c.method).toList(), <String>[
      'setup',
      'setForwardedHeaders',
      'setCredentials',
      'setForwardedHeaders',
    ]);
  });

  test('the provider is read live on each turn-serving call', () async {
    int calls = 0;
    platform.forwardedHeaders = () {
      calls++;
      return <String, String>{'X-Seq': '$calls'};
    };

    await platform.prewarm();
    await platform.present();

    // Two turn-serving calls → two independent reads of the live provider.
    expect(calls, 2);
    expect(
      log
          .where((MethodCall c) => c.method == 'setForwardedHeaders')
          .map((MethodCall c) => argsOf(c)['headers'])
          .toList(),
      <Map<String, String>>[
        <String, String>{'X-Voqal-Forward-X-Seq': '1'},
        <String, String>{'X-Voqal-Forward-X-Seq': '2'},
      ],
    );
  });
}
