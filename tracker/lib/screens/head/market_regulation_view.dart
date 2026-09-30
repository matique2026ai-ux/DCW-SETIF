import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drh_setif_tracker/services/auth_service.dart';
import 'package:drh_setif_tracker/providers/language_provider.dart';

class MarketRegulationView extends StatefulWidget {
  final String departmentName;
  final VoidCallback onRefresh;
  final TabController? tabController;

  const MarketRegulationView({
    super.key,
    required this.departmentName,
    required this.onRefresh,
    this.tabController,
  });

  @override
  State<MarketRegulationView> createState() => _MarketRegulationViewState();
}

class _MarketRegulationViewState extends State<MarketRegulationView> with SingleTickerProviderStateMixin {
  late TabController _internalTabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _prices = [];
  List<Map<String, dynamic>> _alerts = [];
  Map<String, dynamic> _bulletin = {};

  String _searchQuery = '';
  String _selectedCategory = 'الكل';
  String _selectedStatusFilter = 'الكل';

  final List<String> _categories = [
    'الكل',
    'مواد مقننة واسعة الاستهلاك',
    'خضر وفواكه طازجة',
    'لحوم ودواجن',
    'مواد غذائية عامة',
  ];

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
      final prices = await api.getMarketPrices();
      final alerts = await api.getSupplyAlerts();
      final bulletin = await api.getMarketBulletin();

      if (mounted) {
        setState(() {
          _prices = prices;
          _alerts = alerts;
          _bulletin = bulletin;
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
                _buildPricesTab(isAr),
                _buildAlertsTab(isAr),
                _buildBulletinTab(isAr),
              ],
            );
    }

    return Column(
      children: [
        // Sub-tabs for Market Regulation
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
                icon: const Icon(Icons.storefront, size: 18),
                text: isAr ? 'مرصد الأسعار وضبط السوق' : 'Observatoire des Prix',
              ),
              Tab(
                icon: const Icon(Icons.crisis_alert, size: 18),
                text: isAr ? 'إخطارات التموين والإنذار' : 'Alertes Approvisionnement',
              ),
              Tab(
                icon: const Icon(Icons.summarize, size: 18),
                text: isAr ? 'النشرة اليومية لضبط السوق' : 'Bulletin Quotidien',
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
                    _buildPricesTab(isAr),
                    _buildAlertsTab(isAr),
                    _buildBulletinTab(isAr),
                  ],
                ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 1: PRICES OBSERVATORY (مرصد الأسعار)
  // ==========================================
  Widget _buildPricesTab(bool isAr) {
    final filtered = _prices.where((p) {
      final name = (p['CommodityName'] ?? p['commodityName'] ?? '').toString().toLowerCase();
      final cat = (p['Category'] ?? p['category'] ?? '').toString();
      final status = (p['SupplyStatus'] ?? p['supplyStatus'] ?? '').toString();

      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
      final matchesCat = _selectedCategory == 'الكل' || cat == _selectedCategory;
      final matchesStatus = _selectedStatusFilter == 'الكل' || status == _selectedStatusFilter;

      return matchesSearch && matchesCat && matchesStatus;
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFD4AF37),
      backgroundColor: const Color(0xFF1E0B26),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Informative Banner & Add Button
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
                  child: const Icon(Icons.analytics_outlined, color: Color(0xFFD4AF37), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'المرصد الولائي لأسعار المواد الاستهلاكية' : 'Observatoire de Wilaya des Prix',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        isAr
                            ? 'متابعة الأسعار المقننة، فوارق التجزئة والجملة، ورصد مؤشرات وفرة المنتجات بأسواق سطيف'
                            : 'Suivi des prix réglementés, marges et indices de disponibilité',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Color(0xFFFDE68A)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showAddPriceDialog(isAr),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(isAr ? 'إدراج مادة' : 'Ajouter', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold)),
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

          // Search and Filters
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: isAr ? 'بحث عن مادة استهلاكية (سميد، حليب، زيت...)' : 'Rechercher un produit...',
                    hintStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37), size: 18),
                    filled: true,
                    fillColor: const Color(0xFF1E0B26),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((c) {
                final isSel = _selectedCategory == c;
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: FilterChip(
                    selected: isSel,
                    label: Text(c, style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: isSel ? Colors.black : Colors.white70, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                    selectedColor: const Color(0xFFD4AF37),
                    backgroundColor: const Color(0xFF1E0B26),
                    checkmarkColor: Colors.black,
                    onSelected: (val) {
                      setState(() => _selectedCategory = val ? c : 'الكل');
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),

          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                'الكل',
                'وفرة مستقرة',
                'تذبذب طفيف',
                'ندرة حرجة',
              ].map((s) {
                final isSel = _selectedStatusFilter == s;
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: FilterChip(
                    selected: isSel,
                    label: Text(s, style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: isSel ? Colors.white : Colors.white60, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                    selectedColor: s == 'وفرة مستقرة' ? const Color(0xFF10B981) : (s == 'ندرة حرجة' ? const Color(0xFFEF4444) : (s == 'الكل' ? const Color(0xFFD4AF37) : const Color(0xFFF59E0B))),
                    backgroundColor: const Color(0xFF1E0B26),
                    checkmarkColor: Colors.white,
                    onSelected: (val) {
                      setState(() => _selectedStatusFilter = val ? s : 'الكل');
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Commodity Cards List
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: Text(
                isAr ? 'لا توجد معطيات مطابقة للبحث' : 'Aucun produit trouvé',
                style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white54, fontSize: 12),
              ),
            )
          else
            ...filtered.map((item) => _buildCommodityCard(item, isAr)),
        ],
      ),
    );
  }

  Widget _buildCommodityCard(Map<String, dynamic> item, bool isAr) {
    final id = item['Id'] ?? item['id'];
    final name = (item['CommodityName'] ?? item['commodityName'] ?? '').toString();
    final cat = (item['Category'] ?? item['category'] ?? '').toString();
    final reg = double.tryParse((item['RegulatedPrice'] ?? item['regulatedPrice'] ?? 0).toString()) ?? 0;
    final whole = double.tryParse((item['WholesalePrice'] ?? item['wholesalePrice'] ?? 0).toString()) ?? 0;
    final retail = double.tryParse((item['RetailPrice'] ?? item['retailPrice'] ?? 0).toString()) ?? 0;
    final unit = (item['Unit'] ?? item['unit'] ?? 'كلغ').toString();
    final loc = (item['MarketLocation'] ?? item['marketLocation'] ?? 'سطيف').toString();
    final status = (item['SupplyStatus'] ?? item['supplyStatus'] ?? 'sufficient').toString();
    final notes = (item['Notes'] ?? item['notes'] ?? '').toString();

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'abundant':
        statusColor = const Color(0xFF10B981);
        statusText = isAr ? 'وفرة ممتازة' : 'Abondant';
        statusIcon = Icons.check_circle;
        break;
      case 'sufficient':
        statusColor = const Color(0xFF10B981);
        statusText = isAr ? 'وفرة كافية' : 'Suffisant';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'fluctuating':
        statusColor = const Color(0xFFF59E0B);
        statusText = isAr ? 'تذبذب في التموين' : 'Fluctuant';
        statusIcon = Icons.warning_amber_rounded;
        break;
      case 'scarce':
      default:
        statusColor = const Color(0xFFEF4444);
        statusText = isAr ? 'ندرة / ضغط حاد' : 'Pénurie';
        statusIcon = Icons.error_outline;
        break;
    }

    final isRegulated = reg > 0;
    final isAboveRegulated = isRegulated && retail > reg;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF240D2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAboveRegulated ? const Color(0xFFEF4444).withValues(alpha: 0.6) : Colors.white12,
          width: isAboveRegulated ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      '$cat • $loc',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Price Metrics Row
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E0B26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (isRegulated) ...[
                  _buildPriceItem(
                    label: isAr ? 'السعر المقنن' : 'Prix Réglementé',
                    val: '${reg.toStringAsFixed(1)} دج',
                    color: const Color(0xFFD4AF37),
                  ),
                  Container(width: 1, height: 25, color: Colors.white12),
                ],
                _buildPriceItem(
                  label: isAr ? 'سعر الجملة' : 'Prix Gros',
                  val: '${whole.toStringAsFixed(1)} دج',
                  color: Colors.white70,
                ),
                Container(width: 1, height: 25, color: Colors.white12),
                _buildPriceItem(
                  label: isAr ? 'سعر التجزئة' : 'Prix Détail',
                  val: '${retail.toStringAsFixed(1)} دج / $unit',
                  color: isAboveRegulated ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  isBold: true,
                ),
              ],
            ),
          ),

          if (notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '📌 $notes',
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Color(0xFFFDE68A)),
            ),
          ],

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _showEditPriceDialog(item, isAr),
                icon: const Icon(Icons.edit, size: 14, color: Color(0xFFD4AF37)),
                label: Text(isAr ? 'تحيين السعر والوفرة' : 'Mettre à jour', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFD4AF37))),
              ),
              IconButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      backgroundColor: const Color(0xFF1E0B26),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      title: Text(isAr ? 'حذف المادة من المرصد' : 'Supprimer le produit', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold)),
                      content: Text(isAr ? 'هل أنت متأكد من حذف هذه المادة من مرصد الأسعار؟' : 'Confirmer la suppression ?', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(isAr ? 'تراجع' : 'Annuler', style: const TextStyle(fontFamily: 'Tajawal'))),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                          onPressed: () => Navigator.pop(c, true),
                          child: Text(isAr ? 'تأكيد الحذف' : 'Supprimer', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && id != null) {
                    if (!mounted) return;
                    final api = context.read<AuthService>().api;
                    await api.deleteMarketPrice(int.parse(id.toString()));
                    if (mounted) _loadData();
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white38),
                tooltip: isAr ? 'حذف' : 'Supprimer',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceItem({required String label, required String val, required Color color, bool isBold = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 9.5, color: Colors.white54)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
      ],
    );
  }

  // ==========================================
  // TAB 2: SUPPLY ALERTS (الإخطارات التموينية والإنذار المبكر)
  // ==========================================
  Widget _buildAlertsTab(bool isAr) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFD4AF37),
      backgroundColor: const Color(0xFF1E0B26),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Banner with Issue Alert Button
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2D1035),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.crisis_alert, color: Color(0xFFEF4444), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'منظومة الإنذار المبكر والتوجيه الاستباقي' : 'Système d\'alerte précoce',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        isAr
                            ? 'إشعار فوري لفرق المفتشين بالميدان والمدير الولائي للتدخل بمناطق التذبذب'
                            : 'Notification immédiate aux brigades pour intervenir en cas de pénurie',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showCreateAlertDialog(isAr),
                  icon: const Icon(Icons.campaign, size: 16),
                  label: Text(isAr ? 'إصدار إخطار' : 'Alerter', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_alerts.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: Text(
                isAr ? 'لا توجد إخطارات تموينية حالياً ✅ السوق مستقر' : 'Aucune alerte en cours',
                style: const TextStyle(fontFamily: 'Tajawal', color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold),
              ),
            )
          else
            ..._alerts.map((alert) => _buildAlertCard(alert, isAr)),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert, bool isAr) {
    final id = alert['Id'] ?? alert['id'];
    final title = (alert['Title'] ?? alert['title'] ?? '').toString();
    final desc = (alert['Description'] ?? alert['description'] ?? '').toString();
    final muni = (alert['Municipality'] ?? alert['municipality'] ?? 'سطيف').toString();
    final sev = (alert['Severity'] ?? alert['severity'] ?? 'medium').toString();
    final status = (alert['Status'] ?? alert['status'] ?? 'open').toString();
    final targetService = (alert['DispatchedToService'] ?? alert['dispatchedToService'] ?? 'مصلحة حماية المستهلك').toString();

    Color sevColor;
    String sevText;
    switch (sev) {
      case 'critical':
        sevColor = const Color(0xFFEF4444);
        sevText = isAr ? '🔴 استعجالي حرج' : 'Critique';
        break;
      case 'high':
        sevColor = const Color(0xFFF97316);
        sevText = isAr ? '🟠 أولوية قصوى' : 'Élevée';
        break;
      case 'medium':
      default:
        sevColor = const Color(0xFFF59E0B);
        sevText = isAr ? '🟡 متابعة دورية' : 'Moyenne';
        break;
    }

    final isResolved = status == 'resolved';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF240D2D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isResolved ? Colors.white12 : sevColor.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: sevColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(sevText, style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, fontWeight: FontWeight.bold, color: sevColor)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'بلدية: $muni',
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isResolved ? const Color(0xFF10B981).withValues(alpha: 0.15) : Colors.white10,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isResolved ? (isAr ? 'تمت التسوية ✅' : 'Résolu') : (isAr ? 'قيد التدخل' : 'En cours'),
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: isResolved ? const Color(0xFF34D399) : Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            title,
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              desc,
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70, height: 1.3),
            ),
          ],
          const SizedBox(height: 8),

          Row(
            children: [
              const Icon(Icons.send, size: 12, color: Color(0xFFD4AF37)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${isAr ? "موجه إلى" : "Assigné à"}: $targetService',
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Color(0xFFFDE68A)),
                ),
              ),
              if (!isResolved && id != null)
                TextButton(
                  onPressed: () async {
                    final api = context.read<AuthService>().api;
                    await api.updateSupplyAlertStatus(int.parse(id.toString()), 'resolved');
                    _loadData();
                  },
                  child: Text(isAr ? 'تسجيل كـ منجز ومستقر' : 'Marquer résolu', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFF10B981))),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: DAILY BULLETIN (النشرة اليومية لضبط السوق)
  // ==========================================
  Widget _buildBulletinTab(bool isAr) {
    final stats = _bulletin['statistics'] as Map<String, dynamic>? ?? {};
    final total = stats['totalTracked'] ?? _prices.length;
    final stable = stats['stableCount'] ?? 0;
    final fluctuating = stats['fluctuatingCount'] ?? 0;
    final scarce = stats['scarceCount'] ?? 0;
    final activeAlerts = stats['activeAlertsCount'] ?? _alerts.where((a) => a['Status'] != 'resolved').length;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Official Bulletin Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2D1035), Color(0xFF1E0B26)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD4AF37), width: 1.2),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_balance, color: Color(0xFFD4AF37), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isAr ? 'الجمهورية الجزائرية الديمقراطية الشعبية' : 'République Algérienne Démocratique et Populaire',
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFD4AF37)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isAr ? 'وزارة التجارة الداخلية وضبط السوق الوطنية' : 'Ministère du Commerce Intérieur et de la Régulation du Marché',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              Text(
                isAr ? 'مديرية التجارة الداخلية وضبط السوق الوطنية لولاية سطيف' : 'Direction du Commerce Intérieur de la Wilaya de Sétif',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFFDE68A)),
                textAlign: TextAlign.center,
              ),
              const Divider(color: Colors.white24, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isAr ? 'النشرة اليومية لمؤشرات التموين والأسعار' : 'Bulletin Quotidien des Marchés & Prix',
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFD4AF37).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      _bulletin['date']?.toString() ?? DateTime.now().toString().split(' ')[0],
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Statistics Matrix
        Row(
          children: [
            _buildStatBox(isAr ? 'المواد' : 'Total', '$total', const Color(0xFFD4AF37), Icons.list_alt),
            const SizedBox(width: 6),
            _buildStatBox(isAr ? 'وفرة مستقرة' : 'Stables', '$stable', const Color(0xFF10B981), Icons.check_circle_outline),
            const SizedBox(width: 6),
            _buildStatBox(isAr ? 'تذبذب' : 'Fluctuants', '$fluctuating', const Color(0xFFF59E0B), Icons.warning_amber),
            const SizedBox(width: 6),
            _buildStatBox(isAr ? 'ندرة حرجة' : 'Pénuries', '$scarce', const Color(0xFFEF4444), Icons.remove_shopping_cart),
            const SizedBox(width: 6),
            _buildStatBox(isAr ? 'إخطارات' : 'Alertes', '$activeAlerts', const Color(0xFF9333EA), Icons.crisis_alert),
          ],
        ),
        const SizedBox(height: 16),

        // Regulated Products Summary Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF240D2D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified, color: Color(0xFFD4AF37), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    isAr ? 'ملخص المواد الاستراتيجية والمدعمة قانوناً' : 'Produits Stratégiques Subventionnés',
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._prices.where((p) => (p['Category'] ?? '').toString().contains('مقننة')).map((p) {
                final n = (p['CommodityName'] ?? '').toString();
                final r = (p['RetailPrice'] ?? 0).toString();
                final reg = (p['RegulatedPrice'] ?? 0).toString();
                final u = (p['Unit'] ?? '').toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('• $n', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70)),
                      Text('$r دج / $u (السعر المقنن: $reg دج)', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFDE68A))),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatBox(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF240D2D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 9.5, color: Colors.white60), textAlign: TextAlign.center, maxLines: 1),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // DIALOGS: ADD / EDIT COMMODITY & CREATE ALERT
  // ==========================================
  void _showAddPriceDialog(bool isAr) {
    final nameCtrl = TextEditingController();
    final regCtrl = TextEditingController();
    final wholeCtrl = TextEditingController();
    final retailCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'كلغ');
    final locCtrl = TextEditingController(text: 'ولاية سطيف');
    final notesCtrl = TextEditingController();
    String selectedCat = 'مواد استهلاكية عامة';
    String selectedStatus = 'sufficient';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF240D2D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFD4AF37))),
          title: Text(isAr ? 'إدراج مادة جديدة في مرصد الأسعار' : 'Ajouter un produit', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'اسم المادة الاستهلاكية *' : 'Nom du produit *')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCat,
                    dropdownColor: const Color(0xFF2D1035),
                    style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 12),
                    items: _categories.where((c) => c != 'الكل').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setDialogState(() => selectedCat = v ?? selectedCat),
                    decoration: InputDecoration(labelText: isAr ? 'تصنيف المادة' : 'Catégorie'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: regCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'السعر المقنن (إن وجد)' : 'Prix rég.'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: wholeCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'سعر الجملة' : 'Prix gros'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: retailCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'سعر التجزئة *' : 'Prix détail *'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: unitCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'الوحدة (كلغ، لتر...)' : 'Unité'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: locCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'السوق / المنطقة' : 'Marché / Zone'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    dropdownColor: const Color(0xFF2D1035),
                    style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 12),
                    items: [
                      DropdownMenuItem(value: 'abundant', child: Text(isAr ? '🟢 وفرة ممتازة' : 'Abondant')),
                      DropdownMenuItem(value: 'sufficient', child: Text(isAr ? '🟢 وفرة كافية' : 'Suffisant')),
                      DropdownMenuItem(value: 'fluctuating', child: Text(isAr ? '🟡 تذبذب طفيف' : 'Fluctuant')),
                      DropdownMenuItem(value: 'scarce', child: Text(isAr ? '🔴 ندرة وضغط' : 'Pénurie')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedStatus = v ?? selectedStatus),
                    decoration: InputDecoration(labelText: isAr ? 'حالة الوفرة بالسوق' : 'Disponibilité'),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: notesCtrl, maxLines: 2, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'ملاحظات وتوجيهات' : 'Remarques')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? 'إلغاء' : 'Annuler', style: const TextStyle(fontFamily: 'Tajawal'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final api = context.read<AuthService>().api;
                await api.addMarketPrice({
                  'commodityName': nameCtrl.text.trim(),
                  'category': selectedCat,
                  'regulatedPrice': double.tryParse(regCtrl.text) ?? 0,
                  'wholesalePrice': double.tryParse(wholeCtrl.text) ?? 0,
                  'retailPrice': double.tryParse(retailCtrl.text) ?? 0,
                  'unit': unitCtrl.text.trim(),
                  'marketLocation': locCtrl.text.trim(),
                  'supplyStatus': selectedStatus,
                  'notes': notesCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) _loadData();
              },
              child: Text(isAr ? 'تسجيل المادة' : 'Enregistrer', style: const TextStyle(fontFamily: 'Tajawal', color: Color(0xFF1E0B26), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPriceDialog(Map<String, dynamic> item, bool isAr) {
    final id = item['Id'] ?? item['id'];
    final regCtrl = TextEditingController(text: (item['RegulatedPrice'] ?? item['regulatedPrice'] ?? '').toString());
    final wholeCtrl = TextEditingController(text: (item['WholesalePrice'] ?? item['wholesalePrice'] ?? '').toString());
    final retailCtrl = TextEditingController(text: (item['RetailPrice'] ?? item['retailPrice'] ?? '').toString());
    final locCtrl = TextEditingController(text: (item['MarketLocation'] ?? item['marketLocation'] ?? '').toString());
    final notesCtrl = TextEditingController(text: (item['Notes'] ?? item['notes'] ?? '').toString());
    String selectedStatus = (item['SupplyStatus'] ?? item['supplyStatus'] ?? 'sufficient').toString();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF240D2D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFD4AF37))),
          title: Text('${isAr ? "تحيين سعر" : "Mise à jour"}: ${item["CommodityName"] ?? item["commodityName"]}', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: TextField(controller: regCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'السعر المقنن' : 'Prix rég.'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: wholeCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'سعر الجملة' : 'Prix gros'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: retailCtrl, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'سعر التجزئة الحالي *' : 'Prix détail *')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    dropdownColor: const Color(0xFF2D1035),
                    style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 12),
                    items: [
                      DropdownMenuItem(value: 'abundant', child: Text(isAr ? '🟢 وفرة ممتازة' : 'Abondant')),
                      DropdownMenuItem(value: 'sufficient', child: Text(isAr ? '🟢 وفرة كافية' : 'Suffisant')),
                      DropdownMenuItem(value: 'fluctuating', child: Text(isAr ? '🟡 تذبذب طفيف' : 'Fluctuant')),
                      DropdownMenuItem(value: 'scarce', child: Text(isAr ? '🔴 ندرة وضغط' : 'Pénurie')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedStatus = v ?? selectedStatus),
                    decoration: InputDecoration(labelText: isAr ? 'حالة الوفرة بالسوق' : 'Disponibilité'),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: locCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'السوق المرصود' : 'Marché')),
                  const SizedBox(height: 8),
                  TextField(controller: notesCtrl, maxLines: 2, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'ملاحظات الرصد' : 'Remarques')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? 'إلغاء' : 'Annuler', style: const TextStyle(fontFamily: 'Tajawal'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
              onPressed: () async {
                if (id == null) return;
                final api = context.read<AuthService>().api;
                await api.updateMarketPrice(int.parse(id.toString()), {
                  'regulatedPrice': double.tryParse(regCtrl.text) ?? 0,
                  'wholesalePrice': double.tryParse(wholeCtrl.text) ?? 0,
                  'retailPrice': double.tryParse(retailCtrl.text) ?? 0,
                  'supplyStatus': selectedStatus,
                  'marketLocation': locCtrl.text.trim(),
                  'notes': notesCtrl.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) _loadData();
              },
              child: Text(isAr ? 'حفظ التحيين' : 'Sauvegarder', style: const TextStyle(fontFamily: 'Tajawal', color: Color(0xFF1E0B26), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateAlertDialog(bool isAr) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final itemCtrl = TextEditingController();
    final muniCtrl = TextEditingController(text: 'بلدية سطيف');
    String selectedSev = 'medium';
    String selectedTarget = 'مصلحة حماية المستهلك وقمع الغش';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF240D2D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFEF4444))),
          title: Row(
            children: [
              const Icon(Icons.campaign, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Text(isAr ? 'إصدار إخطار تمويني استباقي' : 'Émettre une alerte', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'موضوع الإخطار التمويني *' : 'Objet de l\'alerte *')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: itemCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'المادة المعنية' : 'Produit'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: muniCtrl, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'البلدية المستهدفة' : 'Commune'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedSev,
                    dropdownColor: const Color(0xFF2D1035),
                    style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 12),
                    items: [
                      DropdownMenuItem(value: 'medium', child: Text(isAr ? '🟡 درجة متوسطة (متابعة عادية)' : 'Moyenne')),
                      DropdownMenuItem(value: 'high', child: Text(isAr ? '🟠 درجة عالية (تدخل سريع)' : 'Élevée')),
                      DropdownMenuItem(value: 'critical', child: Text(isAr ? '🔴 حرج واستعجالي (مداهمة فورية)' : 'Critique')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedSev = v ?? selectedSev),
                    decoration: InputDecoration(labelText: isAr ? 'درجة الخطورة' : 'Gravité'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTarget,
                    dropdownColor: const Color(0xFF2D1035),
                    style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 12),
                    items: [
                      DropdownMenuItem(value: 'مصلحة حماية المستهلك وقمع الغش', child: Text(isAr ? 'مصلحة حماية المستهلك وقمع الغش' : 'Protection Consommateurs')),
                      DropdownMenuItem(value: 'مصلحة المنافسة والتحقيقات الاقتصادية', child: Text(isAr ? 'مصلحة المنافسة والتحقيقات الاقتصادية' : 'Concurrence & Enquêtes')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedTarget = v ?? selectedTarget),
                    decoration: InputDecoration(labelText: isAr ? 'المصلحة الموجه إليها الإخطار' : 'Service destinataire'),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: descCtrl, maxLines: 3, style: const TextStyle(fontSize: 12, color: Colors.white), decoration: InputDecoration(labelText: isAr ? 'تفاصيل التذبذب والتعليمات الميدانية' : 'Détails')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isAr ? 'إلغاء' : 'Annuler', style: const TextStyle(fontFamily: 'Tajawal'))),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
              icon: const Icon(Icons.send, size: 14),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                final api = context.read<AuthService>().api;
                await api.createSupplyAlert({
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'commodityName': itemCtrl.text.trim(),
                  'municipality': muniCtrl.text.trim(),
                  'severity': selectedSev,
                  'dispatchedToService': selectedTarget,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) _loadData();
              },
              label: Text(isAr ? 'تعميم الإخطار فوراً' : 'Diffuser l\'alerte', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
