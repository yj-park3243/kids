import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: KidsApp()),
    );
    // Verify splash screen shows
    expect(find.text('같이크자'), findsOneWidget);
  });
}
