import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drh_setif_tracker/services/auth_service.dart';
import 'package:drh_setif_tracker/utils/theme.dart';
import 'package:drh_setif_tracker/screens/common/inquiry_letter_dialog.dart';

class InspectorInquiriesSheet extends StatefulWidget {
  final int employeeId;

  const InspectorInquiriesSheet({super.key, required this.employeeId});

  static void show(BuildContext context, int employeeId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InspectorInquiriesSheet(employeeId: employeeId),
    );
  }

  @override
  State<InspectorInquiriesSheet> createState() => _InspectorInquiriesSheetState();
}

class _InspectorInquiriesSheetState extends State<InspectorInquiriesSheet> {
  List<Map<String, dynamic>> _inquiries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<AuthService>().api;
      final list = await api.getInquiries(employeeId: widget.employeeId);
      if (mounted) {
        setState(() {
          _inquiries = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showReplyDialog(Map<String, dynamic> inquiry) {
    final replyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF16121E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
        ),
        title: Row(
          children: [
            const Icon(Icons.reply, color: Color(0xFFD4AF37)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'الرد على الاستفسار #${inquiry['Id']}',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFFD4AF37),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الموضوع: ${inquiry['Subject']}',
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'اكتب تبريراتك وأسباب الغياب/التأخر بالتفصيل لرفعها إلى المدير الولائي:',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11,
                color: AppTheme.TextSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: replyCtrl,
              maxLines: 4,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'مثال: سبب التأخر كان عطلاً مفاجئاً في مركبة التفتيش / مهمة رقابية استعجالية خارج الولاية...',
                hintStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white38),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (replyCtrl.text.trim().isEmpty) return;
              try {
                final api = context.read<AuthService>().api;
                await api.replyToInquiry(inquiry['Id'] as int, replyCtrl.text.trim());
                if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ تم إرسال ردك على الاستفسار بنجاح إلى المدير الولائي ومكتب المستخدمين'),
                    backgroundColor: AppTheme.SuccessColor,
                  ),
                );
                _load();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: AppTheme.DangerColor),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('إرسال الرد الرسمي', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF130F1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.mail_outline, color: Color(0xFFD4AF37), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الاستفسارات الإدارية الواردة',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Demandes d\'Explications - أجل الرد القانوني 48 ساعة',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 10,
                          color: AppTheme.TextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
                : _inquiries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 56,
                              color: AppTheme.SuccessColor.withValues(alpha: 0.8),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'لا توجد أي استفسارات إدارية بحقك ✨',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'سجل الحضور والمردودية الميدانية منضبط تماماً',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11,
                                color: AppTheme.TextSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _inquiries.length,
                        itemBuilder: (ctx, i) {
                          final inq = _inquiries[i];
                          final status = inq['Status'] ?? 'sent';
                          final isAnswered = inq['EmployeeReply'] != null && inq['EmployeeReply'].toString().isNotEmpty;

                          Color statusColor = AppTheme.WarningColor;
                          String statusText = 'بانتظار ردك (48 ساعة)';
                          if (status == 'answered') {
                            statusColor = Colors.cyan;
                            statusText = 'تم إرسال ردك — قيد دراسة المدير';
                          } else if (status == 'justified') {
                            statusColor = AppTheme.SuccessColor;
                            statusText = '✅ تم قبول تبريرك وحفظ الملف';
                          } else if (status == 'warning') {
                            statusColor = Colors.orange;
                            statusText = '⚠️ تم توجيه تنبيه إداري';
                          } else if (status == 'deduction_ordered' || status == 'executed') {
                            statusColor = AppTheme.DangerColor;
                            statusText = '❌ قرار خصم (${inq['DeductionDays'] ?? 1} يوم)';
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.CardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: status == 'sent'
                                    ? const Color(0xFFD4AF37).withValues(alpha: 0.5)
                                    : AppTheme.BorderColor.withValues(alpha: 0.3),
                              ),
                              boxShadow: [
                                if (status == 'sent')
                                  BoxShadow(
                                    color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      inq['IncidentDate'] != null
                                          ? inq['IncidentDate'].toString().substring(0, 10)
                                          : 'اليوم',
                                      style: const TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 11,
                                        color: AppTheme.TextSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${inq['Subject']}',
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                if (inq['Details'] != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '${inq['Details']}',
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 11,
                                      color: Colors.white70,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                                if (isAnswered) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.check_circle, size: 14, color: AppTheme.SuccessColor),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'ردك: ${inq['EmployeeReply']}',
                                            style: const TextStyle(
                                              fontFamily: 'Tajawal',
                                              fontSize: 11,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => InquiryLetterDialog.show(context, inq),
                                      icon: const Icon(Icons.visibility, size: 16, color: Color(0xFFD4AF37)),
                                      label: const Text(
                                        'عرض الاستمارة الرسمية',
                                        style: TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontSize: 11,
                                          color: Color(0xFFD4AF37),
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFFD4AF37)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (!isAnswered && status == 'sent')
                                      ElevatedButton.icon(
                                        onPressed: () => _showReplyDialog(inq),
                                        icon: const Icon(Icons.reply, size: 16),
                                        label: const Text(
                                          'كتابة الرد الرسمي',
                                          style: TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFD4AF37),
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
