import 'package:flutter_test/flutter_test.dart';
import 'package:minmin/main.dart';

void main() {
  testWidgets('MinMin app launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MinMinApp());
    expect(find.text('MIN MIN'), findsOneWidget);
  });
}
