import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drh_setif_tracker/services/auth_service.dart';
import 'package:drh_setif_tracker/utils/theme.dart';
import 'package:drh_setif_tracker/utils/app_localizations.dart';
import 'package:drh_setif_tracker/screens/auth/login_screen.dart';
import 'package:drh_setif_tracker/screens/common/justifications_review_screen.dart';
import 'package:drh_setif_tracker/screens/common/inquiry_letter_dialog.dart';
import 'package:drh_setif_tracker/screens/common/change_password_dialog.dart';
import 'package:drh_setif_tracker/screens/common/change_master_pin_dialog.dart';
import 'package:drh_setif_tracker/screens/common/mandatory_security_setup_dialog.dart';
import 'package:drh_setif_tracker/screens/common/app_footer.dart';
import 'package:drh_setif_tracker/widgets/modern_executive_navbar.dart';
import 'package:drh_setif_tracker/providers/language_provider.dart';

class BureauScreen extends StatefulWidget {
  const BureauScreen({super.key});

  @override
  State<BureauScreen> createState() => _BureauScreenState();
}

class _BureauScreenState extends State<BureauScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _pollTimer;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _inquiries = [];
  List<Map<String, dynamic>> _delaysSummary = [];
  List<String> _departments = [];
  String _morningGraceTime = '08:45';
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, active, sick_leave, annual_leave, brigade

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadAll();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadAll(silent: true);
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

  Future<void> _loadAll({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final api = context.read<AuthService>().api;
      final emps = await api.getEmployees(all: true);
      final inqs = await api.getInquiries();
      final settings = await api.getSettings();
      final grace = (settings['morning_grace_time'] ?? '08:45').toString();
      final delays = await api.getDelaysSummary(graceTime: grace);
      final depts = await api.getAllDepartments();

      if (mounted) {
        setState(() {
          _employees = emps;
          _inquiries = inqs;
          _morningGraceTime = grace;
          _delaysSummary = delays;
          _departments = depts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateGraceTime(String newTime) async {
    try {
      final api = context.read<AuthService>().api;
      await api.updateSetting('morning_grace_time', newTime);
      setState(() => _morningGraceTime = newTime);
      final delays = await api.getDelaysSummary(graceTime: newTime);
      if (mounted) {
        setState(() => _delaysSummary = delays);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم ضبط فترة التسامح الصباحية إلى $newTime وتحديث حساب التأخرات'),
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

  Future<void> _executeDeductionInPayroll(int inquiryId, String name) async {
    try {
      final auth = context.read<AuthService>();
      final userId = auth.currentUser?.id ?? 1;
      await auth.api.executeInquiryDeduction(inquiryId, userId);
      _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم تدوين وتنفيذ الخصم رسمياً في كشف راتب $name'),
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

  void _showSendInquiryDialog(Map<String, dynamic> emp, {int? lateMinutes, String? defaultSubject, String? defaultDetails}) {
    final name = emp['NomAr'] != null
        ? '${emp['NomAr']} ${emp['PrenomAr'] ?? ''}'
        : '${emp['name'] ?? emp['Nom'] ?? ''} ${emp['Prenom'] ?? ''}';
    final empId = emp['EmployeeId'] ?? emp['employeeId'] ?? emp['Id'] ?? emp['id'];

    final subjectCtrl = TextEditingController(
      text: defaultSubject ?? (lateMinutes != null && lateMinutes > 0
          ? 'استفسار كتابي حول التأخر الصباحي عن العمل الميداني'
          : 'استفسار كتابي حول الانضباط والغياب عن العمل'),
    );
    final detailsCtrl = TextEditingController(
      text: defaultDetails ?? (lateMinutes != null && lateMinutes > 0
          ? 'بناءً على البصمة الجغرافية وسجلات الحضور، سُجل بحقكم تأخر صباحي قدره $lateMinutes دقيقة عن موعد العمل وفترة التسامح القانونية.'
          : 'بناءً على المعطيات المسجلة، لم تسجلوا أي حضور أو زيارات رقابية ميدانية في التاريخ المذكور دون ترخيص مسبق.'),
    );
    final minsCtrl = TextEditingController(text: lateMinutes != null ? lateMinutes.toString() : '0');

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
            const Icon(Icons.mail_outline, color: Color(0xFFD4AF37)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'توجيه استفسار إداري كتابي — $name',
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
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'مكتب المستخدمين يصدر هذا الاستفسار رسمياً ويمنح الموظف 48 ساعة لتقديم تبريراته عبر التطبيق:',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subjectCtrl,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  labelText: 'الموضوع',
                  labelStyle: const TextStyle(fontFamily: 'Tajawal', color: Color(0xFFD4AF37)),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: minsCtrl,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: 'دقائق التأخر المسجلة (إن وجدت)',
                  labelStyle: const TextStyle(fontFamily: 'Tajawal', color: Colors.white70),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detailsCtrl,
                maxLines: 3,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  labelText: 'تفاصيل الوقائع والإنذار',
                  labelStyle: const TextStyle(fontFamily: 'Tajawal', color: Colors.white70),
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (subjectCtrl.text.trim().isEmpty) return;
              try {
                final auth = context.read<AuthService>();
                final userId = auth.currentUser?.id ?? 1;
                final created = await auth.api.createInquiry({
                  'employeeId': empId,
                  'type': (int.tryParse(minsCtrl.text) ?? 0) > 0 ? 'late_arrival' : 'unjustified_absence',
                  'subject': subjectCtrl.text.trim(),
                  'lateMinutes': int.tryParse(minsCtrl.text) ?? 0,
                  'details': detailsCtrl.text.trim(),
                  'sentBy': userId,
                });

                if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ تم إرسال الاستفسار الإداري بنجاح إلى $name'),
                    backgroundColor: AppTheme.SuccessColor,
                    action: SnackBarAction(
                      label: 'معاينة وطباعة',
                      textColor: Colors.black,
                      onPressed: () {
                        InquiryLetterDialog.show(context, created);
                      },
                    ),
                  ),
                );
                _loadAll();
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
            child: const Text('إرسال الاستفسار الرسمي', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddEmployeeDialog() {
    final matriculeCtrl = TextEditingController(
      text: 'MAT-${DateTime.now().year}-${(100 + _employees.length + 1)}',
    );
    final nomArCtrl = TextEditingController();
    final prenomArCtrl = TextEditingController();
    final nomFrCtrl = TextEditingController();
    final prenomFrCtrl = TextEditingController();
    final brigadeCtrl = TextEditingController();
    final customPositionCtrl = TextEditingController();

    String selectedDept = _departments.isNotEmpty
        ? _departments.first
        : 'مصلحة الإدارة والوسائل';

    final defaultDepts = [
      'مصلحة الإدارة والوسائل',
      'مكتب المستخدمين',
      'مكتب المنازعات والشؤون القانونية',
      'مكتب المحاسبة والوسائل',
      'مصلحة حماية المستهلك وقمع الغش',
      'مصلحة ملاحظة السوق ومراقبة الممارسات التجارية والمنافسة',
      'المقر الرئيسي للمديرية الولائية سطيف',
      'المفتشية الحدودية لمراقبة الجودة - مطار 8 ماي 1945',
      'المفتشية الإقليمية للتجارة - العلمة',
      'المفتشية الإقليمية للتجارة - عين ولمان',
      'المفتشية الإقليمية للتجارة - بوقاعة',
      'المفتشية الإقليمية للتجارة - عين الكبيرة',
      'الملحقة التجارية - عين آزال',
      'الملحقة التجارية - عين أرنات',
    ];

    final deptOptions = [
      ...defaultDepts,
      for (final d in _departments)
        if (!defaultDepts.contains(d)) d,
    ];

    if (!deptOptions.contains(selectedDept)) {
      selectedDept = deptOptions.first;
    }

    final gradeOptions = [
      'متصرف رئيسي',
      'متصرف مستشار',
      'متصرف',
      'مفتش رئيسي لقمع الغش',
      'محقق رئيسي للمنافسة والتحقيقات الاقتصادية',
      'مفتش رئيسي للنوعية وقمع الغش',
      'محقق رئيسي للمنافسة',
      'مفتش قمع الغش',
      'محقق اقتصادي',
      'عون مراقبة الجودة وقمع الغش',
      'عون معاينة الممارسات التجارية',
      'مهندس دولة في الإعلام الآلي',
      'مهندس دولة',
      'ملحق رئيسي للإدارة',
      'محاسب إداري رئيسي',
      'كاتب مديرية رئيسي',
      'عون إدارة',
    ];
    String selectedGrade = gradeOptions.first;

    final positionOptions = [
      'رئيس مكتب المستخدمين',
      'رئيس مكتب المنازعات والشؤون القانونية',
      'رئيس مكتب المحاسبة والوسائل',
      'رئيس مكتب ملاحظة السوق',
      'رئيس مكتب حماية المستهلك',
      'رئيس مصلحة الإدارة والوسائل',
      'رئيس مصلحة حماية المستهلك وقمع الغش',
      'رئيس مصلحة المنافسة والتحقيقات الاقتصادية',
      'المدير الولائي',
      'رئيس فرقة رقابية',
      'مفتش ميداني',
      'محقق ميداني',
      'عون مراقبة وتفتيش',
      'عضو فرقة تحقيق',
      'إداري / تسيير',
      'أخرى (كتابة يدوية مخصصة)...',
    ];
    String selectedPosition = positionOptions.first;

    bool isBrigadeLeader = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgContext, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E102F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add_alt_1, color: Color(0xFFD4AF37), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إدراج عون / موظف في السجل الإداري',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                    Text(
                      'صلاحيات رئيس مكتب المستخدمين • السجل الرسمي',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFFD4AF37), size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'يقوم مكتب المستخدمين بتسجيل المعطيات الإدارية، الرتبة والمصلحة. إنشاء حساب الدخول وتعيين كلمة المرور هو من صلاحية مدير النظام (الآدمن) حصراً.',
                            style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Matricule
                  TextField(
                    controller: matriculeCtrl,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: 'رقم التسجيل / الماتريكول (Matricule)',
                      labelStyle: const TextStyle(color: Color(0xFFD4AF37), fontFamily: 'Tajawal', fontSize: 12),
                      prefixIcon: const Icon(Icons.badge_outlined, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Nom & Prenom (Arabic)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nomArCtrl,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                          decoration: InputDecoration(
                            labelText: 'اللقب (بالعربية) *',
                            labelStyle: const TextStyle(color: Colors.white70, fontFamily: 'Tajawal', fontSize: 12),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: prenomArCtrl,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                          decoration: InputDecoration(
                            labelText: 'الاسم (بالعربية) *',
                            labelStyle: const TextStyle(color: Colors.white70, fontFamily: 'Tajawal', fontSize: 12),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Nom & Prenom (Latin - Optional)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nomFrCtrl,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                          decoration: InputDecoration(
                            labelText: 'Nom (Français)',
                            labelStyle: const TextStyle(color: Colors.white54, fontFamily: 'Tajawal', fontSize: 11),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: prenomFrCtrl,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                          decoration: InputDecoration(
                            labelText: 'Prénom (Français)',
                            labelStyle: const TextStyle(color: Colors.white54, fontFamily: 'Tajawal', fontSize: 11),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Department Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedDept,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF26123A),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'المصلحة أو المفتشية التابع لها *',
                      labelStyle: const TextStyle(color: Color(0xFFD4AF37), fontFamily: 'Tajawal', fontSize: 12),
                      prefixIcon: const Icon(Icons.apartment, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: deptOptions.map((d) => DropdownMenuItem(
                      value: d,
                      child: Text(d, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) setDlgState(() => selectedDept = v);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Grade Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedGrade,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF26123A),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'الرتبة الإدارية *',
                      labelStyle: const TextStyle(color: Colors.white70, fontFamily: 'Tajawal', fontSize: 12),
                      prefixIcon: const Icon(Icons.military_tech_outlined, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: gradeOptions.map((g) => DropdownMenuItem(
                      value: g,
                      child: Text(g, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) setDlgState(() => selectedGrade = v);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Position Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedPosition,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF26123A),
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal', fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'الوظيفة أو الصفة الممارسة *',
                      labelStyle: const TextStyle(color: Color(0xFFD4AF37), fontFamily: 'Tajawal', fontSize: 12),
                      prefixIcon: const Icon(Icons.work_outline, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: positionOptions.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) setDlgState(() => selectedPosition = v);
                    },
                  ),
                  if (selectedPosition == 'أخرى (كتابة يدوية مخصصة)...') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: customPositionCtrl,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                      decoration: InputDecoration(
                        labelText: 'اكتب المسمى الوظيفي الممارس *',
                        labelStyle: const TextStyle(color: Color(0xFFD4AF37), fontFamily: 'Tajawal', fontSize: 12),
                        prefixIcon: const Icon(Icons.edit_note, color: Color(0xFFD4AF37)),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Brigade Name
                  TextField(
                    controller: brigadeCtrl,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Tajawal'),
                    decoration: InputDecoration(
                      labelText: 'اسم الفرقة التابع لها (اختياري للفرق الرقابية)',
                      labelStyle: const TextStyle(color: Colors.white70, fontFamily: 'Tajawal', fontSize: 12),
                      prefixIcon: const Icon(Icons.groups_outlined, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Switch IsBrigadeLeader
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'الموظف رئيس فرقة رقابية (Chef de Brigade)',
                      style: TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'يمنح صلاحية إدارة وتوزيع المهام الميدانية لأعضاء فرقته',
                      style: TextStyle(fontFamily: 'Tajawal', color: Colors.white54, fontSize: 11),
                    ),
                    value: isBrigadeLeader,
                    activeThumbColor: const Color(0xFFD4AF37),
                    onChanged: (val) => setDlgState(() => isBrigadeLeader = val),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('إدراج في السجل الإداري', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              onPressed: () async {
                final authApi = context.read<AuthService>().api;
                final messenger = ScaffoldMessenger.of(context);
                final matricule = matriculeCtrl.text.trim();
                final nomAr = nomArCtrl.text.trim();
                final prenomAr = prenomArCtrl.text.trim();
                final nomFr = nomFrCtrl.text.trim().isNotEmpty ? nomFrCtrl.text.trim() : null;
                final prenomFr = prenomFrCtrl.text.trim().isNotEmpty ? prenomFrCtrl.text.trim() : null;
                final dept = selectedDept;
                final grade = selectedGrade;
                final position = (selectedPosition == 'أخرى (كتابة يدوية مخصصة)...' && customPositionCtrl.text.trim().isNotEmpty)
                    ? customPositionCtrl.text.trim()
                    : selectedPosition;
                final brigade = brigadeCtrl.text.trim().isNotEmpty ? brigadeCtrl.text.trim() : null;
                final leader = isBrigadeLeader;

                if (nomAr.isEmpty && (nomFr == null || nomFr.isEmpty)) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('يرجى إدخال لقب الموظف'),
                      backgroundColor: AppTheme.DangerColor,
                    ),
                  );
                  return;
                }
                if (prenomAr.isEmpty && (prenomFr == null || prenomFr.isEmpty)) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('يرجى إدخال اسم الموظف'),
                      backgroundColor: AppTheme.DangerColor,
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                setState(() => _isLoading = true);

                try {
                  final res = await authApi.createEmployee(
                    numeroMatricule: matricule,
                    nomAr: nomAr,
                    prenomAr: prenomAr,
                    nom: nomFr,
                    prenom: prenomFr,
                    service: dept,
                    grade: grade,
                    fonctionExercee: position,
                    brigadeName: brigade,
                    isBrigadeLeader: leader,
                  );

                  await _loadAll();

                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(res['message']?.toString() ?? '✅ تم إدراج الموظف في السجل الإداري بنجاح'),
                      backgroundColor: AppTheme.SuccessColor,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  setState(() => _isLoading = false);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('خطأ أثناء إدراج الموظف: $e'),
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

  void _openEditEmployeeModal(Map<String, dynamic> emp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditEmployeeStatusModal(
        employee: emp,
        departments: _departments,
        onSaved: () {
          Navigator.pop(ctx);
          _loadAll();
        },
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredEmployees {
    return _employees.where((e) {
      final nom = (e['Nom'] ?? '').toString().toLowerCase();
      final prenom = (e['Prenom'] ?? '').toString().toLowerCase();
      final nomAr = (e['NomAr'] ?? '').toString().toLowerCase();
      final prenomAr = (e['PrenomAr'] ?? '').toString().toLowerCase();
      final matricule = (e['NumeroMatricule'] ?? '').toString().toLowerCase();
      final grade = (e['Grade'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();

      final matchesSearch =
          q.isEmpty ||
          nom.contains(q) ||
          prenom.contains(q) ||
          nomAr.contains(q) ||
          prenomAr.contains(q) ||
          matricule.contains(q) ||
          grade.contains(q);

      if (!matchesSearch) return false;

      final status = (e['AdministrativeStatus'] ?? 'active').toString().toLowerCase();
      final isBrigade =
          e['IsBrigadeLeader'] == true || e['IsBrigadeLeader'] == 1;

      if (_statusFilter == 'active') return status == 'active';
      if (_statusFilter == 'sick_leave') return status == 'sick_leave';
      if (_statusFilter == 'annual_leave') return status == 'annual_leave';
      if (_statusFilter == 'brigade') return isBrigade;

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isAr = context.watch<LanguageProvider>().isArabic;
    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.BackgroundColor,
        appBar: ModernExecutiveNavbar(
          title: loc.roleBureau,
          badgeText: isAr ? 'الموارد البشرية والرواتب' : 'RH & Traitements',
          subtitle: isAr
              ? 'تسيير الموظفين والمسار المهني • مديرية التجارة سطيف'
              : 'Gestion du Personnel & Carrières • Dir. Commerce Sétif',
          selectedIndex: _tabController.index,
          onTabSelected: (idx) {
            _tabController.animateTo(idx);
            setState(() {});
          },
          tabs: [
            ModernNavTabItem(
              icon: Icons.people_alt,
              label: isAr ? 'الموظفون (${_employees.length})' : 'Agents (${_employees.length})',
            ),
            ModernNavTabItem(
              icon: Icons.gavel,
              label: isAr ? 'الانضباط والاستفسارات (${_inquiries.length})' : 'Discipline (${_inquiries.length})',
              badgeCount: _inquiries.where((i) => i['Status'] == 'deduction_ordered' || i['Status'] == 'sent').length,
            ),
            ModernNavTabItem(
              icon: Icons.assignment_turned_in,
              label: isAr ? 'التبريرات والشهادات' : 'Justifications & Certificats',
            ),
          ],
          additionalActions: [
            Builder(
              builder: (ctx) {
                final isSmall = MediaQuery.of(ctx).size.width < 600;
                if (isSmall) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      padding: const EdgeInsets.all(4),
                      icon: const Icon(Icons.person_add_alt_1, size: 16, color: Colors.black),
                      tooltip: isAr ? 'إدراج موظف جديد' : 'Nouvel Agent',
                      onPressed: _showAddEmployeeDialog,
                    ),
                  );
                }
                return ElevatedButton.icon(
                  onPressed: _showAddEmployeeDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.person_add_alt_1, size: 16, color: Colors.black),
                  label: Text(
                    isAr ? 'إدراج موظف' : 'Nouvel Agent',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
          ],
          onRefresh: _loadAll,
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
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildEmployeesTab(),
                  _buildInquiriesAndDisciplineTab(),
                  const JustificationsReviewScreen(),
                ],
              ),
      ),
    );
  }

  Widget _buildEmployeesTab() {
    final activeCount = _employees
        .where((e) => (e['AdministrativeStatus'] ?? 'active') == 'active')
        .length;
    final sickCount = _employees
        .where((e) => e['AdministrativeStatus'] == 'sick_leave')
        .length;
    final annualCount = _employees
        .where((e) => e['AdministrativeStatus'] == 'annual_leave')
        .length;
    final brigadeCount = _employees
        .where((e) => e['IsBrigadeLeader'] == true || e['IsBrigadeLeader'] == 1)
        .length;

    final filtered = _filteredEmployees;

    return Column(
      children: [
        // KPI Mini Stats Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E102F).withValues(alpha: 0.6),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.BorderColor.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              _buildMiniStat('الإجمالي', '${_employees.length}', Colors.white70),
              const SizedBox(width: 8),
              _buildMiniStat('مباشر', '$activeCount', AppTheme.SuccessColor),
              const SizedBox(width: 8),
              _buildMiniStat('عطلة مرضية', '$sickCount', const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              _buildMiniStat('عطلة سنوية', '$annualCount', const Color(0xFFD4AF37)),
              const SizedBox(width: 8),
              _buildMiniStat('رؤساء فرق', '$brigadeCount', const Color(0xFFEAB308)),
            ],
          ),
        ),

        // Section Header & Add Employee Action
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 450;
              return Row(
                children: [
                  const Icon(Icons.badge, color: Color(0xFFD4AF37), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isSmall ? 'سجل الموظفين' : 'سجل موظفي وأعوان الرقابة الإداري',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: isSmall ? 13.5 : 14.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _showAddEmployeeDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.person_add_alt_1, size: 16, color: Colors.black),
                    label: Text(
                      isSmall ? 'إدراج' : 'إدراج موظف',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Search Bar & Filter Chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white),
            decoration: InputDecoration(
              hintText: 'بحث بالاسم، اللقب، الرتبة، أو رقم التسجيل...',
              hintStyle: const TextStyle(
                fontFamily: 'Tajawal',
                color: Colors.white38,
                fontSize: 13,
              ),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37)),
              filled: true,
              fillColor: AppTheme.CardColor,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.BorderColor.withValues(alpha: 0.4),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37)),
              ),
            ),
          ),
        ),

        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _buildFilterChip('الكل (${_employees.length})', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('🟢 مباشرون ($activeCount)', 'active'),
              const SizedBox(width: 8),
              _buildFilterChip('🩺 عطلة مرضية ($sickCount)', 'sick_leave'),
              const SizedBox(width: 8),
              _buildFilterChip('🏖️ عطلة سنوية ($annualCount)', 'annual_leave'),
              const SizedBox(width: 8),
              _buildFilterChip('🎖️ رؤساء الفرق ($brigadeCount)', 'brigade'),
            ],
          ),
        ),

        // Employees List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _employees.isEmpty ? Icons.person_add_outlined : Icons.person_search,
                        size: 56,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _employees.isEmpty
                            ? 'لم يتم إدراج أي موظف بعد في السجل الإداري'
                            : 'لا توجد نتائج مطابقة للبحث',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.TextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _employees.isEmpty
                            ? 'بصفتك رئيس مكتب المستخدمين، قم بإدراج الأعوان وتعيين رتبهم ومصالحهم'
                            : 'جرّب تغيير كلمات البحث أو المرشح أعلاه',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          color: Colors.white38,
                        ),
                      ),
                      if (_employees.isEmpty) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showAddEmployeeDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.person_add_alt_1, size: 18, color: Colors.black),
                          label: const Text(
                            'إدراج أول عون في السجل الإداري',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: filtered.length + 1,
                  itemBuilder: (ctx, i) {
                    if (i == filtered.length) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 16, bottom: 8),
                        child: AppFooter(),
                      );
                    }
                    final emp = filtered[i];
                    return _buildEmployeeCard(emp);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 10,
                color: Colors.white60,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return InkWell(
      onTap: () => setState(() => _statusFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFD4AF37)
              : AppTheme.CardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFD4AF37)
                : AppTheme.BorderColor.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF1E102F) : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> emp) {
    final nomAr = emp['NomAr'] ?? '';
    final prenomAr = emp['PrenomAr'] ?? '';
    final name = nomAr.toString().isNotEmpty ? '$nomAr $prenomAr' : '${emp['Nom']} ${emp['Prenom']}';
    final matricule = emp['NumeroMatricule'] ?? '-';
    final grade = emp['Grade'] ?? 'غير محدد';
    final service = emp['Service'] ?? 'غير محدد';
    final function = (emp['FonctionExercee'] ?? '').toString();
    final status = emp['AdministrativeStatus'] ?? 'active';
    final isBrigade = emp['IsBrigadeLeader'] == true || emp['IsBrigadeLeader'] == 1;
    final brigadeName = (emp['BrigadeName'] ?? '').toString();

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'sick_leave':
        statusColor = const Color(0xFFF59E0B);
        statusLabel = 'عطلة مرضية';
        statusIcon = Icons.medical_services;
        break;
      case 'annual_leave':
        statusColor = const Color(0xFFD4AF37);
        statusLabel = 'عطلة سنوية';
        statusIcon = Icons.beach_access;
        break;
      case 'maternity_leave':
        statusColor = const Color(0xFFEC4899);
        statusLabel = 'عطلة أمومة';
        statusIcon = Icons.child_friendly;
        break;
      case 'special_mission':
        statusColor = const Color(0xFF8B5CF6);
        statusLabel = 'تكليف بمهمة';
        statusIcon = Icons.assignment_ind;
        break;
      case 'detached':
        statusColor = const Color(0xFF6B7280);
        statusLabel = 'انتداب';
        statusIcon = Icons.swap_horiz;
        break;
      default:
        statusColor = AppTheme.SuccessColor;
        statusLabel = 'مباشر للعمل';
        statusIcon = Icons.check_circle;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.CardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBrigade
              ? const Color(0xFFD4AF37).withValues(alpha: 0.5)
              : AppTheme.BorderColor.withValues(alpha: 0.25),
          width: isBrigade ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isBrigade
                        ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
                        : const Color(0xFF1E102F),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isBrigade
                          ? const Color(0xFFD4AF37)
                          : AppTheme.BorderColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isBrigade ? Icons.military_tech : Icons.person,
                      color: isBrigade ? const Color(0xFFD4AF37) : Colors.white70,
                      size: 22,
                    ),
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
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 12, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  statusLabel,
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'رقم التسجيل: $matricule | $grade',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          color: AppTheme.TextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Colors.white10),
            const SizedBox(height: 8),

            // Service & Function
            Row(
              children: [
                const Icon(Icons.business, size: 14, color: Color(0xFFD4AF37)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$service',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (function.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.work_outline, size: 14, color: Colors.white38),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'المنصب الممارس: $function',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Brigade Badge
            if (isBrigade) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Color(0xFFD4AF37)),
                    const SizedBox(width: 6),
                    Text(
                      'رئيس فرقة: ${brigadeName.isNotEmpty ? brigadeName : "فرقة تفتيش ومراقبة"}',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action Buttons
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openEditEmployeeModal(emp),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D1035),
                  foregroundColor: const Color(0xFFD4AF37),
                  elevation: 0,
                  side: BorderSide(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text(
                  'تعديل الوضعية الإدارية والتكليف (رئيس فرقة / عطلة / منصب)',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInquiriesAndDisciplineTab() {
    final pendingOrders = _inquiries.where((i) => i['Status'] == 'deduction_ordered').toList();

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: const Color(0xFFD4AF37),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Morning Grace Period Configuration Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF261C14), AppTheme.CardColor],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
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
                            DropdownMenuItem(value: '08:45', child: Text('08:45 ص (الموصى بها)')),
                            DropdownMenuItem(value: '09:00', child: Text('09:00 ص (مرونة قصوى)')),
                            DropdownMenuItem(value: '09:15', child: Text('09:15 ص')),
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
                  'الحضور بين 08:00 و $_morningGraceTime نظامي ومقبول، والتأخر يُحسب بعده.',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 2. Urgent Director Deduction Orders (Must Execute)
          if (pendingOrders.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.DangerColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.DangerColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gavel, color: AppTheme.DangerColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'أوامر خصم معتمدة من المدير الولائي واجبة التنفيذ على الراتب (${pendingOrders.length})',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.DangerColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ...pendingOrders.map((inq) {
              final name = inq['NomAr'] != null
                  ? '${inq['NomAr']} ${inq['PrenomAr'] ?? ''}'
                  : '${inq['Nom'] ?? ''} ${inq['Prenom'] ?? ''}';
              final days = inq['DeductionDays'] ?? 1.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.CardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.DangerColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.DangerColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'خصم $days يوم',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: AppTheme.DangerColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'السبب: ${inq['Subject']}',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70),
                    ),
                    if (inq['DirectorNotes'] != null)
                      Text(
                        'ملاحظات المدير: ${inq['DirectorNotes']}',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Color(0xFFD4AF37)),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => InquiryLetterDialog.show(context, inq),
                          icon: const Icon(Icons.picture_as_pdf, size: 14, color: Color(0xFFD4AF37)),
                          label: const Text('مقرر الخصم الرسمي', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFD4AF37))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFD4AF37)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () => _executeDeductionInPayroll(inq['Id'] as int, name),
                          icon: const Icon(Icons.check_circle, size: 16),
                          label: const Text('تأكيد التنفيذ في الراتب', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.DangerColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // 3. Automated Delay & Absence Calculator Header
          Row(
            children: [
              const Icon(Icons.history_toggle_off, color: Color(0xFFD4AF37), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'كشف حساب التأخرات المتراكمة ومقترحات الخصم القانونية',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFFD4AF37), size: 20),
                onPressed: _loadAll,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 4. Delay Summary List
          ...(_delaysSummary.where((d) {
            final lateDays = (d['lateDaysCount'] as num?)?.toInt() ?? 0;
            final lateMins = (d['totalLateMinutes'] as num?)?.toInt() ?? 0;
            return lateDays > 0 || lateMins > 0;
          }).take(15).map((del) {
            final name = (del['name'] ?? 'موظف').toString();
            final lateMins = (del['totalLateMinutes'] as num?)?.toInt() ?? 0;
            final lateHours = (del['totalLateHours'] as num?)?.toDouble() ?? 0.0;
            final lateDays = (del['lateDaysCount'] as num?)?.toInt() ?? 0;
            final suggestedDays = (del['suggestedDeductionDays'] as num?)?.toDouble() ?? 0.0;
            final bool hasDeduction = suggestedDays > 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.CardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (hasDeduction ? AppTheme.WarningColor : AppTheme.BorderColor).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: (hasDeduction ? AppTheme.WarningColor : AppTheme.AccentColor).withValues(alpha: 0.15),
                    child: Icon(
                      Icons.schedule,
                      color: hasDeduction ? AppTheme.WarningColor : AppTheme.AccentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$lateDays أيام تأخر بعد $_morningGraceTime — إجمالي: $lateHours ساعة ($lateMins دقيقة)',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 10,
                            color: AppTheme.TextSecondary,
                          ),
                        ),
                        if (hasDeduction)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'مقترح الخصم القانوني المحسوب: $suggestedDays يوم عمل',
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD4AF37),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showSendInquiryDialog(
                      del,
                      lateMinutes: lateMins,
                      defaultSubject: 'استفسار كتابي حول تراكم $lateHours ساعات تأخر صباحي',
                      defaultDetails: 'سُجل بحقكم تراكم $lateHours ساعات تأخر عن موعد العمل وفترة التسامح ($lateDays مرات). يرجى تقديم التبريرات خلال 48 ساعة.',
                    ),
                    icon: const Icon(Icons.send, size: 14),
                    label: const Text(
                      'توجيه استفسار',
                      style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            );
          })),

          const SizedBox(height: 18),

          // 5. Active Inquiries Section
          Row(
            children: [
              const Icon(Icons.mail, color: Color(0xFFD4AF37), size: 20),
              const SizedBox(width: 8),
              Text(
                'سجل الاستفسارات الإدارية ومتابعة الردود (${_inquiries.length})',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_inquiries.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'لا توجد استفسارات إدارية مسجلة حالياً',
                  style: TextStyle(fontFamily: 'Tajawal', color: AppTheme.TextSecondary),
                ),
              ),
            )
          else
            ..._inquiries.map((inq) {
              final nomAr = inq['NomAr'] ?? inq['nomar'] ?? inq['Nom'] ?? inq['nom'] ?? inq['name'] ?? inq['employeeName'] ?? '';
              final prenomAr = inq['PrenomAr'] ?? inq['prenomar'] ?? inq['Prenom'] ?? inq['prenom'] ?? '';
              final name = (nomAr.toString().trim().isNotEmpty || prenomAr.toString().trim().isNotEmpty)
                  ? '$nomAr $prenomAr'.trim()
                  : (inq['EmployeeName'] ?? inq['employee_name'] ?? 'عضو فرقة الرقابة والتفتيش').toString();
              final status = (inq['Status'] ?? inq['status'] ?? 'sent').toString();
              final subject = (inq['Subject'] ?? inq['subject'] ?? inq['Details'] ?? inq['details'] ?? 'استفسار إداري حول الانضباط ومواقيت العمل').toString();
              final reply = inq['EmployeeReply'] ?? inq['employeereply'] ?? inq['Reply'] ?? inq['reply'];
              final rawDate = (inq['IncidentDate'] ?? inq['incidentdate'] ?? inq['Date'] ?? inq['date'] ?? inq['CreatedAt'] ?? '').toString();
              final cleanDate = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;

              Color stCol = AppTheme.WarningColor;
              String stTxt = 'مرسل بانتظار رد الموظف';
              if (status == 'answered') {
                stCol = const Color(0xFFD4AF37);
                stTxt = 'تم الرد — بانتظار قرار المدير';
              } else if (status == 'justified') {
                stCol = AppTheme.SuccessColor;
                stTxt = '✅ محفوظ (مبرر مقبول)';
              } else if (status == 'warning') {
                stCol = Colors.orange;
                stTxt = '⚠️ تنبيه إداري';
              } else if (status == 'deduction_ordered') {
                stCol = AppTheme.DangerColor;
                stTxt = '❌ قرار خصم (${inq['DeductionDays'] ?? inq['deductiondays'] ?? 1} يوم)';
              } else if (status == 'executed') {
                stCol = Colors.green;
                stTxt = '✔️ تم التنفيذ في الراتب';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.CardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.BorderColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                name,
                                style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: stCol.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  stTxt,
                                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, fontWeight: FontWeight.bold, color: stCol),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subject,
                            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70),
                          ),
                          if (cleanDate.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'تاريخ الواقعة: $cleanDate',
                                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.white38),
                              ),
                            ),
                          if (reply != null && reply.toString().trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'رد الموظف: $reply',
                                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Color(0xFFD4AF37)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.print, color: Color(0xFFD4AF37), size: 20),
                      onPressed: () => InquiryLetterDialog.show(context, inq),
                      tooltip: 'معاينة وطباعة الاستمارة الرسمية',
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 16),
          const AppFooter(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _EditEmployeeStatusModal extends StatefulWidget {
  final Map<String, dynamic> employee;
  final List<String> departments;
  final VoidCallback onSaved;

  const _EditEmployeeStatusModal({
    required this.employee,
    required this.departments,
    required this.onSaved,
  });

  @override
  State<_EditEmployeeStatusModal> createState() =>
      _EditEmployeeStatusModalState();
}

class _EditEmployeeStatusModalState extends State<_EditEmployeeStatusModal> {
  late String _status;
  late bool _isBrigadeLeader;
  late TextEditingController _brigadeNameCtrl;
  late TextEditingController _functionCtrl;
  late TextEditingController _notesCtrl;
  String? _selectedDept;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final emp = widget.employee;
    _status = (emp['AdministrativeStatus'] ?? 'active').toString();
    _isBrigadeLeader =
        emp['IsBrigadeLeader'] == true || emp['IsBrigadeLeader'] == 1;
    _brigadeNameCtrl = TextEditingController(text: (emp['BrigadeName'] ?? '').toString());
    _functionCtrl = TextEditingController(text: (emp['FonctionExercee'] ?? '').toString());
    _notesCtrl = TextEditingController(text: (emp['StatusNotes'] ?? '').toString());
    _selectedDept = emp['Service']?.toString();

    if (emp['StatusStartDate'] != null) {
      _startDate = DateTime.tryParse(emp['StatusStartDate'].toString());
    }
    if (emp['StatusEndDate'] != null) {
      _endDate = DateTime.tryParse(emp['StatusEndDate'].toString());
    }
  }

  @override
  void dispose() {
    _brigadeNameCtrl.dispose();
    _functionCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final api = context.read<AuthService>().api;
      final empId = widget.employee['Id'] as int;

      await api.updateEmployeeAdminStatus(empId, {
        'administrativeStatus': _status,
        'statusStartDate': _startDate?.toIso8601String().split('T')[0],
        'statusEndDate': _endDate?.toIso8601String().split('T')[0],
        'statusNotes': _notesCtrl.text.trim(),
        'isBrigadeLeader': _isBrigadeLeader,
        'brigadeName': _brigadeNameCtrl.text.trim(),
        'assignedDepartment': _selectedDept,
        'assignedPosition': _functionCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم حفظ التعديلات الإدارية وتحديث وضعية الموظف بنجاح',
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
            backgroundColor: AppTheme.SuccessColor,
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.DangerColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.employee;
    final name = emp['NomAr'] != null && emp['NomAr'].toString().isNotEmpty
        ? '${emp['NomAr']} ${emp['PrenomAr']}'
        : '${emp['Nom']} ${emp['Prenom']}';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1E102F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.admin_panel_settings, color: Color(0xFFD4AF37)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تعديل الوضعية الإدارية: $name',
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
              const SizedBox(height: 4),
              Text(
                'الرتبة: ${emp['Grade'] ?? '-'} | رقم التسجيل: ${emp['NumeroMatricule'] ?? '-'}',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  color: AppTheme.TextSecondary,
                ),
              ),
              const SizedBox(height: 20),

              // Administrative Status Dropdown
              const Text(
                'الوضعية الإدارية الحالية:',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFFD4AF37),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.CardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.BorderColor.withValues(alpha: 0.3),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _status,
                    dropdownColor: const Color(0xFF2D1035),
                    isExpanded: true,
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      color: Colors.white,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('🟢 مباشر للعمل (في الخدمة الفعلية)'),
                      ),
                      DropdownMenuItem(
                        value: 'sick_leave',
                        child: Text('🩺 عطلة مرضية (قصيرة / طويلة المدى)'),
                      ),
                      DropdownMenuItem(
                        value: 'annual_leave',
                        child: Text('🏖️ عطلة سنوية / راحة قانونية'),
                      ),
                      DropdownMenuItem(
                        value: 'maternity_leave',
                        child: Text('👶 عطلة أمومة'),
                      ),
                      DropdownMenuItem(
                        value: 'special_mission',
                        child: Text('📜 تكليف بمهمة تفتيش خاصة / خارج الولاية'),
                      ),
                      DropdownMenuItem(
                        value: 'detached',
                        child: Text('🔄 انتداب لدى هيئة أخرى'),
                      ),
                      DropdownMenuItem(
                        value: 'disponibilite',
                        child: Text('⏸️ إحالة على الاستيداع'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _status = v);
                    },
                  ),
                ),
              ),

              // Dates if on leave
              if (_status != 'active') ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setState(() => _startDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.CardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'تاريخ البداية:',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 11,
                                  color: Colors.white60,
                                ),
                              ),
                              Text(
                                _startDate != null
                                    ? _startDate!.toIso8601String().split('T')[0]
                                    : 'اختر التاريخ',
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _endDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setState(() => _endDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.CardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'تاريخ النهاية:',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 11,
                                  color: Colors.white60,
                                ),
                              ),
                              Text(
                                _endDate != null
                                    ? _endDate!.toIso8601String().split('T')[0]
                                    : 'اختر التاريخ',
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 18),
              const Divider(color: Colors.white12),
              const SizedBox(height: 10),

              // Team Leader Assignment (رئيس فرقة)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isBrigadeLeader
                      ? const Color(0xFFD4AF37).withValues(alpha: 0.1)
                      : AppTheme.CardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isBrigadeLeader
                        ? const Color(0xFFD4AF37)
                        : Colors.white12,
                  ),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      thumbColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? const Color(0xFFD4AF37)
                            : Colors.white60,
                      ),
                      title: const Text(
                        '🎖️ تعيين الموظف كرئيس فرقة تفتيش ومراقبة',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: const Text(
                        'يمنحه شارة رئيس فرقة وتظهر إدارته للفرقة على الخريطة واللوحة',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                      value: _isBrigadeLeader,
                      onChanged: (v) => setState(() => _isBrigadeLeader = v),
                    ),
                    if (_isBrigadeLeader) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _brigadeNameCtrl,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          labelText: 'اسم أو رقم الفرقة التفتيشية',
                          labelStyle: const TextStyle(
                            fontFamily: 'Tajawal',
                            color: Color(0xFFD4AF37),
                          ),
                          hintText: 'مثال: فرقة العلمة 01 / فرقة قمع الغش المناوبة',
                          hintStyle: const TextStyle(
                            fontFamily: 'Tajawal',
                            color: Colors.white30,
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: const Color(0xFF1E102F),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 18),
              const Divider(color: Colors.white12),
              const SizedBox(height: 10),

              // Department Transfer & Position Change
              const Text(
                '🔄 تحويل المصلحة أو المنصب الممارس:',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFFD4AF37),
                ),
              ),
              const SizedBox(height: 8),

              if (widget.departments.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.CardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: widget.departments.contains(_selectedDept)
                          ? _selectedDept
                          : null,
                      hint: Text(
                        _selectedDept ?? 'اختر المصلحة / المكتب',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          color: Colors.white70,
                        ),
                      ),
                      dropdownColor: const Color(0xFF2D1035),
                      isExpanded: true,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        color: Colors.white,
                      ),
                      items: widget.departments.map((d) {
                        return DropdownMenuItem<String>(
                          value: d,
                          child: Text(d),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedDept = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              TextField(
                controller: _functionCtrl,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  labelText: 'المنصب الممارس الفعلي',
                  labelStyle: const TextStyle(
                    fontFamily: 'Tajawal',
                    color: Colors.white70,
                  ),
                  filled: true,
                  fillColor: AppTheme.CardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: _notesCtrl,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  color: Colors.white,
                ),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'ملاحظات إدارية / رقم القرار الإداري',
                  labelStyle: const TextStyle(
                    fontFamily: 'Tajawal',
                    color: Colors.white70,
                  ),
                  filled: true,
                  fillColor: AppTheme.CardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: const Color(0xFF1E102F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF1E102F),
                          ),
                        )
                      : const Icon(Icons.check_circle, size: 20),
                  label: Text(
                    _isSaving ? 'جارٍ الحفظ والتحديث...' : 'حفظ التعديلات الإدارية',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
