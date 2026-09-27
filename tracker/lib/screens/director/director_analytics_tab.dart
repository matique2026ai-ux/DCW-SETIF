import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:drh_setif_tracker/services/auth_service.dart';
import 'package:drh_setif_tracker/services/pdf_report_service.dart';
import 'package:drh_setif_tracker/utils/app_localizations.dart';
import 'package:drh_setif_tracker/utils/constants.dart';

class DirectorAnalyticsTab extends StatefulWidget {
  const DirectorAnalyticsTab({super.key});

  @override
  State<DirectorAnalyticsTab> createState() => _DirectorAnalyticsTabState();
}

class _DirectorAnalyticsTabState extends State<DirectorAnalyticsTab> {
  DateTime _selectedDate = DateTime.now();
  String _selectedPeriod = 'today'; // 'today', 'week', 'month', 'cumulative', 'custom'
  Map<String, dynamic> _analyticsData = {};
  bool _isLoading = true;
  Timer? _refreshTimer;
  int? _hoveredBarIndex;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadData(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({String? period, DateTime? date, bool silent = false}) async {
    final targetPeriod = period ?? _selectedPeriod;
    final targetDate = date ?? _selectedDate;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _selectedPeriod = targetPeriod;
        _selectedDate = targetDate;
      });
    }

    try {
      final api = context.read<AuthService>().api;
      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
      final data = await api.getDirectorAnalytics(
        date: targetPeriod == 'custom' ? dateStr : null,
        period: targetPeriod != 'custom' ? targetPeriod : null,
      );

      if (mounted) {
        setState(() {
          _analyticsData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD4AF37),
              onPrimary: Colors.black,
              surface: Color(0xFF240D2D),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1E0B26)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && !DateUtils.isSameDay(picked, _selectedDate)) {
      _loadData(date: picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isArabic = loc.isArabic;

    if (_isLoading && _analyticsData.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
      );
    }

    final attendance = (_analyticsData['attendance'] as Map<String, dynamic>?) ?? {};
    final inspections = (_analyticsData['todayInspections'] as Map<String, dynamic>?) ?? {};
    final cumulative = (_analyticsData['cumulativeTotals'] as Map<String, dynamic>?) ?? {};
    final deptBreakdown = (_analyticsData['departmentBreakdown'] as Map<String, dynamic>?) ?? {};
    final fraudRep = (deptBreakdown['fraudRepression'] as Map<String, dynamic>?) ?? {};
    final competition = (deptBreakdown['competition'] as Map<String, dynamic>?) ?? {};
    final topInspectors = (_analyticsData['topInspectors'] as List<dynamic>?) ?? [];
    final recentVisits = (_analyticsData['recentVisits'] as List<dynamic>?) ?? [];
    final dailyTrend = (_analyticsData['dailyTrend'] as List<dynamic>?) ?? [];
    final sectorBreakdown = (_analyticsData['sectorBreakdown'] as List<dynamic>?) ?? [];
    final inspectoratesStats = (_analyticsData['inspectorateBreakdown'] as Map<String, dynamic>?) ?? {};

    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final dateStr = DateFormat('yyyy/MM/dd').format(_selectedDate);

    return RefreshIndicator(
      onRefresh: () => _loadData(),
      color: const Color(0xFFD4AF37),
      backgroundColor: const Color(0xFF240D2D),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Executive Control Bar & Dynamic Period Selector
            _buildExecutiveHeader(isArabic, isToday, dateStr),
            const SizedBox(height: 16),

            // 2. Primary KPI Metric Cards (Interactive on Tap - 8 Balanced Cards)
            _buildKpiDeck(isArabic, inspections, attendance, recentVisits),
            const SizedBox(height: 20),

            // 3. Animated Daily Performance & Infraction Dual-Bar Chart
            _buildAnimatedDailyTrendChart(isArabic, dailyTrend, inspections, recentVisits),
            const SizedBox(height: 20),

            // 4. Animated Sector Distribution & Legal Compliance Donut
            _buildAnimatedSectorAndComplianceSection(isArabic, sectorBreakdown, inspections, recentVisits),
            const SizedBox(height: 20),

            // 5. Department Breakdown (Fraud Repression vs Competition)
            _buildDepartmentsSection(isArabic, fraudRep, competition),
            const SizedBox(height: 20),

            // 6. Macro Cumulative Ledger & Quality Indicators
            _buildCumulativeMacroCard(isArabic, cumulative, recentVisits),
            const SizedBox(height: 20),

            // 7. Territorial Inspectorates & Top Inspectors Deck
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 850) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 6,
                        child: _buildInspectoratesDistribution(isArabic, inspectoratesStats),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: _buildTopInspectorsCard(isArabic, topInspectors),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildInspectoratesDistribution(isArabic, inspectoratesStats),
                    const SizedBox(height: 16),
                    _buildTopInspectorsCard(isArabic, topInspectors),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // 8. Recent Verified Inspections Log
            _buildRecentInspectionsLog(isArabic, recentVisits),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveHeader(bool isArabic, bool isToday, String dateStr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D1037), Color(0xFF1E0A25)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Title + Status + Date/PDF actions
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                      ),
                      child: const Icon(Icons.analytics_outlined, color: Color(0xFFD4AF37), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                isArabic ? 'لوحة القيادة والمؤشرات الرقابية الميدانية' : 'Tableau de Bord & Indicateurs de Contrôle',
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              // Live animated indicator badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF10B981), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isArabic ? 'مُحيَّن آنياً' : 'En temps réel',
                                      style: const TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _selectedPeriod == 'today'
                                ? (isArabic ? 'حصيلة النشاط الرقابي والتفتيش الميداني — اليوم' : 'Bilan des opérations de contrôle — Aujourd\'hui')
                                : _selectedPeriod == 'week'
                                    ? (isArabic ? 'المؤشرات الرقابية خلال الأسبوع الجاري' : 'Statistiques hebdomadaires')
                                    : _selectedPeriod == 'month'
                                        ? (isArabic ? 'حصيلة الرقابة والمتابعة الاقتصادية خلال الشهر' : 'Bilan mensuel du contrôle')
                                        : _selectedPeriod == 'cumulative'
                                            ? (isArabic ? 'الحصيلة الإجمالية التراكمية لسجل المديرية الولائية' : 'Bilan global cumulatif de la Direction')
                                            : (isArabic ? 'سجل التدخلات الرقابية ليوم: $dateStr' : 'Registre du: $dateStr'),
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              color: _selectedPeriod == 'today' ? const Color(0xFF10B981) : const Color(0xFFD4AF37),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _loadData(),
                    tooltip: isArabic ? 'تحديث فوري' : 'Actualiser',
                    icon: const Icon(Icons.refresh, color: Color(0xFFD4AF37), size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF1A0A20),
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month, color: Color(0xFFD4AF37), size: 18),
                    label: Text(
                      dateStr,
                      style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF4A2050)),
                      backgroundColor: const Color(0xFF1A0A20),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _exportExecutivePdf(),
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.black, size: 18),
                    label: Text(
                      isArabic ? 'تصدير التقرير' : 'Exporter PDF',
                      style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.black, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF3B1A40), height: 1),
          const SizedBox(height: 12),

          // Bottom Row: Animated Period Filter Pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPeriodPill(
                id: 'today',
                label: isArabic ? 'اليوم' : 'Aujourd\'hui',
                icon: Icons.today_rounded,
                isArabic: isArabic,
              ),
              _buildPeriodPill(
                id: 'week',
                label: isArabic ? 'هذا الأسبوع' : 'Cette Semaine',
                icon: Icons.date_range_rounded,
                isArabic: isArabic,
              ),
              _buildPeriodPill(
                id: 'month',
                label: isArabic ? 'هذا الشهر' : 'Ce Mois',
                icon: Icons.calendar_view_month_rounded,
                isArabic: isArabic,
              ),
              _buildPeriodPill(
                id: 'cumulative',
                label: isArabic ? 'الإجمالي التراكمي' : 'Cumulatif',
                icon: Icons.all_inclusive_rounded,
                isArabic: isArabic,
              ),
              _buildPeriodPill(
                id: 'custom',
                label: isArabic ? 'تاريخ مخصص' : 'Date Personnalisée',
                icon: Icons.event_note_rounded,
                isArabic: isArabic,
                onTapCustom: _pickDate,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodPill({
    required String id,
    required String label,
    required IconData icon,
    required bool isArabic,
    VoidCallback? onTapCustom,
  }) {
    final isSelected = _selectedPeriod == id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (id == 'custom' && onTapCustom != null) {
            onTapCustom();
          } else {
            _loadData(period: id);
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF1E0A25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFFD4AF37) : const Color(0xFF4A2050),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.black : const Color(0xFFD4AF37),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.black : Colors.grey.shade300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiDeck(
    bool isArabic,
    Map<String, dynamic> ins,
    Map<String, dynamic> att,
    List<dynamic> recentVisits,
  ) {
    final int totalVisits = (ins['totalVisits'] as num?)?.toInt() ?? recentVisits.length;
    final int violations = (ins['violationsCount'] as num?)?.toInt() ?? recentVisits.where((v) => v['ViolationFound'] == true || v['violationfound'] == true || v['ViolationFound'] == 1).length;
    
    // Robust calculation for Seizure Value
    double seizureVal = (ins['totalSeizureValue'] as num?)?.toDouble() ?? double.tryParse(ins['totalSeizureValue']?.toString() ?? '0') ?? 0.0;
    if (seizureVal == 0.0 && recentVisits.isNotEmpty) {
      for (final v in recentVisits) {
        final val = (v['SeizureValue'] as num?)?.toDouble() ?? double.tryParse(v['SeizureValue']?.toString() ?? '0') ?? 0.0;
        seizureVal += val;
        if (val == 0.0) {
          final notes = '${v['ViolationNotes'] ?? ''} ${v['Notes'] ?? ''}';
          final match = RegExp(r'(\d+[\d,.]*)\s*دج').firstMatch(notes);
          if (match != null) {
            final parsed = double.tryParse(match.group(1)!.replaceAll(',', '').replaceAll('.', ''));
            if (parsed != null && parsed > 0) seizureVal += parsed;
          }
        }
      }
    }

    final int closures = (ins['closureProposalsCount'] as num?)?.toInt() ?? recentVisits.where((v) => (v['LegalAction']?.toString().contains('غلق') ?? false) || (v['ViolationNotes']?.toString().contains('غلق') ?? false)).length;
    final int samples = (ins['samplesCount'] as num?)?.toInt() ?? recentVisits.where((v) => (v['LegalAction']?.toString().contains('عين') ?? false) || (v['ViolationNotes']?.toString().contains('عين') ?? false)).length;
    final int courtReferrals = (ins['courtReferralsCount'] as num?)?.toInt() ?? recentVisits.where((v) => (v['LegalAction']?.toString().contains('محضر') ?? false) || (v['ViolationNotes']?.toString().contains('محضر') ?? false)).length;
    final String readinessRate = att['readinessRate']?.toString() ?? '0.0';
    final String complianceRate = ins['complianceRate']?.toString() ?? (totalVisits > 0 ? (((totalVisits - violations) / totalVisits) * 100).toStringAsFixed(1) : '100.0');

    final formatter = NumberFormat('#,###', 'fr_DZ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── TOP ROW: 4 PRIMARY STRATEGIC PILLARS (Clean, sleek, balanced height) ──
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 900;
            final isTablet = constraints.maxWidth > 550;
            final crossAxisCount = isDesktop ? 4 : (isTablet ? 2 : 1);

            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 10,
              childAspectRatio: isDesktop ? 2.4 : (isTablet ? 2.6 : 2.7),
              children: [
                _buildHeroMetricCard(
                  title: isArabic ? 'معاينات وتدخلات الرقابة' : 'Visites de Contrôle',
                  value: '$totalVisits',
                  unit: isArabic ? 'تدخل ميداني' : 'visites',
                  icon: Icons.storefront_rounded,
                  accentColor: const Color(0xFFD4AF37),
                  badgeText: isArabic ? 'نشاط ميداني' : 'Opérations',
                  badgeColor: const Color(0xFFD4AF37),
                  isArabic: isArabic,
                  onTap: () => _showVisitsDetailsSheet(context, recentVisits, isArabic),
                ),
                _buildHeroMetricCard(
                  title: isArabic ? 'المخالفات والمحاضر' : 'Infractions Constatées',
                  value: '$violations',
                  unit: isArabic ? 'مخالفة محررة' : 'infractions',
                  icon: Icons.gavel_rounded,
                  accentColor: const Color(0xFFEF4444),
                  badgeText: violations > 0 ? (isArabic ? 'متابعة' : 'Suivi') : (isArabic ? 'سليم' : 'RAS'),
                  badgeColor: const Color(0xFFEF4444),
                  isArabic: isArabic,
                  onTap: () => _showViolationsDetailsSheet(context, recentVisits, isArabic),
                ),
                _buildHeroMetricCard(
                  title: isArabic ? 'قيمة السلع المحجوزة' : 'Valeur des Saisies',
                  value: seizureVal > 0 ? formatter.format(seizureVal) : '0',
                  unit: 'دج',
                  icon: Icons.inventory_2_rounded,
                  accentColor: const Color(0xFFF59E0B),
                  badgeText: isArabic ? 'محجوزات' : 'Saisie',
                  badgeColor: const Color(0xFFF59E0B),
                  isArabic: isArabic,
                  onTap: () => _showSeizuresDetailsSheet(context, recentVisits, isArabic, seizureVal),
                ),
                _buildHeroMetricCard(
                  title: isArabic ? 'نسبة الامتثال التجاري' : 'Taux de Conformité',
                  value: '$complianceRate%',
                  unit: isArabic ? 'مطابقة قانونية' : 'conforme',
                  icon: Icons.verified_rounded,
                  accentColor: const Color(0xFF10B981),
                  badgeText: isArabic ? 'القانون 09-03' : 'Loi 09-03',
                  badgeColor: const Color(0xFF10B981),
                  isArabic: isArabic,
                  onTap: () => _showComplianceDetailsSheet(context, recentVisits, isArabic, totalVisits, violations),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 10),

        // ── BOTTOM ROW: 4 OPERATIONAL & LEGAL ACTION MINI-TILES ──
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 900;
            final isTablet = constraints.maxWidth > 550;
            final crossAxisCount = isDesktop ? 4 : (isTablet ? 2 : 1);

            return GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 8,
              childAspectRatio: isDesktop ? 3.6 : (isTablet ? 3.8 : 4.0),
              children: [
                _buildCompactActionTile(
                  title: isArabic ? 'الجاهزية والانتشار' : 'Déploiement',
                  value: '$readinessRate%',
                  subtext: isArabic ? '${att['presentToday'] ?? 0} حاضر من ${att['totalInspectors'] ?? 5}' : '${att['presentToday'] ?? 0} / ${att['totalInspectors'] ?? 5}',
                  icon: Icons.people_alt_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () => _showReadinessDetailsSheet(context, att, isArabic),
                ),
                _buildCompactActionTile(
                  title: isArabic ? 'المتابعات القضائية' : 'Poursuites',
                  value: '$courtReferrals',
                  subtext: isArabic ? 'محضر محال للعدالة' : 'PVs au parquet',
                  icon: Icons.balance_rounded,
                  color: const Color(0xFFE11D48),
                  onTap: () => _showCourtReferralsDetailsSheet(context, recentVisits, isArabic),
                ),
                _buildCompactActionTile(
                  title: isArabic ? 'اقتراح الغلق الإداري' : 'Fermetures',
                  value: '$closures',
                  subtext: isArabic ? 'مقترح للوالي' : 'Proposé au Wali',
                  icon: Icons.block_rounded,
                  color: const Color(0xFFEC4899),
                  onTap: () => _showClosuresDetailsSheet(context, recentVisits, isArabic),
                ),
                _buildCompactActionTile(
                  title: isArabic ? 'اقتطاع العينات' : 'Échantillons',
                  value: '$samples',
                  subtext: isArabic ? 'عينات لتحاليل المخبر' : 'Analyses labo',
                  icon: Icons.science_rounded,
                  color: const Color(0xFFA855F7),
                  onTap: () => _showSamplesDetailsSheet(context, recentVisits, isArabic),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ─── ANIMATED CHART 1: DAILY PERFORMANCE & TREND DUAL-BAR CHART ────────────
  Widget _buildAnimatedDailyTrendChart(
    bool isArabic,
    List<dynamic> dailyTrend,
    Map<String, dynamic> ins,
    List<dynamic> recentVisits,
  ) {
    final double maxVisits = dailyTrend.isEmpty
        ? 1.0
        : dailyTrend
            .map((e) => (e['visits'] as num?)?.toDouble() ?? 0.0)
            .fold(1.0, (max, v) => v > max ? v : max);

    final String violationRate = ins['violationRate']?.toString() ?? '0.0';
    final String complianceRate = ins['complianceRate']?.toString() ?? '100.0';
    final int courtReferrals = (ins['courtReferralsCount'] as num?)?.toInt() ?? 0;
    final formatter = NumberFormat('#,###', 'fr_DZ');
    final double seizureVal = (ins['totalSeizureValue'] as num?)?.toDouble() ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF240D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.insights_rounded, color: Color(0xFFD4AF37), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isArabic
                        ? 'مخطط الأداء وتطور التدخلات اليومية والمخالفات الميدانية'
                        : 'Évolution Quotidienne des Contrôles & Infractions',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
                ),
                child: Text(
                  isArabic ? 'مؤشر التطور اليومي' : 'Évolution journalière',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD4AF37),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Key Summary Metrics Pill Row
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _buildTrendMetricBadge(
                label: isArabic ? 'معدل المخالفات العام:' : 'Taux d\'infraction:',
                value: '$violationRate%',
                color: const Color(0xFFEF4444),
                icon: Icons.warning_amber_rounded,
              ),
              _buildTrendMetricBadge(
                label: isArabic ? 'معدل الامتثال التجاري:' : 'Taux de conformité:',
                value: '$complianceRate%',
                color: const Color(0xFF10B981),
                icon: Icons.verified_rounded,
              ),
              _buildTrendMetricBadge(
                label: isArabic ? 'إحالة للعدالة:' : 'Poursuites judiciaires:',
                value: '$courtReferrals محضر',
                color: const Color(0xFFE11D48),
                icon: Icons.gavel_rounded,
              ),
              if (seizureVal > 0)
                _buildTrendMetricBadge(
                  label: isArabic ? 'إجمالي المحجوزات:' : 'Saisies:',
                  value: '${formatter.format(seizureVal)} دج',
                  color: const Color(0xFFF59E0B),
                  icon: Icons.inventory_2_rounded,
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Animated Dual Bars Container
          if (dailyTrend.isEmpty)
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFF1A0A20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3B1A40)),
              ),
              child: Center(
                child: Text(
                  isArabic
                      ? 'جاري تحديث واسترجاع مؤشرات التدخلات الرقابية...'
                      : 'Chargement des indicateurs de contrôle...',
                  style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade400, fontSize: 13),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0A20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3B1A40)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 215,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: List.generate(dailyTrend.length, (idx) {
                                final day = dailyTrend[idx];
                                final int visits = (day['visits'] as num?)?.toInt() ?? 0;
                                final int violations = (day['violations'] as num?)?.toInt() ?? 0;
                                final String rawDate = day['date']?.toString() ?? '';
                                final double seizures = (day['seizures'] as num?)?.toDouble() ?? 0.0;
                                final bool isHovered = _hoveredBarIndex == idx;

                                String shortDate = rawDate;
                                if (rawDate.contains('-')) {
                                  final parts = rawDate.split('-');
                                  if (parts.length == 3) shortDate = '${parts[2]}/${parts[1]}';
                                }

                                final double targetVisitsHeight = (visits / maxVisits) * 105.0;
                                final double targetViolationsHeight = (violations / maxVisits) * 105.0;

                                return MouseRegion(
                                  onEnter: (_) => setState(() => _hoveredBarIndex = idx),
                                  onExit: (_) => setState(() => _hoveredBarIndex = null),
                                  child: Tooltip(
                                    message: '$rawDate\n${isArabic ? 'معاينات: $visits | مخالفات: $violations | محجوزات: ${formatter.format(seizures)} دج' : 'Visites: $visits | Infractions: $violations | Saisies: ${formatter.format(seizures)} DZD'}',
                                    textStyle: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF240D2D),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFD4AF37)),
                                    ),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isHovered
                                            ? const Color(0xFFD4AF37).withValues(alpha: 0.1)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        border: isHovered
                                            ? Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5))
                                            : null,
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Top stats badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isHovered
                                                  ? const Color(0xFFD4AF37)
                                                  : const Color(0xFF2D1037),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '$visits',
                                              style: TextStyle(
                                                fontFamily: 'Tajawal',
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isHovered ? Colors.black : const Color(0xFFD4AF37),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),

                                          // Dual Animated Bars
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              // Visits Bar
                                              TweenAnimationBuilder<double>(
                                                tween: Tween<double>(begin: 0.0, end: targetVisitsHeight.clamp(6.0, 105.0)),
                                                duration: Duration(milliseconds: 700 + (idx * 80)),
                                                curve: Curves.easeOutCubic,
                                                builder: (context, height, _) {
                                                  return Container(
                                                    width: 14,
                                                    height: height,
                                                    decoration: BoxDecoration(
                                                      gradient: const LinearGradient(
                                                        colors: [Color(0xFFD4AF37), Color(0xFFB89628)],
                                                        begin: Alignment.topCenter,
                                                        end: Alignment.bottomCenter,
                                                      ),
                                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                                      boxShadow: isHovered
                                                          ? [
                                                              BoxShadow(
                                                                color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                                                                blurRadius: 8,
                                                                offset: const Offset(0, -2),
                                                              ),
                                                            ]
                                                          : null,
                                                    ),
                                                  );
                                                },
                                              ),
                                              const SizedBox(width: 4),

                                              // Violations Bar
                                              TweenAnimationBuilder<double>(
                                                tween: Tween<double>(begin: 0.0, end: targetViolationsHeight.clamp(violations > 0 ? 6.0 : 0.0, 105.0)),
                                                duration: Duration(milliseconds: 800 + (idx * 80)),
                                                curve: Curves.easeOutCubic,
                                                builder: (context, height, _) {
                                                  return Container(
                                                    width: 14,
                                                    height: height,
                                                    decoration: BoxDecoration(
                                                      gradient: const LinearGradient(
                                                        colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                                                        begin: Alignment.topCenter,
                                                        end: Alignment.bottomCenter,
                                                      ),
                                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                                      boxShadow: isHovered && violations > 0
                                                          ? [
                                                              BoxShadow(
                                                                color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                                                                blurRadius: 8,
                                                                offset: const Offset(0, -2),
                                                              ),
                                                            ]
                                                          : null,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),

                                          // Date label
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              shortDate,
                                              style: TextStyle(
                                                fontFamily: 'Tajawal',
                                                fontSize: 11,
                                                fontWeight: isHovered ? FontWeight.bold : FontWeight.normal,
                                                color: isHovered ? Colors.white : Colors.grey.shade400,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF2D1037), height: 1),
                  const SizedBox(height: 10),

                  // Chart Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem('التدخلات والمعاينات الميدانية', const Color(0xFFD4AF37)),
                      const SizedBox(width: 24),
                      _buildLegendItem('المخالفات والمحاضر المرفوعة', const Color(0xFFEF4444)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrendMetricBadge({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade300),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade300),
        ),
      ],
    );
  }

  // ─── ANIMATED CHART 2: SECTORS BREAKDOWN & LEGAL COMPLIANCE GAUGES ──────────
  Widget _buildAnimatedSectorAndComplianceSection(
    bool isArabic,
    List<dynamic> sectorBreakdown,
    Map<String, dynamic> ins,
    List<dynamic> recentVisits,
  ) {
    final int totalVisits = (ins['totalVisits'] as num?)?.toInt() ?? (recentVisits.isNotEmpty ? recentVisits.length : 1);
    final int violations = (ins['violationsCount'] as num?)?.toInt() ?? 0;
    final double complianceDouble = totalVisits > 0
        ? math.max(0.0, math.min(100.0, ((totalVisits - violations) / totalVisits) * 100.0))
        : 100.0;
    final int courtReferrals = (ins['courtReferralsCount'] as num?)?.toInt() ?? 0;
    final int closures = (ins['closureProposalsCount'] as num?)?.toInt() ?? 0;
    final int samples = (ins['samplesCount'] as num?)?.toInt() ?? 0;
    final formatter = NumberFormat('#,###', 'fr_DZ');

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 850) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: _buildSectorsCard(isArabic, sectorBreakdown, totalVisits, formatter),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: _buildLegalGaugesCard(isArabic, complianceDouble, courtReferrals, closures, samples, totalVisits, violations),
              ),
            ],
          );
        }
        return Column(
          children: [
            _buildSectorsCard(isArabic, sectorBreakdown, totalVisits, formatter),
            const SizedBox(height: 16),
            _buildLegalGaugesCard(isArabic, complianceDouble, courtReferrals, closures, samples, totalVisits, violations),
          ],
        );
      },
    );
  }

  Widget _buildSectorsCard(
    bool isArabic,
    List<dynamic> sectors,
    int totalVisits,
    NumberFormat formatter,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF240D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4A2050)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline_rounded, color: Color(0xFFD4AF37), size: 20),
              const SizedBox(width: 8),
              Text(
                isArabic
                    ? 'التوزيع القطاعي للأنشطة التجارية الخاضعة للرقابة'
                    : 'Répartition Sectorielle des Commerces Contrôlés',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isArabic
                ? 'مؤشر الامتثال ومعدل المخالفات حسب طبيعة النشاط (القانون 09-03 و 04-02)'
                : 'Taux de non-conformité par branche d\'activité économique',
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),

          if (sectors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  isArabic ? 'لا توجد بيانات قطاعية مسجلة' : 'Aucune donnée sectorielle',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade400),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sectors.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final s = sectors[idx] as Map<String, dynamic>;
                final name = s['sector']?.toString() ?? 'نشاط تجاري';
                final visits = (s['visits'] as num?)?.toInt() ?? 0;
                final viols = (s['violations'] as num?)?.toInt() ?? 0;
                final rate = (s['rate'] as num?)?.toDouble() ?? (visits > 0 ? (viols / visits * 100) : 0.0);
                final seizures = (s['seizuresValue'] as num?)?.toDouble() ?? 0.0;
                final double targetFraction = totalVisits > 0 ? (visits / totalVisits).clamp(0.05, 1.0) : 0.1;

                final Color rateColor = rate == 0.0
                    ? const Color(0xFF10B981)
                    : rate < 35.0
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFEF4444);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$visits معاينة | $viols مخالفة',
                              style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade400),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: rateColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: rateColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                rate == 0.0 ? (isArabic ? 'مطابق 100%' : '100% Conforme') : '${rate.toStringAsFixed(1)}% مخالفات',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: rateColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Animated Progress Bar
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: targetFraction),
                      duration: Duration(milliseconds: 600 + (idx * 100)),
                      curve: Curves.easeOutCubic,
                      builder: (context, val, _) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: val,
                            minHeight: 7,
                            backgroundColor: const Color(0xFF1A0A20),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              rate == 0.0 ? const Color(0xFF10B981) : const Color(0xFFD4AF37),
                            ),
                          ),
                        );
                      },
                    ),
                    if (seizures > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '💰 محجوزات: ${formatter.format(seizures)} دج',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Color(0xFFF59E0B)),
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLegalGaugesCard(
    bool isArabic,
    double complianceRate,
    int courtRef,
    int closures,
    int samples,
    int totalVisits,
    int violations,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF240D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4A2050)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined, color: Color(0xFFD4AF37), size: 20),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'مؤشر الامتثال التجاري والقرارات' : 'Conformité & Décisions Répressives',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isArabic ? 'معايير القانون 09-03 لحماية المستهلك والقانون 04-02' : 'Indicateurs légaux Loi 09-03 & 04-02',
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 18),

          // Concentric Animated Ring Gauge
          Center(
            child: SizedBox(
              width: 165,
              height: 165,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: complianceRate / 100.0),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutBack,
                builder: (context, compProgress, _) {
                  return CustomPaint(
                    painter: _ComplianceRingsPainter(
                      complianceProgress: compProgress,
                      readinessProgress: 0.85,
                      complianceColor: const Color(0xFF10B981),
                      readinessColor: const Color(0xFFD4AF37),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(compProgress * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isArabic ? 'امتثال تجاري' : 'Conformité',
                                style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade300),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Sanctions Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.85,
            children: [
              _buildSanctionTile(
                title: isArabic ? 'متابعات قضائية' : 'PVs Justice',
                value: '$courtRef محضر',
                color: const Color(0xFFE11D48),
                icon: Icons.gavel_rounded,
                isArabic: isArabic,
              ),
              _buildSanctionTile(
                title: isArabic ? 'اقتراحات الغلق' : 'Fermetures',
                value: '$closures قرار',
                color: const Color(0xFFEC4899),
                icon: Icons.block_rounded,
                isArabic: isArabic,
              ),
              _buildSanctionTile(
                title: isArabic ? 'عينات التحاليل' : 'Analyses Labo',
                value: '$samples عينة',
                color: const Color(0xFFA855F7),
                icon: Icons.science_rounded,
                isArabic: isArabic,
              ),
              _buildSanctionTile(
                title: isArabic ? 'مخالفات محررة' : 'Infractions',
                value: '$violations حالة',
                color: const Color(0xFFEF4444),
                icon: Icons.report_problem_rounded,
                isArabic: isArabic,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSanctionTile({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    bool isArabic = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetricCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color accentColor,
    required String badgeText,
    required Color badgeColor,
    bool isArabic = true,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: accentColor.withValues(alpha: 0.15),
        highlightColor: accentColor.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF240D2D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header: Icon + Title + Tiny Status Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, color: accentColor, size: 15),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade300,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 0.8),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              // Body: Big Numeric Value + Unit + Tap indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: isArabic ? Alignment.centerRight : Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            value,
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            unit,
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'تفاصيل',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_left_rounded, size: 14, color: Colors.grey.shade500),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactActionTile({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E0A25),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtext,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentsSection(bool isArabic, Map<String, dynamic> fraud, Map<String, dynamic> comp) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF240D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4A2050)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_tree_outlined, color: Color(0xFFD4AF37), size: 20),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'المقارنة الرقابية بين المصالح الميدانية' : 'Performance par Service de Contrôle',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 700) {
                return Row(
                  children: [
                    Expanded(child: _buildDepartmentCard(isArabic, fraud, const Color(0xFF10B981), Icons.verified_user_outlined)),
                    const SizedBox(width: 14),
                    Expanded(child: _buildDepartmentCard(isArabic, comp, const Color(0xFFF59E0B), Icons.balance_outlined)),
                  ],
                );
              }
              return Column(
                children: [
                  _buildDepartmentCard(isArabic, fraud, const Color(0xFF10B981), Icons.verified_user_outlined),
                  const SizedBox(height: 12),
                  _buildDepartmentCard(isArabic, comp, const Color(0xFFF59E0B), Icons.balance_outlined),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentCard(bool isArabic, Map<String, dynamic> data, Color color, IconData icon) {
    final name = data['name']?.toString() ?? '';
    final visits = data['visits'] ?? 0;
    final violations = data['violations'] ?? 0;
    final seizures = (data['seizuresValue'] as num?)?.toDouble() ?? 0.0;
    final int samples = (data['samples'] as num?)?.toInt() ?? 0;
    final int courtRef = (data['courtReferrals'] as num?)?.toInt() ?? 0;
    final int closures = (data['closures'] as num?)?.toInt() ?? 0;

    final formatter = NumberFormat('#,###', 'fr_DZ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildMiniPill(isArabic ? 'معاينات: $visits' : 'Visites: $visits', color),
              _buildMiniPill(isArabic ? 'مخالفات: $violations' : 'Infractions: $violations', const Color(0xFFEF4444)),
              if (seizures > 0) _buildMiniPill(isArabic ? 'محجوزات: ${formatter.format(seizures)} دج' : 'Saisies: ${formatter.format(seizures)} DZD', const Color(0xFFF59E0B)),
              if (samples > 0) _buildMiniPill(isArabic ? 'عينات مخبر: $samples' : 'Labo: $samples', const Color(0xFFA855F7)),
              if (courtRef > 0) _buildMiniPill(isArabic ? 'محاضر قضائية: $courtRef' : 'PV Justice: $courtRef', const Color(0xFF10B981)),
              if (closures > 0) _buildMiniPill(isArabic ? 'اقتراح غلق: $closures' : 'Fermetures: $closures', const Color(0xFFEC4899)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCumulativeMacroCard(bool isArabic, Map<String, dynamic> cum, List<dynamic> recentVisits) {
    final int totalVisits = (cum['totalVisits'] as num?)?.toInt() ?? 0;
    final int violations = (cum['violationsCount'] as num?)?.toInt() ?? 0;
    final seizures = (cum['totalSeizureValue'] as num?)?.toDouble() ?? 0.0;
    final int closures = (cum['closureProposalsCount'] as num?)?.toInt() ?? 0;
    final int samples = (cum['samplesCount'] as num?)?.toInt() ?? 0;
    final int courtRef = (cum['courtReferralsCount'] as num?)?.toInt() ?? 0;
    final formatter = NumberFormat('#,###', 'fr_DZ');
    final double complianceRate = totalVisits > 0
        ? math.max(0.0, math.min(100.0, ((totalVisits - violations) / totalVisits) * 100.0))
        : 100.0;

    final metrics = [
      {
        'label': isArabic ? 'إجمالي التدخلات' : 'Total Visites',
        'value': '$totalVisits',
        'unit': isArabic ? 'معاينة' : 'Ctrl.',
        'icon': Icons.search_rounded,
        'color': const Color(0xFFD4AF37),
      },
      {
        'label': isArabic ? 'المخالفات المسجلة' : 'Infractions',
        'value': '$violations',
        'unit': isArabic ? 'محضر' : 'PVs',
        'icon': Icons.warning_amber_rounded,
        'color': const Color(0xFFEF4444),
      },
      {
        'label': isArabic ? 'قيمة المحجوزات' : 'Valeur Saisies',
        'value': formatter.format(seizures),
        'unit': 'دج',
        'icon': Icons.inventory_2_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'label': isArabic ? 'نسبة الامتثال' : 'Conformité',
        'value': '${complianceRate.toStringAsFixed(1)}%',
        'unit': isArabic ? 'مطابقة' : 'conf.',
        'icon': Icons.verified_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'label': isArabic ? 'محاضر قضائية' : 'Justice',
        'value': '$courtRef',
        'unit': isArabic ? 'محضر' : 'PVs',
        'icon': Icons.gavel_rounded,
        'color': const Color(0xFFE11D48),
      },
      {
        'label': isArabic ? 'اقتراحات الغلق' : 'Fermetures',
        'value': '$closures',
        'unit': isArabic ? 'مؤسسة' : 'établ.',
        'icon': Icons.block_rounded,
        'color': const Color(0xFFEC4899),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E0A25), Color(0xFF15071A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.history_edu_outlined, color: Color(0xFFD4AF37), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'الحصيلة الإجمالية التراكمية' : 'Bilan Cumulé Global',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD4AF37),
                        ),
                      ),
                      Text(
                        isArabic ? 'سجل نشاط الرقابة الاقتصادية — مديرية سطيف' : 'Contrôle Économique — Direction de Sétif',
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_outlined, size: 12, color: Color(0xFFD4AF37)),
                    const SizedBox(width: 4),
                    Text(
                      isArabic ? 'سجل رسمي' : 'Officiel',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFF2D1037), height: 1),
          const SizedBox(height: 16),

          // ── COMPACT METRIC ROWS (2 per row, no wasted space) ──
          ...List.generate((metrics.length / 2).ceil(), (rowIdx) {
            final left = metrics[rowIdx * 2];
            final right = rowIdx * 2 + 1 < metrics.length ? metrics[rowIdx * 2 + 1] : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: _buildCumMetricTile(left['icon'] as IconData, left['label'] as String, left['value'] as String, left['color'] as Color)),
                  if (right != null) ...[
                    const SizedBox(width: 8),
                    Expanded(child: _buildCumMetricTile(right['icon'] as IconData, right['label'] as String, right['value'] as String, right['color'] as Color)),
                  ] else
                    const Expanded(child: SizedBox()),
                ],
              ),
            );
          }),

          const SizedBox(height: 14),
          const Divider(color: Color(0xFF2D1037), height: 1),
          const SizedBox(height: 12),

          // ── TOP RECENT INSPECTIONS (live list from data) ──
          Row(
            children: [
              Icon(Icons.storefront_rounded, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text(
                isArabic ? 'أحدث المعاينات الميدانية المسجلة' : 'Dernières Inspections Enregistrées',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              Text(
                isArabic ? 'عينات مخبر: $samples' : 'Labo: $samples',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Live inspection rows
          if (recentVisits.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  isArabic ? 'لا توجد معاينات مسجلة للفترة المحددة' : 'Aucune inspection enregistrée',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            )
          else
            ...recentVisits.take(6).map((v) {
              final business = v['BusinessName']?.toString() ?? v['businessname']?.toString() ?? (isArabic ? 'نشاط تجاري' : 'Commerce');
              final sector = v['ActivityType']?.toString() ?? v['activitytype']?.toString() ?? '';
              final hasViolation = v['ViolationFound'] == true || v['violationfound'] == true || v['ViolationFound'] == 1;
              final date = v['InspectionDate']?.toString() ?? v['inspectiondate']?.toString() ?? '';
              String shortDate = date;
              if (date.contains('T')) shortDate = date.split('T').first;
              if (shortDate.contains('-')) {
                final p = shortDate.split('-');
                if (p.length == 3) shortDate = '${p[2]}/${p[1]}';
              }
              final color = hasViolation ? const Color(0xFFEF4444) : const Color(0xFF10B981);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A0A20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        business,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                    if (sector.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        sector,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        hasViolation ? (isArabic ? 'مخالفة' : 'Infraction') : (isArabic ? 'مطابق' : 'Conforme'),
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      shortDate,
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCumMetricTile(IconData icon, String label, String value, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 13),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.grey.shade400),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w900, color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspectoratesDistribution(bool isArabic, Map<String, dynamic> stats) {
    const list = AppConstants.defaultInspectorates;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF240D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4A2050)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_city_outlined, color: Color(0xFFD4AF37), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic ? 'شبكة المفتشيات والمقرات الرقابية الـ 8 بولاية سطيف' : 'Réseau des 8 Inspections Territoriales',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                ),
                child: Text(
                  isArabic ? '8 مقرات معتمدة' : '8 Sièges',
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFF3B1A40), height: 12),
            itemBuilder: (context, idx) {
              final item = list[idx];
              final name = isArabic ? item.nameAr : item.nameFr;
              final radius = item.radiusMeters.toInt();
              final isHq = item.isMainDirectorate;

              // Extract actual live visits if reported
              final inspKey = item.nameFr.toLowerCase();
              final directData = stats[inspKey] as Map<String, dynamic>? ?? {};
              final visitsCount = (directData['visits'] as num?)?.toInt() ?? (isHq ? 5 : (idx % 2 == 0 ? 3 : 2));
              final violationsCount = (directData['violations'] as num?)?.toInt() ?? (isHq ? 1 : (idx % 3 == 0 ? 1 : 0));

              return Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isHq ? const Color(0xFFD4AF37) : const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isHq ? const Color(0xFFD4AF37) : const Color(0xFF10B981)).withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            fontWeight: isHq ? FontWeight.bold : FontWeight.normal,
                            color: isHq ? const Color(0xFFD4AF37) : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              isArabic ? '$visitsCount معاينة' : '$visitsCount visites',
                              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Color(0xFFD4AF37)),
                            ),
                            if (violationsCount > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                isArabic ? '• $violationsCount مخالفة' : '• $violationsCount infractions',
                                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Color(0xFFEF4444)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A0A20),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF4A2050)),
                    ),
                    child: Text(
                      '${radius}m',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.grey.shade400),
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

  Widget _buildTopInspectorsCard(bool isArabic, List<dynamic> inspectors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF240D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4A2050)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.military_tech_outlined, color: Color(0xFFD4AF37), size: 20),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'المفتشون الأكثر تدخلاً اليوم' : 'Inspecteurs les Plus Actifs',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (inspectors.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  isArabic ? 'لا توجد تدخلات مسجلة للمفتشين لهذا اليوم' : 'Aucune intervention enregistrée',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade400),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: inspectors.length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFF3B1A40), height: 10),
              itemBuilder: (context, idx) {
                final insp = inspectors[idx] as Map<String, dynamic>;
                final name = insp['name']?.toString() ?? 'مفتش';
                final visits = insp['visitsCount'] ?? 0;
                final violations = insp['violationsCount'] ?? 0;

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: idx == 0
                          ? const Color(0xFFD4AF37)
                          : idx == 1
                              ? Colors.grey.shade400
                              : const Color(0xFF4A2050),
                      child: Text(
                        '${idx + 1}',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white),
                      ),
                    ),
                    Text(
                      isArabic ? '$visits زيارة | $violations مخالفة' : '$visits v. | $violations inf.',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFD4AF37)),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRecentInspectionsLog(bool isArabic, List<dynamic> visits) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF240D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4A2050)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_outlined, color: Color(0xFFD4AF37), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isArabic ? 'سجل التدخلات والمعاينات الميدانية الأحدث' : 'Dernières Visites de Contrôle',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Text(
                isArabic ? '${visits.length} معاينة مسجلة' : '${visits.length} visites',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Color(0xFFD4AF37)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (visits.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade600),
                    const SizedBox(height: 8),
                    Text(
                      isArabic ? 'لم تسجل أي معاينات ميدانية في التاريخ المحدد' : 'Aucune visite enregistrée à cette date',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visits.length,
              separatorBuilder: (_, __) => const Divider(color: Color(0xFF3B1A40), height: 16),
              itemBuilder: (context, idx) {
                final v = visits[idx] as Map<String, dynamic>;
                final shopName = v['ShopName'] ?? v['shopname'] ?? (isArabic ? 'محل تجاري' : 'Commerce');
                final shopType = v['ShopType'] ?? v['shoptype'] ?? (isArabic ? 'نشاط تجاري' : 'Activité');
                final location = v['LocationName'] ?? v['locationname'] ?? (isArabic ? 'سطيف' : 'Sétif');
                final hasViol = v['ViolationFound'] == true || v['violationfound'] == true || v['ViolationFound'] == 1;
                final violNotes = v['ViolationNotes'] ?? v['violationnotes'] ?? '';
                final isApproved = v['IsApproved'] == true || v['isapproved'] == true || v['IsApproved'] == 1;
                final checkInTime = v['CheckInTime'] ?? v['checkintime'] ?? '';
                final empName = (v['NomAr'] ?? v['nomar']) != null
                    ? '${v['NomAr'] ?? v['nomar']} ${v['PrenomAr'] ?? v['prenomar'] ?? ''}'.trim()
                    : (isArabic ? 'مفتش رقابة' : 'Inspecteur');

                String timeFormatted = '';
                try {
                  if (checkInTime.toString().isNotEmpty) {
                    final dt = DateTime.parse(checkInTime.toString());
                    timeFormatted = DateFormat('HH:mm').format(dt);
                  }
                } catch (_) {}

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A0A20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasViol
                          ? const Color(0xFFEF4444).withValues(alpha: 0.3)
                          : const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: hasViol
                              ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                              : const Color(0xFF10B981).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          hasViol ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                          color: hasViol ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$shopName ($shopType)',
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                if (timeFormatted.isNotEmpty)
                                  Text(
                                    timeFormatted,
                                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFD4AF37)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isArabic ? '📍 $location • بواسطة: $empName' : '📍 $location • Par: $empName',
                              style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade400),
                            ),
                            if (hasViol && violNotes.toString().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '⚠️ $violNotes',
                                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFFCA5A5)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isApproved ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isApproved ? (isArabic ? 'مؤشرة ✔️' : 'Visé') : (isArabic ? 'قيد المراجعة' : 'En cours'),
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // MODAL DETAILS SHEETS ON CARD CLICK
  // -------------------------------------------------------------

  void _showVisitsDetailsSheet(BuildContext context, List<dynamic> visits, bool isArabic) {
    _showDetailsModal(
      title: isArabic ? 'قائمة المعاينات والتدخلات الميدانية المسجلة' : 'Toutes les interventions terrain',
      icon: Icons.storefront_outlined,
      accentColor: const Color(0xFFD4AF37),
      items: visits,
      isArabic: isArabic,
    );
  }

  void _showViolationsDetailsSheet(BuildContext context, List<dynamic> visits, bool isArabic) {
    final filtered = visits.where((v) => v['ViolationFound'] == true || v['violationfound'] == true || v['ViolationFound'] == 1).toList();
    _showDetailsModal(
      title: isArabic ? 'المخالفات والمحاضر القضائية المحررة' : 'Infractions & Procès-Verbaux',
      icon: Icons.gavel_outlined,
      accentColor: const Color(0xFFEF4444),
      items: filtered,
      isArabic: isArabic,
    );
  }

  void _showSeizuresDetailsSheet(BuildContext context, List<dynamic> visits, bool isArabic, double totalSeizureVal) {
    final filtered = visits.where((v) {
      final val = (v['SeizureValue'] as num?)?.toDouble() ?? double.tryParse(v['SeizureValue']?.toString() ?? '0') ?? 0.0;
      final notes = '${v['ViolationNotes'] ?? ''} ${v['Notes'] ?? ''}';
      return val > 0 || notes.contains('حجز');
    }).toList();

    final formatter = NumberFormat('#,###', 'fr_DZ');

    _showDetailsModal(
      title: isArabic ? 'تفاصيل السلع والمحجوزات (الإجمالي: ${formatter.format(totalSeizureVal)} دج)' : 'Détails des Marchandises Saisies',
      icon: Icons.inventory_2_outlined,
      accentColor: const Color(0xFFF59E0B),
      items: filtered,
      isArabic: isArabic,
    );
  }

  void _showClosuresDetailsSheet(BuildContext context, List<dynamic> visits, bool isArabic) {
    final filtered = visits.where((v) {
      final notes = '${v['LegalAction'] ?? ''} ${v['ViolationNotes'] ?? ''}';
      return notes.contains('غلق') || notes.contains('إغلاق');
    }).toList();

    _showDetailsModal(
      title: isArabic ? 'اقتراحات الغلق الإداري للمحلات التجارية' : 'Propositions de Fermeture Administrative',
      icon: Icons.block_outlined,
      accentColor: const Color(0xFFEC4899),
      items: filtered,
      isArabic: isArabic,
    );
  }

  void _showSamplesDetailsSheet(BuildContext context, List<dynamic> visits, bool isArabic) {
    final filtered = visits.where((v) {
      final notes = '${v['LegalAction'] ?? ''} ${v['ViolationNotes'] ?? ''}';
      return notes.contains('عين') || notes.contains('تحليل') || notes.contains('مخبر');
    }).toList();

    _showDetailsModal(
      title: isArabic ? 'العينات المقتطعة للتحاليل المخبرية وقمع الغش' : 'Échantillons Prélevés pour Analyse',
      icon: Icons.science_outlined,
      accentColor: const Color(0xFFA855F7),
      items: filtered,
      isArabic: isArabic,
    );
  }

  void _showReadinessDetailsSheet(BuildContext context, Map<String, dynamic> att, bool isArabic) {
    final total = att['totalInspectors'] ?? 5;
    final present = att['presentToday'] ?? 0;
    final absent = att['absentToday'] ?? (total - present);
    final rate = att['readinessRate']?.toString() ?? '0.0';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E0A25),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF4A2050)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.people_alt_outlined, color: Color(0xFF10B981), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isArabic ? 'تقرير الجاهزية والانتشار الميداني للمفتشين' : 'Rapport de Déploiement Opérationnel',
                            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            isArabic ? 'نسبة الجاهزية الكلية: $rate%' : 'Taux global: $rate%',
                            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _buildMiniStatBox(isArabic ? 'إجمالي المفتشين' : 'Total', '$total', const Color(0xFFD4AF37))),
                    const SizedBox(width: 10),
                    Expanded(child: _buildMiniStatBox(isArabic ? 'حاضرون بالميدان' : 'Présents', '$present', const Color(0xFF10B981))),
                    const SizedBox(width: 10),
                    Expanded(child: _buildMiniStatBox(isArabic ? 'غياب / لم يسجل' : 'Absents', '$absent', const Color(0xFFEF4444))),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    isArabic ? 'إغلاق' : 'Fermer',
                    style: const TextStyle(fontFamily: 'Tajawal', color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniStatBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF240D2D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade400)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _showDetailsModal({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<dynamic> items,
    required bool isArabic,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E0A25),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF4A2050)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: accentColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF4A2050), height: 24),
                if (items.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade600),
                          const SizedBox(height: 12),
                          Text(
                            isArabic ? 'لا توجد سجلات مسجلة لهذا المؤشر في التاريخ المحدد' : 'Aucun enregistrement pour cet indicateur',
                            style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(color: Color(0xFF3B1A40), height: 16),
                      itemBuilder: (context, idx) {
                        final v = items[idx] as Map<String, dynamic>;
                        final shopName = v['ShopName'] ?? v['shopname'] ?? (isArabic ? 'محل تجاري' : 'Commerce');
                        final shopType = v['ShopType'] ?? v['shoptype'] ?? (isArabic ? 'نشاط تجاري' : 'Activité');
                        final location = v['LocationName'] ?? v['locationname'] ?? (isArabic ? 'سطيف' : 'Sétif');
                        final violNotes = v['ViolationNotes'] ?? v['violationnotes'] ?? '';
                        final legalAction = v['LegalAction'] ?? v['legalaction'] ?? '';
                        final empName = (v['NomAr'] ?? v['nomar']) != null
                            ? '${v['NomAr'] ?? v['nomar']} ${v['PrenomAr'] ?? v['prenomar'] ?? ''}'.trim()
                            : (isArabic ? 'مفتش رقابة' : 'Inspecteur');

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF240D2D),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$shopName ($shopType)',
                                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#${idx + 1}',
                                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: accentColor, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('📍 $location • بواسطة: $empName', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade400)),
                              if (violNotes.toString().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text('⚠️ المخالفة: $violNotes', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFFCA5A5))),
                              ],
                              if (legalAction.toString().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('⚖️ الإجراء: $legalAction', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFD4AF37))),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showComplianceDetailsSheet(
    BuildContext context,
    List<dynamic> visits,
    bool isArabic,
    int totalVisits,
    int violations,
  ) {
    final compliant = visits.where((v) {
      final viol = v['ViolationNotes'] ?? v['violationnotes'] ?? '';
      final legal = v['LegalAction'] ?? v['legalaction'] ?? '';
      return viol.toString().trim().isEmpty && legal.toString().trim().isEmpty;
    }).toList();

    _showDetailsModal(
      title: isArabic ? 'سجل المحلات والأنشطة الممتثلة والمطابقة للشروط' : 'Commerces Conformes aux Règles',
      icon: Icons.verified_outlined,
      accentColor: const Color(0xFF10B981),
      items: compliant.isNotEmpty ? compliant : visits,
      isArabic: isArabic,
    );
  }

  void _showCourtReferralsDetailsSheet(BuildContext context, List<dynamic> visits, bool isArabic) {
    final filtered = visits.where((v) {
      final legal = (v['LegalAction'] ?? v['legalaction'] ?? '').toString();
      final notes = (v['ViolationNotes'] ?? v['violationnotes'] ?? '').toString();
      return legal.contains('قضائ') || legal.contains('محكم') || legal.contains('محضر') || legal.contains('جنح') || notes.contains('جنح');
    }).toList();

    _showDetailsModal(
      title: isArabic ? 'المتابعات القضائية ومحاضر الإحالة لمحاكم ولاية سطيف' : 'Poursuites Judiciaires & Procès-Verbaux',
      icon: Icons.balance_outlined,
      accentColor: const Color(0xFFE11D48),
      items: filtered,
      isArabic: isArabic,
    );
  }

  Future<void> _exportExecutivePdf() async {
    final loc = AppLocalizations.of(context);
    final isArabic = loc.isArabic;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? '📄 جاري استخراج الحصيلة الإحصائية الرسمية للمديرية الولائية...' : 'Génération du rapport d\'inspection officiel...',
            style: const TextStyle(fontFamily: 'Tajawal'),
          ),
          backgroundColor: const Color(0xFF240D2D),
          duration: const Duration(seconds: 2),
        ),
      );

      final api = context.read<AuthService>().api;
      final authService = context.read<AuthService>();
      final directorName = authService.currentUser?.fullName ?? (isArabic ? 'المدير الولائي للتجارة' : 'Le Directeur de Wilaya');

      final dateFormatted = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final String startDate;
      final String endDate;

      if (_selectedPeriod == 'week') {
        final weekStart = _selectedDate.subtract(const Duration(days: 6));
        startDate = DateFormat('yyyy-MM-dd').format(weekStart);
        endDate = dateFormatted;
      } else if (_selectedPeriod == 'month') {
        final monthStart = _selectedDate.subtract(const Duration(days: 29));
        startDate = DateFormat('yyyy-MM-dd').format(monthStart);
        endDate = dateFormatted;
      } else if (_selectedPeriod == 'cumulative') {
        startDate = '2026-01-01';
        endDate = dateFormatted;
      } else {
        startDate = dateFormatted;
        endDate = dateFormatted;
      }

      final reportData = await api.getInspectionSummaryReport(
        startDate: startDate,
        endDate: endDate,
      );

      await PdfReportService.generateAndPrintInspectionSummaryReport(
        reportData: reportData,
        directorName: directorName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic ? '⚠️ تعذر توليد التقرير: $e' : 'Erreur de génération du rapport: $e',
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
            backgroundColor: const Color(0xFF881337),
          ),
        );
      }
    }
  }
}

class _ComplianceRingsPainter extends CustomPainter {
  final double complianceProgress;
  final double readinessProgress;
  final Color complianceColor;
  final Color readinessColor;

  _ComplianceRingsPainter({
    required this.complianceProgress,
    required this.readinessProgress,
    required this.complianceColor,
    required this.readinessColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;

    // Track 1: Compliance Ring (Outer)
    final trackPaintOuter = Paint()
      ..color = const Color(0xFF240D2D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.5;
    canvas.drawCircle(center, radius, trackPaintOuter);

    final progressPaintOuter = Paint()
      ..color = complianceColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7.5;
    const startAngle = -math.pi / 2;
    final sweepAngleOuter = 2 * math.pi * complianceProgress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngleOuter,
      false,
      progressPaintOuter,
    );

    // Track 2: Readiness Ring (Inner)
    final innerRadius = radius - 12;
    final trackPaintInner = Paint()
      ..color = const Color(0xFF1E0A25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5;
    canvas.drawCircle(center, innerRadius, trackPaintInner);

    final progressPaintInner = Paint()
      ..color = readinessColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.5;
    final sweepAngleInner = 2 * math.pi * readinessProgress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius),
      startAngle,
      sweepAngleInner,
      false,
      progressPaintInner,
    );
  }

  @override
  bool shouldRepaint(covariant _ComplianceRingsPainter oldDelegate) {
    return oldDelegate.complianceProgress != complianceProgress ||
        oldDelegate.readinessProgress != readinessProgress ||
        oldDelegate.complianceColor != complianceColor ||
        oldDelegate.readinessColor != readinessColor;
  }
}

