package ai.voqal.voqal_flutter

import ai.voqal.sdk.VoqalOutcomeReportError
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Test
import java.io.IOException

internal class ErrorReportTest {

    @Test
    fun arguments_outcomeReportError_carriesStatusCodeAndConfirmId() {
        val error = VoqalOutcomeReportError("success", "confirm_not_found", "c-1")

        assertEquals(
            mapOf(
                "type" to "outcome_report",
                "outcomeStatus" to "success",
                "code" to "confirm_not_found",
                "confirmId" to "c-1",
                "detail" to "VoqalOutcomeReportError",
            ),
            ErrorReport.arguments(error),
        )
    }

    @Test
    fun arguments_otherError_sendsOnlyTheTypeName() {
        assertEquals(
            mapOf("type" to "sdk", "detail" to "IOException"),
            ErrorReport.arguments(IOException("secret token in message")),
        )
    }

    @Test
    fun arguments_bridgeBookingError_isNotForwarded() {
        assertNull(ErrorReport.arguments(HostBookingException("host_error")))
    }
}
