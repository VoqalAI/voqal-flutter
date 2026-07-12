## 1.5.0

Bundles native VoqalSDK **iOS 1.5.0** + **Android 1.5.0**.

* **Optional action button.** An accent-colored call-to-action button can be shown to the
  right of the voice wave. Enable it with `VoqalConfig(actionButtonEnabled: true)` (optionally
  `actionButtonIcon` / `actionButtonDismissOnTap`), then set `voqal.onActionButtonTapped` to
  navigate from your Flutter app (e.g. `Navigator.push` to a checkout page). The SDK owns the
  button; your app owns the route. Adds the plugin's first native→Dart callback. Opt-in and
  fully backward compatible — existing integrations are unaffected.

## 1.4.0

Security fix — bundles native VoqalSDK **iOS 1.4.0** + **Android 1.4.0**.

* **Cross-account chat-history leak fixed.** The assistant now auto-detects when the
  signed-in account changes (from the token's identity) and wipes the retained
  conversation + starts a fresh session, so one user's chat can never appear for the
  next user after a logout/login. No app code change required — just this version bump.
  A refresh of the *same* account's token does not reset the chat.

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