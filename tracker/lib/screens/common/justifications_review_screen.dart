import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:drh_setif_tracker/services/auth_service.dart';
import 'package:drh_setif_tracker/utils/theme.dart';

class JustificationsReviewScreen extends StatefulWidget {
  const JustificationsReviewScreen({super.key});

  static void show(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const JustificationsReviewScreen()),
    );
  }

  @override
  State<JustificationsReviewScreen> createState() => _JustificationsReviewScreenState();
}

class _JustificationsReviewScreenState extends State<JustificationsReviewScreen> {
  List<Map<String, dynamic>> _justifications = [];
  bool _isLoading = true;
  String _filter = 'pending'; // 'pending', 'approved', 'rejected', 'all'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<AuthService>().api;
      final list = await api.getJustifications(status: _filter == 'all' ? null : _filter);
      if (mounted) {
        setState(() {
          _justifications = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(int id, String newStatus) async {
    try {
      final api = context.read<AuthService>().api;
      await api.updateJustificationStatus(id, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'approved' ? '✅ تمت المصادقة على التبرير' : '❌ تم رفض التبرير'),
            backgroundColor: newStatus == 'approved' ? AppTheme.SuccessColor : AppTheme.DangerColor,
          ),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: AppTheme.DangerColor),
        );
      }
    }
  }

  void _showDetailsModal(Map<String, dynamic> j) {
    final name = j['NomAr'] != null ? '${j['NomAr']} ${j['PrenomAr']}' : '${j['Nom']} ${j['Prenom']}';
    final service = (j['Service'] ?? '').toString();
    final typeTitle = (j['Title'] ?? j['Type'] ?? 'تبرير غياب').toString();
    final startDate = j['StartDate']?.toString().split('T').first ?? '';
    final endDate = j['EndDate']?.toString().split('T').first ?? '';
    final daysCount = j['DaysCount'] ?? 1;
    final notes = j['Notes']?.toString();
    final photo = j['DocumentPhoto']?.toString();
    final status = (j['Status'] ?? 'pending').toString();
    final int id = (j['Id'] as num).toInt();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
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
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, color: Color(0xFFD4AF37)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'تفاصيل ومرفقات مبرر الغياب',
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Employee header
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFFD4AF37),
                            child: Icon(Icons.person, color: Colors.black),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(service, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.TextSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Leave details
                    _infoCardRow('نوع التبرير', typeTitle, Icons.category),
                    _infoCardRow('الفترة', 'من $startDate إلى $endDate ($daysCount أيام عمل)', Icons.calendar_month),
                    if (notes != null && notes.isNotEmpty) _infoCardRow('توضيحات العون', notes, Icons.notes),
                    const SizedBox(height: 14),

                    // Document Certificate Photo
                    const Text('الوثيقة الثبوتية المرفقة:', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
                    const SizedBox(height: 8),
                    if (photo != null && photo.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: photo.startsWith('data:image')
                            ? Image.memory(base64Decode(photo.split(',').last), height: 240, width: double.infinity, fit: BoxFit.contain)
                            : Image.network(photo, height: 240, width: double.infinity, fit: BoxFit.contain),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)),
                        child: const Center(
                          child: Text('لم يتم إرفاق صورة مستند', style: TextStyle(fontFamily: 'Tajawal', color: AppTheme.TextSecondary)),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Actions if pending
                    if (status == 'pending') ...[
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _updateStatus(id, 'approved');
                              },
                              icon: const Icon(Icons.check, color: Colors.white),
                              label: const Text('مصادقة وقبول التبرير', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.SuccessColor,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _updateStatus(id, 'rejected');
                              },
                              icon: const Icon(Icons.close, color: Colors.white),
                              label: const Text('رفض التبرير', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.DangerColor,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: status == 'approved' ? AppTheme.SuccessColor.withValues(alpha: 0.15) : AppTheme.DangerColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            status == 'approved' ? '✔️ تمت المصادقة على هذا المبرر' : '❌ تم رفض هذا المبرر',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.bold,
                              color: status == 'approved' ? AppTheme.SuccessColor : AppTheme.DangerColor,
                            ),
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

  Widget _infoCardRow(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFD4AF37)),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.TextSecondary)),
          Expanded(child: Text(value, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.BackgroundColor,
        appBar: AppBar(
          backgroundColor: const Color(0xFF2D1035),
          centerTitle: true,
          title: const Text('مراجعة مبررات الغياب والعطل', style: TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(icon: const Icon(Icons.refresh, color: Color(0xFFD4AF37)), onPressed: _load),
          ],
        ),
        body: Column(
          children: [
            // Filter tabs
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF1E1026),
              child: Row(
                children: [
                  _filterChip('pending', 'قيد المراجعة'),
                  const SizedBox(width: 8),
                  _filterChip('approved', 'المصادق عليها'),
                  const SizedBox(width: 8),
                  _filterChip('rejected', 'المرفوضة'),
                  const SizedBox(width: 8),
                  _filterChip('all', 'الكل'),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.AccentColor))
                  : _justifications.isEmpty
                      ? const Center(
                          child: Text('لا توجد مبررات غياب في هذه القائمة', style: TextStyle(fontFamily: 'Tajawal', color: AppTheme.TextSecondary)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _justifications.length,
                          itemBuilder: (context, index) {
                            final j = _justifications[index];
                            final name = j['NomAr'] != null ? '${j['NomAr']} ${j['PrenomAr']}' : '${j['Nom']} ${j['Prenom']}';
                            final service = (j['Service'] ?? '').toString();
                            final typeTitle = (j['Title'] ?? j['Type'] ?? 'تبرير غياب').toString();
                            final startDate = j['StartDate']?.toString().split('T').first ?? '';
                            final status = (j['Status'] ?? 'pending').toString();

                            Color statusColor = const Color(0xFFD4AF37);
                            String statusText = 'قيد المراجعة';
                            if (status == 'approved') {
                              statusColor = AppTheme.SuccessColor;
                              statusText = 'تمت المصادقة';
                            } else if (status == 'rejected') {
                              statusColor = AppTheme.DangerColor;
                              statusText = 'مرفوض';
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.CardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: statusColor.withValues(alpha: 0.15),
                                  child: Icon(Icons.file_present, color: statusColor),
                                ),
                                title: Text(name, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text('$service • $typeTitle ($startDate)', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.TextSecondary)),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(statusText, style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: statusColor, fontWeight: FontWeight.bold)),
                                ),
                                onTap: () => _showDetailsModal(j),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = _filter == key;
    return GestureDetector(
      onTap: () {
        setState(() => _filter = key);
        _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD4AF37) : Colors.black26,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }
}
