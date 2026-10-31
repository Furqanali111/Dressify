import 'package:dressify/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App boots and shows Dressify wordmark', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: DressifyApp()));
    await tester.pump();

    expect(find.text('Dressify'), findsOneWidget);

    // Let flutter_animate's zero-duration timers and splash timers fire
    // before the test ends, otherwise it fails with "pending timers".
    await tester.pump(const Duration(seconds: 10));
  });
}
