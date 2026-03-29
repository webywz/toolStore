import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/app.dart';

void main() {
  testWidgets('mobile shell renders primary navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MarineHardwareApp());

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('分类'), findsOneWidget);
    expect(find.text('AI 助手'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}
