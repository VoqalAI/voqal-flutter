/// Value types for booking confirmations (2.2.0): who books a confirmed booking,
/// the structured details the host app receives, and the result it reports back.
///
/// Everything here crosses the method channel as primitives only.
library;

/// Who completes a booking once the user taps Confirm.
enum VoqalBookingMode {
  /// Voqal books it server-side (the 2.1.0 behavior). When the wallet is short,
  /// the SDK shows an Add-funds card instead. This is the default.
  server,

  /// Your app books it in `Voqal.onBookingConfirmed`, and Voqal reports the
  /// result to the assistant so the conversation continues with it.
  host;

  /// The wire value the native bridges expect (`server` | `host`).
  String get wireValue => name;
}

/// A short UI string with an English and an Arabic value. The SDK shows the one
/// matching the conversation's language.
class VoqalLocalizedText {
  /// Creates an immutable localized string. Neither value may be empty.
  const VoqalLocalizedText({required this.en, required this.ar})
    : assert(en != '', 'VoqalLocalizedText.en must not be empty'),
      assert(ar != '', 'VoqalLocalizedText.ar must not be empty');

  /// The English text.
  final String en;

  /// The Arabic text.
  final String ar;

  /// Serializes to a primitives-only map.
  Map<String, Object?> toMap() => <String, Object?>{'en': en, 'ar': ar};
}

/// The booking the user confirmed, from the confirm card's `details`.
///
/// Every field is optional: the engine fills what it knows, and an unexpected
/// type yields null rather than an error. Times are venue-local wall-clock
/// ([date] = `yyyy-MM-dd`, [start]/[end] = `HH:mm`). [fields] keeps the whole
/// object as sent, including keys this version doesn't name.
class VoqalBookingDetails {
  /// Creates booking details. Prefer [VoqalBookingDetails.fromMap].
  const VoqalBookingDetails({
    this.action,
    this.venue,
    this.court,
    this.providerId,
    this.spaceId,
    this.areaId,
    this.date,
    this.start,
    this.end,
    this.durationMinutes,
    this.price,
    this.deposit,
    this.currency,
    this.fields = const <String, Object?>{},
  });

  /// Parses the native `details` map leniently (numbers may arrive as doubles,
  /// ids as strings).
  factory VoqalBookingDetails.fromMap(Map<Object?, Object?> map) {
    final Map<String, Object?> fields = <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in map.entries)
        if (entry.key is String) entry.key! as String: entry.value,
    };
    return VoqalBookingDetails(
      action: _readString(fields['action']),
      venue: _readString(fields['venue']),
      court: _readString(fields['court']),
      providerId: _readInt(fields['provider_id']),
      spaceId: _readInt(fields['space_id']),
      areaId: _readInt(fields['area_id']),
      date: _readString(fields['date']),
      start: _readString(fields['start']),
      end: _readString(fields['end']),
      durationMinutes: _readInt(fields['duration_minutes']),
      price: _readDouble(fields['price']),
      deposit: _readDouble(fields['deposit']),
      currency: _readString(fields['currency']),
      fields: Map<String, Object?>.unmodifiable(fields),
    );
  }

  /// The tool the card confirms, e.g. `create_booking`.
  final String? action;

  /// The venue name.
  final String? venue;

  /// The court name.
  final String? court;

  /// The venue's provider id in your API.
  final int? providerId;

  /// The court's space id in your API.
  final int? spaceId;

  /// The area id in your API.
  final int? areaId;

  /// The local date, `yyyy-MM-dd`.
  final String? date;

  /// The local start time, `HH:mm`.
  final String? start;

  /// The local end time, `HH:mm`.
  final String? end;

  /// The booking length in minutes.
  final int? durationMinutes;

  /// The full price, when the assistant read it.
  final double? price;

  /// The deposit required to book, when the assistant read it.
  final double? deposit;

  /// The ISO currency of [price] and [deposit], e.g. `EGP`.
  final String? currency;

  /// The complete `details` object as sent by the engine.
  final Map<String, Object?> fields;
}

/// Whether your app's booking went through.
enum VoqalBookingStatus {
  /// The booking succeeded.
  success,

  /// The booking failed.
  failed;

  /// The wire value the native bridges expect (`success` | `failed`).
  String get wireValue => name;
}

/// What your app reports from `Voqal.onBookingConfirmed`. Voqal sends it to the
/// assistant as the booking's outcome, so the conversation continues with it.
class VoqalBookingResult {
  /// Creates an immutable booking result.
  const VoqalBookingResult({
    required this.status,
    this.message,
    this.code,
    this.reference,
  });

  /// Whether the booking succeeded.
  final VoqalBookingStatus status;

  /// A user-facing message in English or Arabic, e.g. `Booked! Ref #8812`.
  final String? message;

  /// A machine-readable code, e.g. your backend's error code on failure.
  final String? code;

  /// Your booking id or reference, on success.
  final String? reference;

  /// Serializes to a primitives-only map, omitting null fields.
  Map<String, Object?> toMap() => <String, Object?>{
    'status': status.wireValue,
    if (message != null) 'message': message,
    if (code != null) 'code': code,
    if (reference != null) 'reference': reference,
  };
}

String? _readString(Object? value) {
  if (value is String) return value;
  if (value is! num || !value.isFinite) return null;
  return value == value.roundToDouble() ? '${value.toInt()}' : '$value';
}

double? _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

int? _readInt(Object? value) {
  final double? number = _readDouble(value);
  if (number == null || !number.isFinite || number != number.roundToDouble()) {
    return null;
  }
  return number.toInt();
}
