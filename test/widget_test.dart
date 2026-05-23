import 'package:flutter_test/flutter_test.dart';

import 'package:hcode_app/app.dart';
import 'package:hcode_app/theme/theme_provider.dart';

void main() {
  testWidgets('App renders home page', (WidgetTester tester) async {
    final themeProvider = ThemeProvider();
    await tester.pumpWidget(HCodeApp(themeProvider: themeProvider));

    expect(find.text('AI 指挥中心'), findsOneWidget);
  });
}
