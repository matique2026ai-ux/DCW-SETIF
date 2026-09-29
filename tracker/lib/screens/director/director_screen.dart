import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drh_setif_tracker/services/auth_service.dart';
import 'package:drh_setif_tracker/utils/theme.dart';
import 'package:drh_setif_tracker/utils/app_localizations.dart';
import 'package:drh_setif_tracker/screens/auth/login_screen.dart';
import 'package:drh_setif_tracker/screens/director/director_map_tab.dart';
import 'package:drh_setif_tracker/screens/director/director_analytics_tab.dart';
import 'package:drh_setif_tracker/screens/director/director_reports_tab.dart';
import 'package:drh_setif_tracker/screens/director/director_deductions_tab.dart';
import 'package:drh_setif_tracker/screens/common/change_password_dialog.dart';
import 'package:drh_setif_tracker/screens/common/change_master_pin_dialog.dart';
import 'package:drh_setif_tracker/screens/common/mandatory_security_setup_dialog.dart';
import 'package:drh_setif_tracker/widgets/modern_executive_navbar.dart';


import 'package:drh_setif_tracker/screens/common/app_footer.dart';

class DirectorScreen extends StatefulWidget {
  const DirectorScreen({super.key});

  @override
  State<DirectorScreen> createState() => _DirectorScreenState();
}

class _DirectorScreenState extends State<DirectorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _pollTimer;
  int _pendingDecisionsCount = 0;
  int _activeSentInquiriesCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadInquiriesSummary();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInquiriesSummary();
      final auth = context.read<AuthService>();
      if (auth.currentUser?.mustChangeCredentials == true) {
        MandatorySecuritySetupDialog.show(context);
      }
    });
  }

  Future<void> _loadInquiriesSummary() async {
    try {
      final api = context.read<AuthService>().api;
      final inqs = await api.getInquiries();
      final answered = inqs.where((i) => ((i['Status'] ?? i['status'])?.toString().toLowerCase()) == 'answered').length;
      final sent = inqs.where((i) => ((i['Status'] ?? i['status'])?.toString().toLowerCase()) == 'sent').length;
      List<Map<String, dynamic>> justs = [];
      try {
        justs = await api.getJustifications(status: 'pending');
      } catch (_) {}
      if (mounted) {
        setState(() {
          _pendingDecisionsCount = answered + justs.length;
          _activeSentInquiriesCount = sent;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    final int? badgeNum = _pendingDecisionsCount > 0
        ? _pendingDecisionsCount
        : (_activeSentInquiriesCount > 0 ? _activeSentInquiriesCount : null);
    final bool hasUrgentDecision = _pendingDecisionsCount > 0;

    return Directionality(
      textDirection: loc.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.BackgroundColor,
        appBar: ModernExecutiveNavbar(
          title: loc.roleDirector,
          badgeText: loc.isArabic ? 'الآمر بالصرف' : 'Ordonnateur',
          subtitle: loc.isArabic ? 'مديرية التجارة — ولاية سطيف' : 'Direction du Commerce — Wilaya de Sétif',
          selectedIndex: _tabController.index,
          onRefresh: _loadInquiriesSummary,
          onTabSelected: (idx) {
            _tabController.animateTo(idx);
            setState(() {});
            _loadInquiriesSummary();
          },
          tabs: [
            ModernNavTabItem(
              icon: Icons.map_outlined,
              label: loc.navMap,
            ),
            ModernNavTabItem(
              icon: Icons.analytics_outlined,
              label: loc.isArabic ? 'الإحصائيات الرقابية' : 'Statistiques de Contrôle',
            ),
            ModernNavTabItem(
              icon: Icons.assessment_outlined,
              label: loc.navReports,
            ),
            ModernNavTabItem(
              icon: Icons.gavel_outlined,
              label: loc.isArabic ? 'الانضباط والاستفسارات' : 'Discipline & Explications',
              badgeCount: badgeNum,
              isAlert: hasUrgentDecision,
              badgeColor: hasUrgentDecision ? const Color(0xFFEF4444) : const Color(0xFFD97706),
            ),
          ],
          onPasswordChange: () => ChangePasswordDialog.show(context),
          onMasterPinChange: () => ChangeMasterPinDialog.show(context),
          onLogout: _showLogoutDialog,
        ),
        body: Column(
          children: [
            if (hasUrgentDecision && _tabController.index != 3)
              Material(
                color: const Color(0xFF991B1B),
                child: InkWell(
                  onTap: () {
                    _tabController.animateTo(3);
                    setState(() {});
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            loc.isArabic
                                ? '⚠️ تنبيه سيادي: يوجد ($_pendingDecisionsCount) رد على استفسار كتابي بانتظار قراركم الإداري'
                                : '⚠️ Alerte : ($_pendingDecisionsCount) réponse(s) d\'explications en attente de votre décision',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            loc.isArabic ? 'البت فيها الآن ❯' : 'Traiter maintenant ❯',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  DirectorMapTab(),
                  DirectorAnalyticsTab(),
                  DirectorReportsTab(),
                  DirectorDeductionsTab(),
                ],
              ),
            ),
            const AppFooter(),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.CardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          loc.logout,
          style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
        ),
        content: Text(
          loc.logoutConfirm,
          style: const TextStyle(fontFamily: 'Tajawal'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.cancel, style: const TextStyle(fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AuthService>().logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.DangerColor,
            ),
            child: Text(loc.logout, style: const TextStyle(fontFamily: 'Tajawal')),
          ),
        ],
      ),
    );
  }
}
