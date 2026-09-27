import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:drh_setif_tracker/screens/splash_screen.dart';
import 'package:drh_setif_tracker/screens/common/verification_screen.dart';
import 'package:drh_setif_tracker/utils/theme.dart';
import 'package:drh_setif_tracker/utils/app_localizations.dart';
import 'package:drh_setif_tracker/services/auth_service.dart';
import 'package:drh_setif_tracker/providers/language_provider.dart';

import 'package:drh_setif_tracker/services/inspectorate_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await InspectorateService.instance.initialize();
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF1A0A1F),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFD4AF37), size: 44),
              const SizedBox(height: 12),
              const Text(
                'تنبيه في عرض البيانات',
                style: TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  };
  runApp(const DRHTrackerApp());
}

class DRHTrackerApp extends StatelessWidget {
  const DRHTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider.value(value: InspectorateService.instance),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, langProvider, _) {
          return MaterialApp(
            title: 'مديرية التجارة سطيف — منصة الرقابة والتفتيش',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.getTheme(isArabic: langProvider.isArabic),
            locale: langProvider.locale,
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ar', ''), Locale('fr', '')],
            onGenerateRoute: (settings) {
              final routeUri = Uri.parse(settings.name ?? '/');
              final baseUri = Uri.base;
              final isVerifyRoute = routeUri.path.contains('verify') || 
                                    baseUri.path.contains('verify') || 
                                    routeUri.queryParameters.containsKey('id') || 
                                    routeUri.queryParameters.containsKey('emp') ||
                                    baseUri.queryParameters.containsKey('id') ||
                                    baseUri.queryParameters.containsKey('emp');

              if (isVerifyRoute) {
                final mergedParams = <String, dynamic>{
                  ...baseUri.queryParameters,
                  ...routeUri.queryParameters,
                };
                return MaterialPageRoute(
                  builder: (_) => VerificationScreen(params: mergedParams),
                  settings: settings,
                );
              }
              return MaterialPageRoute(
                builder: (_) => const SplashScreen(),
                settings: settings,
              );
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
