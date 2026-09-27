import 'package:flutter/material.dart';
import 'package:drh_setif_tracker/utils/app_localizations.dart';
import 'package:drh_setif_tracker/screens/auth/login_screen.dart';
import 'package:drh_setif_tracker/widgets/golden_emblem_coin.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _startFlow();
  }

  Future<void> _startFlow() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _fadeController.forward();

    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isAr = loc.isArabic;
    final fontFam = isAr ? 'Tajawal' : 'Roboto';

    return Scaffold(
      backgroundColor: const Color(0xFF140719),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1F0B26),
              Color(0xFF280B30),
              Color(0xFF1A0720),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isShort = constraints.maxHeight < 680;
              final coinSize = isShort ? 110.0 : 150.0;
              final spacerFlexTop = isShort ? 1 : 3;
              final spacerFlexMid = isShort ? 1 : 2;

              return Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Spacer(flex: spacerFlexTop),

                                // Official Emblem Medallion
                                GoldenEmblemCoin(
                                  size: coinSize,
                                  showOuterGlow: true,
                                ),
                                SizedBox(height: isShort ? 18 : 28),

                                // Directorate and State Text
                                Text(
                                  loc.splashDirectorate,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: fontFam,
                                    fontSize: isAr ? (isShort ? 13.5 : 15.0) : (isShort ? 12.0 : 13.5),
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.90),
                                    letterSpacing: isAr ? 0 : 0.3,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 6),

                                Text(
                                  loc.isArabic ? 'ولاية سطيف' : 'Wilaya de Sétif',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: fontFam,
                                    fontSize: isAr ? 14 : 13,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFFD4AF37),
                                    letterSpacing: isAr ? 0 : 0.5,
                                  ),
                                ),
                                SizedBox(height: isShort ? 14 : 20),

                                // Main Platform Name
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF881337).withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    loc.splashTitle,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: fontFam,
                                      fontSize: isAr ? (isShort ? 17 : 20) : (isShort ? 14 : 16),
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: isAr ? 0 : 0.4,
                                    ),
                                  ),
                                ),

                                Spacer(flex: spacerFlexMid),

                                // Subtle Loading Bar
                                SizedBox(
                                  width: 130,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: const LinearProgressIndicator(
                                      minHeight: 3,
                                      backgroundColor: Color(0xFF381440),
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                Text(
                                  loc.splashLoading,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: fontFam,
                                    fontSize: 11,
                                    color: Colors.white38,
                                  ),
                                ),

                                const Spacer(flex: 1),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
