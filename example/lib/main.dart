import 'package:flutter/material.dart';
import 'package:voqal_flutter/voqal_flutter.dart';

// Credentials live in a gitignored file so nothing sensitive is ever committed.
// Copy demo_credentials.dart.example -> demo_credentials.dart and fill it in.
import 'demo_credentials.dart';

void main() => runApp(const RabbitDemoApp());

class RabbitDemoApp extends StatelessWidget {
  const RabbitDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voqal × Rabbit',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1F7A4D),
      ),
      home: const RabbitHome(),
    );
  }
}

class RabbitHome extends StatefulWidget {
  const RabbitHome({super.key});

  @override
  State<RabbitHome> createState() => _RabbitHomeState();
}

class _RabbitHomeState extends State<RabbitHome> {
  final Voqal _voqal = Voqal();
  bool _ready = false;
  bool _fullScreen = false; // demo toggle: sheet (default) vs full app screen

  // LOCAL TEST: agentUrl points at the local engine instead of the baked prod URL.
  VoqalConfig _config(VoqalPresentationStyle style) => VoqalConfig(
    apiKey: demoApiKey,
    requestId: 'prod-rabbit-demo',
    agentUrl: demoAgentUrl,
    theme: const VoqalTheme(accent: '#1F7A4D', accent2: '#C7ED4A'),
    home: const VoqalHome(
      userName: 'Yaseen',
      pinnedCTAs: <String>["Where's my order?", 'Find milk and eggs'],
    ),
    presentationStyle: style,
    // Brand the sheet header with Rabbit's name + logo (instead of "Voqal").
    headerTitle: 'Rabbit',
    headerIcon: const VoqalImage.asset('assets/rabbit_logo.png'),
    // Optional action button (v1.5.0): accent CTA right of the voice wave. The
    // SDK dismisses the sheet on tap, then fires onActionButtonTapped (below).
    actionButtonEnabled: true,
  );

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // The host owns navigation: the SDK dismissed its sheet, now we route to our page.
    _voqal.onActionButtonTapped = () {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const CheckoutPage()),
      );
    };
    try {
      await _voqal.setup(_config(VoqalPresentationStyle.sheet));
      // A demo bearer the Rabbit mock MCP accepts. A real integration pushes a
      // live token here and re-pushes on every rotation.
      await _voqal.setCredentials(
        demoUserToken,
        metadataJson: '{"country_code":"EGY","user_id":"999001"}',
      );
      await _voqal.prewarm();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      // Never surface credential payloads in an error message.
      _toast('Setup failed — check the engine connection.');
    }
  }

  Future<void> _present() async {
    try {
      // Presentation style is a setup-time setting, so re-apply the chosen style
      // (and re-push credentials) right before presenting.
      await _voqal.setup(
        _config(
          _fullScreen
              ? VoqalPresentationStyle.fullScreen
              : VoqalPresentationStyle.sheet,
        ),
      );
      await _voqal.setCredentials(
        demoUserToken,
        metadataJson: '{"country_code":"EGY","user_id":"999001"}',
      );
      await _voqal.present();
    } catch (e) {
      // present() errors (e.g. PlatformException) carry no credentials, so
      // they're safe to log in this dev sample.
      debugPrint('Voqal present error: $e');
      _toast('Could not open the assistant.');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Rabbit',
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Groceries in 15 minutes',
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),
            const SizedBox(height: 44),
            FilledButton.icon(
              onPressed: _ready ? _present : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1F7A4D),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
              ),
              icon: const Icon(Icons.mic),
              label: Text(_ready ? 'Talk to Rabbit' : 'Starting…'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 260,
              child: SwitchListTile(
                value: _fullScreen,
                onChanged: (bool v) => setState(() => _fullScreen = v),
                title: const Text(
                  'Full screen',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: const Text(
                  'off = slide-up sheet (default)',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                activeThumbColor: const Color(0xFFC7ED4A),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stand-in host page the example routes to when the assistant's action button is
/// tapped — proves the SDK hands control back to Flutter to navigate anywhere.
class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0D),
        foregroundColor: Colors.white,
        title: const Text('Checkout'),
      ),
      body: const Center(
        child: Text(
          '🛍  Checkout Page',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
