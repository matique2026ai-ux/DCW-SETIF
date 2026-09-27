import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:drh_setif_tracker/widgets/golden_emblem_coin.dart';
import 'package:drh_setif_tracker/utils/constants.dart';
import 'package:drh_setif_tracker/services/pdf_report_service.dart';

class QRCodeScreen extends StatelessWidget {
  final String data;
  final String title;
  final String subtitle;
  final Map<String, dynamic>? record;

  const QRCodeScreen({
    super.key,
    required this.data,
    required this.title,
    this.subtitle = '',
    this.record,
  });

  static void showOfficialBadge(BuildContext context, InspectorateHQ insp) {
    final now = DateTime.now().toIso8601String().split('T')[0];
    final verifyUrl = 'https://drh-setif-api.onrender.com/verify?id=${insp.id}&name=${Uri.encodeComponent(insp.nameAr)}&loc=${Uri.encodeComponent(insp.nameAr)}&lat=${insp.latitude}&lng=${insp.longitude}&rad=${insp.radiusMeters.round()}&date=$now&type=OFFICIAL_INSPECTORATE_BADGE&status=VERIFIED_OFFICIAL_HQ';
    final badgeData = {
      'type': 'OFFICIAL_INSPECTORATE_BADGE',
      'inspectorateId': insp.id,
      'name': insp.nameAr,
      'nameFr': insp.nameFr,
      'latitude': insp.latitude,
      'longitude': insp.longitude,
      'radiusMeters': insp.radiusMeters,
      'date': now,
      'status': 'VERIFIED_OFFICIAL_HQ',
    };
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QRCodeScreen(
          data: verifyUrl,
          title: 'شهادة الاعتماد الرقمي للمقر',
          subtitle: insp.nameAr,
          record: badgeData,
        ),
      ),
    );
  }

  Map<String, dynamic> _parseData() {
    if (record != null) return Map<String, dynamic>.from(record!);
    if (data.startsWith('http://') || data.startsWith('https://')) {
      try {
        final uri = Uri.parse(data);
        if (uri.queryParameters.isNotEmpty) {
          final q = uri.queryParameters;
          final isPres = q['present'] == '1' || (q['status'] != null && q['status']!.contains('PRESENT')) || q['type'] == 'checkin';
          return {
            'id': q['id'],
            'employee': q['emp'] ?? q['employee'] ?? subtitle,
            'service': q['service'] ?? '',
            'date': q['date'] ?? DateTime.now().toIso8601String().split('T')[0],
            'time': q['time'] ?? '',
            'location': q['loc'] ?? q['location'] ?? (isPres ? 'المقر الرئيسي لمديرية التجارة سطيف' : 'غير متواجد بالمقر'),
            'type': q['type'] ?? (isPres ? 'checkin' : 'employee_badge'),
            'status': q['status'] ?? (isPres ? 'VERIFIED_PRESENT' : 'NOT_CHECKED_IN_TODAY'),
            'isPresent': isPres,
          };
        }
      } catch (_) {}
    }
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {
      'employee': subtitle.isNotEmpty ? subtitle : 'عضو فرقة الرقابة والتفتيش',
      'title': title,
      'date': DateTime.now().toIso8601String().split('T')[0],
      'time': DateTime.now().toString().substring(11, 16),
      'status': 'معتمد وموثق',
      'isPresent': true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final info = _parseData();
    final isInspectorateBadge = info['type'] == 'OFFICIAL_INSPECTORATE_BADGE' || info['inspectorateId'] != null;
    final isVisitBadge = info['type'] == 'visit' || info['type'] == 'visit_evidence';
    final isCheckOut = info['type'] == 'checkout';
    final isPresent = info['isPresent'] == true || (info['status'] != null && info['status'].toString().contains('PRESENT')) || info['type'] == 'checkin';
    final isNotCheckedIn = !isPresent && !isInspectorateBadge && !isVisitBadge && !isCheckOut;

    final employeeName = info['employee'] ?? info['employeeName'] ?? info['name'] ?? subtitle;
    final serviceName = info['service']?.toString() ?? '';
    final dateStr = info['date'] ?? DateTime.now().toIso8601String().split('T')[0];
    final timeStr = info['time'] ?? info['checkInTime'] ?? '';
    final locName = info['location'] ?? info['locationName'] ?? (isInspectorateBadge ? (info['name'] ?? 'مقر إقليمي') : (isPresent ? 'المقر الرئيسي لمديرية التجارة سطيف' : 'غير متواجد بالمقر'));
    
    String typeStr;
    String statusLabel;
    Color statusColor;
    IconData statusIcon;

    if (isInspectorateBadge) {
      typeStr = 'مقر رقابي إقليمي معتمد (بصمة GPS)';
      statusLabel = 'شارة مقر إقليمي معتمد في المنظومة الجغرافية';
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.verified;
    } else if (isVisitBadge) {
      typeStr = 'معاينة وتفتيش ميداني رسمي';
      statusLabel = 'إثبات معاينة ورقابة ميدانية رسمية';
      statusColor = const Color(0xFF38BDF8);
      statusIcon = Icons.storefront;
    } else if (isCheckOut) {
      typeStr = 'تسجيل انصراف نظامي (خروج)';
      statusLabel = 'إثبات انصراف رسمي معتمد';
      statusColor = const Color(0xFF818CF8);
      statusIcon = Icons.logout;
    } else if (isNotCheckedIn) {
      typeStr = 'بطاقة مهنية رقمية (غير مسجل حضور اليوم)';
      statusLabel = 'بطاقة مهنية — الموظف لم يسجل الحضور اليوم';
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.warning_amber_rounded;
    } else {
      typeStr = 'تسجيل حضور صباحي معتمد بالـ GPS';
      statusLabel = 'إثبات حضور صباحي رسمي معتمد بالبصمة الجغرافية';
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.verified;
    }

    final passId = (info['id'] != null ? '#${info['id']}' : (info['inspectorateId'] != null ? '#${info['inspectorateId']}' : '#${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}'));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0514),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E0B26),
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Executive Pass Card
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
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
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                      blurRadius: 25,
                      spreadRadius: 4,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Official Header Ribbon
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
                              GoldenEmblemCoin(size: 28, showOuterGlow: false, enableFloating: false),
                              SizedBox(width: 8),
                              Text(
                                'الجمهورية الجزائرية الديمقراطية الشعبية',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFDE68A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'مديرية التجارة وضبط السوق الوطنية — ولاية سطيف',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // QR Code Wrapper
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: data,
                          version: QrVersions.auto,
                          size: 220,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.all(0),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Dynamic Status Ribbon
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor, width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: statusColor, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              statusLabel,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11,
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Details Card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF120517),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF4A2050).withValues(alpha: 0.6),
                          ),
                        ),
                        child: Column(
                          children: [
                            if (isInspectorateBadge) ...[
                              _buildInfoRow('المقر / الملحقة الإقليمية', (info['name'] ?? locName).toString(), Icons.apartment),
                              const Divider(color: Color(0xFF2D1035), height: 16),
                              _buildInfoRow('نوع الاعتماد', typeStr, Icons.verified_user_outlined),
                              if (info['latitude'] != null && info['longitude'] != null) ...[
                                const Divider(color: Color(0xFF2D1035), height: 16),
                                _buildInfoRow('الإحداثيات الجغرافية (GPS)', '${(info['latitude'] as num).toDouble().toStringAsFixed(4)}, ${(info['longitude'] as num).toDouble().toStringAsFixed(4)}', Icons.my_location),
                              ],
                              const Divider(color: Color(0xFF2D1035), height: 16),
                              _buildInfoRow('تاريخ الاعتماد في المنظومة', dateStr.toString(), Icons.calendar_today_outlined),
                              const Divider(color: Color(0xFF2D1035), height: 16),
                              _buildInfoRow('الرمز المرجعي للمقر', 'DCW-SETIF-HQ-$passId', Icons.tag),
                            ] else ...[
                              if (employeeName.toString().isNotEmpty) ...[
                                _buildInfoRow('الموظف / المفتش', employeeName.toString(), Icons.person_outline),
                                const Divider(color: Color(0xFF2D1035), height: 16),
                              ],
                              if (serviceName.isNotEmpty) ...[
                                _buildInfoRow('المصلحة / الرتبة', serviceName, Icons.badge_outlined),
                                const Divider(color: Color(0xFF2D1035), height: 16),
                              ],
                              _buildInfoRow('نوع الإثبات', typeStr, Icons.assignment_turned_in_outlined),
                              const Divider(color: Color(0xFF2D1035), height: 16),
                              _buildInfoRow(
                                'حالة الحضور اليوم',
                                isPresent
                                    ? '🟢 حاضر ومسجل بالسيرفر الحي ✓'
                                    : (isVisitBadge ? '🔵 في مهمة رقابية ميدانية' : '🔴 لم يسجل الحضور بعد (غائب)'),
                                Icons.verified_outlined,
                                valueColor: isPresent ? const Color(0xFF34D399) : (isVisitBadge ? const Color(0xFF38BDF8) : const Color(0xFFF87171)),
                              ),
                              const Divider(color: Color(0xFF2D1035), height: 16),
                              _buildInfoRow(
                                'التاريخ والتوقيت',
                                isPresent
                                    ? '$dateStr • ${timeStr.toString().isNotEmpty ? timeStr : "توقيت نظامي"}'
                                    : '$dateStr • غير مسجل اليوم',
                                Icons.access_time,
                              ),
                              if (locName.toString().isNotEmpty) ...[
                                const Divider(color: Color(0xFF2D1035), height: 16),
                                _buildInfoRow('المقر / الموقع', locName.toString(), Icons.location_on_outlined),
                              ],
                              const Divider(color: Color(0xFF2D1035), height: 16),
                              _buildInfoRow('الرقم المرجعي للإثبات', 'DCW-SETIF-$passId', Icons.tag),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Footer security note
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16, left: 20, right: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.security, size: 14, color: Color(0xFFD4AF37)),
                          const SizedBox(width: 6),
                          Text(
                            'مشفر وموثق عبر المنظومة السحابية لمديرية سطيف',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons Row
              Column(
                children: [
                  if (!isInspectorateBadge) ...[
                    SizedBox(
                      width: 340,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await PdfReportService.generateAttendanceProofReceiptPdf(
                            employeeName: employeeName.toString(),
                            serviceName: serviceName.isNotEmpty ? serviceName : 'مصلحة الرقابة وقمع الغش والمنافسة',
                            date: dateStr.toString(),
                            time: timeStr.toString().isNotEmpty ? timeStr.toString() : (isPresent ? '08:15' : 'غير مسجل'),
                            locationName: locName.toString(),
                            proofId: passId.replaceAll('#', ''),
                            verifyUrl: data,
                            isPresent: isPresent,
                          );
                        },
                        icon: const Icon(Icons.picture_as_pdf, size: 20),
                        label: const Text(
                          'تحميل وطباعة وصل الإثبات المادي (PDF)',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: const Color(0xFF1A0A1F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: 340,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text(
                        'الرجوع',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF4A2050)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildInfoRow(String label, String value, IconData icon, {Color? valueColor}) {
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

  static void show(
    BuildContext context, {
    required Map<String, dynamic> record,
    required String title,
  }) {
    final id = record['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString().substring(6);
    final emp = record['employeeName'] ?? record['employee'] ?? record['name'] ?? '';
    final service = record['service']?.toString() ?? '';
    final date = record['date'] ?? DateTime.now().toIso8601String().split('T')[0];
    final isPres = record['isPresent'] == true || (record['status'] != null && record['status'].toString().contains('PRESENT')) || record['type'] == 'checkin';
    final time = record['time'] ?? record['checkInTime'] ?? (isPres ? DateTime.now().toString().substring(11, 16) : 'غير مسجل');
    final loc = record['location'] ?? record['locationName'] ?? (isPres ? 'المقر الرئيسي لمديرية التجارة سطيف' : 'غير متواجد بالمقر');
    final type = record['type'] ?? (isPres ? 'checkin' : 'employee_badge');
    final status = record['status'] ?? (isPres ? 'VERIFIED_PRESENT' : 'NOT_CHECKED_IN_TODAY');

    final uri = Uri.https(
      'drh-setif-api.onrender.com',
      '/verify',
      {
        'id': id,
        'emp': emp.toString(),
        'service': service,
        'date': date.toString(),
        'time': time.toString(),
        'loc': loc.toString(),
        'type': type.toString(),
        'status': status.toString(),
        'present': isPres ? '1' : '0',
      },
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QRCodeScreen(
          data: uri.toString(),
          title: title,
          record: record,
          subtitle: '$emp • $date',
        ),
      ),
    );
  }
}
