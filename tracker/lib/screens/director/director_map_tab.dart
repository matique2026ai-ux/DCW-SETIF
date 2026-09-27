import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:drh_setif_tracker/services/auth_service.dart';
import 'package:drh_setif_tracker/utils/theme.dart';
import 'package:drh_setif_tracker/utils/app_localizations.dart';
import 'package:drh_setif_tracker/utils/constants.dart';
import 'package:drh_setif_tracker/screens/common/qr_code_screen.dart';

class DirectorMapTab extends StatefulWidget {
  const DirectorMapTab({super.key});

  @override
  State<DirectorMapTab> createState() => _DirectorMapTabState();
}

class _DirectorMapTabState extends State<DirectorMapTab> {
  List<Map<String, dynamic>> _mapData = [];
  bool _isLoading = true;
  bool _isLocating = false;
  LatLng? _directorLiveLocation;
  Timer? _liveRefreshTimer;
  final MapController _mapController = MapController();
  String _selectedMapStyle = 'satellite'; // 'satellite', 'osm'

  static const LatLng _setifCenter = LatLng(AppConstants.hqLatitude, AppConstants.hqLongitude);

  @override
  void initState() {
    super.initState();
    _loadData();
    // Live Auto-Refresh every 12 seconds
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted) _loadData(silent: true);
    });
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    try {
      final api = context.read<AuthService>().api;
      final data = await api.getMapData();
      final cleanData = data.where((e) {
        final name = (e['name'] ?? '').toString();
        final service = (e['service'] ?? '').toString();
        return !name.contains('المدير الولائي') && !service.contains('المديرية الولائية');
      }).toList();

      if (mounted) {
        setState(() {
          _mapData = cleanData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  void _zoomIn() {
    try {
      final currentZoom = _mapController.camera.zoom;
      final target = (currentZoom + 1.2).clamp(3.0, 19.0);
      _mapController.move(_mapController.camera.center, target);
    } catch (_) {}
  }

  void _zoomOut() {
    try {
      final currentZoom = _mapController.camera.zoom;
      final target = (currentZoom - 1.2).clamp(3.0, 19.0);
      _mapController.move(_mapController.camera.center, target);
    } catch (_) {}
  }

  Future<void> _locateDirectorLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    final loc = AppLocalizations.of(context);

    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }

      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        _mapController.move(_setifCenter, 13.5);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text(
                loc.isArabic
                    ? '📍 تم التوجيه إلى مركز ولاية سطيف (صلاحية GPS غير مفعلة في المتصفح)'
                    : '📍 Redirection vers le centre de Sétif (GPS non autorisé)',
                style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppTheme.WarningColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      final livePoint = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _directorLiveLocation = livePoint);
        _mapController.move(livePoint, 16.0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              loc.isArabic
                  ? '🎯 تم تحديد موقعك المباشر بنجاح (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})'
                  : '🎯 Position actuelle localisée (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})',
              style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.SuccessColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _mapController.move(_setifCenter, 13.5);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text(
              loc.isArabic
                  ? '📍 تم التوجيه إلى مركز ولاية سطيف والمقر الرئيسي'
                  : '📍 Redirection vers le siège principal (Sétif)',
              style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.AccentColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  String _selectedInspectorateId = 'الكل';

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final inField = _mapData.where((e) {
      final bool checkedIn = e['hasCheckedIn'] == true;
      final bool notCheckedOut = e['isCheckedOut'] != true;
      final bool isFieldLoc = e['locationType'] == 'in_field';
      final int visits = ((e['visitsCount'] as num?)?.toInt() ?? 0);
      return checkedIn && notCheckedOut && (isFieldLoc || visits > 0);
    }).toList();

    final atHQ = _mapData.where((e) {
      final bool checkedIn = e['hasCheckedIn'] == true;
      final bool notCheckedOut = e['isCheckedOut'] != true;
      final bool isFieldLoc = e['locationType'] == 'in_field';
      final int visits = ((e['visitsCount'] as num?)?.toInt() ?? 0);
      return checkedIn && notCheckedOut && (!isFieldLoc && visits == 0);
    }).toList();
    final checkedOut = _mapData.where((e) => e['isCheckedOut'] == true).toList();
    final notRegistered = _mapData.where((e) => e['hasCheckedIn'] != true).toList();

    // Collect all visits markers
    final List<Marker> visitMarkers = [];
    for (final emp in _mapData) {
      final visits = (emp['visits'] as List?) ?? [];
      for (final v in visits) {
        if (v['latitude'] != null && v['longitude'] != null) {
          final double? vLat = (v['latitude'] is num) ? (v['latitude'] as num).toDouble() : double.tryParse(v['latitude']?.toString() ?? '');
          final double? vLng = (v['longitude'] is num) ? (v['longitude'] as num).toDouble() : double.tryParse(v['longitude']?.toString() ?? '');
          if (vLat == null || vLng == null) continue;
          final visitMap = Map<String, dynamic>.from(v as Map);
          final String empName = emp['name']?.toString() ?? 'مفتش ميداني';
          visitMarkers.add(
            Marker(
              point: LatLng(vLat, vLng),
              width: 36,
              height: 36,
              child: GestureDetector(
                onTap: () => _showVisitDetailsModal(visitMap, empName),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 6),
                    ],
                  ),
                  child: const Icon(Icons.storefront, color: Colors.white, size: 18),
                ),
              ),
            ),
          );
        }
      }
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(initialCenter: _setifCenter, initialZoom: 13),
          children: [
            if (_selectedMapStyle == 'satellite') ...[
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'DCW-SETIF-TRACKER',
                maxZoom: 19,
              ),
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'DCW-SETIF-TRACKER',
                maxZoom: 19,
              ),
            ] else ...[
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'DCW-SETIF-TRACKER',
                maxZoom: 19,
              ),
            ],

            // Geofence Circles for All Regional Inspectorates & Annexes in Setif Province
            CircleLayer(
              circles: AppConstants.allInspectorates.map((insp) {
                return CircleMarker(
                  point: LatLng(insp.latitude, insp.longitude),
                  radius: insp.radiusMeters,
                  useRadiusInMeter: true,
                  color: (insp.isMainDirectorate ? AppTheme.AccentColor : const Color(0xFF10B981)).withValues(alpha: 0.15),
                  borderColor: insp.isMainDirectorate ? AppTheme.AccentColor : const Color(0xFF10B981),
                  borderStrokeWidth: 1.5,
                );
              }).toList(),
            ),

            MarkerLayer(
              markers: [
                // Regional Inspectorates & Main HQ Markers
                ...AppConstants.allInspectorates.map((insp) {
                  return Marker(
                    point: LatLng(insp.latitude, insp.longitude),
                    width: insp.isMainDirectorate ? 44 : 38,
                    height: insp.isMainDirectorate ? 44 : 38,
                    child: Tooltip(
                      message: insp.nameAr,
                      child: GestureDetector(
                        onTap: () {
                          _showInspectorateHQModal(insp);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: insp.isMainDirectorate ? AppTheme.AccentColor : const Color(0xFF881337),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black54,
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            insp.isMainDirectorate ? Icons.account_balance : Icons.apartment,
                            color: Colors.white,
                            size: insp.isMainDirectorate ? 22 : 18,
                          ),
                        ),
                      ),
                    ),
                  );
                }),

                // Field Visit Markers (Stores inspected today)
                ...visitMarkers,

                // Live Director / User Current Location Marker
                if (_directorLiveLocation != null)
                  Marker(
                    point: _directorLiveLocation!,
                    width: 52,
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.AccentColor.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.AccentColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 8),
                            ],
                          ),
                          child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ),

                // Active In-Field Inspectors Markers (Excludes checked out agents to respect privacy)
                ..._mapData
                    .where(
                      (e) =>
                          e['latitude'] != null &&
                          e['hasCheckedIn'] == true &&
                          e['isCheckedOut'] != true,
                    )
                    .map((emp) {
                      final double lat = (emp['latitude'] is num)
                          ? (emp['latitude'] as num).toDouble()
                          : (double.tryParse(emp['latitude']?.toString() ?? '') ?? 0.0);
                      final double lng = (emp['longitude'] is num)
                          ? (emp['longitude'] as num).toDouble()
                          : (double.tryParse(emp['longitude']?.toString() ?? '') ?? 0.0);
                      final isOut = emp['isCheckedOut'] == true;
                      final int vCount = (emp['visitsCount'] as num?)?.toInt() ?? 0;

                      return Marker(
                        point: LatLng(lat, lng),
                        width: 48,
                        height: 48,
                        child: GestureDetector(
                          onTap: () => _showInspectorModal(emp),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isOut
                                      ? const Color(0xFF64748B)
                                      : AppTheme.SuccessColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isOut
                                              ? const Color(0xFF64748B)
                                              : AppTheme.SuccessColor)
                                          .withValues(alpha: 0.6),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              if (vCount > 0)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.AccentColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$vCount',
                                      style: const TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
              ],
            ),
          ],
        ),

        // Executive Top Control Bar (Responsive across Desktop, Tablet, and Mobile)
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 960;
              final isNarrow = constraints.maxWidth < 640;

              if (isWide) {
                // Desktop / Wide: Single Unified Executive Glass Bar
                return Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E1038), Color(0xFF1E0B26)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                        width: 1.2,
                      ),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        _searchAgentButton(isCompact: false),
                        const SizedBox(width: 8),
                        _hqSelectorDropdown(isCompact: false),
                        const Spacer(),
                        _statsCapsuleContent(
                          loc,
                          inFieldCount: inField.length,
                          atHQCount: atHQ.length,
                          visitsCount: visitMarkers.length,
                          notRegisteredCount: notRegistered.length,
                          checkedOutCount: checkedOut.length,
                        ),
                        const Spacer(),
                        _mapStyleSwitcher(isCompact: false),
                      ],
                    ),
                  ),
                );
              }

              // Tablet & Mobile: Two clean, compact tiers without clutter
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tier 1: Stats Capsule
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E1038), Color(0xFF1E0B26)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
                        ],
                      ),
                      child: _statsCapsuleContent(
                        loc,
                        inFieldCount: inField.length,
                        atHQCount: atHQ.length,
                        visitsCount: visitMarkers.length,
                        notRegisteredCount: notRegistered.length,
                        checkedOutCount: checkedOut.length,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Tier 2: Search + HQ Selector Dropdown + Map Type Switcher
                  Row(
                    children: [
                      _searchAgentButton(isCompact: isNarrow),
                      const SizedBox(width: 6),
                      Expanded(child: _hqSelectorDropdown(isCompact: isNarrow)),
                      const SizedBox(width: 6),
                      _mapStyleSwitcher(isCompact: isNarrow),
                    ],
                  ),
                ],
              );
            },
          ),
        ),

        // Map Control Buttons
        Positioned(
          bottom: 24,
          left: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionButton(
                Icons.add,
                _zoomIn,
                tooltip: loc.isArabic ? 'تكبير الخريطة (+)' : 'Zoomer (+)',
              ),
              const SizedBox(height: 10),
              _actionButton(
                Icons.remove,
                _zoomOut,
                tooltip: loc.isArabic ? 'تصغير الخريطة (-)' : 'Dézoomer (-)',
              ),
              const SizedBox(height: 10),
              _actionButton(
                Icons.my_location,
                _locateDirectorLocation,
                tooltip: loc.isArabic ? 'تحديد موقعي المباشر (GPS)' : 'Ma position actuelle (GPS)',
                isLoading: _isLocating,
                highlightColor: AppTheme.AccentColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _styleChip(String styleKey, String label) {
    final isSelected = _selectedMapStyle == styleKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedMapStyle = styleKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.AccentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppTheme.TextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    IconData icon,
    VoidCallback onPressed, {
    String? tooltip,
    bool isLoading = false,
    Color? highlightColor,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        elevation: 6,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          customBorder: const CircleBorder(),
          splashColor: AppTheme.AccentColor.withValues(alpha: 0.4),
          child: Ink(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1638),
              shape: BoxShape.circle,
              border: Border.all(
                color: highlightColor ?? const Color(0xFFD4AF37).withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Color(0xFFD4AF37),
                      ),
                    )
                  : Icon(
                      icon,
                      color: highlightColor ?? const Color(0xFFFFF6D6),
                      size: 22,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _legend(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11,
            color: AppTheme.TextSecondary,
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatAttendanceTime(dynamic rawTime) {
    if (rawTime == null || rawTime.toString().isEmpty) return '---';
    try {
      final dt = DateTime.parse(rawTime.toString()).toLocal();
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      final yyyy = dt.year.toString();
      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      return '$hh:$mm ($yyyy-$month-$day)';
    } catch (_) {
      return rawTime.toString().replaceAll('T', ' ').substring(0, 16);
    }
  }

  void _showInspectorModal(Map<String, dynamic> emp) {
    final loc = AppLocalizations.of(context);
    final String name = (emp['name'] ?? (loc.isArabic ? 'مفتش' : 'Agent')).toString();
    final String service = (emp['service'] ?? (loc.isArabic ? 'مديرية التجارة' : 'Direction du Commerce')).toString();
    final String checkInStr = _formatAttendanceTime(emp['checkInTime']);
    final bool isPresent = emp['hasCheckedIn'] == true;
    final bool isOut = emp['isCheckedOut'] == true;
    final List<dynamic> visits = (emp['visits'] as List<dynamic>?) ?? [];
    final String? checkInPhoto = emp['checkInPhoto']?.toString();

    // Precise administrative status:
    String statusText = loc.isArabic ? 'غائب (لم يسجل)' : 'Absent (Non pointé)';
    Color statusColor = AppTheme.DangerColor;
    if (isOut) {
      statusText = loc.isArabic ? 'انصرف' : 'Sorti';
      statusColor = const Color(0xFF64748B);
    } else if (isPresent) {
      final bool isInField = emp['locationType'] == 'in_field' || visits.isNotEmpty;
      if (isInField) {
        statusText = loc.isArabic
            ? (visits.isNotEmpty ? 'نشط في الميدان (${visits.length} معاينات)' : 'في مهمة تفتيشية ميدانية')
            : (visits.isNotEmpty ? 'En mission (${visits.length} visites)' : 'En mission terrain');
        statusColor = const Color(0xFF38BDF8);
      } else {
        statusText = loc.isArabic ? 'حاضر بالمقر (مسجل حضور)' : 'Présent au siège';
        statusColor = AppTheme.SuccessColor;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.CardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person, color: statusColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(service, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.TextSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (emp['activeProgram'] != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assignment, color: Color(0xFF38BDF8), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            loc.isArabic ? 'أمر المهمة الرقابية المعين:' : 'Ordre de mission assigné :',
                            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      emp['activeProgram']['title']?.toString() ?? '',
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    if (emp['activeProgram']['targetArea'] != null && emp['activeProgram']['targetArea'].toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '📍 الإقليم: ${emp['activeProgram']['targetArea']}',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(color: AppTheme.BorderColor),
            const SizedBox(height: 8),
            _infoRow(Icons.access_time, loc.isArabic ? 'توقيت الحضور' : 'Heure de pointage', checkInStr),
            if (emp['notes'] != null && emp['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.notes, loc.isArabic ? 'ملاحظة الانصراف/المبرر' : 'Note / Justification', emp['notes'].toString()),
            ],
            const SizedBox(height: 8),
            _infoRow(
              Icons.store,
              loc.isArabic ? 'المعاينات المنجزة اليوم' : 'Visites de contrôle aujourd\'hui',
              loc.isArabic ? '${visits.length} معاينات' : '${visits.length} visites',
            ),
            if (checkInPhoto != null && checkInPhoto.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(loc.isArabic ? 'صورة إثبات الحضور الميداني:' : 'Photo de présence terrain :', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  base64Decode(checkInPhoto),
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (visits.isNotEmpty) ...[
              Text(loc.isArabic ? 'سجل المحلات المعاينة اليوم:' : 'Commerces contrôlés aujourd\'hui :', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...visits.map((v) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront, color: Color(0xFF38BDF8), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${v['shopName']} • ${v['time'] != null ? v['time'].toString().substring(11, 16) : ""}',
                            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.qr_code, color: AppTheme.AccentColor, size: 18),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showVisitDetailsModal(Map<String, dynamic>.from(v as Map), name);
                          },
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  QRCodeScreen.show(
                    context,
                    record: {
                      'type': isPresent ? 'checkin' : 'employee_badge',
                      'employeeName': name,
                      'service': service,
                      'date': DateTime.now().toString().split(' ')[0],
                      'time': isPresent ? (emp['checkInTime'] ?? '') : '',
                      'checkInTime': isPresent ? (emp['checkInTime'] ?? 'حاضر (توقيت معتمد)') : 'لم يسجل الدخول اليوم',
                      'isPresent': isPresent,
                      'visitsCount': visits.length,
                      'status': isPresent ? 'VERIFIED_PRESENT' : 'NOT_CHECKED_IN_TODAY',
                      'location': isPresent ? (emp['locationName'] ?? 'المقر الرئيسي لمديرية التجارة سطيف') : 'غير متواجد بالمقر',
                    },
                    title: isPresent
                        ? (loc.isArabic ? 'إثبات الحضور الصباحي للعون (QR)' : 'Preuve de présence matinale (QR)')
                        : (loc.isArabic ? 'البطاقة المهنية الرقمية (غير مسجل حضور اليوم)' : 'Badge professionnel (Non pointé)'),
                  );
                },
                icon: Icon(isPresent ? Icons.verified : Icons.badge_outlined),
                label: Text(
                  isPresent
                      ? (loc.isArabic ? 'فحص إثبات الحضور الصباحي المعتمد' : 'Vérifier la présence matinale')
                      : (loc.isArabic ? 'عرض البطاقة المهنية الرقمية (غير حاضر)' : 'Voir le badge professionnel (Absent)'),
                  style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPresent ? AppTheme.AccentColor : const Color(0xFF4A1525),
                  foregroundColor: isPresent ? Colors.black : Colors.white,
                  side: isPresent ? null : const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                ),
              ),
            ),
            if (!isPresent) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showOrderInquiryForEmployee(emp);
                  },
                  icon: const Icon(Icons.gavel, color: Colors.orangeAccent, size: 18),
                  label: Text(
                    loc.isArabic ? 'أمر مكتب المستخدمين بتوجيه استفسار كتابي' : 'Ordonner une demande d\'explications',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.orangeAccent,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orangeAccent, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showOrderInquiryForEmployee(Map<String, dynamic> emp) {
    final loc = AppLocalizations.of(context);
    final name = (emp['name'] ?? (loc.isArabic ? 'عون رقابة' : 'Agent de contrôle')).toString();
    final empId = emp['id'] ?? emp['Id'] ?? emp['employeeId'];
    final subjectCtrl = TextEditingController(
      text: loc.isArabic ? 'استفسار وأمر بالانضباط حول الغياب / التأخر' : 'Demande d\'explications sur l\'absence / retard',
    );
    final detailsCtrl = TextEditingController(
      text: loc.isArabic
          ? 'بناءً على المعطيات الرقابية في الخريطة المركزية، يُطلب من مكتب المستخدمين توجيه استفسار كتابي رسمي للموظف ($name) مع إلزامه بالرد خلال مهلة 48 ساعة القانونية.'
          : 'Sur la base des données de la carte centrale, le bureau du personnel est chargé d\'adresser une demande d\'explications officielle à l\'agent ($name) sous 48h.',
    );

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E0B26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
        ),
        title: Row(
          children: [
            const Icon(Icons.send_and_archive, color: Color(0xFFD4AF37)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                loc.isArabic ? 'أمر بتوجيه استفسار — $name' : 'Ordre d\'explications — $name',
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.isArabic
                  ? 'المدير الولائي يكلف مكتب المستخدمين بإصدار استفسار كتابي رسمي للموظف عبر المنظومة:'
                  : 'Le Directeur de Wilaya charge le bureau du personnel d\'émettre une demande d\'explications :',
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subjectCtrl,
              textDirection: loc.isArabic ? TextDirection.rtl : TextDirection.ltr,
              decoration: InputDecoration(
                labelText: loc.isArabic ? 'الموضوع' : 'Objet',
                labelStyle: const TextStyle(fontFamily: 'Tajawal', color: Color(0xFFD4AF37)),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: detailsCtrl,
              maxLines: 3,
              textDirection: loc.isArabic ? TextDirection.rtl : TextDirection.ltr,
              decoration: InputDecoration(
                labelText: loc.isArabic ? 'تعليمات وتفاصيل الاستفسار' : 'Instructions et détails',
                labelStyle: const TextStyle(fontFamily: 'Tajawal', color: Colors.white70),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(loc.isArabic ? 'إلغاء' : 'Annuler', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (subjectCtrl.text.trim().isEmpty) return;
              try {
                final auth = context.read<AuthService>();
                final userId = auth.currentUser?.id ?? 1;
                await auth.api.createInquiry({
                  'employeeId': empId,
                  'type': 'unjustified_absence',
                  'subject': subjectCtrl.text.trim(),
                  'details': detailsCtrl.text.trim(),
                  'sentBy': userId,
                });
                if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: AppTheme.SuccessColor,
                    content: Text(
                      loc.isArabic
                          ? '✅ تم تكليف مكتب المستخدمين بإصدار الاستفسار لـ $name بنجاح'
                          : '✅ Demande transmise au bureau du personnel pour $name',
                      style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    backgroundColor: AppTheme.DangerColor,
                    content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(loc.isArabic ? 'إصدار الأمر' : 'Émettre l\'ordre', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showVisitDetailsModal(Map<String, dynamic> v, String inspectorName) {
    final loc = AppLocalizations.of(context);
    final String shop = (v['shopName'] ?? (loc.isArabic ? 'محل تجاري' : 'Commerce')).toString();
    final String? photo = v['photo']?.toString();
    final dynamic lat = v['latitude'];
    final dynamic lng = v['longitude'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.CardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.verified, color: AppTheme.SuccessColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shop, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('${loc.isArabic ? "المفتش" : "Inspecteur"}: $inspectorName', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: AppTheme.TextSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (photo != null && photo.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(photo),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (lat != null && lng != null)
              Text(
                '${loc.isArabic ? "الإحداثيات الجغرافية" : "Coordonnées GPS"}: $lat, $lng',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  QRCodeScreen.show(
                    context,
                    record: {
                      'type': 'visit_evidence',
                      'shop': shop,
                      'inspector': inspectorName,
                      'latitude': lat,
                      'longitude': lng,
                      'id': v['id'] ?? DateTime.now().millisecondsSinceEpoch,
                    },
                    title: loc.isArabic ? 'إثبات المعاينة الميدانية (QR)' : 'Preuve de visite terrain (QR)',
                  );
                },
                icon: const Icon(Icons.qr_code),
                label: Text(
                  loc.isArabic ? 'عرض رمز الاستجابة السريعة للزيارة' : 'Afficher le QR code de la visite',
                  style: const TextStyle(fontFamily: 'Tajawal'),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.AccentColor, foregroundColor: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.AccentColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 12,
            color: AppTheme.TextSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  void _showSearchInspectorSheet() {
    final loc = AppLocalizations.of(context);
    String query = '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final q = query.trim().toLowerCase();
          final filtered = _mapData.where((emp) {
            if (q.isEmpty) return true;
            final name = (emp['name'] ?? '').toString().toLowerCase();
            final service = (emp['service'] ?? '').toString().toLowerCase();
            return name.contains(q) || service.contains(q);
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
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
                      const Icon(Icons.person_search, color: Color(0xFFD4AF37)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          loc.isArabic ? 'البحث عن عون ومتابعة حالته الميدانية' : 'Rechercher un agent et suivre son état',
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    textDirection: loc.isArabic ? TextDirection.rtl : TextDirection.ltr,
                    onChanged: (val) => setSheetState(() => query = val),
                    decoration: InputDecoration(
                      hintText: loc.isArabic ? 'ابحث بالاسم، اللقب أو المصلحة...' : 'Rechercher par nom ou service...',
                      hintStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const Divider(color: Colors.white12, height: 16),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            loc.isArabic ? 'لم يتم العثور على أي عون يطابق البحث' : 'Aucun agent trouvé',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              color: AppTheme.TextSecondary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final emp = filtered[index];
                            final name = emp['name']?.toString() ?? (loc.isArabic ? 'عون رقابة' : 'Agent de contrôle');
                            final service = emp['service']?.toString() ?? (loc.isArabic ? 'مديرية التجارة' : 'Direction du Commerce');
                            final bool hasCheckedIn = emp['hasCheckedIn'] == true;
                            final bool isCheckedOut = emp['isCheckedOut'] == true;
                            final visits = (emp['visits'] as List?) ?? [];
                            final double? lat = (emp['latitude'] is num) ? (emp['latitude'] as num).toDouble() : double.tryParse(emp['latitude']?.toString() ?? '');
                            final double? lng = (emp['longitude'] is num) ? (emp['longitude'] as num).toDouble() : double.tryParse(emp['longitude']?.toString() ?? '');

                            final statusStr = hasCheckedIn
                                ? (isCheckedOut
                                    ? (loc.isArabic ? 'انصرف' : 'Sorti')
                                    : (loc.isArabic ? 'في الميدان (${visits.length} زيارات)' : 'Sur le terrain (${visits.length} v.)'))
                                : (loc.isArabic ? 'لم يسجل الحضور اليوم' : 'Non pointé');

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: hasCheckedIn
                                      ? AppTheme.SuccessColor.withValues(alpha: 0.4)
                                      : Colors.white10,
                                ),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: hasCheckedIn
                                      ? (isCheckedOut
                                          ? Colors.grey.withValues(alpha: 0.3)
                                          : AppTheme.SuccessColor.withValues(alpha: 0.2))
                                      : AppTheme.DangerColor.withValues(alpha: 0.2),
                                  child: Icon(
                                    hasCheckedIn ? Icons.location_on : Icons.person_off,
                                    color: hasCheckedIn
                                        ? (isCheckedOut ? Colors.grey : AppTheme.SuccessColor)
                                        : AppTheme.DangerColor,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  '$service • $statusStr',
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 11,
                                    color: hasCheckedIn ? AppTheme.SuccessColor : AppTheme.TextSecondary,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: Color(0xFFD4AF37),
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  if (lat != null && lng != null && (lat != 0 || lng != 0)) {
                                    _mapController.move(LatLng(lat, lng), 16);
                                    _showInspectorModal(emp);
                                  } else {
                                    _showInspectorModal(emp);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        behavior: SnackBarBehavior.floating,
                                        margin: const EdgeInsets.all(16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        backgroundColor: const Color(0xFF2D1035),
                                        content: Row(
                                          children: [
                                            const Icon(Icons.info_outline, color: Color(0xFFD4AF37), size: 20),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                loc.isArabic
                                                    ? 'العون ($name) لم يسجل حضوره اليوم بعد (لا تتوفر إحداثيات GPS مباشرة)'
                                                    : 'L\'agent ($name) n\'a pas encore pointé aujourd\'hui',
                                                style: const TextStyle(
                                                  fontFamily: 'Tajawal',
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getInspectorateLabel(String id, AppLocalizations loc) {
    if (id == 'الكل') return loc.isArabic ? '📌 كل ولاية سطيف' : '📌 Toute la Wilaya';
    final matches = AppConstants.allInspectorates.where((i) => i.id == id);
    if (matches.isNotEmpty) {
      final insp = matches.first;
      if (loc.isArabic) {
        String cleanName = insp.nameAr;
        if (insp.isMainDirectorate) {
          cleanName = '🏢 المقر الرئيسي (المعبودة)';
        } else if (cleanName.contains('مطار')) {
          cleanName = '✈️ مطار 8 ماي (عين أرنات)';
        } else if (cleanName.contains('المفتشية الإقليمية للتجارة — ')) {
          cleanName = '🏛️ مفتشية ${cleanName.replaceAll('المفتشية الإقليمية للتجارة — ', '')}';
        } else if (cleanName.contains('الملحقة التجارية — ')) {
          cleanName = '🏪 ملحقة ${cleanName.replaceAll('الملحقة التجارية — ', '')}';
        }
        return cleanName;
      } else {
        String cleanName = insp.nameFr;
        if (insp.isMainDirectorate) {
          cleanName = '🏢 Siège Principal (Maabouda)';
        } else if (cleanName.contains('Aéroport')) {
          cleanName = '✈️ Aéroport 8 Mai (Ain Arnat)';
        } else if (cleanName.contains('Inspection Territoriale — ')) {
          cleanName = '🏛️ Insp. ${cleanName.replaceAll('Inspection Territoriale — ', '')}';
        } else if (cleanName.contains('Annexe — ')) {
          cleanName = '🏪 Annexe ${cleanName.replaceAll('Annexe — ', '')}';
        }
        return cleanName;
      }
    }
    return loc.isArabic ? '📌 كل ولاية سطيف' : '📌 Toute la Wilaya';
  }

  void _selectInspectorate(String id) {
    setState(() => _selectedInspectorateId = id);
    if (id == 'الكل') {
      _mapController.move(_setifCenter, 11.0);
    } else {
      final matches = AppConstants.allInspectorates.where((i) => i.id == id);
      if (matches.isNotEmpty) {
        final insp = matches.first;
        _mapController.move(LatLng(insp.latitude, insp.longitude), 15.5);
        _showInspectorateHQModal(insp);
      }
    }
  }

  Widget _searchAgentButton({bool isCompact = false}) {
    final loc = AppLocalizations.of(context);
    return Tooltip(
      message: loc.isArabic ? 'بحث سريع عن عون رقابة' : 'Rechercher un agent',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showSearchInspectorSheet,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF1E0B26).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 6),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_search, size: 16, color: Color(0xFFD4AF37)),
                if (!isCompact) ...[
                  const SizedBox(width: 6),
                  Text(
                    loc.isArabic ? 'بحث عن عون...' : 'Recherche...',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _hqSelectorDropdown({bool isCompact = false}) {
    final loc = AppLocalizations.of(context);
    final currentLabel = _getInspectorateLabel(_selectedInspectorateId, loc);
    return PopupMenuButton<String>(
      tooltip: loc.isArabic ? 'اختيار المقر أو المفتشية الإقليمية' : 'Sélectionner le siège ou l\'inspection',
      offset: const Offset(0, 42),
      color: const Color(0xFF1E0B26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
      ),
      onSelected: _selectInspectorate,
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'الكل',
          child: Row(
            children: [
              const Icon(Icons.public, color: Color(0xFFD4AF37), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.isArabic ? '📌 كامل ولاية سطيف (الكل)' : '📌 Toute la Wilaya de Sétif',
                  style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                ),
              ),
              if (_selectedInspectorateId == 'الكل')
                const Icon(Icons.check, color: Color(0xFFD4AF37), size: 16),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        ...AppConstants.allInspectorates.map((insp) {
          final isSelected = _selectedInspectorateId == insp.id;
          final label = _getInspectorateLabel(insp.id, loc);
          final IconData icon = insp.isMainDirectorate
              ? Icons.account_balance
              : (insp.nameAr.contains('مطار') ? Icons.flight : Icons.apartment);
          return PopupMenuItem<String>(
            value: insp.id,
            child: Row(
              children: [
                Icon(icon, color: insp.isMainDirectorate ? const Color(0xFFD4AF37) : const Color(0xFF38BDF8), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 12,
                          color: isSelected ? const Color(0xFFD4AF37) : Colors.white,
                        ),
                      ),
                      Text(
                        loc.isArabic
                            ? 'نطاق البصمة: ${insp.radiusMeters.round()}م'
                            : 'Rayon GPS : ${insp.radiusMeters.round()}m',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: AppTheme.TextSecondary),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check, color: Color(0xFFD4AF37), size: 16),
              ],
            ),
          );
        }),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF1E0B26).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 6),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance, size: 15, color: Color(0xFFD4AF37)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                currentLabel,
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFFD4AF37)),
          ],
        ),
      ),
    );
  }

  Widget _mapStyleSwitcher({bool isCompact = false}) {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF1E0B26).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.BorderColor.withValues(alpha: 0.5),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 6),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _styleChip('satellite', isCompact ? '🛰️' : (loc.isArabic ? 'أقمار صناعية' : 'Satellite')),
          _styleChip('osm', isCompact ? '🗺️' : (loc.isArabic ? 'خريطة الشوارع' : 'Rues')),
        ],
      ),
    );
  }

  Widget _statsCapsuleContent(
    AppLocalizations loc, {
    required int inFieldCount,
    required int atHQCount,
    required int visitsCount,
    required int notRegisteredCount,
    required int checkedOutCount,
  }) {
    if (_isLoading) {
      return const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.AccentColor,
        ),
      );
    }
    final isWeekend = DateTime.now().weekday == DateTime.friday || DateTime.now().weekday == DateTime.saturday;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _legend(loc.isArabic ? 'في الميدان' : 'Terrain', inFieldCount, const Color(0xFF38BDF8)),
          const SizedBox(width: 10),
          _legend(loc.isArabic ? 'بالمقر' : 'Au siège', atHQCount, AppTheme.SuccessColor),
          const SizedBox(width: 10),
          _legend(loc.isArabic ? 'معاينات اليوم' : 'Visites', visitsCount, const Color(0xFFF59E0B)),
          if (checkedOutCount > 0) ...[
            const SizedBox(width: 10),
            _legend(loc.isArabic ? 'انصرف' : 'Sortis', checkedOutCount, const Color(0xFF94A3B8)),
          ],
          const SizedBox(width: 10),
          _legend(
            isWeekend
                ? (loc.isArabic ? 'لم يسجل (عطلة رسمية)' : 'Non pointé (W-E)')
                : (loc.isArabic ? 'لم يسجل' : 'Non pointé'),
            notRegisteredCount,
            isWeekend ? const Color(0xFF64748B) : AppTheme.DangerColor,
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _loadData,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.AccentColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.refresh,
                size: 14,
                color: AppTheme.AccentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isEmployeeAssignedToHQ(Map<String, dynamic> emp, InspectorateHQ insp) {
    final service = (emp['service'] ?? emp['Service'] ?? emp['serviceName'] ?? '').toString().toLowerCase();
    final fonction = (emp['fonction'] ?? emp['FonctionExercee'] ?? '').toString().toLowerCase();
    final text = '$service $fonction';

    if (insp.id == 'insp_airport_arnat') {
      return text.contains('مطار') || text.contains('aéroport') || text.contains('حدودية') || text.contains('frontalière');
    } else if (insp.id == 'insp_eulma') {
      return text.contains('علمة') || text.contains('eulma');
    } else if (insp.id == 'insp_ain_oulmene') {
      return text.contains('ولمان') || text.contains('oulmene') || text.contains('oulmène');
    } else if (insp.id == 'insp_bougaa') {
      return text.contains('بوقاعة') || text.contains('bougaa') || text.contains('bougaâ');
    } else if (insp.id == 'annex_ain_azel') {
      return text.contains('آزال') || text.contains('azel');
    } else if (insp.id == 'annex_ain_kebira') {
      return text.contains('كبيرة') || text.contains('kebira');
    } else if (insp.id == 'annex_ain_arnat') {
      return (text.contains('أرنات') || text.contains('arnat')) && !text.contains('مطار');
    } else if (insp.isMainDirectorate || insp.id == 'hq_setif') {
      final isRegional = text.contains('علمة') || text.contains('eulma') ||
                         text.contains('ولمان') || text.contains('oulmene') ||
                         text.contains('بوقاعة') || text.contains('bougaa') ||
                         text.contains('مطار') || text.contains('aéroport') ||
                         text.contains('آزال') || text.contains('azel') ||
                         text.contains('كبيرة') || text.contains('kebira');
      return !isRegional;
    }
    return false;
  }

  void _showInspectorateHQModal(InspectorateHQ insp) {
    final loc = AppLocalizations.of(context);
    final assignedEmps = _mapData.where((e) {
      final isAssigned = _isEmployeeAssignedToHQ(e, insp);
      final double? lat = (e['latitude'] is num) ? (e['latitude'] as num).toDouble() : double.tryParse(e['latitude']?.toString() ?? '');
      final double? lng = (e['longitude'] is num) ? (e['longitude'] as num).toDouble() : double.tryParse(e['longitude']?.toString() ?? '');
      final isPhysicallyHere = (lat != null && lng != null && AppConstants.distanceBetween(lat, lng, insp.latitude, insp.longitude) <= insp.radiusMeters);
      return isAssigned || isPhysicallyHere;
    }).toList();

    final presentInHQ = assignedEmps.where((e) {
      final double? lat = (e['latitude'] is num) ? (e['latitude'] as num).toDouble() : double.tryParse(e['latitude']?.toString() ?? '');
      final double? lng = (e['longitude'] is num) ? (e['longitude'] as num).toDouble() : double.tryParse(e['longitude']?.toString() ?? '');
      if (lat == null || lng == null) return false;
      return AppConstants.distanceBetween(lat, lng, insp.latitude, insp.longitude) <= insp.radiusMeters;
    }).toList();

    final inField = assignedEmps.where((e) {
      final isCheckedIn = e['isCheckedIn'] == true;
      return isCheckedIn && !presentInHQ.contains(e);
    }).toList();

    final absent = assignedEmps.where((e) => e['isCheckedIn'] != true).toList();

    String currentFilter = 'all';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          List<Map<String, dynamic>> displayedList = assignedEmps;
          if (currentFilter == 'present') displayedList = presentInHQ;
          if (currentFilter == 'field') displayedList = inField;
          if (currentFilter == 'absent') displayedList = absent;

          return Directionality(
            textDirection: loc.isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF160A1D),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pull handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header with Icon & Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (insp.isMainDirectorate ? const Color(0xFFD4AF37) : const Color(0xFF38BDF8)).withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          insp.isMainDirectorate ? Icons.account_balance : Icons.apartment,
                          color: insp.isMainDirectorate ? const Color(0xFFD4AF37) : const Color(0xFF38BDF8),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.isArabic ? insp.nameAr : insp.nameFr,
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              loc.isArabic
                                  ? '${insp.nameFr} • نطاق الحضور: ${insp.radiusMeters.round()}م'
                                  : '${insp.nameAr} • Rayon GPS : ${insp.radiusMeters.round()}m',
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11,
                                color: AppTheme.TextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white60),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 4-Stats Quick Bar
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F0D28),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF3D1645)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _hqStatItem(loc.isArabic ? 'الأعوان المعينين' : 'Effectif', '${assignedEmps.length}', Colors.white),
                        _hqStatItem(loc.isArabic ? 'حاضرون بالمقر' : 'Au siège', '${presentInHQ.length}', const Color(0xFF10B981)),
                        _hqStatItem(loc.isArabic ? 'في الميدان' : 'Terrain', '${inField.length}', const Color(0xFF38BDF8)),
                        _hqStatItem(loc.isArabic ? 'غائبون' : 'Absents', '${absent.length}', const Color(0xFFF87171)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(loc.isArabic ? 'الكل (${assignedEmps.length})' : 'Tous (${assignedEmps.length})', 'all', currentFilter, (v) => setModalState(() => currentFilter = v)),
                        const SizedBox(width: 6),
                        _buildFilterChip(loc.isArabic ? 'حاضرون بالمقر (${presentInHQ.length})' : 'Au siège (${presentInHQ.length})', 'present', currentFilter, (v) => setModalState(() => currentFilter = v), color: const Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        _buildFilterChip(loc.isArabic ? 'في الميدان (${inField.length})' : 'Terrain (${inField.length})', 'field', currentFilter, (v) => setModalState(() => currentFilter = v), color: const Color(0xFF38BDF8)),
                        const SizedBox(width: 6),
                        _buildFilterChip(loc.isArabic ? 'غائبون (${absent.length})' : 'Absents (${absent.length})', 'absent', currentFilter, (v) => setModalState(() => currentFilter = v), color: const Color(0xFFF87171)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // List of Employees in this HQ
                  Expanded(
                    child: displayedList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, color: Colors.white.withValues(alpha: 0.3), size: 40),
                                const SizedBox(height: 8),
                                Text(
                                  loc.isArabic ? 'لا يوجد أعوان في هذا التصنيف حالياً' : 'Aucun agent dans cette catégorie',
                                  style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white60, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: displayedList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final emp = displayedList[i];
                              final isField = inField.contains(emp);
                              final isAbs = absent.contains(emp);

                              Color statusColor = const Color(0xFF10B981);
                              String statusText = loc.isArabic ? 'حاضر بالمقر' : 'Au siège';
                              IconData statusIcon = Icons.check_circle;

                              if (isField) {
                                statusColor = const Color(0xFF38BDF8);
                                statusText = loc.isArabic ? 'في مهمة ميدانية' : 'En mission';
                                statusIcon = Icons.explore;
                              } else if (isAbs) {
                                statusColor = const Color(0xFFF87171);
                                statusText = loc.isArabic ? 'غائب (لم يسجل)' : 'Absent';
                                statusIcon = Icons.cancel;
                              }

                              final name = (emp['name'] ?? emp['NomAr'] ?? emp['Nom'] ?? (loc.isArabic ? 'مفتش' : 'Agent')).toString();
                              final grade = (emp['grade'] ?? emp['Grade'] ?? (loc.isArabic ? 'مفتش رئيسي' : 'Inspecteur')).toString();
                              final service = (emp['service'] ?? emp['Service'] ?? '').toString();

                              return InkWell(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _showInspectorModal(emp);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1F0D28),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: statusColor.withValues(alpha: 0.15),
                                          border: Border.all(color: statusColor, width: 1.5),
                                        ),
                                        child: Center(
                                          child: Icon(statusIcon, color: statusColor, size: 18),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                fontFamily: 'Tajawal',
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$grade ${service.isNotEmpty ? '• $service' : ''}',
                                              style: const TextStyle(
                                                fontFamily: 'Tajawal',
                                                fontSize: 11,
                                                color: Colors.white60,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_back_ios_new, size: 12, color: Colors.white30),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),

                  // Bottom Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _mapController.move(LatLng(insp.latitude, insp.longitude), 16.0);
                            },
                            icon: const Icon(Icons.center_focus_strong, color: Colors.black, size: 16),
                            label: Text(
                              loc.isArabic ? 'تركيز الخريطة' : 'Centrer la carte',
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.black,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              QRCodeScreen.showOfficialBadge(context, insp);
                            },
                            icon: const Icon(Icons.qr_code_2, color: Color(0xFFD4AF37), size: 16),
                            label: Text(
                              loc.isArabic ? 'الشارة الرقمية (QR)' : 'Badge numérique (QR)',
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFD4AF37)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String current, Function(String) onSelect, {Color? color}) {
    final isSelected = current == value;
    final activeColor = color ?? const Color(0xFFD4AF37);

    return InkWell(
      onTap: () => onSelect(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : Colors.black26,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white12,
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? activeColor : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _hqStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 11,
            color: AppTheme.TextSecondary,
          ),
        ),
      ],
    );
  }
}
