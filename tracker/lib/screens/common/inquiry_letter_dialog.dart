import 'package:flutter/material.dart';
import 'package:drh_setif_tracker/utils/theme.dart';
import 'package:drh_setif_tracker/services/pdf_report_service.dart';

class InquiryLetterDialog extends StatelessWidget {
  final Map<String, dynamic> inquiry;
  final VoidCallback? onPrint;

  const InquiryLetterDialog({
    super.key,
    required this.inquiry,
    this.onPrint,
  });

  static void show(BuildContext context, Map<String, dynamic> inquiry) {
    showDialog(
      context: context,
      builder: (ctx) => InquiryLetterDialog(inquiry: inquiry),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nomAr = inquiry['NomAr'] ?? inquiry['nomar'] ?? inquiry['Nom'] ?? inquiry['nom'] ?? inquiry['name'] ?? inquiry['employeeName'] ?? '';
    final prenomAr = inquiry['PrenomAr'] ?? inquiry['prenomar'] ?? inquiry['Prenom'] ?? inquiry['prenom'] ?? '';
    final name = (nomAr.toString().trim().isNotEmpty || prenomAr.toString().trim().isNotEmpty)
        ? '$nomAr $prenomAr'.trim()
        : (inquiry['EmployeeName'] ?? inquiry['employee_name'] ?? 'عضو فرقة الرقابة والتفتيش').toString();
    final service = (inquiry['Service'] ?? inquiry['service'] ?? 'مديرية التجارة لولاية سطيف').toString();
    final grade = (inquiry['Grade'] ?? inquiry['grade'] ?? 'مفتش رئيسي').toString();
    final rawDate = (inquiry['IncidentDate'] ?? inquiry['incidentdate'] ?? inquiry['Date'] ?? inquiry['date'] ?? inquiry['CreatedAt'] ?? '').toString();
    final dateStr = rawDate.length >= 10 ? rawDate.substring(0, 10) : (rawDate.isNotEmpty ? rawDate : 'اليوم');
    final subject = (inquiry['Subject'] ?? inquiry['subject'] ?? 'استفسار كتابي حول الانضباط ومواقيت العمل').toString();
    final details = (inquiry['Details'] ?? inquiry['details'] ??
        'بناءً على السجلات الرسمية للحضور والانصراف عبر المنصة الرقمية، سُجل بحقكم غياب/تأخر عن موعد العمل الميداني دون إشعار مسبق أو رخصة قانونية.').toString();
    final int lateMins = ((inquiry['LateMinutes'] ?? inquiry['lateminutes'] ?? 0) as num).toInt();
    final reply = inquiry['EmployeeReply'] ?? inquiry['employeereply'] ?? inquiry['Reply'] ?? inquiry['reply'];

    return AlertDialog(
      backgroundColor: const Color(0xFF16121E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.5), width: 1.5),
      ),
      contentPadding: EdgeInsets.zero,
      content: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 700),
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.description, color: Color(0xFFD4AF37), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'استمارة استفسار إداري كتابي رسمي',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Official Printable Document Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Republic of Algeria
                      const Text(
                        'الجمهورية الجزائرية الديمقراطية الشعبية\nوزارة التجارة الداخلية وضبط السوق الوطنية\nمديرية التجارة الداخلية وضبط السوق الوطنية لولاية سطيف\nمصلحة الإدارة والوسائل — مكتب المستخدمين والتكوين',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                      const Divider(color: Color(0xFFD4AF37), height: 24, thickness: 1.2),

                      // Document Metadata
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'الرقم: 2026/استفسار/${inquiry['Id'] ?? '—'}',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              color: Color(0xFFD4AF37),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'سطيف في: $dateStr',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Addressed To
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إلى السيد(ة): $name',
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'الرتبة: $grade  |  المصلحة: $service',
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11,
                                color: AppTheme.TextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Subject & Legal Reference
                      Text(
                        'الموضوع: $subject\nالمرجع: الأمر رقم 06-03 المؤرخ في 15 يوليو 2006 المتضمن القانون الأساسي العام للوظيفة العمومية.',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD4AF37),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Body text
                      Text(
                        '$details\n\n${lateMins > 0 ? "وقد قُدِّر التأخر الفعلي المسجل عن توقيت العمل بـ: $lateMins دقيقة.\n\n" : ""}وعليه، يُطلب منكم موافاة الإدارة ومكتب المستخدمين بتبريراتكم وأسباب ذلك كتابياً عبر التطبيق أو كتابياً، في أجل أقصاه 48 ساعة من تاريخ استلامكم هذا الاستفسار، حتى يتسنى للمدير الولائي اتخاذ الإجراءات الإدارية والقانونية المناسبة.',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          height: 1.6,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Employee Reply Section if answered
                      if (reply != null && reply.toString().isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.SuccessColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.SuccessColor.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.reply, color: AppTheme.SuccessColor, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'رد وتبرير الموظف (المسجل عبر التطبيق):',
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppTheme.SuccessColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$reply',
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 12,
                                  color: Colors.white,
                                  height: 1.4,
                                ),
                              ),
                              if (inquiry['ReplyDate'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'تاريخ الرد: ${inquiry['ReplyDate'].toString().substring(0, 16)}',
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 10,
                                      color: AppTheme.TextSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Director Decision section if decided
                      if (inquiry['DirectorDecision'] != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'قرار المدير الولائي للتجارة:',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFFD4AF37),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                inquiry['DirectorDecision'] == 'justified'
                                    ? '✅ قبول التبرير وحفظ الملف دون عقوبة أو خصم.'
                                    : inquiry['DirectorDecision'] == 'warning'
                                        ? '⚠️ توجيه إنذار/تنبيه إداري رسمي.'
                                        : '❌ تثبيت الخصم القانوني من الراتب بمقدار: ${inquiry['DeductionDays'] ?? 1} يوم.',
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (inquiry['DirectorNotes'] != null && inquiry['DirectorNotes'].toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'ملاحظات المدير: ${inquiry['DirectorNotes']}',
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
                        const SizedBox(height: 16),
                      ],

                      // Official Signatures
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            children: [
                              Text(
                                'تأشيرة مكتب المستخدمين',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                ),
                              ),
                              SizedBox(height: 30),
                              Text(
                                'عـ/ المدير والآمر بالصرف',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 9,
                                  color: AppTheme.TextSecondary,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text(
                                'المدير الولائي للتجارة',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD4AF37),
                                ),
                              ),
                              const SizedBox(height: 30),
                              Text(
                                'ولاية سطيف',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Actions Bottom Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await PdfReportService.generateAndPrintInquiryLetter(inquiry);
                          if (context.mounted && onPrint != null) {
                            onPrint!();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('خطأ في إرسال أمر الطباعة: $e'),
                                backgroundColor: AppTheme.DangerColor,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.print, color: Colors.black, size: 18),
                      label: const Text(
                        'طباعة الاستمارة الرسمية (PDF)',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('إغلاق', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
