#
# Voqal Flutter plugin — thin bridge over the native VoqalSDK (vendored XCFramework).
# Run `pod lib lint voqal_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'voqal_flutter'
  s.version          = '0.0.1'
  s.summary          = 'Voqal — voice-first assistant SDK for Flutter.'
  s.description      = <<-DESC
Thin Flutter bridge over the native VoqalSDK. The SDK presents its own full-screen
voice/chat experience; this plugin only forwards configuration, pushed credentials,
and the prewarm/present calls. All cryptography (Secure Enclave P-256 device key,
per-request DPoP proof, in-memory session token) lives in the native SDK.
                       DESC
  s.homepage         = 'https://voqal.ai'
  s.license          = { :type => 'Commercial', :file => '../LICENSE' }
  s.author           = { 'Voqal' => 'hello@voqal.ai' }
  s.source           = { :path => '.' }
  s.source_files     = 'voqal_flutter/Sources/voqal_flutter/**/*'
  s.dependency 'Flutter'

  # Linking the VoqalSentry bridge sources (Sources/.../VoqalSentry/) + this pod
  # turns observability on by default: the core SDK discovers VoqalSentryAutoStart
  # via the ObjC runtime at setup() and starts Sentry with the baked Voqal DSN.
  s.dependency 'Sentry', '~> 8.0'
  s.platform = :ios, '16.0'

  # The native SDK ships inside the plugin — pod install needs no network.
  s.vendored_frameworks = 'Frameworks/VoqalSDK.xcframework'

  # Flutter.framework has no i386 slice. The vendored xcframework DOES ship an
  # arm64 simulator slice, so do NOT exclude arm64 for the simulator.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
