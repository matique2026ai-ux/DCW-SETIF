import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:drh_setif_tracker/screens/admin/admin_screen.dart';
import 'package:drh_setif_tracker/services/auth_service.dart';
import 'package:drh_setif_tracker/utils/app_localizations.dart';
import 'package:drh_setif_tracker/providers/language_provider.dart';

void main() {
  testWidgets('AdminScreen builds and renders all tabs properly', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final authService = AuthService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: authService),
          ChangeNotifierProvider<LanguageProvider>(create: (_) => LanguageProvider()),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('ar', ''), Locale('fr', '')],
          locale: Locale('ar', ''),
          home: AdminScreen(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));

    // Check AppBar
    expect(find.text('الإدارة التقنية للمنظومة'), findsOneWidget);

    // Check Top Tabs
    expect(find.text('المستخدمين والحسابات'), findsOneWidget);
    expect(find.text('المقرات والبصمة الجغرافية'), findsOneWidget);
    expect(find.text('حالة النظام والسيرفر'), findsOneWidget);
    expect(find.text('معاينة شاشات الأدوار'), findsOneWidget);

    // Tap Tab 1 (Inspectorates)
    await tester.tap(find.text('المقرات والبصمة الجغرافية'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Tab 2 (System Health)
    await tester.tap(find.text('حالة النظام والسيرفر'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Tab 3 (Role Preview)
    await tester.tap(find.text('معاينة شاشات الأدوار'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
  });
}
