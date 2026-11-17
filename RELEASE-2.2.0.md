# voqal_flutter 2.2.0 release checklist

Branch `release/2.2.0` (cut from tag `2.1.0`). **Not tagged, not published.** The
native SDKs ship first; this plugin is tagged last.

## Before tagging (in order)

1. **Android native published.** `ai.voqal:voqal-sdk:2.2.0` is live on
   `https://raw.githubusercontent.com/VoqalAI/voqal-android-maven/main` (aar, module,
   pom + checksums, metadata). `android/build.gradle.kts` already pins `2.2.0`, and
   nothing here adds `mavenLocal()`. The *example* app's `example/android/build.gradle.kts`
   lists `mavenLocal()` first (pre-existing), so verify against the published
   artifact with `~/.m2/repository/ai/voqal/voqal-sdk/2.2.0` moved aside.
2. **iOS native published, then re-vendored.** `ios/Frameworks/VoqalSDK.xcframework`
   on this branch is a **DEV build** from VoqalAI/iOS-SDK `release/2.2.0` @ `7399c69`.
   Replace it with the contents of the published `VoqalSDK-2.2.0.zip` from
   `s3://voqal-sdk-releases-eu/` (the same zip `VoqalAI/voqal-ios` 2.2.0 points at),
   then confirm `shasum -a 256` on that zip equals the `Package.swift` checksum. If
   native iOS moved past `7399c69`, this replacement picks the change up.
3. **Rebuild and retest on Flutter 3.35.7** (`example/`): `flutter analyze`,
   `flutter test`, `flutter build ios --simulator`, `flutter build apk --debug`,
   `./gradlew :voqal_flutter:testDebugUnitTest` (from `example/android`, JDK 17).
   Keep the 3.35.7-resolved `example/pubspec.lock`.
4. Commit, then `git tag 2.2.0` (bare, no `v`) and push the branch and tag. Merge to `main`.

## Versions already bumped
`pubspec.yaml` 2.2.0, `lib/src/voqal_flutter_version.dart` 2.2.0 (a test asserts they
match; native reports it as the wrapper version), podspec 2.2.0, README install ref 2.2.0.

## Engine dependency
Host mode (`bookingMode: host`) needs `create_booking` in the assistant version's
`client_handled_actions`. Otherwise `/voqal/execute` returns 400 `outcome_not_allowed`.
Server mode and the Add-funds card need the engine's `insufficient_funds` mapping.
