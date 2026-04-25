import 'package:dressify_frontend/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App boots and shows Dressify wordmark', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: DressifyApp()));
    await tester.pump();

    expect(find.text('Dressify'), findsOneWidget);
  });
}
