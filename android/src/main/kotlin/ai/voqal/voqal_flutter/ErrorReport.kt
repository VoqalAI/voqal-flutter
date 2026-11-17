package ai.voqal.voqal_flutter

import ai.voqal.sdk.VoqalOutcomeReportError

/**
 * What the plugin forwards to Dart's `Voqal.onError`: codes, ids, and type names only, never an
 * error's message (it may carry user data).
 */
internal object ErrorReport {

    /**
     * The `onError` payload for [error], or null when it must not be forwarded: the bridge's own
     * booking failures are already reported in Dart, with the card's confirm id.
     */
    fun arguments(error: Throwable): Map<String, Any?>? = when (error) {
        is HostBookingException -> null
        is VoqalOutcomeReportError -> mapOf(
            "type" to "outcome_report",
            "outcomeStatus" to error.outcomeStatus,
            "code" to error.code,
            "confirmId" to error.confirmId,
            "detail" to "VoqalOutcomeReportError",
        )
        else -> mapOf("type" to "sdk", "detail" to error.javaClass.simpleName)
    }
}
