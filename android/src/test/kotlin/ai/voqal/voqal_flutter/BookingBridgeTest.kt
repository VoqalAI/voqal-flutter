package ai.voqal.voqal_flutter

import ai.voqal.sdk.VoqalBookingMode
import ai.voqal.sdk.VoqalBookingResult
import ai.voqal.sdk.VoqalBookingStatus
import ai.voqal.sdk.VoqalLocalizedText
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows

internal class BookingBridgeTest {

    @Test
    fun bookingMode_host_mapsToHost() {
        assertEquals(VoqalBookingMode.HOST, BookingBridge.bookingMode("host"))
    }

    @Test
    fun bookingMode_unknownOrMissing_defaultsToServer() {
        assertEquals(
            listOf(VoqalBookingMode.SERVER, VoqalBookingMode.SERVER),
            listOf(BookingBridge.bookingMode(null), BookingBridge.bookingMode("weird")),
        )
    }

    @Test
    fun localizedText_withBothValues_buildsText() {
        assertEquals(
            VoqalLocalizedText("Top up", "اشحن"),
            BookingBridge.localizedText(mapOf("en" to "Top up", "ar" to "اشحن")),
        )
    }

    @Test
    fun localizedText_withBlankValue_returnsNullSoTheDefaultIsKept() {
        assertNull(BookingBridge.localizedText(mapOf("en" to "Top up", "ar" to " ")))
    }

    @Test
    fun timeoutSeconds_nonPositive_returnsNull() {
        assertEquals(listOf(120L, null), listOf(BookingBridge.timeoutSeconds(120), BookingBridge.timeoutSeconds(0)))
    }

    @Test
    fun resultFrom_null_returnsNullForTheSdkToReportNoResult() {
        assertNull(BookingBridge.resultFrom(null))
    }

    @Test
    fun resultFrom_successMap_buildsTheResult() {
        val reply = mapOf("status" to "success", "message" to "Booked!", "reference" to "8812")

        assertEquals(
            VoqalBookingResult(VoqalBookingStatus.SUCCESS, message = "Booked!", reference = "8812"),
            BookingBridge.resultFrom(reply),
        )
    }

    @Test
    fun resultFrom_failedMap_carriesTheCode() {
        val reply = mapOf("status" to "failed", "code" to "DEPOSIT_REQUIRED")

        assertEquals("DEPOSIT_REQUIRED", BookingBridge.resultFrom(reply)?.code)
    }

    @Test
    fun resultFrom_unknownStatus_throwsMalformedReply() {
        val error = assertThrows<HostBookingException> { BookingBridge.resultFrom(mapOf("status" to "ok")) }

        assertEquals(HostBookingException.MALFORMED_REPLY, error.code)
    }

    @Test
    fun resultFrom_nonMap_throwsMalformedReply() {
        val error = assertThrows<HostBookingException> { BookingBridge.resultFrom("success") }

        assertEquals(HostBookingException.MALFORMED_REPLY, error.code)
    }

    @Test
    fun addFundsArguments_keepsNulls() {
        assertEquals(
            mapOf("amount" to null, "currency" to null),
            BookingBridge.addFundsArguments(null, null),
        )
    }
}
