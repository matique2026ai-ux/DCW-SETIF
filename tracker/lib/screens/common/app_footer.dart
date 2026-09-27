import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drh_setif_tracker/providers/language_provider.dart';

class AppFooter extends StatelessWidget {
  final bool showDivider;
  final EdgeInsetsGeometry padding;

  const AppFooter({
    super.key,
    this.showDivider = false,
    this.padding = const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<LanguageProvider>().isArabic;

    return Container(
      width: double.infinity,
      padding: padding,
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width - 24,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF16081E).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.45),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Gold Engineering Seal Medallion
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD4AF37),
                        width: 1.0,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/engineering_seal.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.workspace_premium_rounded,
                          size: 11,
                          color: Color(0xFFD4AF37),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Crisp, elegant, and prominent copyright text
                  Text(
                    isArabic
                        ? 'جميع حقوق التصميم والبرمجة محفوظة © المهندس عكرور توفيق'
                        : 'Copyright © 2026 ING Akrour ToufiK',
                    style: TextStyle(
                      fontFamily: isArabic ? 'Tajawal' : null,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                      color: const Color(0xFFD4AF37),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
