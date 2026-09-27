import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drh_setif_tracker/services/auth_service.dart';
import 'package:drh_setif_tracker/utils/theme.dart';
import 'package:drh_setif_tracker/utils/app_localizations.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:drh_setif_tracker/services/pdf_report_service.dart';
import 'package:drh_setif_tracker/screens/common/justifications_review_screen.dart';

class DirectorReportsTab extends StatefulWidget {
  const DirectorReportsTab({super.key});

  @override
  State<DirectorReportsTab> createState() => _DirectorReportsTabState();
}

class _DirectorReportsTabState extends State<DirectorReportsTab> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _attendance = [];
  List<Map<String, dynamic>> _deductions = [];
  List<Map<String, dynamic>> _programs = [];
  String _searchQuery = '';
  DateTime _selectedDate = DateTime.now();
  String _selectedFilter = 'absent'; // 'all', 'present', 'absent'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({DateTime? targetDate}) async {
    final date = targetDate ?? _selectedDate;
    setState(() {
      _isLoading = true;
      _selectedDate = date;
    });
    try {
      final api = context.read<AuthService>().api;
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final emp = await api.getEmployees();
      final cleanEmp = emp.where((e) {
        final nom = (e['NomAr'] ?? e['nomAr'] ?? '').toString();
        final service = (e['Service'] ?? e['service'] ?? '').toString();
        return !nom.contains('المدير الولائي') && !service.contains('المديرية الولائية');
      }).toList();
      final att = await api.getAttendance(date: dateStr);
      final ded = await api.getDeductions();
      final progs = await api.getPrograms();
      if (mounted) {
        setState(() {
          _employees = cleanEmp;
          _attendance = att;
          _deductions = ded;
          _programs = progs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
      _load(targetDate: picked);
    }
  }

  void _showProgramsDialog() {
    final loc = AppLocalizations.of(context);
    final checkedInIds = _attendance.map((a) => a['EmployeeId']).toSet();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF240D2D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF4A2050)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.assignment, color: Color(0xFF38BDF8), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.isArabic ? 'البرامج الرقابية وأوامر المهمة السارية' : 'Programmes et ordres de mission',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    loc.isArabic
                        ? 'متابعة برامج مصالح الرقابة الاقتصادية وقمع الغش'
                        : 'Suivi des programmes de contrôle et répression des fraudes',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 10,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          width: double.maxFinite,
          child: _programs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      loc.isArabic ? 'لا توجد برامج رقابية مسجلة حالياً' : 'Aucun programme enregistré actuellement',
                      style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white60),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _programs.map((p) {
                      final title = p['Title']?.toString() ?? (loc.isArabic ? 'برنامج رقابي' : 'Programme de contrôle');
                      final service = p['ServiceName']?.toString() ?? (loc.isArabic ? 'مصلحة الرقابة' : 'Service de contrôle');
                      final targetArea = p['TargetArea']?.toString() ?? (loc.isArabic ? 'ولاية سطيف' : 'Wilaya de Sétif');
                      final focus = p['FocusPoints']?.toString() ?? '';
                      final isConcurrence = service.contains('المنافسة') || service.toLowerCase().contains('concurrence');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E0B26),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isConcurrence
                                ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                                : const Color(0xFF10B981).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isConcurrence ? const Color(0xFF3B82F6) : const Color(0xFF10B981))
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    service,
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isConcurrence ? const Color(0xFF60A5FA) : const Color(0xFF34D399),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  loc.isArabic ? 'أمر مهمة ساري' : 'Ordre valide',
                                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Color(0xFF10B981)),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () async {
                                    final api = context.read<AuthService>().api;
                                    final messenger = ScaffoldMessenger.of(context);
                                    final nav = Navigator.of(ctx);

                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                        backgroundColor: const Color(0xFF1E0B26),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: Row(
                                          children: [
                                            const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444)),
                                            const SizedBox(width: 8),
                                            Text(
                                              loc.isArabic ? 'إلغاء سريان أمر المهمة' : 'Annuler l\'ordre de mission',
                                              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        content: Text(
                                          loc.isArabic
                                              ? 'هل أنت متأكد من إلغاء سريان هذا البرنامج الرقابي / أمر المهمة وإنهاء العمل به؟'
                                              : 'Êtes-vous sûr de vouloir annuler la validité de cet ordre de mission ?',
                                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(c, false),
                                            child: Text(loc.isArabic ? 'تراجع' : 'Retour', style: const TextStyle(fontFamily: 'Tajawal')),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                                            onPressed: () => Navigator.pop(c, true),
                                            child: Text(loc.isArabic ? 'تأكيد الإلغاء' : 'Confirmer l\'annulation', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      final progId = int.tryParse(p['Id']?.toString() ?? p['id']?.toString() ?? '0') ?? 0;
                                      final progTitle = (p['Title'] ?? p['title'] ?? '').toString();
                                      try {
                                        await api.deleteProgram(progId, title: progTitle);
                                        nav.pop();
                                        _load();
                                        messenger.showSnackBar(
                                          SnackBar(
                                            backgroundColor: const Color(0xFF10B981),
                                            content: Text(
                                              loc.isArabic ? 'تم إلغاء أمر المهمة بنجاح ✅' : 'Ordre de mission annulé ✅',
                                              style: const TextStyle(fontFamily: 'Tajawal'),
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            backgroundColor: const Color(0xFFEF4444),
                                            content: Text(e.toString()),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.cancel_outlined, color: Color(0xFFF87171), size: 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 13, color: Color(0xFFD4AF37)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${loc.isArabic ? "القطاع الإقليمي" : "Secteur"}: $targetArea',
                                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFFCD34D)),
                                  ),
                                ),
                              ],
                            ),
                            if (focus.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.center_focus_strong, size: 13, color: Colors.white54),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${loc.isArabic ? "أهداف المداهمة والرقابة" : "Objectifs"}: $focus',
                                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 10),
                            // Inspectors working on this department/program
                            Builder(
                              builder: (_) {
                                final targetS = service.toLowerCase();
                                var deptInspectors = _employees.where((e) {
                                  final s = (e['Service'] ?? '').toString().toLowerCase();
                                  if (targetS.contains('مستهلك') || targetS.contains('غش') || targetS.contains('consommation') || targetS.contains('fraude')) {
                                    return s.contains('مستهلك') || s.contains('غش') || s.contains('consommation');
                                  }
                                  if (targetS.contains('منافسة') || targetS.contains('تحقيق') || targetS.contains('concurrence') || targetS.contains('enqu')) {
                                    return s.contains('منافسة') || s.contains('تحقيق') || s.contains('concurrence');
                                  }
                                  return s.contains(targetS) || targetS.contains(s);
                                }).toList();

                                // If generic or empty, show sample active field inspectors
                                if (deptInspectors.isEmpty && _employees.isNotEmpty) {
                                  deptInspectors = _employees.take(6).toList();
                                }

                                if (deptInspectors.isEmpty) {
                                  return Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline, size: 14, color: Colors.amber),
                                        const SizedBox(width: 6),
                                        Text(
                                          loc.isArabic ? 'برنامج عام لم يتم تخصيص فرقة محددة له بعد' : 'Programme général (brigade non assignée)',
                                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.amber),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                final attendedCount = deptInspectors.where((emp) => checkedInIds.contains(emp['Id'])).length;

                                return Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.groups, size: 14, color: Color(0xFF38BDF8)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              loc.isArabic
                                                  ? 'الفرق المفتشية المكلفة بالمهمة (${deptInspectors.length} مفتشاً):'
                                                  : 'Brigades affectées (${deptInspectors.length} inspecteurs) :',
                                              style: const TextStyle(
                                                fontFamily: 'Tajawal',
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF38BDF8),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              loc.isArabic ? '🟢 $attendedCount بالميدان' : '🟢 $attendedCount sur terrain',
                                              style: const TextStyle(
                                                fontFamily: 'Tajawal',
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF34D399),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: deptInspectors.take(8).map((emp) {
                                          final isAttended = checkedInIds.contains(emp['Id']);
                                          final name = loc.isArabic
                                              ? '${emp['NomAr'] ?? emp['Nom'] ?? ''} ${emp['PrenomAr'] ?? emp['Prenom'] ?? ''}'.trim()
                                              : '${emp['Nom'] ?? emp['NomAr'] ?? ''} ${emp['Prenom'] ?? emp['PrenomAr'] ?? ''}'.trim();
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isAttended
                                                  ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                                  : Colors.white.withValues(alpha: 0.05),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isAttended
                                                    ? const Color(0xFF10B981).withValues(alpha: 0.6)
                                                    : Colors.white12,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isAttended ? Icons.check_circle : Icons.circle_outlined,
                                                  size: 11,
                                                  color: isAttended ? const Color(0xFF10B981) : Colors.white38,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  name.isNotEmpty ? name : 'مفتش #${emp['Id']}',
                                                  style: TextStyle(
                                                    fontFamily: 'Tajawal',
                                                    fontSize: 11,
                                                    color: isAttended ? Colors.white : Colors.white60,
                                                    fontWeight: isAttended ? FontWeight.bold : FontWeight.normal,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.isArabic ? 'إغلاق' : 'Fermer', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white70)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showNewProgramDialog();
            },
            icon: const Icon(Icons.add_task, size: 16),
            label: Text(
              loc.isArabic ? '+ تسطير برنامج ولائي جديد' : '+ Nouveau programme',
              style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: const Color(0xFF1E0B26),
            ),
          ),
        ],
      ),
    );
  }

  void _showNewProgramDialog() {
    final loc = AppLocalizations.of(context);
    final titleCtrl = TextEditingController(
      text: loc.isArabic
          ? 'برنامج ولائي لمراقبة الممارسات التجارية وقمع الغش'
          : 'Programme de Wilaya de contrôle des pratiques commerciales',
    );
    final areaCtrl = TextEditingController(
      text: loc.isArabic
          ? 'بلديات سطيف، العلمة، وعين ولمان'
          : 'Communes de Sétif, El Eulma et Ain Oulmene',
    );
    final focusCtrl = TextEditingController(
      text: loc.isArabic
          ? 'مراقبة الأسعار المقننة، الفوترة، ومطابقة المواد الاستهلاكية الحساسة'
          : 'Contrôle des prix réglementés, facturation et conformité des produits sensibles',
    );
    String selectedService = loc.isArabic ? 'مصلحة حماية المستهلك وقمع الغش' : 'Protection des consommateurs et répression des fraudes';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF240D2D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFD4AF37)),
          ),
          title: Row(
            children: [
              const Icon(Icons.add_task, color: Color(0xFFD4AF37), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  loc.isArabic ? 'تسطير برنامج رقابي ولائي جديد' : 'Nouveau programme de contrôle',
                  style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
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
                  Text(
                    loc.isArabic ? 'المصلحة المكلفة بالتنفيذ:' : 'Service chargé de l\'exécution :',
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedService,
                    dropdownColor: const Color(0xFF2D1035),
                    isExpanded: true,
                    style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: const Color(0xFF1E0B26),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: loc.isArabic ? 'مصلحة حماية المستهلك وقمع الغش' : 'Protection des consommateurs et répression des fraudes',
                        child: Text(loc.isArabic ? 'مصلحة حماية المستهلك وقمع الغش' : 'Protection des consommateurs et répression des fraudes'),
                      ),
                      DropdownMenuItem(
                        value: loc.isArabic ? 'مصلحة المنافسة والتحقيقات الاقتصادية' : 'Concurrence et enquêtes économiques',
                        child: Text(loc.isArabic ? 'مصلحة المنافسة والتحقيقات الاقتصادية' : 'Concurrence et enquêtes économiques'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedService = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    textDirection: loc.isArabic ? TextDirection.rtl : TextDirection.ltr,
                    style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: loc.isArabic ? 'عنوان البرنامج الرقابي / أمر المهمة *' : 'Titre du programme / Ordre de mission *',
                      labelStyle: const TextStyle(fontFamily: 'Tajawal', color: Colors.white70, fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: const Color(0xFF1E0B26),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: areaCtrl,
                    textDirection: loc.isArabic ? TextDirection.rtl : TextDirection.ltr,
                    style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: loc.isArabic ? 'القطاع الجغرافي المستهدف *' : 'Secteur géographique ciblé *',
                      labelStyle: const TextStyle(fontFamily: 'Tajawal', color: Colors.white70, fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: const Color(0xFF1E0B26),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: focusCtrl,
                    maxLines: 2,
                    textDirection: loc.isArabic ? TextDirection.rtl : TextDirection.ltr,
                    style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: loc.isArabic ? 'محاور التفتيش والأهداف الرئيسية' : 'Objectifs et axes prioritaires',
                      labelStyle: const TextStyle(fontFamily: 'Tajawal', color: Colors.white70, fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: const Color(0xFF1E0B26),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.isArabic ? 'إلغاء' : 'Annuler', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white70)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final area = areaCtrl.text.trim();
                final focus = focusCtrl.text.trim();
                if (title.isEmpty) return;

                Navigator.pop(ctx);
                setState(() => _isLoading = true);

                final messenger = ScaffoldMessenger.of(context);
                try {
                  final api = context.read<AuthService>().api;
                  final user = context.read<AuthService>().currentUser;
                  await api.createProgram(
                    title: title,
                    targetArea: area,
                    focusPoints: focus,
                    serviceName: selectedService,
                    createdBy: user?.id ?? 1,
                    type: 'provincial_mission',
                  );
                  await _load();
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          loc.isArabic ? '✅ تم تسطير وإسناد البرنامج الرقابي الولائي بنجاح' : '✅ Programme de contrôle validé et diffusé',
                          style: const TextStyle(fontFamily: 'Tajawal'),
                        ),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    messenger.showSnackBar(
                      SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.DangerColor),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check, color: Colors.black),
              label: Text(
                loc.isArabic ? 'إسناد وتسطير البرنامج' : 'Valider le programme',
                style: const TextStyle(fontFamily: 'Tajawal', color: Colors.black, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
      );
    }
    final loc = AppLocalizations.of(context);
    final checkedInMap = <dynamic, Map<String, dynamic>>{};
    for (final a in _attendance) {
      final empId = a['EmployeeId'] ?? a['employeeid'] ?? a['Id'];
      if (empId != null) {
        checkedInMap[empId] = a;
      }
    }

    final present = _employees
        .where((e) => checkedInMap.containsKey(e['Id']))
        .toList();
    final absent = _employees
        .where((e) => !checkedInMap.containsKey(e['Id']))
        .toList();

    List<Map<String, dynamic>> activeList;
    String filterTitle;
    String filterSubtitle;
    Color filterColor;

    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final dayNamesAr = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    final dayNamesFr = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    final monthNamesAr = [
      'جانفي', 'فيفري', 'مارس', 'أفريل', 'ماي', 'جوان',
      'جويلية', 'أوت', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    final monthNamesFr = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    final dayName = loc.isArabic ? dayNamesAr[_selectedDate.weekday - 1] : dayNamesFr[_selectedDate.weekday - 1];
    final monthName = loc.isArabic ? monthNamesAr[_selectedDate.month - 1] : monthNamesFr[_selectedDate.month - 1];
    final formattedDateStr = '$dayName ${_selectedDate.day} $monthName ${_selectedDate.year}';

    if (_selectedFilter == 'present') {
      activeList = present;
      filterTitle = isToday
          ? (loc.isArabic ? 'حاضرون اليوم (${present.length})' : 'Présents aujourd\'hui (${present.length})')
          : (loc.isArabic ? 'حاضرون يوم $formattedDateStr (${present.length})' : 'Présents le $formattedDateStr (${present.length})');
      filterSubtitle = loc.isArabic ? 'مسجلون رسمياً بالبصمة الجغرافية والـ GPS' : 'Pointage GPS validé';
      filterColor = AppTheme.SuccessColor;
    } else if (_selectedFilter == 'all') {
      activeList = _employees;
      filterTitle = loc.isArabic ? 'كافة موظفي الولاية (${_employees.length})' : 'Tous les agents de la Wilaya (${_employees.length})';
      filterSubtitle = loc.isArabic ? 'الوضعية الشاملة لكافة المصالح والمفتشيات' : 'Situation globale de tous les services';
      filterColor = const Color(0xFFD4AF37);
    } else {
      activeList = absent;
      filterTitle = isToday
          ? (loc.isArabic ? 'غائبين اليوم (${absent.length})' : 'Absents aujourd\'hui (${absent.length})')
          : (loc.isArabic ? 'غائبون يوم $formattedDateStr (${absent.length})' : 'Absents le $formattedDateStr (${absent.length})');
      filterSubtitle = isToday
          ? (loc.isArabic ? 'لم يسجلوا الحضور اليوم (يتطلب متابعة)' : 'Non pointés aujourd\'hui')
          : (loc.isArabic ? 'سجل الغياب المعتمد والمثبت في هذا التاريخ' : 'Registre des absences certifié');
      filterColor = AppTheme.DangerColor;
    }

    final q = _searchQuery.trim().toLowerCase();
    final filteredList = activeList.where((e) {
      if (q.isEmpty) return true;
      final nameAr = '${e['NomAr'] ?? ''} ${e['PrenomAr'] ?? ''}'.toLowerCase();
      final nameFr = '${e['Nom'] ?? ''} ${e['Prenom'] ?? ''}'.toLowerCase();
      final service = (e['Service'] ?? '').toString().toLowerCase();
      final matricule = (e['NumeroMatricule'] ?? '').toString().toLowerCase();
      return nameAr.contains(q) || nameFr.contains(q) || service.contains(q) || matricule.contains(q);
    }).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Date Selector & History Navigation Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isToday
                    ? [const Color(0xFF240D2D), const Color(0xFF16061D)]
                    : [const Color(0xFF3B1D11), const Color(0xFF240D2D)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isToday
                    ? const Color(0xFFD4AF37).withValues(alpha: 0.4)
                    : const Color(0xFFF59E0B),
                width: isToday ? 1.0 : 1.5,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: loc.isArabic ? 'اليوم السابق' : 'Jour précédent',
                  icon: const Icon(Icons.chevron_right, color: Color(0xFFD4AF37), size: 26),
                  onPressed: () {
                    final prevDate = _selectedDate.subtract(const Duration(days: 1));
                    _load(targetDate: prevDate);
                  },
                ),
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isToday ? Icons.calendar_today : Icons.history,
                                color: isToday ? const Color(0xFFD4AF37) : const Color(0xFFF59E0B),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  formattedDateStr,
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down, color: Color(0xFFD4AF37), size: 18),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isToday
                                ? (loc.isArabic ? '🟢 التقرير الرقابي الميداني (اليوم الجاري)' : '🟢 Rapport journalier de contrôle')
                                : (loc.isArabic ? 'سجل التدخلات الميدانية المؤرشف' : 'Archive historique certifiée'),
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 10,
                              fontWeight: isToday ? FontWeight.normal : FontWeight.bold,
                              color: isToday ? const Color(0xFF10B981) : const Color(0xFFFBBF24),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!isToday)
                  TextButton.icon(
                    onPressed: () => _load(targetDate: DateTime.now()),
                    icon: const Icon(Icons.today, color: Color(0xFF10B981), size: 14),
                    label: Text(
                      loc.isArabic ? 'العودة لليوم' : 'Aujourd\'hui',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                else
                  IconButton(
                    tooltip: loc.isArabic ? 'اليوم التالي' : 'Jour suivant',
                    icon: Icon(
                      Icons.chevron_left,
                      color: isToday ? Colors.white24 : const Color(0xFFD4AF37),
                      size: 26,
                    ),
                    onPressed: isToday
                        ? null
                        : () {
                            final nextDate = _selectedDate.add(const Duration(days: 1));
                            _load(targetDate: nextDate);
                          },
                  ),
              ],
            ),
          ),

          // Top Interactive Stat Cards
          Row(
            children: [
              _stat(
                loc.totalEmployees,
                _employees.length,
                AppTheme.AccentColor,
                Icons.people,
                'all',
              ),
              const SizedBox(width: 8),
              _stat(
                isToday ? loc.presentToday : (loc.isArabic ? 'حاضرون بالسجل' : 'Présents (Registre)'),
                present.length,
                AppTheme.SuccessColor,
                Icons.check_circle,
                'present',
              ),
              const SizedBox(width: 8),
              _stat(
                isToday ? loc.absentToday : (loc.isArabic ? 'غائبون بالسجل' : 'Absents (Registre)'),
                absent.length,
                AppTheme.DangerColor,
                Icons.cancel,
                'absent',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons: PDF Export, Programs Review, Justifications Review
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    PdfReportService.generateAndPrintDailyReport(
                      employees: _employees,
                      attendance: _attendance,
                      visits: [],
                      directorName: loc.isArabic ? 'السيد المدير الولائي' : 'Monsieur le Directeur de Wilaya',
                      reportDate: _selectedDate,
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.black, size: 16),
                  label: Text(
                    isToday
                        ? (loc.isArabic ? 'تصدير محضر PDF' : 'Exporter PV (PDF)')
                        : (loc.isArabic ? 'تصدير أرشيف PDF' : 'Exporter Archive (PDF)'),
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showProgramsDialog,
                  icon: const Icon(Icons.assignment, color: Colors.white, size: 16),
                  label: Text(
                    loc.isArabic ? 'البرامج الرقابية' : 'Programmes',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => JustificationsReviewScreen.show(context),
                  icon: const Icon(Icons.assignment_turned_in_outlined, color: Color(0xFF38BDF8), size: 16),
                  label: Text(
                    loc.isArabic ? 'مبررات الغياب' : 'Justifications',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Dynamic Section Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: filterColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: filterColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: filterColor),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      filterTitle,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: filterColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  filterSubtitle,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Live Search Bar
          TextField(
            textDirection: loc.isArabic ? TextDirection.rtl : TextDirection.ltr,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: loc.isArabic ? 'ابحث بالاسم، اللقب، المصلحة أو رقم التسجيل...' : 'Rechercher par nom, prénom, service ou matricule...',
              hintStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37)),
              filled: true,
              fillColor: AppTheme.CardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.BorderColor.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppTheme.BorderColor.withValues(alpha: 0.3)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(height: 14),

          filteredList.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.CardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.BorderColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          activeList.isEmpty ? Icons.check_circle : Icons.search_off,
                          size: 48,
                          color: activeList.isEmpty ? AppTheme.SuccessColor : AppTheme.TextSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          activeList.isEmpty
                              ? (_selectedFilter == 'absent' ? 'لا يوجد أي غياب اليوم ✅' : 'القائمة فارغة')
                              : 'لم يتم العثور على أي موظف يطابق البحث',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            color: AppTheme.TextSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: filteredList.asMap().entries.map((entry) {
                    final e = entry.value;
                    final isPresent = checkedInMap.containsKey(e['Id']);
                    final attRecord = checkedInMap[e['Id']];
                    final checkInTime = attRecord?['CheckInTime'] != null
                        ? _formatTime(attRecord!['CheckInTime'])
                        : '';

                    final name = e['NomAr'] != null
                        ? '${e['NomAr']} ${e['PrenomAr'] ?? ''}'.trim()
                        : '${e['Nom']} ${e['Prenom'] ?? ''}'.trim();

                    return GestureDetector(
                      onTap: () {
                        if (isPresent) {
                          _showPresentEmployeeDetails(e, attRecord);
                        } else {
                          _showAbsentEmployeeOptions(e);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.CardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isPresent
                                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                : AppTheme.BorderColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: (isPresent ? AppTheme.SuccessColor : AppTheme.DangerColor)
                                    .withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPresent ? Icons.check_circle : Icons.person_off,
                                color: isPresent ? AppTheme.SuccessColor : AppTheme.DangerColor,
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
                                          name,
                                          style: const TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      if (isPresent)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                                          ),
                                          child: Text(
                                            '🟢 حاضر: $checkInTime',
                                            style: const TextStyle(
                                              fontFamily: 'Tajawal',
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF10B981),
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            loc.isArabic ? '🔴 غير مسجل' : '🔴 Non Enregistré',
                                            style: const TextStyle(
                                              fontFamily: 'Tajawal',
                                              fontSize: 10,
                                              color: Color(0xFFF87171),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${e['Service'] ?? ''} • ${e['Grade'] ?? ''}',
                                    style: const TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 11,
                                      color: AppTheme.TextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_back_ios_new,
                              color: AppTheme.TextSecondary,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    ),
  ),
);
  }

  void _showAbsentEmployeeOptions(Map<String, dynamic> emp) {
    final loc = AppLocalizations.of(context);
    final name = !loc.isArabic && emp['Nom'] != null
        ? '${emp['Prenom'] ?? ''} ${emp['Nom'] ?? ''}'.trim()
        : (emp['NomAr'] != null
            ? '${emp['NomAr']} ${emp['PrenomAr'] ?? ''}'.trim()
            : '${emp['Nom'] ?? ''} ${emp['Prenom'] ?? ''}'.trim());
    final service = (emp['Service'] ?? (loc.isArabic ? 'مصلحة حماية المستهلك وقمع الغش' : 'Service Protection Consommateur')).toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: loc.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: const BoxDecoration(
            color: AppTheme.CardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.person_off, color: AppTheme.DangerColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loc.isArabic ? 'ملف الغياب والقرائن الرقمية' : 'Dossier d\'absence & Preuves numériques',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.BackgroundColor.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.BorderColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppTheme.DangerColor.withValues(alpha: 0.2),
                            child: const Icon(Icons.person, color: AppTheme.DangerColor, size: 28),
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  service,
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 11,
                                    color: AppTheme.TextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      loc.isArabic ? 'القرائن والوضعية الحالية المسجلة بالنظام' : 'Preuves et statut actuel enregistré',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _proofTile(
                      icon: Icons.timer_off_outlined,
                      title: loc.isArabic ? 'تسجيل الحضور اليومي' : 'Pointage quotidien',
                      status: loc.isArabic ? 'لم يسجل الحضور اليوم عبر التطبيق ❌' : 'Non pointé aujourd\'hui via l\'application ❌',
                      color: AppTheme.DangerColor,
                    ),
                    const SizedBox(height: 8),
                    _proofTile(
                      icon: Icons.storefront_outlined,
                      title: loc.isArabic ? 'المهام والمعاينات الميدانية' : 'Missions et visites sur le terrain',
                      status: loc.isArabic ? '0 زيارات تجارية مسجلة اليوم (لا يوجد نشاط ميداني)' : '0 visites de contrôle enregistrées aujourd\'hui',
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(height: 8),
                    _proofTile(
                      icon: _deductions.where((d) => d['EmployeeId'] == emp['Id']).isEmpty
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_rounded,
                      title: loc.isArabic ? 'السوابق الإدارية والخصومات' : 'Antécédents administratifs et retenues',
                      status: _deductions.where((d) => d['EmployeeId'] == emp['Id']).isEmpty
                          ? (loc.isArabic ? 'السجل الإداري نظيف (0 سوابق خصم) ✔️' : 'Dossier administratif vierge (0 antécédents) ✔️')
                          : (loc.isArabic
                              ? 'يوجد ${_deductions.where((d) => d['EmployeeId'] == emp['Id']).length} طلبات خصم سابقة في النظام ⚠️'
                              : '${_deductions.where((d) => d['EmployeeId'] == emp['Id']).length} ordres de retenue antérieurs ⚠️'),
                      color: _deductions.where((d) => d['EmployeeId'] == emp['Id']).isEmpty
                          ? const Color(0xFF10B981)
                          : AppTheme.DangerColor,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showExplanationLetterForAbsent(emp);
                        },
                        icon: const Icon(Icons.description, color: Colors.black87),
                        label: Text(
                          loc.isArabic ? 'معاينة الاستفسار الكتابي (48 ساعة للتبرير)' : 'Aperçu de la demande d\'explications (48h)',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontSize: 12,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _proofTile({
    required IconData icon,
    required String title,
    required String status,
    Color? color,
  }) {
    final statusColor = color ?? AppTheme.DangerColor;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: statusColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  status,
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: statusColor, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showExplanationLetterForAbsent(Map<String, dynamic> emp) {
    final loc = AppLocalizations.of(context);
    final name = !loc.isArabic && emp['Nom'] != null
        ? '${emp['Prenom'] ?? ''} ${emp['Nom'] ?? ''}'.trim()
        : (emp['NomAr'] != null
            ? '${emp['NomAr']} ${emp['PrenomAr'] ?? ''}'.trim()
            : '${emp['Nom'] ?? ''} ${emp['Prenom'] ?? ''}'.trim());
    final service = (emp['Service'] ?? (loc.isArabic ? 'مصلحة حماية المستهلك وقمع الغش' : 'Service Protection Consommateur')).toString();
    final grade = (emp['Grade'] ?? emp['grade'] ?? (loc.isArabic ? 'مفتش رئيسي للرقابة' : 'Inspecteur')).toString();
    final empId = emp['Id'] ?? emp['id'] ?? emp['EmployeeId'] ?? emp['employeeid'];
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    showDialog(
      context: context,
      builder: (dlgCtx) {
        bool isSending = false;
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return Directionality(
              textDirection: loc.isArabic ? TextDirection.rtl : TextDirection.ltr,
              child: AlertDialog(
                backgroundColor: const Color(0xFF1E1026),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.5), width: 1.5),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mark_email_unread_outlined, color: Color(0xFFD4AF37), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.isArabic ? 'استفسار كتابي رسمي — مهلة 48 ساعة' : 'Demande d\'Explications Officielle (48h)',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD4AF37),
                            ),
                          ),
                          Text(
                            loc.isArabic ? 'إجراء رقابي مباشر صادر عن المدير الولائي' : 'Procédure disciplinaire - Directeur de Wilaya',
                            style: const TextStyle(
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            loc.isArabic
                                ? 'الجمهورية الجزائرية الديمقراطية الشعبية\nوزارة التجارة الداخلية وضبط السوق الوطنية\nمديرية التجارة الداخلية وضبط السوق الوطنية لولاية سطيف'
                                : 'RÉPUBLIQUE ALGÉRIENNE DÉMOCRATIQUE ET POPULAIRE\nMINISTÈRE DU COMMERCE INTÉRIEUR ET DE LA RÉGULATION DU MARCHÉ NATIONAL\nDIRECTION DU COMMERCE DE LA WILAYA DE SÉTIF',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const Divider(color: Color(0xFFD4AF37), height: 20, thickness: 1),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.isArabic ? 'إلى السيد(ة): $name' : 'À Monsieur / Madame : $name',
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                loc.isArabic ? 'الرتبة: $grade  |  المصلحة: $service' : 'Grade: $grade  |  Service: $service',
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 11,
                                  color: AppTheme.TextSecondary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                loc.isArabic ? 'تاريخ الواقعة المسجلة: $dateStr' : 'Date de l\'incident: $dateStr',
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 11,
                                  color: Color(0xFFD4AF37),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          loc.isArabic
                              ? 'الموضوع: استفسار كتابي حول الغياب عن العمل الميداني وعدم تسجيل البصمة\nالمرجع: الأمر رقم 06-03 المتضمن القانون الأساسي للوظيفة العمومية.'
                              : 'Objet : Demande d\'explications pour absence du terrain\nRéf : Ordonnance n° 06-03 portant statut général de la fonction publique.',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Color(0xFFD4AF37),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          loc.isArabic
                              ? 'بناءً على المعطيات الميدانية المسجلة عبر المنصة الرقمية للرقابة والتفتيش اليوم، تبيّن عدم التحاقكم بنقطة الانطلاق أو المقر المحدد وعدم تسجيل أي نشاط أو زيارة رقابية ميدانية.\n\nوعليه، يُطلب منكم موافاة الإدارة بمبررات غيابكم مدعمة بالوثائق الثبوتية، في أجل أقصاه 48 ساعة من استلامكم هذا الاستفسار، وإلا ستُتخذ ضدكم الإجراءات القانونية المترتبة عن الخصم من الراتب وفق التشريع الساري.'
                              : 'Sur la base des données enregistrées aujourd\'hui sur la plateforme numérique d\'inspection, il a été constaté votre non-pointage au point de départ et l\'absence d\'activités de contrôle sur le terrain.\n\nEn conséquence, il vous est demandé de fournir à l\'administration vos justifications écrites appuyées par les pièces justificatives dans un délai strict de 48 heures à compter de la réception de la présente, faute de quoi les mesures réglementaires de retenue sur salaire seront appliquées.',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            height: 1.5,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.forward_to_inbox, color: Colors.blueAccent, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    loc.isArabic ? 'إحالة آلية لرئيس مكتب المستخدمين' : 'Notification Bureau Personnel',
                                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.blueAccent),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              loc.isArabic ? 'المدير الولائي للتجارة\nولاية سطيف' : 'Le Directeur du Commerce\nWilaya de Sétif',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD4AF37),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                actionsAlignment: MainAxisAlignment.spaceBetween,
                actions: [
                  TextButton(
                    onPressed: isSending ? null : () => Navigator.pop(dlgCtx),
                    child: Text(loc.isArabic ? 'إلغاء' : 'Annuler', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white60)),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: isSending ? null : () async {
                          final inquiryMap = {
                            'NomAr': emp['NomAr'],
                            'PrenomAr': emp['PrenomAr'],
                            'Nom': emp['Nom'],
                            'Prenom': emp['Prenom'],
                            'EmployeeName': name,
                            'Service': service,
                            'Grade': grade,
                            'IncidentDate': dateStr,
                            'Subject': loc.isArabic
                                ? 'استفسار كتابي حول الغياب عن العمل الميداني وعدم تسجيل البصمة'
                                : 'Demande d\'explications pour absence du terrain',
                            'Details': loc.isArabic
                                ? 'عدم تسجيل حضور بالبصمة الجغرافية وعدم الالتحاق بنقطة الانطلاق أو تسجيل نشاط رقابي ميداني بتاريخ $dateStr.'
                                : 'Absence constatée sur le terrain le $dateStr sans justification préalable.',
                            'LateMinutes': 0,
                            'SentBy': loc.isArabic ? 'المدير الولائي للتجارة - ولاية سطيف' : 'Directeur du Commerce - Wilaya de Sétif',
                          };
                          await PdfReportService.generateAndPrintInquiryLetter(inquiryMap);
                        },
                        icon: const Icon(Icons.print_outlined, size: 16, color: Color(0xFFD4AF37)),
                        label: Text(
                          loc.isArabic ? 'طباعة الاستفسار (PDF)' : 'Imprimer (PDF)',
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFD4AF37)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFD4AF37)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: isSending ? null : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(dlgCtx);
                          final isArabic = loc.isArabic;
                          setDlgState(() => isSending = true);
                          try {
                            final auth = Provider.of<AuthService>(context, listen: false);
                            final userId = auth.currentUser?.id ?? 1;
                            
                            final inquiryData = {
                              'employeeId': empId,
                              'type': 'unjustified_absence',
                              'subject': isArabic
                                  ? 'استفسار كتابي حول الغياب عن العمل الميداني وعدم تسجيل البصمة'
                                  : 'Demande d\'explications pour absence du terrain',
                              'incidentDate': dateStr,
                              'lateMinutes': 0,
                              'details': isArabic
                                  ? 'بناءً على المعطيات المسجلة عبر المنصة الرقمية للرقابة والتفتيش بتاريخ $dateStr، تبيّن عدم التحاقكم بنقطة الانطلاق وعدم تسجيل أي نشاط أو زيارة رقابية ميدانية.'
                                  : 'Absence constatée sur le terrain le $dateStr sans justification préalable.',
                              'sentBy': userId,
                            };

                            await auth.api.createInquiry(inquiryData);

                            nav.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        isArabic
                                            ? 'تم إرسال الاستفسار الكتابي رسمياً للموظف ($name) وإخطار مكتب المستخدمين بنجاح (مهلة الرد: 48 ساعة).'
                                            : 'Demande d\'explications envoyée avec succès à $name et notifiée au Bureau du Personnel.',
                                        style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            if (mounted) {
                              _load();
                            }
                          } catch (e) {
                            setDlgState(() => isSending = false);
                            messenger.showSnackBar(
                              SnackBar(
                                backgroundColor: AppTheme.DangerColor,
                                behavior: SnackBarBehavior.floating,
                                content: Text(
                                  isArabic ? 'فشل إرسال الاستفسار: $e' : 'Erreur lors de l\'envoi : $e',
                                  style: const TextStyle(fontFamily: 'Tajawal'),
                                ),
                              ),
                            );
                          }
                        },
                        icon: isSending
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.send_rounded, size: 16, color: Colors.black),
                        label: Text(
                          isSending
                              ? (loc.isArabic ? 'جاري الإرسال...' : 'Envoi en cours...')
                              : (loc.isArabic ? 'إرسال رسمي للموظف والمستخدمين' : 'Envoyer officiellement (48h)'),
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.black,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(dynamic val) {
    if (val == null) return '--:--';
    try {
      final dt = DateTime.parse(val.toString()).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return val.toString();
    }
  }

  void _showPresentEmployeeDetails(Map<String, dynamic> emp, Map<String, dynamic>? att) {
    final loc = AppLocalizations.of(context);
    final name = !loc.isArabic && emp['Nom'] != null
        ? '${emp['Prenom'] ?? ''} ${emp['Nom'] ?? ''}'.trim()
        : (emp['NomAr'] != null
            ? '${emp['NomAr']} ${emp['PrenomAr'] ?? ''}'.trim()
            : '${emp['Nom'] ?? ''} ${emp['Prenom'] ?? ''}'.trim());
    final service = (emp['Service'] ?? (loc.isArabic ? 'مصلحة حماية المستهلك وقمع الغش' : 'Service Protection Consommateur')).toString();
    final matricule = (emp['NumeroMatricule'] ?? 'N/A').toString();
    final checkInTime = att?['CheckInTime'] != null ? _formatTime(att!['CheckInTime']) : '--:--';
    final locationName = att?['LocationName'] ?? (loc.isArabic ? 'المقر الرئيسي (حي المعبودة)' : 'Siège Principal (El Maabouda)');
    final status = att?['Status'] ?? 'present';
    final lat = att?['Latitude'] ?? att?['lat'];
    final lng = att?['Longitude'] ?? att?['lng'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: loc.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.70,
          decoration: const BoxDecoration(
            color: AppTheme.CardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user, color: AppTheme.SuccessColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loc.isArabic ? 'بيانات الحضور والبصمة الجغرافية' : 'Détails du pointage et géolocalisation',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.BackgroundColor.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.SuccessColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppTheme.SuccessColor.withValues(alpha: 0.2),
                            child: const Icon(Icons.person, color: AppTheme.SuccessColor, size: 28),
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  loc.isArabic ? '$service | رقم التسجيل: $matricule' : '$service | Matricule : $matricule',
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 11,
                                    color: AppTheme.TextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      loc.isArabic ? 'تفاصيل البصمة والتحقق الميداني' : 'Détails du pointage et vérification GPS',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _proofTile(
                      icon: Icons.access_time_filled,
                      title: loc.isArabic ? 'توقيت تسجيل الحضور' : 'Heure de pointage',
                      status: loc.isArabic ? 'تم الحضور في تمام الساعة: $checkInTime ✔️' : 'Pointage enregistré à : $checkInTime ✔️',
                    ),
                    const SizedBox(height: 8),
                    _proofTile(
                      icon: Icons.location_on,
                      title: loc.isArabic ? 'المقر / نقطة الانطلاق الميدانية' : 'Siège / Point de départ terrain',
                      status: '$locationName ${lat != null ? "($lat, $lng)" : ""}',
                    ),
                    const SizedBox(height: 8),
                    _proofTile(
                      icon: Icons.check_circle_outline,
                      title: loc.isArabic ? 'حالة الحضور القانونية' : 'Statut réglementaire',
                      status: status == 'late'
                          ? (loc.isArabic ? 'تأخر صباحي مسجل' : 'Retard matinal enregistré')
                          : (loc.isArabic ? 'حضور منضبط ومثبت رسمياً ✅' : 'Présence ponctuelle et confirmée ✅'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, int value, Color color, IconData icon, String filterKey) {
    final isSelected = _selectedFilter == filterKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = filterKey;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.18) : AppTheme.CardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.3),
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 20),
                  if (isSelected) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$value',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : AppTheme.TextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
