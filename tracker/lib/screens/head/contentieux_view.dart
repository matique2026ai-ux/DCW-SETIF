import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drh_setif_tracker/services/auth_service.dart';
import 'package:drh_setif_tracker/providers/language_provider.dart';

class ContentieuxView extends StatefulWidget {
  final String departmentName;
  final VoidCallback onRefresh;
  final TabController? tabController;

  const ContentieuxView({
    super.key,
    required this.departmentName,
    required this.onRefresh,
    this.tabController,
  });

  @override
  State<ContentieuxView> createState() => _ContentieuxViewState();
}

class _ContentieuxViewState extends State<ContentieuxView> with SingleTickerProviderStateMixin {
  late TabController _internalTabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _pvs = [];
  List<Map<String, dynamic>> _closures = [];
  List<Map<String, dynamic>> _courts = [];

  String _closureFilter = 'all'; // all, submitted_to_director, approved_by_director, executed, reopened
  String _pvSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _internalTabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _internalTabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = context.read<AuthService>().api;
      final pvs = await api.getContentieuxPvs();
      final closures = await api.getClosureOrders();
      final courts = await api.getCourtCases();

      if (mounted) {
        setState(() {
          _pvs = pvs;
          _closures = closures;
          _courts = courts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.watch<LanguageProvider>().isArabic;
    final ctrl = widget.tabController ?? _internalTabController;

    if (widget.tabController != null) {
      return _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : TabBarView(
              controller: ctrl,
              children: [
                _buildPvsTab(isAr),
                _buildClosuresTab(isAr),
                _buildCourtsTab(isAr),
              ],
            );
    }

    return Column(
      children: [
        // Sub-tabs for Contentieux
        Container(
          color: const Color(0xFF1E0B26),
          child: TabBar(
            controller: ctrl,
            indicatorColor: const Color(0xFFD4AF37),
            indicatorWeight: 3,
            labelColor: const Color(0xFFD4AF37),
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12),
            tabs: [
              Tab(
                icon: const Icon(Icons.gavel, size: 18),
                text: isAr ? 'تدقيق محاضر المعاينة' : 'Contrôle des PVs',
              ),
              Tab(
                icon: const Icon(Icons.lock_clock, size: 18),
                text: isAr ? 'قرارات الغلق الإداري' : 'Fermetures Administratives',
              ),
              Tab(
                icon: const Icon(Icons.account_balance, size: 18),
                text: isAr ? 'المتابعة القضائية والمصالحة' : 'Contentieux & Justice',
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
              : TabBarView(
                  controller: ctrl,
                  children: [
                    _buildPvsTab(isAr),
                    _buildClosuresTab(isAr),
                    _buildCourtsTab(isAr),
                  ],
                ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 1: PVS INBOX (صندوق تدقيق المحاضر)
  // ==========================================
  Widget _buildPvsTab(bool isAr) {
    final filtered = _pvs.where((pv) {
      final shop = (pv['ShopName'] ?? pv['shopName'] ?? '').toString().toLowerCase();
      final type = (pv['ViolationType'] ?? pv['violationType'] ?? '').toString().toLowerCase();
      return _pvSearchQuery.isEmpty || shop.contains(_pvSearchQuery.toLowerCase()) || type.contains(_pvSearchQuery.toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFD4AF37),
      backgroundColor: const Color(0xFF1E0B26),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2D1035), Color(0xFF1E0B26)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fact_check, color: Color(0xFFD4AF37), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'صندوق تدقيق المحاضر الميدانية (PVs Inbox)' : 'Registre des PVs d\'infraction',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        isAr
                            ? 'استلام محاضر المفتشين، التحقق من التكييف القانوني والثنائية (Binôme)، وإعداد قرارات الغلق'
                            : 'Validation juridique des PVs et instruction des fermetures',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Color(0xFFFDE68A)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            onChanged: (v) => setState(() => _pvSearchQuery = v),
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white),
            decoration: InputDecoration(
              hintText: isAr ? 'بحث عن محل أو نوع مخالفة...' : 'Recherche...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37), size: 18),
              filled: true,
              fillColor: const Color(0xFF1E0B26),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),

          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: Text(
                isAr ? 'لا توجد محاضر مخالفات معلقة حالياً' : 'Aucun PV d\'infraction',
                style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white54, fontSize: 12),
              ),
            )
          else
            ...filtered.map((pv) => _buildPvCard(pv, isAr)),
        ],
      ),
    );
  }

  Widget _buildPvCard(Map<String, dynamic> pv, bool isAr) {
    final visitId = pv['Id'] ?? pv['id'];
    final shopName = (pv['ShopName'] ?? pv['shopName'] ?? 'محل تجاري').toString();
    final shopType = (pv['ShopType'] ?? pv['shopType'] ?? 'نشاط تجاري').toString();
    final violation = (pv['ViolationType'] ?? pv['violationType'] ?? 'مخالفة غير محددة').toString();
    final notes = (pv['ViolationNotes'] ?? pv['violationNotes'] ?? pv['Notes'] ?? '').toString();
    final legalAction = (pv['LegalAction'] ?? pv['legalAction'] ?? 'تحرير محضر متابعة').toString();
    final seizureVal = double.tryParse((pv['SeizureValue'] ?? pv['seizureValue'] ?? 0).toString()) ?? 0;
    final date = (pv['Date'] ?? pv['date'] ?? '').toString().split('T')[0];
    final inspectorName = (pv['InspectorNomAr'] ?? pv['InspectorNom'] ?? 'مفتش الرقابة').toString();
    final closureId = pv['ClosureOrderId'] ?? pv['closureOrderId'];

    final hasClosureOrder = closureId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF240D2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.report_problem, color: Color(0xFFEF4444), size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#$visitId • $shopName', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('$shopType • تاريخ المعاينة: $date', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.white54)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: hasClosureOrder ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFD4AF37).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  hasClosureOrder ? (isAr ? 'صدر قرار غلق' : 'Fermeture instruite') : (isAr ? 'قيد المعالجة' : 'En attente'),
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: hasClosureOrder ? const Color(0xFF34D399) : const Color(0xFFD4AF37)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF1E0B26), borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⚠️ طبيعة المخالفة: $violation', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFCA5A5))),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('📝 ملاحظات المحضر: $notes', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.white70)),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('🛡️ الإجراء المقترح: $legalAction', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Color(0xFFFDE68A))),
                    if (seizureVal > 0) ...[
                      const Spacer(),
                      Text('📦 قيمة المحجوزات: ${seizureVal.toStringAsFixed(0)} دج', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          Row(
            children: [
              Text('👤 العون المحرر: $inspectorName (تنظيم ثنائي Binôme)', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.white54)),
              const Spacer(),
              if (!hasClosureOrder)
                ElevatedButton.icon(
                  onPressed: () => _showDraftClosureFromPvDialog(pv, isAr),
                  icon: const Icon(Icons.lock_outline, size: 14),
                  label: Text(isAr ? 'استصدار قرار غلق' : 'Instruire fermeture', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: CLOSURE ORDERS (قرارات الغلق الإداري)
  // ==========================================
  Widget _buildClosuresTab(bool isAr) {
    final filtered = _closures.where((c) {
      if (_closureFilter == 'all') return true;
      return (c['Status'] ?? c['status']) == _closureFilter;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFD4AF37),
      backgroundColor: const Color(0xFF1E0B26),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Banner with Manual Create Button
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2D1035),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.lock_clock, color: Color(0xFFEF4444), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'سجل قرارات الغلق الإداري للمحلات المخالفة' : 'Arrêtés de Fermeture Administrative',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        isAr
                            ? 'إعداد القرارات، توقيع السيد المدير الولائي، وتتبع التشميع مع مصالح الأمن والدرك'
                            : 'Instruction, signature du Directeur et exécution des scellés',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Color(0xFFFDE68A)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showManualClosureDialog(isAr),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(isAr ? 'قرار جديد' : 'Nouveau', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: const Color(0xFF1E0B26),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Closure Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', isAr ? 'الكل (${_closures.length})' : 'Tous', isAr),
                _buildFilterChip('submitted_to_director', isAr ? 'قيد عرض المدير' : 'En attente Dir', isAr),
                _buildFilterChip('approved_by_director', isAr ? 'موقعة وجاهزة للتنفيذ' : 'Approuvés', isAr),
                _buildFilterChip('executed', isAr ? 'مشمعة ومنفذة 🔒' : 'Scellés', isAr),
                _buildFilterChip('reopened', isAr ? 'أعيد فتحها ✅' : 'Réouverts', isAr),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: Text(
                isAr ? 'لا توجد قرارات غلق في هذا القسم' : 'Aucun arrêté trouvé',
                style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white54, fontSize: 12),
              ),
            )
          else
            ...filtered.map((c) => _buildClosureCard(c, isAr)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, bool isAr) {
    final isSel = _closureFilter == key;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: FilterChip(
        selected: isSel,
        label: Text(label, style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: isSel ? Colors.black : Colors.white70, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
        selectedColor: const Color(0xFFD4AF37),
        backgroundColor: const Color(0xFF1E0B26),
        checkmarkColor: Colors.black,
        onSelected: (val) {
          setState(() => _closureFilter = key);
        },
      ),
    );
  }

  Widget _buildClosureCard(Map<String, dynamic> c, bool isAr) {
    final id = c['Id'] ?? c['id'];
    final orderNum = (c['OrderNumber'] ?? c['orderNumber'] ?? '').toString();
    final est = (c['EstablishmentName'] ?? c['establishmentName'] ?? '').toString();
    final reg = (c['CommercialRegister'] ?? c['commercialRegister'] ?? '').toString();
    final owner = (c['OwnerName'] ?? c['ownerName'] ?? '').toString();
    final addr = (c['Address'] ?? c['address'] ?? '').toString();
    final muni = (c['Municipality'] ?? c['municipality'] ?? 'سطيف').toString();
    final inf = (c['InfractionType'] ?? c['infractionType'] ?? '').toString();
    final legal = (c['LegalBasis'] ?? c['legalBasis'] ?? '').toString();
    final days = (c['DurationDays'] ?? c['durationDays'] ?? 30).toString();
    final status = (c['Status'] ?? c['status'] ?? 'draft').toString();
    final notes = (c['Notes'] ?? c['notes'] ?? '').toString();

    Color statusColor;
    String statusText;
    switch (status) {
      case 'submitted_to_director':
        statusColor = const Color(0xFFF59E0B);
        statusText = isAr ? 'قيد توقيع المدير' : 'En attente signature';
        break;
      case 'approved_by_director':
        statusColor = const Color(0xFFD4AF37);
        statusText = isAr ? 'موقع • جاهز للتنفيذ' : 'Approuvé • À sceller';
        break;
      case 'executed':
        statusColor = const Color(0xFFEF4444);
        statusText = isAr ? 'مشمع ومنفذ 🔒' : 'Exécuté / Scellé';
        break;
      case 'reopened':
        statusColor = const Color(0xFF10B981);
        statusText = isAr ? 'أعيد فتحه ✅' : 'Réouvert';
        break;
      default:
        statusColor = Colors.white54;
        statusText = status;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF240D2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFD4AF37).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                child: Text('قرار رقم: $orderNum', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'بلدية: $muni',
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Text(statusText, style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(est, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          if (owner.isNotEmpty || reg.isNotEmpty) ...[
            Text('التاجر: $owner • السجل التجاري: $reg', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.white60)),
          ],
          if (addr.isNotEmpty) Text('العنوان: $addr', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.white54)),
          const SizedBox(height: 6),

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF1E0B26), borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⚠️ سبب الغلق: $inf', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFFCA5A5))),
                Text('⚖️ السند القانوني: $legal', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Color(0xFFFDE68A))),
                Text('⏱️ مدة الغلق المقررة: $days يوماً', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                if (notes.isNotEmpty) Text('📌 $notes', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (status == 'approved_by_director' && id != null) ...[
                ElevatedButton.icon(
                  onPressed: () async {
                    final api = context.read<AuthService>().api;
                    await api.executeClosureOrder(int.parse(id.toString()), notes: 'تم تشميع المحل وتثبيت ملصق الغلق الإداري');
                    _loadData();
                  },
                  icon: const Icon(Icons.lock, size: 14),
                  label: Text(isAr ? 'تسجيل التشميع والتنفيذ' : 'Enregistrer exécution', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
                ),
              ] else if (status == 'executed' && id != null) ...[
                ElevatedButton.icon(
                  onPressed: () async {
                    final api = context.read<AuthService>().api;
                    await api.reopenClosureOrder(int.parse(id.toString()));
                    _loadData();
                  },
                  icon: const Icon(Icons.lock_open, size: 14),
                  label: Text(isAr ? 'رفع الغلق وإعادة الفتح' : 'Lever la fermeture', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: COURTS & SETTLEMENTS (المتابعة القضائية والمصالحة)
  // ==========================================
  Widget _buildCourtsTab(bool isAr) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFD4AF37),
      backgroundColor: const Color(0xFF1E0B26),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2D1035),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFD4AF37).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.account_balance, color: Color(0xFFD4AF37), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'سجل المتابعة القضائية لدى محاكم الولاية' : 'Contentieux Judiciaire & Parquet',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        isAr
                            ? 'إحالة ملفات المخالفين لوكلاء الجمهورية (سطيف، العلمة، عين ولمان) واستيفاء الغرامات'
                            : 'Transmission des dossiers au parquet et recouvrement des amendes',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Color(0xFFFDE68A)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showAddCourtCaseDialog(isAr),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(isAr ? 'إحالة جديدة' : 'Nouveau dossier', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: const Color(0xFF1E0B26),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_courts.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: Text(
                isAr ? 'لا توجد قضايا مسجلة حالياً' : 'Aucun dossier judiciaire',
                style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white54, fontSize: 12),
              ),
            )
          else
            ..._courts.map((cs) => _buildCourtCard(cs, isAr)),
        ],
      ),
    );
  }

  Widget _buildCourtCard(Map<String, dynamic> cs, bool isAr) {
    final id = cs['Id'] ?? cs['id'];
    final caseNum = (cs['CaseNumber'] ?? cs['caseNumber'] ?? '').toString();
    final court = (cs['CourtName'] ?? cs['courtName'] ?? 'محكمة سطيف').toString();
    final def = (cs['DefendantName'] ?? cs['defendantName'] ?? '').toString();
    final reg = (cs['CommercialRegister'] ?? cs['commercialRegister'] ?? '').toString();
    final details = (cs['InfractionDetails'] ?? cs['infractionDetails'] ?? '').toString();
    final verdict = (cs['Verdict'] ?? cs['verdict'] ?? 'قيد الدراسة').toString();
    final fine = double.tryParse((cs['FineAmount'] ?? cs['fineAmount'] ?? 0).toString()) ?? 0;
    final isSettled = cs['IsSettled'] == true || cs['isSettled'] == 1;
    final receipt = (cs['SettlementReceipt'] ?? cs['settlementReceipt'] ?? '').toString();
    final subDate = (cs['SubmissionDate'] ?? cs['submissionDate'] ?? '').toString().split('T')[0];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF240D2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSettled ? const Color(0xFF10B981).withValues(alpha: 0.5) : const Color(0xFFD4AF37).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFD4AF37).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                child: Text('ملف: $caseNum', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(court, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSettled ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isSettled ? (isAr ? 'تم الصلح وسددت الغرامة ✅' : 'Régularisé') : (isAr ? 'قيد المتابعة القضائية' : 'En cours'),
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: isSettled ? const Color(0xFF34D399) : const Color(0xFFF59E0B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(def, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white)),
          if (reg.isNotEmpty) Text('رقم السجل: $reg • تاريخ الإحالة: $subDate', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.white54)),
          const SizedBox(height: 6),

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF1E0B26), borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('⚖️ التهمة والجنحة: $details', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70)),
                const SizedBox(height: 4),
                Text('🏛️ مآل القضية / الحكم: $verdict', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFFDE68A))),
                if (fine > 0) ...[
                  const SizedBox(height: 2),
                  Text('💰 الغرامة المقررة: ${fine.toStringAsFixed(0)} دج', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                ],
                if (receipt.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('🧾 $receipt', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Color(0xFF34D399))),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          if (!isSettled && id != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showUpdateCourtDialog(cs, isAr),
                  icon: const Icon(Icons.edit, size: 14, color: Color(0xFFD4AF37)),
                  label: Text(isAr ? 'تحديث مآل القضية أو تسجيل المصالحة' : 'Mettre à jour', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFD4AF37))),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ==========================================
  // DIALOGS: DRAFT CLOSURE & ADD COURT CASE
  // ==========================================
  void _showDraftClosureFromPvDialog(Map<String, dynamic> pv, bool isAr) {
    final visitId = pv['Id'] ?? pv['id'];
    final estCtrl = TextEditingController(text: (pv['ShopName'] ?? pv['shopName'] ?? '').toString());
    final ownerCtrl = TextEditingController();
    final regCtrl = TextEditingController();
    final addrCtrl = TextEditingController(text: (pv['LocationName'] ?? pv['locationName'] ?? 'سطيف').toString());
    final infCtrl = TextEditingController(text: (pv['ViolationType'] ?? pv['violationType'] ?? '').toString());
    final daysCtrl = TextEditingController(text: '30');
    const selectedMuni = 'سطيف';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF240D2D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFEF4444))),
          title: Row(
            children: [
              const Icon(Icons.lock_clock, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Text(isAr ? 'إعداد مسودة قرار غلق إداري' : 'Instruire un arrêté de fermeture', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: estCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'اسم المحل / المؤسسة *' : 'Établissement *')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: ownerCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'اسم صاحب المحل' : 'Propriétaire'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: regCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'رقم السجل التجاري' : 'Registre'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: addrCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'العنوان الإداري والبلدية' : 'Adresse')),
                  const SizedBox(height: 8),
                  TextField(controller: infCtrl, maxLines: 2, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'سبب وموضوع الغلق الإداري *' : 'Motif *')),
                  const SizedBox(height: 8),
                  TextField(controller: daysCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'مدة الغلق المقترحة (بالأيام)' : 'Durée (jours)')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? 'إلغاء' : 'Annuler', style: const TextStyle(fontFamily: 'Tajawal'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              onPressed: () async {
                if (estCtrl.text.trim().isEmpty || infCtrl.text.trim().isEmpty) return;
                final api = context.read<AuthService>().api;
                await api.createClosureOrder({
                  'establishmentName': estCtrl.text.trim(),
                  'ownerName': ownerCtrl.text.trim(),
                  'commercialRegister': regCtrl.text.trim(),
                  'address': addrCtrl.text.trim(),
                  'municipality': selectedMuni,
                  'infractionType': infCtrl.text.trim(),
                  'durationDays': int.tryParse(daysCtrl.text) ?? 30,
                  'relatedVisitId': visitId != null ? int.tryParse(visitId.toString()) : null,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) _loadData();
              },
              child: Text(isAr ? 'إحالة القرار للمدير للاعتماد' : 'Soumettre au Directeur', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualClosureDialog(bool isAr) {
    final estCtrl = TextEditingController();
    final ownerCtrl = TextEditingController();
    final regCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final infCtrl = TextEditingController();
    final daysCtrl = TextEditingController(text: '30');
    final legalCtrl = TextEditingController(text: 'القانون 09-03 المتعلق بحماية المستهلك والقانون 04-02');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF240D2D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFD4AF37))),
          title: Text(isAr ? 'إعداد مسودة قرار غلق إداري جديد' : 'Nouvel arrêté de fermeture', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: estCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'اسم المحل / المؤسسة *' : 'Établissement *')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: ownerCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'اسم صاحب المحل' : 'Propriétaire'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: regCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'رقم السجل التجاري' : 'Registre'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: addrCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'العنوان والبلدية' : 'Adresse')),
                  const SizedBox(height: 8),
                  TextField(controller: infCtrl, maxLines: 2, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'سبب وموضوع الغلق *' : 'Motif *')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: legalCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'السند القانوني' : 'Base légale'))),
                      const SizedBox(width: 8),
                      SizedBox(width: 80, child: TextField(controller: daysCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'المدة (يوم)' : 'Jours'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? 'إلغاء' : 'Annuler', style: const TextStyle(fontFamily: 'Tajawal'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
              onPressed: () async {
                if (estCtrl.text.trim().isEmpty || infCtrl.text.trim().isEmpty) return;
                final api = context.read<AuthService>().api;
                await api.createClosureOrder({
                  'establishmentName': estCtrl.text.trim(),
                  'ownerName': ownerCtrl.text.trim(),
                  'commercialRegister': regCtrl.text.trim(),
                  'address': addrCtrl.text.trim(),
                  'municipality': 'سطيف',
                  'infractionType': infCtrl.text.trim(),
                  'legalBasis': legalCtrl.text.trim(),
                  'durationDays': int.tryParse(daysCtrl.text) ?? 30,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) _loadData();
              },
              child: Text(isAr ? 'إحالة للمدير للاعتماد' : 'Soumettre', style: const TextStyle(fontFamily: 'Tajawal', color: Color(0xFF1E0B26), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCourtCaseDialog(bool isAr) {
    final courtCtrl = TextEditingController(text: 'محكمة سطيف (قسم الجنح)');
    final defCtrl = TextEditingController();
    final regCtrl = TextEditingController();
    final detCtrl = TextEditingController();
    final fineCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF240D2D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFD4AF37))),
        title: Text(isAr ? 'تسجيل إحالة قضائية جديدة لوكيل الجمهورية' : 'Nouveau dossier parquet', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: courtCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'المحكمة المختصة *' : 'Tribunal *')),
                const SizedBox(height: 8),
                TextField(controller: defCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'اسم التاجر / المتهم *' : 'Prévenu *')),
                const SizedBox(height: 8),
                TextField(controller: regCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'رقم السجل التجاري' : 'Registre')),
                const SizedBox(height: 8),
                TextField(controller: detCtrl, maxLines: 2, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'تفاصيل الجنحة والمحضر المحال *' : 'Détails de l\'infraction *')),
                const SizedBox(height: 8),
                TextField(controller: fineCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'مبلغ الغرامة المقدرة (دج)' : 'Amende estimée')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? 'إلغاء' : 'Annuler', style: const TextStyle(fontFamily: 'Tajawal'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
            onPressed: () async {
              if (defCtrl.text.trim().isEmpty || detCtrl.text.trim().isEmpty) return;
              final api = context.read<AuthService>().api;
              await api.createCourtCase({
                'courtName': courtCtrl.text.trim(),
                'defendantName': defCtrl.text.trim(),
                'commercialRegister': regCtrl.text.trim(),
                'infractionDetails': detCtrl.text.trim(),
                'fineAmount': double.tryParse(fineCtrl.text) ?? 0,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) _loadData();
            },
            child: Text(isAr ? 'تسجيل الإحالة' : 'Enregistrer', style: const TextStyle(fontFamily: 'Tajawal', color: Color(0xFF1E0B26), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showUpdateCourtDialog(Map<String, dynamic> cs, bool isAr) {
    final id = cs['Id'] ?? cs['id'];
    final verdictCtrl = TextEditingController(text: (cs['Verdict'] ?? cs['verdict'] ?? '').toString());
    final fineCtrl = TextEditingController(text: (cs['FineAmount'] ?? cs['fineAmount'] ?? '').toString());
    final receiptCtrl = TextEditingController(text: (cs['SettlementReceipt'] ?? cs['settlementReceipt'] ?? '').toString());
    bool isSettled = cs['IsSettled'] == true || cs['isSettled'] == 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF240D2D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFD4AF37))),
          title: Text(isAr ? 'تحيين مآل القضية أو إجراء المصالحة' : 'Mise à jour du dossier', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: verdictCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'منطوق الحكم / مآل الملف' : 'Jugement')),
                  const SizedBox(height: 8),
                  TextField(controller: fineCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'مبلغ الغرامة المحكوم بها (دج)' : 'Amende')),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: isSettled,
                    activeThumbColor: const Color(0xFF10B981),
                    contentPadding: EdgeInsets.zero,
                    title: Text(isAr ? 'تمت المصالحة القانونية وسددت الغرامة' : 'Transaction payée', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white)),
                    onChanged: (v) => setDialogState(() => isSettled = v),
                  ),
                  if (isSettled) ...[
                    const SizedBox(height: 8),
                    TextField(controller: receiptCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'رقم وتاريخ وصل قباضة الضرائب' : 'Reçu du trésor')),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? 'إلغاء' : 'Annuler', style: const TextStyle(fontFamily: 'Tajawal'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () async {
                if (id == null) return;
                final api = context.read<AuthService>().api;
                await api.updateCourtCase(int.parse(id.toString()), {
                  'verdict': verdictCtrl.text.trim(),
                  'fineAmount': double.tryParse(fineCtrl.text) ?? 0,
                  'isSettled': isSettled,
                  'settlementReceipt': receiptCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) _loadData();
              },
              child: Text(isAr ? 'حفظ المآل' : 'Sauvegarder', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
