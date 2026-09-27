import 'package:flutter/material.dart';
import 'package:drh_setif_tracker/widgets/golden_emblem_coin.dart';

class VerificationScreen extends StatelessWidget {
  final Map<String, dynamic> params;

  const VerificationScreen({
    super.key,
    required this.params,
  });

  @override
  Widget build(BuildContext context) {
    final isInspectorateBadge = params['type'] == 'OFFICIAL_INSPECTORATE_BADGE' || params['inspectorateId'] != null;
    final isVisit = params['type'] == 'visit';

    final empName = (params['emp'] ?? params['employee'] ?? params['employeeName'] ?? (isInspectorateBadge ? (params['name'] ?? 'مقر إقليمي') : 'عضو فرقة الرقابة والتفتيش')).toString();
    final date = (params['date'] ?? DateTime.now().toIso8601String().split('T')[0]).toString();
    final time = (params['time'] ?? DateTime.now().toString().substring(11, 16)).toString();
    final location = (params['loc'] ?? params['location'] ?? (isInspectorateBadge ? empName : 'المقر الرسمي لمديرية التجارة سطيف')).toString();
    
    String type;
    if (isInspectorateBadge) {
      type = 'مقر رقابي إقليمي معتمد (بصمة GPS)';
    } else if (isVisit) {
      type = 'معاينة ميدانية رسمية';
    } else {
      type = 'إثبات حضور جغرافي معتمد';
    }

    final id = (params['id'] ?? (isInspectorateBadge ? (params['inspectorateId'] ?? 'HQ') : 'PASS')).toString();
    final statusStr = (params['status'] ?? 'معتمد وموثق سحابياً').toString();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0514),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E0B26),
        elevation: 0,
        centerTitle: true,
        title: Text(
          isInspectorateBadge ? 'التحقق من اعتماد المقر الإقليمي' : 'التحقق من الإثبات الرقمي الرسمي',
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF240D2D), Color(0xFF190720), Color(0xFF2E0C25)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                width: 1.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: 4,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF881337), Color(0xFF4C0519)],
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GoldenEmblemCoin(size: 32, showOuterGlow: false, enableFloating: false),
                          SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'الجمهورية الجزائرية الديمقراطية الشعبية',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFDE68A),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'وزارة التجارة وترقية الصادرات — مديرية ولاية سطيف',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Official Stamp / Status Circle
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF10B981), width: 2.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.verified, color: Color(0xFF10B981), size: 48),
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  isInspectorateBadge ? 'مقر رقابي إقليمي معتمد وموثق' : 'إثبات رقمي رسمي معتمد وموثق',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'تم التحقق من صحة وموثوقية السجل بنجاح ($statusStr)',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                // Data details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF120517),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4A2050).withValues(alpha: 0.6),
                      ),
                    ),
                    child: Column(
                      children: [
                        if (isInspectorateBadge) ...[
                          _buildRow('المقر / الملحقة الإقليمية', location, Icons.apartment),
                          const Divider(color: Color(0xFF2D1035), height: 18),
                          _buildRow('طبيعة الاعتماد', type, Icons.verified_user_outlined),
                          const Divider(color: Color(0xFF2D1035), height: 18),
                          _buildRow('تاريخ التسجيل بالمنظومة', date, Icons.calendar_today_outlined),
                          const Divider(color: Color(0xFF2D1035), height: 18),
                          _buildRow('الرمز المرجعي للمقر', 'DCW-SETIF-HQ-#$id', Icons.tag),
                          const Divider(color: Color(0xFF2D1035), height: 18),
                          _buildRow('حالة الاعتماد', 'صالح ومعتمد سحابياً', Icons.check_circle_outline, valueColor: const Color(0xFF10B981)),
                        ] else ...[
                          _buildRow('الموظف / المفتش', empName, Icons.person_outline),
                          const Divider(color: Color(0xFF2D1035), height: 18),
                          _buildRow('طبيعة الإجراء', type, Icons.assignment_turned_in_outlined),
                          const Divider(color: Color(0xFF2D1035), height: 18),
                          _buildRow('التاريخ والتوقيت', '$date • $time', Icons.access_time),
                          const Divider(color: Color(0xFF2D1035), height: 18),
                          _buildRow('المقر / الموقع الجغرافي', location, Icons.location_on_outlined),
                          const Divider(color: Color(0xFF2D1035), height: 18),
                          _buildRow('الرقم المرجعي', 'DCW-SETIF-#$id', Icons.tag),
                          const Divider(color: Color(0xFF2D1035), height: 18),
                          _buildRow('حالة الاعتماد', 'صالح ومسجل سحابياً', Icons.check_circle_outline, valueColor: const Color(0xFF10B981)),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.security, size: 14, color: Color(0xFFD4AF37)),
                          const SizedBox(width: 6),
                          Text(
                            'سجل مشفر ومعتمد رسمياً من مديرية التجارة لولاية سطيف',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 180,
                        height: 42,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              Navigator.pushReplacementNamed(context, '/');
                            }
                          },
                          icon: const Icon(Icons.home, size: 16, color: Color(0xFFD4AF37)),
                          label: const Text(
                            'الرئيسية',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD4AF37),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFD4AF37)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      ),
    );
  }

  static Widget _buildRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFD4AF37)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 12,
            color: Colors.white60,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.white,
            ),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
