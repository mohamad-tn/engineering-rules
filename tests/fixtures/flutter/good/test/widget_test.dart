import 'package:demo_app/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('counter starts at zero and increments', (tester) async {
    await tester.pumpWidget(const DemoApp());

    expect(find.text('Count: 0'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    expect(find.text('Count: 1'), findsOneWidget);
  });
}
