package ai.voqal.voqal_flutter

import ai.voqal.sdk.VoqalConfiguration
import ai.voqal.sdk.VoqalDelegate
import ai.voqal.sdk.VoqalHome
import ai.voqal.sdk.VoqalSDK
import ai.voqal.sdk.VoqalTheme
import android.app.Activity
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import android.util.Log
import androidx.activity.ComponentActivity
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Thin Flutter bridge over the native Voqal Android SDK.
 *
 * The SDK launches its own full-screen experience, so the bridge only forwards
 * configuration, pushed credentials, and the prewarm/present calls. The
 * MethodChannel is async but [VoqalDelegate] reads the token synchronously, so
 * Dart pushes credentials down (refreshing them on rotation) and the delegate
 * serves an in-memory cache. The token is never logged, persisted, or returned
 * across the channel.
 */
class VoqalFlutterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null

    // Latest credentials pushed from Dart. In-memory only — never persisted.
    @Volatile private var cachedToken: String = ""
    @Volatile private var cachedMetadata: String? = null

    private val delegate = object : VoqalDelegate {
        override fun getToken(): String = cachedToken
        override fun getMetadata(): String? = cachedMetadata
        override fun onUploadResult(result: String) {
            // No-op for v1 (matches iOS). Wire a Dart listener before forwarding.
        }

        override fun onError(error: Throwable) {
            // Log the Throwable only — never the token or metadata.
            Log.e("VoqalFlutter", "Voqal error", error)
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "voqal_flutter")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "setup" -> {
                val config = call.arguments as? Map<*, *>
                    ?: return result.error("bad_args", "setup expects a configuration map", null)
                VoqalSDK.setup(configuration(config))
                result.success(null)
            }

            "setCredentials" -> {
                val token = call.argument<String>("token")
                    ?: return result.error("bad_args", "setCredentials expects a token", null)
                cachedToken = token
                cachedMetadata = call.argument<String>("metadata")
                result.success(null)
            }

            "prewarm" -> {
                VoqalSDK.prewarm(delegate)
                result.success(null)
            }

            "present" -> {
                val host = activity as? ComponentActivity
                    ?: return result.error(
                        "no_activity",
                        "present requires a foreground ComponentActivity (FlutterActivity)",
                        null,
                    )
                VoqalSDK.present(host, delegate)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun configuration(config: Map<*, *>): VoqalConfiguration {
        // Note: `observability` is intentionally ignored — the Android SDK
        // exposes no observability surface yet (documented follow-up).
        return VoqalConfiguration(
            requestId = config["requestId"] as? String ?: "prod-flutter",
            apiKey = config["apiKey"] as? String,
            agentUrl = config["agentUrl"] as? String,
            theme = theme(config["theme"] as? Map<*, *>),
            home = home(config["home"] as? Map<*, *>),
            hapticsEnabled = config["hapticsEnabled"] as? Boolean ?: true,
            conversationTimeoutSeconds = (config["conversationTimeoutSeconds"] as? Number)?.toLong() ?: 7200L,
            presentationStyle = when (config["presentationStyle"] as? String) {
                "fullScreen" -> VoqalConfiguration.PresentationStyle.FULL_SCREEN
                else -> VoqalConfiguration.PresentationStyle.SHEET
            },
            headerTitle = config["headerTitle"] as? String,
            headerIcon = decodeIcon(config["headerIconPngBase64"] as? String),
        )
    }

    /** Decodes a base64 PNG (the header logo, sent from Dart) to a Bitmap. */
    private fun decodeIcon(base64: String?): Bitmap? {
        if (base64.isNullOrEmpty()) return null
        return try {
            val bytes = Base64.decode(base64, Base64.DEFAULT)
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        } catch (e: IllegalArgumentException) {
            Log.w("VoqalFlutter", "Ignoring malformed header icon", e)
            null
        }
    }

    private fun theme(map: Map<*, *>?): VoqalTheme {
        if (map == null) return VoqalTheme()
        return VoqalTheme(
            accent = map["accent"] as? String ?: "#2d5bff",
            accent2 = map["accent2"] as? String,
            appearance = appearance(map["appearance"] as? String),
            radius = (map["radius"] as? Number)?.toFloat() ?: 20f,
        )
    }

    private fun home(map: Map<*, *>?): VoqalHome {
        if (map == null) return VoqalHome()
        @Suppress("UNCHECKED_CAST")
        val ctas = (map["pinnedCTAs"] as? List<String>) ?: emptyList()
        return VoqalHome(
            userName = map["userName"] as? String,
            pinnedCTAs = ctas,
            showAgentGlance = map["showAgentGlance"] as? Boolean ?: true,
        )
    }

    private fun appearance(value: String?): VoqalTheme.Appearance = when (value) {
        "light" -> VoqalTheme.Appearance.LIGHT
        "dark" -> VoqalTheme.Appearance.DARK
        else -> VoqalTheme.Appearance.AUTO
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }
}
