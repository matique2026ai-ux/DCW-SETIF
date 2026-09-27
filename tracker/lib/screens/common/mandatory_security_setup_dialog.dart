import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drh_setif_tracker/services/auth_service.dart';
import 'package:drh_setif_tracker/utils/theme.dart';

class MandatorySecuritySetupDialog extends StatefulWidget {
  const MandatorySecuritySetupDialog({super.key});

  /// Displays the mandatory security credentials setup modal dialog.
  /// Returns `true` if the credentials were successfully updated and confirmed.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const MandatorySecuritySetupDialog(),
    );
    return result ?? false;
  }

  @override
  State<MandatorySecuritySetupDialog> createState() => _MandatorySecuritySetupDialogState();
}

class _MandatorySecuritySetupDialogState extends State<MandatorySecuritySetupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = context.read<AuthService>();
      await auth.completeMandatoryCredentialsSetup(
        newPassword: _newPasswordCtrl.text.trim(),
        newPin: _newPinCtrl.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.verified_user, color: Color(0xFF1A0A1F)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'تم تأمين حسابك بنجاح! تم اعتماد كلمة المرور ورمز الأمان الجديدين بنجاح ✅',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A0A1F),
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFD4AF37),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _handleLogout() async {
    final auth = context.read<AuthService>();
    await auth.logout();
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1E0A26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1.8),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: Color(0xFFD4AF37),
                size: 38,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'إجراء أمني إلزامي — تفعيل الحساب',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD4AF37),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'كإجراء أمني إلزامي عند أول تسجيل دخول لك كمسؤول، يتوجب عليك استبدال البيانات الممنوحة لك من إدارة النظام وتعيين بياناتك السرية الشخصية لمتابعة العمل:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.DangerColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.DangerColor.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.DangerColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppTheme.DangerColor,
                                fontFamily: 'Tajawal',
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── SECTION 1: Password Change ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14051B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4A1A5E)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lock_reset, color: Color(0xFFD4AF37), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'الشرط الأول: كلمة المرور الشخصية الجديدة',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _newPasswordCtrl,
                          obscureText: _obscurePassword,
                          style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور الجديدة (6 أحرف على الأقل)',
                            labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFD4AF37), size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white60,
                                size: 18,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1E0B26),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'يرجى إدخال كلمة المرور الجديدة';
                            if (val.trim().length < 6) return 'يجب ألا تقل عن 6 أحرف أو أرقام';
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _confirmPasswordCtrl,
                          obscureText: _obscureConfirmPassword,
                          style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                          decoration: InputDecoration(
                            labelText: 'تأكيد كلمة المرور الجديدة',
                            labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
                            prefixIcon: const Icon(Icons.check_circle_outline, color: Color(0xFFD4AF37), size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white60,
                                size: 18,
                              ),
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1E0B26),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (val) {
                            if (val != _newPasswordCtrl.text) return 'كلمتا المرور غير متطابقتين';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── SECTION 2: PIN Code Change ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14051B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4A1A5E)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.pin, color: Color(0xFFD4AF37), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'الشرط الثاني: رمز الأمان السري الشخصي (PIN)',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'مطلوب للتحقق عند تسجيل الدخول من المتصفح والعمليات السيادية الحساسة.',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white54),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _newPinCtrl,
                          obscureText: _obscurePin,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', letterSpacing: 2),
                          decoration: InputDecoration(
                            labelText: 'رمز الأمان الجديد (4 أرقام أو أكثر)',
                            labelStyle: const TextStyle(color: Colors.white60, fontSize: 12, letterSpacing: 0),
                            prefixIcon: const Icon(Icons.pin_outlined, color: Color(0xFFD4AF37), size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePin ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white60,
                                size: 18,
                              ),
                              onPressed: () => setState(() => _obscurePin = !_obscurePin),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1E0B26),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'يرجى إدخال رمز الأمان السري';
                            if (val.trim().length < 4) return 'يجب ألا يقل عن 4 أرقام';
                            if (val.trim() == '202600') return 'يرجى اختيار رمز جديد مختلف عن الرمز الافتراضي (202600)';
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _confirmPinCtrl,
                          obscureText: _obscureConfirmPin,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', letterSpacing: 2),
                          decoration: InputDecoration(
                            labelText: 'تأكيد رمز الأمان السري',
                            labelStyle: const TextStyle(color: Colors.white60, fontSize: 12, letterSpacing: 0),
                            prefixIcon: const Icon(Icons.check_circle_outline, color: Color(0xFFD4AF37), size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPin ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white60,
                                size: 18,
                              ),
                              onPressed: () => setState(() => _obscureConfirmPin = !_obscureConfirmPin),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1E0B26),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          validator: (val) {
                            if (val != _newPinCtrl.text) return 'رمزا الأمان غير متطابقين';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isNarrow = MediaQuery.of(context).size.width < 460;
              if (isNarrow) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: const Color(0xFF1A0A1F),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isLoading ? null : _submit,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF1A0A1F),
                              ),
                            )
                          : const Icon(Icons.verified_user, size: 18),
                      label: Text(
                        _isLoading ? 'جارِ الاعتماد...' : 'حفظ واعتماد البيانات ومتابعة الدخول',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: _isLoading ? null : _handleLogout,
                      child: const Text(
                        'تسجيل الخروج والعودة',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : _handleLogout,
                    child: const Text(
                      'تسجيل الخروج',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: const Color(0xFF1A0A1F),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isLoading ? null : _submit,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1A0A1F),
                            ),
                          )
                        : const Icon(Icons.verified_user, size: 18),
                    label: Text(
                      _isLoading ? 'جارِ الاعتماد...' : 'حفظ واعتماد البيانات ومتابعة الدخول',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
