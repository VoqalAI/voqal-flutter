package ai.voqal.voqal_flutter

import ai.voqal.sdk.VoqalBookingResult
import ai.voqal.sdk.VoqalBookingStatus
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertDoesNotThrow
import org.junit.jupiter.api.assertThrows

internal class BookingReplyCallbackTest {

    /** Suspends like the plugin's onBookingConfirmed and lets [reply] answer as Dart would. */
    private fun awaitReply(
        pending: PendingBookingReplies = PendingBookingReplies(),
        reply: (BookingReplyCallback) -> Unit,
    ): VoqalBookingResult? = runBlocking {
        suspendCancellableCoroutine { continuation -> reply(pending.track(continuation)) }
    }

    @Test
    fun success_withResultMap_resumesWithTheResult() {
        val result = awaitReply { it.success(mapOf("status" to "success", "reference" to "8812")) }

        assertEquals(VoqalBookingResult(VoqalBookingStatus.SUCCESS, reference = "8812"), result)
    }

    @Test
    fun success_withNull_resumesWithNull() {
        assertNull(awaitReply { it.success(null) })
    }

    @Test
    fun success_withMalformedReply_throwsMalformedReply() {
        val error = assertThrows<HostBookingException> { awaitReply { it.success("nope") } }

        assertEquals(HostBookingException.MALFORMED_REPLY, error.code)
    }

    @Test
    fun error_fromDart_throwsWithDartsCode() {
        val error = assertThrows<HostBookingException> { awaitReply { it.error("host_error", "StateError", null) } }

        assertEquals("host_error", error.code)
    }

    @Test
    fun notImplemented_resumesWithNull() {
        assertNull(awaitReply { it.notImplemented() })
    }

    @Test
    fun lateReply_afterTheSdkStoppedWaiting_isIgnored() {
        var callback: BookingReplyCallback? = null
        runBlocking {
            withTimeoutOrNull(10) {
                suspendCancellableCoroutine<VoqalBookingResult?> { callback = PendingBookingReplies().track(it) }
            }
        }

        assertDoesNotThrow { callback!!.success(mapOf("status" to "success")) }
    }

    @Test
    fun failAll_onEngineDetach_throwsDetached() {
        val pending = PendingBookingReplies()

        val error = assertThrows<HostBookingException> { awaitReply(pending) { pending.failAll() } }

        assertEquals(HostBookingException.ENGINE_DETACHED, error.code)
    }

    @Test
    fun settledReply_isNoLongerTracked() {
        val pending = PendingBookingReplies()

        awaitReply(pending) { it.success(null) }

        assertTrue(pending.isEmpty)
    }
}
