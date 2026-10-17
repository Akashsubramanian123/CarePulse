import 'package:flutter_test/flutter_test.dart';
import 'package:carepulse/main.dart';

void main() {
  testWidgets('CarePulseApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CarePulseApp());
    expect(find.text('CarePulse'), findsWidgets);
  });
}
