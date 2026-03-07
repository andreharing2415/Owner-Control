import 'package:flutter_test/flutter_test.dart';
import 'package:mestre_da_obra/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ObraMasterApp());
    expect(find.byType(ObraMasterApp), findsOneWidget);
  });
}
