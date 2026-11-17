## 2.2.0

Bundles native **iOS 2.2.0** + **Android 2.2.0**. Booking confirmations can now
be completed by your app, and a short wallet gets an Add-funds button.

* **`VoqalConfig.bookingMode`**: `server` (default, unchanged from 2.1.0) or
  `host`. In host mode, tapping **Confirm** on a booking card calls
  **`Voqal.onBookingConfirmed`** with a `VoqalBookingDetails` (venue, court,
  provider/space/area ids, venue-local date and times, duration, price/deposit/currency).
  Your handler books it and returns a `VoqalBookingResult` (success/failed, message,
  code, reference). Voqal reports it to the assistant, so the conversation continues
  with the outcome. The handler is **required** in host mode, and Voqal never books
  it for you: `null` or no handler is reported as failed (`host_no_result`), a throw
  as failed (`host_error`), and a timeout (`hostActionTimeoutSeconds`, default 300)
  as unknown (`host_timeout`), and the assistant asks the user to check their
  bookings. Voqal stops waiting after the timeout and ignores a late result.
  `VoqalBookingDetails.confirmId` identifies the card (single-use); use it as your
  booking API's idempotency key so a retry never books twice.
* **Add-funds card.** When Voqal books a booking server-side and the wallet is short,
  the assistant shows the amount due and a button titled by
  `VoqalConfig.addFundsButtonTitle` (English + Arabic). Tapping it calls
  **`Voqal.onAddFundsTapped(amount, currency)`**. With `dismissOnAddFunds` (default
  true) the assistant closes first, so the screen you open stays in front.
* **`Voqal.onError`.** A Dart error callback carrying a `VoqalError`:
  `outcomeReport` when your booking result couldn't be recorded by Voqal (with
  `outcomeStatus`, `code` and `confirmId`, so you can reconcile), `bookingHandler`
  when `onBookingConfirmed` threw, and `sdk` for other SDK errors (type name
  only). Errors carry no user data.
* **SDK version reporting.** Every request now carries `X-Voqal-SDK-Version`
  (`flutter-2.2.0/ios-2.2.0` or `flutter-2.2.0/android-2.2.0`), `X-Voqal-Platform:
  flutter` and `X-Voqal-App-Version`, so Voqal can see which build each app runs.
* **Behaviour change: forwarded headers now arrive under their own name.** Since
  2.0.0 the plugin prefixed `forwardedHeaders` with `X-Voqal-Forward-` and the native
  SDK prefixed them again, so your backend received `X-Voqal-Forward-<name>` instead of
  the documented `<name>`. 2.2.0 prefixes once: an `X-Tenant-Id` you return now reaches
  your backend as `X-Tenant-Id`. **If your backend compensated for the bug by reading
  `X-Voqal-Forward-<name>`, switch it to `<name>` when you upgrade.**
  `VoqalForwardedHeaders.filtered()` is new; `namespaced()` still returns the wire form.
* **Opt-in and drop-in.** Apart from the forwarded-header fix above, with no booking
  options set 2.2.0 behaves exactly like 2.1.0 (every 2.1.0 widget, including the tappable `action_list`, is carried over).
* Android plugin: fixes a unit test that failed since 1.5.0 (the plugin could not be
  constructed off-device).

## 2.1.0

Bundles native **iOS 2.1.0** + **Android 2.1.0** — the tappable `action_list` widget.

* **Tappable option lists.** The agent can now answer with a list whose rows are
  tap targets: tapping a row sends that row's utterance as your next message, so a
  user picks an offered option ("here are the free slots") instead of retyping it.
  Rows render exactly like the existing `list` widget plus a trailing chevron and
  press feedback. Taps route through the same guarded path as the suggestion chips,
  so they are inert while a turn is in flight, count as a text turn (no speech), and
  stay live in scroll-back.
* **No Flutter API change and no app code to write.** The plugin is a wrapper — the
  native SDK owns every pixel and decodes the render spec itself — so this is a
  version bump only. `VoqalConfig`, `Voqal`, and the method channel are unchanged;
  2.1.0 is a drop-in over 2.0.1.
* **Android also starts reporting `meta.platform` on every turn.** The native Android
  2.1.0 artifact carries one fix beyond the widget: Android turns previously reached the
  engine with no channel set, so those conversations were not attributable on the Voqal
  dashboard. Nothing in your app changes — but Android conversations that were invisible
  will start appearing. iOS already reported this.
* The widget is additive on the wire: apps still on 2.0.x decode an unknown kind and
  leave it unrendered, so the engine can emit `action_list` without gating on the
  installed SDK version.

## 2.0.1

Routes to the self-serve engine.

* The baked engine URL is now `https://api.voqal.ai/v3`, the deployment that
  serves assistants configured in the Voqal dashboard. 2.0.0 pointed at `/v2`,
  which predates self-serve, so a dashboard-published assistant's publishable
  key resolved against the wrong deployment. No API changes — drop-in over 2.0.0.
* Native SDKs bumped to iOS 2.0.1 (vendored) and `ai.voqal:voqal-sdk:2.0.1`.

## 2.0.0

Header passthrough — send your own headers straight through Voqal to your backend.

* **`VoqalConfig.forwardedHeaders`.** An optional provider — `Map<String, String>
  Function()?` — of developer headers to forward to your own backend on every
  turn-serving request. Return a fresh map each call; it is read live, so a
  rotating value (e.g. a short-lived `Authorization`) always sends its current
  value. Each entry reaches the engine namespaced as `X-Voqal-Forward-<name>`, and
  the engine strips the prefix and forwards it to your tenant's backend(s) — zero
  dashboard configuration. Reserved Voqal control headers (`X-Token`,
  `X-Voqal-Key`, `X-Request-Id`, `X-Client-Metadata`, `Content-Type`, `Accept`)
  are dropped if supplied so they can never override the SDK's own headers, while
  `Authorization` is forwarded; at most 32 headers are sent. Opt-in and fully
  backward compatible — integrations that set no provider are unaffected and issue
  no extra native traffic. Ships the send side of the cross-platform SDK 2.0.0
  header-passthrough protocol, matching iOS, Android, and React Native.

## 1.5.2

Bundles native **Android 1.5.2** (iOS unchanged at 1.5.0 — not affected).

* **Fix: Android conversation history.** The Android SDK never attached prior turns
  to a request, so the agent could forget earlier questions/answers whenever the
  engine's stored session history wasn't available (session rotation, DB fallback).
  Android now threads history on every text turn exactly like iOS always has.
  All Android versions up to 1.5.1 carry the latent bug — upgrading is recommended.

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