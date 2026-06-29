package ai.voqal.voqal_flutter

import io.sentry.SentryEvent

/**
 * Defence-in-depth redaction, mirroring the iOS `PIIScrubber`.
 *
 * The SDK never logs raw tokens or PII by design, but this strips anything that
 * looks like a bearer/JWT token, email, phone number, or a URL query string from
 * outgoing Sentry payloads before they leave the device. It is applied both
 * inline as breadcrumbs/extras are built and again at the Sentry `beforeSend`
 * boundary so a missed call site cannot leak.
 */
internal object PiiScrubber {

    private const val REDACTED = "[redacted]"

    // Order mirrors the iOS scrubber: token, email, phone, then URL query.
    private val patterns: List<Regex> = listOf(
        Regex("""[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}"""), // JWT-ish
        Regex("""[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"""),               // email
        Regex("""\+?\d[\d \-]{7,}\d"""),                                             // phone
        Regex("""\?\S+"""),                                                          // URL query
    )

    /** Replaces every PII-shaped match in [text] with `[redacted]`. */
    fun redact(text: String): String {
        var result = text
        for (pattern in patterns) {
            result = pattern.replace(result, REDACTED)
        }
        return result
    }

    /** Redacts the formatted message and any String-valued extras on [event] in place. */
    fun scrub(event: SentryEvent) {
        event.message?.let { message ->
            message.formatted?.let { message.formatted = redact(it) }
        }
        scrubExtras(event)
    }

    private fun scrubExtras(event: SentryEvent) {
        val extras = event.extras ?: return
        // Snapshot the String keys so re-setting values does not disturb iteration.
        val stringKeys = extras.entries.filter { it.value is String }.map { it.key }
        for (key in stringKeys) {
            event.setExtra(key, redact(extras[key] as String))
        }
    }
}
