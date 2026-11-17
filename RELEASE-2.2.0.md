# voqal_flutter 2.2.0 release checklist

Branch `release/2.2.0` (cut from tag `2.1.0`). **Not tagged, not published.** The
native SDKs ship first; this plugin is tagged last.

## Native heads this branch was verified against
- iOS: VoqalAI/iOS-SDK `release/2.2.0` @ `2250c57`. The booking callbacks are on
  `VoqalBookingHandler` / `VoqalAddFundsHandler`, which the plugin's Coordinator
  adopts. Failed outcome reports arrive at `didFailWith` as `VoqalOutcomeReportError`.
- Android: VoqalAI/voqal-android `release/2.2.0` @ `fa71b8e`. It includes ef725cf,
  where failed outcome reports reach `onError` as `VoqalOutcomeReportError`.

If either native branch moves before it is published, redo steps 1 to 3 against the
published artifacts.

## Before tagging (in order)

1. **Android native published, and verified from the published AAR, not `~/.m2`.**
   - `ai.voqal:voqal-sdk:2.2.0` must be live on
     `https://raw.githubusercontent.com/VoqalAI/voqal-android-maven/main` (aar,
     module, pom with checksums, metadata).
   - `android/build.gradle.kts` already pins `2.2.0`, and the plugin adds no
     `mavenLocal()`.
   - The example's `example/android/build.gradle.kts` lists `mavenLocal()` first,
     and `~/.m2` holds a dev build. Before step 3, move it aside so Gradle has to
     download the published artifact:
     `mv ~/.m2/repository/ai/voqal/voqal-sdk/2.2.0 ~/.m2/repository/ai/voqal/voqal-sdk/2.2.0.dev`.
   - Then check that the AAR Gradle resolved (under
     `~/.gradle/caches/modules-2/files-2.1/ai.voqal/voqal-sdk/2.2.0/`) has the same
     `shasum -a 256` as the published `voqal-sdk-2.2.0.aar`.
2. **iOS native published, then re-vendored.**
   - `ios/Frameworks/VoqalSDK.xcframework` on this branch is a **DEV build** of
     `2250c57`.
   - Replace it with the contents of the published `VoqalSDK-2.2.0.zip` from
     `s3://voqal-sdk-releases-eu/` (the zip `VoqalAI/voqal-ios` 2.2.0 points at).
   - Confirm `shasum -a 256` of that zip equals the `Package.swift` checksum.
   - Run `pod install` in `example/ios`.
3. **Rebuild and retest on Flutter 3.35.7** (in `example/`, JDK 17):
   - `flutter analyze` and `flutter test`;
   - `flutter build ios --simulator` and `flutter build apk --debug`. Delete
     `example/build/app/intermediates/flutter` first: Gradle can repackage a stale
     Dart kernel after a toolchain switch.
   - `./gradlew :voqal_flutter:testDebugUnitTest` (from `example/android`);
   - `xcodebuild test -workspace Runner.xcworkspace -scheme Runner -only-testing:RunnerTests`
     (from `example/ios`, any iOS 16+ simulator);
   - Keep the 3.35.7-resolved `example/pubspec.lock`.
4. Commit, then `git tag 2.2.0` (bare, no `v`), push the branch and the tag, and
   merge to `main`.

## Versions already bumped
`pubspec.yaml` 2.2.0, `lib/src/voqal_flutter_version.dart` 2.2.0 (a test asserts they
match; native reports it as the wrapper version), podspec 2.2.0, README install ref 2.2.0.

## Engine dependency
Host mode (`bookingMode: host`) needs `create_booking` in the assistant version's
`client_handled_actions`. Otherwise `/voqal/execute` returns 400 `outcome_not_allowed`.
Server mode and the Add-funds card need the engine's `insufficient_funds` mapping.
