/// Namespacing for developer-supplied headers forwarded to the host's own backend.
///
/// Each developer header is sent to the engine as its own request header with a
/// fixed prefix — `X-Voqal-Forward-<name>: <value>`. The engine strips the prefix
/// and forwards the header to the tenant's backend(s) on every call, so a host can
/// push arbitrary headers (a rotating `Authorization`, a tenant id, …) straight
/// through Voqal with zero dashboard configuration. See the cross-platform
/// `PROTOCOL.md` (SDK 2.0.0 header passthrough); this mirrors the iOS
/// `VoqalForwardedHeaders`.
library;

/// Turns a host's developer headers into the namespaced wire form and enforces the
/// two hard rules: a Voqal control header can never be overridden, and the set is
/// bounded. Pure and side-effect-free so the namespacing, control-header
/// precedence, and cap are unit-tested directly.
abstract final class VoqalForwardedHeaders {
  /// The fixed prefix the engine matches (case-insensitively) and strips verbatim.
  static const String prefix = 'X-Voqal-Forward-';

  /// Upper bound on forwarded headers, matching the engine's cap. Excess is
  /// dropped rather than failing the turn.
  static const int maxCount = 32;

  /// Headers the SDK owns; a developer key that collides (case-insensitively) is
  /// dropped so it can never displace the SDK's auth/routing headers. Mirrors the
  /// engine's control-header precedence as defense in depth.
  ///
  /// `Authorization` is deliberately absent — forwarding it to the host's backend
  /// is a primary use case, and the engine still refuses to let it override a
  /// tenant's configured auth header.
  static const Set<String> _reservedControlHeaders = <String>{
    'x-token',
    'x-voqal-key',
    'x-request-id',
    'x-client-metadata',
    'content-type',
    'accept',
  };

  /// The namespaced headers to send: empty names and control-header collisions
  /// removed, sorted by original name, capped at [maxCount], each prefixed with
  /// [prefix]. Sorting makes the forwarded set deterministic so the cap drops a
  /// stable subset.
  ///
  /// Returns an empty map when [developerHeaders] is null or yields nothing to
  /// send, so a host that never opts in stays byte-identical to the pre-2.0 SDK.
  static Map<String, String> namespaced(Map<String, String>? developerHeaders) {
    if (developerHeaders == null || developerHeaders.isEmpty) {
      return const <String, String>{};
    }

    final List<MapEntry<String, String>> retained =
        developerHeaders.entries
            .where((MapEntry<String, String> header) =>
                header.key.isNotEmpty &&
                !_reservedControlHeaders.contains(header.key.toLowerCase()))
            .toList()
          ..sort((MapEntry<String, String> a, MapEntry<String, String> b) =>
              a.key.compareTo(b.key));

    return <String, String>{
      for (final MapEntry<String, String> header in retained.take(maxCount))
        '$prefix${header.key}': header.value,
    };
  }
}
