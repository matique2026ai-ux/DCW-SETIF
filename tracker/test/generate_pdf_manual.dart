import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('Generate Executive Director Manual PDF - Light Theme with Test Credentials', () async {
    final pdf = pw.Document();

    final fontDataRegular = File('assets/fonts/Tajawal-Regular.ttf').readAsBytesSync();
    final fontDataBold = File('assets/fonts/Tajawal-Bold.ttf').readAsBytesSync();
    final ttfRegular = pw.Font.ttf(fontDataRegular.buffer.asByteData());
    final ttfBold = pw.Font.ttf(fontDataBold.buffer.asByteData());

    // Load images
    pw.MemoryImage? loadImage(String path) {
      final f = File(path);
      if (f.existsSync()) {
        return pw.MemoryImage(f.readAsBytesSync());
      }
      return null;
    }

    final imgLogin = loadImage('../manual_assets/login.png');
    final imgMapSetif = loadImage('../manual_assets/map_setif.png');
    final imgMapEulma = loadImage('../manual_assets/map_eulma.png');
    final imgReports = loadImage('../manual_assets/reports.png');
    final imgDeductions = loadImage('../manual_assets/deductions_grace.png');
    final imgHeadInspectors = loadImage('../manual_assets/head_inspectors.png');
    final imgHeadMissions = loadImage('../manual_assets/head_missions_list.png');
    final imgHeadBrigade = loadImage('../manual_assets/head_create_mission_brigade.png');
    final imgHeadBroadcast = loadImage('../manual_assets/head_create_mission_broadcast.png');
    final imgBureauEmps = loadImage('../manual_assets/bureau_employees.png');
    final imgBureauGrace = loadImage('../manual_assets/bureau_discipline_grace.png');
    final imgBureauModal = loadImage('../manual_assets/bureau_edit_status_modal.png');
    final imgQrHq = loadImage('../manual_assets/qr_hq_certificate.png');
    final imgQrBadge = loadImage('../manual_assets/qr_inspector_badge.png');

    // Light Printer-Friendly Colors
    const bgLight = PdfColors.white;
    final bgCardLight = PdfColor.fromHex('#F8FAFC');
    final bgCardTint = PdfColor.fromHex('#FDF8E2');
    final goldPrimary = PdfColor.fromHex('#9A6B00');
    final goldBorder = PdfColor.fromHex('#D4AF37');
    final textDark = PdfColor.fromHex('#0F172A');
    final textBody = PdfColor.fromHex('#1E293B');
    final textMuted = PdfColor.fromHex('#64748B');

    pw.PageTheme getTheme() {
      return pw.PageTheme(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(22),
        theme: pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold),
        textDirection: pw.TextDirection.rtl,
        buildBackground: (pw.Context context) {
          return pw.Container(color: bgLight);
        },
      );
    }

    pw.Widget buildHeader(String title, int pageNum, int totalPages) {
      return pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 7),
        margin: const pw.EdgeInsets.only(bottom: 11),
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
                  style: pw.TextStyle(font: ttfBold, fontSize: 9.5, color: goldPrimary),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  title,
                  style: pw.TextStyle(font: ttfBold, fontSize: 15.5, color: textDark),
                ),
              ],
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
              decoration: pw.BoxDecoration(
                color: bgCardTint,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: goldBorder, width: 0.8),
              ),
              child: pw.Text(
                'شريحة $pageNum من $totalPages',
                style: pw.TextStyle(font: ttfBold, fontSize: 9, color: goldPrimary),
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget buildFooter() {
      return pw.Container(
        padding: const pw.EdgeInsets.only(top: 5),
        decoration: pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColor.fromHex('#E2E8F0'), width: 0.8)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('DCW-SETIF TRACKER • المنظومة الرقمية للرقابة والتفتيش الميداني',
                style: pw.TextStyle(font: ttfRegular, fontSize: 8.5, color: textMuted)),
            pw.Text('وثيقة إدارية رسمية موجهة حصراً للسيد المدير الولائي (الآمر بالصرف)',
                style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: goldPrimary)),
          ],
        ),
      );
    }

    const totalPages = 12;

    // SLIDE 1: COVER
    pdf.addPage(
      pw.Page(
        pageTheme: getTheme(),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: goldBorder, width: 1.5),
              borderRadius: pw.BorderRadius.circular(12),
              color: bgCardLight,
            ),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'الجمهورية الجزائرية الديمقراطية الشعبية\nوزارة التجارة الداخلية وضبط السوق الوطنية\nمديرية التجارة وترقية الصادرات لولاية سطيف',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: ttfBold, fontSize: 13, color: goldPrimary),
                ),
                pw.SizedBox(height: 12),
                if (imgLogin != null)
                  pw.Container(
                    height: 130,
                    child: pw.Image(imgLogin, fit: pw.BoxFit.contain),
                  ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'دليل الاستعمال الرسمي للمدير الولائي\nمنظومة الرقابة والتفتيش الميداني الذكية',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: ttfBold, fontSize: 22, color: textDark),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'الوثيقة التنفيذية المرجعية لتسيير المفتشين، الانضباط وفق الأمر 06-03، وضبط فترات التسامح وقرارات الخصم السيادية',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: ttfRegular, fontSize: 10.5, color: textMuted),
                ),
                pw.Spacer(),
                buildFooter(),
              ],
            ),
          );
        },
      ),
    );

    // SLIDE 2: MAP & VISION
    pdf.addPage(
      pw.Page(
        pageTheme: getTheme(),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              buildHeader('1. الرؤية الاستراتيجية والخريطة الحية للمدير', 2, totalPages),
              pw.Expanded(
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 1,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(10),
                            decoration: pw.BoxDecoration(
                              color: bgCardTint,
                              borderRadius: pw.BorderRadius.circular(8),
                              border: pw.Border.all(color: goldBorder, width: 0.8),
                            ),
                            child: pw.Text(
                              'ترسيخ مبدأ "الراتب مقابل أداء الخدمة الفعلية" في إطار الاحترام التام للضمانات القانونية وحق الدفاع، مع تحويل الرقابة إلى حوكمة استباقية بالبصمة الجغرافية الموثوقة.',
                              style: pw.TextStyle(font: ttfBold, fontSize: 9.5, color: textDark),
                            ),
                          ),
                          pw.SizedBox(height: 10),
                          pw.Text(
                            '• لوحة تحكم الخريطة الحية: أقمار صناعية لولاية سطيف مع مؤشرات لحظية (المتواجدين بالميدان، المعاينات، والغائبين).\n• التنقل الفوري بين المقرات الـ 8 بضغطة زر.\n• حماية خصوصية الموظفين: اعتماد بصمة GPS الذكية دون طلب صور السيلفي.',
                            style: pw.TextStyle(font: ttfRegular, fontSize: 9.5, color: textBody, lineSpacing: 2.8),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 14),
                    pw.Expanded(
                      flex: 1,
                      child: imgMapSetif != null
                          ? pw.Container(
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: goldBorder, width: 1),
                                borderRadius: pw.BorderRadius.circular(8),
                              ),
                              child: pw.Image(imgMapSetif, fit: pw.BoxFit.contain),
                            )
                          : pw.Container(),
                    ),
                  ],
                ),
              ),
              buildFooter(),
            ],
          );
        },
      ),
    );

    // SLIDE 3: CREDENTIALS TABLE FOR DIRECTOR TESTING
    pdf.addPage(
      pw.Page(
        pageTheme: getTheme(),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              buildHeader('2. جدول الحسابات الرسمية وكلمات المرور المعتمدة للتجريب', 3, totalPages),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      margin: const pw.EdgeInsets.only(bottom: 8),
                      decoration: pw.BoxDecoration(
                        color: bgCardTint,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(color: goldBorder, width: 0.8),
                      ),
                      child: pw.Text(
                        'مخصص للسيد المدير الولائي لتجريب كافة واجهات المنظومة والاطلاع على بيئة عمل كل مصلحة ورتبة:',
                        style: pw.TextStyle(font: ttfBold, fontSize: 9.5, color: goldPrimary),
                      ),
                    ),
                    pw.Table(
                      border: pw.TableBorder.all(color: goldBorder, width: 0.8),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2.2),
                        1: const pw.FlexColumnWidth(1.8),
                        2: const pw.FlexColumnWidth(1.5),
                        3: const pw.FlexColumnWidth(4.5),
                      },
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: bgCardTint),
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('المستوى / الصفة الإدارية', style: pw.TextStyle(font: ttfBold, fontSize: 9, color: goldPrimary))),
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('اسم المستخدم (Login)', style: pw.TextStyle(font: ttfBold, fontSize: 9, color: goldPrimary))),
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('كلمة المرور', style: pw.TextStyle(font: ttfBold, fontSize: 9, color: goldPrimary))),
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('الصلاحية والوظيفة في التطبيق', style: pw.TextStyle(font: ttfBold, fontSize: 9, color: goldPrimary))),
                          ],
                        ),
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FEFCE8')),
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('المدير الولائي (الآمر بالصرف)', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: textDark))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('directeur', style: pw.TextStyle(font: ttfBold, fontSize: 9, color: goldPrimary))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('directeur123', style: pw.TextStyle(font: ttfBold, fontSize: 9, color: textDark))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('لوحة القيادة، الخريطة الحية، ضبط فترة التسامح، والبت في الاستفسارات والخصم', style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: textBody))),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('رئيس مصلحة المنافسة والتحقيقات', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: textDark))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('chef_concurrence', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: goldPrimary))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('chef123', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: textDark))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('إصدار أوامر المهمة، توزيع وتشكيل الفرق الرقابية، واعتماد المعاينات', style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: textBody))),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('رئيس مصلحة حماية المستهلك', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: textDark))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('chef_consommation', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: goldPrimary))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('chef123', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: textDark))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('توجيه فرق قمع الغش، أوامر المهمة اليومية، وتأشير المحاضر والمحجوزات', style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: textBody))),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('رئيس مصلحة الإدارة والوسائل', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: textDark))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('chef_administration', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: goldPrimary))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('chef123', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: textDark))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('متابعة أسطول السيارات (12 مركبة)، المقرات الـ 8، والمستخدمين والرواتب', style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: textBody))),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('رئيس مكتب المستخدمين', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: textDark))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('bureau_user', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: goldPrimary))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('bureau123', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: textDark))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('متابعة التأخرات، توجيه الاستفسارات، وتنفيذ قرارات خصم المدير على الراتب فوراً', style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: textBody))),
                          ],
                        ),
                        pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('المفتشون الميدانيون (267 مفتش)', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: textDark))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('emp.1 إلى emp.267', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: goldPrimary))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('chef123', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: textDark))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('تسجيل الحضور والانصراف بـ GPS، توثيق المعاينات، والرد على الاستفسارات', style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: textBody))),
                          ],
                        ),
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F1F5F9')),
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('مدير النظام التقني', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: textMuted))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('حساب محمي وخاص', style: pw.TextStyle(font: ttfBold, fontSize: 8, color: textMuted))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('••••••••', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: textMuted))),
                            pw.Padding(padding: const pw.EdgeInsets.all(4.5), child: pw.Text('الدعم الفني، صيانة وتأمين قواعد البيانات السحابية، ومراقبة البنية التحتية', style: pw.TextStyle(font: ttfRegular, fontSize: 8, color: textMuted))),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              buildFooter(),
            ],
          );
        },
      ),
    );

    // SLIDE 4: GRACE PERIOD & DEDUCTIONS
    pdf.addPage(
      pw.Page(
        pageTheme: getTheme(),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              buildHeader('3. فترة التسامح الصباحية القابلة للضبط (Tolérance) وقرارات الخصم', 4, totalPages),
              pw.Expanded(
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 1,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'خيارات ضبط فترة التسامح الصباحية المتاحة حصراً للمدير:',
                            style: pw.TextStyle(font: ttfBold, fontSize: 10.5, color: goldPrimary),
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text(
                            '• 08:15 ص: انضباط شديد لفرق المناوبة الخاصة.\n• 08:30 ص: توقيت مرن معتدل.\n• 08:45 ص (الموصى بها): توازن مثالي بين الانضباط وتحديات النقل.\n• 09:00 ص: مرونة قصوى في التقلبات الجوية والظروف الطارئة.\n• 09:15 ص: تسهيل استثنائي.\n\nالمعادلة القانونية (الأمر 06-03):\n- تراكم 4 ساعات شهرياً = خصم نصف يوم (0.5 يوم).\n- تراكم 8 ساعات شهرياً = خصم يوم كامل (1.0 يوم).',
                            style: pw.TextStyle(font: ttfRegular, fontSize: 9, color: textBody, lineSpacing: 2),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 14),
                    pw.Expanded(
                      flex: 1,
                      child: imgDeductions != null
                          ? pw.Container(
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: goldBorder, width: 1),
                                borderRadius: pw.BorderRadius.circular(8),
                              ),
                              child: pw.Image(imgDeductions, fit: pw.BoxFit.contain),
                            )
                          : pw.Container(),
                    ),
                  ],
                ),
              ),
              buildFooter(),
            ],
          );
        },
      ),
    );

    // SLIDE 5: REPORTS & PDF
    pdf.addPage(
      pw.Page(
        pageTheme: getTheme(),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              buildHeader('4. تبويب التقارير اليومية وتوليد محاضر الحضور الرسمية (PDF)', 5, totalPages),
              pw.Expanded(
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 1,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '• البث المباشر لحضور وغياب 267 موظفاً موزعين عبر الولاية.\n• البحث بالاسم، اللقب، الرتبة، أو رقم التسجيل.\n• إمكانية تصفح التواريخ السابقة ومراجعة أرشيف الانضباط.\n• توليد وتصدير محاضر الحضور اليومية والشهرية بصيغة PDF بضغطة زر واحدة موثقة بالختم الرسمي.',
                            style: pw.TextStyle(font: ttfRegular, fontSize: 10, color: textBody, lineSpacing: 3),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 14),
                    pw.Expanded(
                      flex: 1,
                      child: imgReports != null
                          ? pw.Container(
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: goldBorder, width: 1),
                                borderRadius: pw.BorderRadius.circular(8),
                              ),
                              child: pw.Image(imgReports, fit: pw.BoxFit.contain),
                            )
                          : pw.Container(),
                    ),
                  ],
                ),
              ),
              buildFooter(),
            ],
          );
        },
      ),
    );

    // SLIDE 6: INSPECTION HEAD
    pdf.addPage(
      pw.Page(
        pageTheme: getTheme(),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              buildHeader('5. لوحة رئيس مصلحة المنافسة / قمع الغش وتسيير الفرق الرقابية', 6, totalPages),
              pw.Expanded(
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: imgHeadInspectors != null
                          ? pw.Column(
                              children: [
                                pw.Text('تشكيل الفرق وتعيين رؤساء الفرق', style: pw.TextStyle(font: ttfBold, fontSize: 9, color: goldPrimary)),
                                pw.SizedBox(height: 3),
                                pw.Expanded(
                                  child: pw.Container(
                                    decoration: pw.BoxDecoration(border: pw.Border.all(color: goldBorder, width: 0.8), borderRadius: pw.BorderRadius.circular(6)),
                                    child: pw.Image(imgHeadInspectors, fit: pw.BoxFit.contain),
                                  ),
                                ),
                              ],
                            )
                          : pw.Container(),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: imgHeadMissions != null
                          ? pw.Column(
                              children: [
                                pw.Text('سجل أوامر المهمة والبرامج الميدانية', style: pw.TextStyle(font: ttfBold, fontSize: 9, color: goldPrimary)),
                                pw.SizedBox(height: 3),
                                pw.Expanded(
                                  child: pw.Container(
                                    decoration: pw.BoxDecoration(border: pw.Border.all(color: goldBorder, width: 0.8), borderRadius: pw.BorderRadius.circular(6)),
                                    child: pw.Image(imgHeadMissions, fit: pw.BoxFit.contain),
                                  ),
                                ),
                              ],
                            )
                          : pw.Container(),
                    ),
                  ],
                ),
              ),
              buildFooter(),
            ],
          );
        },
      ),
    );

    // SLIDE 7: MISSION ORDERS
    pdf.addPage(
      pw.Page(
        pageTheme: getTheme(),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              buildHeader('6. محرك إصدار وتوجيه أوامر المهمة (تكليف فرقة / تعميم شامل)', 7, totalPages),
              pw.Expanded(
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: imgHeadBrigade != null
                          ? pw.Column(
                              children: [
                                pw.Text('تكليف فرقة كاملة بالبلديات والمحاور البؤرية', style: pw.TextStyle(font: ttfBold, fontSize: 9, color: goldPrimary)),
                                pw.SizedBox(height: 3),
                                pw.Expanded(
                                  child: pw.Container(
                                    decoration: pw.BoxDecoration(border: pw.Border.all(color: goldBorder, width: 0.8), borderRadius: pw.BorderRadius.circular(6)),
                                    child: pw.Image(imgHeadBrigade, fit: pw.BoxFit.contain),
                                  ),
                                ),
                              ],
                            )
                          : pw.Container(),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: imgHeadBroadcast != null
                          ? pw.Column(
                              children: [
                                pw.Text('تعميم شامل لكافة الفرق دفعة واحدة بضغطة زر', style: pw.TextStyle(font: ttfBold, fontSize: 9, color: goldPrimary)),
                                pw.SizedBox(height: 3),
                                pw.Expanded(
                                  child: pw.Container(
                                    decoration: pw.BoxDecoration(border: pw.Border.all(color: goldBorder, width: 0.8), borderRadius: pw.BorderRadius.circular(6)),
                                    child: pw.Image(imgHeadBroadcast, fit: pw.BoxFit.contain),
                                  ),
                                ),
                              ],
                            )
                          : pw.Container(),
                    ),
                  ],
                ),
              ),
              buildFooter(),
            ],
          );
        },
      ),
    );

    // SLIDE 8: BUREAU
    pdf.addPage(
      pw.Page(
        pageTheme: getTheme(),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              buildHeader('7. لوحة رئيس مكتب المستخدمين (تسيير المسار المهني والانضباط)', 8, totalPages),
              pw.Expanded(
                child: pw.Row(
                  children: [
                    if (imgBureauEmps != null)
                      pw.Expanded(
                        child: pw.Column(
                          children: [
                            pw.Text('الموظفون الـ 267 والـ KPIs', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: goldPrimary)),
                            pw.SizedBox(height: 3),
                            pw.Expanded(
                              child: pw.Container(
                                decoration: pw.BoxDecoration(border: pw.Border.all(color: goldBorder, width: 0.8), borderRadius: pw.BorderRadius.circular(6)),
                                child: pw.Image(imgBureauEmps, fit: pw.BoxFit.contain),
                              ),
                            ),
                          ],
                        ),
                      ),
                    pw.SizedBox(width: 6),
                    if (imgBureauGrace != null)
                      pw.Expanded(
                        child: pw.Column(
                          children: [
                            pw.Text('سجل الانضباط والتسامح', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: goldPrimary)),
                            pw.SizedBox(height: 3),
                            pw.Expanded(
                              child: pw.Container(
                                decoration: pw.BoxDecoration(border: pw.Border.all(color: goldBorder, width: 0.8), borderRadius: pw.BorderRadius.circular(6)),
                                child: pw.Image(imgBureauGrace, fit: pw.BoxFit.contain),
                              ),
                            ),
                          ],
                        ),
                      ),
                    pw.SizedBox(width: 6),
                    if (imgBureauModal != null)
                      pw.Expanded(
                        child: pw.Column(
                          children: [
                            pw.Text('تعديل الوضعية الإدارية', style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: goldPrimary)),
                            pw.SizedBox(height: 3),
                            pw.Expanded(
                              child: pw.Container(
                                decoration: pw.BoxDecoration(border: pw.Border.all(color: goldBorder, width: 0.8), borderRadius: pw.BorderRadius.circular(6)),
                                child: pw.Image(imgBureauModal, fit: pw.BoxFit.contain),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              buildFooter(),
            ],
          );
        },
      ),
    );

    // SLIDE 9: QR DIGITAL BADGES
    pdf.addPage(
      pw.Page(
        pageTheme: getTheme(),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              buildHeader('8. منظومة التوثيق والتشفير الرقمي بالـ QR Code المعتمد', 9, totalPages),
              pw.Expanded(
                child: pw.Row(
                  children: [
                    if (imgQrHq != null)
                      pw.Expanded(
                        child: pw.Column(
                          children: [
                            pw.Text('شهادة الاعتماد الرقمي للمقر (المعبودة)', style: pw.TextStyle(font: ttfBold, fontSize: 9, color: goldPrimary)),
                            pw.SizedBox(height: 3),
                            pw.Expanded(
                              child: pw.Container(
                                decoration: pw.BoxDecoration(border: pw.Border.all(color: goldBorder, width: 0.8), borderRadius: pw.BorderRadius.circular(6)),
                                child: pw.Image(imgQrHq, fit: pw.BoxFit.contain),
                              ),
                            ),
                          ],
                        ),
                      ),
                    pw.SizedBox(width: 14),
                    if (imgQrBadge != null)
                      pw.Expanded(
                        child: pw.Column(
                          children: [
                            pw.Text('البطاقة الرقمية الرسمية للمفتش مع التوقيت والرمز المشفر', style: pw.TextStyle(font: ttfBold, fontSize: 9, color: goldPrimary)),
                            pw.SizedBox(height: 3),
                            pw.Expanded(
                              child: pw.Container(
                                decoration: pw.BoxDecoration(border: pw.Border.all(color: goldBorder, width: 0.8), borderRadius: pw.BorderRadius.circular(6)),
                                child: pw.Image(imgQrBadge, fit: pw.BoxFit.contain),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              buildFooter(),
            ],
          );
        },
      ),
    );

    // SLIDE 10: 8 REGIONAL HQS & GEOFENCING
    pdf.addPage(
      pw.Page(
        pageTheme: getTheme(),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              buildHeader('9. شبكة المقرات الـ 8 والبصمة الجغرافية (العلمة نموذجاً)', 10, totalPages),
              pw.Expanded(
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 1,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'التغطية الجغرافية الشاملة لولاية سطيف:\n• المقر الرئيسي للمديرية (حي المعبودة) - سطيف وسط.\n• مفتشية مطار 8 ماي 1945 (عين أرنات) - مراقبة الجودة والحدود.\n• المفتشية الإقليمية بالعلمة - قطب تجاري وصناعي.\n• المفتشية الإقليمية بعين ولمان - الجهة الجنوبية.\n• المفتشية الإقليمية ببوقاعة - الجهة الشمالية الغربية.\n• الملحقات (عين آزال، عين الكبيرة، عين أرنات).\n\nالنظام يحيط كل مقر بدائرة جغرافية ذكية (Geofence) للتحقق التلقائي من الحضور الميداني.',
                            style: pw.TextStyle(font: ttfRegular, fontSize: 9, color: textBody, lineSpacing: 2.5),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 14),
                    pw.Expanded(
                      flex: 1,
                      child: imgMapEulma != null
                          ? pw.Container(
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: goldBorder, width: 1),
                                borderRadius: pw.BorderRadius.circular(8),
                              ),
                              child: pw.Image(imgMapEulma, fit: pw.BoxFit.contain),
                            )
                          : pw.Container(),
                    ),
                  ],
                ),
              ),
              buildFooter(),
            ],
          );
        },
      ),
    );

    // SLIDE 11: ADMIN SERVICE
    pdf.addPage(
      pw.Page(
        pageTheme: getTheme(),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              buildHeader('10. لوحة مصلحة الإدارة والوسائل (المستخدمين، السيارات، والرواتب)', 11, totalPages),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: bgCardTint,
                        borderRadius: pw.BorderRadius.circular(8),
                        border: pw.Border.all(color: goldBorder, width: 0.8),
                      ),
                      child: pw.Text(
                        'تم فصل واجهة رئيس مصلحة الإدارة والوسائل بالكامل عن مصالح الرقابة التجارية لتناسب طبيعة مهامه الإشرافية واللوجستية والمالية:',
                        style: pw.TextStyle(font: ttfBold, fontSize: 10, color: goldPrimary),
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      '1. تبويب المستخدمين والانضباط العام: متابعة 267 موظف، الحضور اليومي، وتراكم ساعات التأخر.\n2. تبويب الوسائل العامة والمقرات الـ 8: تتبع أسطول سيارات المصلحة (12 مركبة)، بطاقات الوقود، أجهزة الكشف السريع وحقائب التفتيش.\n3. تبويب المحاسبة والرواتب: متابعة تنفيذ قرارات خصم المدير الصادرة على الرواتب وإعداد جداول الخصم الرسمية.',
                      style: pw.TextStyle(font: ttfRegular, fontSize: 9.5, color: textBody, lineSpacing: 2.8),
                    ),
                  ],
                ),
              ),
              buildFooter(),
            ],
          );
        },
      ),
    );

    // SLIDE 12: CLOSING & SIGNATURE
    pdf.addPage(
      pw.Page(
        pageTheme: getTheme(),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: goldBorder, width: 1.5),
              borderRadius: pw.BorderRadius.circular(12),
              color: bgCardLight,
            ),
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'الجمهورية الجزائرية الديمقراطية الشعبية\nمديرية التجارة وترقية الصادرات لولاية سطيف',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: ttfBold, fontSize: 13, color: goldPrimary),
                ),
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: bgCardTint,
                    borderRadius: pw.BorderRadius.circular(10),
                    border: pw.Border.all(color: goldBorder, width: 1),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'خاتمة التأكيد والجاهزية للإنتاج والعرض الوزاري',
                        style: pw.TextStyle(font: ttfBold, fontSize: 15.5, color: textDark),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'تم تطوير هذه المنظومة الرقمية بأعلى معايير الأمن السيبراني والمطابقة القانونية مع قانون الوظيفة العمومية الجزائري (الأمر رقم 06-03)، وتعتبر أداة قيادة سيادية تحت الإشراف المباشر للسيد المدير الولائي لضبط النشاط الرقابي والتفتيشي عبر كامل إقليم ولاية سطيف.',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(font: ttfRegular, fontSize: 10, color: textBody, lineSpacing: 2.3),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('المصادقة الإدارية والسيادية', style: pw.TextStyle(font: ttfBold, fontSize: 10, color: goldPrimary)),
                        pw.SizedBox(height: 3),
                        pw.Text('السيد المدير الولائي للتجارة — ولاية سطيف', style: pw.TextStyle(font: ttfBold, fontSize: 10.5, color: textDark)),
                        pw.Text('الآمر بالصرف ورئيس العمليات الرقابية', style: pw.TextStyle(font: ttfRegular, fontSize: 8.5, color: textMuted)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text('الدعم الفني وإدارة النظام', style: pw.TextStyle(font: ttfBold, fontSize: 10, color: goldPrimary)),
                        pw.SizedBox(height: 3),
                        pw.Text('فريق الهندسة والتطوير والرقمنة', style: pw.TextStyle(font: ttfBold, fontSize: 10.5, color: textDark)),
                        pw.Text('DCW-SETIF Systems & Digital Infrastructure', style: pw.TextStyle(font: ttfRegular, fontSize: 8.5, color: textMuted)),
                      ],
                    ),
                  ],
                ),
                pw.Spacer(),
                buildFooter(),
              ],
            ),
          );
        },
      ),
    );

    final outputFile = File('../DCW_SETIF_DIRECTOR_MANUAL_PRINT.pdf');
    await outputFile.writeAsBytes(await pdf.save());
    // ignore: avoid_print
    print('✅ Light PDF Generated Successfully with Credentials Table at: ${outputFile.absolute.path}');
  });
}
