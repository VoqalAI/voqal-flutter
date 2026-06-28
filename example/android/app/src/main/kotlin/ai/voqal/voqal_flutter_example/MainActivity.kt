package ai.voqal.voqal_flutter_example

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity extends androidx ComponentActivity, which the Voqal
// SDK's present(activity, delegate) requires. The default FlutterActivity does
// NOT extend ComponentActivity, so present() would always fail with it.
class MainActivity : FlutterFragmentActivity()
