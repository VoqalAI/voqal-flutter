/// Immutable value types for configuring the Voqal SDK.
///
/// Every type serializes to a primitives-only map via [toMap] so it can cross
/// the Flutter method channel and be reconstructed by the native bridges. No
/// type here ever carries the end-user auth token — credentials are pushed
/// separately through `Voqal.setCredentials` and held in a native cache only.
library;

/// Requested color scheme for the assistant surface.
enum VoqalAppearance {
  /// Always light.
  light,

  /// Always dark.
  dark,

  /// Follows the system setting at present-time.
  auto;

  /// The wire value the native bridges expect (`light` | `dark` | `auto`).
  String get wireValue => name;
}

/// Visual theme tokens. A small set reskins the entire surface and every widget;
/// the native SDK derives the full scale (surfaces, hairlines, text) from these.
class VoqalTheme {
  /// Creates an immutable theme.
  const VoqalTheme({
    this.accent = defaultAccent,
    this.accent2,
    this.appearance = VoqalAppearance.auto,
    this.fontName,
    this.radius,
  });

  /// Default accent used when a host supplies none (`#2d5bff`).
  static const String defaultAccent = '#2d5bff';

  /// Primary brand color as a hex string. Drives the orb, highlights, primary buttons.
  final String accent;

  /// Optional gradient-pair end as a hex string. Falls back to [accent] when null.
  final String? accent2;

  /// Light, dark, or system-driven appearance.
  final VoqalAppearance appearance;

  /// Optional display font family name (iOS only). Null uses the native default.
  final String? fontName;

  /// Base corner radius for cards and the sheet. Null uses the native default.
  final double? radius;

  /// Serializes to a primitives-only map, omitting null fields.
  Map<String, Object?> toMap() => <String, Object?>{
    'accent': accent,
    if (accent2 != null) 'accent2': accent2,
    'appearance': appearance.wireValue,
    if (fontName != null) 'fontName': fontName,
    if (radius != null) 'radius': radius,
  };
}

/// Opening-glance customization shown the instant the sheet opens.
class VoqalHome {
  /// Creates an immutable home configuration.
  const VoqalHome({
    this.userName,
    this.pinnedCTAs = const <String>[],
    this.showAgentGlance = true,
  });

  /// Optional display name used in the greeting. Null renders a greeting only.
  final String? userName;

  /// Quick-action prompts rendered as tappable chips, before the agent's suggestions.
  final List<String> pinnedCTAs;

  /// Whether to render the agent-authored glance widgets.
  final bool showAgentGlance;

  /// Serializes to a primitives-only map, omitting null fields.
  Map<String, Object?> toMap() => <String, Object?>{
    if (userName != null) 'userName': userName,
    'pinnedCTAs': List<String>.unmodifiable(pinnedCTAs),
    'showAgentGlance': showAgentGlance,
  };
}

/// Off-device diagnostics options (errors, traces, breadcrumbs).
///
/// Forwarded into the native iOS config. On Android the native SDK exposes no
/// observability surface yet, so these options are ignored there (a documented
/// follow-up). No Sentry pod ships with this plugin in v1.
class VoqalObservability {
  /// Creates immutable observability options.
  const VoqalObservability({
    this.dsn,
    this.enabled = true,
    this.scrubPII = true,
    this.tracesSampleRate = 1.0,
    this.environment,
  });

  /// Optional Sentry DSN override. Null uses the native baked default.
  final String? dsn;

  /// Whether off-device reporting is active.
  final bool enabled;

  /// Whether PII is scrubbed from outgoing events. Keep true in production.
  final bool scrubPII;

  /// Fraction of transactions sampled for tracing, in `[0.0, 1.0]`.
  final double tracesSampleRate;

  /// Optional environment tag. Null lets the native SDK infer it from `requestId`.
  final String? environment;

  /// Serializes to a primitives-only map, omitting null fields.
  Map<String, Object?> toMap() => <String, Object?>{
    if (dsn != null) 'dsn': dsn,
    'enabled': enabled,
    'scrubPII': scrubPII,
    'tracesSampleRate': tracesSampleRate,
    if (environment != null) 'environment': environment,
  };
}

/// Top-level SDK configuration supplied once via `Voqal.setup`.
///
/// Tokens are intentionally NOT part of this object — they rotate frequently and
/// are pushed separately via `Voqal.setCredentials`.
class VoqalConfig {
  /// Creates an immutable configuration.
  ///
  /// [requestId] defaults to `prod-flutter`; a missing value must never silently
  /// route to staging, so the default carries the `prod-` prefix the engine uses
  /// for production MCP routing.
  const VoqalConfig({
    required this.apiKey,
    this.requestId = defaultRequestId,
    this.agentUrl,
    this.theme = const VoqalTheme(),
    this.home = const VoqalHome(),
    this.conversationTimeoutSeconds,
    this.hapticsEnabled,
    this.observability,
  });

  /// Default environment-routing request id (production MCP).
  static const String defaultRequestId = 'prod-flutter';

  /// Publishable tenant key (`pk_live_...`), sent as `X-Voqal-Key`.
  final String apiKey;

  /// Environment-routing request id. Engine routes by prefix (`prod-` / `stg-`).
  final String requestId;

  /// Optional HTTPS engine base URL override. Null uses the SDK's baked endpoint.
  final String? agentUrl;

  /// Visual theme tokens.
  final VoqalTheme theme;

  /// Opening-glance configuration.
  final VoqalHome home;

  /// Idle window after which the conversation resets. Null uses the native default.
  final int? conversationTimeoutSeconds;

  /// Whether haptic feedback is enabled. Null uses the native default.
  final bool? hapticsEnabled;

  /// Optional off-device diagnostics options (iOS only in v1).
  final VoqalObservability? observability;

  /// Serializes to a primitives-only map for the method channel.
  ///
  /// Omits null fields so the native bridges fall back to their own defaults.
  Map<String, Object?> toMap() => <String, Object?>{
    'apiKey': apiKey,
    'requestId': requestId,
    if (agentUrl != null) 'agentUrl': agentUrl,
    'theme': theme.toMap(),
    'home': home.toMap(),
    if (conversationTimeoutSeconds != null)
      'conversationTimeoutSeconds': conversationTimeoutSeconds,
    if (hapticsEnabled != null) 'hapticsEnabled': hapticsEnabled,
    if (observability != null) 'observability': observability!.toMap(),
  };
}
