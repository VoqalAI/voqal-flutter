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
      ref: v0.0.1
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

> The plugin pulls `ai.voqal:voqal-sdk:1.0.3` from the public Maven repo at
> `https://raw.githubusercontent.com/VoqalAI/voqal-android-maven/main` (no auth
> required) — already wired in the plugin's `build.gradle.kts`.

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
  (`https://api.voqal.ai/v2`); the plugin ships no cleartext exception.

## Status

- **iOS:** complete, built and run on the simulator.
- **Android:** code-complete; pulls the SDK from the public `voqal-android-maven`
  repo; pending on-device verification.
- Off-device diagnostics (Sentry) and SwiftPM support are planned follow-ups;
  v1 ships CocoaPods (iOS) + Gradle (Android).
