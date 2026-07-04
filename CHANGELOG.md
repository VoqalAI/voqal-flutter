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