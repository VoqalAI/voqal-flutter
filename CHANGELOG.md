## 1.5.4 (Rabbit custom build)

Consume via the `rabbit-1.5.4` git tag. Bundles native iOS `1.5.0-rabbit.4` +
Android `voqal-sdk-rabbit:1.5.4`.

* **Deep-investigation hardening.** Cart control: product rows re-key their
  count by product id (a reshuffled list can no longer show another product's
  count on iOS); the 300ms cross-fade window is tap-guarded on both platforms
  (no stray server increments/decrements); the outgoing pill never displays 0;
  VoiceOver/TalkBack announce the control and quantity changes.
* **Coverage:** +18 iOS unit tests (proof-of-possession crypto, per-script font
  table, currency splitter, streamed-delta accumulation) and +16 Android tests
  (barge-in, currency splitter, font routing, cart guards). iOS 84/84,
  Android 197/197; voice verified end-to-end over both transports incl. Arabic.

## 1.5.3 (Rabbit custom build)

Consume via the `rabbit-1.5.3` git tag. Bundles native iOS `1.5.0-rabbit.3` +
Android `voqal-sdk-rabbit:1.5.3`.

* **Rabbit's exact add-to-cart control.** The product card's stepper + Add button
  is replaced with Rabbit's own `RMAddToCartButton` (style-for-style): a lime
  (`#E0FF16`) circular "+" that cross-fades (300ms) into the counter pill
  (`#7A1FA2`, lime −/+ icons, white count) once a product is in the cart.
  Cart semantics are now per-unit: every + / − silently fires one
  `add_to_cart` increment/decrement — no chat bubbles, no agent turns.

## 1.5.2 (Rabbit custom build)

Consume via the `rabbit-1.5.2` git tag. Bundles native Android
`voqal-sdk-rabbit:1.5.2` (iOS unchanged — not affected).

* **Fix: Android conversation history.** Prior turns are now attached to every
  request, so follow-up questions keep their context even when the engine's
  stored session history isn't available. Same fix as mainline 1.5.2.

## 1.5.1 (Rabbit custom build)

Consume via the `rabbit-1.5.1` git tag.

* **Exact Rabbit brand colors.** `primaryColor` `#00573F` is now the baked accent
  (Add button, price amount, orb) and `darkPrimaryColor` `#003D2C` colors the
  currency token — both straight from Rabbit's `MyThemeData`, replacing the
  placeholder green. Android artifact is `ai.voqal:voqal-sdk-rabbit:1.5.1`.

## 1.5.0+rabbit.1 (Rabbit custom build)

Rabbit-only build on top of 1.5.0 — consume via the `rabbit-1.5.0` git tag.

* **Rabbit brand fonts baked in.** Lota Grotesque (Latin) and Janna LT (Arabic) ship
  inside the native SDKs and register automatically; every piece of SDK text uses them,
  resolved per string (Arabic → Janna, Latin → Lota). `VoqalTheme.fontName` is now
  ignored — no host font setup needed or honored.
* **Product card matches Rabbit's in-app AutoCompleteCard.** 96pt image (radius 8,
  hairline border, inner padding, fit — not cropped), stacked name/unit/price column,
  14pt regular name (#1F1F1F), 14pt unit (#7B7B7B), price with the currency token at
  10pt in Rabbit green. Stepper + Add-to-cart behavior unchanged.
* Android dependency is `ai.voqal:voqal-sdk-rabbit:1.5.0`; iOS vendored framework is
  `1.5.0-rabbit.1`. The 1.5.0 action button (checkout redirect) is unchanged.

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