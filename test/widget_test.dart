import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agri_lenz/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Agri Lenz shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(const AgriLenzApp(initialThemeMode: ThemeMode.light));
    await tester.pumpAndSettle();
    expect(find.text('Agri Lenz'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
  });
}
