import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drh_setif_tracker/services/auth_service.dart';
import 'package:drh_setif_tracker/utils/app_localizations.dart';
import 'package:drh_setif_tracker/providers/language_provider.dart';
import 'package:drh_setif_tracker/screens/director/director_screen.dart';
import 'package:drh_setif_tracker/screens/head/head_screen.dart';
import 'package:drh_setif_tracker/screens/bureau/bureau_screen.dart';
import 'package:drh_setif_tracker/screens/inspector/inspector_screen.dart';
import 'package:drh_setif_tracker/screens/admin/admin_screen.dart';
import 'package:drh_setif_tracker/widgets/golden_emblem_coin.dart';
import 'package:drh_setif_tracker/screens/common/app_footer.dart';
import 'package:drh_setif_tracker/screens/common/mandatory_security_setup_dialog.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _pinFocusNode = FocusNode();
  bool _isLoading = false;
  bool _obscure = true;
  bool _obscurePin = true;
  bool _showPinField = false;
  bool _forceShowPin = false;
  bool _isTrustedDevice = false;
  String? _error;

  late AnimationController _slideController;
  late AnimationController _shakeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
        );
    _shakeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _shakeController, curve: ShakeCurve()));

    AuthService.getSavedMasterPin().then((savedPin) {
      if (mounted && savedPin != null && savedPin.isNotEmpty) {
        setState(() => _isTrustedDevice = true);
      }
    });

    _usernameCtrl.addListener(() {
      final u = _usernameCtrl.text.trim().toLowerCase();
      final isLeadership = u == 'tracker_admin' ||
          u.startsWith('directeur') ||
          u.startsWith('chef_') ||
          u.startsWith('bureau_') ||
          u == 'admin';
      final shouldShow = isLeadership && !_isTrustedDevice;
      if (!_forceShowPin && _showPinField != shouldShow) {
        setState(() => _showPinField = shouldShow);
      }
      if (_error != null) {
        setState(() => _error = null);
      }
    });

    _slideController.forward();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _pinCtrl.dispose();
    _pinFocusNode.dispose();
    _slideController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final pin = _pinCtrl.text.trim();
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'أدخل اسم المستخدم وكلمة المرور');
      _shakeController.forward(from: 0);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthService>();
      await auth.login(username, password, masterPin: pin.isNotEmpty ? pin : null);

      if (!mounted) return;

      // 🛡️ Check if official must change credentials (first-time login or administrative reset)
      if (auth.currentUser?.mustChangeCredentials == true) {
        final setupCompleted = await MandatorySecuritySetupDialog.show(context);
        if (!setupCompleted || !mounted) {
          setState(() {
            _isLoading = false;
            _error = 'يجب استكمال تأمين وتفعيل الحساب بتغيير كلمة المرور ورمز الأمان للمتابعة';
          });
          return;
        }
      }

      Widget nextScreen;
      switch (auth.currentUser?.role) {
        case 'admin':
          nextScreen = const AdminScreen();
          break;
        case 'director':
          nextScreen = const DirectorScreen();
          break;
        case 'head_of_department':
          nextScreen = const HeadScreen();
          break;
        case 'bureau_chief':
          nextScreen = const BureauScreen();
          break;
        default:
          nextScreen = const InspectorScreen();
      }


      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => nextScreen,
          transitionsBuilder: (_, anim, __, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero)
                    .animate(
                      CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                    ),
                child: child,
              ),
            );
          },
        ),
      );
    } catch (e) {
      final errStr = e.toString().replaceAll('Exception: ', '');
      if (errStr.contains('Master PIN') || errStr.contains('رمز الأمان') || errStr.contains('requiresMasterPin') || errStr.contains('PIN')) {
        await AuthService.clearSavedMasterPin();
        setState(() {
          _isTrustedDevice = false;
          _forceShowPin = true;
          _showPinField = true;
        });
        _pinFocusNode.requestFocus();
        if (_pinCtrl.text.isNotEmpty) {
          _pinCtrl.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _pinCtrl.text.length,
          );
        }
      }
      setState(() {
        _error = errStr;
        _isLoading = false;
      });
      _shakeController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final langProvider = context.watch<LanguageProvider>();
    final isAr = loc.isArabic;
    final fontFam = isAr ? 'Tajawal' : 'Plus Jakarta Sans';


    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF1A0A1F), Color(0xFF2D1035), Color(0xFF4C0519)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Background decoration
              Positioned(
                top: -100,
                right: -80,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFD4AF37).withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -80,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF881337).withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Language toggle
              Positioned(
                top: 16,
                left: 16,
                child: IconButton(
                  onPressed: () => langProvider.toggleLanguage(),
                  icon: const Icon(
                    Icons.language,
                    color: Color(0xFFD4AF37),
                    size: 28,
                  ),
                ),
              ),

              // Main content
              Center(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Official 3D Medallion Emblem
                            const Center(
                              child: GoldenEmblemCoin(
                                size: 110,
                                showOuterGlow: true,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Title
                            Text(
                              loc.isArabic
                                  ? 'منصة الرقابة والتفتيش الميداني'
                                  : 'Plateforme de Contrôle et d\'Inspection',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: fontFam,
                                fontSize: isAr ? 22 : 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: isAr ? 0 : 0.4,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              loc.isArabic
                                  ? 'مديرية التجارة الداخلية وضبط السوق — سطيف'
                                  : 'Direction du Commerce Intérieur et de la Régulation — Sétif',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: fontFam,
                                fontSize: isAr ? 13 : 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFD4AF37),
                                letterSpacing: isAr ? 0 : 0.3,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Username field
                            AnimatedBuilder(
                              animation: _shakeAnimation,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(
                                    sin(_shakeAnimation.value * 2 * pi * 3) * 5,
                                    0,
                                  ),
                                  child: TextField(
                                    controller: _usernameCtrl,
                                    cursorColor: const Color(0xFFD4AF37),
                                    textDirection: TextDirection.ltr,
                                    style: TextStyle(
                                      fontFamily: fontFam,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: loc.loginUsername,
                                      labelStyle: TextStyle(
                                        fontFamily: fontFam,
                                        fontSize: 13,
                                        color: Colors.white70,
                                      ),
                                      floatingLabelStyle: TextStyle(
                                        fontFamily: fontFam,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFD4AF37),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.person_outline,
                                        color: Color(0xFFD4AF37),
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFF3D1A45),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF4A2050),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF4A2050),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: const BorderSide(
                                          color: Color(0xFFD4AF37),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password field
                            TextField(
                              controller: _passwordCtrl,
                              cursorColor: const Color(0xFFD4AF37),
                              obscureText: _obscure,
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                fontFamily: fontFam,
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              onChanged: (_) {
                                if (_error != null) setState(() => _error = null);
                              },
                              onSubmitted: (_) => _login(),
                              decoration: InputDecoration(
                                labelText: loc.loginPassword,
                                labelStyle: TextStyle(
                                  fontFamily: fontFam,
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                                floatingLabelStyle: TextStyle(
                                  fontFamily: fontFam,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFD4AF37),
                                ),
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  color: Color(0xFFD4AF37),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF3D1A45),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFF4A2050)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFF4A2050)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD4AF37),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                             const SizedBox(height: 16),

                            // Master PIN / Trusted Device UI
                            if (_isTrustedDevice && !_forceShowPin) ...[
                              Container(
                                margin: const EdgeInsets.only(top: 6, bottom: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.35)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.verified_user, color: Color(0xFFD4AF37), size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      'هذا الجهاز موثق ومعتمد للمسؤول ✓',
                                      style: TextStyle(
                                        fontFamily: fontFam,
                                        color: const Color(0xFFD4AF37),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (_showPinField || _forceShowPin) ...[
                              TextField(
                                controller: _pinCtrl,
                                focusNode: _pinFocusNode,
                                cursorColor: const Color(0xFFD4AF37),
                                obscureText: _obscurePin,
                                keyboardType: TextInputType.number,
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  fontFamily: fontFam,
                                  color: Colors.white,
                                  fontSize: 14,
                                  letterSpacing: 3,
                                ),
                                onChanged: (_) {
                                  if (_error != null) {
                                    setState(() => _error = null);
                                  } else {
                                    setState(() {});
                                  }
                                },
                                onSubmitted: (_) => _login(),
                                decoration: InputDecoration(
                                  labelText: 'رمز الأمان السري (PIN Code) — تأكيد الهوية',
                                  labelStyle: TextStyle(
                                    fontFamily: fontFam,
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                  floatingLabelStyle: TextStyle(
                                    fontFamily: fontFam,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFD4AF37),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.shield_outlined,
                                    color: Color(0xFFD4AF37),
                                  ),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_pinCtrl.text.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.cancel_outlined,
                                            color: Color(0xFFD4AF37),
                                            size: 18,
                                          ),
                                          tooltip: 'مسح الرمز',
                                          onPressed: () {
                                            _pinCtrl.clear();
                                            setState(() => _error = null);
                                            _pinFocusNode.requestFocus();
                                          },
                                        ),
                                      IconButton(
                                        icon: Icon(
                                          _obscurePin ? Icons.visibility_off : Icons.visibility,
                                          color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                                        ),
                                        onPressed: () => setState(() => _obscurePin = !_obscurePin),
                                      ),
                                    ],
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF3D1A45),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFF4A2050)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFF4A2050)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFD4AF37),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '🔒 أدخل رمز الأمان السري الخاص بك (6 أرقام).',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: fontFam,
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              if (_pinCtrl.text.isNotEmpty && _pinCtrl.text.trim().length != 6) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '⚠️ تنبيه: رمز الأمان يتكون من 6 أرقام (أنت كتبت ${_pinCtrl.text.trim().length} أرقام فقط)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: fontFam,
                                    color: const Color(0xFFD4AF37),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                            ],

                            // Error message with instant retry/clear action
                            if (_error != null) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              _error!,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontFamily: fontFam,
                                                color: const Color(0xFFEF4444),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_error!.contains('PIN') || _error!.contains('رمز الأمان') || _showPinField || _forceShowPin) ...[
                                        const SizedBox(height: 8),
                                        InkWell(
                                          onTap: () {
                                            _pinCtrl.clear();
                                            setState(() => _error = null);
                                            _pinFocusNode.requestFocus();
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.refresh, color: Color(0xFFD4AF37), size: 16),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'مسح الرمز وإعادة المحاولة',
                                                  style: TextStyle(
                                                    fontFamily: fontFam,
                                                    color: const Color(0xFFD4AF37),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),

                            // Login button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD4AF37),
                                  foregroundColor: const Color(0xFF1A0A1F),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 4,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Color(0xFF1A0A1F),
                                        ),
                                      )
                                    : Text(
                                        loc.loginButton,
                                        style: TextStyle(
                                          fontFamily: fontFam,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: isAr ? 0 : 0.4,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            const AppFooter(),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ShakeCurve extends Curve {
  @override
  double transformInternal(double t) {
    return sin(t * 3 * pi);
  }
}
