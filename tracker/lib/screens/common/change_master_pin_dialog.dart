import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drh_setif_tracker/services/auth_service.dart';
import 'package:drh_setif_tracker/utils/theme.dart';

class ChangeMasterPinDialog extends StatefulWidget {
  const ChangeMasterPinDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const ChangeMasterPinDialog(),
    );
  }

  @override
  State<ChangeMasterPinDialog> createState() => _ChangeMasterPinDialogState();
}

class _ChangeMasterPinDialogState extends State<ChangeMasterPinDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscurePin = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
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
      final api = context.read<AuthService>().api;
      final res = await api.changeMasterPin(
        newMasterPin: _newPinCtrl.text.trim(),
        currentPassword: _currentPasswordCtrl.text.trim(),
      );

      if (!mounted) return;

      final message = res['message']?.toString() ?? 'تم حفظ وتحديث رمز الأمان السري بنجاح ✅';
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.verified_user, color: Color(0xFF1A0A1F)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E0A26),
      actionsOverflowButtonSpacing: 8,
      actionsOverflowDirection: VerticalDirection.up,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.shield, color: Color(0xFFD4AF37), size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'تغيير رمز الأمان السري (Master PIN)',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'لحماية دخول مدير النظام من متصفحات الويب',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    color: Color(0xFFD4AF37),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          width: double.maxFinite,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.DangerColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.DangerColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.DangerColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              color: AppTheme.DangerColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Helper info
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFFD4AF37), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'يستخدم هذا الرمز السري حصرياً عند تسجيل دخولك كمدير نظام من متصفح الويب لفك القفل الأمني وتأكيد هويتك.',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            color: Colors.white70,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Current Password Field
                TextFormField(
                  controller: _currentPasswordCtrl,
                  obscureText: _obscurePass,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                  decoration: InputDecoration(
                    labelText: 'كلمة مرور حسابك الحالية للتأكيد',
                    labelStyle: const TextStyle(color: Colors.white70, fontFamily: 'Tajawal', fontSize: 13),
                    floatingLabelStyle: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                    prefixIcon: const Icon(Icons.lock, color: Color(0xFFD4AF37), size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off, color: Colors.white54, size: 18),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF14061A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'أدخل كلمة المرور الحالية للتأكيد';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // New Master PIN Field
                TextFormField(
                  controller: _newPinCtrl,
                  obscureText: _obscurePin,
                  keyboardType: TextInputType.text,
                  style: const TextStyle(color: Color(0xFFD4AF37), fontFamily: 'Tajawal', fontWeight: FontWeight.bold, letterSpacing: 2),
                  decoration: InputDecoration(
                    labelText: 'رمز الأمان السري الجديد (Master PIN)',
                    labelStyle: const TextStyle(color: Colors.white70, fontFamily: 'Tajawal', fontSize: 13),
                    floatingLabelStyle: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                    prefixIcon: const Icon(Icons.password, color: Color(0xFFD4AF37), size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePin ? Icons.visibility : Icons.visibility_off, color: Colors.white54, size: 18),
                      onPressed: () => setState(() => _obscurePin = !_obscurePin),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF14061A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    hintText: 'مثال: 202688 أو كلمة سرية خاصة',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 11, letterSpacing: 0),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 4) return 'يجب ألا يقل الرمز عن 4 أرقام أو حروف';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Confirm Master PIN Field
                TextFormField(
                  controller: _confirmPinCtrl,
                  obscureText: _obscureConfirm,
                  style: const TextStyle(color: Color(0xFFD4AF37), fontFamily: 'Tajawal', fontWeight: FontWeight.bold, letterSpacing: 2),
                  decoration: InputDecoration(
                    labelText: 'تأكيد رمز الأمان السري الجديد',
                    labelStyle: const TextStyle(color: Colors.white70, fontFamily: 'Tajawal', fontSize: 13),
                    floatingLabelStyle: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                    prefixIcon: const Icon(Icons.check_circle_outline, color: Color(0xFFD4AF37), size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off, color: Colors.white54, size: 18),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF14061A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) {
                    if (v != _newPinCtrl.text) return 'رمز الأمان وتأكيده غير متطابقين';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(color: Colors.white60, fontFamily: 'Tajawal')),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            foregroundColor: const Color(0xFF1A0A1F),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isLoading ? null : _submit,
          icon: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A0A1F)))
              : const Icon(Icons.save, size: 18, color: Color(0xFF1A0A1F)),
          label: Text(
            _isLoading ? 'جاري الحفظ...' : 'حفظ رمز الأمان الجديد',
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A0A1F),
            ),
          ),
        ),
      ],
    );
  }
}
