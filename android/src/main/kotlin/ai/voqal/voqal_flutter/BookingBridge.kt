package ai.voqal.voqal_flutter

import ai.voqal.sdk.VoqalBookingMode
import ai.voqal.sdk.VoqalBookingResult
import ai.voqal.sdk.VoqalBookingStatus
import ai.voqal.sdk.VoqalLocalizedText
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellableContinuation
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Raised when Dart's booking handler threw or replied with something that isn't a result.
 * The native SDK reports it to the engine as a failed booking (`host_error`).
 *
 * @property code The error code Dart sent, or [MALFORMED_REPLY].
 */
internal class HostBookingException(val code: String) :
    RuntimeException("Flutter booking handler failed: $code") {
    companion object {
        /** Code used when Dart's reply isn't a `{status, ...}` map. */
        const val MALFORMED_REPLY: String = "malformed_reply"

        /** Code used when the Flutter engine detached before Dart replied. */
        const val ENGINE_DETACHED: String = "engine_detached"
    }
}

/** Pure mapping between the method-channel payloads and the native booking types. */
internal object BookingBridge {

    /** The `bookingMode` wire value, defaulting to [VoqalBookingMode.SERVER]. */
    fun bookingMode(value: Any?): VoqalBookingMode = when (value) {
        "host" -> VoqalBookingMode.HOST
        else -> VoqalBookingMode.SERVER
    }

    /** The `addFundsButtonTitle` map, or null (keep the SDK default) when either value is blank. */
    fun localizedText(value: Any?): VoqalLocalizedText? {
        val map = value as? Map<*, *> ?: return null
        val english = (map["en"] as? String)?.takeIf { it.isNotBlank() } ?: return null
        val arabic = (map["ar"] as? String)?.takeIf { it.isNotBlank() } ?: return null
        return VoqalLocalizedText(english, arabic)
    }

    /** A positive timeout in seconds, or null (keep the SDK default). */
    fun timeoutSeconds(value: Any?): Long? =
        (value as? Number)?.toLong()?.takeIf { it > 0 }

    /** The arguments for Dart's `onAddFundsTapped`. */
    fun addFundsArguments(amount: Double?, currency: String?): Map<String, Any?> =
        mapOf("amount" to amount, "currency" to currency)

    /**
     * Decodes Dart's reply to `onBookingConfirmed`. Null means Dart had no handler or declined;
     * the SDK reports that as a failed booking (`host_no_result`).
     *
     * @throws HostBookingException when the reply isn't a result map with a known status.
     */
    fun resultFrom(reply: Any?): VoqalBookingResult? {
        if (reply == null) return null
        val map = reply as? Map<*, *> ?: throw HostBookingException(HostBookingException.MALFORMED_REPLY)
        val status = when (map["status"]) {
            "success" -> VoqalBookingStatus.SUCCESS
            "failed" -> VoqalBookingStatus.FAILED
            else -> throw HostBookingException(HostBookingException.MALFORMED_REPLY)
        }
        return VoqalBookingResult(
            status = status,
            message = map["message"] as? String,
            code = map["code"] as? String,
            reference = map["reference"] as? String,
        )
    }
}

/**
 * The booking calls still waiting for Dart. If the Flutter engine detaches, Dart can never reply,
 * so [failAll] ends each wait instead of leaving it until the SDK's timeout. Main thread only.
 */
internal class PendingBookingReplies {
    private val callbacks = mutableSetOf<BookingReplyCallback>()

    /** True when no booking call is waiting for Dart. */
    val isEmpty: Boolean get() = callbacks.isEmpty()

    /** Creates the reply callback for [continuation] and tracks it until it settles. */
    fun track(continuation: CancellableContinuation<VoqalBookingResult?>): BookingReplyCallback =
        BookingReplyCallback(continuation) { callbacks.remove(it) }.also { callbacks += it }

    /** Fails every waiting call with [HostBookingException.ENGINE_DETACHED]. */
    fun failAll() {
        callbacks.toList().forEach { it.error(HostBookingException.ENGINE_DETACHED, null, null) }
    }
}

/**
 * Resumes the SDK's suspended `onBookingConfirmed` with Dart's reply, once. Ignores a reply that
 * arrives after the SDK gave up (timeout or barge-in cancelled the continuation).
 */
internal class BookingReplyCallback(
    private val continuation: CancellableContinuation<VoqalBookingResult?>,
    private val onSettled: (BookingReplyCallback) -> Unit,
) : MethodChannel.Result {

    override fun success(result: Any?) {
        settle {
            try {
                continuation.resume(BookingBridge.resultFrom(result))
            } catch (error: HostBookingException) {
                continuation.resumeWithException(error)
            }
        }
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        settle { continuation.resumeWithException(HostBookingException(errorCode)) }
    }

    override fun notImplemented() {
        // An older Dart side with no booking handler: no result (the SDK reports host_no_result).
        settle { continuation.resume(null) }
    }

    private fun settle(resume: () -> Unit) {
        onSettled(this)
        if (continuation.isActive) resume()
    }
}
