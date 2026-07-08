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