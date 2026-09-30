import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('Generate Legal & Administrative Field Audit Guide PDF (Zero Budget Strategy)', () async {
    final pdf = pw.Document();

    final fontDataRegular = File('assets/fonts/Tajawal-Regular.ttf').readAsBytesSync();
    final fontDataBold = File('assets/fonts/Tajawal-Bold.ttf').readAsBytesSync();
    final ttfRegular = pw.Font.ttf(fontDataRegular.buffer.asByteData());
    final ttfBold = pw.Font.ttf(fontDataBold.buffer.asByteData());

    // Official Palette
    const bgLight = PdfColors.white;
    final bgCardLight = PdfColor.fromHex('#F8FAFC');
    final bgCardTint = PdfColor.fromHex('#FDF8E2');
    final goldPrimary = PdfColor.fromHex('#9A6B00');
    final goldBorder = PdfColor.fromHex('#D4AF37');
    final textDark = PdfColor.fromHex('#0F172A');
    final textBody = PdfColor.fromHex('#1E293B');
    final textMuted = PdfColor.fromHex('#64748B');
    final redCrimson = PdfColor.fromHex('#881337');
    final redDangerBg = PdfColor.fromHex('#FEF2F2');
    final greenEmerald = PdfColor.fromHex('#047857');
    final greenSuccessBg = PdfColor.fromHex('#ECFDF5');
    final greenSuccessBorder = PdfColor.fromHex('#059669');
    final orangeWarningBg = PdfColor.fromHex('#FFF7ED');
    final orangeWarningBorder = PdfColor.fromHex('#EA580C');

    pw.PageTheme getPortraitTheme() {
      return pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 26, vertical: 22),
        theme: pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold),
        textDirection: pw.TextDirection.rtl,
        buildBackground: (pw.Context context) {
          return pw.Container(color: bgLight);
        },
      );
    }

    pw.Widget buildPageHeader(String subtitle, int pageNum, int totalPages) {
      return pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 6),
        margin: const pw.EdgeInsets.only(bottom: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: goldBorder, width: 1.2)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'الجمهورية الجزائرية الديمقراطية الشعبية • مديرية التجارة لولاية سطيف',
                  style: pw.TextStyle(font: ttfBold, fontSize: 9, color: goldPrimary),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  subtitle,
                  style: pw.TextStyle(font: ttfBold, fontSize: 11, color: textDark),
                ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: pw.BoxDecoration(
                color: bgCardTint,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: goldBorder, width: 0.7),
              ),
              child: pw.Text(
                'صفحة $pageNum من $totalPages',
                style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: goldPrimary),
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget buildPageFooter() {
      return pw.Container(
        padding: const pw.EdgeInsets.only(top: 5),
        decoration: pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColor.fromHex('#E2E8F0'), width: 0.8)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'منظومة DCW-SETIF TRACKER • الدليل التنفيذي المعتمد لمكافحة التحايل الميداني',
              style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: textMuted),
            ),
            pw.Text(
              'سري وإداري — معتمد للمدير الولائي ورؤساء المصالح',
              style: pw.TextStyle(font: ttfBold, fontSize: 8, color: redCrimson),
            ),
          ],
        ),
      );
    }

    const totalPages = 4;

    // =========================================================================
    // PAGE 1: COVER & ZERO-BUDGET DIAGNOSIS & LEGAL FRAMEWORK
    // =========================================================================
    pdf.addPage(
      pw.Page(
        pageTheme: getPortraitTheme(),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Official Header
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: goldBorder, width: 1),
                  borderRadius: pw.BorderRadius.circular(8),
                  color: bgCardLight,
                ),
                child: pw.Column(
                  children: [
                    pw.Text('الجمهورية الجزائرية الديمقراطية الشعبية',
                        style: pw.TextStyle(font: ttfBold, fontSize: 12, color: textDark)),
                    pw.SizedBox(height: 2),
                    pw.Text('وزارة التجارة الداخلية وضبط السوق الوطنية',
                        style: pw.TextStyle(font: ttfBold, fontSize: 10.5, color: redCrimson)),
                    pw.SizedBox(height: 1),
                    pw.Text('مديرية التجارة وترقية الصادرات لولاية سطيف',
                        style: pw.TextStyle(font: ttfBold, fontSize: 9.5, color: textDark)),
                    pw.Text('مصلحة الإدارة والوسائل • مكتب المستخدمين • مكتب الرقمنة والأنظمة',
                        style: pw.TextStyle(font: ttfRegular, fontSize: 8.5, color: textMuted)),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Main Banner
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: pw.BoxDecoration(
                  color: redCrimson,
                  borderRadius: pw.BorderRadius.circular(10),
                  border: pw.Border.all(color: goldBorder, width: 1.5),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'الدليل الإداري والقانوني والتقني الشامل لمكافحة التحايل في الرقابة الميدانية',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: ttfBold, fontSize: 13.5, color: PdfColors.white),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'استراتيجية الميزانية الصفرية: حل معضلة الأجهزة واللوحات الرقمية (Zero-Budget & BYOD Strategy)',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: ttfBold, fontSize: 10, color: PdfColor.fromHex('#FEF08A')),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Metadata card
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: bgCardTint,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: goldBorder, width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Text('المرجع: د.ت.س/رقمنة-تفتيش/2026-09',
                        style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: goldPrimary)),
                    pw.Text('التصنيف: استراتيجية إدارية تنفيذية سيادية',
                        style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: redCrimson)),
                    pw.Text('تاريخ السريان: 30 سبتمبر 2026',
                        style: pw.TextStyle(font: ttfRegular, fontSize: 8.5, color: textDark)),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Section 1: Zero-Budget Reality
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                  borderRadius: pw.BorderRadius.circular(8),
                  color: bgLight,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 18,
                          height: 18,
                          alignment: pw.Alignment.center,
                          decoration: pw.BoxDecoration(color: goldPrimary, shape: pw.BoxShape.circle),
                          child: pw.Text('1', style: pw.TextStyle(font: ttfBold, fontSize: 9, color: PdfColors.white)),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text('تشخيص عجز الميزانية: لماذا لا نشتري لوحات إلكترونية (Tablettes)؟',
                            style: pw.TextStyle(font: ttfBold, fontSize: 10.5, color: redCrimson)),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'في إطار ترشيد النفقات العمومية وتعليمات التحكم في ميزانية التسيير، يستحيل على المديرية الولائية اقتناء لوحات رقمية (Tablettes) أو هواتف مهنية وشرائح اتصال لكافة أعوان التفتيش (أكثر من 80 مفتشاً ميدانياً). كما أن اقتناء الأجهزة اللوحية يفرض أعباء صيانة، تأمين، وتعويضات في حال الضياع أو الكسر.',
                      style: pw.TextStyle(font: ttfRegular, fontSize: 8.8, color: textBody, lineSpacing: 1.3),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(
                        color: orangeWarningBg,
                        border: pw.Border.all(color: orangeWarningBorder, width: 1),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        'الإشكال القانوني المطروح: تنص المادة 30 من الأمر 06-03 على حق الموظف في توفير وسائل العمل. لذلك لا يمكن قانوناً إجبار المفتش قسراً على استعمال هاتفه الشخصي. لكن الإدارة تملك السلطة التنظيمية الكاملة لتحديد مسارات وضوابط الاستفادة من التسهيلات الميدانية!',
                        style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: PdfColor.fromHex('#7C2D12')),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // Section 2: Framework summary
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                  borderRadius: pw.BorderRadius.circular(8),
                  color: bgLight,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 18,
                          height: 18,
                          alignment: pw.Alignment.center,
                          decoration: pw.BoxDecoration(color: goldPrimary, shape: pw.BoxShape.circle),
                          child: pw.Text('2', style: pw.TextStyle(font: ttfBold, fontSize: 9, color: PdfColors.white)),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text('المبادئ الحاكمة للاستراتيجية الصفرية (Zero-Budget Axioms)',
                            style: pw.TextStyle(font: ttfBold, fontSize: 10.5, color: textDark)),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Bullet(
                      text: 'صفر دينار نفقات أجهزة: استثمار كامل في البنية البرمجية الحالية (Node.js + PostgreSQL + Flutter).',
                      style: pw.TextStyle(font: ttfRegular, fontSize: 8.5, color: textBody),
                    ),
                    pw.Bullet(
                      text: 'صفر دينار نفقات إنترنت 4G: التطبيق يعمل بكفاءة 100% بنظام Offline مع استغلال GPS الأقمار الصناعية المجاني ومزامنة البيانات عند توفر Wi-Fi المقر أو المنزل.',
                      style: pw.TextStyle(font: ttfRegular, fontSize: 8.5, color: textBody),
                    ),
                    pw.Bullet(
                      text: 'الالتزام التام بالقانون 18-07: احترام حرمة الحياة الخاصة بعدم طلب أي وصول لصور الموظف، رسائله، أو جهات اتصاله، واقتصار الإذن حصراً على إحداثية نقطة المعاينة لحظة إرسال المحضر.',
                      style: pw.TextStyle(font: ttfRegular, fontSize: 8.5, color: textBody),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),
              buildPageFooter(),
            ],
          );
        },
      ),
    );

    // =========================================================================
    // PAGE 2: THE MASTERSTROKE — DOUBLE PROTOCOL & INCENTIVE INVERSION
    // =========================================================================
    pdf.addPage(
      pw.Page(
        pageTheme: getPortraitTheme(),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              buildPageHeader('المحور الثاني • هندسة البروتوكول المزدوج وقلب المعادلة الإدارية', 2, totalPages),

              // Title concept
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: bgCardTint,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: goldBorder, width: 0.8),
                ),
                child: pw.Text(
                  'فلسفة "قلب المعادلة": بدلاً من مصادمة الموظف لإجباره على استخدام هاتفه، يتم جعل النظام الورقي البديل صارماً ومقيداً، بينما يمثل التطبيق الذكي امتيازاً مريحاً يطلبه الموظف طواعية!',
                  style: pw.TextStyle(font: ttfBold, fontSize: 9.2, color: redCrimson, lineSpacing: 1.3),
                  textAlign: pw.TextAlign.center,
                ),
              ),

              pw.SizedBox(height: 10),

              // Comparison Table / Cards
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Option A: Paper Protocol (Restrictive)
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(9),
                      decoration: pw.BoxDecoration(
                        color: orangeWarningBg,
                        border: pw.Border.all(color: orangeWarningBorder, width: 1.2),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('[أ] الخيار (أ): البروتوكول الورقي الكلاسيكي',
                              style: pw.TextStyle(font: ttfBold, fontSize: 9.5, color: PdfColor.fromHex('#9A3412'))),
                          pw.Text('يطبق إجبارياً على من يرفض التطبيق الرقمي',
                              style: pw.TextStyle(font: ttfRegular, fontSize: 7.5, color: textMuted)),
                          pw.SizedBox(height: 6),
                          pw.Text('• الحضور الفعلي للمقر 3 مرات يومياً:',
                              style: pw.TextStyle(font: ttfBold, fontSize: 8.3, color: textDark)),
                          pw.Text('  1) 08:00 صباحاً: توقيع سجل الحضور واستلام أوامر المهمة الورقية والمحاضر الكربونية.',
                              style: pw.TextStyle(font: ttfRegular, fontSize: 7.8, color: textBody)),
                          pw.Text('  2) 12:30 ظهراً: عودة إلزامية للمقر لإيداع محاضر الصباح وتأشير سجل الغداء.',
                              style: pw.TextStyle(font: ttfRegular, fontSize: 7.8, color: textBody)),
                          pw.Text('  3) 16:00 إلى 16:30: عودة إلزامية لتوقيع دفتر الانصراف وإيداع تقارير المساء.',
                              style: pw.TextStyle(font: ttfRegular, fontSize: 7.8, color: textBody)),
                          pw.SizedBox(height: 4),
                          pw.Text('• كتابة التقارير والمحاضر والإحصائيات الشهرية يدوياً بقلم الحبر مع التدقيق الحرفي.',
                              style: pw.TextStyle(font: ttfRegular, fontSize: 7.8, color: textBody)),
                          pw.SizedBox(height: 4),
                          pw.Text('• المنع البات من التسريح المباشر من الميدان نحو البيت (يعتبر غياباً غير مبرر).',
                              style: pw.TextStyle(font: ttfBold, fontSize: 7.8, color: PdfColor.fromHex('#991B1B'))),
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(width: 10),

                  // Option B: Digital Protocol (Privileged)
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(9),
                      decoration: pw.BoxDecoration(
                        color: greenSuccessBg,
                        border: pw.Border.all(color: greenSuccessBorder, width: 1.2),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('[ب] الخيار (ب): البروتوكول الرقمي المرن',
                              style: pw.TextStyle(font: ttfBold, fontSize: 9.5, color: greenEmerald)),
                          pw.Text('امتياز إداري مخصص لمن ينخرط طوعياً في التطبيق',
                              style: pw.TextStyle(font: ttfRegular, fontSize: 7.5, color: textMuted)),
                          pw.SizedBox(height: 6),
                          pw.Text('• التسريح الميداني المباشر نحو المنزل:',
                              style: pw.TextStyle(font: ttfBold, fontSize: 8.3, color: textDark)),
                          pw.Text('  تسجيل الانصراف بنقرة زر من آخر نقطة تفتيش ميدانية والذهاب مباشرة للبيت دون قطع مسافات العودة لمقر حي المعبودة.',
                              style: pw.TextStyle(font: ttfRegular, fontSize: 7.8, color: textBody)),
                          pw.SizedBox(height: 4),
                          pw.Text('• إعفاء تام من العودة للمقر منتصف النهار:',
                              style: pw.TextStyle(font: ttfBold, fontSize: 8.3, color: textDark)),
                          pw.Text('  حرية تناول وجبة الغداء داخل قطاع التفتيش الميداني دون التقييد بحضور المقر.',
                              style: pw.TextStyle(font: ttfRegular, fontSize: 7.8, color: textBody)),
                          pw.SizedBox(height: 4),
                          pw.Text('• توليد المحاضر والتقارير آلياً (PDF): بنقرة زر ودون الحاجة لأي كتابة يدوية مرهقة.',
                              style: pw.TextStyle(font: ttfRegular, fontSize: 7.8, color: textBody)),
                          pw.SizedBox(height: 4),
                          pw.Text('• أولوية احتساب علاوة المردودية والتعويضات بناءً على دقة التوثيق الرقمي.',
                              style: pw.TextStyle(font: ttfBold, fontSize: 7.8, color: greenEmerald)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 12),

              // Psychological Result Box
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: bgCardLight,
                  border: pw.Border.all(color: goldBorder, width: 1),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('[!] النتيجة السيكولوجية والتنفيذية الحتمية:',
                        style: pw.TextStyle(font: ttfBold, fontSize: 10, color: redCrimson)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'عندما يدرك المفتش أن رفض التطبيق سيكلفه ركوب سيارته والعودة للمديرية 3 مرات يومياً، وضياع ساعتين في زحام الطرقات لكتابة محاضر يدوية، فإنه سيسارع بنفسه إلى مكتب المستخدمين ومعه هاتفه الشخصي، مطالباً بتثبيت التطبيق وموقعاً على استمارة الانخراط الطوعي! وهكذا تحول عجز الميزانية من عائق للإدارة إلى أقوى حافز للانضباط.',
                      style: pw.TextStyle(font: ttfRegular, fontSize: 8.8, color: textBody, lineSpacing: 1.3),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // Table: Summary of Rights vs Obligations
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1')),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Table(
                  border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0'), width: 0.6),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.5),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FlexColumnWidth(3),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: textDark),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('معيار التقييم', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: PdfColors.white)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('النظام الورقي (المتعنت)', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: PdfColor.fromHex('#FCA5A5'))),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('النظام الرقمي (المنخرط)', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: PdfColor.fromHex('#86EFAC'))),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('حركات التنقل اليومية', style: pw.TextStyle(font: ttfBold, fontSize: 8, color: textDark))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('3 رحلات إجبارية للمقر الرئيسي', style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: textBody))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('رحلة واحدة صباحاً فقط (أو انطلاق ميداني)', style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: textBody))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('انصراف نهاية الدوام', style: pw.TextStyle(font: ttfBold, fontSize: 8, color: textDark))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('حصراً بمكتب الأمانة 16:30', style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: textBody))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('تسريح مباشر للمنزل من الميدان', style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: textBody))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('إعداد التقارير والمحاضر', style: pw.TextStyle(font: ttfBold, fontSize: 8, color: textDark))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('يدوي بقلم الحبر مع نسخ كربونية', style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: textBody))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('توليد فوري PDF وحفظ سحابي آمن', style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: textBody))),
                      ],
                    ),
                  ],
                ),
              ),

              pw.Spacer(),
              buildPageFooter(),
            ],
          );
        },
      ),
    );

    // =========================================================================
    // PAGE 3: DEFEATING THE CHEATING TRICKS (PHONE LEAVING & SENSOR TRAPS)
    // =========================================================================
    pdf.addPage(
      pw.Page(
        pageTheme: getPortraitTheme(),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              buildPageHeader('المحور الثالث • إسقاط حيل التحايل السيكولوجية والتقنية في السيرفر', 3, totalPages),

              pw.Text(
                'تفكيك الحيل الأكثر شيوعاً: ترك الهاتف عند التاجر أو في البيت أو استعمال هاتف ثانوي',
                style: pw.TextStyle(font: ttfBold, fontSize: 10.5, color: redCrimson),
              ),
              pw.SizedBox(height: 6),

              // Breakdown of Trick 1: Leaving phone with merchant
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                margin: const pw.EdgeInsets.only(bottom: 8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                  borderRadius: pw.BorderRadius.circular(6),
                  color: bgCardLight,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('الحيلة 1: المفتش يترك هاتفه عند تاجر صديق لتسجيل الانصراف له في 16:30',
                            style: pw.TextStyle(font: ttfBold, fontSize: 8.8, color: redCrimson)),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(color: redDangerBg, borderRadius: pw.BorderRadius.circular(4)),
                          child: pw.Text('مستحيلة واقعياً وتقنياً', style: pw.TextStyle(font: ttfBold, fontSize: 7.5, color: redCrimson)),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '• المانع السيكولوجي والشخصي: بما أن التطبيق مصطب على الهاتف الشخصي اليومي للمفتش، فإنه يحتوي على صوره العائلية، محادثات الواتساب الخاصة، وتطبيقاته البنكية. لا يوجد موظف سوي يفرط في هاتفه الخاص ويتركه في عهدة تاجر غريب لساعات!\n• القفل التقني بالسيرفر: يرفض السيرفر أي طلب تسجيل انصراف بعد 15:00 ما لم يكن مسبوقاً بمحضر معاينة ميداني حقيقي تم رفعه بعد الساعة 13:30. والتاجر لا يملك صفة الضبطية القضائية ولا يستطيع تفتيش محلات منافسيه!',
                      style: pw.TextStyle(font: ttfRegular, fontSize: 8.2, color: textBody, lineSpacing: 1.25),
                    ),
                  ],
                ),
              ),

              // Breakdown of Trick 2: Leaving phone at home with spouse/son
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                margin: const pw.EdgeInsets.only(bottom: 8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                  borderRadius: pw.BorderRadius.circular(6),
                  color: bgCardLight,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('الحيلة 2: ترك الهاتف في المنزل مع الزوجة أو الابن وممارسة عمل حر',
                            style: pw.TextStyle(font: ttfBold, fontSize: 8.8, color: redCrimson)),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(color: redDangerBg, borderRadius: pw.BorderRadius.circular(4)),
                          child: pw.Text('تسقط بخوارزمية الفرقة', style: pw.TextStyle(font: ttfBold, fontSize: 7.5, color: redCrimson)),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '• خوارزمية انشطار الفرقة الرقابية (Brigade Separation): في التشريع الجزائري، التفتيش يتم بفرق ثنائية على الأقل (رئيس فرقة + عون رقابة). إذا كان هاتف العون في البيت وهاتف زميله في قطاع النشاط وسط مدينة سطيف (فارق أكثر من 300م لمدة تتجاوز 15 دقيقة)، يُطلق السيرفر إنذاراً فورياً للمدير: "شبهة افتراق فرقة وغياب أحد العضوين".\n• كاشف ركود الهاتف والجمود الحركي: قراءة مستشعر التسارع (0.00G) تؤكد أن الجهاز موضوع فوق طاولة بالمنزل ولم يشهد أي خطوة بشرية طوال 3 ساعات!',
                      style: pw.TextStyle(font: ttfRegular, fontSize: 8.2, color: textBody, lineSpacing: 1.25),
                    ),
                  ],
                ),
              ),

              // Breakdown of Trick 3: Dedicated burner phone
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                margin: const pw.EdgeInsets.only(bottom: 8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                  borderRadius: pw.BorderRadius.circular(6),
                  color: bgCardLight,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('الحيلة 3: شراء هاتف ثانوي رخيص (Burner) خصيصاً للتحايل على النظام',
                            style: pw.TextStyle(font: ttfBold, fontSize: 8.8, color: redCrimson)),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(color: redDangerBg, borderRadius: pw.BorderRadius.circular(4)),
                          child: pw.Text('تسقط بالمأمورية الخاطفة', style: pw.TextStyle(font: ttfBold, fontSize: 7.5, color: redCrimson)),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      '• المأمورية التفتيشية الخاطفة (Flash Inspection Mission): يملك المدير الولائي ورئيس المصلحة في لوحة القيادة زر "تكليف فجائي طارئ". يُرسل إشعار على الهاتف في تمام 14:45 بتفتيش مستودع أو محل محدد في عين المكان مع مهلة 25 دقيقة لتسجيل المحضر. إذا كان الهاتف الثانوي مع شخص آخر أو في البيت، يعجز تماماً عن التنفيذ ويثبت الغياب والتزوير فوراً!\n• الاتصال الهاتفي الصوتي المفاجئ: الاتصال بالرقم الشخصي المسجل بالملف الإداري يثبت فورا مكان تواجد الموظف.',
                      style: pw.TextStyle(font: ttfRegular, fontSize: 8.2, color: textBody, lineSpacing: 1.25),
                    ),
                  ],
                ),
              ),

              // Architecture efficiency box
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: greenSuccessBg,
                  border: pw.Border.all(color: greenSuccessBorder, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  children: [
                    pw.Container(
                      width: 20,
                      height: 20,
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(color: greenEmerald, shape: pw.BoxShape.circle),
                      child: pw.Text('+', style: pw.TextStyle(font: ttfBold, fontSize: 10, color: PdfColors.white)),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                      child: pw.Text(
                        'كفاءة المعمارية: كافة هذه الفحوصات تتم في الخادم السحابي (Node.js) خلال أجزاء من الثانية دون إثقال قاعدة البيانات ودون استهلاك بطارية هاتف المفتش إطلاقاً.',
                        style: pw.TextStyle(font: ttfBold, fontSize: 8.2, color: greenEmerald),
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),
              buildPageFooter(),
            ],
          );
        },
      ),
    );

    // =========================================================================
    // PAGE 4: LEGAL ADOPTION FORM & OFFICIAL LEADERSHIP ENDORSEMENT
    // =========================================================================
    pdf.addPage(
      pw.Page(
        pageTheme: getPortraitTheme(),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              buildPageHeader('المحور الرابع • النموذج الإداري القانوني للانخراط ومصادقة القيادة', 4, totalPages),

              // Legal Form Box
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: goldBorder, width: 1.2),
                  borderRadius: pw.BorderRadius.circular(8),
                  color: bgCardLight,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      alignment: pw.Alignment.center,
                      padding: const pw.EdgeInsets.only(bottom: 6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border(bottom: pw.BorderSide(color: goldBorder, width: 0.8)),
                      ),
                      child: pw.Text(
                        'استمارة رسمية: طلب وتعهد الانخراط الطوعي في نظام العمل الميداني الرقمي المرن',
                        style: pw.TextStyle(font: ttfBold, fontSize: 9.5, color: redCrimson),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'أنا الموقع أسفله: ............................................................................................ الرتبة: ......................................................\nالمصلحة / الفرقة: ....................................................................................... رقم الهاتف النقال: ....................................................',
                      style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: textDark, lineSpacing: 1.4),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'بناءً على المنشور التنظيمي الداخلي المحدد لشروط التسهيلات الميدانية، أصرح بملء إرادتي ورغبتي الطوعية التامة في تثبيت واستخدام المنصة الرقمية الرسمية (DCW-SETIF-TRACKER) على هاتفي النقال الشخصي، وذلك للاستفادة من الامتيازات الإدارية التالية:',
                      style: pw.TextStyle(font: ttfRegular, fontSize: 8.2, color: textBody, lineSpacing: 1.25),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('1. الاستفادة الحصرية من ميزة الانصراف الميداني المباشر نحو مقر السكن دون إلزامية العودة لمقر المديرية مساءً.',
                        style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: textBody)),
                    pw.Text('2. الإعفاء التام من الحضور الشخصي في منتصف النهار لتأشير سجلات الحضور الورقية.',
                        style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: textBody)),
                    pw.Text('3. التوليد والتوثيق الآلي الفوري لكافة محاضر المعاينة والتقارير الرقابية (PDF) دون كتابة يدوية.',
                        style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: textBody)),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'أتعهد بالانضباط التام لأوقات العمل الرسمية المقررة قانوناً والامتناع التام عن أي تداول أو تسليم للحساب أو الهاتف لأي طرف آخر، مع علمي بأن إحداثيات المعاينة الميدانية موثقة رقمياً وتعتبر حجة إدارية رسمية.',
                      style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: textBody, lineSpacing: 1.2),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('حرر بسطيف في: ..................................', style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: textMuted)),
                        pw.Text('توقيع وبصمة الموظف (طوعياً): ............................................', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: textDark)),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              // Legal protection statement
              pw.Container(
                padding: const pw.EdgeInsets.all(7),
                decoration: pw.BoxDecoration(
                  color: bgCardTint,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: goldBorder, width: 0.7),
                ),
                child: pw.Text(
                  'الأثر القانوني للاستمارة: هذا التوقيع الطوعي يحصن الإدارة تحصيناً قانونياً مطلقاً أمام مفتشية الوظيفة العمومية وأمام النقابات؛ حيث يسقط أي ادعاء بالإجبار أو خرق المادة 30 من الأمر 06-03 أو خرق القانون 18-07 لحماية المعطيات الشخصية.',
                  style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: goldPrimary, lineSpacing: 1.2),
                  textAlign: pw.TextAlign.center,
                ),
              ),

              pw.SizedBox(height: 12),

              // Authentic Leadership Signature Blocks (4 Official Columns)
              pw.Text('المصادقة والاعتماد الإداري والتقني الرسمي:',
                  style: pw.TextStyle(font: ttfBold, fontSize: 9.5, color: redCrimson)),
              pw.SizedBox(height: 6),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Director
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: goldBorder, width: 0.9),
                        borderRadius: pw.BorderRadius.circular(6),
                        color: bgCardLight,
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text('المدير الولائي للتجارة', style: pw.TextStyle(font: ttfBold, fontSize: 7.8, color: goldPrimary)),
                          pw.SizedBox(height: 2),
                          pw.Text('حمادي رشيد', style: pw.TextStyle(font: ttfBold, fontSize: 9, color: textDark)),
                          pw.Text('الآمر بالصرف ورئيس العمليات', style: pw.TextStyle(font: ttfRegular, fontSize: 6.8, color: textMuted)),
                          pw.SizedBox(height: 16),
                          pw.Text('[التأشيرة والختم الرسمي]', style: pw.TextStyle(font: ttfRegular, fontSize: 6.5, color: textMuted)),
                        ],
                      ),
                    ),
                  ),

                  // Head of Administration & Resources
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.8),
                        borderRadius: pw.BorderRadius.circular(6),
                        color: bgCardLight,
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text('رئيس مصلحة الإدارة والوسائل', style: pw.TextStyle(font: ttfBold, fontSize: 7.5, color: redCrimson)),
                          pw.SizedBox(height: 2),
                          pw.Text('لعلامي كمال', style: pw.TextStyle(font: ttfBold, fontSize: 8.8, color: textDark)),
                          pw.Text('الوصاية وتنظيم المرفق العام', style: pw.TextStyle(font: ttfRegular, fontSize: 6.8, color: textMuted)),
                          pw.SizedBox(height: 16),
                          pw.Text('[التأشيرة والختم]', style: pw.TextStyle(font: ttfRegular, fontSize: 6.5, color: textMuted)),
                        ],
                      ),
                    ),
                  ),

                  // Bureau Chief of Personnel
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.8),
                        borderRadius: pw.BorderRadius.circular(6),
                        color: bgCardLight,
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text('رئيس مكتب المستخدمين', style: pw.TextStyle(font: ttfBold, fontSize: 7.5, color: redCrimson)),
                          pw.SizedBox(height: 2),
                          pw.Text('عصماني سعاد', style: pw.TextStyle(font: ttfBold, fontSize: 8.8, color: textDark)),
                          pw.Text('إدارة المسار والانضباط', style: pw.TextStyle(font: ttfRegular, fontSize: 6.8, color: textMuted)),
                          pw.SizedBox(height: 16),
                          pw.Text('[التأشيرة والختم]', style: pw.TextStyle(font: ttfRegular, fontSize: 6.5, color: textMuted)),
                        ],
                      ),
                    ),
                  ),

                  // System Admin & Digitization
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      margin: const pw.EdgeInsets.symmetric(horizontal: 2),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.8),
                        borderRadius: pw.BorderRadius.circular(6),
                        color: bgCardLight,
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text('مدير النظام والرقمنة', style: pw.TextStyle(font: ttfBold, fontSize: 7.5, color: goldPrimary)),
                          pw.SizedBox(height: 2),
                          pw.Text('عكرور توفيق', style: pw.TextStyle(font: ttfBold, fontSize: 8.8, color: textDark)),
                          pw.Text('مكتب الإعلام الآلي والأنظمة', style: pw.TextStyle(font: ttfRegular, fontSize: 6.8, color: textMuted)),
                          pw.SizedBox(height: 16),
                          pw.Text('[التأشيرة الفنية]', style: pw.TextStyle(font: ttfRegular, fontSize: 6.5, color: textMuted)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.Spacer(),
              buildPageFooter(),
            ],
          );
        },
      ),
    );

    // Save outputs in multiple target locations
    final pdfBytes = await pdf.save();

    final outputFileRoot = File('../LEGAL_ADMINISTRATIVE_FIELD_AUDIT_GUIDE.pdf');
    final outputFileTracker = File('LEGAL_ADMINISTRATIVE_FIELD_AUDIT_GUIDE.pdf');
    final outputFileDocs = File('../docs/LEGAL_ADMINISTRATIVE_FIELD_AUDIT_GUIDE.pdf');

    await outputFileRoot.writeAsBytes(pdfBytes);
    await outputFileTracker.writeAsBytes(pdfBytes);
    await outputFileDocs.writeAsBytes(pdfBytes);

    // ignore: avoid_print
    print('✅ Executive Legal & Administrative Field Audit Guide PDF Generated in:');
    // ignore: avoid_print
    print('  - ${outputFileRoot.absolute.path}');
    // ignore: avoid_print
    print('  - ${outputFileTracker.absolute.path}');
    // ignore: avoid_print
    print('  - ${outputFileDocs.absolute.path}');
  });
}
