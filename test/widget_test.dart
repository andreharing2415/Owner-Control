import 'package:flutter_test/flutter_test.dart';
import 'package:owner_control/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MestreDaObraApp());
    expect(find.byType(MestreDaObraApp), findsOneWidget);
  });
}
