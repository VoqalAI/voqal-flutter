package ai.voqal.voqal_flutter

import kotlin.test.assertEquals
import kotlin.test.assertFalse
import org.junit.jupiter.api.Test

internal class PiiScrubberTest {

    @Test
    fun redact_withJwtToken_replacesWithRedacted() {
        val jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N"

        val result = PiiScrubber.redact("token=$jwt failed")

        assertEquals("token=[redacted] failed", result)
    }

    @Test
    fun redact_withEmail_replacesWithRedacted() {
        val result = PiiScrubber.redact("user yaseen@example.com hit an error")

        assertEquals("user [redacted] hit an error", result)
    }

    @Test
    fun redact_withPhoneNumber_replacesWithRedacted() {
        val result = PiiScrubber.redact("call +1 415 555 1234 now")

        assertFalse(result.contains("555"))
    }

    @Test
    fun redact_withUrlQuery_replacesWithRedacted() {
        val result = PiiScrubber.redact("GET https://api.voqal.ai/v1/balance?token=abc123&user=42")

        assertEquals("GET https://api.voqal.ai/v1/balance[redacted]", result)
    }

    @Test
    fun redact_withPlainText_leavesUnchanged() {
        val plain = "balance fetched in 240 ms"

        val result = PiiScrubber.redact(plain)

        assertEquals(plain, result)
    }
}
