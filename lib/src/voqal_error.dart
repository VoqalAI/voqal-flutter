/// Errors the SDK reports to `Voqal.onError`.
library;

/// What kind of failure a [VoqalError] describes.
enum VoqalErrorType {
  /// Your app's booking result could not be reported to Voqal (2.2.0). The
  /// booking may already exist in your system while the assistant doesn't know
  /// it: reconcile using [VoqalError.confirmId] and [VoqalError.outcomeStatus].
  outcomeReport,

  /// Your `Voqal.onBookingConfirmed` handler threw. Voqal reported the booking
  /// as failed (`host_error`).
  bookingHandler,

  /// Any other SDK error (network, session, audio, ...).
  sdk,
}

/// A failure the SDK reports to `Voqal.onError`. Carries no user data: only
/// codes, ids, and error type names.
class VoqalError {
  /// Creates an error report.
  const VoqalError({
    required this.type,
    this.code,
    this.outcomeStatus,
    this.confirmId,
    this.detail,
  });

  /// Parses the native `onError` payload. An unknown `type` becomes [VoqalErrorType.sdk].
  factory VoqalError.fromMap(Map<Object?, Object?> map) => VoqalError(
    type: _types[map['type']] ?? VoqalErrorType.sdk,
    code: _readString(map['code']),
    outcomeStatus: _readString(map['outcomeStatus']),
    confirmId: _readString(map['confirmId']),
    detail: _readString(map['detail']),
  );

  static const Map<String, VoqalErrorType> _types = <String, VoqalErrorType>{
    'outcome_report': VoqalErrorType.outcomeReport,
    'booking_handler': VoqalErrorType.bookingHandler,
    'sdk': VoqalErrorType.sdk,
  };

  /// What kind of failure this is.
  final VoqalErrorType type;

  /// A machine-readable code. For [VoqalErrorType.outcomeReport], the engine's
  /// code (e.g. `outcome_not_allowed`, `confirm_not_found`) or `transport`; for
  /// [VoqalErrorType.bookingHandler], `host_error`.
  final String? code;

  /// For [VoqalErrorType.outcomeReport]: the outcome that couldn't be reported
  /// (`success`, `failed` or `unknown`).
  final String? outcomeStatus;

  /// The confirm card's id, when the error concerns a booking. Matches
  /// `VoqalBookingDetails.confirmId`.
  final String? confirmId;

  /// The underlying error's type name (e.g. `StateError`, `URLError`), never its message.
  final String? detail;

  @override
  String toString() =>
      'VoqalError(${type.name}, code: $code, outcomeStatus: $outcomeStatus, '
      'confirmId: $confirmId, detail: $detail)';
}

String? _readString(Object? value) => value is String ? value : null;
