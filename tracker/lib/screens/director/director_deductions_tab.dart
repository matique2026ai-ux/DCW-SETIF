import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:drh_setif_tracker/services/auth_service.dart';
import 'package:drh_setif_tracker/services/pdf_report_service.dart';
import 'package:drh_setif_tracker/utils/theme.dart';
import 'package:drh_setif_tracker/utils/app_localizations.dart';
import 'package:drh_setif_tracker/screens/common/inquiry_letter_dialog.dart';

class DirectorDeductionsTab extends StatefulWidget {
  const DirectorDeductionsTab({super.key});

  @override
  State<DirectorDeductionsTab> createState() => _DirectorDeductionsTabState();
}

class _DirectorDeductionsTabState extends State<DirectorDeductionsTab> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _inquiries = [];
  List<Map<String, dynamic>> _delaysSummary = [];
  String _morningGraceTime = '08:45';
  bool _isLoading = true;
  String _archiveTimeFilter = 'all'; // 'today', 'week', 'month', 'all'
  String _archiveDecisionFilter = 'all'; // 'all', 'justified', 'warning', 'deduction'
  String _archiveSearchQuery = '';
  bool _isPrintingReport = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<AuthService>().api;
      final emp = await api.getEmployees();
      final cleanEmp = emp.where((e) {
        final nom = (e['NomAr'] ?? e['nomAr'] ?? '').toString();
        final service = (e['Service'] ?? e['service'] ?? '').toString();
        return !nom.contains('المدير الولائي') && !service.contains('المديرية الولائية');
      }).toList();
      final inqs = await api.getInquiries();
      final settings = await api.getSettings();
      final grace = (settings['morning_grace_time'] ?? '08:45').toString();
      final delays = await api.getDelaysSummary(graceTime: grace);

      if (mounted) {
        setState(() {
          _employees = cleanEmp;
          _inquiries = inqs;
          _morningGraceTime = grace;
          _delaysSummary = delays;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateGraceTime(String newTime) async {
    final loc = AppLocalizations.of(context);
    try {
      final api = context.read<AuthService>().api;
      await api.updateSetting('morning_grace_time', newTime);
      setState(() => _morningGraceTime = newTime);
      final delays = await api.getDelaysSummary(graceTime: newTime);
      if (mounted) {
        setState(() => _delaysSummary = delays);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc.isArabic
                  ? '✅ تم تعديل فترة التسامح الصباحية إلى $newTime وتحديث حساب التأخرات'
                  : '✅ Tolérance matinale modifiée à $newTime et retards recalculés',
            ),
            backgroundColor: AppTheme.SuccessColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.DangerColor),
        );
      }
    }
  }

  void _showDirectorOrderModal(Map<String, dynamic> employee) {
    final loc = AppLocalizations.of(context);
    final name = '${employee['NomAr'] ?? employee['Nom'] ?? ''} ${employee['PrenomAr'] ?? employee['Prenom'] ?? ''}';
    final empId = employee['Id'] ?? employee['id'];
    final subjectCtrl = TextEditingController(
      text: loc.isArabic
          ? 'استفسار وأمر بالانضباط حول الحضور والمردودية'
          : 'Demande d\'explications et ordre de discipline',
    );
    final detailsCtrl = TextEditingController(
      text: loc.isArabic
          ? 'بناءً على المعطيات الرقابية، يُطلب من مكتب المستخدمين توجيه استفسار كتابي رسمي للموظف المذكور مع منحه 48 ساعة للرد.'
          : 'Sur la base des données de contrôle, le bureau du personnel est chargé d\'adresser une demande d\'explications officielle à l\'agent concerné (délai de réponse: 48h).',
    );

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
            const Icon(Icons.send_and_archive, color: Color(0xFFD4AF37)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loc.isArabic ? 'أمر بتوجيه استفسار — $name' : 'Ordre d\'explications — $name',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
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
              loc.isArabic
                  ? 'المدير الولائي يكلف مكتب المستخدمين بإصدار استفسار كتابي رسمي للموظف عبر التطبيق:'
                  : 'Le Directeur de Wilaya charge le bureau du personnel d\'émettre une demande d\'explications officielle via l\'application :',
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subjectCtrl,
              textDirection: loc.isArabic ? TextDirection.rtl : TextDirection.ltr,
              decoration: InputDecoration(
                labelText: loc.isArabic ? 'الموضوع' : 'Objet',
                labelStyle: const TextStyle(fontFamily: 'Tajawal', color: Color(0xFFD4AF37)),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: detailsCtrl,
              maxLines: 3,
              textDirection: loc.isArabic ? TextDirection.rtl : TextDirection.ltr,
              decoration: InputDecoration(
                labelText: loc.isArabic ? 'تعليمات وتفاصيل الاستفسار' : 'Instructions et détails',
                labelStyle: const TextStyle(fontFamily: 'Tajawal', color: Colors.white70),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(loc.isArabic ? 'إلغاء' : 'Annuler', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (subjectCtrl.text.trim().isEmpty) return;
              try {
                final auth = context.read<AuthService>();
                final userId = auth.currentUser?.id ?? 1;
                await auth.api.createInquiry({
                  'employeeId': empId,
                  'type': 'unjustified_absence',
                  'subject': subjectCtrl.text.trim(),
                  'details': detailsCtrl.text.trim(),
                  'sentBy': userId,
                });
                if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      loc.isArabic
                          ? '✅ تم تكليف مكتب المستخدمين بإصدار الاستفسار لـ $name'
                          : '✅ Demande d\'explications transmise au bureau du personnel pour $name',
                    ),
                    backgroundColor: AppTheme.SuccessColor,
                  ),
                );
                _load();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.DangerColor),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(loc.isArabic ? 'إصدار الأمر' : 'Émettre l\'ordre', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _printDisciplineReport(List<Map<String, dynamic>> inquiriesToPrint) async {
    final loc = AppLocalizations.of(context);
    setState(() => _isPrintingReport = true);
    try {
      String periodTitle = loc.isArabic ? 'كامل السجل والأرشيف الإداري' : 'Tout l\'historique';
      if (_archiveTimeFilter == 'today') {
        periodTitle = loc.isArabic ? 'اليوم (${DateFormat('yyyy/MM/dd').format(DateTime.now())})' : 'Aujourd\'hui';
      } else if (_archiveTimeFilter == 'week') {
        periodTitle = loc.isArabic ? 'هذا الأسبوع' : 'Cette semaine';
      } else if (_archiveTimeFilter == 'month') {
        periodTitle = loc.isArabic ? 'شهر ${DateFormat('MM/yyyy').format(DateTime.now())}' : 'Ce mois-ci';
      }

      final auth = context.read<AuthService>();
      final directorName = auth.currentUser?.fullName ?? (loc.isArabic ? 'المدير الولائي للتجارة' : 'Directeur du Commerce');

      await PdfReportService.generateAndPrintDisciplineReport(
        inquiries: inquiriesToPrint,
        periodTitle: periodTitle,
        directorName: directorName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الطباعة: $e'), backgroundColor: AppTheme.DangerColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrintingReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
    }
    final loc = AppLocalizations.of(context);

    final answeredInquiries = _inquiries.where((i) => i['Status'] == 'answered').toList();
    final rawDecided = _inquiries.where((i) => ['justified', 'warning', 'deduction_ordered', 'executed'].contains(i['Status'])).toList();
    final sentInquiries = _inquiries.where((i) => i['Status'] == 'sent').toList();

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final currentMonthStr = DateFormat('yyyy-MM').format(now);

    final decidedInquiries = rawDecided.where((inq) {
      // 1. Time filter
      final rawDate = (inq['DecisionDate'] ?? inq['DecisionAt'] ?? inq['CreatedAt'] ?? '').toString();
      if (_archiveTimeFilter == 'today') {
        if (!rawDate.startsWith(todayStr)) return false;
      } else if (_archiveTimeFilter == 'week') {
        final parsed = DateTime.tryParse(rawDate);
        if (parsed != null && now.difference(parsed).inDays > 7) return false;
      } else if (_archiveTimeFilter == 'month') {
        if (!rawDate.startsWith(currentMonthStr)) return false;
      }

      // 2. Decision filter
      final status = (inq['Status'] ?? inq['DirectorDecision'] ?? '').toString();
      if (_archiveDecisionFilter == 'justified' && status != 'justified') return false;
      if (_archiveDecisionFilter == 'warning' && status != 'warning') return false;
      if (_archiveDecisionFilter == 'deduction' && !['deduction_ordered', 'executed', 'deduction'].contains(status)) return false;

      // 3. Search query
      if (_archiveSearchQuery.trim().isNotEmpty) {
        final q = _archiveSearchQuery.trim().toLowerCase();
        final name = '${inq['NomAr'] ?? inq['Nom'] ?? ''} ${inq['PrenomAr'] ?? inq['Prenom'] ?? ''}'.toLowerCase();
        final service = (inq['Service'] ?? inq['service'] ?? '').toString().toLowerCase();
        final subject = (inq['Subject'] ?? inq['subject'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !service.contains(q) && !subject.contains(q)) return false;
      }

      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFFD4AF37),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
          // 1. Morning Grace Time Setting Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E1C0A), AppTheme.CardColor],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tune, color: Color(0xFFD4AF37), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loc.isArabic ? 'فترة التسامح الصباحية (Tolérance)' : 'Tolérance Matinale (Tolérance)',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFFD4AF37),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD4AF37)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _morningGraceTime,
                          dropdownColor: const Color(0xFF1E1026),
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFD4AF37)),
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD4AF37),
                            fontSize: 13,
                          ),
                          items: [
                            DropdownMenuItem(value: '08:15', child: Text(loc.isArabic ? '08:15 ص' : '08:15')),
                            DropdownMenuItem(value: '08:30', child: Text(loc.isArabic ? '08:30 ص' : '08:30')),
                            DropdownMenuItem(value: '08:45', child: Text(loc.isArabic ? '08:45 ص (الموصى بها)' : '08:45 (Recommandée)')),
                            DropdownMenuItem(value: '09:00', child: Text(loc.isArabic ? '09:00 ص (مرونة قصوى)' : '09:00 (Flexibilité Max)')),
                            DropdownMenuItem(value: '09:15', child: Text(loc.isArabic ? '09:15 ص' : '09:15')),
                          ],
                          onChanged: (val) {
                            if (val != null && val != _morningGraceTime) {
                              _updateGraceTime(val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  loc.isArabic
                      ? 'التوقيت الحالي: $_morningGraceTime ص — التأخرات الصباحية تُحسب بعده مباشرة.'
                      : 'Heure actuelle : $_morningGraceTime — Les retards sont comptabilisés au-delà.',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Overview of accumulated delays
          if (_delaysSummary.any((d) => ((d['lateDaysCount'] as num?)?.toInt() ?? 0) > 0)) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.WarningColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.WarningColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.analytics_outlined, color: AppTheme.WarningColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loc.isArabic
                          ? 'سجل النظام ${_delaysSummary.where((d) => ((d['lateDaysCount'] as num?)?.toInt() ?? 0) > 0).length} موظفين تجاوزوا موعد التسامح ($_morningGraceTime) هذا الشهر.'
                          : 'Le système enregistre ${_delaysSummary.where((d) => ((d['lateDaysCount'] as num?)?.toInt() ?? 0) > 0).length} agent(s) ayant dépassé la tolérance ($_morningGraceTime) ce mois-ci.',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 2. Button: Issue Inquiry Order
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showEmployeePicker(),
              icon: const Icon(Icons.person_search, color: Colors.black),
              label: Text(
                loc.isArabic ? 'طلب توجيه استفسار كتابي لموظف محدد' : "Ordonner une demande d'explications",
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                padding: const EdgeInsets.all(14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // 3. Urgent: Answered Inquiries Awaiting Director Sovereign Decision
          Row(
            children: [
              const Icon(Icons.rate_review, color: Colors.cyanAccent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.isArabic
                      ? 'ملفات الاستفسارات التي تم الرد عليها وبانتظار قراركم السيادي (${answeredInquiries.length})'
                      : "Demandes d'explications répondues en attente de décision (${answeredInquiries.length})",
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (answeredInquiries.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Center(
                child: Text(
                  loc.isArabic
                      ? 'لا توجد ردود جديدة معلقة — كافة الملفات تمت معالجتها واتخاذ القرارات بشأنها ✨'
                      : 'Aucun dossier en attente — Toutes les réponses ont été traitées ✨',
                  style: const TextStyle(fontFamily: 'Tajawal', color: AppTheme.TextSecondary, fontSize: 12),
                ),
              ),
            )
          else
            ...answeredInquiries.map((inq) => _buildInquiryCard(inq, isActionable: true)),

          const SizedBox(height: 20),

          // 4. Sent Inquiries (Pending Employee Reply)
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppTheme.WarningColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.isArabic
                      ? 'استفسارات موجهة بانتظار رد الموظف خلال 48 ساعة (${sentInquiries.length})'
                      : 'Demandes envoyées en attente de réponse sous 48h (${sentInquiries.length})',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          if (sentInquiries.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Center(
                child: Text(
                  loc.isArabic
                      ? 'لا توجد استفسارات قيد الانتظار حالياً ⏳'
                      : 'Aucune demande en attente de réponse ⏳',
                  style: const TextStyle(fontFamily: 'Tajawal', color: AppTheme.TextSecondary, fontSize: 12),
                ),
              ),
            )
          else ...[
            ...sentInquiries.map((inq) => _buildInquiryCard(inq, isActionable: false)),
            const SizedBox(height: 20),
          ],

          // 5. Decided / Past Inquiries History
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header & PDF Print Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history_edu, color: Color(0xFFD4AF37), size: 22),
                        const SizedBox(width: 8),
                        Text(
                          loc.isArabic
                              ? 'أرشيف قرارات الانضباط والسوابق (${decidedInquiries.length})'
                              : 'Historique des décisions disciplinaires (${decidedInquiries.length})',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _isPrintingReport || decidedInquiries.isEmpty
                          ? null
                          : () => _printDisciplineReport(decidedInquiries),
                      icon: _isPrintingReport
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Icon(Icons.print, size: 16, color: Colors.black),
                      label: Text(
                        loc.isArabic ? 'طباعة تقرير القرارات (PDF)' : 'Imprimer Rapport (PDF)',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Bar
                TextField(
                  onChanged: (val) => setState(() => _archiveSearchQuery = val),
                  style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: loc.isArabic ? 'بحث بالاسم، الرتبة أو المصلحة...' : 'Recherche par nom, grade ou service...',
                    hintStyle: const TextStyle(fontFamily: 'Tajawal', color: Colors.white38, fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37), size: 20),
                    suffixIcon: _archiveSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white70, size: 18),
                            onPressed: () => setState(() => _archiveSearchQuery = ''),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.black26,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Filters Row 1: Time Period
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(
                        loc.isArabic ? 'الفترة:' : 'Période :',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: loc.isArabic ? 'الكل 🗂️' : 'Tout 🗂️',
                        isSelected: _archiveTimeFilter == 'all',
                        onSelected: () => setState(() => _archiveTimeFilter = 'all'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: loc.isArabic ? 'اليوم 📅' : 'Aujourd\'hui 📅',
                        isSelected: _archiveTimeFilter == 'today',
                        onSelected: () => setState(() => _archiveTimeFilter = 'today'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: loc.isArabic ? 'هذا الأسبوع 🗓️' : 'Cette semaine 🗓️',
                        isSelected: _archiveTimeFilter == 'week',
                        onSelected: () => setState(() => _archiveTimeFilter = 'week'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: loc.isArabic ? 'هذا الشهر 📊' : 'Ce mois 📊',
                        isSelected: _archiveTimeFilter == 'month',
                        onSelected: () => setState(() => _archiveTimeFilter = 'month'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Filters Row 2: Decision Type
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(
                        loc.isArabic ? 'القرار:' : 'Décision :',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: loc.isArabic ? 'الكل' : 'Toutes',
                        isSelected: _archiveDecisionFilter == 'all',
                        onSelected: () => setState(() => _archiveDecisionFilter = 'all'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: loc.isArabic ? '✅ تبرير مقبول' : '✅ Justifié',
                        isSelected: _archiveDecisionFilter == 'justified',
                        activeColor: AppTheme.SuccessColor,
                        onSelected: () => setState(() => _archiveDecisionFilter = 'justified'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: loc.isArabic ? '⚠️ إنذار رسمي' : '⚠️ Avertissement',
                        isSelected: _archiveDecisionFilter == 'warning',
                        activeColor: AppTheme.WarningColor,
                        onSelected: () => setState(() => _archiveDecisionFilter = 'warning'),
                      ),
                      const SizedBox(width: 6),
                      _buildFilterChip(
                        label: loc.isArabic ? '⚖️ خصم نافذ' : '⚖️ Déduction',
                        isSelected: _archiveDecisionFilter == 'deduction',
                        activeColor: AppTheme.DangerColor,
                        onSelected: () => setState(() => _archiveDecisionFilter = 'deduction'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          
          if (decidedInquiries.isEmpty)
            Container(
              padding: const EdgeInsets.all(22),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Center(
                child: Text(
                  loc.isArabic
                      ? 'لا توجد قرارات تطابق خيارات الفلترة المحددة 📜'
                      : 'Aucun dossier ne correspond aux filtres sélectionnés 📜',
                  style: const TextStyle(fontFamily: 'Tajawal', color: AppTheme.TextSecondary, fontSize: 12),
                ),
              ),
            )
          else ...[
            ...decidedInquiries.map((inq) => _buildInquiryCard(inq, isActionable: false)),
          ],
        ],
      ),
    ),
  ),
);
}

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    Color? activeColor,
  }) {
    final effectiveColor = activeColor ?? const Color(0xFFD4AF37);
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? effectiveColor.withValues(alpha: 0.25) : Colors.black26,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? effectiveColor : Colors.white12,
            width: isSelected ? 1.3 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? (activeColor ?? const Color(0xFFD4AF37)) : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildInquiryCard(Map<String, dynamic> inq, {required bool isActionable}) {
    final loc = AppLocalizations.of(context);
    final nomAr = inq['NomAr'] ?? inq['nomar'] ?? inq['Nom'] ?? inq['nom'] ?? inq['name'] ?? inq['employeeName'] ?? '';
    final prenomAr = inq['PrenomAr'] ?? inq['prenomar'] ?? inq['Prenom'] ?? inq['prenom'] ?? '';
    final name = (nomAr.toString().trim().isNotEmpty || prenomAr.toString().trim().isNotEmpty)
        ? '$nomAr $prenomAr'.trim()
        : (inq['EmployeeName'] ?? inq['employee_name'] ?? (loc.isArabic ? 'عضو فرقة الرقابة والتفتيش' : 'Agent de contrôle')).toString();
    final status = (inq['Status'] ?? inq['status'] ?? 'sent').toString();
    final service = (inq['Service'] ?? inq['service'] ?? (loc.isArabic ? 'مديرية التجارة لولاية سطيف' : 'Direction du Commerce de Sétif')).toString();
    final subject = (inq['Subject'] ?? inq['subject'] ?? inq['Details'] ?? inq['details'] ?? (loc.isArabic ? 'استفسار إداري حول الانضباط ومواقيت العمل' : 'Demande d\'explications sur la ponctualité')).toString();

    Color statusColor = AppTheme.WarningColor;
    String statusText = loc.isArabic ? 'بانتظار رد الموظف' : 'En attente de réponse';
    if (status == 'answered') {
      statusColor = Colors.cyan;
      statusText = loc.isArabic ? 'ورد الرد — بانتظار الفصل والقرار' : 'Réponse reçue — En attente d\'arbitrage';
    } else if (status == 'justified') {
      statusColor = AppTheme.SuccessColor;
      statusText = loc.isArabic ? 'تم قبول التبرير وحفظ الملف' : 'Justification acceptée — Dossier classé';
    } else if (status == 'warning') {
      statusColor = Colors.orange;
      statusText = loc.isArabic ? 'تم توجيه تنبيه إداري' : 'Avertissement administratif notifié';
    } else if (status == 'deduction_ordered') {
      statusColor = AppTheme.DangerColor;
      final days = inq['DeductionDays'] ?? inq['deductiondays'] ?? 1;
      statusText = loc.isArabic ? 'قرار خصم ($days يوم) محال للتنفيذ' : 'Décision de retenue ($days j) transmise';
    } else if (status == 'executed') {
      statusColor = Colors.green;
      statusText = loc.isArabic ? 'تم تنفيذ الخصم في الراتب' : 'Retenue exécutée sur salaire';
    }

    return GestureDetector(
      onTap: () => _showInquiryDossier(inq),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.CardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActionable
                ? Colors.cyan.withValues(alpha: 0.6)
                : AppTheme.BorderColor.withValues(alpha: 0.3),
            width: isActionable ? 1.5 : 1,
          ),
          boxShadow: [
            if (isActionable)
              BoxShadow(
                color: Colors.cyan.withValues(alpha: 0.1),
                blurRadius: 10,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActionable ? Icons.rate_review : Icons.folder_shared,
                color: statusColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.arrow_back_ios_new, size: 12, color: AppTheme.TextSecondary),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$service — $subject',
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.TextSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInquiryDossier(Map<String, dynamic> inq) {
    final loc = AppLocalizations.of(context);
    final nomAr = inq['NomAr'] ?? inq['nomar'] ?? inq['Nom'] ?? inq['nom'] ?? inq['name'] ?? inq['employeeName'] ?? '';
    final prenomAr = inq['PrenomAr'] ?? inq['prenomar'] ?? inq['Prenom'] ?? inq['prenom'] ?? '';
    final name = (nomAr.toString().trim().isNotEmpty || prenomAr.toString().trim().isNotEmpty)
        ? '$nomAr $prenomAr'.trim()
        : (inq['EmployeeName'] ?? inq['employee_name'] ?? (loc.isArabic ? 'عضو فرقة الرقابة والتفتيش' : 'Agent de contrôle')).toString();
    final service = (inq['Service'] ?? inq['service'] ?? (loc.isArabic ? 'مديرية التجارة سطيف' : 'Direction du Commerce Sétif')).toString();
    final status = (inq['Status'] ?? inq['status'] ?? 'sent').toString();
    final rawDate = (inq['IncidentDate'] ?? inq['incidentdate'] ?? inq['Date'] ?? inq['date'] ?? inq['CreatedAt'] ?? '').toString();
    final dateStr = rawDate.length >= 10 ? rawDate.substring(0, 10) : (rawDate.isNotEmpty ? rawDate : (loc.isArabic ? 'اليوم' : 'Aujourd\'hui'));
    final reply = inq['EmployeeReply'] ?? inq['employeereply'] ?? inq['Reply'] ?? inq['reply'];
    final int lateMins = ((inq['LateMinutes'] ?? inq['lateminutes'] ?? 0) as num).toInt();
    final bool hasLateMins = lateMins > 0;
    final bool hasReply = reply != null && reply.toString().trim().isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.90,
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
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.gavel, color: Color(0xFFD4AF37), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.isArabic ? 'ملف الاستفسار واتخاذ القرار السيادي للمدير' : 'Dossier d\'explications & Décision souveraine',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          loc.isArabic
                              ? 'Dossier Disciplinaire & Pouvoir d\'Appréciation - المدير الولائي الآمر بالصرف'
                              : 'Dossier Disciplinaire & Pouvoir d\'Appréciation - Directeur Ordonnateur',
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppTheme.TextSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),

            // Dossier Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Employee Header Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF261230), AppTheme.CardColor]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.BorderColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppTheme.PrimaryColor.withValues(alpha: 0.2),
                          child: const Icon(Icons.person, size: 30, color: AppTheme.PrimaryColor),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                service,
                                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.TextSecondary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                loc.isArabic
                                    ? 'تاريخ الواقعة: $dateStr  ${hasLateMins ? " | تأخر: $lateMins دقيقة" : ""}'
                                    : 'Date: $dateStr  ${hasLateMins ? " | Retard: $lateMins min" : ""}',
                                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFD4AF37)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Employee Written Reply Section (The Core!)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: hasReply
                          ? Colors.cyan.withValues(alpha: 0.1)
                          : Colors.black26,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: hasReply
                            ? Colors.cyan.withValues(alpha: 0.4)
                            : Colors.white12,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              hasReply ? Icons.reply_all : Icons.pending_actions,
                              color: hasReply ? Colors.cyanAccent : Colors.orange,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                hasReply
                                    ? (loc.isArabic ? 'رد وتبريرات الموظف الرسمية:' : 'Réponse et justifications écrites :')
                                    : (loc.isArabic ? 'الموظف لم يرسل رده بعد (ضمن مهلة 48 ساعة)' : 'En attente de réponse (délai légal de 48h)'),
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: hasReply ? Colors.cyanAccent : Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasReply
                              ? '$reply'
                              : (loc.isArabic
                                  ? 'بانتظار إدخال الموظف لمبرراته عبر التطبيق أو تقديم وثيقة رسمية.'
                                  : 'En attente des explications de l\'agent via l\'application ou document officiel.'),
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                        if (hasReply && inq['ReplyDate'] != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 13, color: Colors.cyanAccent),
                              const SizedBox(width: 5),
                              Text(
                                loc.isArabic
                                    ? 'تاريخ تسجيل الرد: ${inq['ReplyDate'].toString().substring(0, 16)}'
                                    : 'Enregistré le : ${inq['ReplyDate'].toString().substring(0, 16)}',
                                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.cyanAccent),
                              ),
                            ],
                          ),
                        ],
                        if (hasReply && inq['ReplyAttachment'] != null && inq['ReplyAttachment'].toString().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.attach_file, color: Colors.cyanAccent, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  loc.isArabic
                                      ? 'مرفق إثبات رسمي: ${inq['ReplyAttachment']}'
                                      : 'Pièce justificative : ${inq['ReplyAttachment']}',
                                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 4 Digital Evidence Cards
                  Text(
                    loc.isArabic ? 'أدلة وقرائن الإثبات الرقمية (GPS & الحضور):' : 'Preuves et constats numériques (GPS & Pointage) :',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _evidenceCard(
                    icon: Icons.timer_off_outlined,
                    title: loc.isArabic
                        ? '1. موعد الانطلاق وفترة التسامح ($_morningGraceTime)'
                        : '1. Départ et heure de tolérance ($_morningGraceTime)',
                    desc: hasLateMins
                        ? (loc.isArabic
                            ? 'تجاوز فترة التسامح الصباحية بمقدار $lateMins دقيقة تأخر.'
                            : 'Dépassement de la tolérance matinale de $lateMins min.')
                        : (loc.isArabic
                            ? 'عدم تسجيل حضور في النطاق الجغرافي المحدد.'
                            : 'Aucun pointage dans le périmètre géographique requis.'),
                    status: hasLateMins
                        ? (loc.isArabic ? '$lateMins دقيقة تأخر ⚠️' : '$lateMins min retard ⚠️')
                        : (loc.isArabic ? 'غير مسجل ❌' : 'Non pointé ❌'),
                    statusColor: hasLateMins ? AppTheme.WarningColor : AppTheme.DangerColor,
                  ),
                  const SizedBox(height: 6),
                  _evidenceCard(
                    icon: Icons.storefront_outlined,
                    title: loc.isArabic ? '2. المردودية والزيارات الميدانية' : '2. Rendement et visites de contrôle',
                    desc: loc.isArabic
                        ? 'سجل الزيارات والمعاينات التجارية والمحاضر الرقابية في هذا التاريخ.'
                        : 'Registre des visites commerciales et PV établis à cette date.',
                    status: loc.isArabic ? '0 زيارات ❌' : '0 visites ❌',
                    statusColor: AppTheme.DangerColor,
                  ),

                  const SizedBox(height: 14),

                  // Printable Inquiry Sheet Button
                  OutlinedButton.icon(
                    onPressed: () => InquiryLetterDialog.show(context, inq),
                    icon: const Icon(Icons.picture_as_pdf, color: Color(0xFFD4AF37)),
                    label: Text(
                      loc.isArabic ? 'معاينة استمارة الاستفسار الإداري الرسمية' : 'Aperçu du formulaire officiel de demande d\'explications',
                      style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Color(0xFFD4AF37)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFD4AF37)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sovereign Decision Buttons for Director (if status == 'answered' or 'sent')
                  if (status == 'answered' || status == 'sent') ...[
                    Text(
                      loc.isArabic
                          ? 'القرار السيادي للمدير الولائي (صاحب السلطة والآمر بالصرف):'
                          : 'Décision souveraine du Directeur de Wilaya (Ordonnateur) :',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Option 1: Justified (Classé sans suite)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _submitDecision(
                              inquiryId: inq['Id'] as int,
                              decision: 'justified',
                              name: name,
                              parentCtx: ctx,
                            ),
                            icon: const Icon(Icons.check, size: 16),
                            label: Text(
                              loc.isArabic ? 'قبول التبرير (حفظ)' : 'Accepter (Classer)',
                              style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.SuccessColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Option 2: Warning (Avertissement)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _submitDecision(
                              inquiryId: inq['Id'] as int,
                              decision: 'warning',
                              name: name,
                              parentCtx: ctx,
                            ),
                            icon: const Icon(Icons.warning_amber, size: 16),
                            label: Text(
                              loc.isArabic ? 'توجيه إنذار' : 'Avertissement',
                              style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Option 3: Final Deduction Decision
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showDeductionDaysDialog(
                              inquiryId: inq['Id'] as int,
                              name: name,
                              parentCtx: ctx,
                            ),
                            icon: const Icon(Icons.gavel, size: 16),
                            label: Text(
                              loc.isArabic ? 'قرار خصم نافذ' : 'Ordre de déduction',
                              style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.DangerColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeductionDaysDialog({required int inquiryId, required String name, required BuildContext parentCtx}) {
    final loc = AppLocalizations.of(context);
    double selectedDays = 1.0;
    final notesCtrl = TextEditingController(
      text: loc.isArabic
          ? 'خصم من الراتب لعدم كفاية التبريرات المسجلة بناءً على المقتضيات القانونية'
          : 'Déduction sur salaire pour justifications insuffisantes conformément à la réglementation',
    );

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF16121E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppTheme.DangerColor, width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.gavel, color: AppTheme.DangerColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.isArabic ? 'إصدار قرار خصم نهائي — $name' : 'Décision de déduction définitive — $name',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.DangerColor,
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
                loc.isArabic
                    ? 'حدد عدد أيام الخصم الواجب اقتطاعها رسمياً وإحالتها لمكتب المستخدمين لتنفيذها في كشف الراتب:'
                    : 'Indiquez le nombre de jours à déduire officiellement sur la fiche de paie par le bureau du personnel :',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ChoiceChip(
                    label: Text(loc.isArabic ? 'نصف يوم (0.5)' : '0.5 jour', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
                    selected: selectedDays == 0.5,
                    selectedColor: AppTheme.DangerColor,
                    onSelected: (val) => setDlgState(() => selectedDays = 0.5),
                  ),
                  ChoiceChip(
                    label: Text(loc.isArabic ? 'يوم كامل (1.0)' : '1.0 jour', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
                    selected: selectedDays == 1.0,
                    selectedColor: AppTheme.DangerColor,
                    onSelected: (val) => setDlgState(() => selectedDays = 1.0),
                  ),
                  ChoiceChip(
                    label: Text(loc.isArabic ? 'يومان (2.0)' : '2.0 jours', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
                    selected: selectedDays == 2.0,
                    selectedColor: AppTheme.DangerColor,
                    onSelected: (val) => setDlgState(() => selectedDays = 2.0),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                textDirection: loc.isArabic ? TextDirection.rtl : TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: loc.isArabic ? 'ملاحظات وتوجيهات المدير لمكتب المستخدمين' : 'Instructions du Directeur au bureau du personnel',
                  labelStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white60),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: Text(loc.isArabic ? 'إلغاء' : 'Annuler', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final api = context.read<AuthService>().api;
                Navigator.pop(dlgCtx);
                Navigator.pop(parentCtx);
                try {
                  await api.submitDirectorDecision(
                    inquiryId,
                    'deduction',
                    notes: notesCtrl.text.trim(),
                    deductionDays: selectedDays,
                  );
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        loc.isArabic
                            ? '✅ تم إصدار قرار الخصم بمقدار $selectedDays يوم وإحالته لمكتب المستخدمين للتنفيذ الفوري'
                            : '✅ Décision de déduction de $selectedDays jour(s) transmise au bureau du personnel',
                      ),
                      backgroundColor: AppTheme.SuccessColor,
                    ),
                  );
                  if (mounted) _load();
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.DangerColor),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.DangerColor),
              child: Text(
                loc.isArabic ? 'تأكيد وإصدار القرار النافذ' : 'Confirmer la décision',
                style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitDecision({
    required int inquiryId,
    required String decision,
    required String name,
    required BuildContext parentCtx,
  }) async {
    final loc = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final api = context.read<AuthService>().api;
    Navigator.pop(parentCtx);
    try {
      await api.submitDirectorDecision(inquiryId, decision);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            decision == 'justified'
                ? (loc.isArabic ? '✅ تم قبول تبرير $name وحفظ الملف' : '✅ Justification acceptée pour $name (Classé)')
                : (loc.isArabic ? '⚠️ تم توجيه تنبيه إداري لـ $name' : '⚠️ Avertissement administratif adressé à $name'),
          ),
          backgroundColor: decision == 'justified' ? AppTheme.SuccessColor : Colors.orange,
        ),
      );
      if (mounted) _load();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.DangerColor),
      );
    }
  }

  Widget _evidenceCard({
    required IconData icon,
    required String title,
    required String desc,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.BackgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.BorderColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                      ),
                    ),
                    Text(
                      status,
                      style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 10, color: statusColor),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.TextSecondary, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEmployeePicker() {
    final loc = AppLocalizations.of(context);
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filtered = _employees.where((e) {
            final nameAr = '${e['NomAr'] ?? ''} ${e['PrenomAr'] ?? ''}'.toLowerCase();
            final nameFr = '${e['Nom'] ?? ''} ${e['Prenom'] ?? ''}'.toLowerCase();
            final service = (e['Service'] ?? '').toString().toLowerCase();
            final q = searchQuery.trim().toLowerCase();
            return nameAr.contains(q) || nameFr.contains(q) || service.contains(q);
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Color(0xFF130F1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppTheme.BorderColor.withValues(alpha: 0.3))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          loc.isArabic ? 'اختر موظفاً لإصدار أمر استفسار بشأنه' : 'Sélectionner un agent pour ordonner une demande',
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    textDirection: loc.isArabic ? TextDirection.rtl : TextDirection.ltr,
                    onChanged: (val) => setSheetState(() => searchQuery = val),
                    decoration: InputDecoration(
                      hintText: loc.isArabic ? 'ابحث عن مفتش بالاسم أو المصلحة...' : 'Rechercher un agent par nom ou service...',
                      hintStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Colors.black26,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final e = filtered[index];
                      final name = loc.isArabic
                          ? (e['NomAr'] != null ? '${e['NomAr']} ${e['PrenomAr'] ?? ''}'.trim() : '${e['Nom'] ?? ''} ${e['Prenom'] ?? ''}'.trim())
                          : (e['Nom'] != null ? '${e['Nom']} ${e['Prenom'] ?? ''}'.trim() : '${e['NomAr'] ?? ''} ${e['PrenomAr'] ?? ''}'.trim());
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.PrimaryColor.withValues(alpha: 0.2),
                          child: const Icon(Icons.person, color: AppTheme.PrimaryColor, size: 18),
                        ),
                        title: Text(name, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.white)),
                        subtitle: Text('${e['Service'] ?? ''}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.TextSecondary)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showDirectorOrderModal(e);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
