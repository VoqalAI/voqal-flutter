package ai.voqal.voqal_flutter

import ai.voqal.sdk.VoqalSDK
import ai.voqal.sdk.diagnostics.VoqalLogSink
import android.content.Context
import io.sentry.Breadcrumb
import io.sentry.Sentry
import io.sentry.SentryLevel
import io.sentry.SentryOptions
import io.sentry.android.core.SentryAndroid

/**
 * Bridges the native Voqal Android SDK's diagnostics stream onto Sentry,
 * mirroring the iOS `VoqalSentry` bridge.
 *
 * Default-on with the baked Voqal DSN, PII-scrubbed, and overridable through the
 * Flutter `observability` config. Diagnostic `event`s become breadcrumbs and
 * `error`s become captured exceptions (or messages) carrying the surrounding
 * fields as scrubbed extras.
 */
object VoqalSentryBridge {

    // Same project/DSN as the iOS bridge. This is an ingest key, not a secret.
    private const val BAKED_DSN =
        "https://e497e80a89ec061fb167ec2699e72889@o4511559480770560.ingest.de.sentry.io/4511559486275664"

    private const val DEFAULT_ENVIRONMENT = "unknown"

    @Volatile
    private var initialized = false

    /** Resolved observability options, parsed from the Flutter `observability` sub-map. */
    data class Options(
        val dsn: String?,
        val environment: String?,
        val scrubPii: Boolean,
        val tracesSampleRate: Double,
    )

    /**
     * Initializes Sentry once and registers the diagnostics sink. Idempotent:
     * repeated calls (e.g. a second `setup`) are ignored so we never re-init the
     * Sentry client or attach duplicate sinks.
     */
    @Synchronized
    fun enable(context: Context, options: Options) {
        if (initialized) {
            return
        }
        val resolvedDsn = options.dsn?.takeIf { it.isNotBlank() } ?: BAKED_DSN
        SentryAndroid.init(context) { sentryOptions ->
            sentryOptions.dsn = resolvedDsn
            sentryOptions.environment = options.environment ?: DEFAULT_ENVIRONMENT
            sentryOptions.tracesSampleRate = options.tracesSampleRate
            sentryOptions.isEnableAutoSessionTracking = true
            if (options.scrubPii) {
                sentryOptions.beforeSend = SentryOptions.BeforeSendCallback { event, _ ->
                    PiiScrubber.scrub(event)
                    event
                }
            }
        }
        VoqalSDK.addLogSink(VoqalSentrySink(scrubPii = options.scrubPii))
        initialized = true
    }

    /**
     * Forwards SDK diagnostics to Sentry. Events become breadcrumbs; errors
     * become captured exceptions (or messages when no Throwable is supplied).
     * Field values are redacted inline when [scrubPii] is set, so PII never
     * reaches the Sentry buffer even before `beforeSend` runs.
     */
    private class VoqalSentrySink(private val scrubPii: Boolean) : VoqalLogSink {

        override fun event(name: String, fields: Map<String, Any?>) {
            val crumb = Breadcrumb().apply {
                message = redactText(name)
                for ((key, value) in fields) {
                    if (value != null) setData(key, redactValue(value))
                }
            }
            Sentry.addBreadcrumb(crumb)
        }

        override fun error(name: String, throwable: Throwable?, fields: Map<String, Any?>) {
            Sentry.withScope { scope ->
                for ((key, value) in fields) {
                    if (value != null) scope.setExtra(key, redactText(value.toString()))
                }
                if (throwable != null) {
                    Sentry.captureException(throwable)
                } else {
                    Sentry.captureMessage(redactText(name), SentryLevel.ERROR)
                }
            }
        }

        private fun redactText(text: String): String =
            if (scrubPii) PiiScrubber.redact(text) else text

        private fun redactValue(value: Any): Any =
            if (scrubPii && value is String) PiiScrubber.redact(value) else value
    }
}
