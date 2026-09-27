import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drh_setif_tracker/services/auth_service.dart';
import 'package:drh_setif_tracker/utils/theme.dart';
import 'package:drh_setif_tracker/providers/language_provider.dart';
import 'package:drh_setif_tracker/screens/auth/login_screen.dart';
import 'package:drh_setif_tracker/screens/director/director_screen.dart';
import 'package:drh_setif_tracker/screens/head/head_screen.dart';
import 'package:drh_setif_tracker/screens/bureau/bureau_screen.dart';
import 'package:drh_setif_tracker/screens/inspector/inspector_screen.dart';
import 'package:drh_setif_tracker/screens/common/change_password_dialog.dart';
import 'package:drh_setif_tracker/screens/common/change_master_pin_dialog.dart';
import 'package:drh_setif_tracker/screens/common/mandatory_security_setup_dialog.dart';
import 'package:drh_setif_tracker/screens/common/app_footer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:drh_setif_tracker/services/inspectorate_service.dart';
import 'package:drh_setif_tracker/utils/constants.dart';
import 'package:drh_setif_tracker/screens/common/qr_code_screen.dart';
import 'package:drh_setif_tracker/widgets/modern_executive_navbar.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _employees = [];
  String _morningGraceTime = '08:45';
  String _searchQuery = '';
  String _filterRole = 'all';
  int _currentPage = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = context.read<AuthService>();
      if (auth.currentUser?.mustChangeCredentials == true) {
        await MandatorySecuritySetupDialog.show(context);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final api = context.read<AuthService>().api;
      List<Map<String, dynamic>> usersList = [];
      List<Map<String, dynamic>> employeesList = [];
      Map<String, dynamic> settingsMap = {};

      try {
        usersList = await api.getSystemUsers();
      } catch (_) {}

      try {
        employeesList = await api.getEmployees(all: true);
      } catch (_) {}

      try {
        settingsMap = await api.getSettings();
      } catch (_) {}

      try {
        await InspectorateService.instance.loadInspectorates(api: api);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _users = usersList;
          _employees = employeesList;
          _morningGraceTime = (settingsMap['morning_grace_time'] ?? '08:45').toString();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    return _users.where((u) {
      final matchesSearch = _searchQuery.isEmpty ||
          (u['username'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (u['fullName'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (u['empNom'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (u['empPrenom'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRole = _filterRole == 'all' ||
          u['role'] == _filterRole ||
          (_filterRole == 'inactive' && u['isActive'] == false);
      return matchesSearch && matchesRole;
    }).toList();
  }

  List<Map<String, dynamic>> get _pagedUsers {
    final all = _filteredUsers;
    final start = _currentPage * _pageSize;
    if (start >= all.length) return [];
    return all.sublist(start, (start + _pageSize).clamp(0, all.length));
  }

  int get _totalPages => (_filteredUsers.length / _pageSize).ceil().clamp(1, 9999);


  void _showAddUserDialog() {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: '123456');
    final fullNameCtrl = TextEditingController();
    final pinCtrl = TextEditingController(text: '202600');  // default PIN — user must change on first login
    String selectedRole = 'inspector';
    String selectedDepartment = 'مصلحة حماية المستهلك وقمع الغش';
    int? selectedEmpId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF240D2D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF4A2050)),
          ),
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Color(0xFFD4AF37)),
              SizedBox(width: 10),
              Text(
                'إضافة مستخدم جديد للنظام',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameCtrl,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم (Login Username)',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.account_circle, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Color(0xFF1E0B26),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordCtrl,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور الابتدائية',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.lock, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Color(0xFF1E0B26),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fullNameCtrl,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                    decoration: const InputDecoration(
                      labelText: 'الاسم واللقب الكامل',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.badge, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Color(0xFF1E0B26),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2D1035),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                    decoration: const InputDecoration(
                      labelText: 'صلاحية / دور المستخدم',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.security, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Color(0xFF1E0B26),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'inspector', child: Text('مفتش ميداني (Inspector)')),
                      DropdownMenuItem(value: 'head_of_department', child: Text('رئيس مصلحة (Head of Service)')),
                      DropdownMenuItem(value: 'bureau_chief', child: Text('رئيس مكتب المستخدمين (Bureau Chief)')),
                      DropdownMenuItem(value: 'director', child: Text('المدير الولائي (Director)')),
                      DropdownMenuItem(value: 'admin', child: Text('مسؤول النظام (Admin)')),
                    ],
                    onChanged: (val) => setDialogState(() => selectedRole = val ?? 'inspector'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDepartment,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2D1035),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                    decoration: const InputDecoration(
                      labelText: 'المصلحة / الهيكل الإداري التابع له',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.business, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Color(0xFF1E0B26),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'مصلحة حماية المستهلك وقمع الغش',
                        child: Text('مصلحة حماية المستهلك وقمع الغش'),
                      ),
                      DropdownMenuItem(
                        value: 'مصلحة المنافسة والتحقيقات الاقتصادية',
                        child: Text('مصلحة المنافسة والتحقيقات الاقتصادية'),
                      ),
                      DropdownMenuItem(
                        value: 'مصلحة الإدارة والوسائل',
                        child: Text('مصلحة الإدارة والوسائل'),
                      ),
                      DropdownMenuItem(
                        value: 'الأمانة العامة / ديوان المدير',
                        child: Text('الأمانة العامة / ديوان المدير'),
                      ),
                    ],
                    onChanged: (val) => setDialogState(() => selectedDepartment = val ?? 'مصلحة حماية المستهلك وقمع الغش'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedEmpId,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2D1035),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'ربط بالموظف من القائمة (اختياري)',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.link, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Color(0xFF1E0B26),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          'بدون ربط (حساب إداري عام)',
                          style: TextStyle(fontFamily: 'Tajawal', color: Colors.white70),
                        ),
                      ),
                      ..._employees
                          .where((e) {
                            final nom = (e['Nom'] ?? '').toString().toLowerCase();
                            final nomAr = (e['NomAr'] ?? '').toString().toLowerCase();
                            return !nom.contains('tracker_admin') && !nomAr.contains('tracker_admin');
                          })
                          .map((e) {
                        final rawId = e['Id'] ?? e['id'];
                        final id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;
                        final nomAr = (e['NomAr'] ?? '').toString().trim();
                        final prenomAr = (e['PrenomAr'] ?? '').toString().trim();
                        final fullNameAr = '$nomAr $prenomAr'.trim();
                        final nomFr = (e['Nom'] ?? '').toString().trim();
                        final prenomFr = (e['Prenom'] ?? '').toString().trim();
                        final fullNameFr = '$nomFr $prenomFr'.trim();
                        final displayName = fullNameAr.isNotEmpty
                            ? fullNameAr
                            : (fullNameFr.isNotEmpty ? fullNameFr : 'موظف #$id');
                        final service = (e['Service'] ?? '').toString();
                        final matricule = (e['NumeroMatricule'] ?? '').toString();

                        return DropdownMenuItem<int?>(
                          value: id,
                          child: Row(
                            children: [
                              if (matricule.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4), width: 0.5),
                                  ),
                                  child: Text(
                                    matricule,
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD4AF37),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (service.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  service,
                                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.white54),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        selectedEmpId = val;
                        if (val != null) {
                          final emp = _employees.firstWhere(
                            (e) => (e['Id'] ?? e['id']) == val,
                            orElse: () => {},
                          );
                          if (emp.isNotEmpty) {
                            final nomAr = (emp['NomAr'] ?? '').toString().trim();
                            final prenomAr = (emp['PrenomAr'] ?? '').toString().trim();
                            final fullNameAr = '$nomAr $prenomAr'.trim();
                            final nomFr = (emp['Nom'] ?? '').toString().trim();
                            final prenomFr = (emp['Prenom'] ?? '').toString().trim();
                            final fullNameFr = '$nomFr $prenomFr'.trim();
                            fullNameCtrl.text = fullNameAr.isNotEmpty ? fullNameAr : fullNameFr;

                            if (usernameCtrl.text.isEmpty) {
                              final cleanNom = nomFr.isNotEmpty ? nomFr.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') : '';
                              final cleanPrenom = prenomFr.isNotEmpty ? prenomFr.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '') : '';
                              if (cleanPrenom.isNotEmpty && cleanNom.isNotEmpty) {
                                usernameCtrl.text = '$cleanPrenom.$cleanNom';
                              } else {
                                usernameCtrl.text = 'emp.$val';
                              }
                            }

                            final empService = (emp['Service'] ?? '').toString();
                            if (empService.isNotEmpty) {
                              if (empService.contains('مستهلك') || empService.contains('غش')) {
                                selectedDepartment = 'مصلحة حماية المستهلك وقمع الغش';
                              } else if (empService.contains('منافسة') || empService.contains('ممارسات')) {
                                selectedDepartment = 'مصلحة المنافسة والتحقيقات الاقتصادية';
                              } else if (empService.contains('إدارة') || empService.contains('وسائل') || empService.contains('مستخدمين')) {
                                selectedDepartment = 'مصلحة الإدارة والوسائل';
                              }
                            }

                            final fonction = (emp['FonctionExercee'] ?? '').toString();
                            if (fonction.contains('رئيس مصلحة')) {
                              selectedRole = 'head_of_department';
                            } else if (fonction.contains('رئيس مكتب')) {
                              selectedRole = 'bureau_chief';
                            } else if (fonction.contains('مدير')) {
                              selectedRole = 'director';
                            } else {
                              selectedRole = 'inspector';
                            }
                          }
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white60, fontFamily: 'Tajawal')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF881337),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (usernameCtrl.text.trim().isEmpty || passwordCtrl.text.trim().isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                final api = context.read<AuthService>().api;
                Navigator.pop(ctx);
                try {
                  final res = await api.createSystemUser(
                    username: usernameCtrl.text.trim(),
                    password: passwordCtrl.text.trim(),
                    fullName: fullNameCtrl.text.trim().isNotEmpty ? fullNameCtrl.text.trim() : usernameCtrl.text.trim(),
                    role: selectedRole,
                    service: selectedDepartment,
                    employeeId: selectedEmpId,
                    masterPin: pinCtrl.text.trim(),
                  );
                  _loadData();
                  messenger.showSnackBar(
                    SnackBar(content: Text(res['message']?.toString() ?? 'تم الحفظ'), backgroundColor: const Color(0xFF10B981)),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.DangerColor),
                  );
                }
              },
              child: const Text('إنشاء الحساب', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final fullNameCtrl = TextEditingController(text: user['fullName']?.toString() ?? '');
    String selectedRole = user['role']?.toString() ?? 'inspector';
    final userDept = (user['service'] ?? user['Service'] ?? 'مصلحة حماية المستهلك وقمع الغش').toString();
    const validDepts = [
      'مصلحة حماية المستهلك وقمع الغش',
      'مصلحة المنافسة والتحقيقات الاقتصادية',
      'مصلحة الإدارة والوسائل',
      'الأمانة العامة / ديوان المدير',
    ];
    String selectedDepartment = validDepts.contains(userDept) ? userDept : 'مصلحة حماية المستهلك وقمع الغش';
    bool isActive = user['isActive'] == true;
    int? selectedEmpId = user['employeeId'] is int ? user['employeeId'] as int : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF240D2D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF4A2050)),
          ),
          title: Row(
            children: [
              const Icon(Icons.edit, color: Color(0xFFD4AF37)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'تعديل حساب: ${user['username']}',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: fullNameCtrl,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                    decoration: const InputDecoration(
                      labelText: 'الاسم واللقب الكامل',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.badge, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Color(0xFF1E0B26),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2D1035),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                    decoration: const InputDecoration(
                      labelText: 'صلاحية / دور المستخدم',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.security, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Color(0xFF1E0B26),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'inspector', child: Text('مفتش ميداني (Inspector)')),
                      DropdownMenuItem(value: 'head_of_department', child: Text('رئيس مصلحة (Head of Service)')),
                      DropdownMenuItem(value: 'bureau_chief', child: Text('رئيس مكتب المستخدمين (Bureau Chief)')),
                      DropdownMenuItem(value: 'director', child: Text('المدير الولائي (Director)')),
                      DropdownMenuItem(value: 'admin', child: Text('مسؤول النظام (Admin)')),
                    ],
                    onChanged: (val) => setDialogState(() => selectedRole = val ?? 'inspector'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDepartment,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2D1035),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                    decoration: const InputDecoration(
                      labelText: 'المصلحة / الهيكل الإداري التابع له',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.business, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Color(0xFF1E0B26),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'مصلحة حماية المستهلك وقمع الغش',
                        child: Text('مصلحة حماية المستهلك وقمع الغش'),
                      ),
                      DropdownMenuItem(
                        value: 'مصلحة المنافسة والتحقيقات الاقتصادية',
                        child: Text('مصلحة المنافسة والتحقيقات الاقتصادية'),
                      ),
                      DropdownMenuItem(
                        value: 'مصلحة الإدارة والوسائل',
                        child: Text('مصلحة الإدارة والوسائل'),
                      ),
                      DropdownMenuItem(
                        value: 'الأمانة العامة / ديوان المدير',
                        child: Text('الأمانة العامة / ديوان المدير'),
                      ),
                    ],
                    onChanged: (val) => setDialogState(() => selectedDepartment = val ?? 'مصلحة حماية المستهلك وقمع الغش'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: selectedEmpId,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2D1035),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'ربط بالموظف من القائمة',
                      labelStyle: TextStyle(color: Colors.white70),
                      prefixIcon: Icon(Icons.link, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Color(0xFF1E0B26),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          'بدون ربط (حساب عام)',
                          style: TextStyle(fontFamily: 'Tajawal', color: Colors.white70),
                        ),
                      ),
                      ..._employees
                          .where((e) {
                            final nom = (e['Nom'] ?? '').toString().toLowerCase();
                            final nomAr = (e['NomAr'] ?? '').toString().toLowerCase();
                            return !nom.contains('tracker_admin') && !nomAr.contains('tracker_admin');
                          })
                          .map((e) {
                        final rawId = e['Id'] ?? e['id'];
                        final id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;
                        final name = '${e['NomAr'] ?? e['Nom'] ?? ''} ${e['PrenomAr'] ?? e['Prenom'] ?? ''}'.trim();
                        final displayName = name.isNotEmpty ? name : 'موظف #$id';
                        final service = (e['Service'] ?? '').toString();
                        final matricule = (e['NumeroMatricule'] ?? '').toString();
                        return DropdownMenuItem<int?>(
                          value: id,
                          child: Row(
                            children: [
                              if (matricule.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4), width: 0.5),
                                  ),
                                  child: Text(
                                    matricule,
                                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (service.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  service,
                                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.white54),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) => setDialogState(() => selectedEmpId = val),
                  ),
                  if (user['username'] != 'tracker_admin') ...[
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: Text(
                        isActive ? 'الحساب نشط (Active)' : 'الحساب موقوف / مجمّد (Suspended)',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          color: isActive ? const Color(0xFF10B981) : AppTheme.DangerColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      value: isActive,
                      activeThumbColor: const Color(0xFF10B981),
                      inactiveThumbColor: AppTheme.DangerColor,
                      onChanged: (val) => setDialogState(() => isActive = val),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white60, fontFamily: 'Tajawal')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF881337),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final api = context.read<AuthService>().api;
                Navigator.pop(ctx);
                try {
                  final res = await api.updateSystemUser(
                    id: user['id'] as int,
                    fullName: fullNameCtrl.text.trim().isNotEmpty ? fullNameCtrl.text.trim() : (user['username']?.toString() ?? ''),
                    role: selectedRole,
                    service: selectedDepartment,
                    isActive: isActive,
                    employeeId: selectedEmpId,
                  );
                  _loadData();
                  messenger.showSnackBar(
                    SnackBar(content: Text(res['message']?.toString() ?? 'تم تحديث الحساب بنجاح'), backgroundColor: const Color(0xFF10B981)),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.DangerColor),
                  );
                }
              },
              child: const Text('حفظ التعديلات', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteUserDialog(Map<String, dynamic> user) {
    if (user['username'] == 'tracker_admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن حذف الحساب الرئيسي لمدير النظام'),
          backgroundColor: AppTheme.DangerColor,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF240D2D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.DangerColor),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: AppTheme.DangerColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'حذف الحساب نهائياً: ${user['username']}',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من رغبتك في حذف حساب (${user['fullName'] ?? user['username']}) نهائياً من النظام؟ لا يمكن التراجع عن هذه الخطوة.',
          style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white60, fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.DangerColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final api = context.read<AuthService>().api;
                final res = await api.deleteSystemUser(user['id'] as int);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message']?.toString() ?? 'تم حذف الحساب بنجاح'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ في الحذف: $e'), backgroundColor: AppTheme.DangerColor),
                  );
                }
              }
            },
            child: const Text('نعم، حذف الحساب', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(Map<String, dynamic> user) {
    final newPassCtrl = TextEditingController(text: '123456');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF240D2D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF4A2050)),
        ),
        title: Row(
          children: [
            const Icon(Icons.key, color: Color(0xFFD4AF37)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'إعادة تعيين كلمة مرور: ${user['username']}',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
              'المستخدم: ${user['fullName'] ?? user['username']}',
              style: const TextStyle(color: Colors.white70, fontFamily: 'Tajawal', fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassCtrl,
              style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
              decoration: const InputDecoration(
                labelText: 'كلمة المرور الجديدة',
                labelStyle: TextStyle(color: Colors.white70),
                prefixIcon: Icon(Icons.lock_outline, color: Color(0xFFD4AF37)),
                filled: true,
                fillColor: Color(0xFF1E0B26),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white60, fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF881337),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (newPassCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                final api = context.read<AuthService>().api;
                final res = await api.resetUserPassword(
                  id: user['id'] as int,
                  newPassword: newPassCtrl.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res['message']?.toString() ?? 'تم التعيين بنجاح'), backgroundColor: const Color(0xFF10B981)),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.DangerColor),
                  );
                }
              }
            },

            child: const Text('حفظ كلمة المرور', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showResetPinDialog(Map<String, dynamic> user) {
    if (user['username'] == 'tracker_admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حساب مدير النظام التقني (tracker_admin) محمي سيادياً وممنوع إعادة ضبط رمزه من هنا'),
          backgroundColor: AppTheme.DangerColor,
        ),
      );
      return;
    }

    final newPinCtrl = TextEditingController(text: '202600');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF240D2D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD4AF37)),
        ),
        title: Row(
          children: [
            const Icon(Icons.pin, color: Color(0xFFD4AF37)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'إعادة ضبط رمز الأمان (PIN): ${user['username']}',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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
              'المسؤول: ${user['fullName'] ?? user['username']}',
              style: const TextStyle(color: Colors.white70, fontFamily: 'Tajawal', fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'الرمز الافتراضي لإعادة الضبط هو: 202600. عند تسجيل دخول المسؤول مجدداً، سيُفرض عليه تغيير رمزه وكلمة مروره.',
              style: TextStyle(color: Color(0xFFD4AF37), fontFamily: 'Tajawal', fontSize: 11),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPinCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', letterSpacing: 2),
              decoration: const InputDecoration(
                labelText: 'رمز الأمان (PIN) الجديد',
                labelStyle: TextStyle(color: Colors.white70, letterSpacing: 0),
                prefixIcon: Icon(Icons.pin_outlined, color: Color(0xFFD4AF37)),
                filled: true,
                fillColor: Color(0xFF1E0B26),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white60, fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: const Color(0xFF1A0A1F),
            ),
            onPressed: () async {
              final pin = newPinCtrl.text.trim();
              if (pin.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يجب ألا يقل الرمز عن 4 أرقام'), backgroundColor: AppTheme.DangerColor),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                final api = context.read<AuthService>().api;
                final res = await api.resetUserPin(
                  user['id'] as int,
                  newPin: pin,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message']?.toString() ?? 'تم إعادة تعيين رمز الأمان بنجاح'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                  _loadData();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.DangerColor),
                  );
                }
              }
            },
            child: const Text('إعادة ضبط الرمز', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCleanDataDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF240D2D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.DangerColor),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.DangerColor),
            SizedBox(width: 10),
            Text(
              'تصفير شامل للمنظومة وقاعدة البيانات',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من رغبتك في تصفير المنظومة وقاعدة البيانات بالكامل؟\n\n• سيتم حذف كافة حسابات المستخدمين (يبقى فقط حساب مدير النظام التقني tracker_admin).\n• سيتم تفريغ سجل الموظفين وكافة سجلات الحضور والانصراف والتدخلات الميدانية.\n• تصبح قاعدة البيانات بيضاء وجاهزة 100% لبدء دورة العمل الحقيقية.',
          style: TextStyle(fontFamily: 'Tajawal', color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white60, fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.DangerColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                final api = context.read<AuthService>().api;
                final res = await api.cleanTestData();
                await _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message']?.toString() ?? 'تم تصفير المنظومة بنجاح'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.DangerColor),
                  );
                }
              }
            },
            child: const Text('نعم، تصفير شامل للمنظومة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<LanguageProvider>().isArabic;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.BackgroundColor,
        appBar: ModernExecutiveNavbar(
          title: isAr ? 'الإدارة التقنية للمنظومة' : 'Administration Technique du Système',
          badgeText: 'Admin',
          subtitle: isAr ? 'التحكم في الخوادم وقواعد البيانات والمستخدمين' : 'Contrôle des serveurs, bases de données et utilisateurs',
          selectedIndex: _tabController.index,
          onTabSelected: (idx) {
            _tabController.animateTo(idx);
            setState(() {});
          },
          tabs: [
            ModernNavTabItem(icon: Icons.people_alt, label: isAr ? 'المستخدمين والحسابات' : 'Utilisateurs & Comptes'),
            ModernNavTabItem(icon: Icons.location_on, label: isAr ? 'المقرات والبصمة الجغرافية' : 'Sièges & Géolocalisation'),
            ModernNavTabItem(icon: Icons.dns, label: isAr ? 'حالة النظام والسيرفر' : 'État du Système & Serveur'),
            ModernNavTabItem(icon: Icons.preview, label: isAr ? 'معاينة شاشات الأدوار' : 'Aperçu des Rôles'),
          ],
          onRefresh: _loadData,
          onPasswordChange: () => ChangePasswordDialog.show(context),
          onMasterPinChange: () => ChangeMasterPinDialog.show(context),
          onLogout: () {
            context.read<AuthService>().logout();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildUsersTab(isAr),
            _buildInspectoratesTab(isAr),
            _buildSystemHealthTab(isAr),
            _buildRolePreviewTab(isAr),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab(bool isAr) {
    if (_isLoading && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
    }
    final activeCount = _users.where((u) => u['isActive'] == true).length;
    final inspectorsCount = _users.where((u) => u['role'] == 'inspector').length;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFD4AF37),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Row (Horizontally scrollable for all screens)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatCard('إجمالي الحسابات', '${_users.length}', Icons.account_circle, const Color(0xFF881337)),
                  const SizedBox(width: 8),
                  _buildStatCard('الحسابات النشطة', '$activeCount', Icons.check_circle, const Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  _buildStatCard('المفتشون الميدانيون', '$inspectorsCount', Icons.explore, const Color(0xFFD4AF37)),
                  const SizedBox(width: 8),
                  _buildStatCard('إجمالي الموظفين', '${_employees.length}', Icons.badge, const Color(0xFFEAB308)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Action Buttons Bar (Responsive Wrap)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _showAddUserDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: const Color(0xFF1A0A1F),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.person_add, size: 18, color: Color(0xFF1A0A1F)),
                  label: const Text(
                    'إضافة وتفعيل مستخدم جديد',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A0A1F)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _loadData,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD4AF37),
                    side: const BorderSide(color: Color(0x66D4AF37)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text(
                    'تحديث القائمة',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: Color(0xFFD4AF37), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'صلاحية إنشاء الحسابات وتعيين كلمات المرور محصورة بمدير النظام (الآدمن) حصراً، بربط الحساب بالموظف المسجل إدارياً.',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Master PIN Management Banner
            LayoutBuilder(
              builder: (ctx, constraints) {
                final isNarrow = constraints.maxWidth < 580;
                final bannerContent = Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shield, color: Color(0xFFD4AF37), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'منظومة الدرع المزدوج: رمز الأمان السري للمتصفح (Master PIN)',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'يمكنك في أي وقت تخصيص وتغيير رمز الأمان السري للدخول إلى حسابك من أي حاسوب أو متصفح ويب.',
                            style: TextStyle(fontFamily: 'Tajawal', color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final actionBtn = ElevatedButton.icon(
                  onPressed: () => ChangeMasterPinDialog.show(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: const Color(0xFF1A0A1F),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.key, size: 15, color: Color(0xFF1A0A1F)),
                  label: const Text(
                    'تغيير الرمز الآن',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1A0A1F)),
                  ),
                );

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E1236), Color(0xFF1F0926)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
                  ),
                  child: isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            bannerContent,
                            const SizedBox(height: 10),
                            actionBtn,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: bannerContent),
                            const SizedBox(width: 12),
                            actionBtn,
                          ],
                        ),
                );
              },
            ),
            const SizedBox(height: 14),

            // Search and Filter
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return Column(
                    children: [
                      TextField(
                        onChanged: (v) => setState(() { _searchQuery = v; _currentPage = 0; }),
                        style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'بحث باسم المستخدم أو الاسم أو اللقب...',
                          hintStyle: const TextStyle(color: Colors.white38, fontFamily: 'Tajawal', fontSize: 12),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37), size: 18),
                          filled: true,
                          fillColor: const Color(0xFF240D2D),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF4A2050)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF4A2050)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF240D2D),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF4A2050)),
                        ),
                        child: DropdownButton<String>(
                          value: _filterRole,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2D1035),
                          underline: const SizedBox(),
                          style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 12),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('جميع الأدوار')),
                            DropdownMenuItem(value: 'inspector', child: Text('المفتشون فقط')),
                            DropdownMenuItem(value: 'head_of_department', child: Text('رؤساء المصالح')),
                            DropdownMenuItem(value: 'bureau_chief', child: Text('رئيس مكتب المستخدمين')),
                            DropdownMenuItem(value: 'director', child: Text('المدير الولائي')),
                            DropdownMenuItem(value: 'admin', child: Text('مسؤولو النظام')),
                            DropdownMenuItem(value: 'inactive', child: Text('الحسابات المعطلة')),
                          ],
                          onChanged: (val) => setState(() { _filterRole = val ?? 'all'; _currentPage = 0; }),
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() { _searchQuery = v; _currentPage = 0; }),
                        style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                        decoration: InputDecoration(
                          hintText: 'بحث باسم المستخدم أو الاسم أو اللقب...',
                          hintStyle: const TextStyle(color: Colors.white38, fontFamily: 'Tajawal'),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37)),
                          filled: true,
                          fillColor: const Color(0xFF240D2D),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF4A2050)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF4A2050)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF240D2D),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF4A2050)),
                      ),
                      child: DropdownButton<String>(
                        value: _filterRole,
                        dropdownColor: const Color(0xFF2D1035),
                        underline: const SizedBox(),
                        style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('جميع الأدوار')),
                          DropdownMenuItem(value: 'inspector', child: Text('المفتشون فقط')),
                          DropdownMenuItem(value: 'head_of_department', child: Text('رؤساء المصالح')),
                          DropdownMenuItem(value: 'bureau_chief', child: Text('رئيس مكتب المستخدمين')),
                          DropdownMenuItem(value: 'director', child: Text('المدير الولائي')),
                          DropdownMenuItem(value: 'admin', child: Text('مسؤولو النظام')),
                          DropdownMenuItem(value: 'inactive', child: Text('الحسابات المعطلة')),
                        ],
                        onChanged: (val) => setState(() { _filterRole = val ?? 'all'; _currentPage = 0; }),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),

            // Users List header + pagination info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'قائمة المستخدمين (${_filteredUsers.length}):',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD4AF37),
                  ),
                ),
                if (_filteredUsers.length > _pageSize)
                  Text(
                    'صفحة ${_currentPage + 1} / $_totalPages',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                      color: Colors.white54,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (_filteredUsers.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF240D2D),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF4A2050)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.search_off, size: 36, color: Colors.white38),
                    SizedBox(height: 8),
                    Text(
                      'لا توجد حسابات مطابقة لمعايير البحث الحالية',
                      style: TextStyle(fontFamily: 'Tajawal', color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pagedUsers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final u = _pagedUsers[idx];
                final isActive = u['isActive'] == true;
                final roleStr = _formatRole(u['role']);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF240D2D),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFF4A2050)
                          : AppTheme.DangerColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Avatar + Name + Role Badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Avatar
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _getRoleColor(u['role']).withValues(alpha: 0.2),
                              border: Border.all(color: _getRoleColor(u['role'])),
                            ),
                            child: Center(
                              child: Icon(
                                _getRoleIcon(u['role']),
                                color: _getRoleColor(u['role']),
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Full Name & Service
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        u['fullName']?.toString() ?? u['username']?.toString() ?? 'مستخدم',
                                        style: const TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getRoleColor(u['role']).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: _getRoleColor(u['role']).withValues(alpha: 0.5)),
                                      ),
                                      child: Text(
                                        roleStr,
                                        style: TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _getRoleColor(u['role']),
                                        ),
                                      ),
                                    ),
                                    if (!isActive) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.DangerColor.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'معطل',
                                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 9, color: AppTheme.DangerColor),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if ((u['service'] ?? u['empService'] ?? '').toString().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    (u['service'] ?? u['empService']).toString(),
                                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white54),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(color: Color(0xFF381544), height: 1),
                      const SizedBox(height: 6),

                      // Bottom Row: Username + Compact Action Buttons (Responsive Wrap)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.login, size: 12, color: Color(0xFFD4AF37)),
                                const SizedBox(width: 4),
                                Text(
                                  'اسم الدخول: ${u['username']}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: Color(0xFFFCD34D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.edit_outlined, color: Color(0xFFD4AF37), size: 18),
                                tooltip: 'تعديل الحساب والصلاحية',
                                onPressed: () => _showEditUserDialog(u),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.key_outlined, color: Color(0xFFD4AF37), size: 18),
                                tooltip: 'إعادة تعيين كلمة المرور',
                                onPressed: () => _showResetPasswordDialog(u),
                              ),
                              if (u['username'] != 'tracker_admin') ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.pin_outlined, color: Color(0xFF10B981), size: 18),
                                  tooltip: 'إعادة ضبط رمز الأمان (PIN)',
                                  onPressed: () => _showResetPinDialog(u),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                  icon: Icon(
                                    isActive ? Icons.block_outlined : Icons.check_circle_outline,
                                    color: isActive ? Colors.orangeAccent : const Color(0xFF10B981),
                                    size: 18,
                                  ),
                                  tooltip: isActive ? 'تجميد / إيقاف الحساب' : 'تفعيل الحساب',
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    try {
                                      final api = context.read<AuthService>().api;
                                      await api.updateSystemUser(
                                        id: u['id'] as int,
                                        fullName: u['fullName']?.toString() ?? u['username']?.toString() ?? '',
                                        role: u['role']?.toString() ?? 'inspector',
                                        isActive: !isActive,
                                        employeeId: u['employeeId'] is int ? u['employeeId'] as int : null,
                                      );
                                      _loadData();
                                    } catch (e) {
                                      messenger.showSnackBar(
                                        SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.DangerColor),
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.all(4),
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.DangerColor, size: 18),
                                  tooltip: 'حذف الحساب نهائياً',
                                  onPressed: () => _showDeleteUserDialog(u),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // ── Pagination Controls ──────────────────────────────────────
            if (_filteredUsers.length > _pageSize)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A0A22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Previous
                    TextButton.icon(
                      onPressed: _currentPage > 0
                          ? () => setState(() => _currentPage--)
                          : null,
                      icon: const Icon(Icons.chevron_right, size: 20),
                      label: const Text('السابق', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
                      style: TextButton.styleFrom(
                        foregroundColor: _currentPage > 0
                            ? const Color(0xFFD4AF37)
                            : Colors.white24,
                      ),
                    ),
                    // Page indicator dots
                    Text(
                      '${_currentPage + 1}  /  $_totalPages',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        color: Color(0xFFD4AF37),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Next
                    TextButton.icon(
                      onPressed: _currentPage < _totalPages - 1
                          ? () => setState(() => _currentPage++)
                          : null,
                      icon: const Icon(Icons.chevron_left, size: 20),
                      label: const Text('التالي', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
                      style: TextButton.styleFrom(
                        foregroundColor: _currentPage < _totalPages - 1
                            ? const Color(0xFFD4AF37)
                            : Colors.white24,
                      ),
                    ),
                  ],
                ),
              ),

            const AppFooter(),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }


  Widget _buildSystemHealthTab(bool isAr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'حالة الخادم وقاعدة البيانات السحابية:',
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37)),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF240D2D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF4A2050)),
            ),
            child: Column(
              children: [
                _buildHealthRow('حالة الخادم (API Status)', 'متصل ويعمل (Online)', Icons.check_circle, const Color(0xFF10B981)),
                const Divider(color: Color(0xFF3D1A45)),
                _buildHealthRow('بيئة الخادم السحابي', 'Render Web Service (Node.js Express)', Icons.cloud, const Color(0xFFD4AF37)),
                const Divider(color: Color(0xFF3D1A45)),
                _buildHealthRow('قاعدة البيانات النشطة', 'PostgreSQL Cloud Database', Icons.storage, const Color(0xFFD4AF37)),
                const Divider(color: Color(0xFF3D1A45)),
                _buildHealthRow('المنطقة الزمنية الرسمية', 'Africa/Algiers (UTC+1)', Icons.schedule, Colors.white70),
                const Divider(color: Color(0xFF3D1A45)),
                _buildHealthRow('إجمالي الموظفين المسجلين', '${_employees.length} موظف', Icons.people, Colors.white),
                const Divider(color: Color(0xFF3D1A45)),
                _buildHealthRow('إجمالي حسابات النظام', '${_users.length} حساب', Icons.account_box, Colors.white),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Morning Grace Setting Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E1C0A), Color(0xFF240D2D)],
              ),
              borderRadius: BorderRadius.circular(14),
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
                      child: const Icon(Icons.access_time_filled, color: Color(0xFFD4AF37), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'فترة التسامح الصباحية (Tolérance)',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFFD4AF37),
                        ),
                        overflow: TextOverflow.ellipsis,
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
                          items: const [
                            DropdownMenuItem(value: '08:15', child: Text('08:15 ص')),
                            DropdownMenuItem(value: '08:30', child: Text('08:30 ص')),
                            DropdownMenuItem(value: '08:45', child: Text('08:45 ص (موصى بها)')),
                            DropdownMenuItem(value: '09:00', child: Text('09:00 ص (مرونة)')),
                            DropdownMenuItem(value: '09:15', child: Text('09:15 ص')),
                          ],
                          onChanged: (val) async {
                            if (val != null && val != _morningGraceTime) {
                              try {
                                final api = context.read<AuthService>().api;
                                await api.updateSetting('morning_grace_time', val);
                                setState(() => _morningGraceTime = val);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✅ تم تعديل فترة التسامح الصباحية للنظام إلى $val'),
                                      backgroundColor: const Color(0xFF10B981),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('خطأ: $e'),
                                      backgroundColor: AppTheme.DangerColor,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'الحضور بين 08:00 و $_morningGraceTime ص يُعتبر حضوراً نظامياً، والتأخر يُحسب بعده.',
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'إجراءات الصيانة والتجهيز الميداني:',
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37)),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.DangerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.DangerColor.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cleaning_services, color: AppTheme.DangerColor, size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'إعادة تهيئة السجلات التشغيلية',
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.DangerColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _showCleanDataDialog,
                      child: const Text('إعادة تهيئة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'تصفير سجلات الحضور والمعاينات الميدانية لبدء دورة العمل الرقابية الجديدة مع الحفاظ على قاعدة بيانات الموظفين.',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: Colors.white60),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const AppFooter(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRolePreviewTab(bool isAr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.preview, color: Color(0xFFD4AF37), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAr
                      ? 'معاينة الشاشات بمختلف الأدوار والصلاحيات (Role Previews):'
                      : 'Aperçu des Écrans selon les Rôles et Permissions (Role Previews):',
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isAr
                ? 'تتيح لك هذه الميزة تجربة أي واجهة في المنظومة بكل صلاحياتها الحقيقية لمعاينة تسلسل وسير العمل (Workflow):'
                : 'Cette fonctionnalité vous permet de prévisualiser chaque interface avec ses autorisations réelles pour tester le workflow:',
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 14),

          // Hierarchy & Workflow Info Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E0B26),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_tree, color: Color(0xFFD4AF37), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isAr
                        ? 'تسلسل الأدوار الإدارية: المفتش الميداني يوثق المهمة والمعاينة ⬅️ رئيس المصلحة المعني يؤشر ويصادق ⬅️ رئيس مصلحة الإدارة والوسائل يتابع تعداد الموظفين واللوجستيك ⬅️ المدير الولائي يشرف على كامل الولاية ويعتمد الخصومات كآمر بالصرف الوحيد.'
                        : 'Hiérarchie administrative: L\'inspecteur documente la mission ⬅️ Le chef de service vise et valide ⬅️ Le chef de service administration suit les effectifs ⬅️ Le Directeur de Wilaya supervise et valide les déductions.',
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 1. Director
          _buildPreviewCard(
            title: isAr ? '1. شاشة المدير الولائي (Director View)' : '1. Écran du Directeur de Wilaya (Director View)',
            desc: isAr
                ? 'القيادة الإشرافية العامة، الخريطة الحية للمفتشين، إحصائيات المعاينات، وجداول الخصم المالي (الآمر بالصرف الوحيد).'
                : 'Supervision générale, carte en direct des inspecteurs, statistiques des visites et retenues sur salaire (Ordonnateur unique).',
            icon: Icons.shield_outlined,
            color: const Color(0xFFD4AF37),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DirectorScreen())),
          ),
          const SizedBox(height: 10),

          // 2. Head of Administration & Means
          _buildPreviewCard(
            title: isAr
                ? '2. شاشة رئيس مصلحة الإدارة والوسائل (Administration & Moyens)'
                : '2. Écran Chef de Service Administration & Moyens',
            desc: isAr
                ? 'تسيير وتعداد الموظفين المسجلين، الانضباط والحضور، متابعة المقرات والمفتشيات الثمانية، والرواتب طبقاً للأمر 06-03.'
                : 'Gestion des effectifs, présence et discipline, suivi des 8 sièges et contrôle de la paie selon l\'ordonnance 06-03.',
            icon: Icons.badge_outlined,
            color: const Color(0xFF10B981),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HeadScreen(initialDepartment: 'مصلحة الإدارة والوسائل'))),
          ),
          const SizedBox(height: 10),

          // 3. Head of Consumer Protection & Fraud
          _buildPreviewCard(
            title: isAr
                ? '3. شاشة رئيس مصلحة قمع الغش وحماية المستهلك (Fraude & Consommation)'
                : '3. Écran Chef de Service Repression des Fraudes & Consommation',
            desc: isAr
                ? 'إصدار أوامر المهمة الرقابية، تأشير ومصادقة محاضر المعاينة والمحجوزات وسحب العينات، ومتابعة فرق الرقابة الصحية.'
                : 'Ordres de mission, validation des procès-verbaux, saisies, prélèvements d\'échantillons et contrôle sanitaire.',
            icon: Icons.health_and_safety_outlined,
            color: const Color(0xFFE11D48),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HeadScreen(initialDepartment: 'مصلحة حماية المستهلك وقمع الغش'))),
          ),
          const SizedBox(height: 10),

          // 4. Head of Competition & Economic Inquiries
          _buildPreviewCard(
            title: isAr
                ? '4. شاشة رئيس مصلحة المنافسة والتحقيقات (Concurrence & Enquêtes)'
                : '4. Écran Chef de Service Concurrence & Enquêtes Économiques',
            desc: isAr
                ? 'برامج مراقبة الأسعار المقننة، تتبع سلاسل التوزيع، فواتير التوزيع والبيع، ومكافحة المضاربة غير المشروعة وتفريغ المخازن.'
                : 'Contrôle des prix réglementés, suivi de la distribution, facturation, lutte contre la spéculation et vérification des stocks.',
            icon: Icons.query_stats,
            color: const Color(0xFFD4AF37),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HeadScreen(initialDepartment: 'مصلحة المنافسة والتحقيقات الاقتصادية'))),
          ),
          const SizedBox(height: 10),

          // 5. Bureau Chief
          _buildPreviewCard(
            title: isAr
                ? '5. شاشة رئيس مكتب المستخدمين (Bureau du Personnel)'
                : '5. Écran Chef de Bureau du Personnel',
            desc: isAr
                ? 'السجلات الإدارية للموظفين الفعليين، متابعة الانضباط والتأخرات، توجيه الاستفسارات، وتنفيذ قرارات الخصم على كشف الراتب.'
                : 'Registres du personnel, suivi de la discipline et retards, demandes d\'explication et exécution des retenues.',
            icon: Icons.folder_shared_outlined,
            color: const Color(0xFF8B5CF6),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BureauScreen())),
          ),
          const SizedBox(height: 10),

          // 6. Field Inspector
          _buildPreviewCard(
            title: isAr
                ? '6. شاشة المفتش الميداني (Field Inspector View)'
                : '6. Écran Inspecteur de Terrain (Field Inspector)',
            desc: isAr
                ? 'تسجيل الحضور الصباحي بالبصمة الجغرافية GPS، توثيق المعاينات الميدانية والمخالفات، واستقبال أوامر المهمة.'
                : 'Pointage matinal par géolocalisation GPS, enregistrement des visites et réceptions des ordres de mission.',
            icon: Icons.explore,
            color: const Color(0xFFF59E0B),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InspectorScreen())),
          ),
          const SizedBox(height: 24),
          const AppFooter(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF240D2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                value,
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 20, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRow(String label, String value, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard({
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF240D2D),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.2),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  String _formatRole(dynamic role) {
    switch (role) {
      case 'admin':
        return 'مسؤول النظام (Admin)';
      case 'director':
        return 'المدير الولائي';
      case 'head_of_department':
        return 'رئيس مصلحة';
      case 'bureau_chief':
        return 'رئيس مكتب';
      case 'inspector':
      default:
        return 'مفتش ميداني';
    }
  }

  Widget _buildInspectoratesTab(bool isAr) {
    final list = InspectorateService.instance.inspectorates;

    return RefreshIndicator(
      onRefresh: () async {
        final api = context.read<AuthService>().api;
        await InspectorateService.instance.loadInspectorates(api: api);
        setState(() {});
      },
      color: const Color(0xFFD4AF37),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Information & Control Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E103A), Color(0xFF1E0B26)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.satellite_alt, color: Color(0xFFD4AF37), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'إدارة وضبط البصمات الجغرافية للمقرات والملحقات',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'تحديد إحداثيات GPS بدقة السنتيمتر وتعيين نطاق التسامح (نصف القطر) لكل ملحقة',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF10B981)),
                        ),
                        child: Text(
                          '${list.length} مقرات معتمدة',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            color: Color(0xFF10B981),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF3D1645)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showEditInspectorateDialog(null),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: const Color(0xFF1A0A1F),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.add_location_alt, size: 16),
                        label: const Text(
                          'إضافة مقر / ملحقة رقابية جديدة',
                          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _showResetInspectoratesDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFF87171),
                          side: const BorderSide(color: Color(0xFFF87171)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.restore, size: 16),
                        label: const Text(
                          'استعادة الإحداثيات الافتراضية الأصلية',
                          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // List of Inspectorates Cards
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final insp = list[index];
                return _buildInspectorateCard(insp);
              },
            ),
            const SizedBox(height: 24),
            const AppFooter(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInspectorateCard(InspectorateHQ insp) {
    IconData iconData = Icons.account_balance;
    Color iconColor = const Color(0xFFD4AF37);
    String typeLabel = 'مفتشية إقليمية';

    if (insp.isMainDirectorate || insp.id == 'hq_setif') {
      iconData = Icons.domain;
      iconColor = const Color(0xFFD4AF37);
      typeLabel = 'المقر الرئيسي للمديرية الولائية';
    } else if (insp.id.contains('airport')) {
      iconData = Icons.local_airport;
      iconColor = const Color(0xFF38BDF8);
      typeLabel = 'مفتشية حدودية لمراقبة الجودة';
    } else if (insp.id.startsWith('annex_')) {
      iconData = Icons.storefront;
      iconColor = const Color(0xFF34D399);
      typeLabel = 'ملحقة تجارية إقليمية';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E0B26),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: insp.isMainDirectorate ? const Color(0xFFD4AF37).withValues(alpha: 0.5) : const Color(0xFF3D1645),
          width: insp.isMainDirectorate ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insp.nameAr,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (insp.nameFr.isNotEmpty)
                      Text(
                        insp.nameFr,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: iconColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Coordinates and Radius details
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF14071A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2D1035)),
            ),
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.explore, size: 14, color: Color(0xFFD4AF37)),
                    const SizedBox(width: 4),
                    Text(
                      'خط العرض (Lat): ${insp.latitude.toStringAsFixed(6)}°',
                      style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.navigation, size: 14, color: Color(0xFFD4AF37)),
                    const SizedBox(width: 4),
                    Text(
                      'خط الطول (Lng): ${insp.longitude.toStringAsFixed(6)}°',
                      style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.radar, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      'نطاق البصمة: ${insp.radiusMeters.round()} متر',
                      style: const TextStyle(fontFamily: 'Tajawal', color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => QRCodeScreen.showOfficialBadge(context, insp),
                icon: const Icon(Icons.qr_code, size: 15, color: Color(0xFFD4AF37)),
                label: const Text(
                  'شهادة QR المقر',
                  style: TextStyle(fontFamily: 'Tajawal', color: Color(0xFFD4AF37), fontSize: 11),
                ),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: () => _showEditInspectorateDialog(insp),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E103A),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFD4AF37)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.edit_location_alt, size: 14, color: Color(0xFFD4AF37)),
                label: const Text(
                  'تعديل الإحداثيات والبصمة',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              if (!insp.isMainDirectorate) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFF87171)),
                  tooltip: 'حذف الملحقة',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showDeleteInspectorateDialog(insp),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showEditInspectorateDialog(InspectorateHQ? insp) {
    final isNew = insp == null;
    final nameArCtrl = TextEditingController(text: insp?.nameAr ?? '');
    final nameFrCtrl = TextEditingController(text: insp?.nameFr ?? '');
    final latCtrl = TextEditingController(text: insp != null ? insp.latitude.toString() : '36.190057');
    final lngCtrl = TextEditingController(text: insp != null ? insp.longitude.toString() : '5.399013');
    final radiusCtrl = TextEditingController(text: insp != null ? insp.radiusMeters.round().toString() : '600');
    bool isFetchingGps = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF240D2D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFD4AF37)),
          ),
          title: Row(
            children: [
              Icon(isNew ? Icons.add_location : Icons.edit_location_alt, color: const Color(0xFFD4AF37)),
              const SizedBox(width: 10),
              Text(
                isNew ? 'إضافة ملحقة / مقر رقابي جديد' : 'تعديل إحداثيات: ${insp.nameAr}',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Button to capture real-time GPS location on site
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        side: const BorderSide(color: Color(0xFF38BDF8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: isFetchingGps
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)))
                          : const Icon(Icons.my_location, size: 18),
                      label: Text(
                        isFetchingGps ? 'جاري التقاط إحداثيات GPS...' : '📍 التقاط إحداثيات موقعي الحالي (GPS)',
                        style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: isFetchingGps
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              setDialogState(() => isFetchingGps = true);
                              try {
                                LocationPermission perm = await Geolocator.checkPermission();
                                if (perm == LocationPermission.denied) {
                                  perm = await Geolocator.requestPermission();
                                }
                                final pos = await Geolocator.getCurrentPosition(
                                  desiredAccuracy: LocationAccuracy.high,
                                );
                                setDialogState(() {
                                  latCtrl.text = pos.latitude.toStringAsFixed(7);
                                  lngCtrl.text = pos.longitude.toStringAsFixed(7);
                                  isFetchingGps = false;
                                });
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('تم جلب موقعك الدقيق: (${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)})'),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              } catch (e) {
                                setDialogState(() => isFetchingGps = false);
                                messenger.showSnackBar(
                                  SnackBar(content: Text('تعذر جلب GPS: $e'), backgroundColor: AppTheme.DangerColor),
                                );
                              }
                            },
                    ),
                  ),
                  TextField(
                    controller: nameArCtrl,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                    decoration: const InputDecoration(
                      labelText: 'الاسم الرسمي بالعربية (مثال: الملحقة التجارية — عين الكبيرة)',
                      labelStyle: TextStyle(color: Colors.white70, fontSize: 12),
                      prefixIcon: Icon(Icons.business, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Color(0xFF1E0B26),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameFrCtrl,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                    decoration: const InputDecoration(
                      labelText: 'الاسم بالفرنسية (Nom en Français)',
                      labelStyle: TextStyle(color: Colors.white70, fontSize: 12),
                      prefixIcon: Icon(Icons.translate, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Color(0xFF1E0B26),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: latCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                          decoration: const InputDecoration(
                            labelText: 'خط العرض (Latitude)',
                            labelStyle: TextStyle(color: Colors.white70, fontSize: 12),
                            prefixIcon: Icon(Icons.explore, color: Color(0xFFD4AF37)),
                            filled: true,
                            fillColor: Color(0xFF1E0B26),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: lngCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                          decoration: const InputDecoration(
                            labelText: 'خط الطول (Longitude)',
                            labelStyle: TextStyle(color: Colors.white70, fontSize: 12),
                            prefixIcon: Icon(Icons.navigation, color: Color(0xFFD4AF37)),
                            filled: true,
                            fillColor: Color(0xFF1E0B26),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: radiusCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                    decoration: const InputDecoration(
                      labelText: 'نطاق الحضور الجغرافي بالأمتار (Radius: 150، 250، 500، 1000)',
                      labelStyle: TextStyle(color: Colors.white70, fontSize: 12),
                      prefixIcon: Icon(Icons.radar, color: Color(0xFF10B981)),
                      filled: true,
                      fillColor: Color(0xFF1E0B26),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white60, fontFamily: 'Tajawal')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: const Color(0xFF1A0A1F),
              ),
              onPressed: () async {
                if (nameArCtrl.text.trim().isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                final lat = double.tryParse(latCtrl.text.trim()) ?? 36.190057;
                final lng = double.tryParse(lngCtrl.text.trim()) ?? 5.399013;
                final rad = double.tryParse(radiusCtrl.text.trim()) ?? 600.0;

                final updated = InspectorateHQ(
                  id: insp?.id ?? 'insp_${DateTime.now().millisecondsSinceEpoch}',
                  nameAr: nameArCtrl.text.trim(),
                  nameFr: nameFrCtrl.text.trim(),
                  latitude: lat,
                  longitude: lng,
                  radiusMeters: rad,
                  isMainDirectorate: insp?.isMainDirectorate ?? false,
                );

                Navigator.pop(ctx);
                final api = context.read<AuthService>().api;
                await InspectorateService.instance.updateInspectorate(updated, api: api);
                setState(() {});

                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('تم حفظ وتحديث الإحداثيات والبصمة الجغرافية بنجاح 📍'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              },
              child: Text(isNew ? 'إضافة المقر' : 'حفظ التعديلات', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteInspectorateDialog(InspectorateHQ insp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF240D2D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.DangerColor),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.DangerColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'حذف الملحقة: ${insp.nameAr}',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف ${insp.nameAr} من قائمة المقرات المعتمدة للبصمة الجغرافية؟',
          style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white60, fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.DangerColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final api = context.read<AuthService>().api;
              await InspectorateService.instance.deleteInspectorate(insp.id, api: api);
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حذف الملحقة بنجاح'), backgroundColor: Color(0xFF10B981)),
                );
              }
            },
            child: const Text('نعم، تأكيد الحذف', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showResetInspectoratesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF240D2D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD4AF37)),
        ),
        title: const Row(
          children: [
            Icon(Icons.restore, color: Color(0xFFD4AF37)),
            SizedBox(width: 10),
            Text(
              'استعادة الإحداثيات الأصلية',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: const Text(
          'هل تريد إعادة ضبط جميع إحداثيات ونطاقات المقرات والملحقات الثمانية إلى القيم الافتراضية الأصلية؟',
          style: TextStyle(fontFamily: 'Tajawal', color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white60, fontFamily: 'Tajawal')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: const Color(0xFF1A0A1F),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final api = context.read<AuthService>().api;
              await InspectorateService.instance.resetToDefaults(api: api);
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تمت استعادة الإحداثيات الافتراضية بنجاح'), backgroundColor: Color(0xFF10B981)),
                );
              }
            },
            child: const Text('نعم، استعادة الافتراضي', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(dynamic role) {
    switch (role) {
      case 'admin':
        return const Color(0xFFD4AF37);
      case 'director':
        return const Color(0xFFF59E0B);
      case 'head_of_department':
        return const Color(0xFFD4AF37);
      case 'bureau_chief':
        return const Color(0xFF10B981);
      case 'inspector':
      default:
        return const Color(0xFFE11D48);
    }
  }

  IconData _getRoleIcon(dynamic role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'director':
        return Icons.shield;
      case 'head_of_department':
        return Icons.business_center;
      case 'bureau_chief':
        return Icons.badge;
      case 'inspector':
      default:
        return Icons.explore;
    }
  }
}
