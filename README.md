# voqal_flutter

Voice-first assistant SDK for Flutter — a thin wrapper over the native Voqal iOS
and Android SDKs. The native SDK is a self-contained shell: it presents its own
full-screen voice/chat UI, performs all networking, and holds every secret. This
plugin forwards configuration + pushed credentials and opens the assistant.
Flutter renders no Voqal UI.

## Install

In your app's `pubspec.yaml`:

```yaml
dependencies:
  voqal_flutter:
    git:
      url: https://github.com/VoqalAI/voqal-flutter.git
      ref: 2.2.0
```

### iOS

- Minimum deployment target **iOS 16**. In `ios/Podfile`:

  ```ruby
  platform :ios, '16.0'
  ```

- The native SDK requests microphone access for voice. Add to `ios/Runner/Info.plist`:

  ```xml
  <key>NSMicrophoneUsageDescription</key>
  <string>Voqal uses the microphone for voice requests.</string>
  ```

The `VoqalSDK.xcframework` is vendored inside the plugin, so `pod install` needs
no network.

### Android

- **`minSdk 28`** (the native SDK floor). In `android/app/build.gradle.kts`:

  ```kotlin
  defaultConfig { minSdk = 28 }
  ```

- The host `MainActivity` **must extend `FlutterFragmentActivity`** (an androidx
  `ComponentActivity`), which the SDK's `present(activity, …)` requires. The
  default `FlutterActivity` does not extend `ComponentActivity`, so `present()`
  fails with it:

  ```kotlin
  import io.flutter.embedding.android.FlutterFragmentActivity

  class MainActivity : FlutterFragmentActivity()
  ```

- The SDK declares `INTERNET` and `RECORD_AUDIO` and requests audio at runtime —
  no manual permission wiring needed.

- The native Android SDK (`ai.voqal:voqal-sdk:2.1.0`) ships from the public Maven
  repo `https://raw.githubusercontent.com/VoqalAI/voqal-android-maven/main` (no
  auth). A Flutter plugin **cannot** contribute repositories to the host app, so
  **you must add this repo to your app** — in `android/build.gradle.kts`:

  ```kotlin
  allprojects {
      repositories {
          maven { url = uri("https://raw.githubusercontent.com/VoqalAI/voqal-android-maven/main") }
      }
  }
  ```

  (or in `settings.gradle.kts` `dependencyResolutionManagement.repositories` if
  your project uses centralized repository management).

## Usage

```dart
import 'package:voqal_flutter/voqal_flutter.dart';

final voqal = Voqal();

// Once, at launch:
await voqal.setup(const VoqalConfig(
  apiKey: 'pk_live_…',            // publishable key (public)
  requestId: 'prod-yourtenant',
  theme: VoqalTheme(accent: '#1F7A4D'),
  home: VoqalHome(userName: 'Yaseen', pinnedCTAs: ["Where's my order?"]),
));

// Push the live auth token; call again whenever it rotates:
await voqal.setCredentials(yourAuthToken,
    metadataJson: '{"country_code":"EGY","user_id":"123"}');

await voqal.prewarm();           // optional: warm the connection

// On a button tap:
await voqal.present();
```

See `example/` for a runnable app (Rabbit tenant, production engine).

### Opening it: your button, and presentation style

- **Open from your own button/action** — call `voqal.present()` from any widget's
  `onPressed` (a button, icon, FAB, nav action). That's the supported path; there
  is no separate native orb widget in Flutter (build your own button + `present()`).
- **Presentation style** — by default the assistant slides up as a **sheet** the
  user can swipe down to dismiss. For a **full, edge-to-edge app screen** (no
  swipe-to-dismiss; close via the button), set it in the config:

  ```dart
  await voqal.setup(VoqalConfig(
    apiKey: 'pk_live_…',
    presentationStyle: VoqalPresentationStyle.fullScreen, // default: .sheet
  ));
  ```

  It's a setup-time setting, so apply it before `present()`. Works identically on
  iOS and Android.

### Branding the header (name + logo)

By default the sheet header shows **"Voqal"** with the default mark. Override both:

```dart
await voqal.setup(VoqalConfig(
  apiKey: 'pk_live_…',
  headerTitle: 'Rabbit',                                  // header name
  headerIcon: const VoqalImage.asset('assets/logo.png'),  // header logo (PNG)
));
```

`headerIcon` accepts `VoqalImage.asset('<path>')` (declare it under `flutter:
assets:` in your pubspec) or `VoqalImage.bytes(...)`. The bytes are resolved at
`setup` and handed to the native SDK as a `UIImage` / `Bitmap`.

**Also customizable** — via `VoqalTheme`: accent colors (`accent`, `accent2`),
`appearance` (light/dark/auto), `fontName`, corner `radius`; via `VoqalHome`: the
greeting `userName` + `pinnedCTAs`; plus `hapticsEnabled` and
`conversationTimeoutSeconds`.

### Forwarding your own headers to your backend (v2.0.0)

Need your backend to receive an extra header on every turn — a rotating
`Authorization`, a tenant id, anything? Return them from `forwardedHeaders`:

```dart
await voqal.setup(VoqalConfig(
  apiKey: 'pk_live_…',
  forwardedHeaders: () => {
    'Authorization': 'Bearer ${myAuth.currentAccessToken}',
    'X-Tenant-Id': myTenantId,
  },
));
```

The provider is **read live** — return a fresh map so a rotating value always
sends its current value. Each entry reaches the engine namespaced as
`X-Voqal-Forward-<name>`, and the engine strips the prefix and forwards it to your
own backend(s) on every turn. **No dashboard configuration.**

Reserved Voqal control headers (`X-Token`, `X-Voqal-Key`, `X-Request-Id`,
`X-Client-Metadata`, `Content-Type`, `Accept`) are dropped if you supply them — they
can never override the SDK's own headers — while `Authorization` **is** forwarded.
At most 32 headers are sent. Omit `forwardedHeaders` (the default) and nothing
changes: no header is forwarded and no extra work is done.

### Booking confirmations: book in your app, or top up a wallet (v2.2.0)

When the assistant offers a booking, the user taps **Confirm** on its card. You
choose who completes it with `bookingMode`:

* **`VoqalBookingMode.server`** (default): Voqal books it, as in 2.1.0. If the
  user's wallet is short, Voqal shows an **Add funds** card instead. Its button
  calls `onAddFundsTapped` so you can open your wallet screen.
* **`VoqalBookingMode.host`**: Voqal hands the booking to `onBookingConfirmed`,
  which you **must** set in this mode. You book it with your own API and return
  the outcome. Voqal reports it to the assistant, so the conversation continues
  with it ("you're booked, ref 8812"). Voqal never books it for you in this mode.

```dart
final voqal = Voqal();

await voqal.setup(const VoqalConfig(
  apiKey: 'pk_live_…',
  bookingMode: VoqalBookingMode.host, // or .server (default)
  addFundsButtonTitle: VoqalLocalizedText(en: 'Add funds', ar: 'إضافة رصيد'),
  dismissOnAddFunds: true,            // close the assistant before the callback
  hostActionTimeoutSeconds: 300,      // then report the outcome as unknown
));

// Host mode: book it yourself and report the outcome.
voqal.onBookingConfirmed = (VoqalBookingDetails booking) async {
  // booking.providerId / spaceId / areaId, booking.date ("2026-11-17"),
  // booking.start / end ("21:00", venue-local wall-clock), booking.durationMinutes,
  // booking.price / deposit / currency (nullable). booking.fields has the raw map;
  // its numbers may arrive as int or double depending on the platform, so prefer
  // the typed getters or read them as `num`.
  // booking.confirmId is unique per card and single-use: pass it as your
  // idempotency key so a retry never books twice.
  final response = await myApi.createBooking(
    idempotencyKey: booking.confirmId,
    providerId: booking.providerId!,
    spaceId: booking.spaceId!,
    date: booking.date!,
    start: booking.start!,
    end: booking.end!,
  );
  if (response.ok) {
    return VoqalBookingResult(
      status: VoqalBookingStatus.success,
      message: response.messageEn,      // English or Arabic, whichever you have
      reference: '${response.bookingId}',
    );
  }
  return VoqalBookingResult(
    status: VoqalBookingStatus.failed,
    code: response.errorCode,           // e.g. DEPOSIT_REQUIRED
    message: response.messageEn,
  );
};

// Server mode only: the Add-funds card's button (the card appears when Voqal
// books and the wallet is short). The assistant has already closed.
voqal.onAddFundsTapped = (double? amount, String? currency) {
  navigatorKey.currentState?.pushNamed('/wallet', arguments: amount);
};
```

* In host mode, returning **`null`** or leaving the handler unset is reported as
  a failed booking (`host_no_result`). That is a bug in the app, not a fallback.
* A handler that **throws** is reported as failed (`host_error`). The thrown
  error goes to `FlutterError.onError` with its stack; only its type crosses to
  native.
* A handler that doesn't answer within `hostActionTimeoutSeconds` is reported
  as **unknown** (`host_timeout`), because the booking may still have gone
  through. The assistant asks the user to check their bookings.
* **Expect to be abandoned.** After the timeout, Voqal stops waiting. A Dart
  `Future` can't be cancelled, so your handler keeps running, and its result is
  ignored when it arrives. Keep bookings safe to retry by sending `confirmId`
  as your idempotency key, and don't open UI from a result that arrives late.
* Both handlers are process-global. Clear them in `dispose()` if they capture
  widget state.
* Set `onAddFundsTapped` whenever you can get a server-mode booking. Without it,
  the Add-funds button closes the assistant and nothing else happens.
* **Tell Voqal before you ship host mode.** We enable it for your assistant. Until
  then Voqal rejects the outcome your app reports, so the user would see an error
  even though your app made the booking.

## Security

This wrapper preserves the native SDK's security model and adds nothing:

- **All cryptography stays native.** A hardware-bound P-256 device key (iOS
  Secure Enclave / Android Keystore) signs every request with a DPoP-style
  proof; the engine-minted session token is held **in memory only**. The bridge
  never sees a private key, a session token, or a signing secret.
- **Only the publishable key** (`pk_live_…`) lives in the app — it is public by
  design. There is no secret key in the binary.
- **Push-credential model.** The auth token is pushed via `setCredentials`,
  cached in native memory, and served synchronously to the SDK. It is never
  persisted (no Keychain / `UserDefaults` / `SharedPreferences` / disk), never
  logged, and never returned across the method channel to Dart.
- **HTTPS only.** Requests go to the baked production endpoint
  (`https://api.voqal.ai/v3`); the plugin ships no cleartext exception.

## Status

- **iOS:** complete, built and run on the simulator.
- **Android:** code-complete; pulls the SDK from the public `voqal-android-maven`
  repo; pending on-device verification.
- Off-device diagnostics (Sentry) and SwiftPM support are planned follow-ups;
  v1 ships CocoaPods (iOS) + Gradle (Android).
