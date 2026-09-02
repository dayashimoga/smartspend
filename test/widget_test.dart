import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/app.dart';

void main() {
  testWidgets('SmartSpendApp mounts and displays navigation bar smoke test',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SmartSpendApp(),
      ),
    );

    // Initial pump
    await tester.pump();

    // Verify app title or core elements exist
    expect(find.text('SmartSpend'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
  });
}
