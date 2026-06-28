import 'package:flutter_test/flutter_test.dart';
import 'package:voqal_flutter_example/main.dart';

void main() {
  testWidgets('Rabbit demo renders its title and CTA', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const RabbitDemoApp());

    // The setup/prewarm calls hit the method channel (no native handler in a
    // widget test) and are swallowed by the app's try/catch, so the first
    // frame still renders the brand chrome.
    expect(find.text('Rabbit'), findsOneWidget);
    expect(find.text('Groceries in 15 minutes'), findsOneWidget);
  });
}
