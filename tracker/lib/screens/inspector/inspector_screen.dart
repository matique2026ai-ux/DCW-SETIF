import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:drh_setif_tracker/services/auth_service.dart';
import 'package:drh_setif_tracker/services/offline_sync_service.dart';
import 'package:drh_setif_tracker/utils/theme.dart';
import 'package:drh_setif_tracker/utils/app_localizations.dart';
import 'package:drh_setif_tracker/providers/language_provider.dart';
import 'package:drh_setif_tracker/utils/constants.dart';
import 'package:drh_setif_tracker/screens/auth/login_screen.dart';
import 'package:drh_setif_tracker/screens/common/qr_code_screen.dart';
import 'package:drh_setif_tracker/screens/common/justification_submission_modal.dart';
import 'package:drh_setif_tracker/screens/common/change_password_dialog.dart';
import 'package:drh_setif_tracker/screens/common/app_footer.dart';
import 'package:drh_setif_tracker/screens/inspector/inspector_inquiries_sheet.dart';
import 'package:drh_setif_tracker/widgets/golden_emblem_coin.dart';
import 'package:drh_setif_tracker/screens/common/mandatory_security_setup_dialog.dart';

class InspectorScreen extends StatefulWidget {
  const InspectorScreen({super.key});

  @override
  State<InspectorScreen> createState() => _InspectorScreenState();
}

class _InspectorScreenState extends State<InspectorScreen> {
  Timer? _pollTimer;
  bool _isCheckedIn = false;
  bool _isCheckedOut = false;
  bool _isLoading = false;
  bool _isSyncing = false;
  int _pendingSyncCount = 0;
  int _pendingInquiryCount = 0;
  String? _checkInTime;
  String? _checkOutTime;
  String? _checkInPhoto;
  double? _checkInLat;
  double? _checkInLng;
  List<Map<String, dynamic>> _todayVisits = [];
  int _visitCount = 0;
  Map<String, dynamic>? _activeProgram;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _loadActiveProgram();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadStatus();
        _loadActiveProgram();
      }
    });
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
    _pollTimer?.cancel();
    super.dispose();
  }

  String _formatTime(dynamic val) {
    if (val == null) return '';
    final str = val.toString().trim();
    if (str.isEmpty || str == 'null') return '';
    try {
      final dt = DateTime.tryParse(str);
      if (dt != null) {
        final local = dt.toLocal();
        final hh = local.hour.toString().padLeft(2, '0');
        final mm = local.minute.toString().padLeft(2, '0');
        return '$hh:$mm';
      }
      if (str.contains('T')) {
        final timePart = str.split('T')[1];
        if (timePart.length >= 5) return timePart.substring(0, 5);
      }
      if (str.contains(' ')) {
        final parts = str.split(' ');
        if (parts.length > 1 && parts[1].length >= 5) {
          return parts[1].substring(0, 5);
        }
      }
      if (str.length >= 5) return str.substring(0, 5);
    } catch (_) {}
    return str;
  }

  Future<void> _loadActiveProgram() async {
    try {
      final auth = context.read<AuthService>();
      final user = auth.currentUser;
      final api = auth.api;
      final deptName = user?.serviceName ?? '';
      final empName = user?.fullName ?? '';
      final progs = await api.getPrograms(service: deptName.isNotEmpty ? deptName : null);
      if (progs.isNotEmpty && mounted) {
        // Match by inspector name first in Title, Description (where mission members are listed), or FocusPoints
        Map<String, dynamic>? matchingProg;
        for (final p in progs) {
          final t = (p['Title'] ?? p['title'] ?? '').toString();
          final d = (p['Description'] ?? p['description'] ?? '').toString();
          final fp = (p['FocusPoints'] ?? p['focuspoints'] ?? '').toString();
          if (empName.isNotEmpty && (t.contains(empName) || d.contains(empName) || fp.contains(empName))) {
            matchingProg = p;
            break;
          }
        }
        // If not explicitly assigned, check for general department-wide missions
        if (matchingProg == null) {
          for (final p in progs) {
            final t = (p['Title'] ?? p['title'] ?? '').toString();
            final d = (p['Description'] ?? p['description'] ?? '').toString();
            if (t.contains('تعميم') || d.contains('تعميم شامل') || d.contains('المصلحة بالكامل')) {
              matchingProg = p;
              break;
            }
          }
        }
        matchingProg ??= progs.first;
        setState(() {
          _activeProgram = matchingProg;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStatus() async {
    final pending = await OfflineSyncService.getPendingCount();
    if (mounted) {
      setState(() => _pendingSyncCount = pending);
    }

    try {
      if (!mounted) return;
      final auth = context.read<AuthService>();
      final api = auth.api;
      final empId = auth.currentUser?.employeeId ?? auth.currentUser?.id ?? 1;
      final att = await api.getTodayAttendance();
      final visits = await api.getTodayVisits(empId);
      final offlineVisits = await OfflineSyncService.getCachedVisits();

      final inqs = await api.getInquiries(employeeId: empId);
      final pendingInq = inqs.where((i) => (i['Status'] ?? i['status']) == 'sent').length;

      if (mounted) {
        setState(() {
          _pendingInquiryCount = pendingInq;
          if (att != null && att['Id'] != null) {
            final isOut = att['IsCheckedOut'] == true || att['IsCheckedOut'] == 1 || att['CheckOutTime'] != null;
            _isCheckedOut = isOut;
            _isCheckedIn = !isOut;
            _checkInTime = _formatTime(att['CheckInTime']);
            _checkOutTime = _formatTime(att['CheckOutTime']);
            _checkInPhoto = att['CheckInPhoto']?.toString();
            _checkInLat = att['CheckInLatitude'] != null
                ? double.tryParse(att['CheckInLatitude'].toString())
                : null;
            _checkInLng = att['CheckInLongitude'] != null
                ? double.tryParse(att['CheckInLongitude'].toString())
                : null;
          } else {
            _isCheckedIn = false;
            _isCheckedOut = false;
            _checkInTime = null;
            _checkOutTime = null;
          }
          _todayVisits = [...offlineVisits, ...visits];
          _visitCount = _todayVisits.length;
        });
      }

      if (pending > 0) {
        _syncPendingItems(silent: true);
      }
    } catch (_) {
      final cachedAtt = await OfflineSyncService.getCachedAttendance();
      final cachedVisits = await OfflineSyncService.getCachedVisits();
      if (mounted) {
        setState(() {
          if (cachedAtt != null) {
            final isOut = cachedAtt['isCheckedOut'] == true;
            _isCheckedOut = isOut;
            _isCheckedIn = cachedAtt['isCheckedIn'] == true && !isOut;
            _checkInTime = cachedAtt['checkInTime']?.toString();
            _checkOutTime = cachedAtt['checkOutTime']?.toString();
            _checkInPhoto = cachedAtt['photo']?.toString();
            _checkInLat = double.tryParse(cachedAtt['latitude']?.toString() ?? '');
            _checkInLng = double.tryParse(cachedAtt['longitude']?.toString() ?? '');
          }
          _todayVisits = cachedVisits;
          _visitCount = cachedVisits.length;
        });
      }
    }
  }

  Future<void> _syncPendingItems({bool silent = false}) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final api = context.read<AuthService>().api;
      final result = await OfflineSyncService.syncAll(api);
      final int synced = (result['syncedCount'] as num?)?.toInt() ?? 0;
      final int remaining = await OfflineSyncService.getPendingCount();

      if (mounted) {
        setState(() {
          _pendingSyncCount = remaining;
          _isSyncing = false;
        });

        if (synced > 0) {
          _loadStatus();
        }

        if (!silent && mounted) {
          if (synced > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '✅ تمت مزامنة $synced عمليات بنجاح مع السيرفر',
                  style: const TextStyle(fontFamily: 'Tajawal'),
                ),
                backgroundColor: AppTheme.SuccessColor,
              ),
            );
          } else if (remaining > 0) {
            final List<dynamic> errors = (result['errors'] as List<dynamic>?) ?? [];
            final String errorMsg = errors.isNotEmpty
                ? errors.first.toString()
                : '⚠️ تعذر المزامنة: يرجى التحقق من اتصال السيرفر';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  errorMsg,
                  style: const TextStyle(fontFamily: 'Tajawal'),
                ),
                backgroundColor: AppTheme.WarningColor,
                action: SnackBarAction(
                  label: 'مسح العالق',
                  textColor: Colors.white,
                  onPressed: () async {
                    await OfflineSyncService.clearAll();
                    if (mounted) {
                      setState(() => _pendingSyncCount = 0);
                      _loadStatus();
                    }
                  },
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ خطأ: $e', style: const TextStyle(fontFamily: 'Tajawal')),
              backgroundColor: AppTheme.WarningColor,
            ),
          );
        }
      }
    }
  }

  Future<Position?> _getPosition() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services disabled on device
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) return null;

      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (_) {
        try {
          return await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
        } catch (_) {
          return await Geolocator.getLastKnownPosition();
        }
      }
    } catch (_) {
      return null;
    }
  }

  Future<String?> _pickPhoto({bool fromGallery = false}) async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 50,
        maxWidth: 600,
      );
      if (photo == null) return null;
      final bytes = await photo.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      return null;
    }
  }

  Future<void> _checkIn() async {
    final loc = AppLocalizations.of(context);
    setState(() => _isLoading = true);

    final Position? pos = await _getPosition();
    if (pos == null) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.location_off, color: AppTheme.DangerColor, size: 26),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تعذر تحديد موقع GPS',
                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          content: const Text(
            '⚠️ تنبيه أمني إلزامي:\nلم يتمكن التطبيق من قراءة إحداثيات موقعك الجغرافي الفعلي (GPS).\n\n• يرجى تفعيل خدمة الموقع (GPS) في الهاتف أو المتصفح.\n• التأكد من منح التطبيق صلاحية الموقع الجغرافي الدقيق.\n• يُمنع قانوناً تسجيل الحضور الصباحي دون بصمة جغرافية حقيقية وموثقة.',
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.white70, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.AccentColor),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('حسناً، مفهوم', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;

    final nearestHQ = AppConstants.findNearestHQ(pos.latitude, pos.longitude);
    final distance = AppConstants.distanceBetween(
      pos.latitude,
      pos.longitude,
      nearestHQ.latitude,
      nearestHQ.longitude,
    );
    final bool isAtHQ = distance <= nearestHQ.radiusMeters;

    String locationName = isAtHQ ? nearestHQ.nameAr : 'مهمة ميدانية خارجية (${nearestHQ.nameAr} - ${distance.round()}م)';
    String? missionReason;

    // Strict Enforcement: If outside all official inspectorates/HQ
    if (!isAtHQ) {
      setState(() => _isLoading = false);

      // If no official active program is assigned to this inspector in the system
      if (_activeProgram == null) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF200B1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppTheme.DangerColor, width: 1.5),
            ),
            title: const Row(
              children: [
                Icon(Icons.gpp_bad, color: AppTheme.DangerColor, size: 26),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'رفض البصمة — خارج المقرات الرسمية',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
            content: Text(
              '📍 أنت الآن خارج النطاق الجغرافي المعتمد للمقرات الرسمية (${nearestHQ.nameAr} يبعد عنك ${distance.round()}م).\n\n⛔ يُمنع قانوناً تسجيل الحضور الصباحي من خارج المقر أو من المنزل إلا بوجود أمر بمهمة رقابية خارجية مسطرة ومسندة لك مسبقاً في النظام من طرف الإدارة.\n\nيرجى التوجه إلى المقر الرسمي للبصمة، أو مراجعة رئيس المصلحة لتأشير أمر المهمة.',
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.white70, height: 1.5),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.DangerColor),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حسناً، مفهوم', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        return;
      }

      // If the inspector has a legitimate authorized mission program in the system
      final String programTitle = (_activeProgram?['title'] ?? 'مهمة رقابية ميدانية معتمدة').toString();
      final fieldChoice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final reasonCtrl = TextEditingController(text: programTitle);
          return AlertDialog(
            backgroundColor: AppTheme.CardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.assignment_turned_in, color: AppTheme.AccentColor, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'حضور بموجب أمر مهمة خارجية',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.AccentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.AccentColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '📍 برنامج المهمة الميدانية المسجل لك اليوم:\n$programTitle\n(${nearestHQ.nameAr} على بعد ${distance.round()}م)',
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Color(0xFFFCD34D), height: 1.4),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'تفاصيل نقطة الانطلاق الميدانية:',
                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'أدخل تفاصيل الانطلاق الميداني...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white70)),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('تأكيد الحضور الميداني', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.AccentColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      );

      if (fieldChoice == null) return;
      if (!mounted) return;
      missionReason = fieldChoice.isNotEmpty ? fieldChoice : programTitle;
      locationName = '$missionReason ($locationName)';
      setState(() => _isLoading = true);
    }

    if (!mounted) return;
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    final int empId = user?.employeeId ?? user?.id ?? 1;
    final nowStr = DateTime.now().toString().substring(11, 16);

    final devId = await AuthService.getOrCreateDeviceId();
    final payload = {
      'employeeId': empId,
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'location': locationName,
      'notes': missionReason,
      'deviceId': devId,
      'offlineTimestamp': DateTime.now().toIso8601String(),
    };

    bool isOfflineMode = false;

    try {
      final api = auth.api;
      await api.checkIn(
        empId,
        latitude: pos.latitude,
        longitude: pos.longitude,
        location: locationName,
        notes: missionReason,
        deviceId: devId,
      );
    } catch (e) {
      final errMsg = e.toString().replaceAll('Exception:', '').trim();
      // If it's a security rule rejection from the server (geofence, time window, device mismatch)
      if (errMsg.contains('النطاق الجغرافي') ||
          errMsg.contains('نافذة تسجيل الحضور') ||
          errMsg.contains('غير مطابق للجهاز') ||
          errMsg.contains('تنبيه أمني') ||
          errMsg.contains('خارج الأوقات') ||
          errMsg.contains('أقرب مقر')) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF200B1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppTheme.DangerColor, width: 1.5),
            ),
            title: const Row(
              children: [
                Icon(Icons.gpp_bad, color: AppTheme.DangerColor, size: 26),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'رفض البصمة — ضوابط أمنية',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
            content: Text(
              errMsg,
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.white70, height: 1.5),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.DangerColor),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حسناً، مفهوم', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        return;
      }

      isOfflineMode = true;
      await OfflineSyncService.queueCheckIn(payload);
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final pending = await OfflineSyncService.getPendingCount();

    if (mounted) {
      setState(() {
        _isCheckedIn = true;
        _checkInTime = nowStr;
        _checkInPhoto = null;
        _checkInLat = pos.latitude;
        _checkInLng = pos.longitude;
        _isLoading = false;
        _pendingSyncCount = pending;
      });

      final message = isOfflineMode
          ? (loc.isArabic
              ? '📡 تم حفظ الحضور محلياً — ستتم المزامنة تلقائياً'
              : '📡 Présence enregistrée hors ligne — synchro auto')
          : (isAtHQ
              ? (loc.isArabic
                  ? '✅ تم تسجيل الحضور رسميّاً: $locationName'
                  : '✅ Présence enregistrée: $locationName')
              : (loc.isArabic
                  ? '📍 تم تسجيل الحضور الميداني المباشر بنجاح'
                  : '📍 Présence mission terrain enregistrée'));

      messenger.showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontFamily: 'Tajawal')),
          backgroundColor: isOfflineMode
              ? const Color(0xFFD97706)
              : (isAtHQ ? AppTheme.SuccessColor : AppTheme.AccentColor),
          duration: const Duration(seconds: 4),
        ),
      );

      _showAttendanceProof(isOffline: isOfflineMode);
    }
  }

  void _handleSmartCheckOut() {
    int elapsedMinutes = 999;
    if (_checkInTime != null && _checkInTime!.isNotEmpty) {
      try {
        final parts = _checkInTime!.split(':');
        if (parts.length >= 2) {
          final now = DateTime.now();
          final checkInDt = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
          elapsedMinutes = now.difference(checkInDt).inMinutes;
        }
      } catch (_) {}
    }

    final now = DateTime.now();
    final bool isBefore1600 = now.hour < 16;
    final bool isVeryShortShift = elapsedMinutes < 30;
    final bool isHalfShiftWithoutVisits = elapsedMinutes < 240 && _visitCount == 0;

    if (isVeryShortShift) {
      _showEarlyCheckOutDialog(
        customNotice: '⛔ تنبيه أمني صارم: مضت $elapsedMinutes دقيقة فقط على تسجيل الحضور الصباحي!\nيُمنع الانصراف الفوري بعد دقائق معدودة من الدخول إلا في الحالات الاستعجالية القاهرة وفقاً للأمر 06-03.',
      );
    } else if (isBefore1600) {
      final hoursLeft = 15 - now.hour;
      final minutesLeft = 60 - now.minute;
      final remainingStr = hoursLeft > 0 ? '$hoursLeft ساعة و $minutesLeft دقيقة' : '$minutesLeft دقيقة';
      _showEarlyCheckOutDialog(
        customNotice: '⚠️ تنبيه إداري وقانوني: الدوام الرسمي سارٍ (08:00 - 16:30).\nنافذة الانصراف القانوني تفتح ابتداءً من الساعة 16:00 (المتبقي: $remainingStr).\nأي خروج حالياً يُعد مغادرة استعجالية غير عادية تستوجب تعهداً قانونياً وإيداع المبرر الإداري بمكتب المستخدمين خلال 48 ساعة.',
      );
    } else if (isHalfShiftWithoutVisits) {
      _showEarlyCheckOutDialog(
        customNotice: '⚠️ تنبيه إداري: لم يتم تسجيل أي زيارات أو معاينات ميدانية اليوم. يتطلب الانصراف توثيق المبرر الإداري أو المهمة المكلف بها للمصادقة عليه.',
      );
    } else {
      _showNormalCheckOutConfirmDialog();
    }
  }

  void _showNormalCheckOutConfirmDialog() {
    final loc = AppLocalizations.of(context);
    String checkoutLocationType = 'المقر الرسمي للمديرية/المفتشية';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.CardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.exit_to_app, color: AppTheme.PrimaryGold, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.isArabic ? 'تأكيد تسجيل الانصراف ونهاية الدوام الرسمي' : 'Confirmation de fin de service',
                  style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.AccentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.AccentColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: AppTheme.AccentColor, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.isArabic ? 'إحصاء النشاط الميداني لليوم:' : 'Bilan d\'activité du jour :',
                            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFCD34D)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            loc.isArabic
                                ? 'تم إنجاز وتوثيق $_visitCount معاينة وزيارة رقابية في الميدان.'
                                : '$_visitCount visites de contrôle effectuées et enregistrées.',
                            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'نقطة الانصراف ونهاية المهام:',
                style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: checkoutLocationType,
                isExpanded: true,
                dropdownColor: AppTheme.CardColor,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: 'المقر الرسمي للمديرية/المفتشية', child: Text('🏢 الرجوع للمقر الرسمي وتسجيل الانصراف', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                  DropdownMenuItem(value: 'انصراف ميداني مباشر من آخر نقطة تفتيش', child: Text('📍 انصراف ميداني مباشر من آخر نقطة تفتيش', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => checkoutLocationType = val);
                },
              ),
              const SizedBox(height: 12),
              Text(
                loc.isArabic
                    ? 'هل أنت متأكد من رغبتك في تسجيل الانصراف وإنهاء الدوام لليوم؟'
                    : 'Êtes-vous sûr de vouloir enregistrer votre départ pour aujourd\'hui ?',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                loc.isArabic
                    ? '🔒 حماية الخصوصية: سيتم إيقاف التتبع الجغرافي وتوثيق البصمة الجغرافية الرسمية لموقع الانصراف.\n⚠️ هذا الإجراء نهائي لليوم ولا يمكنك التراجع عنه ذاتياً، وفي حال الضغط خطأ يجب الاتصال بالإدارة لإلغائه إدارياً.'
                    : '🔒 Confidentialité : Le suivi GPS sera immédiatement désactivé après le pointage de sortie.',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white60, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.isArabic ? 'تراجع / إلغاء (ضغطت خطأ)' : 'Annuler', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white70)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _executeCheckOut(notes: checkoutLocationType);
              },
              icon: const Icon(Icons.check, size: 16),
              label: Text(loc.isArabic ? 'نعم، تأكيد الانصراف' : 'Confirmer le départ', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.PrimaryGold,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelCheckOut() async {
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    final user = context.read<AuthService>().currentUser;
    final int empId = user?.employeeId ?? user?.id ?? 1;

    try {
      final api = context.read<AuthService>().api;
      await api.cancelCheckOut(empId);
      if (mounted) {
        setState(() {
          _isCheckedOut = false;
          _isCheckedIn = true;
          _checkOutTime = null;
          _isLoading = false;
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('✅ تم استئناف الدوام وإعادة تفعيل بطاقة الحضور بنجاح', style: TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.SuccessColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('⚠️ خطأ: $e', style: const TextStyle(fontFamily: 'Tajawal')),
            backgroundColor: AppTheme.WarningColor,
          ),
        );
      }
    }
  }

  void _showEarlyCheckOutDialog({String? customNotice}) {
    final reasonCtrl = TextEditingController();
    String selectedReason = 'حالة صحية طارئة / وعكة مفاجئة (تستوجب شهادة طبية)';
    bool isPledged = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final int textLen = reasonCtrl.text.trim().length;
          final bool isTextValid = textLen >= 10;
          final bool canSubmit = isPledged && isTextValid;

          return AlertDialog(
            backgroundColor: AppTheme.CardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppTheme.WarningColor, width: 1.2),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.WarningColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.gavel_rounded, color: AppTheme.WarningColor, size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تصريح بمغادرة استعجالية اضطرارية',
                        style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                      ),
                      Text(
                        'الأمر 06-03 (قانون الوظيفة العمومية)',
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFFCD34D)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.WarningColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.WarningColor.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customNotice ??
                              '⚠️ ينتهي الدوام الرسمي في الساعة 16:30 ونافذة الانصراف تبدأ من 16:00. أي خروج قبل ذلك يخضع للرقابة الإدارية الصارمة.',
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Color(0xFFFCD34D), height: 1.4, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '📌 المادتان 40 و41 من الأمر 06-03 وقانون المحاسبة العمومية 90-21:\nالتصريح بالخروج الاضطراري ليس إعفاءً تلقائياً؛ بل يُقيد كوضعية معلقة بانتظار إيداع المبرر الرسمي أو الشهادة الطبية بمكتب المستخدمين خلال مهلة أقصاها 48 ساعة، وإلا تم إدراج الغياب غير المبرر والاقتطاع المباشر من الراتب وإحالة الملف للمسؤول المباشر.',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'نوع المبرر الإداري / الاستعجالي:',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    isExpanded: true,
                    dropdownColor: AppTheme.CardColor,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'حالة صحية طارئة / وعكة مفاجئة (تستوجب شهادة طبية)',
                        child: Text('حالة صحية طارئة / وعكة مفاجئة (تستوجب شهادة طبية)', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: 'مهمة رسمية خارجية بتكليف مسبق من الإدارة',
                        child: Text('مهمة رسمية خارجية بتكليف مسبق من الإدارة', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: 'ظرف عائلي قاهر / طارئ استثنائي',
                        child: Text('ظرف عائلي قاهر / طارئ استثنائي', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: 'إذن خروج رسمي كتابي مرخص به من رئيس المصلحة',
                        child: Text('إذن خروج رسمي كتابي مرخص به من رئيس المصلحة', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: 'مرافقة لجنة ولائية / جهوية مشتركة',
                        child: Text('مرافقة لجنة ولائية / جهوية مشتركة', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedReason = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    maxLines: 2,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'تفاصيل وظروف المغادرة الاضطرارية (إلزامي - 10 أحرف على الأقل)*',
                      labelStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white70),
                      helperText: !isTextValid
                          ? 'المتبقي: ${10 - textLen} حرف لاكتمال النصاب القانوني'
                          : '✓ النصاب مستوفٍ ($textLen حرف)',
                      helperStyle: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        color: isTextValid ? AppTheme.SuccessColor : const Color(0xFFFCD34D),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isTextValid ? AppTheme.SuccessColor : Colors.white24,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.PrimaryGold, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      setDialogState(() => isPledged = !isPledged);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isPledged ? AppTheme.PrimaryGold.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isPledged ? AppTheme.PrimaryGold : Colors.white24,
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: isPledged,
                            activeColor: AppTheme.PrimaryGold,
                            checkColor: Colors.black,
                            onChanged: (val) {
                              setDialogState(() => isPledged = val ?? false);
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'أصرح بشرفي بصحة البيانات أعلاه وأتعهد بتقديم المبرر الإداري أو الشهادة الطبية الرسمية لمكتب المستخدمين خلال 48 ساعة، وأتحمل كامل المسؤولية التأديبية والمالية وفقاً للأمر 06-03 في حال ثبوت عدم صحة الظرف.',
                              style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('تراجع واستمرار الدوام', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white70)),
              ),
              ElevatedButton.icon(
                onPressed: canSubmit
                    ? () {
                        final noteExtra = reasonCtrl.text.trim();
                        final fullReason = '$selectedReason — $noteExtra [تعهد قانوني مسجل]';
                        Navigator.pop(ctx);
                        _executeCheckOut(notes: fullReason, earlyReason: fullReason);
                      }
                    : null,
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('إيداع التصريح الاستعجالي', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.WarningColor,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white12,
                  disabledForegroundColor: Colors.white38,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _executeCheckOut({String? notes, String? earlyReason}) async {
    setState(() => _isLoading = true);
    Position? pos = await _getPosition();
    pos ??= Position(
      latitude: AppConstants.hqLatitude,
      longitude: AppConstants.hqLongitude,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );

    if (!mounted) return;

    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    final int empId = user?.employeeId ?? user?.id ?? 1;
    final isAtHQ = AppConstants.isWithinHQ(pos.latitude, pos.longitude);

    final payload = {
      'employeeId': empId,
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'location': isAtHQ ? 'HQ' : 'Field',
      'notes': notes,
      'earlyReason': earlyReason,
      'visitsCount': _visitCount,
    };

    bool isOfflineMode = false;

    try {
      final api = auth.api;
      await api.checkOut(
        empId,
        latitude: pos.latitude,
        longitude: pos.longitude,
        location: isAtHQ ? 'HQ' : 'Field',
        notes: notes,
        earlyReason: earlyReason,
        visitsCount: _visitCount,
      );
    } catch (e) {
      final errMsg = e.toString().replaceAll('Exception:', '').trim();
      if (errMsg.contains('تنبيه أمني') ||
          errMsg.contains('تنبيه إداري') ||
          errMsg.contains('الانصراف الفوري') ||
          errMsg.contains('يُمنع الانصراف') ||
          errMsg.contains('تبرير رسمي') ||
          errMsg.contains('نصف الدوام') ||
          errMsg.contains('دقيقة فقط')) {
        setState(() => _isLoading = false);
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF200B1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppTheme.WarningColor, width: 1.5),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppTheme.WarningColor, size: 26),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ضوابط الانصراف الإداري',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
            content: Text(
              errMsg,
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.white70, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء والتراجع', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white60)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.WarningColor, foregroundColor: Colors.black),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showEarlyCheckOutDialog(customNotice: errMsg);
                },
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('تقديم تبرير الخروج الاستعجالي', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        return;
      }

      isOfflineMode = true;
      await OfflineSyncService.queueCheckOut(payload);
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final pending = await OfflineSyncService.getPendingCount();

    if (mounted) {
      final nowStr = DateTime.now().toString().substring(11, 16);
      setState(() {
        _isCheckedIn = false;
        _isCheckedOut = true;
        _checkOutTime = nowStr;
        _isLoading = false;
        _pendingSyncCount = pending;
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isOfflineMode
                ? '📡 تم حفظ الانصراف محلياً — ستتم المزامنة تلقائياً'
                : '✅ تم تسجيل الانصراف بنجاح وإغلاق بطاقة الدوام لليوم',
            style: const TextStyle(fontFamily: 'Tajawal'),
          ),
          backgroundColor: isOfflineMode ? const Color(0xFFD97706) : AppTheme.SuccessColor,
          duration: const Duration(seconds: 4),
        ),
      );

      _showCheckOutProof(
        employeeName: user?.fullName ?? '',
        latitude: pos.latitude,
        longitude: pos.longitude,
        notes: notes,
        isOffline: isOfflineMode,
      );
    }
  }

  void _showAttendanceProof({bool isOffline = false}) {
    final user = context.read<AuthService>().currentUser;
    QRCodeScreen.show(
      context,
      record: {
        'type': 'checkin',
        'employeeName': user?.fullName ?? '',
        'date': DateTime.now().toString().split(' ')[0],
        'time': _checkInTime ?? DateTime.now().toString().substring(11, 19),
        'latitude': _checkInLat ?? AppConstants.hqLatitude,
        'longitude': _checkInLng ?? AppConstants.hqLongitude,
        'photo': _checkInPhoto,
        'id': DateTime.now().millisecondsSinceEpoch,
        'status': isOffline ? 'OFFLINE_PENDING_SYNC' : 'VERIFIED_ACTIVE',
      },
      title: isOffline ? 'إثبات الحضور (محلي)' : 'بطاقة الإثبات الرقمي (حضور معتمد)',
    );
  }

  void _showCheckOutProof({
    required String employeeName,
    required double latitude,
    required double longitude,
    String? notes,
    bool isOffline = false,
  }) {
    QRCodeScreen.show(
      context,
      record: {
        'type': 'checkout',
        'employeeName': employeeName,
        'date': DateTime.now().toString().split(' ')[0],
        'time': DateTime.now().toString().substring(11, 19),
        'latitude': latitude,
        'longitude': longitude,
        'notes': notes ?? 'انصراف نظامي',
        'id': DateTime.now().millisecondsSinceEpoch,
        'status': isOffline ? 'OFFLINE_PENDING_SYNC' : 'SYNCED',
      },
      title: isOffline ? 'إثبات الانصراف (وضع عدم الاتصال)' : 'إثبات الانصراف الرسمي',
    );
  }

  void _showVisitProofModal(Map<String, dynamic> visit) {
    final user = context.read<AuthService>().currentUser;
    final bool isOffline = visit['IsOffline'] == true;
    final String shop = (visit['TraderName'] ?? visit['ShopName'] ?? 'معاينة تجارية').toString();
    final String time = _formatTime(visit['CreatedAt'] ?? visit['VisitTime'] ?? visit['CheckInTime']);
    final dynamic lat = visit['Latitude'];
    final dynamic lng = visit['Longitude'];
    final String? photoBase64 = visit['Photo']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.CardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.AccentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.storefront, color: AppTheme.AccentColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'توقيت المعاينة: $time • ${isOffline ? "قيد المزامنة" : "مثبتة سحابياً"}',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 12,
                          color: AppTheme.TextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOffline ? const Color(0xFFD97706) : AppTheme.SuccessColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isOffline ? 'معلق' : 'معتمد',
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (photoBase64 != null && photoBase64.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(photoBase64),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (lat != null && lng != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.gps_fixed, color: AppTheme.AccentColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'الإحداثيات: ${lat.toString().substring(0, lat.toString().length > 7 ? 7 : lat.toString().length)}, ${lng.toString().substring(0, lng.toString().length > 7 ? 7 : lng.toString().length)}',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  QRCodeScreen.show(
                    context,
                    record: {
                      'type': 'visit',
                      'employeeName': user?.fullName ?? '',
                      'shopName': shop,
                      'time': time,
                      'latitude': lat,
                      'longitude': lng,
                      'id': visit['Id'] ?? DateTime.now().millisecondsSinceEpoch,
                      'status': isOffline ? 'OFFLINE_PENDING_SYNC' : 'VERIFIED_VISIT',
                    },
                    title: 'رمز الإثبات الرقمي للزيارة (QR Pass)',
                  );
                },
                icon: const Icon(Icons.qr_code_2),
                label: const Text('عرض رمز الاستجابة السريعة (QR Pass)', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.AccentColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _recordVisit() {
    final loc = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final violationNotesCtrl = TextEditingController();
    final seizureValueCtrl = TextEditingController();
    String shopType = 'محل تجزئة / مواد غذائية';
    bool violationFound = false;
    String violationType = 'عدم إشهار الأسعار والتعريفات';
    String legalAction = 'محضر متابعة قضائية';
    String? capturedPhoto;
    Position? currentPos;
    bool isLocating = true;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (isLocating && currentPos == null) {
            _getPosition().then((pos) {
              if (ctx.mounted) {
                setDialogState(() {
                  currentPos = pos ?? Position(
                    latitude: AppConstants.hqLatitude,
                    longitude: AppConstants.hqLongitude,
                    timestamp: DateTime.now(),
                    accuracy: 5.0,
                    altitude: 0.0,
                    altitudeAccuracy: 0.0,
                    heading: 0.0,
                    headingAccuracy: 0.0,
                    speed: 0.0,
                    speedAccuracy: 0.0,
                  );
                  isLocating = false;
                });
              }
            });
          }

          final double displayLat = currentPos?.latitude ?? AppConstants.hqLatitude;
          final double displayLng = currentPos?.longitude ?? AppConstants.hqLongitude;

          return AlertDialog(
            backgroundColor: AppTheme.CardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.PrimaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.storefront, color: AppTheme.PrimaryColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loc.recordVisit,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
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
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.SuccessColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.SuccessColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: AppTheme.SuccessColor, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isLocating
                                  ? 'جاري تحديد إحداثيات الموقع الميداني (GPS)...'
                                  : 'الموقع: ${displayLat.toStringAsFixed(5)}, ${displayLng.toStringAsFixed(5)} (دقيق)',
                              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.SuccessColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        labelText: 'اسم المحل التجاري / التاجر المعاين *',
                        prefixIcon: const Icon(Icons.business, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: shopType,
                      isExpanded: true,
                      dropdownColor: AppTheme.CardColor,
                      decoration: InputDecoration(
                        labelText: 'طبيعة النشاط التجاري',
                        prefixIcon: const Icon(Icons.category, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'محل تجزئة / مواد غذائية', child: Text('محل تجزئة / مواد غذائية', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                        DropdownMenuItem(value: 'مخبزة / صناعة حلويات', child: Text('مخبزة / صناعة حلويات', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                        DropdownMenuItem(value: 'قصابة / لحوم ودواجن', child: Text('قصابة / لحوم ودواجن', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                        DropdownMenuItem(value: 'سوق الجملة للخضر والفواكه', child: Text('سوق الجملة للخضر والفواكه', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                        DropdownMenuItem(value: 'وحدة إنتاج / تحويل صناعي', child: Text('وحدة إنتاج / تحويل صناعي', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                        DropdownMenuItem(value: 'خدمات وإطعام سريع', child: Text('خدمات وإطعام سريع', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                        DropdownMenuItem(value: 'استيراد وتصدير', child: Text('استيراد وتصدير', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                        DropdownMenuItem(value: 'أخرى', child: Text('أخرى', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => shopType = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    // Violation Switch Container
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: violationFound ? Colors.red.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: violationFound ? Colors.red.withValues(alpha: 0.4) : Colors.white12,
                        ),
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          violationFound ? '⚠️ تم رصد مخالفة / تحرير محضر' : '✅ الوضعية مطابقة (لا توجد مخالفة)',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: violationFound ? Colors.redAccent : Colors.white70,
                          ),
                        ),
                        value: violationFound,
                        activeThumbColor: Colors.redAccent,
                        onChanged: (val) => setDialogState(() => violationFound = val),
                      ),
                    ),
                    if (violationFound) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: violationType,
                        isExpanded: true,
                        dropdownColor: AppTheme.CardColor,
                        decoration: InputDecoration(
                          labelText: 'طبيعة المخالفة المرصودة',
                          prefixIcon: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'عدم إشهار الأسعار والتعريفات', child: Text('عدم إشهار الأسعار والتعريفات', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                          DropdownMenuItem(value: 'عدم الفوترة / معاملات بدون فواتير', child: Text('عدم الفوترة / معاملات بدون فواتير', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                          DropdownMenuItem(value: 'عرض مواد منتهية الصلاحية / غير صالحة', child: Text('عرض مواد منتهية الصلاحية / غير صالحة', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                          DropdownMenuItem(value: 'انعدام النظافة وشروط الحفظ الصحي', child: Text('انعدام النظافة وشروط الحفظ الصحي', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                          DropdownMenuItem(value: 'ممارسة نشاط تجاري دون القيد في السجل', child: Text('ممارسة نشاط تجاري دون القيد في السجل', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                          DropdownMenuItem(value: 'عدم مطابقة المنتوج للمواصفات القانونية', child: Text('عدم مطابقة المنتوج للمواصفات القانونية', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                          DropdownMenuItem(value: 'المضاربة غير المشروعة وإخفاء السلع', child: Text('المضاربة غير المشروعة وإخفاء السلع', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                          DropdownMenuItem(value: 'أخرى', child: Text('أخرى', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => violationType = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: legalAction,
                        isExpanded: true,
                        dropdownColor: AppTheme.CardColor,
                        decoration: InputDecoration(
                          labelText: 'الإجراء القانوني المتخذ',
                          prefixIcon: const Icon(Icons.gavel, color: AppTheme.PrimaryColor, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'محضر متابعة قضائية', child: Text('محضر متابعة قضائية', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                          DropdownMenuItem(value: 'محضر حجز سلع وبضائع', child: Text('محضر حجز سلع وبضائع', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                          DropdownMenuItem(value: 'محضر إتلاف فوري للمنتوجات', child: Text('محضر إتلاف فوري للمنتوجات', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                          DropdownMenuItem(value: 'اقتراح غلق إداري للمحل', child: Text('اقتراح غلق إداري للمحل', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                          DropdownMenuItem(value: 'استدعاء رسمي لمقر المديرية/المفتشية', child: Text('استدعاء رسمي لمقر المديرية/المفتشية', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                          DropdownMenuItem(value: 'إعذار لتسوية الوضعية القانونية', child: Text('إعذار لتسوية الوضعية القانونية', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12))),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => legalAction = val);
                        },
                      ),
                      if (legalAction.contains('حجز') || legalAction.contains('إتلاف')) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: seizureValueCtrl,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          decoration: InputDecoration(
                            labelText: 'القيمة المالية التقديرية للمحجوزات (د.ج)',
                            prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                            suffixText: 'د.ج',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: violationNotesCtrl,
                        textDirection: TextDirection.rtl,
                        decoration: InputDecoration(
                          labelText: 'تفاصيل المخالفة والمواد المعنية',
                          prefixIcon: const Icon(Icons.description, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesCtrl,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        labelText: 'ملاحظات عامة حول الزيارة الميدانية',
                        prefixIcon: const Icon(Icons.notes, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Photo capture row
                    if (capturedPhoto != null && capturedPhoto!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          base64Decode(capturedPhoto!),
                          height: 130,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final photo = await _pickPhoto(fromGallery: false);
                              if (photo != null && ctx.mounted) {
                                setDialogState(() => capturedPhoto = photo);
                              }
                            },
                            icon: const Icon(Icons.camera_alt, size: 16),
                            label: Text(
                              capturedPhoto != null ? 'تغيير الصورة' : 'توثيق بالكاميرا',
                              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final photo = await _pickPhoto(fromGallery: true);
                              if (photo != null && ctx.mounted) {
                                setDialogState(() => capturedPhoto = photo);
                              }
                            },
                            icon: const Icon(Icons.photo_library, size: 16),
                            label: const Text(
                              'من المعرض',
                              style: TextStyle(fontFamily: 'Tajawal', fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text(loc.cancel, style: const TextStyle(fontFamily: 'Tajawal')),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  setDialogState(() => isSaving = true);
                  final auth = context.read<AuthService>();
                  final user = auth.currentUser;
                  final messenger = ScaffoldMessenger.of(context);
                  final int empId = user?.employeeId ?? user?.id ?? 1;
                  final shopNameVal = nameCtrl.text.trim().isEmpty ? 'محل تجاري - معاينة ميدانية' : nameCtrl.text.trim();

                  final double posLat = currentPos?.latitude ?? AppConstants.hqLatitude;
                  final double posLng = currentPos?.longitude ?? AppConstants.hqLongitude;
                  final double parsedSeizure = double.tryParse(seizureValueCtrl.text.trim()) ?? 0.0;
                  final String finalLegalAction = violationFound ? legalAction : 'مطابقة وتوعية';

                  final payload = {
                    'employeeId': empId,
                    'latitude': posLat,
                    'longitude': posLng,
                    'photo': capturedPhoto,
                    'shopName': shopNameVal,
                    'shopType': shopType,
                    'notes': notesCtrl.text.trim(),
                    'violationFound': violationFound,
                    'violationType': violationFound ? violationType : null,
                    'violationNotes': violationNotesCtrl.text.trim(),
                    'legalAction': finalLegalAction,
                    'seizureValue': parsedSeizure,
                    'visitTime': DateTime.now().toIso8601String(),
                  };

                  bool isOfflineMode = false;
                  try {
                    final api = auth.api;
                    await api.recordVisit(
                      employeeId: empId,
                      latitude: posLat,
                      longitude: posLng,
                      photo: capturedPhoto,
                      shopName: shopNameVal,
                      shopType: shopType,
                      notes: payload['notes'] as String,
                      violationFound: violationFound,
                      violationType: payload['violationType'] as String?,
                      violationNotes: payload['violationNotes'] as String?,
                      legalAction: finalLegalAction,
                      seizureValue: parsedSeizure,
                    );
                  } catch (e) {
                    isOfflineMode = true;
                    await OfflineSyncService.queueVisit(payload);
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (!mounted) return;

                  _loadStatus();

                  final Map<String, dynamic> visitRecord = {
                    'TraderName': shopNameVal,
                    'ShopName': shopNameVal,
                    'ActivityType': shopType,
                    'CreatedAt': DateTime.now().toIso8601String(),
                    'Latitude': posLat,
                    'Longitude': posLng,
                    'Photo': capturedPhoto,
                    'Notes': payload['notes'],
                    'ViolationFound': violationFound,
                    'ViolationType': violationType,
                    'LegalAction': finalLegalAction,
                    'SeizureValue': parsedSeizure,
                    'IsOffline': isOfflineMode,
                  };

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        isOfflineMode ? '📡 تم حفظ المعاينة محلياً بنجاح (وضع عدم الاتصال)' : '✅ تم توثيق المعاينة الميدانية بنجاح',
                        style: const TextStyle(fontFamily: 'Tajawal'),
                      ),
                      backgroundColor: isOfflineMode ? const Color(0xFFD97706) : AppTheme.SuccessColor,
                      action: SnackBarAction(
                        label: 'عرض الـ QR',
                        textColor: Colors.white,
                        onPressed: () => _showVisitProofModal(visitRecord),
                      ),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: violationFound ? Colors.orange.shade800 : AppTheme.SuccessColor,
                  foregroundColor: Colors.white,
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(loc.save, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final user = context.watch<AuthService>().currentUser;
    final isAr = context.watch<LanguageProvider>().isArabic;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.BackgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF260D2E), Color(0xFF16061D)],
              ),
              border: const Border(
                bottom: BorderSide(
                  color: Color(0x33D4AF37),
                  width: 0.8,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          titleSpacing: 8,
          title: LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = MediaQuery.of(context).size.width < 400;
              return Row(
                children: [
                  GoldenEmblemCoin(
                    size: isSmall ? 28 : 34,
                    showOuterGlow: false,
                    enableFloating: false,
                    animateGleam: false,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                isAr ? 'المفتشية الميدانية' : 'Contrôle Terrain',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: isSmall ? 13.0 : 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 4),
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
                                isAr ? 'مفتش' : 'Inspecteur',
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD4AF37),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          (user?.fullName != null && user!.fullName!.isNotEmpty)
                              ? '${user.fullName}'
                              : (isAr ? 'مديرية التجارة وضبط السوق — سطيف' : 'Direction du Commerce — Sétif'),
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: isSmall ? 9.5 : 10.5,
                            color: const Color(0xFFD4AF37),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            Builder(
              builder: (context) {
                final screenWidth = MediaQuery.of(context).size.width;
                final isCompact = screenWidth < 500;

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_pendingSyncCount > 0)
                        InkWell(
                          onTap: _isSyncing ? null : () => _syncPendingItems(silent: false),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _isSyncing
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.sync, color: Colors.white, size: 13),
                                const SizedBox(width: 3),
                                Text(
                                  '$_pendingSyncCount',
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.cloud_done, color: Color(0xFF10B981), size: 17),
                          tooltip: 'جميع البيانات متزامنة',
                          onPressed: () => _syncPendingItems(silent: false),
                        ),
                      Container(width: 1, height: 14, color: Colors.white12),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            icon: const Icon(Icons.mark_email_unread, color: Color(0xFFD4AF37), size: 17),
                            tooltip: 'الاستفسارات الإدارية',
                            onPressed: () => InspectorInquiriesSheet.show(context, user?.employeeId ?? user?.id ?? 1),
                          ),
                          if (_pendingInquiryCount > 0)
                            Positioned(
                              top: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                                child: Text(
                                  '$_pendingInquiryCount',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Container(width: 1, height: 14, color: Colors.white12),
                      InkWell(
                        onTap: () => context.read<LanguageProvider>().toggleLanguage(),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.language, color: Color(0xFFD4AF37), size: 12),
                              const SizedBox(width: 3),
                              Text(
                                isAr ? 'FR' : 'عربي',
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD4AF37),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isCompact) ...[
                        Container(width: 1, height: 14, color: Colors.white12),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Color(0xFFD4AF37), size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 32),
                          color: const Color(0xFF1E293B),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0x33D4AF37)),
                          ),
                          onSelected: (val) {
                            if (val == 'password') {
                              ChangePasswordDialog.show(context);
                            } else if (val == 'logout') {
                              context.read<AuthService>().logout();
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                              );
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'password',
                              child: Row(
                                children: [
                                  const Icon(Icons.lock_reset, color: Color(0xFFD4AF37), size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    isAr ? 'تغيير كلمة المرور' : 'Changer mot de passe',
                                    style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const PopupMenuDivider(height: 1),
                            PopupMenuItem(
                              value: 'logout',
                              child: Row(
                                children: [
                                  const Icon(Icons.logout, color: Color(0xFFEF4444), size: 18),
                                  const SizedBox(width: 10),
                                  Text(
                                    isAr ? 'تسجيل الخروج' : 'Déconnexion',
                                    style: const TextStyle(fontFamily: 'Tajawal', color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Container(width: 1, height: 16, color: Colors.white12),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.lock_reset, color: Color(0xFFD4AF37), size: 18),
                          tooltip: isAr ? 'تغيير كلمة المرور' : 'Changer mot de passe',
                          onPressed: () => ChangePasswordDialog.show(context),
                        ),
                        Container(width: 1, height: 16, color: Colors.white12),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.logout, color: Color(0xFFEF4444), size: 18),
                          tooltip: loc.isArabic ? 'تسجيل الخروج' : 'Déconnexion',
                          onPressed: () {
                            context.read<AuthService>().logout();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pending Inquiries Alert Banner
              if (_pendingInquiryCount > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5B1124), Color(0xFF2E091B)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFD4AF37), width: 1.3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mail, color: Color(0xFFD4AF37), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'لديك $_pendingInquiryCount استفسار إداري كتابي بانتظار ردك',
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'مهلة 48 ساعة لتقديم تبريراتكم للمدير الولائي',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11,
                                color: Color(0xFFFDE68A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => InspectorInquiriesSheet.show(context, user?.employeeId ?? user?.id ?? 1),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('الرد الآن', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                ),

              // Offline banner
              if (_pendingSyncCount > 0)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'يوجد $_pendingSyncCount عمليات مسجلة محلياً في انتظار المزامنة مع السيرفر.',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            color: Color(0xFFFCD34D),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _isSyncing ? null : () => _syncPendingItems(silent: false),
                        child: Text(
                          _isSyncing ? 'جاري...' : 'مزامنة الآن',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD4AF37),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Profile Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF881337), Color(0xFF4C0519)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.AccentColor.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF881337).withValues(alpha: 0.3),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFD4AF37), Color(0xFF92400E)],
                        ),
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? '',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.serviceName ?? loc.roleInspector,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isCheckedOut
                            ? const Color(0xFF6366F1)
                            : (_isCheckedIn ? AppTheme.SuccessColor : AppTheme.WarningColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _isCheckedOut
                            ? 'تم الانصراف'
                            : (_isCheckedIn ? loc.checkedIn : loc.notCheckedIn),
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Active Assignment / Mission Order Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assignment, color: Color(0xFF38BDF8), size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'أمر المهمة والقطاع التفتيشي لليوم',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF38BDF8),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ساري المفعول',
                            style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _activeProgram != null
                          ? (_activeProgram!['Title']?.toString() ?? 'برنامج مراقبة الأسعار وإشهارها')
                          : 'مراقبة الممارسات التجارية والمطابقة وقمع الغش',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _activeProgram != null
                          ? 'القطاع المستهدف: ${_activeProgram!['TargetArea'] ?? "بلدية سطيف والعلمة"} • ${_activeProgram!['FocusPoints'] ?? "تجار الجملة والتجزئة"}'
                          : 'القطاع: وسط مدينة سطيف والأسواق الجوارية • الهدف: التحقق من إشهار الأسعار والفوترة ومطابقة المواد الحساسة',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Digital Proofs & QR Passes Action Banner
              if (_isCheckedIn)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF818CF8).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.qr_code_2, color: Color(0xFFA5B4FC), size: 28),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'محفظة الإثباتات الرقمية (QR Pass)',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'عرض بطاقة الحضور والزيارات المثبتة للمسؤولين',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _showAttendanceProof(isOffline: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF818CF8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text(
                          'عرض البطاقة',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

              // Attendance Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.CardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.BorderColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: AppTheme.AccentColor,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          loc.attendance,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_isCheckedIn) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.SuccessColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.SuccessColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: AppTheme.SuccessColor,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              loc.checkedIn,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.bold,
                                color: AppTheme.SuccessColor,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$_checkInTime',
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.bold,
                                color: AppTheme.SuccessColor,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Builder(
                        builder: (context) {
                          final now = DateTime.now();
                          final isNormalCheckoutWindow = now.hour >= 16;
                          final hoursLeft = 15 - now.hour;
                          final minutesLeft = 60 - now.minute;
                          final remainingStr = hoursLeft > 0 ? '$hoursLeft س و $minutesLeft د' : '$minutesLeft د';

                          if (isNormalCheckoutWindow) {
                            return SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _handleSmartCheckOut,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.black,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.exit_to_app, color: Colors.black),
                                label: const Text(
                                  'تسجيل الانصراف الرسمي ونهاية الدوام',
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.PrimaryGold,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            );
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2A1535),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.PrimaryGold.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.PrimaryGold.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.access_time_filled,
                                        color: AppTheme.PrimaryGold,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'الدوام الرسمي سارٍ (08:00 - 16:30)',
                                            style: TextStyle(
                                              fontFamily: 'Tajawal',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'نافذة الانصراف القانوني تُفتح في 16:00 (المتبقي: $remainingStr)',
                                            style: const TextStyle(
                                              fontFamily: 'Tajawal',
                                              fontSize: 11,
                                              color: Color(0xFFFCD34D),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _handleSmartCheckOut,
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            color: AppTheme.WarningColor,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.emergency_outlined, color: AppTheme.WarningColor, size: 20),
                                  label: const Text(
                                    'تصريح بمغادرة استعجالية اضطرارية',
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppTheme.WarningColor,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: AppTheme.WarningColor.withValues(alpha: 0.8),
                                      width: 1.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: AppTheme.WarningColor.withValues(alpha: 0.06),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ] else if (_isCheckedOut) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.PrimaryGold.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.PrimaryGold.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.verified,
                                  color: AppTheme.PrimaryGold,
                                  size: 24,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'تم تسجيل الانصراف وإغلاق بطاقة الدوام بنجاح',
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.PrimaryGold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Text('وقت الحضور', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white60)),
                                    const SizedBox(height: 2),
                                    Text('$_checkInTime', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.SuccessColor)),
                                  ],
                                ),
                                Container(width: 1, height: 28, color: Colors.white24),
                                Column(
                                  children: [
                                    const Text('وقت الانصراف', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white60)),
                                    const SizedBox(height: 2),
                                    Text('$_checkOutTime', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFFCD34D))),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              '🔒 تم إيقاف التتبع الجغرافي لانتهاء الدوام الرسمي',
                              style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white60),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading ? null : _cancelCheckOut,
                                icon: const Icon(Icons.replay, size: 16, color: AppTheme.PrimaryGold),
                                label: const Text(
                                  'استئناف الدوام (إلغاء الانصراف بالخطأ)',
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.PrimaryGold,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppTheme.PrimaryGold, width: 1.2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.fingerprint,
                              size: 56,
                              color: AppTheme.TextSecondary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              loc.notCheckedIn,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                color: AppTheme.TextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _checkIn,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.fingerprint),
                          label: Text(
                            _isLoading ? loc.checkInProgress : loc.checkInWithCamera,
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.AccentColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => JustificationSubmissionModal.show(context),
                          icon: const Icon(Icons.file_present_outlined, color: Color(0xFFD4AF37), size: 18),
                          label: const Text(
                            'تقديم مبرر غياب / عطلة قانونية (شهادة طبية، وفاة، زواج...)',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              color: Color(0xFFD4AF37),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final user = context.read<AuthService>().currentUser;
                            final empId = user?.employeeId ?? 1;
                            InspectorInquiriesSheet.show(context, empId);
                          },
                          icon: const Icon(Icons.mail_outline, color: Color(0xFFD4AF37), size: 18),
                          label: const Text(
                            'الاستفسارات الإدارية الواردة والردود (Demandes d\'Explications)',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              color: Color(0xFFD4AF37),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Visit Action
              if (_isCheckedIn) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _recordVisit,
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text(
                      'توثيق معاينة ميدانية جديدة بالصورة والـ GPS',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.PrimaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Today's visits
                Row(
                  children: [
                    const Icon(Icons.history, color: AppTheme.AccentColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${loc.visitsToday} ($_visitCount)',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_todayVisits.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppTheme.CardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.BorderColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        loc.noVisits,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          color: AppTheme.TextSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  ..._todayVisits.map(
                    (v) {
                      final bool isItemOffline = v['IsOffline'] == true;
                      return InkWell(
                        onTap: () => _showVisitProofModal(v),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.CardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isItemOffline
                                  ? const Color(0xFFD97706).withValues(alpha: 0.5)
                                  : AppTheme.BorderColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: (isItemOffline
                                          ? const Color(0xFFD97706)
                                          : AppTheme.SuccessColor)
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.store,
                                  color: isItemOffline
                                      ? const Color(0xFFD97706)
                                      : AppTheme.SuccessColor,
                                  size: 18,
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
                                            '${v['TraderName'] ?? v['ShopName'] ?? (loc.isArabic ? 'معاينة تجارية' : 'Visite')}',
                                            style: const TextStyle(
                                              fontFamily: 'Tajawal',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        if (isItemOffline) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFD97706)
                                                  .withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'معلق للمزامنة',
                                              style: TextStyle(
                                                fontFamily: 'Tajawal',
                                                fontSize: 9,
                                                color: Color(0xFFFCD34D),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${v['ActivityType'] ?? v['ShopType'] ?? ''} • ${_formatTime(v['CreatedAt'] ?? v['VisitTime'] ?? v['CheckInTime'])}',
                                      style: const TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 11,
                                        color: AppTheme.TextSecondary,
                                      ),
                                    ),
                                    if (v['ViolationFound'] == true || v['ViolationFound'] == 1) ...[
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              '⚠️ ${v['ViolationType'] ?? 'مخالفة مرصودة'}',
                                              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          if (v['LegalAction'] != null && v['LegalAction'].toString().isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '⚖️ ${v['LegalAction']}',
                                                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Color(0xFFD4AF37)),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ] else ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.SuccessColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          '✅ مطابقة وتوعية',
                                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppTheme.SuccessColor),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(Icons.qr_code, color: AppTheme.AccentColor, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),
                const AppFooter(),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
