import 'package:flutter_test/flutter_test.dart';
import 'package:voqal_flutter/voqal_flutter.dart';

void main() {
  test('filtered keeps the original names without a prefix', () {
    final Map<String, String> result = VoqalForwardedHeaders.filtered(
      <String, String>{'X-Tenant-Id': 't_42', 'Authorization': 'Bearer xyz'},
    );

    expect(result, <String, String>{
      'Authorization': 'Bearer xyz',
      'X-Tenant-Id': 't_42',
    });
  });

  test('filtered drops reserved control headers and empty names', () {
    final Map<String, String> result = VoqalForwardedHeaders.filtered(
      <String, String>{'x-voqal-key': 'leak', '': 'x', 'X-Safe': 'keep'},
    );

    expect(result, <String, String>{'X-Safe': 'keep'});
  });

  test('filtered caps the set at maxCount', () {
    final Map<String, String> many = <String, String>{
      for (int i = 0; i < VoqalForwardedHeaders.maxCount + 5; i++)
        'X-H-${i.toString().padLeft(2, '0')}': '$i',
    };

    expect(
      VoqalForwardedHeaders.filtered(many).length,
      VoqalForwardedHeaders.maxCount,
    );
  });

  test('namespaced prefixes each header with X-Voqal-Forward-', () {
    final Map<String, String> result = VoqalForwardedHeaders.namespaced(
      <String, String>{'X-Tenant-Id': 't_42'},
    );

    expect(result, <String, String>{'X-Voqal-Forward-X-Tenant-Id': 't_42'});
  });

  test('namespaced preserves the original name casing after the prefix', () {
    final Map<String, String> result = VoqalForwardedHeaders.namespaced(
      <String, String>{'X-Custom-Header': 'v'},
    );

    expect(result.keys.single, 'X-Voqal-Forward-X-Custom-Header');
  });

  test('namespaced forwards Authorization (a primary use case)', () {
    final Map<String, String> result = VoqalForwardedHeaders.namespaced(
      <String, String>{'Authorization': 'Bearer xyz'},
    );

    expect(result['X-Voqal-Forward-Authorization'], 'Bearer xyz');
  });

  test('namespaced drops reserved control headers regardless of casing', () {
    final Map<String, String> result = VoqalForwardedHeaders.namespaced(
      <String, String>{
        'X-Token': 'leak',
        'x-voqal-key': 'leak',
        'X-Request-Id': 'leak',
        'x-client-metadata': 'leak',
        'Content-Type': 'application/json',
        'accept': '*/*',
        'X-Safe': 'keep',
      },
    );

    expect(result, <String, String>{'X-Voqal-Forward-X-Safe': 'keep'});
  });

  test('namespaced drops empty header names', () {
    final Map<String, String> result = VoqalForwardedHeaders.namespaced(
      <String, String>{'': 'nameless', 'X-Ok': 'v'},
    );

    expect(result, <String, String>{'X-Voqal-Forward-X-Ok': 'v'});
  });

  test('namespaced caps the set at maxCount, keeping a sorted subset', () {
    final Map<String, String> input = <String, String>{
      for (int i = 0; i < VoqalForwardedHeaders.maxCount + 8; i++)
        'X-H-${i.toString().padLeft(2, '0')}': 'v$i',
    };

    final Map<String, String> result = VoqalForwardedHeaders.namespaced(input);

    expect(result.length, VoqalForwardedHeaders.maxCount);
    // Sorted, so the first maxCount names survive and the tail is dropped.
    expect(result.containsKey('X-Voqal-Forward-X-H-00'), isTrue);
    expect(result.containsKey('X-Voqal-Forward-X-H-31'), isTrue);
    expect(result.containsKey('X-Voqal-Forward-X-H-32'), isFalse);
  });

  test('namespaced returns an empty map for null input', () {
    expect(VoqalForwardedHeaders.namespaced(null), isEmpty);
  });

  test('namespaced returns an empty map for empty input', () {
    expect(
      VoqalForwardedHeaders.namespaced(const <String, String>{}),
      isEmpty,
    );
  });

  test('namespaced passes the value through unmodified', () {
    final Map<String, String> result = VoqalForwardedHeaders.namespaced(
      <String, String>{'X-Raw': '  spaced value  '},
    );

    expect(result['X-Voqal-Forward-X-Raw'], '  spaced value  ');
  });
}
