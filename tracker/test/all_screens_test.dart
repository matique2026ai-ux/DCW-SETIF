import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drh_setif_tracker/providers/language_provider.dart';
import 'package:drh_setif_tracker/services/auth_service.dart';
import 'package:drh_setif_tracker/utils/app_localizations.dart';
import 'package:drh_setif_tracker/screens/admin/admin_screen.dart';
import 'package:drh_setif_tracker/screens/director/director_screen.dart';
import 'package:drh_setif_tracker/screens/head/head_screen.dart';
import 'package:drh_setif_tracker/screens/bureau/bureau_screen.dart';
import 'package:drh_setif_tracker/screens/inspector/inspector_screen.dart';

Widget createTestApp(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthService()),
      ChangeNotifierProvider(create: (_) => LanguageProvider()),
    ],
    child: MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
      ],
      home: child,
    ),
  );
}

void main() {
  testWidgets('AdminScreen renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(createTestApp(const AdminScreen()));
    await tester.pump();
    expect(find.byType(AdminScreen), findsOneWidget);
  });

  testWidgets('DirectorScreen renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(createTestApp(const DirectorScreen()));
    await tester.pump();
    expect(find.byType(DirectorScreen), findsOneWidget);
  });

  testWidgets('HeadScreen renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(createTestApp(const HeadScreen()));
    await tester.pump();
    expect(find.byType(HeadScreen), findsOneWidget);
  });

  testWidgets('BureauScreen renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(createTestApp(const BureauScreen()));
    await tester.pump();
    expect(find.byType(BureauScreen), findsOneWidget);
  });

  testWidgets('InspectorScreen renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(createTestApp(const InspectorScreen()));
    await tester.pump();
    expect(find.byType(InspectorScreen), findsOneWidget);
  });
}
