import 'package:flutter_test/flutter_test.dart';
import 'package:minmin/main.dart';

void main() {
  testWidgets('MinMin app launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MinMinApp());
    // Setup screen shown when no model is loaded — title appears multiple times
    expect(find.text('MIN MIN'), findsWidgets);
  });
}
