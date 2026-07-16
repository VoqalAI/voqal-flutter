// Host-driven toolchain: AGP + Kotlin versions come from the consuming app's
// settings.gradle pluginManagement (via the Flutter plugin loader), NOT pinned here.
// A hard-pinned buildscript classpath (previously AGP 9.0.1 / Kotlin 2.3.20) forced
// Gradle 9 and broke apps on Flutter 3.35.x (Gradle 8.12 / AGP 8.9.1).
plugins {
    id("com.android.library")
}

group = "ai.voqal.voqal_flutter"
version = "1.0-SNAPSHOT"

// Built-in-Kotlin compatibility (Flutter's KGP migration). AGP >= 9 (Flutter 3.44+)
// supplies Kotlin itself; applying KGP there triggers a deprecation warning that will
// become a hard failure. Older Flutter (3.35.x / AGP 8.9) has no built-in Kotlin, so
// the plugin must apply KGP itself. Gate on the host's AGP major version to do both.
val agpMajorVersion = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.substringBefore('.').toInt()
if (agpMajorVersion < 9) {
    apply(plugin = "org.jetbrains.kotlin.android")
}

allprojects {
    repositories {
        google()
        mavenCentral()
        // Voqal Android SDK is distributed as a Maven repository served over
        // raw.githubusercontent.com (public, no auth). See VoqalAI/voqal-android-maven.
        maven { url = uri("https://raw.githubusercontent.com/VoqalAI/voqal-android-maven/main") }
    }
}

android {
    namespace = "ai.voqal.voqal_flutter"

    // Matches the native voqal-sdk AAR (compileSdk 35). 35 is supported by every AGP
    // from 8.6 up, so this builds on Flutter 3.35.x (AGP 8.9.1) and newer alike.
    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        // Voqal native SDK floor (Android 9). The host app must use minSdk >= 28.
        minSdk = 28
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

// Set the Kotlin JVM target via the project extension (not `android { kotlinOptions }`),
// so it works whether KGP was applied by us (AGP < 9) or is built into AGP (>= 9).
project.extensions.configure(org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java) {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("ai.voqal:voqal-sdk-rabbit:1.5.3") // Rabbit-custom native Android SDK (paired with the Rabbit iOS VoqalSDK vendored under ios/Frameworks)
    // sentry-android (not the SDK-only artifact) so we get Android lifecycle/ANR/crash handlers.
    implementation("io.sentry:sentry-android:7.22.6")
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}
