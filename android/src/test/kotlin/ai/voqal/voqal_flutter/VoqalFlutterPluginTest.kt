package ai.voqal.voqal_flutter

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.jupiter.api.Test
import org.mockito.Mockito

internal class VoqalFlutterPluginTest {
    /// An unknown method must reply `notImplemented` (the channel is the small,
    /// fixed set: setup / setCredentials / prewarm / present). Methods that touch
    /// the native SDK are exercised on-device, not in unit tests.
    @Test
    fun unknownMethod_repliesNotImplemented() {
        val plugin = VoqalFlutterPlugin()
        val call = MethodCall("doesNotExist", null)
        val result = Mockito.mock(MethodChannel.Result::class.java)

        plugin.onMethodCall(call, result)

        Mockito.verify(result).notImplemented()
    }
}
