import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:drh_setif_tracker/services/auth_service.dart';
import 'package:drh_setif_tracker/utils/theme.dart';

class JustificationSubmissionModal extends StatefulWidget {
  final Map<String, dynamic>? employee;

  const JustificationSubmissionModal({super.key, this.employee});

  static Future<bool?> show(BuildContext context, {Map<String, dynamic>? employee}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JustificationSubmissionModal(employee: employee),
    );
  }

  @override
  State<JustificationSubmissionModal> createState() => _JustificationSubmissionModalState();
}

class _JustificationSubmissionModalState extends State<JustificationSubmissionModal> {
  String _selectedType = 'bereavement_3days'; // 'bereavement_3days', 'medical', 'family', 'external_mission'
  final _titleCtrl = TextEditingController(text: 'عطلة وفاة أخ/أقارب (3 أيام مدفوعة الأجر)');
  final _notesCtrl = TextEditingController();
  final DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 2));
  int _daysCount = 3;
  String? _documentPhotoBase64;
  Uint8List? _documentPhotoBytes;
  bool _isLoading = false;

  final Map<String, Map<String, dynamic>> _typeOptions = {
    'bereavement_3days': {
      'title': 'عطلة وفاة أخ/أخت أو أقارب مباشرين (3 أيام)',
      'defaultDays': 3,
      'desc': 'المادة 212 من الأمر 06-03: عطلة استثنائية مدفوعة الأجر كاملة',
      'icon': Icons.groups_2_outlined,
    },
    'medical': {
      'title': 'شهادة طبية / عطلة مرضية',
      'defaultDays': 1,
      'desc': 'تبرير بداعي المرض مدعم بشهادة طبية رسمية',
      'icon': Icons.medical_services_outlined,
    },
    'family': {
      'title': 'حدث عائلي (زواج، ولادة، ختان)',
      'defaultDays': 3,
      'desc': 'المادة 212: عطلة خاصة مدفوعة الأجر بمناسبة حدث عائلي',
      'icon': Icons.favorite_outline,
    },
    'external_mission': {
      'title': 'مهمة رسمية خارجية / تسخير',
      'defaultDays': 1,
      'desc': 'أمر بمهمة خارجية موقع من طرف الإدارة',
      'icon': Icons.assignment_outlined,
    },
  };

  void _onTypeChanged(String newType) {
    setState(() {
      _selectedType = newType;
      final opt = _typeOptions[newType]!;
      _titleCtrl.text = opt['title'] as String;
      _daysCount = opt['defaultDays'] as int;
      _endDate = _startDate.add(Duration(days: _daysCount - 1));
    });
  }

  Future<void> _pickDocumentImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 75, maxWidth: 1000);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _documentPhotoBytes = bytes;
          _documentPhotoBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل الصورة: $e'), backgroundColor: AppTheme.DangerColor),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد عنوان التبرير'), backgroundColor: AppTheme.DangerColor),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = context.read<AuthService>().api;
      final auth = context.read<AuthService>();
      final empId = widget.employee?['Id'] ?? auth.currentUser?.employeeId ?? auth.currentUser?.id;

      await api.submitJustification({
        'employeeId': empId,
        'type': _selectedType,
        'title': _titleCtrl.text.trim(),
        'startDate': intl.DateFormat('yyyy-MM-dd').format(_startDate),
        'endDate': intl.DateFormat('yyyy-MM-dd').format(_endDate),
        'daysCount': _daysCount,
        'documentPhoto': _documentPhotoBase64 != null ? 'data:image/jpeg;base64,$_documentPhotoBase64' : null,
        'notes': _notesCtrl.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم إرسال مبرر الغياب بنجاح وهو قيد المراجعة والمصادقة الإدارية'),
            backgroundColor: AppTheme.SuccessColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إرسال التبرير: $e'), backgroundColor: AppTheme.DangerColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = intl.DateFormat('yyyy/MM/dd');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
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
                  const Icon(Icons.file_present_outlined, color: Color(0xFFD4AF37)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'تقديم مبرر غياب / عطلة قانونية خاصة',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Type selection chips
                  const Text(
                    'نوع التبرير أو العطلة القانونية:',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37)),
                  ),
                  const SizedBox(height: 8),
                  ..._typeOptions.entries.map((entry) {
                    final key = entry.key;
                    final opt = entry.value;
                    final isSelected = _selectedType == key;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFD4AF37).withValues(alpha: 0.15) : Colors.black12,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFD4AF37) : Colors.white12,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(opt['icon'] as IconData, color: isSelected ? const Color(0xFFD4AF37) : AppTheme.TextSecondary),
                        title: Text(
                          opt['title'] as String,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          opt['desc'] as String,
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppTheme.TextSecondary),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Color(0xFFD4AF37))
                            : const Icon(Icons.radio_button_unchecked, color: Colors.white24),
                        onTap: () => _onTypeChanged(key),
                      ),
                    );
                  }),
                  const SizedBox(height: 14),

                  // Dates and days count
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('تاريخ البداية', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.TextSecondary)),
                              const SizedBox(height: 4),
                              Text(dateFormat.format(_startDate), style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('عدد الأيام', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.TextSecondary)),
                              const SizedBox(height: 4),
                              Text('$_daysCount أيام عمل', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Notes / Explanations
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'ملاحظات وتفاصيل إضافية (اختياري)',
                      labelStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.black12,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Attach Document Photo (Medical cert, Death cert...)
                  const Text(
                    'الوثيقة الثبوتية (صورة الشهادة الطبية / شهادة الوفاة):',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37)),
                  ),
                  const SizedBox(height: 8),
                  if (_documentPhotoBytes != null)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(_documentPhotoBytes!, height: 160, width: double.infinity, fit: BoxFit.cover),
                        ),
                        IconButton(
                          icon: const CircleAvatar(backgroundColor: Colors.black87, radius: 14, child: Icon(Icons.close, size: 16, color: Colors.white)),
                          onPressed: () => setState(() {
                            _documentPhotoBytes = null;
                            _documentPhotoBase64 = null;
                          }),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDocumentImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt, color: Color(0xFFD4AF37)),
                            label: const Text('التقاط بالكاميرا', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Color(0xFFD4AF37)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDocumentImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library, color: Color(0xFFD4AF37)),
                            label: const Text('من المعرض', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Colors.white24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.send, color: Colors.black),
                      label: Text(
                        _isLoading ? 'جاري الإرسال...' : 'إرسال التبرير للإدارة والمصادقة',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
