import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drh_setif_tracker/services/auth_service.dart';
import 'package:drh_setif_tracker/utils/theme.dart';
import 'package:drh_setif_tracker/providers/language_provider.dart';
import 'package:drh_setif_tracker/screens/auth/login_screen.dart';
import 'package:drh_setif_tracker/screens/common/change_password_dialog.dart';
import 'package:drh_setif_tracker/screens/common/change_master_pin_dialog.dart';
import 'package:drh_setif_tracker/screens/common/mandatory_security_setup_dialog.dart';
import 'package:drh_setif_tracker/screens/common/app_footer.dart';
import 'package:drh_setif_tracker/widgets/modern_executive_navbar.dart';
import 'package:drh_setif_tracker/utils/constants.dart';
import 'package:drh_setif_tracker/screens/head/market_regulation_view.dart';
import 'package:drh_setif_tracker/screens/head/contentieux_view.dart';

class HeadScreen extends StatefulWidget {
  final String? initialDepartment;
  const HeadScreen({super.key, this.initialDepartment});

  @override
  State<HeadScreen> createState() => _HeadScreenState();
}

class _HeadScreenState extends State<HeadScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _pollTimer;
  bool _isLoading = true;

  // Department State
  String _departmentName = '';
  List<Map<String, dynamic>> _programs = [];
  List<Map<String, dynamic>> _todayVisits = [];
  List<Map<String, dynamic>> _departmentInspectors = [];
  List<Map<String, dynamic>> _allAvailableEmployees = [];
  String _inspectorSearchQuery = '';
  String _selectedBrigadeFilter = 'الكل';
  String _visitsFilter = 'all'; // 'all', 'pending', 'approved', 'violations'
  String _visitsSearchQuery = '';

  // Administration & Means Specific State
  List<Map<String, dynamic>> _allEmployees = [];
  List<Map<String, dynamic>> _deductions = [];
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _equipments = [];
  int _meansSubTab = 0; // 0: vehicles, 1: equipments, 2: hqs
  String _adminPersonnelSearch = '';
  String _adminServiceFilter = 'الكل';

  bool get _isAdministration =>
      _departmentName.contains('الإدارة') ||
      _departmentName.contains('الوسائل') ||
      context.read<AuthService>().currentUser?.username == 'chef_administration';

  bool get _isMarketRegulation =>
      _departmentName.contains('ملاحظة') ||
      _departmentName.contains('السوق') ||
      _departmentName.contains('التموين') ||
      context.read<AuthService>().currentUser?.username == 'chef_marche';

  bool get _isContentieux =>
      _departmentName.contains('المنازعات') ||
      _departmentName.contains('القانون') ||
      context.read<AuthService>().currentUser?.username == 'chef_contentieux';

  @override
  void initState() {
    super.initState();
    if (widget.initialDepartment != null && widget.initialDepartment!.isNotEmpty) {
      _departmentName = widget.initialDepartment!;
    }
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadAllData();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadAllData(silent: true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      if (auth.currentUser?.mustChangeCredentials == true) {
        MandatorySecuritySetupDialog.show(context);
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthService>();
      final user = auth.currentUser;
      final api = auth.api;

      // Determine Department Name from user role or service or widget
      if (_departmentName.isEmpty) {
        if (widget.initialDepartment != null && widget.initialDepartment!.isNotEmpty) {
          _departmentName = widget.initialDepartment!;
        } else if (user?.serviceName != null && user!.serviceName!.isNotEmpty) {
          _departmentName = user.serviceName!;
        } else if (user?.username == 'chef_administration') {
          _departmentName = 'مصلحة الإدارة والوسائل';
        } else if (user?.username == 'chef_concurrence') {
          _departmentName = 'مصلحة المنافسة والتحقيقات الاقتصادية';
        } else if (user?.username == 'chef_marche') {
          _departmentName = 'مصلحة ملاحظة السوق وضبط التموين';
        } else if (user?.username == 'chef_contentieux') {
          _departmentName = 'مصلحة المنازعات والشؤون القانونية';
        } else {
          _departmentName = 'مصلحة حماية المستهلك وقمع الغش';
        }
      }

      final mapData = await api.getMapData();
      final mapLookup = {for (var m in mapData) (m['employeeId'] ?? m['id']): m};

      if (_isAdministration) {
        // Load comprehensive directorate data
        final allEmps = await api.getEmployees();
        List<Map<String, dynamic>> deds = [];
        try {
          deds = await api.getDeductions();
        } catch (_) {}

        List<Map<String, dynamic>> veList = [];
        try {
          veList = await api.getVehicles();
        } catch (_) {}

        List<Map<String, dynamic>> eqList = [];
        try {
          eqList = await api.getEquipments();
        } catch (_) {}

        final List<Map<String, dynamic>> fullList = [];
        for (final emp in allEmps) {
          final id = int.tryParse('${emp['Id'] ?? emp['id'] ?? 0}') ?? 0;
          final liveInfo = mapLookup[id];
          final fullName = '${emp['NomAr'] ?? emp['Nom'] ?? ''} ${emp['PrenomAr'] ?? emp['Prenom'] ?? ''}'.trim();

          fullList.add({
            'id': id,
            'matricule': (emp['NumeroMatricule'] ?? 'MAT-${1000 + id}').toString(),
            'name': fullName.isNotEmpty ? fullName : 'موظف #$id',
            'grade': (emp['Grade'] ?? emp['FonctionExercee'] ?? 'مفتش رئيسي').toString(),
            'service': (emp['Service'] ?? 'المصالح العامة').toString(),
            'brigade': (emp['BrigadeName'] ?? 'بدون تعيين').toString(),
            'isBrigadeLeader': emp['IsBrigadeLeader'] == true || emp['IsBrigadeLeader'] == 1,
            'administrativeStatus': (emp['AdministrativeStatus'] ?? 'active').toString(),
            'hasCheckedIn': liveInfo != null ? (liveInfo['hasCheckedIn'] == true) : false,
            'isCheckedOut': liveInfo != null ? (liveInfo['isCheckedOut'] == true) : false,
            'visitsCount': liveInfo != null ? ((liveInfo['visitsCount'] as num?)?.toInt() ?? 0) : 0,
            'location': (liveInfo?['location'] ?? 'المقر الرئيسي للمديرية').toString(),
            'checkInTime': liveInfo?['checkInTime'],
            'lateMinutes': liveInfo?['lateMinutes'] ?? 0,
          });
        }

        if (mounted) {
          setState(() {
            _allEmployees = fullList;
            _deductions = deds;
            _vehicles = veList;
            _equipments = eqList;
            _isLoading = false;
          });
        }
      } else {
        // Commercial & Fraud Services
        final progs = await api.getPrograms(service: _departmentName);
        final visits = await api.getTodayVisits();
        final deptEmployees = await api.getEmployees(department: _departmentName);
        List<Map<String, dynamic>> allEmps = [];
        try {
          allEmps = await api.getEmployees(all: true);
        } catch (_) {}

        final List<Map<String, dynamic>> deptList = [];
        for (final emp in deptEmployees) {
          final id = int.tryParse('${emp['Id'] ?? emp['id'] ?? 0}') ?? 0;
          final liveInfo = mapLookup[id];
          final fullName = '${emp['NomAr'] ?? emp['Nom'] ?? ''} ${emp['PrenomAr'] ?? emp['Prenom'] ?? ''}'.trim();
          final nomLower = fullName.toLowerCase();
          final mat = (emp['NumeroMatricule'] ?? '').toString().toLowerCase();
          if (nomLower.contains('admin') || mat.contains('admin') || nomLower.contains('مدير النظام')) continue;

          deptList.add({
            'id': id,
            'name': fullName.isNotEmpty ? fullName : 'مفتش #$id',
            'grade': (emp['Grade'] ?? emp['FonctionExercee'] ?? 'مفتش رئيسي للرقابة').toString(),
            'service': (emp['Service'] ?? _departmentName).toString(),
            'brigade': (emp['BrigadeName'] ?? 'فرقة الرقابة والتفتيش 01').toString(),
            'isBrigadeLeader': emp['IsBrigadeLeader'] == true || emp['IsBrigadeLeader'] == 1,
            'administrativeStatus': (emp['AdministrativeStatus'] ?? 'active').toString(),
            'hasCheckedIn': liveInfo != null ? (liveInfo['hasCheckedIn'] == true) : false,
            'isCheckedOut': liveInfo != null ? (liveInfo['isCheckedOut'] == true) : false,
            'visitsCount': liveInfo != null ? ((liveInfo['visitsCount'] as num?)?.toInt() ?? 0) : 0,
            'location': (liveInfo?['location'] ?? 'المقر الرئيسي للمديرية').toString(),
            'checkInTime': liveInfo?['checkInTime'],
          });
        }

        if (mounted) {
          setState(() {
            _programs = progs;
            _todayVisits = visits.where((v) {
              final s = v['Service']?.toString() ?? '';
              return s.isEmpty || s.contains(_departmentName) || _departmentName.contains(s);
            }).toList();
            _departmentInspectors = deptList;
            _allAvailableEmployees = allEmps;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // ADMINISTRATION SPECIFIC TABS & DIALOGS
  // ==========================================

  Widget _buildAdministrationPersonnelTab() {
    final isAr = context.watch<LanguageProvider>().isArabic;
    final totalCount = _allEmployees.length;
    final presentCount = _allEmployees.where((e) => e['hasCheckedIn'] == true).length;
    final outCount = _allEmployees.where((e) => e['isCheckedOut'] == true).length;
    final leaveCount = _allEmployees.where((e) => e['administrativeStatus'] == 'leave' || e['administrativeStatus'] == 'mission').length;
    final lateCount = _allEmployees.where((e) => (e['lateMinutes'] as num? ?? 0) > 0).length;

    final servicesList = [
      'الكل',
      'مصلحة حماية المستهلك وقمع الغش',
      'مصلحة المنافسة والتحقيقات الاقتصادية',
      'مصلحة الإدارة والوسائل',
      'مكتب المستخدمين',
      'المفتشية الإقليمية بالعلمة',
      'المفتشية الإقليمية بعين ولمان',
      'المفتشية الإقليمية ببوقاعة',
      'المفتشية الحدودية بمطار 8 ماي',
    ];

    final filtered = _allEmployees.where((emp) {
      final name = (emp['name'] ?? '').toString().toLowerCase();
      final grade = (emp['grade'] ?? '').toString().toLowerCase();
      final matricule = (emp['matricule'] ?? '').toString().toLowerCase();
      final service = (emp['service'] ?? '').toString();

      final matchesQuery = _adminPersonnelSearch.isEmpty ||
          name.contains(_adminPersonnelSearch.toLowerCase()) ||
          grade.contains(_adminPersonnelSearch.toLowerCase()) ||
          matricule.contains(_adminPersonnelSearch.toLowerCase());

      final matchesService = _adminServiceFilter == 'الكل' || service.contains(_adminServiceFilter);

      return matchesQuery && matchesService;
    }).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stat Counters Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E0B26),
              border: Border(bottom: BorderSide(color: Color(0xFF4A2050), width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt, color: Color(0xFFD4AF37), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isAr ? 'مكتب المستخدمين — متابعة تعداد موظفي المديرية' : 'Bureau du Personnel — Effectif de la Direction',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD4AF37), width: 0.5),
                      ),
                      child: Text(
                        isAr ? 'تعداد: $totalCount موظف' : 'Total: $totalCount agents',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFD4AF37)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildAdminStatCard(
                      title: isAr ? 'حاضرون بالبصمة' : 'Présents (GPS)',
                      value: '$presentCount',
                      icon: Icons.check_circle,
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    _buildAdminStatCard(
                      title: isAr ? 'سجلوا الانصراف' : 'Départs',
                      value: '$outCount',
                      icon: Icons.logout,
                      color: const Color(0xFF6B7280),
                    ),
                    const SizedBox(width: 8),
                    _buildAdminStatCard(
                      title: isAr ? 'عطل / إجازات' : 'Congés / Justifiés',
                      value: '$leaveCount',
                      icon: Icons.event_available,
                      color: const Color(0xFFD4AF37),
                    ),
                    const SizedBox(width: 8),
                    _buildAdminStatCard(
                      title: isAr ? 'تأخرات مسجلة' : 'Retards',
                      value: '$lateCount',
                      icon: Icons.access_time,
                      color: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search & Filter Toolbar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _adminPersonnelSearch = v),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: isAr ? 'بحث بالاسم، الرتبة أو رقم القيد...' : 'Recherche par nom, grade ou matricule...',
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFFD4AF37)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFF1E0B26),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF4A2050))),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Service Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: servicesList.map((srv) {
                final isSelected = _adminServiceFilter == srv;
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: FilterChip(
                    label: Text(srv, style: TextStyle(fontSize: 11, color: isSelected ? Colors.black : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected,
                    selectedColor: const Color(0xFFD4AF37),
                    backgroundColor: const Color(0xFF1E0B26),
                    checkmarkColor: Colors.black,
                    onSelected: (val) {
                      setState(() => _adminServiceFilter = val ? srv : 'الكل');
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Employees List
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: Text(
                isAr ? 'لا توجد نتائج مطابقة لبحث المستخدمين' : 'Aucun employé trouvé',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final emp = filtered[i];
                final isPresent = emp['hasCheckedIn'] == true;
                final isOut = emp['isCheckedOut'] == true;
                final lateMin = (emp['lateMinutes'] as num? ?? 0).toInt();

                final empName = (emp['name'] ?? '').toString();
                final empMatricule = (emp['matricule'] ?? '').toString();
                final empGrade = (emp['grade'] ?? '').toString();
                final empService = (emp['service'] ?? '').toString();
                final empLocation = (emp['location'] ?? 'المقر الرئيسي للمديرية').toString();

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF240D2D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPresent ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFF4A2050),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isPresent ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFF4A2050).withValues(alpha: 0.4),
                          border: Border.all(color: isPresent ? const Color(0xFF10B981) : Colors.white24, width: 1),
                        ),
                        child: Icon(
                          isPresent ? Icons.person_pin_circle : Icons.person_outline,
                          color: isPresent ? const Color(0xFF10B981) : Colors.white60,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  empName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    empMatricule,
                                    style: const TextStyle(fontSize: 9.5, color: Color(0xFFD4AF37)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$empGrade • $empService',
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 12, color: isPresent ? const Color(0xFF10B981) : Colors.white38),
                                const SizedBox(width: 3),
                                Text(
                                  empLocation,
                                  style: TextStyle(fontSize: 10, color: isPresent ? const Color(0xFF10B981) : Colors.white38),
                                ),
                                if (lateMin > 0) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFF59E0B), width: 0.5),
                                    ),
                                    child: Text(
                                      'تأخر: $lateMin د',
                                      style: const TextStyle(fontSize: 9.5, color: Color(0xFFF59E0B), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOut
                              ? Colors.white10
                              : (isPresent ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFEF4444).withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isOut ? Colors.white24 : (isPresent ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          isOut ? 'انصرف' : (isPresent ? 'حاضر' : 'غير ملتحق'),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isOut ? Colors.white60 : (isPresent ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 20),
          const AppFooter(showDivider: false),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildAdminStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF240D2D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9.5, color: Colors.white70),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdministrationMeansTab() {
    final isAr = context.watch<LanguageProvider>().isArabic;
    const officialHQs = AppConstants.defaultInspectorates;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sub-tabs navigation header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E0B26),
              border: Border(bottom: BorderSide(color: Color(0xFF4A2050), width: 1)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.directions_car, size: 16),
                    label: Text(
                      isAr ? 'حظيرة السيارات والوقود (${_vehicles.length})' : 'Parc Auto (${_vehicles.length})',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    selected: _meansSubTab == 0,
                    selectedColor: const Color(0xFFD4AF37),
                    backgroundColor: const Color(0xFF2D1035),
                    onSelected: (sel) {
                      if (sel) setState(() => _meansSubTab = 0);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.medical_services, size: 16),
                    label: Text(
                      isAr ? 'حقائب وأجهزة التفتيش (${_equipments.length})' : 'Mallettes & Équipements (${_equipments.length})',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    selected: _meansSubTab == 1,
                    selectedColor: const Color(0xFFD4AF37),
                    backgroundColor: const Color(0xFF2D1035),
                    onSelected: (sel) {
                      if (sel) setState(() => _meansSubTab = 1);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.apartment, size: 16),
                    label: Text(
                      isAr ? 'المقرات والبصمة الجغرافية (8)' : '8 Sièges & Geofence',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    selected: _meansSubTab == 2,
                    selectedColor: const Color(0xFFD4AF37),
                    backgroundColor: const Color(0xFF2D1035),
                    onSelected: (sel) {
                      if (sel) setState(() => _meansSubTab = 2);
                    },
                  ),
                ],
              ),
            ),
          ),

          if (_meansSubTab == 0) ...[
            _buildVehiclesSubTab(isAr),
          ] else if (_meansSubTab == 1) ...[
            _buildEquipmentsSubTab(isAr),
          ] else ...[
            _buildHQsSubTab(isAr, officialHQs),
          ],

          const SizedBox(height: 20),
          const AppFooter(showDivider: false),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildVehiclesSubTab(bool isAr) {
    final onMissionCount = _vehicles.where((v) => (v['Status'] ?? v['status']) == 'en_mission').length;
    final availableCount = _vehicles.where((v) => (v['Status'] ?? v['status']) == 'disponible').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF2D1035), Color(0xFF1E0B26)]),
            border: Border(bottom: BorderSide(color: Color(0xFFD4AF37), width: 1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping, color: Color(0xFFD4AF37), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAr ? 'حظيرة سيارات المديرية ومتابعة الوقود الحية' : 'Parc Automobile & Suivi Carburant',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAr
                            ? 'إصدار أوامر التنقل الرسمية • جرد عداد الكيلومترات ومستويات الوقود'
                            : 'Ordres de mission officiels • Kilométrage et jauges de carburant',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFD4AF37)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildAdminStatCard(
                    title: isAr ? 'إجمالي الأسطول' : 'Total Flotte',
                    value: '${_vehicles.length}',
                    icon: Icons.directions_car,
                    color: const Color(0xFFD4AF37),
                  ),
                  const SizedBox(width: 8),
                  _buildAdminStatCard(
                    title: isAr ? 'في مهمات ميدانية' : 'En Mission',
                    value: '$onMissionCount',
                    icon: Icons.alt_route,
                    color: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 8),
                  _buildAdminStatCard(
                    title: isAr ? 'جاهزة بالمقر' : 'Disponibles',
                    value: '$availableCount',
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF10B981),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Vehicles List
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            isAr ? 'بيانات المركبات وأوامر التنقل المفتوحة' : 'Véhicules & Ordres de Mission Ouverts',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
          ),
        ),

        if (_vehicles.isEmpty)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF240D2D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4A2050)),
            ),
            alignment: Alignment.center,
            child: Text(
              isAr ? 'جاري تحميل بيانات حظيرة السيارات من الخادم...' : 'Chargement des véhicules...',
              style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white70),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _vehicles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final v = _vehicles[i];
              final status = (v['Status'] ?? v['status'] ?? 'disponible').toString();
              final isEnMission = status == 'en_mission';
              final matricule = (v['Matricule'] ?? v['matricule'] ?? '').toString();
              final brand = (v['Brand'] ?? v['brand'] ?? '').toString();
              final model = (v['Model'] ?? v['model'] ?? '').toString();
              final km = (v['Kilometrage'] ?? v['kilometrage'] ?? 0).toString();
              final fuel = (v['FuelLevel'] ?? v['fuelLevel'] ?? 50) as num;
              final driver = (v['CurrentDriver'] ?? v['currentDriver'] ?? '').toString();
              final missionDest = (v['MissionDestination'] ?? v['missionDestination'] ?? '').toString();
              final missionPurpose = (v['MissionPurpose'] ?? v['missionPurpose'] ?? '').toString();

              Color fuelColor = const Color(0xFF10B981);
              if (fuel < 25) {
                fuelColor = const Color(0xFFEF4444);
              } else if (fuel < 50) {
                fuelColor = const Color(0xFFF59E0B);
              }

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF240D2D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isEnMission ? const Color(0xFFF59E0B) : const Color(0xFF4A2050),
                    width: isEnMission ? 1.2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFD4AF37), width: 0.8),
                          ),
                          child: Text(
                            matricule,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFD4AF37)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$brand $model',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isEnMission ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isEnMission ? const Color(0xFFF59E0B) : const Color(0xFF10B981), width: 0.5),
                          ),
                          child: Text(
                            isEnMission ? (isAr ? 'في مهمة تفتيشية' : 'En Mission') : (isAr ? 'جاهزة للاستعمال' : 'Disponible'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isEnMission ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.speed, size: 14, color: Colors.white60),
                        const SizedBox(width: 4),
                        Text('$km كم', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                        const SizedBox(width: 16),
                        const Icon(Icons.local_gas_station, size: 14, color: Colors.white60),
                        const SizedBox(width: 4),
                        Text('$fuel% وقود', style: TextStyle(fontSize: 11, color: fuelColor, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (fuel / 100.0).clamp(0.0, 1.0),
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation<Color>(fuelColor),
                              minHeight: 6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isEnMission && driver.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(
                          isAr
                            ? '📋 أمر تنقل جاري • السائق المكلف: $driver • الوجهة: $missionDest ${missionPurpose.isNotEmpty ? "($missionPurpose)" : ""}'
                            : '📋 Mission en cours • Chauffeur: $driver • Dest: $missionDest',
                          style: const TextStyle(fontSize: 10.5, color: Colors.white70),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!isEnMission)
                          ElevatedButton.icon(
                            onPressed: () => _showNewVehicleMissionDialog(v),
                            icon: const Icon(Icons.assignment_outlined, size: 14),
                            label: Text(isAr ? 'إصدار أمر تنقل' : 'Ordre de Mission', style: const TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () => _showCloseVehicleMissionDialog(v),
                            icon: const Icon(Icons.assignment_turned_in_outlined, size: 14),
                            label: Text(isAr ? 'إنهاء أمر التنقل واسترجاع' : 'Clôturer la Mission', style: const TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildEquipmentsSubTab(bool isAr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF2D1035), Color(0xFF1E0B26)]),
            border: Border(bottom: BorderSide(color: Color(0xFFD4AF37), width: 1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.medical_services, color: Color(0xFFD4AF37), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'جرد حقائب وأجهزة الرقابة وقمع الغش' : 'Inventaire du Matériel & Mallettes',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAr
                        ? 'متابعة الأجهزة الحساسة • موازين إلكترونية • محارير ليزرية • كواشف ميدانية'
                        : 'Mallettes de contrôle • Thermomètres • Balances homologuées',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFD4AF37)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showNewEquipmentDialog,
                icon: const Icon(Icons.add, size: 16),
                label: Text(isAr ? 'إضافة عتاد' : 'Ajouter', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            isAr ? 'قائمة الأجهزة والحقائب المسجلة رسمياً' : 'Liste du Matériel Enregistré',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
          ),
        ),

        if (_equipments.isEmpty)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF240D2D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4A2050)),
            ),
            alignment: Alignment.center,
            child: Text(
              isAr ? 'جاري تحميل جرد العتاد من الخادم...' : 'Chargement du matériel...',
              style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white70),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _equipments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final eq = _equipments[i];
              final code = (eq['Code'] ?? eq['code'] ?? '').toString();
              final name = (eq['Name'] ?? eq['name'] ?? '').toString();
              final cat = (eq['Category'] ?? eq['category'] ?? 'رقابة').toString();
              final sn = (eq['SerialNumber'] ?? eq['serialNumber'] ?? '').toString();
              final inspector = (eq['AssignedInspector'] ?? eq['assignedInspector'] ?? '').toString();
              final status = (eq['Status'] ?? eq['status'] ?? 'operationnel').toString();

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF240D2D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF4A2050)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.handyman, color: Color(0xFFD4AF37), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(code, style: const TextStyle(fontSize: 9.5, color: Color(0xFFD4AF37))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'الصنف: $cat ${sn.isNotEmpty ? "• الرقم التسلسلي: $sn" : ""}',
                            style: const TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                          if (inspector.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text('مسند إلى: $inspector', style: const TextStyle(fontSize: 10.5, color: Color(0xFF60A5FA))),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: status == 'operationnel'
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status == 'operationnel' ? (isAr ? 'جاهز للاستعمال' : 'Opérationnel') : (isAr ? 'صيانة' : 'Maintenance'),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: status == 'operationnel' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildHQsSubTab(bool isAr, List<InspectorateHQ> officialHQs) {
    int totalHqAttendance = 0;
    for (final emp in _allEmployees) {
      if (emp['hasCheckedIn'] == true) {
        totalHqAttendance++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Official Geofence Registry Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF2D1035), Color(0xFF1E0B26)]),
            border: Border(bottom: BorderSide(color: Color(0xFFD4AF37), width: 1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.apartment, color: Color(0xFFD4AF37), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAr ? 'شبكة المقرات والمفتشيات الثمانية المعتمدة (8)' : 'Réseau des 8 Sièges & Inspections Régionales',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAr
                              ? 'منظومة القفل الجغرافي الصارم (Strict GPS Geofence) • حظر التسجيل خارج النطاق'
                              : 'Geofencing GPS Strict • Interdiction de pointage hors zone',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFD4AF37)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  isAr
                      ? '🏛️ الضوابط الإدارية للمقرات الرسمية:\n• يلزم كافة موظفي ومفتشي المديرية بتسجيل الحضور الصباحي حصراً ضمن النطاق الجغرافي لأحد هذه المقرات الثمانية.\n• يتم رفض أي محاولة لتسجيل الحضور من المنزل أو خارج النطاق تلقائياً، ما لم تكن هناك مهمة رقابية مبرمجة سارية.'
                      : '🏛️ Directives Administratives des Sièges:\n• Pointage matinal obligatoire dans le rayon géographique de ces 8 sièges.\n• Rejet automatique de tout pointage hors zone sans ordre de mission.',
                  style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildAdminStatCard(
                    title: isAr ? 'المقرات المعتمدة' : 'Sièges Agréés',
                    value: '${officialHQs.length}',
                    icon: Icons.business,
                    color: const Color(0xFFD4AF37),
                  ),
                  const SizedBox(width: 8),
                  _buildAdminStatCard(
                    title: isAr ? 'الحضور بالبصمة اليوم' : 'Présents Aujourd\'hui',
                    value: '$totalHqAttendance',
                    icon: Icons.how_to_reg,
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  _buildAdminStatCard(
                    title: isAr ? 'القفل الجغرافي' : 'Geofence GPS',
                    value: '100% نشط',
                    icon: Icons.lock_clock,
                    color: const Color(0xFF10B981),
                  ),
                ],
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.pin_drop, color: Color(0xFFD4AF37), size: 18),
              const SizedBox(width: 8),
              Text(
                isAr ? 'بيانات المقرات والمفتشيات وإحداثيات البصمة الرسمية' : 'Détails des Sièges & Coordonnées GPS Officielles',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
            ],
          ),
        ),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: officialHQs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final hq = officialHQs[i];
            final isMain = hq.isMainDirectorate;

            final attendeesCount = _allEmployees.where((e) {
              if (e['hasCheckedIn'] != true) return false;
              final loc = (e['location'] ?? '').toString();
              if (isMain && (loc.contains('المعبودة') || loc.contains('الرئيسي') || loc.contains('سطيف'))) return true;
              if (hq.id.contains('airport') && (loc.contains('مطار') || loc.contains('8 ماي'))) return true;
              if (hq.id.contains('eulma') && loc.contains('العلمة')) return true;
              if (hq.id.contains('oulmene') && loc.contains('ولمان')) return true;
              if (hq.id.contains('bougaa') && loc.contains('بوقاعة')) return true;
              if (hq.id.contains('azel') && loc.contains('آزال')) return true;
              if (hq.id.contains('kebira') && loc.contains('الكبيرة')) return true;
              if (hq.id.contains('arnat') && loc.contains('أرنات')) return true;
              return false;
            }).length;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF240D2D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isMain ? const Color(0xFFD4AF37) : const Color(0xFF4A2050),
                  width: isMain ? 1.2 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isMain ? const Color(0xFFD4AF37).withValues(alpha: 0.15) : const Color(0xFFD4AF37).withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isMain ? Icons.account_balance : Icons.location_city,
                      color: const Color(0xFFD4AF37),
                      size: 20,
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
                                isAr ? hq.nameAr : hq.nameFr,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                              ),
                            ),
                            if (isMain)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFD4AF37), width: 0.5),
                                ),
                                child: Text(
                                  isAr ? 'المقر الرئيسي' : 'Siège Principal',
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isAr
                              ? 'الإحداثيات: ${hq.latitude.toStringAsFixed(6)}, ${hq.longitude.toStringAsFixed(6)} • نصف القطر: ${hq.radiusMeters.toInt()} متر'
                              : 'GPS: ${hq.latitude.toStringAsFixed(6)}, ${hq.longitude.toStringAsFixed(6)} • Rayon: ${hq.radiusMeters.toInt()} m',
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF10B981), width: 0.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle, size: 11, color: Color(0xFF10B981)),
                                  const SizedBox(width: 4),
                                  Text(
                                    isAr ? 'الحاضرون اليوم: $attendeesCount' : 'Présents: $attendeesCount',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isAr ? '• نطاق بصمة نشط 100%' : '• Zone active 100%',
                              style: const TextStyle(fontSize: 10, color: Colors.white54),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showNewVehicleMissionDialog(Map<String, dynamic> vehicle) {
    final vId = vehicle['Id'] ?? vehicle['id'];
    final plate = (vehicle['Matricule'] ?? vehicle['matricule'] ?? '').toString();
    final model = (vehicle['Model'] ?? vehicle['model'] ?? '').toString();
    final currentKm = (vehicle['Kilometrage'] ?? vehicle['kilometrage'] ?? 0);

    final destCtrl = TextEditingController(text: 'بلدية سطيف وضواحيها');
    final purposeCtrl = TextEditingController(text: 'خرجة رقابية وتفتيش ميداني');
    final kmCtrl = TextEditingController(text: '$currentKm');
    String? selectedDriver;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF240D2D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFD4AF37))),
          title: Row(
            children: [
              const Icon(Icons.directions_car, color: Color(0xFFD4AF37)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('إصدار أمر تنقل للمركبة ($plate)', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('المركبة: $model • العداد الحالي: $currentKm كم', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  dropdownColor: const Color(0xFF2D1035),
                  style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'السائق أو المفتش المكلف بالقيادة *',
                    prefixIcon: const Icon(Icons.person, color: Color(0xFFD4AF37), size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: _allEmployees.map((e) {
                    final name = (e['name'] ?? '').toString();
                    return DropdownMenuItem(value: name, child: Text(name));
                  }).toList(),
                  onChanged: (val) => setDlgState(() => selectedDriver = val),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: destCtrl,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'الوجهة الرسمية *',
                    prefixIcon: const Icon(Icons.place, color: Color(0xFFD4AF37), size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: purposeCtrl,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'موضوع وأسباب المهمة *',
                    prefixIcon: const Icon(Icons.assignment, color: Color(0xFFD4AF37), size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: kmCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'عداد الانطلاق (كم)',
                    prefixIcon: const Icon(Icons.speed, color: Color(0xFFD4AF37), size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.white60, fontFamily: 'Tajawal'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black),
              onPressed: () async {
                if (selectedDriver == null || destCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى تحديد السائق والوجهة'), backgroundColor: Colors.orange),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final api = context.read<AuthService>().api;
                  await api.createVehicleMission({
                    'vehicleId': vId,
                    'driverName': selectedDriver,
                    'destination': destCtrl.text.trim(),
                    'purpose': purposeCtrl.text.trim(),
                    'startKm': int.tryParse(kmCtrl.text.trim()) ?? currentKm,
                  });
                  _loadAllData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ تم إصدار أمر التنقل بنجاح للمركبة'), backgroundColor: Color(0xFF10B981)),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('تأكيد وإصدار الأمر', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCloseVehicleMissionDialog(Map<String, dynamic> vehicle) {
    final vId = vehicle['Id'] ?? vehicle['id'];
    final plate = (vehicle['Matricule'] ?? vehicle['matricule'] ?? '').toString();
    final missionId = vehicle['ActiveMissionId'] ?? vehicle['activeMissionId'];
    final currentKm = (vehicle['Kilometrage'] ?? vehicle['kilometrage'] ?? 0);
    final endKmCtrl = TextEditingController(text: '${(currentKm as num) + 25}');
    double returnFuel = (vehicle['FuelLevel'] ?? vehicle['fuelLevel'] ?? 50) as double;
    final obsCtrl = TextEditingController(text: 'تمت المهمة وعادت المركبة بحالة جيدة');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF240D2D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF10B981))),
          title: Row(
            children: [
              const Icon(Icons.assignment_turned_in, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('إنهاء أمر تنقل واسترجاع المركبة ($plate)', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: endKmCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'عداد الكيلومترات عند الرجوع *',
                    prefixIcon: const Icon(Icons.speed, color: Color(0xFF10B981), size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                Text('مستوى الوقود المتبقي: ${returnFuel.toInt()}%', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white70)),
                Slider(
                  value: returnFuel,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  activeColor: const Color(0xFF10B981),
                  label: '${returnFuel.toInt()}%',
                  onChanged: (val) => setDlgState(() => returnFuel = val),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: obsCtrl,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'ملاحظات حالة المركبة عند الاسترجاع',
                    prefixIcon: const Icon(Icons.notes, color: Color(0xFF10B981), size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.white60, fontFamily: 'Tajawal'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final api = context.read<AuthService>().api;
                  final effectiveMissionId = int.tryParse('$missionId') ?? int.tryParse('$vId') ?? 1;
                  await api.closeVehicleMission(effectiveMissionId, {
                    'endKm': int.tryParse(endKmCtrl.text.trim()) ?? currentKm,
                    'fuelLevel': returnFuel.toInt(),
                    'observations': obsCtrl.text.trim(),
                  });
                  _loadAllData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ تم استرجاع المركبة وإغلاق أمر التنقل بنجاح'), backgroundColor: Color(0xFF10B981)),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('تأكيد الاسترجاع', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewEquipmentDialog() {
    final codeCtrl = TextEditingController(text: 'MAL-0${_equipments.length + 1}');
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'حقائب تفتيش وقمع الغش');
    final snCtrl = TextEditingController();
    String? assignedInsp;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF240D2D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFD4AF37))),
          title: const Row(
            children: [
              Icon(Icons.medical_services, color: Color(0xFFD4AF37)),
              SizedBox(width: 8),
              Text('تسجيل عتاد أو حقيبة تفتيش جديدة', style: TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeCtrl,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'رمز العتاد (Code) *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'اسم الجهاز أو الحقيبة *',
                    hintText: 'مثال: حقيبة تفتيش متعددة الوسائط',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: catCtrl,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'الصنف / الفئة *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: snCtrl,
                  style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'الرقم التسلسلي (N° Série)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  dropdownColor: const Color(0xFF2D1035),
                  style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'المفتش المسند إليه (اختياري)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: _allEmployees.map((e) {
                    final name = (e['name'] ?? '').toString();
                    return DropdownMenuItem(value: name, child: Text(name));
                  }).toList(),
                  onChanged: (val) => setDlgState(() => assignedInsp = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.white60, fontFamily: 'Tajawal'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال اسم العتاد'), backgroundColor: Colors.orange),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final api = context.read<AuthService>().api;
                  await api.createEquipment({
                    'code': codeCtrl.text.trim(),
                    'name': nameCtrl.text.trim(),
                    'category': catCtrl.text.trim(),
                    'serialNumber': snCtrl.text.trim(),
                    'assignedInspector': assignedInsp,
                  });
                  _loadAllData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ تم تسجيل العتاد بنجاح في قاعدة البيانات'), backgroundColor: Color(0xFF10B981)),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('حفظ العتاد', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmCancelMission(Map<String, dynamic> p) {
    final rawId = p['Id'] ?? p['id'];
    final id = int.tryParse('$rawId') ?? 0;
    final title = (p['Title'] ?? p['title'] ?? '').toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF240D2D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              'إلغاء أمر المهمة الرقابية',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في إلغاء أمر المهمة:\n"$title"؟',
          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('رجوع', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final api = context.read<AuthService>().api;
                final res = await api.cancelProgram(id, title: title);
                _loadAllData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message']?.toString() ?? 'تم إلغاء أمر المهمة بنجاح'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ في الإلغاء: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('نعم، إلغاء المهمة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteVisit(Map<String, dynamic> v) {
    final rawId = v['Id'] ?? v['id'];
    final id = int.tryParse('$rawId') ?? 0;
    final shop = (v['ShopName'] ?? v['shopName'] ?? 'المحل التجاري').toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF240D2D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              'حذف محضر المعاينة',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف محضر المعاينة الخاص بـ:\n"$shop"؟ (سيتم إزالته من السجلات).',
          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('رجوع', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final api = context.read<AuthService>().api;
                await api.deleteVisit(id);
                _loadAllData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ تم حذف محضر المعاينة بنجاح'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ في الحذف: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('نعم، حذف', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAdministrationFinanceTab() {
    final isAr = context.watch<LanguageProvider>().isArabic;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sovereign Rule Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2D1035), Color(0xFF4C0519)],
              ),
              border: Border(bottom: BorderSide(color: Color(0xFFD4AF37), width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.gavel, color: Color(0xFFD4AF37), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAr ? 'مكتب المحاسبة والرواتب — تنفيذ قرارات الخصم المالي' : 'Bureau de Paie — Exécution des Décisions du Directeur',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAr ? 'السلطة السيادية للمدير الولائي (الآمر بالصرف الوحيد) • الأمر 06-03' : 'Autorité Souveraine de l\'Ordonnateur • Ordonnance 06-03',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFD4AF37)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    isAr
                        ? '⚖️ القاعدة القانونية المعتمدة (الأمر 06-03):\n• مبدأ الراتب مقابل أداء الخدمة (Service Fait).\n• تراكم 4 ساعات تأخر شهرياً = خصم نصف يوم (0.5 يوم).\n• تراكم 8 ساعات تأخر شهرياً = خصم يوم كامل (1.0 يوم).'
                        : '⚖️ Règle Juridique (Ordonnance 06-03):\n• Principe du Service Fait.\n• Cumul 4h de retard / mois = retenue 0.5 jour.\n• Cumul 8h de retard / mois = retenue 1.0 jour.',
                    style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          // Executed Deductions List
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Color(0xFFD4AF37), size: 18),
                const SizedBox(width: 8),
                Text(
                  isAr ? 'سجل القرارات المالية المنفذة على كشف الراتب' : 'Registre des Retenues sur Paie',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
              ],
            ),
          ),

          if (_deductions.isEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF240D2D),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4A2050)),
              ),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 36),
                  const SizedBox(height: 8),
                  Text(
                    isAr ? 'كافة الرواتب مسواة ومنتظمة ولا توجد قرارات خصم معلقة حالياً' : 'Toutes les paies sont à jour',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _deductions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final d = _deductions[i];
                final days = d['DaysCount'] ?? d['daysCount'] ?? 1;
                final reason = d['Reason'] ?? d['reason'] ?? 'تراكم ساعات التأخر';

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF240D2D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4A2050)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF881337).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.money_off, color: Color(0xFFF43F5E), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'قرار خصم: $days يوم عمل (06-03)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'السبب: $reason',
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981), width: 0.5),
                        ),
                        child: const Text(
                          'منفذ على الراتب ✅',
                          style: TextStyle(fontSize: 10, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 20),
          const AppFooter(showDivider: false),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  // ==========================================
  // COMMERCIAL & FRAUD SERVICES TABS
  // ==========================================

  List<String> _getDepartmentBrigades() {
    if (_departmentName.contains('المنافسة')) {
      return [
        'فرقة التحقيقات الاقتصادية وتتبع الفوترة 01',
        'فرقة مراقبة الممارسات التجارية وهوامش الربح 02',
        'فرقة تتبع مسالك التوزيع والمخازن 03',
        'فرقة مكافحة المضاربة غير المشروعة 04',
        'فرقة المداومة والمناوبة المسائية',
        'احتياط المصلحة (بدون تعيين ميداني)',
      ];
    } else {
      return [
        'فرقة التدخل 01 (حي تبيانت والمركز)',
        'فرقة التدخل 02 (المعبودة وسوق الجملة)',
        'فرقة التدخل 03 (الهضاب والقطاع الشرقي)',
        'فرقة التدخل 04 (المنطقة الحضرية الجديدة)',
        'فرقة سحب العينات والمطابقة المخبرية (CACQE)',
        'فرقة المداومة والمناوبة المسائية',
        'احتياط المصلحة (بدون تعيين ميداني)',
      ];
    }
  }

  void _showAttachEmployeeDialog() {
    final assignedIds = _departmentInspectors.map((e) => e['id']).toSet();
    final available = _allAvailableEmployees.where((e) {
      final id = int.tryParse('${e['Id'] ?? e['id'] ?? 0}') ?? 0;
      return id > 0 && !assignedIds.contains(id);
    }).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('جميع موظفي المديرية ملحقون بمصالحهم حالياً، أو يمكن إدراج عون جديد عبر مكتب المستخدمين.', style: TextStyle(fontFamily: 'Tajawal')),
          backgroundColor: AppTheme.WarningColor,
        ),
      );
      return;
    }

    int selectedEmpId = int.tryParse('${available.first['Id'] ?? available.first['id'] ?? 0}') ?? 0;
    final brigades = _getDepartmentBrigades();
    String selectedBrigade = brigades.first;
    bool isLeader = false;
    final positions = [
      'مفتش ميداني',
      'رئيس فرقة رقابية',
      'عون مراقبة وتفتيش',
      'محقق رئيسي للمنافسة',
      'عضو فرقة تحقيق',
      'مفتش سحب عينات ومطابقة',
    ];
    String selectedPosition = positions.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF1E102F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_alt_1, color: Color(0xFFD4AF37), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إلحاق عون رقابة بالمصلحة',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'المصلحة المستقبلة: $_departmentName',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFD4AF37)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'اختر العون من السجل الإداري العام للمديرية:',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: selectedEmpId,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2D1035),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 12),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.badge, color: Color(0xFFD4AF37), size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFF1E0B26),
                    ),
                    items: available.map((emp) {
                      final id = int.tryParse('${emp['Id'] ?? emp['id'] ?? 0}') ?? 0;
                      final name = '${emp['NomAr'] ?? emp['Nom'] ?? ''} ${emp['PrenomAr'] ?? emp['Prenom'] ?? ''}'.trim();
                      final grade = (emp['Grade'] ?? emp['FonctionExercee'] ?? '').toString().trim();
                      final currentSvc = (emp['Service'] ?? 'غير معين').toString().trim();
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(
                          '$name ($grade) • [حالياً: $currentSvc]',
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedEmpId = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'إسناد الفرقة الرقابية بالمصلحة:',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBrigade,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2D1035),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 12),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.groups, color: Color(0xFFD4AF37), size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFF1E0B26),
                    ),
                    items: brigades.map((b) => DropdownMenuItem(
                      value: b,
                      child: Text(b, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedBrigade = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'الوظيفة والمهمة الميدانية المسندة:',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPosition,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2D1035),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 12),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.work_outline, color: Color(0xFFD4AF37), size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFF1E0B26),
                    ),
                    items: positions.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedPosition = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'تعيين كرئيس فرقة (Chef de brigade)',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    subtitle: const Text(
                      'يمنحه شارة القيادة ⭐ وصلاحية قيادة الثنائي الميداني وتنسيق المحاضر',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white54),
                    ),
                    value: isLeader,
                    activeThumbColor: const Color(0xFFD4AF37),
                    onChanged: (val) => setModalState(() => isLeader = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white60)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('تأكيد الإلحاق والتكليف', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              onPressed: () async {
                final auth = context.read<AuthService>();
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(dlgCtx);
                setState(() => _isLoading = true);

                try {
                  await auth.api.updateEmployeeAdminStatus(selectedEmpId, {
                    'assignedDepartment': _departmentName,
                    'brigadeName': selectedBrigade,
                    'isBrigadeLeader': isLeader,
                    'assignedPosition': selectedPosition,
                  });
                  await _loadAllData();
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('✅ تم إلحاق العون بمصلحة ($_departmentName) بنجاح وتعيين فرقته الرقابية', style: const TextStyle(fontFamily: 'Tajawal')),
                      backgroundColor: AppTheme.SuccessColor,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  setState(() => _isLoading = false);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('خطأ أثناء إلحاق العون: $e', style: const TextStyle(fontFamily: 'Tajawal')),
                      backgroundColor: AppTheme.DangerColor,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBrigadeDialog(Map<String, dynamic> inspector) {
    final name = (inspector['name'] ?? 'مفتش').toString();
    final int id = inspector['id'] as int;
    final defaultBrigades = _getDepartmentBrigades();
    String currentBrigade = (inspector['brigade'] ?? defaultBrigades.first).toString();
    bool isLeader = inspector['isBrigadeLeader'] == true;
    final positions = [
      'مفتش ميداني',
      'رئيس فرقة رقابية',
      'عون مراقبة وتفتيش',
      'محقق رئيسي للمنافسة',
      'عضو فرقة تحقيق',
      'مفتش سحب عينات ومطابقة',
    ];
    String currentPosition = (inspector['grade'] ?? positions.first).toString();
    if (!positions.contains(currentPosition)) {
      positions.insert(0, currentPosition);
    }

    if (!defaultBrigades.contains(currentBrigade) && currentBrigade.isNotEmpty) {
      defaultBrigades.insert(0, currentBrigade);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setModalState) => AlertDialog(
          backgroundColor: AppTheme.CardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.groups, color: AppTheme.AccentColor, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تعديل تشكيل الفرقة وتعيين الثنائي',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      name,
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Color(0xFFD4AF37)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تعيين الفرقة الرقابية والقطاع الجغرافي:',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: defaultBrigades.contains(currentBrigade) ? currentBrigade : defaultBrigades.first,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2D1035),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.shield, color: AppTheme.AccentColor, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFF1E0B26),
                    ),
                    items: defaultBrigades.map((b) => DropdownMenuItem(
                      value: b,
                      child: Text(b, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => currentBrigade = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'الوظيفة والمهمة الميدانية:',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: currentPosition,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2D1035),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.work_outline, color: AppTheme.AccentColor, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFF1E0B26),
                    ),
                    items: positions.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => currentPosition = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تعيين كرئيس فرقة (Chef de brigade)', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('يتولى قيادة الثنائي وتنسيق المحاضر الميدانية', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.TextSecondary)),
                    value: isLeader,
                    activeThumbColor: AppTheme.AccentColor,
                    onChanged: (val) => setModalState(() => isLeader = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white60)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final auth = context.read<AuthService>();
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await auth.api.updateEmployeeAdminStatus(id, {
                    'brigadeName': currentBrigade,
                    'isBrigadeLeader': isLeader,
                    'assignedDepartment': _departmentName,
                    'assignedPosition': currentPosition,
                  });
                  if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                  _loadAllData();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('✅ تم تحديث تشكيل الفرقة وتعيين $name بنجاح', style: const TextStyle(fontFamily: 'Tajawal')),
                      backgroundColor: AppTheme.SuccessColor,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('⚠️ خطأ: $e', style: const TextStyle(fontFamily: 'Tajawal')),
                      backgroundColor: AppTheme.WarningColor,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('حفظ التشكيل', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.AccentColor, foregroundColor: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewMissionDialog() {
    final titleCtrl = TextEditingController();
    final areaCtrl = TextEditingController(text: 'بلديات سطيف والعلمة وعين ولمان');
    final focusCtrl = TextEditingController();
    
    String programCategory = 'برنامج قطاعي وطني مسطر (وزاري / ولائي)';
    String targetActivity = 'تجار التجزئة والسوبرماركت';
    String programDuration = 'daily';
    
    String assignmentMode = 'brigade';
    String? selectedBrigadeName;
    int? selectedInspectorId;
    int? selectedLeaderId = _departmentInspectors.isNotEmpty
        ? (_departmentInspectors.firstWhere((i) => i['isBrigadeLeader'] == true, orElse: () => _departmentInspectors.first)['id'] as int?)
        : null;
    final Set<int> selectedCompanionIds = {};
    String transportMode = 'سيارة الخدمة التابعة للمديرية';

    final Map<String, List<Map<String, dynamic>>> brigadesMap = {};
    for (final emp in _departmentInspectors) {
      final b = (emp['brigade'] ?? 'فرقة التدخل 01 (حي تبيانت والمركز)').toString().trim();
      if (b.isNotEmpty) brigadesMap.putIfAbsent(b, () => []).add(emp);
    }
    if (brigadesMap.isNotEmpty) {
      selectedBrigadeName = brigadesMap.keys.first;
    }

    if (_departmentName.contains('المنافسة')) {
      titleCtrl.text = 'مراقبة احترام الأسعار المقننة وهوامش الربح والفوترة';
      focusCtrl.text = 'التأكد من إشهار الأسعار، فواتير التوزيع لمادتي الزيت والحليب، ومكافحة المضاربة';
    } else {
      titleCtrl.text = 'مراقبة شروط النظافة الصحية ومطابقة المواد الغذائية الحساسة';
      focusCtrl.text = 'مراقبة سلسلة التبريد، شروط حفظ اللحوم والمشتقات اللبنية، وسحب عينات مخبرية';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppTheme.CardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.assignment_add, color: AppTheme.AccentColor, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إصدار أمر مهمة رقابية لفرق المفتشين',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _departmentName,
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFD4AF37)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'نوع البرنامج الرقابي القانوني:',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: programCategory,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2D1035),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.category, color: AppTheme.AccentColor, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFF1E0B26),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'برنامج قطاعي وطني مسطر (وزاري / ولائي)',
                        child: Text('برنامج قطاعي وطني مسطر (وزاري / ولائي)', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: 'برنامج التدخل الميداني الدوري (مراقبة اعتيادية)',
                        child: Text('برنامج التدخل الميداني الدوري (مراقبة اعتيادية)', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: 'تحقيقات اقتصادية وتتبع مسالك التوزيع والفوترة',
                        child: Text('تحقيقات اقتصادية وتتبع مسالك التوزيع', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: 'برنامج سحب العينات والتحاليل المخبرية (CACQE)',
                        child: Text('برنامج سحب العينات والتحاليل المخبرية', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: 'تدخل استعجالي وشكاوى المستهلكين والإخطارات',
                        child: Text('تدخل استعجالي وشكاوى المستهلكين', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: 'لجنة ولائية مشتركة (بيطرة / أمن / صحة)',
                        child: Text('لجنة ولائية مشتركة (بيطرة / أمن / صحة)', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => programCategory = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'نطاق وتوجيه المهمة الرقابية:',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          avatar: const Icon(Icons.groups, size: 16),
                          label: const Text('تكليف فرقة كاملة', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
                          selected: assignmentMode == 'brigade',
                          selectedColor: AppTheme.AccentColor,
                          backgroundColor: const Color(0xFF1E0B26),
                          onSelected: (sel) {
                            if (sel) setModalState(() => assignmentMode = 'brigade');
                          },
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          avatar: const Icon(Icons.public, size: 16),
                          label: const Text('تعميم شامل للمصلحة', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
                          selected: assignmentMode == 'all',
                          selectedColor: AppTheme.AccentColor,
                          backgroundColor: const Color(0xFF1E0B26),
                          onSelected: (sel) {
                            if (sel) setModalState(() => assignmentMode = 'all');
                          },
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          avatar: const Icon(Icons.person, size: 16),
                          label: const Text('تكليف مفتش فردي', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
                          selected: assignmentMode == 'inspector',
                          selectedColor: AppTheme.AccentColor,
                          backgroundColor: const Color(0xFF1E0B26),
                          onSelected: (sel) {
                            if (sel) setModalState(() => assignmentMode = 'inspector');
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (assignmentMode == 'brigade') ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedBrigadeName,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2D1035),
                      decoration: InputDecoration(
                        labelText: 'اختر الفرقة الرقابية المكلفة بالتنفيذ',
                        prefixIcon: const Icon(Icons.shield, color: AppTheme.AccentColor, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFF1E0B26),
                      ),
                      items: brigadesMap.entries.map((entry) {
                        final bName = entry.key;
                        final members = entry.value;
                        final leader = members.firstWhere(
                          (m) => m['isBrigadeLeader'] == true,
                          orElse: () => members.first,
                        );
                        final leaderName = (leader['name'] ?? 'رئيس الفرقة').toString();
                        return DropdownMenuItem(
                          value: bName,
                          child: Text(
                            '$bName (${members.length} أعضاء • بقيادة: $leaderName)',
                            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedBrigadeName = val),
                    ),
                  ] else if (assignmentMode == 'all') ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.campaign, color: Color(0xFFD4AF37), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'سيتم إرسال هذا الأمر إلى كافة الفرق الرقابية الـ (${brigadesMap.length} فرق) بالمصلحة دفعة واحدة.',
                              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFD4AF37)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    DropdownButtonFormField<int?>(
                      initialValue: selectedInspectorId,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2D1035),
                      decoration: InputDecoration(
                        labelText: 'اختر المفتش المكلف',
                        prefixIcon: const Icon(Icons.badge, color: AppTheme.AccentColor, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFF1E0B26),
                      ),
                      items: _departmentInspectors.map((insp) {
                        final id = insp['id'] as int;
                        final name = (insp['name'] ?? '').toString();
                        final grade = (insp['grade'] ?? '').toString();
                        return DropdownMenuItem(
                          value: id,
                          child: Text('$name ($grade)', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12), overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedInspectorId = val),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'تعيين رئيس المهمة الرقابية (Chef de Mission) *:',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFD4AF37)),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedLeaderId,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2D1035),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 12),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.star, color: Color(0xFFD4AF37), size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFF1E0B26),
                    ),
                    items: _departmentInspectors.map((insp) {
                      final id = insp['id'] as int;
                      final name = (insp['name'] ?? '').toString();
                      final grade = (insp['grade'] ?? '').toString();
                      final isL = insp['isBrigadeLeader'] == true;
                      return DropdownMenuItem<int?>(
                        value: id,
                        child: Text(
                          '$name ($grade)${isL ? " ⭐ [رئيس فرقة]" : ""}',
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setModalState(() {
                      selectedLeaderId = val;
                      if (val != null) selectedCompanionIds.remove(val);
                    }),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'الأعوان المرافقون في المهمة (حدد الأعضاء):',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  if (_departmentInspectors.where((i) => i['id'] != selectedLeaderId).isEmpty)
                    const Text('لا يوجد أعوان آخرون متاحون بالمصلحة', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white38))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _departmentInspectors.where((i) => i['id'] != selectedLeaderId).map((insp) {
                        final id = insp['id'] as int;
                        final isChosen = selectedCompanionIds.contains(id);
                        return FilterChip(
                          selected: isChosen,
                          label: Text(
                            insp['name']?.toString() ?? '',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              color: isChosen ? Colors.black : Colors.white70,
                              fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          selectedColor: const Color(0xFFD4AF37),
                          backgroundColor: const Color(0xFF2D1035),
                          checkmarkColor: Colors.black,
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                selectedCompanionIds.add(id);
                              } else {
                                selectedCompanionIds.remove(id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'وسيلة التنقل والتدخل الميداني:',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    initialValue: transportMode,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2D1035),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 12),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.directions_car, color: AppTheme.AccentColor, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFF1E0B26),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'سيارة الخدمة التابعة للمديرية', child: Text('سيارة الخدمة التابعة للمديرية')),
                      DropdownMenuItem(value: 'دورية راجلة / تنقل حضري محلي', child: Text('دورية راجلة / تنقل حضري محلي')),
                      DropdownMenuItem(value: 'حافلة النقل الجماعي أو قطار', child: Text('حافلة النقل الجماعي أو قطار')),
                      DropdownMenuItem(value: 'سيارة خاصة مرخصة بمهمة', child: Text('سيارة خاصة مرخصة بمهمة')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => transportMode = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'موضوع المهمة وأمر التكليف *',
                      prefixIcon: const Icon(Icons.title, color: AppTheme.AccentColor, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFF1E0B26),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: areaCtrl,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'الإقليم والبلديات المستهدفة *',
                      hintText: 'مثال: بلدية سطيف، العلمة، عين ولمان، بوقاعة',
                      prefixIcon: const Icon(Icons.location_on, color: AppTheme.AccentColor, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFF1E0B26),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: targetActivity,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2D1035),
                    decoration: InputDecoration(
                      labelText: 'طبيعة الأنشطة المستهدفة بالمعاينة',
                      prefixIcon: const Icon(Icons.storefront, color: AppTheme.AccentColor, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFF1E0B26),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'تجار التجزئة والسوبرماركت', child: Text('تجار التجزئة والمحلات التجارية', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                      DropdownMenuItem(value: 'أسواق الجملة للخضر والفواكه والمواد الغذائية', child: Text('أسواق الجملة ومستودعات التخزين', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                      DropdownMenuItem(value: 'المخابز ومحلات صناعة الحلويات', child: Text('المخابز ومحلات الحلويات', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                      DropdownMenuItem(value: 'المذابح وتجار اللحوم البيضاء والحمراء والقصابات', child: Text('المذابح وتجار اللحوم والقصابات', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                      DropdownMenuItem(value: 'وحدات الإنتاج والتحويل الصناعي للمواد الاستهلاكية', child: Text('وحدات الإنتاج والتحويل الصناعي', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                      DropdownMenuItem(value: 'المستوردين والموزعين المعتمدين والمستودعات', child: Text('المستوردين والموزعين والمستودعات', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => targetActivity = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: focusCtrl,
                    textDirection: TextDirection.rtl,
                    maxLines: 2,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'النقاط البؤرية والتعليمات الرقابية الميدانية',
                      prefixIcon: const Icon(Icons.rule, color: AppTheme.AccentColor, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: const Color(0xFF1E0B26),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('أمر مهمة يومي', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
                          selected: programDuration == 'daily',
                          selectedColor: AppTheme.AccentColor,
                          backgroundColor: const Color(0xFF1E0B26),
                          onSelected: (selected) {
                            if (selected) setModalState(() => programDuration = 'daily');
                          },
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('برنامج أسبوعي', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
                          selected: programDuration == 'weekly',
                          selectedColor: AppTheme.AccentColor,
                          backgroundColor: const Color(0xFF1E0B26),
                          onSelected: (selected) {
                            if (selected) setModalState(() => programDuration = 'weekly');
                          },
                        ),
                        const SizedBox(width: 6),
                        ChoiceChip(
                          label: const Text('برنامج شهري مسطر', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
                          selected: programDuration == 'monthly',
                          selectedColor: AppTheme.AccentColor,
                          backgroundColor: const Color(0xFF1E0B26),
                          onSelected: (selected) {
                            if (selected) setModalState(() => programDuration = 'monthly');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white60)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || areaCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚠️ يرجى إدخال موضوع المهمة والإقليم المستهدف', style: TextStyle(fontFamily: 'Tajawal')), backgroundColor: AppTheme.WarningColor),
                  );
                  return;
                }

                String targetSummary = '';
                if (assignmentMode == 'brigade') {
                  targetSummary = 'فرقة: $selectedBrigadeName';
                } else if (assignmentMode == 'all') {
                  targetSummary = 'كافة فرق المصلحة (${brigadesMap.length} فرق)';
                } else {
                  final insp = _departmentInspectors.firstWhere((i) => i['id'] == selectedInspectorId, orElse: () => {});
                  targetSummary = 'المفتش: ${insp['name'] ?? ''}';
                }

                final leaderInsp = _departmentInspectors.firstWhere((i) => i['id'] == selectedLeaderId, orElse: () => {});
                final leaderName = (leaderInsp['name'] ?? '').toString();
                final companionNames = _departmentInspectors
                    .where((i) => selectedCompanionIds.contains(i['id']))
                    .map((i) => (i['name'] ?? '').toString())
                    .where((n) => n.isNotEmpty)
                    .toList();

                final fullTitle = '[$programCategory] [$targetSummary] ${leaderName.isNotEmpty ? "[رئيس المهمة: $leaderName] " : ""}${titleCtrl.text.trim()}';

                final fullDescription = [
                  if (leaderName.isNotEmpty) '👑 رئيس المهمة المكلف: $leaderName (${leaderInsp['grade'] ?? ''})',
                  if (companionNames.isNotEmpty) '👥 الأعوان المرافقون: ${companionNames.join("، ")}',
                  '🛡️ التكليف الرقابي: $targetSummary',
                  '🚗 وسيلة التنقل: $transportMode',
                  if (focusCtrl.text.trim().isNotEmpty) '🎯 المحاور الرقابية: ${focusCtrl.text.trim()}',
                ].join('\n');

                final auth = context.read<AuthService>();
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await auth.api.createProgram(
                    title: fullTitle,
                    description: fullDescription,
                    type: programDuration,
                    targetArea: areaCtrl.text.trim(),
                    targetType: targetActivity,
                    focusPoints: focusCtrl.text.trim(),
                    serviceName: _departmentName,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadAllData();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('✅ تم إصدار وتعميم أمر المهمة الرقابية بنجاح إلى $targetSummary', style: const TextStyle(fontFamily: 'Tajawal')),
                      backgroundColor: AppTheme.SuccessColor,
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('⚠️ خطأ: $e', style: const TextStyle(fontFamily: 'Tajawal')),
                      backgroundColor: AppTheme.WarningColor,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.send, size: 16),
              label: const Text('إصدار وتعميم الأمر', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.AccentColor, foregroundColor: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2D1035),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 9.5, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard({
    required String label,
    required int count,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
    bool isPendingHighlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : const Color(0xFF2D1035),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? color
                : (isPendingHighlight ? const Color(0xFFD4AF37).withValues(alpha: 0.6) : Colors.white10),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : (isPendingHighlight ? const Color(0xFFD4AF37) : Colors.white),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 9.5,
                color: isSelected ? color : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionsTab() {
    final isAr = context.watch<LanguageProvider>().isArabic;
    final totalMissions = _programs.length;
    final dailyMissions = _programs.where((p) => (p['Type'] ?? p['type'] ?? 'daily') == 'daily').length;
    final periodicMissions = totalMissions - dailyMissions;

    return Column(
      children: [
        // ── TOP INFORMATIVE HEADER & SINGLE ACTION BUTTON ───────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF240D2D),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment, color: Color(0xFFD4AF37), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'أوامر المهمة والبرامج الرقابية' : 'Ordres de Mission & Programmes',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAr ? 'إصدار وتوجيه مهام الرقابة للفرق الميدانية' : 'Affectation des missions de contrôle sur le terrain',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Color(0xFFD4AF37)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _showNewMissionDialog,
                icon: const Icon(Icons.add_task, size: 16),
                label: Text(
                  isAr ? '+ أمر مهمة جديد' : '+ Nouvel Ordre',
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.AccentColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),

        // ── QUICK STATS SUMMARY ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF1E0B26),
          child: Row(
            children: [
              _buildMiniStatCard(
                title: isAr ? 'إجمالي الأوامر' : 'Total Ordres',
                value: '$totalMissions',
                icon: Icons.assignment_outlined,
                color: const Color(0xFFD4AF37),
              ),
              const SizedBox(width: 8),
              _buildMiniStatCard(
                title: isAr ? 'أوامر يومية' : 'Journaliers',
                value: '$dailyMissions',
                icon: Icons.today,
                color: const Color(0xFF10B981),
              ),
              const SizedBox(width: 8),
              _buildMiniStatCard(
                title: isAr ? 'برامج دورية' : 'Périodiques',
                value: '$periodicMissions',
                icon: Icons.date_range,
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ),

        // ── LIST OF MISSIONS OR CLEAN EMPTY STATE ────────────────────────
        Expanded(
          child: _programs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_outlined, size: 54, color: AppTheme.AccentColor.withValues(alpha: 0.3)),
                        const SizedBox(height: 14),
                        Text(
                          isAr ? 'لا توجد أوامر مهمة مسجلة لهذه المصلحة حالياً' : 'Aucun ordre de mission pour ce service',
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, color: AppTheme.TextSecondary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isAr ? 'اضغط على الزر أدناه لتكليف الفرق الميدانية بأول مهمة رقابية' : 'Cliquez ci-dessous pour assigner une mission',
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white38),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showNewMissionDialog,
                          icon: const Icon(Icons.add_task, size: 16),
                          label: Text(
                            isAr ? 'إصدار أول أمر مهمة رقابية' : 'Créer un premier ordre',
                            style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.AccentColor,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _programs.length + 1,
                  itemBuilder: (ctx, i) {
                    if (i == _programs.length) {
                      return const Column(
                        children: [
                          SizedBox(height: 10),
                          AppFooter(showDivider: false),
                          SizedBox(height: 10),
                        ],
                      );
                    }
                    final p = _programs[i];
                    final rawTitle = (p['Title'] ?? p['title'] ?? 'أمر مهمة رقابية').toString();
                    final targetArea = (p['TargetArea'] ?? p['targetArea'] ?? 'ولاية سطيف').toString();
                    final focusPoints = (p['FocusPoints'] ?? p['focusPoints'] ?? 'مراقبة الممارسات التجارية').toString();
                    final pType = (p['Type'] ?? p['type'] ?? 'daily').toString();

                    String badgeLabel = isAr ? 'أمر مهمة يومي' : 'Ordre Journalier';
                    if (pType == 'weekly') badgeLabel = isAr ? 'برنامج أسبوعي' : 'Programme Hebdo';
                    if (pType == 'monthly') badgeLabel = isAr ? 'برنامج شهري مسطر' : 'Programme Mensuel';

                    String displayTitle = rawTitle;
                    String? assignedBrigadeBadge;

                    if (rawTitle.startsWith('[')) {
                      final closeIndex = rawTitle.indexOf(']');
                      if (closeIndex != -1) {
                        final remainder = rawTitle.substring(closeIndex + 1).trim();
                        if (remainder.startsWith('[')) {
                          final secondClose = remainder.indexOf(']');
                          if (secondClose != -1) {
                            assignedBrigadeBadge = remainder.substring(1, secondClose).trim();
                            displayTitle = remainder.substring(secondClose + 1).trim();
                          }
                        }
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: AppTheme.CardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppTheme.BorderColor.withValues(alpha: 0.5)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFD4AF37), width: 0.5),
                                  ),
                                  child: Text(
                                    badgeLabel,
                                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (assignedBrigadeBadge != null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFD4AF37), width: 0.5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.groups, size: 12, color: Color(0xFFD4AF37)),
                                        const SizedBox(width: 4),
                                        Text(
                                          assignedBrigadeBadge,
                                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
                                  tooltip: isAr ? 'إلغاء أمر المهمة' : 'Annuler l\'ordre',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _confirmCancelMission(p),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              displayTitle,
                              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: AppTheme.AccentColor),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${isAr ? "القطاع المستهدف" : "Secteur"}: $targetArea',
                                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: AppTheme.TextSecondary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${isAr ? "التعليمات" : "Instructions"}: $focusPoints',
                              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if ((p['Description'] ?? p['description'] ?? '').toString().trim().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E0B26),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Text(
                                  (p['Description'] ?? p['description']).toString().trim(),
                                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.white70, height: 1.4),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildVisitsValidationTab() {
    final isAr = context.watch<LanguageProvider>().isArabic;
    final totalVisits = _todayVisits.length;
    final pendingVisits = _todayVisits.where((v) => v['IsApproved'] != true && v['isApproved'] != true).length;
    final approvedVisits = _todayVisits.where((v) => v['IsApproved'] == true || v['isApproved'] == true).length;
    final violationsCount = _todayVisits.where((v) => v['ViolationFound'] == true || v['violationFound'] == true).length;

    final filtered = _todayVisits.where((v) {
      final isApproved = v['IsApproved'] == true || v['isApproved'] == true;
      final hasViolation = v['ViolationFound'] == true || v['violationFound'] == true;

      if (_visitsFilter == 'pending' && isApproved) return false;
      if (_visitsFilter == 'approved' && !isApproved) return false;
      if (_visitsFilter == 'violations' && !hasViolation) return false;

      if (_visitsSearchQuery.isNotEmpty) {
        final q = _visitsSearchQuery.toLowerCase();
        final shop = (v['ShopName'] ?? v['shopName'] ?? '').toString().toLowerCase();
        final type = (v['ShopType'] ?? v['shopType'] ?? '').toString().toLowerCase();
        final loc = (v['LocationName'] ?? v['locationName'] ?? '').toString().toLowerCase();
        final notes = (v['Notes'] ?? v['notes'] ?? '').toString().toLowerCase();
        if (!shop.contains(q) && !type.contains(q) && !loc.contains(q) && !notes.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();

    return Column(
      children: [
        // ── TOP INFORMATIVE GUIDE BANNER ─────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF240D2D),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fact_check, color: Color(0xFFD4AF37), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'تأشير المعاينات والمحاضر الميدانية' : 'Validation des Procès-Verbaux',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAr
                          ? 'راجع تقارير المفتشين وأشّر عليها للاعتماد الرسمي في الحصيلة'
                          : 'Vérifiez et validez les rapports de contrôle pour le bilan officiel',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Color(0xFFD4AF37)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── 4 QUICK FILTER STAT CARDS ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF1E0B26),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildFilterCard(
                      label: isAr ? 'الكل' : 'Tous',
                      count: totalVisits,
                      isSelected: _visitsFilter == 'all',
                      color: Colors.white,
                      onTap: () => setState(() => _visitsFilter = 'all'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildFilterCard(
                      label: isAr ? 'بانتظار التأشير' : 'En attente',
                      count: pendingVisits,
                      isSelected: _visitsFilter == 'pending',
                      color: const Color(0xFFD4AF37),
                      isPendingHighlight: pendingVisits > 0,
                      onTap: () => setState(() => _visitsFilter = 'pending'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildFilterCard(
                      label: isAr ? 'مؤشرة' : 'Validées',
                      count: approvedVisits,
                      isSelected: _visitsFilter == 'approved',
                      color: const Color(0xFF10B981),
                      onTap: () => setState(() => _visitsFilter = 'approved'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildFilterCard(
                      label: isAr ? 'مخالفات' : 'Infractions',
                      count: violationsCount,
                      isSelected: _visitsFilter == 'violations',
                      color: const Color(0xFFEF4444),
                      onTap: () => setState(() => _visitsFilter = 'violations'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (val) => setState(() => _visitsSearchQuery = val),
                textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white),
                decoration: InputDecoration(
                  hintText: isAr ? 'بحث باسم المحل التجاري، النشاط، أو الموقع...' : 'Recherche par nom, activité, commune...',
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37), size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: const Color(0xFF2D1035),
                  suffixIcon: _visitsSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: Colors.white60),
                          onPressed: () => setState(() => _visitsSearchQuery = ''),
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),

        // ── LIST OF VISITS OR INFORMATIVE EMPTY STATE ───────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _visitsFilter == 'pending'
                              ? Icons.task_alt
                              : (_visitsFilter == 'violations' ? Icons.shield_outlined : Icons.inventory_2_outlined),
                          size: 48,
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _visitsFilter == 'pending'
                              ? (isAr ? '🎉 ممتاز! لا توجد محاضر معلقة بانتظار التأشير — كافة التقارير مؤشرة' : 'Aucun rapport en attente de visa !')
                              : (_visitsFilter == 'violations'
                                  ? (isAr ? 'لم تسجل أي مخالفات في هذه الفئة اليوم' : 'Aucune infraction dans cette catégorie')
                                  : (isAr ? 'لا توجد معاينات مطابقة لمعايير البحث' : 'Aucune visite correspondante')),
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: AppTheme.TextSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length + 1,
                  itemBuilder: (ctx, i) {
                    if (i == filtered.length) {
                      return const Column(
                        children: [
                          SizedBox(height: 10),
                          AppFooter(showDivider: false),
                          SizedBox(height: 10),
                        ],
                      );
                    }
                    final v = filtered[i];
                    final shopName = (v['ShopName'] ?? v['shopName'] ?? 'محل تجاري').toString();
                    final shopType = (v['ShopType'] ?? v['shopType'] ?? 'نشاط تجاري').toString();
                    final location = (v['LocationName'] ?? v['locationName'] ?? 'ولاية سطيف').toString();
                    final bool hasViolation = v['ViolationFound'] == true || v['violationFound'] == true;
                    final String notes = (v['Notes'] ?? v['notes'] ?? '').toString();
                    final bool isApproved = v['IsApproved'] == true || v['isApproved'] == true;
                    final int visitId = int.tryParse('${v['Id'] ?? v['id'] ?? 0}') ?? 0;
                    final double seizureVal = double.tryParse('${v['SeizureValue'] ?? v['seizureValue'] ?? 0}') ?? 0.0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: AppTheme.CardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isApproved
                              ? const Color(0xFFD4AF37).withValues(alpha: 0.6)
                              : (hasViolation ? AppTheme.DangerColor.withValues(alpha: 0.5) : AppTheme.BorderColor.withValues(alpha: 0.3)),
                          width: isApproved ? 1.2 : 0.8,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── HEADER ROW: STORE & BADGES ─────────────────────────
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (hasViolation ? AppTheme.DangerColor : AppTheme.SuccessColor).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    hasViolation ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                    color: hasViolation ? AppTheme.DangerColor : AppTheme.SuccessColor,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        shopName,
                                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$shopType • $location',
                                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.TextSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                // Violation badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (hasViolation ? AppTheme.DangerColor : AppTheme.SuccessColor).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    hasViolation ? (isAr ? '🚨 مخالفة' : 'Infraction') : (isAr ? '✅ مطابق' : 'Conforme'),
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: hasViolation ? AppTheme.DangerColor : AppTheme.SuccessColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Approval Status Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isApproved
                                        ? const Color(0xFFD4AF37).withValues(alpha: 0.15)
                                        : Colors.grey.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isApproved ? const Color(0xFFD4AF37) : Colors.grey,
                                      width: 0.6,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isApproved ? Icons.verified : Icons.pending_outlined,
                                        size: 11,
                                        color: isApproved ? const Color(0xFFD4AF37) : Colors.grey,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        isApproved ? (isAr ? 'مؤشر' : 'Visé') : (isAr ? 'معلق' : 'En attente'),
                                        style: TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: isApproved ? const Color(0xFFD4AF37) : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                  tooltip: isAr ? 'حذف المعاينة' : 'Supprimer la visite',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _confirmDeleteVisit(v),
                                ),
                              ],
                            ),

                            // ── SEIZURE VALUE IF PRESENT ───────────────────────────
                            if (seizureVal > 0) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.inventory_2, size: 13, color: Color(0xFFF59E0B)),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${isAr ? "قيمة المحجوزات" : "Valeur saisie"}: ${seizureVal.toStringAsFixed(0)} دج',
                                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFF59E0B), fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // ── NOTES BOX ──────────────────────────────────────────
                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E0B26),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Text(
                                  '${isAr ? "ملاحظات المفتش" : "Notes"}: $notes',
                                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70),
                                ),
                              ),
                            ],

                            // ── THE PRIMARY ACTION: VISA / APPROVE BUTTON ──────────
                            const SizedBox(height: 12),
                            if (!isApproved)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: visitId == 0
                                      ? null
                                      : () async {
                                          try {
                                            final api = context.read<AuthService>().api;
                                            await api.updateVisit(visitId, {'isApproved': true});
                                            _loadAllData();
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    isAr ? '✅ تم التأشير والاعتماد الرسمي للمعاينة بنجاح' : 'Visite validée avec succès',
                                                    style: const TextStyle(fontFamily: 'Tajawal'),
                                                  ),
                                                  backgroundColor: const Color(0xFFD4AF37),
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('خطأ في التأشير: $e', style: const TextStyle(fontFamily: 'Tajawal')),
                                                  backgroundColor: Colors.redAccent,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                  icon: const Icon(Icons.verified, size: 16),
                                  label: Text(
                                    isAr ? '✓ تأشير واعتماد المحضر الآن' : 'Valider et viser le rapport maintenant',
                                    style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12.5),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD4AF37),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 2,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.verified, size: 16, color: Color(0xFF10B981)),
                                    const SizedBox(width: 6),
                                    Text(
                                      isAr ? 'مؤشر رسمياً ومعتمد من رئيس المصلحة' : 'Visé officiellement par le Chef de Service',
                                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                    ),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: visitId == 0
                                          ? null
                                          : () async {
                                              try {
                                                final api = context.read<AuthService>().api;
                                                await api.updateVisit(visitId, {'isApproved': false});
                                                _loadAllData();
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        isAr ? 'تم سحب التأشير — المعاينة معلقة مجدداً' : 'Visa retiré',
                                                        style: const TextStyle(fontFamily: 'Tajawal'),
                                                      ),
                                                      backgroundColor: Colors.orange,
                                                    ),
                                                  );
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.redAccent),
                                                  );
                                                }
                                              }
                                            },
                                      icon: const Icon(Icons.undo, size: 13, color: Colors.white54),
                                      label: Text(
                                        isAr ? 'سحب التأشير' : 'Annuler',
                                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.white54),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInspectorsPresenceTab() {
    final isAr = context.watch<LanguageProvider>().isArabic;
    final brigades = ['الكل', ...{for (var e in _departmentInspectors) (e['brigade'] ?? '').toString()}.where((b) => b.isNotEmpty)];

    final totalCount = _departmentInspectors.length;
    final presentCount = _departmentInspectors.where((e) => e['hasCheckedIn'] == true).length;
    final inFieldCount = _departmentInspectors.where((e) => e['hasCheckedIn'] == true && ((e['visitsCount'] as num?)?.toInt() ?? 0) > 0).length;
    final absentCount = totalCount - presentCount;

    final filtered = _departmentInspectors.where((insp) {
      final name = (insp['name'] ?? '').toString().toLowerCase();
      final brigade = (insp['brigade'] ?? '').toString();
      final matchesQuery = _inspectorSearchQuery.isEmpty || name.contains(_inspectorSearchQuery.toLowerCase());
      final matchesBrigade = _selectedBrigadeFilter == 'الكل' || brigade == _selectedBrigadeFilter;
      return matchesQuery && matchesBrigade;
    }).toList();

    return Column(
      children: [
        // ── TOP INFORMATIVE HEADER & ATTACH ACTION ───────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF240D2D),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.badge, color: Color(0xFFD4AF37), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'مفتشو المصلحة والجاهزية الميدانية' : 'Inspecteurs & État de Présence',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      _getDisplayDepartmentName(isAr),
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Color(0xFFD4AF37)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.person_add_alt_1, size: 15),
                label: Text(
                  isAr ? '+ إلحاق عون بالمصلحة' : '+ Affecter un agent',
                  style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 11),
                ),
                onPressed: _showAttachEmployeeDialog,
              ),
            ],
          ),
        ),

        // ── QUICK STATS ROW ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: const Color(0xFF1E0B26),
          child: Row(
            children: [
              _buildMiniStatCard(
                title: isAr ? 'إجمالي المفتشين' : 'Total',
                value: '$totalCount',
                icon: Icons.people_alt,
                color: const Color(0xFFD4AF37),
              ),
              const SizedBox(width: 6),
              _buildMiniStatCard(
                title: isAr ? 'حاضرون بالمقر' : 'Présents',
                value: '$presentCount',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF10B981),
              ),
              const SizedBox(width: 6),
              _buildMiniStatCard(
                title: isAr ? 'في الميدان' : 'En Terrain',
                value: '$inFieldCount',
                icon: Icons.travel_explore,
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 6),
              _buildMiniStatCard(
                title: isAr ? 'غير ملتحق' : 'Absents',
                value: '$absentCount',
                icon: Icons.timer_outlined,
                color: Colors.white54,
              ),
            ],
          ),
        ),

        // ── SEARCH & BRIGADE FILTER BAR ──────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: const Color(0xFF1E0B26),
          child: Column(
            children: [
              TextField(
                onChanged: (val) => setState(() => _inspectorSearchQuery = val),
                textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white),
                decoration: InputDecoration(
                  hintText: isAr ? 'بحث باسم المفتش أو الرتبة...' : 'Rechercher par nom ou grade...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.AccentColor, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: const Color(0xFF2D1035),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: brigades.map((b) {
                    final isSelected = _selectedBrigadeFilter == b;
                    return Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(
                          b,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 10.5,
                            color: isSelected ? Colors.black : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppTheme.AccentColor,
                        backgroundColor: const Color(0xFF2D1035),
                        onSelected: (sel) {
                          if (sel) setState(() => _selectedBrigadeFilter = b);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // ── INSPECTORS LIST ──────────────────────────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    isAr ? 'لا توجد نتائج مطابقة للبحث أو التصفية' : 'Aucun inspecteur trouvé',
                    style: const TextStyle(fontFamily: 'Tajawal', color: AppTheme.TextSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length + 1,
                  itemBuilder: (ctx, i) {
                    if (i == filtered.length) {
                      return const Column(
                        children: [
                          SizedBox(height: 10),
                          AppFooter(showDivider: false),
                          SizedBox(height: 10),
                        ],
                      );
                    }
                    final emp = filtered[i];
                    final bool isPresent = emp['hasCheckedIn'] == true;
                    final bool isOut = emp['isCheckedOut'] == true;
                    final bool isLeader = emp['isBrigadeLeader'] == true;
                    final String name = (emp['name'] ?? 'مفتش').toString();
                    final String grade = (emp['grade'] ?? 'مفتش رئيسي').toString();
                    final String brigade = (emp['brigade'] ?? 'فرقة الرقابة').toString();
                    final int visitsCount = (emp['visitsCount'] as num?)?.toInt() ?? 0;
                    final String location = (emp['location'] ?? 'المقر الرئيسي للمديرية').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.CardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isLeader
                              ? const Color(0xFFD4AF37).withValues(alpha: 0.5)
                              : (isPresent ? AppTheme.SuccessColor.withValues(alpha: 0.3) : AppTheme.BorderColor.withValues(alpha: 0.3)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: (isPresent ? AppTheme.SuccessColor : Colors.grey).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.person,
                                  color: isPresent ? AppTheme.SuccessColor : Colors.grey,
                                  size: 24,
                                ),
                              ),
                              if (isLeader)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFD4AF37),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.star, size: 10, color: Colors.black),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13.5, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isLeader) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: const Color(0xFFD4AF37), width: 0.5),
                                        ),
                                        child: Text(
                                          isAr ? 'رئيس فرقة' : 'Chef de brigade',
                                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 9, color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$grade • $brigade',
                                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.TextSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (isPresent) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${isAr ? "الموقع" : "Lieu"}: $location • $visitsCount ${isAr ? "معاينات" : "visites"}',
                                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Color(0xFF10B981)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isOut
                                      ? const Color(0xFF6B7280).withValues(alpha: 0.2)
                                      : (isPresent ? AppTheme.SuccessColor.withValues(alpha: 0.2) : AppTheme.WarningColor.withValues(alpha: 0.2)),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isOut ? (isAr ? 'انصرف' : 'Sorti') : (isPresent ? (isAr ? 'في الميدان' : 'Actif') : (isAr ? 'غير ملتحق' : 'Absent')),
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isOut ? Colors.grey : (isPresent ? AppTheme.SuccessColor : AppTheme.WarningColor),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () => _showEditBrigadeDialog(emp),
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.edit_note, size: 14, color: AppTheme.AccentColor),
                                      const SizedBox(width: 2),
                                      Text(
                                        isAr ? 'تعديل التشكيل' : 'Modifier',
                                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppTheme.AccentColor, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
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
    );
  }

  String _getDisplayDepartmentName(bool isAr) {
    if (_departmentName.contains('الإدارة')) {
      return isAr ? 'مصلحة الإدارة والوسائل' : 'Service Administration & Moyens';
    } else if (_departmentName.contains('المستهلك')) {
      return isAr ? 'مصلحة حماية المستهلك وقمع الغش' : 'Protection Consommateur & Fraudes';
    } else {
      return isAr ? 'مصلحة المنافسة والتحقيقات' : 'Concurrence & Enquêtes Éco.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final isAr = context.watch<LanguageProvider>().isArabic;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.BackgroundColor,
        appBar: ModernExecutiveNavbar(
          title: _getDisplayDepartmentName(isAr),
          subtitle: isAr
              ? 'المسؤول: ${user?.fullName ?? user?.username ?? ''} • مديرية التجارة سطيف'
              : 'Resp: ${user?.fullName ?? user?.username ?? ''} • Direction Commerce Sétif',
          badgeText: isAr ? 'رئيس مصلحة' : 'Chef de Service',
          showBackButton: Navigator.canPop(context),
          onBack: () => Navigator.pop(context),
          customTitleWidget: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _getDisplayDepartmentName(isAr),
                      style: const TextStyle(
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 3),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.swap_horiz, color: Color(0xFFD4AF37), size: 16),
                    tooltip: isAr ? 'تبديل المصلحة المعاينة' : 'Changer de service',
                    color: const Color(0xFF2D1035),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    onSelected: (val) {
                      setState(() {
                        _departmentName = val;
                        _isLoading = true;
                      });
                      _loadAllData();
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'مصلحة الإدارة والوسائل',
                        child: Row(
                          children: [
                            const Icon(Icons.badge, color: Color(0xFFD4AF37), size: 16),
                            const SizedBox(width: 8),
                            Text(isAr ? 'مصلحة الإدارة والوسائل (المستخدمين والوسائل)' : 'Administration & Moyens', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'مصلحة حماية المستهلك وقمع الغش',
                        child: Row(
                          children: [
                            const Icon(Icons.shield, color: Color(0xFF10B981), size: 16),
                            const SizedBox(width: 8),
                            Text(isAr ? 'مصلحة حماية المستهلك وقمع الغش' : 'Protection Consommateur & Fraudes', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'مصلحة المنافسة والتحقيقات الاقتصادية',
                        child: Row(
                          children: [
                            const Icon(Icons.query_stats, color: Color(0xFFD4AF37), size: 16),
                            const SizedBox(width: 8),
                            Text(isAr ? 'مصلحة المنافسة والتحقيقات الاقتصادية' : 'Concurrence & Enquêtes Éco.', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'مصلحة ملاحظة السوق وضبط التموين',
                        child: Row(
                          children: [
                            const Icon(Icons.storefront, color: Color(0xFFD4AF37), size: 16),
                            const SizedBox(width: 8),
                            Text(isAr ? 'مصلحة ملاحظة السوق وضبط التموين والأسعار' : 'Régulation du Marché & Prix', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'مصلحة المنازعات والشؤون القانونية',
                        child: Row(
                          children: [
                            const Icon(Icons.gavel, color: Color(0xFFEF4444), size: 16),
                            const SizedBox(width: 8),
                            Text(isAr ? 'مصلحة المنازعات والشؤون القانونية' : 'Contentieux & Affaires Juridiques', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      isAr ? 'رئيس مصلحة' : 'Chef Service',
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                isAr
                    ? 'المسؤول: ${user?.fullName ?? user?.username ?? ''} • مديرية التجارة سطيف'
                    : 'Resp: ${user?.fullName ?? user?.username ?? ''} • Dir. Commerce Sétif',
                style: const TextStyle(
                  fontSize: 9.0,
                  color: Color(0xFFD4AF37),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
          selectedIndex: _tabController.index,
          onTabSelected: (idx) {
            _tabController.animateTo(idx);
            setState(() {});
          },
          tabs: _isAdministration
              ? [
                  ModernNavTabItem(icon: Icons.badge_outlined, label: isAr ? 'المستخدمين والانضباط' : 'Personnel & Discipline'),
                  ModernNavTabItem(icon: Icons.apartment_outlined, label: isAr ? 'المقرات والبصمة الجغرافية' : 'Sièges & Géolocalisation'),
                  ModernNavTabItem(icon: Icons.account_balance_wallet_outlined, label: isAr ? 'المحاسبة والرواتب' : 'Comptabilité & Salaires'),
                ]
              : _isMarketRegulation
                  ? [
                      ModernNavTabItem(icon: Icons.storefront, label: isAr ? 'مرصد الأسعار وضبط السوق' : 'Observatoire Prix'),
                      ModernNavTabItem(icon: Icons.crisis_alert, label: isAr ? 'إخطارات التموين والإنذار' : 'Alertes Appro'),
                      ModernNavTabItem(icon: Icons.summarize, label: isAr ? 'النشرة اليومية لضبط السوق' : 'Bulletin Quotidien'),
                    ]
                  : _isContentieux
                      ? [
                          ModernNavTabItem(icon: Icons.gavel, label: isAr ? 'تدقيق محاضر المعاينة' : 'Contrôle des PVs'),
                          ModernNavTabItem(icon: Icons.lock_clock, label: isAr ? 'قرارات الغلق الإداري' : 'Fermetures'),
                          ModernNavTabItem(icon: Icons.account_balance, label: isAr ? 'المتابعة القضائية والمصالحة' : 'Contentieux & Justice'),
                        ]
                      : [
                          ModernNavTabItem(icon: Icons.assignment, label: isAr ? 'أوامر المهمة والبرامج' : 'Ordres de Mission'),
                          ModernNavTabItem(icon: Icons.fact_check, label: isAr ? 'تأشير المعاينات' : 'Validation Visites'),
                          ModernNavTabItem(icon: Icons.people_alt, label: isAr ? 'مفتشو المصلحة' : 'Inspecteurs'),
                        ],
          additionalActions: const [],
          onRefresh: _loadAllData,
          onPasswordChange: () => ChangePasswordDialog.show(context),
          onMasterPinChange: () => ChangeMasterPinDialog.show(context),
          onLogout: () {
            context.read<AuthService>().logout();
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
          },
        ),
        floatingActionButton: null,
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.AccentColor))
            : _isMarketRegulation
                ? MarketRegulationView(
                    departmentName: _departmentName,
                    onRefresh: _loadAllData,
                    tabController: _tabController,
                  )
                : _isContentieux
                    ? ContentieuxView(
                        departmentName: _departmentName,
                        onRefresh: _loadAllData,
                        tabController: _tabController,
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: _isAdministration
                            ? [
                                _buildAdministrationPersonnelTab(),
                                _buildAdministrationMeansTab(),
                                _buildAdministrationFinanceTab(),
                              ]
                            : [
                                _buildMissionsTab(),
                                _buildVisitsValidationTab(),
                                _buildInspectorsPresenceTab(),
                              ],
                      ),
      ),
    );
  }
}
