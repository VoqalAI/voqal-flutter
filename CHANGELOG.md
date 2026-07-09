## 1.3.6

Compatibility patch — no native SDK or public Dart API changes.

* Lowered the Dart SDK floor to `>=3.9.0` (was `^3.12.2`) so the plugin resolves on
  Flutter 3.35.x (Dart 3.9.2) through 3.44.x (Dart 3.12.2).
* Realigned the Android/Gradle toolchain (host-driven AGP/Kotlin, `compileSdk 35`) so the
  plugin builds under Flutter 3.35.7's Gradle 8.x as well as newer Flutter's Gradle 9.

## 1.3.5

Bundles native VoqalSDK **Android 1.3.5** + **iOS 1.3.3**.

* Android → voqal-sdk 1.3.5: copyable payment-link card, home-page balance card (mode=home),
  soft rounded card shadows (incl. under Confirm press / dimmed), configurable sheet height,
  single-font support, CTA icons.
* iOS → VoqalSDK 1.3.3: `VoqalTheme.font` now takes a UIFont (was `fontName`); light-mode card
  shadow corner fix. The Flutter `fontName` config string is mapped to a UIFont internally, so
  the Dart API is unchanged.

## 1.3.2

* Fix intermittent RTL layout on English messages (stray Arabic ؟ from STT).

## 1.3.1

* Multiple next-step suggestion pills under answers (via VoqalSDK 1.3.1).

## 0.0.1

- Initial thin Flutter bridge over the native Voqal iOS and Android SDKs.
- Public API: `Voqal.setup`, `setCredentials`, `prewarm`, `present`.
- iOS: vendored `VoqalSDK.xcframework`, minimum iOS 16.
- Android: depends on `ai.voqal:voqal-sdk`, minSdk 28 (distribution to be finalized).
- Security: push-credential model; no token logging, persistence, or read-back.