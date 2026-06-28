import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

/// A brand image handed to the SDK (currently the header logo).
///
/// Images can't ride the method channel as Flutter widgets, so the bytes are
/// resolved at [Voqal.setup] time and sent to the native SDK as base64. The
/// native bridge decodes them to a `UIImage` (iOS) / `Bitmap` (Android). PNG is
/// recommended for a crisp logo with transparency.
class VoqalImage {
  const VoqalImage._({this.assetPath, this.bytes});

  /// A Flutter asset path, e.g. `VoqalImage.asset('assets/rabbit_logo.png')`.
  /// The asset must be declared under `flutter: assets:` in the host pubspec.
  const VoqalImage.asset(String assetPath) : this._(assetPath: assetPath);

  /// Raw image bytes (PNG recommended).
  const VoqalImage.bytes(Uint8List bytes) : this._(bytes: bytes);

  /// The bundled asset path, when constructed via [VoqalImage.asset].
  final String? assetPath;

  /// Raw bytes, when constructed via [VoqalImage.bytes].
  final Uint8List? bytes;

  /// Resolves the image to a base64 string for the method channel.
  ///
  /// Reads from the asset bundle when [assetPath] is set; async for that reason.
  Future<String> resolveBase64() async {
    if (bytes != null) return base64Encode(bytes!);
    final ByteData data = await rootBundle.load(assetPath!);
    return base64Encode(data.buffer.asUint8List());
  }
}
