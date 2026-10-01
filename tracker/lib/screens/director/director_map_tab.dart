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
import 'package:drh_setif_tracker/services/inspectorate_service.dart';

class DirectorMapTab extends StatefulWidget {
  const DirectorMapTab({super.key});

  @override
  State<DirectorMapTab> createState() => _DirectorMapTabState();
}

class _DirectorMapTabState extends State<DirectorMapTab>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _mapData = [];
  bool _isLoading = true;
  bool _isLocating = false;
  LatLng? _directorLiveLocation;
  Timer? _liveRefreshTimer;
  final MapController _mapController = MapController();
  String _selectedMapStyle = 'satellite'; // 'satellite', 'osm'
  bool _isLegendExpanded = false;
  Map<String, dynamic>? _selectedInspectorForTrack;
  // 🛰️ كاش نقاط GPS الدورية لكل مفتش (employeeId → قائمة نقاط)
  final Map<int, List<Map<String, dynamic>>> _locationTrailCache = {};

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const LatLng _setifCenter = LatLng(AppConstants.hqLatitude, AppConstants.hqLongitude);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadData();
    // Live Auto-Refresh every 20 seconds (balanced for high-speed responsiveness and zero UI stutter)
    _liveRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) _loadData(silent: true);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    try {
      final api = context.read<AuthService>().api;
      if (!silent) {
        await InspectorateService.instance.loadInspectorates(api: api);
      }
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
          if (_selectedInspectorForTrack != null) {
            final trackId = _selectedInspectorForTrack!['employeeId'] ??
                _selectedInspectorForTrack!['Id'] ??
                _selectedInspectorForTrack!['id'];
            try {
              _selectedInspectorForTrack = cleanData.firstWhere(
                (e) => (e['employeeId'] ?? e['Id'] ?? e['id']) == trackId,
              );
            } catch (_) {}
            // 🛰️ تحديث مسار GPS المفتش المحدد عند كل دورة
            if (silent && trackId != null) {
              _loadInspectorTrail(trackId is int ? trackId : int.tryParse(trackId.toString()) ?? 0);
            }
          }
        });
      }
    } catch (e) {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  /// 🛰️ تحميل مسار GPS الدوري لمفتش محدد وتخزينه في الكاش
  Future<void> _loadInspectorTrail(int employeeId) async {
    if (employeeId <= 0) return;
    try {
      final api = context.read<AuthService>().api;
      final trail = await api.getInspectorTrail(employeeId);
      if (mounted) {
        setState(() {
          _locationTrailCache[employeeId] = trail;
        });
      }
    } catch (_) {}
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
                    color: const Color(0xFF8B5CF6),
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

    final List<LatLng> activeTrackPoints = _selectedInspectorForTrack != null
        ? _getTrackPoints(_selectedInspectorForTrack!)
        : const <LatLng>[];



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
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderColor: const Color(0xFF10B981),
                  borderStrokeWidth: 1.8,
                );
              }).toList(),
            ),

            // 🗺️ Trajectory Route for Selected Inspector (On-Demand only)
            if (_selectedInspectorForTrack != null && activeTrackPoints.length >= 2) ...[
              PolylineLayer(
                polylines: [
                  // Outer Glow Line
                  Polyline(
                    points: activeTrackPoints,
                    strokeWidth: 6.5,
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                  ),
                  // Sharp Core Route
                  Polyline(
                    points: activeTrackPoints,
                    strokeWidth: 3.5,
                    color: const Color(0xFFD4AF37),
                  ),
                ],
              ),
            ],

            // Chronological Waypoint Badges for Selected Inspector
            if (_selectedInspectorForTrack != null)
              MarkerLayer(
                markers: _buildTrackWaypointMarkers(_selectedInspectorForTrack!, loc),
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
                            color: const Color(0xFF881337),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: insp.isMainDirectorate ? const Color(0xFFD4AF37) : Colors.white,
                              width: insp.isMainDirectorate ? 2.5 : 2.0,
                            ),
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

                // Active In-Field & Checked-Out Inspectors Markers (Retains checkout pin)
                ..._mapData
                    .where(
                      (e) =>
                          e['latitude'] != null &&
                          e['hasCheckedIn'] == true,
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
                      final int lateMinutes = (emp['lateMinutes'] as num?)?.toInt() ?? 0;
                      final bool isLate = lateMinutes > 0;
                      final bool isInField = emp['locationType'] == 'in_field' || vCount > 0;

                      Color markerColor;
                      if (isOut) {
                        markerColor = const Color(0xFF64748B);
                      } else if (isLate) {
                        markerColor = const Color(0xFFF97316);
                      } else if (isInField) {
                        markerColor = const Color(0xFF0D9488);
                      } else {
                        markerColor = const Color(0xFF10B981);
                      }

                      final isSelectedForTrack = _selectedInspectorForTrack != null &&
                          (_selectedInspectorForTrack!['employeeId'] ?? _selectedInspectorForTrack!['Id'] ?? _selectedInspectorForTrack!['id']) ==
                              (emp['employeeId'] ?? emp['Id'] ?? emp['id']);

                      return Marker(
                        point: LatLng(lat, lng),
                        width: 58,
                        height: 58,
                        child: GestureDetector(
                          onTap: () {
                            if (isSelectedForTrack) {
                              _showInspectorModal(emp);
                            } else {
                              _focusOnInspectorTrack(emp);
                            }
                          },
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, _) {
                              final pVal = isOut ? 1.0 : _pulseAnimation.value;
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (!isOut || isSelectedForTrack)
                                    Container(
                                      width: (isSelectedForTrack ? 48 : 44) * pVal,
                                      height: (isSelectedForTrack ? 48 : 44) * pVal,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: (isSelectedForTrack ? const Color(0xFFD4AF37) : markerColor)
                                            .withValues(alpha: 0.25 * (1.35 - (pVal - 0.9))),
                                        border: Border.all(
                                          color: (isSelectedForTrack ? const Color(0xFFD4AF37) : markerColor)
                                              .withValues(alpha: 0.7 * (1.35 - (pVal - 0.9))),
                                          width: isSelectedForTrack ? 2.2 : 1.6,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (isSelectedForTrack ? const Color(0xFFD4AF37) : markerColor)
                                                .withValues(alpha: 0.4 * (1.35 - (pVal - 0.9))),
                                            blurRadius: (isSelectedForTrack ? 14 : 10) * pVal,
                                            spreadRadius: isSelectedForTrack ? 3 : 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: isSelectedForTrack ? const Color(0xFFD4AF37) : markerColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelectedForTrack ? Colors.amberAccent : Colors.white,
                                        width: isSelectedForTrack ? 3.0 : 2.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: isSelectedForTrack
                                              ? const Color(0xFFD4AF37).withValues(alpha: 0.8)
                                              : markerColor.withValues(alpha: 0.6),
                                          blurRadius: isSelectedForTrack ? 12 : 8,
                                          spreadRadius: isSelectedForTrack ? 2.5 : 1.5,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      isOut ? Icons.exit_to_app : (isSelectedForTrack ? Icons.route : Icons.person),
                                      color: isSelectedForTrack ? Colors.black87 : Colors.white,
                                      size: isOut ? 20 : 22,
                                    ),
                                  ),
                                  if (vCount > 0)
                                    Positioned(
                                      top: 2,
                                      right: 2,
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
                              );
                            },
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
                          inFieldList: inField,
                          atHQList: atHQ,
                          visitsCount: visitMarkers.length,
                          notRegisteredList: notRegistered,
                          checkedOutList: checkedOut,
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
                        inFieldList: inField,
                        atHQList: atHQ,
                        visitsCount: visitMarkers.length,
                        notRegisteredList: notRegistered,
                        checkedOutList: checkedOut,
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

        // Map Legend (مفتاح رموز الخريطة الرقابي)
        Positioned(
          bottom: 24,
          right: 16,
          child: _buildMapLegend(loc),
        ),

        // 🗺️ Floating Active Trajectory Tracking Pill (When an inspector is selected)
        if (_selectedInspectorForTrack != null)
          Positioned(
            bottom: 84,
            left: 16,
            right: 16,
            child: Center(
              child: _buildActiveTrackPill(loc),
            ),
          ),
      ],
    );
  }

  Widget _buildMapLegend(AppLocalizations loc) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E0B26).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.7), width: 1.2),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => setState(() => _isLegendExpanded = !_isLegendExpanded),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.palette_outlined, color: Color(0xFFD4AF37), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      loc.isArabic ? 'مفتاح الخريطة' : 'Légende',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFFD4AF37),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _isLegendExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                      color: const Color(0xFFD4AF37),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            if (_isLegendExpanded)
              Container(
                constraints: const BoxConstraints(maxWidth: 220),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: Colors.white12, height: 8),
                    // ── عناصر المفتاح بأيقونات وألوان مميزة تماماً ──
                    _legendItem(const Color(0xFF10B981), loc.isArabic ? 'حضور منضبط بالمقر' : 'Présent à l\'heure (siège)', icon: Icons.check_circle_outline),
                    const SizedBox(height: 5),
                    _legendItem(const Color(0xFFF97316), loc.isArabic ? 'حاضر مع تأخر صباحي' : 'Présent avec retard', icon: Icons.schedule),
                    const SizedBox(height: 5),
                    _legendItem(const Color(0xFF0D9488), loc.isArabic ? 'نشط في الميدان' : 'Actif sur le terrain', icon: Icons.directions_walk),
                    const SizedBox(height: 5),
                    _legendItem(const Color(0xFF8B5CF6), loc.isArabic ? 'معاينة / محل تجاري' : 'Visite / commerce', icon: Icons.storefront),
                    const SizedBox(height: 5),
                    _legendItem(const Color(0xFF64748B), loc.isArabic ? 'منصرف (أنهى الدوام)' : 'Sorti (fin de shift)', icon: Icons.exit_to_app),
                    const SizedBox(height: 5),
                    _legendItem(const Color(0xFFEF4444), loc.isArabic ? 'لم يسجل الحضور (غائب)' : 'Non enregistré (absent)', icon: Icons.person_off_outlined),
                    const SizedBox(height: 5),
                    _legendItem(
                      const Color(0xFF10B981),
                      loc.isArabic ? 'نطاق البصمة (المقرات)' : 'Périmètre GPS officiel',
                      isCircle: true,
                    ),
                    const SizedBox(height: 5),
                    _legendItem(
                      const Color(0xFFD4AF37),
                      loc.isArabic ? 'مسار المفتش (عند النقر)' : 'Itinéraire (sélection)',
                      icon: Icons.route,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label, {bool isCircle = false, IconData? icon}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null && !isCircle)
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.6), width: 0.8),
            ),
            child: Icon(icon, color: color, size: 12),
          )
        else
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: isCircle ? color.withValues(alpha: 0.2) : color,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: isCircle ? 1.8 : 1.0),
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70),
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

  Widget _legend(String label, int count, Color color, {VoidCallback? onTap}) {
    final chip = Container(
      padding: onTap != null ? const EdgeInsets.symmetric(horizontal: 7, vertical: 3) : EdgeInsets.zero,
      decoration: onTap != null
          ? BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4),
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
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: chip,
      );
    }
    return chip;
  }

  void _showCategoryPersonnelModal(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> emps,
    Color themeColor, {
    bool isCheckout = false,
    bool isAbsent = false,
  }) {
    final loc = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String modalSearch = '';
        String selectedService = 'all';

        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredEmps = emps.where((emp) {
              final name = (emp['name'] ?? '').toString().toLowerCase();
              final service = (emp['service'] ?? '').toString();
              if (selectedService != 'all' && !service.contains(selectedService)) {
                return false;
              }
              if (modalSearch.trim().isNotEmpty) {
                final q = modalSearch.trim().toLowerCase();
                if (!name.contains(q) && !service.toLowerCase().contains(q)) {
                  return false;
                }
              }
              return true;
            }).toList();

            return Directionality(
              textDirection: loc.isArabic ? TextDirection.rtl : TextDirection.ltr,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.82,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF160A1D),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: themeColor.withValues(alpha: 0.45), width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black87, blurRadius: 20, spreadRadius: 4),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCheckout ? Icons.exit_to_app : (isAbsent ? Icons.person_off : Icons.people_outline),
                            color: themeColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                loc.isArabic
                                    ? 'المعروض: ${filteredEmps.length} من إجمالي ${emps.length} موظف'
                                    : 'Affiché : ${filteredEmps.length} sur ${emps.length}',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 11,
                                  color: themeColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Quick Search Field
                    TextField(
                      onChanged: (v) => setModalState(() => modalSearch = v),
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: loc.isArabic ? 'ابحث سريعاً بالاسم أو اللقب أو المصلحة...' : 'Recherche rapide par nom...',
                        hintStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37), size: 20),
                        filled: true,
                        fillColor: Colors.black38,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Quick Filter Chips by Service
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            loc.isArabic ? 'الكل (${emps.length})' : 'Tous',
                            'all',
                            selectedService,
                            (v) => setModalState(() => selectedService = v),
                            color: themeColor,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            loc.isArabic ? 'حماية المستهلك' : 'Consommation',
                            'حماية المستهلك',
                            selectedService,
                            (v) => setModalState(() => selectedService = v),
                            color: const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            loc.isArabic ? 'المنافسة والتحقيقات' : 'Concurrence',
                            'المنافسة',
                            selectedService,
                            (v) => setModalState(() => selectedService = v),
                            color: const Color(0xFFD4AF37),
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            loc.isArabic ? 'ملاحظة السوق' : 'Marché',
                            'ملاحظة السوق',
                            selectedService,
                            (v) => setModalState(() => selectedService = v),
                            color: const Color(0xFF38BDF8),
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            loc.isArabic ? 'الإدارة والوسائل' : 'Administration',
                            'الإدارة',
                            selectedService,
                            (v) => setModalState(() => selectedService = v),
                            color: const Color(0xFFF97316),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white12, height: 16),
                    Expanded(
                      child: filteredEmps.isEmpty
                          ? Center(
                              child: Text(
                                loc.isArabic ? 'لا توجد نتائج تطابق البحث' : 'Aucun résultat trouvé',
                                style: const TextStyle(fontFamily: 'Tajawal', color: AppTheme.TextSecondary),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredEmps.length,
                        itemBuilder: (context, idx) {
                          final emp = filteredEmps[idx];
                          final name = emp['name']?.toString() ?? (loc.isArabic ? 'موظف' : 'Employé');
                          final service = emp['service']?.toString() ?? '';
                          final checkIn = emp['checkInTime'] != null ? _formatAttendanceTime(emp['checkInTime']) : null;
                          final checkOut = emp['checkOutTime'] != null ? _formatAttendanceTime(emp['checkOutTime']) : null;
                          final String? earlyReason = emp['earlyReason']?.toString() ?? emp['notes']?.toString();
                          final String checkOutLoc = (emp['checkOutLocation'] ?? emp['hqName'] ?? '').toString();
                          final double? lat = (emp['latitude'] is num) ? (emp['latitude'] as num).toDouble() : double.tryParse(emp['latitude']?.toString() ?? '');
                          final double? lng = (emp['longitude'] is num) ? (emp['longitude'] as num).toDouble() : double.tryParse(emp['longitude']?.toString() ?? '');
                          final hasCoords = lat != null && lng != null && (lat != 0 || lng != 0);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.CardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: themeColor.withValues(alpha: 0.3),
                                width: 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: themeColor.withValues(alpha: 0.15),
                                      child: Icon(
                                        isCheckout ? Icons.exit_to_app : (isAbsent ? Icons.person_off : Icons.person),
                                        color: themeColor,
                                        size: 18,
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
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          if (service.isNotEmpty)
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
                                    if (hasCoords)
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _focusOnInspectorTrack(emp);
                                        },
                                        icon: const Icon(Icons.route, size: 14, color: Colors.black87),
                                        label: Text(
                                          loc.isArabic ? 'رسم المسار 🗺️' : 'Itinéraire 🗺️',
                                          style: const TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFD4AF37),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                  ],
                                ),
                                if (isCheckout) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.login, size: 14, color: Color(0xFF10B981)),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${loc.isArabic ? "الدخول:" : "Entrée:"} ${checkIn ?? "--"}',
                                              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70),
                                            ),
                                            const Spacer(),
                                            const Icon(Icons.logout, size: 14, color: Color(0xFF94A3B8)),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${loc.isArabic ? "الانصراف:" : "Sortie:"} ${checkOut ?? "--"}',
                                              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFCBD5E1), fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        if (earlyReason != null && earlyReason.toString().isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.report_problem_outlined, size: 13, color: Color(0xFFF59E0B)),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  '${loc.isArabic ? "المبرر:" : "Motif:"} $earlyReason',
                                                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFFBBF24)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        if (checkOutLoc.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFFD4AF37)),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  '${loc.isArabic ? "موقع الانصراف:" : "Lieu:"} $checkOutLoc',
                                                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.white60),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ] else if (isAbsent) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.cancel_outlined, size: 13, color: Color(0xFFEF4444)),
                                      const SizedBox(width: 4),
                                      Text(
                                        loc.isArabic ? 'لم يتم تسجيل الحضور بالبصمة الجغرافية اليوم' : 'Absence de pointage aujourd\'hui',
                                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFFFCA5A5)),
                                      ),
                                    ],
                                  ),
                                ] else if (checkIn != null) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 13, color: Color(0xFF10B981)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${loc.isArabic ? "سجل الحضور في:" : "Pointé à:"} $checkIn',
                                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        );
      },
    );
  },
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

  List<LatLng> _getTrackPoints(Map<String, dynamic> emp) {
    final empId = emp['employeeId'] ?? emp['Id'] ?? emp['id'];
    final int? resolvedId = empId is int ? empId : int.tryParse(empId?.toString() ?? '');

    // 🛰️ نقاط GPS الدورية من الكاش (مرتبة زمنياً)
    final List<Map<String, dynamic>> trailPts =
        (resolvedId != null && _locationTrailCache.containsKey(resolvedId))
            ? List<Map<String, dynamic>>.from(_locationTrailCache[resolvedId]!)
            : [];

    // نقاط المعاينات مرتبة زمنياً
    final rawVisits = (emp['visits'] as List?) ?? [];
    final List<Map<String, dynamic>> sortedVisits = [];
    for (final v in rawVisits) {
      if (v is Map) sortedVisits.add(Map<String, dynamic>.from(v));
    }
    sortedVisits.sort((a, b) {
      final tA = a['time']?.toString() ?? '';
      final tB = b['time']?.toString() ?? '';
      return tA.compareTo(tB);
    });

    // دمج جميع النقاط في قائمة واحدة مرتبة زمنياً
    final List<Map<String, dynamic>> allPoints = [];

    // أ) نقطة انطلاق الحضور (CheckIn)
    final double? cLat = (emp['checkInLatitude'] is num)
        ? (emp['checkInLatitude'] as num).toDouble()
        : double.tryParse(emp['checkInLatitude']?.toString() ?? '');
    final double? cLng = (emp['checkInLongitude'] is num)
        ? (emp['checkInLongitude'] as num).toDouble()
        : double.tryParse(emp['checkInLongitude']?.toString() ?? '');
    if (cLat != null && cLng != null && (cLat != 0 || cLng != 0)) {
      allPoints.add({'lat': cLat, 'lng': cLng, 'time': emp['checkInTime']?.toString() ?? '00:00:00'});
    }

    // ب) نقاط GPS الدورية من locationHistory
    for (final t in trailPts) {
      final double? tLat = (t['latitude'] is num)
          ? (t['latitude'] as num).toDouble()
          : double.tryParse(t['latitude']?.toString() ?? '');
      final double? tLng = (t['longitude'] is num)
          ? (t['longitude'] as num).toDouble()
          : double.tryParse(t['longitude']?.toString() ?? '');
      if (tLat != null && tLng != null && (tLat != 0 || tLng != 0)) {
        allPoints.add({'lat': tLat, 'lng': tLng, 'time': t['recordedAt']?.toString() ?? ''});
      }
    }

    // ج) نقاط المعاينات الميدانية
    for (final v in sortedVisits) {
      final double? vLat = (v['latitude'] is num)
          ? (v['latitude'] as num).toDouble()
          : double.tryParse(v['latitude']?.toString() ?? '');
      final double? vLng = (v['longitude'] is num)
          ? (v['longitude'] as num).toDouble()
          : double.tryParse(v['longitude']?.toString() ?? '');
      if (vLat != null && vLng != null && (vLat != 0 || vLng != 0)) {
        allPoints.add({'lat': vLat, 'lng': vLng, 'time': v['time']?.toString() ?? ''});
      }
    }

    // د) نقطة الانصراف أو الموقع الحالي
    final isOut = emp['isCheckedOut'] == true;
    double? endLat;
    double? endLng;
    String endTime = '23:59:59';
    if (isOut) {
      endLat = (emp['checkOutLatitude'] is num)
          ? (emp['checkOutLatitude'] as num).toDouble()
          : double.tryParse(emp['checkOutLatitude']?.toString() ?? '');
      endLng = (emp['checkOutLongitude'] is num)
          ? (emp['checkOutLongitude'] as num).toDouble()
          : double.tryParse(emp['checkOutLongitude']?.toString() ?? '');
      endTime = emp['checkOutTime']?.toString() ?? '23:59:59';
    } else {
      endLat = (emp['latitude'] is num)
          ? (emp['latitude'] as num).toDouble()
          : double.tryParse(emp['latitude']?.toString() ?? '');
      endLng = (emp['longitude'] is num)
          ? (emp['longitude'] as num).toDouble()
          : double.tryParse(emp['longitude']?.toString() ?? '');
    }
    if (endLat != null && endLng != null && (endLat != 0 || endLng != 0)) {
      allPoints.add({'lat': endLat, 'lng': endLng, 'time': endTime});
    }

    // ترتيب جميع النقاط زمنياً
    allPoints.sort((a, b) => (a['time'] as String).compareTo(b['time'] as String));

    // تحويل إلى LatLng مع إزالة التكرارات (< 5 متر)
    final List<LatLng> points = [];
    for (final p in allPoints) {
      final pt = LatLng(p['lat'] as double, p['lng'] as double);
      if (points.isEmpty) {
        points.add(pt);
      } else {
        final last = points.last;
        final dLat = (last.latitude - pt.latitude).abs();
        final dLng = (last.longitude - pt.longitude).abs();
        // تجاهل النقاط المتقاربة جداً (< 5م)
        if (dLat > 0.000045 || dLng > 0.000045) {
          points.add(pt);
        }
      }
    }

    return points;
  }

  void _focusOnInspectorTrack(Map<String, dynamic> emp) {
    final loc = AppLocalizations.of(context);
    final name = (emp['name'] ?? (loc.isArabic ? 'المفتش' : 'Inspecteur')).toString();

    // 🛰️ تحميل مسار GPS الدوري فوراً عند اختيار المفتش
    final empId = emp['employeeId'] ?? emp['Id'] ?? emp['id'];
    final int? resolvedId = empId is int ? empId : int.tryParse(empId?.toString() ?? '');
    if (resolvedId != null && resolvedId > 0) {
      _loadInspectorTrail(resolvedId);
    }

    setState(() {
      _selectedInspectorForTrack = emp;
    });

    // نحسب النقاط الحالية لتحديد رسالة الربط (تحتسب بدون trail cache أولاً)
    final points = _getTrackPoints(emp);

    if (points.isEmpty) {
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
                      ? 'العون ($name) لم يسجل حضوره اليوم بعد، لا تتوفر أي محطات مسجلة.'
                      : 'L\'agent ($name) n\'a pas encore de points enregistrés aujourd\'hui.',
                  style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    if (points.length == 1) {
      _mapController.move(points.first, 16.0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF1E0B26),
          duration: const Duration(seconds: 3),
          content: Text(
            loc.isArabic
                ? '📍 تم تحديد موقع انطلاق المفتش ($name) — محطة واحدة مسجلة (حضور بالمقر)'
                : '📍 Point de départ de l\'agent ($name) localisé (1 station)',
            style: const TextStyle(fontFamily: 'Tajawal', color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else {
      try {
        final bounds = LatLngBounds.fromPoints(points);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(85),
          ),
        );
      } catch (_) {
        _mapController.move(points.last, 15.5);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF1E0B26),
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              const Icon(Icons.route, color: Color(0xFFD4AF37), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc.isArabic
                      ? '🗺️ تم رسم مسار الجولة الميدانية للمفتش ($name) — ${points.length} محطات'
                      : '🗺️ Itinéraire terrain tracé pour ($name) — ${points.length} stations',
                  style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  List<Marker> _buildTrackWaypointMarkers(Map<String, dynamic> emp, AppLocalizations loc) {
    final List<Marker> markers = [];
    final name = (emp['name'] ?? (loc.isArabic ? 'المفتش' : 'Inspecteur')).toString();

    // 1. Check-in Start Marker (Emerald Green #1)
    final double? cLat = (emp['checkInLatitude'] is num)
        ? (emp['checkInLatitude'] as num).toDouble()
        : double.tryParse(emp['checkInLatitude']?.toString() ?? '');
    final double? cLng = (emp['checkInLongitude'] is num)
        ? (emp['checkInLongitude'] as num).toDouble()
        : double.tryParse(emp['checkInLongitude']?.toString() ?? '');

    if (cLat != null && cLng != null && (cLat != 0 || cLng != 0)) {
      final checkInStr = emp['checkInTime'] != null ? _formatAttendanceTime(emp['checkInTime']) : '';
      markers.add(
        Marker(
          point: LatLng(cLat, cLng),
          width: 36,
          height: 36,
          child: Tooltip(
            message: loc.isArabic ? 'المحطة 1: انطلاق بالمقر ($checkInStr)' : 'Étape 1: Départ ($checkInStr)',
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 6, spreadRadius: 1),
                ],
              ),
              child: const Center(
                child: Text(
                  '1',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 2. Visits Markers (Numbered 2, 3, 4...)
    final rawVisits = (emp['visits'] as List?) ?? [];
    final List<Map<String, dynamic>> sortedVisits = [];
    for (final v in rawVisits) {
      if (v is Map) {
        sortedVisits.add(Map<String, dynamic>.from(v));
      }
    }
    sortedVisits.sort((a, b) {
      final tA = a['time']?.toString() ?? '';
      final tB = b['time']?.toString() ?? '';
      return tA.compareTo(tB);
    });

    for (int i = 0; i < sortedVisits.length; i++) {
      final v = sortedVisits[i];
      final double? vLat = (v['latitude'] is num)
          ? (v['latitude'] as num).toDouble()
          : double.tryParse(v['latitude']?.toString() ?? '');
      final double? vLng = (v['longitude'] is num)
          ? (v['longitude'] as num).toDouble()
          : double.tryParse(v['longitude']?.toString() ?? '');
      if (vLat == null || vLng == null || (vLat == 0 && vLng == 0)) continue;

      final int stepNum = (markers.isNotEmpty ? 2 : 1) + i;
      final String shop = (v['shopName'] ?? (loc.isArabic ? 'محل تجاري' : 'Commerce')).toString();
      final bool hasViolation = v['violationFound'] == true || v['violationFound'] == 1;

      markers.add(
        Marker(
          point: LatLng(vLat, vLng),
          width: 36,
          height: 36,
          child: GestureDetector(
            onTap: () => _showVisitDetailsModal(v, name),
            child: Tooltip(
              message: 'المحطة $stepNum: $shop',
              child: Container(
                decoration: BoxDecoration(
                  color: hasViolation ? const Color(0xFFEF4444) : const Color(0xFFD4AF37),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 6, spreadRadius: 1),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$stepNum',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: hasViolation ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildActiveTrackPill(AppLocalizations loc) {
    if (_selectedInspectorForTrack == null) return const SizedBox.shrink();
    final emp = _selectedInspectorForTrack!;
    final name = (emp['name'] ?? (loc.isArabic ? 'المفتش' : 'Inspecteur')).toString();
    final trackPts = _getTrackPoints(emp);
    double trackDistKm = 0.0;
    if (trackPts.length >= 2) {
      for (int i = 0; i < trackPts.length - 1; i++) {
        trackDistKm += Geolocator.distanceBetween(
          trackPts[i].latitude,
          trackPts[i].longitude,
          trackPts[i + 1].latitude,
          trackPts[i + 1].longitude,
        ) / 1000.0;
      }
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 580),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E1038), Color(0xFF1E0B26)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFD4AF37),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
              color: Color(0xFFD4AF37),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.route, color: Colors.black, size: 18),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loc.isArabic ? 'مسار الجولة:' : 'Itinéraire:',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        color: Color(0xFFD4AF37),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  loc.isArabic
                      ? '${trackPts.length} محطات | ${trackDistKm.toStringAsFixed(1)} كم مسار مقدر'
                      : '${trackPts.length} stations | ~${trackDistKm.toStringAsFixed(1)} km',
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
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.center_focus_strong, color: Color(0xFFD4AF37), size: 20),
            tooltip: loc.isArabic ? 'التركيز على كامل المسار' : 'Recadrer',
            visualDensity: VisualDensity.compact,
            onPressed: () => _focusOnInspectorTrack(emp),
          ),
          ElevatedButton.icon(
            onPressed: () => _showInspectorModal(emp),
            icon: const Icon(Icons.info_outline, size: 14),
            label: Text(
              loc.isArabic ? 'التفاصيل والـ QR' : 'Détails & QR',
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            tooltip: loc.isArabic ? 'إخفاء المسار' : 'Masquer',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              setState(() => _selectedInspectorForTrack = null);
            },
          ),
        ],
      ),
    );
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
    final bool hasCheckInPhoto = emp['hasCheckInPhoto'] == true;
    final int empId = int.tryParse('${emp['employeeId'] ?? emp['Id'] ?? emp['id'] ?? 0}') ?? 0;

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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _focusOnInspectorTrack(emp);
                },
                icon: const Icon(Icons.route, color: Colors.black87, size: 18),
                label: Text(
                  loc.isArabic
                      ? 'رسم مسار الجولة الميدانية على الخريطة 🗺️'
                      : 'Tracer l\'itinéraire de la tournée 🗺️',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
              ),
            ),
            if (emp['activeProgram'] != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assignment, color: Color(0xFFD4AF37), size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            loc.isArabic ? 'أمر المهمة الرقابية المعين:' : 'Ordre de mission assigné :',
                            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37)),
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
            if (isOut) ...[
              const SizedBox(height: 8),
              _infoRow(
                Icons.exit_to_app,
                loc.isArabic ? 'توقيت الانصراف' : 'Heure de sortie',
                _formatAttendanceTime(emp['checkOutTime']),
                valueColor: const Color(0xFFCBD5E1),
              ),
              if (emp['checkOutLocation'] != null && emp['checkOutLocation'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                _infoRow(
                  Icons.location_on_outlined,
                  loc.isArabic ? 'موقع الانصراف المسجل' : 'Lieu de départ',
                  emp['checkOutLocation'].toString(),
                  valueColor: const Color(0xFFD4AF37),
                ),
              ],
              if (emp['earlyReason'] != null && emp['earlyReason'].toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                _infoRow(
                  Icons.report_problem_outlined,
                  loc.isArabic ? 'مبرر الانصراف المبكر' : 'Motif de sortie',
                  emp['earlyReason'].toString(),
                  valueColor: const Color(0xFFF59E0B),
                ),
              ],
            ],
            if (emp['notes'] != null && emp['notes'].toString().isNotEmpty && emp['notes'] != emp['earlyReason']) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.notes, loc.isArabic ? 'ملاحظة إضافية' : 'Note', emp['notes'].toString()),
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
            ] else if (hasCheckInPhoto && empId > 0) ...[
              const SizedBox(height: 12),
              Text(loc.isArabic ? 'صورة إثبات الحضور الميداني:' : 'Photo de présence terrain :', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              FutureBuilder<String?>(
                future: context.read<AuthService>().api.getAttendancePhoto(empId),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 80,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37)),
                      ),
                    );
                  }
                  final p = snap.data;
                  if (p == null || p.isEmpty) return const SizedBox.shrink();
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      base64Decode(p),
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  );
                },
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
            if (isOut) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        backgroundColor: const Color(0xFF240D2D),
                        title: Row(
                          children: [
                            const Icon(Icons.restore, color: Color(0xFFD4AF37)),
                            const SizedBox(width: 8),
                            Text(
                              loc.isArabic ? 'إلغاء الانصراف واستئناف الدوام' : 'Annuler la sortie',
                              style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        content: Text(
                          loc.isArabic
                              ? 'هل تود إلغاء الانصراف المسجل للعون ($name) وإعادة تفعيل بطاقة حضوره لليوم (في حال الضغط خطأ من طرفه)؟'
                              : 'Voulez-vous annuler la sortie de ($name) et réactiver son pointage ?',
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx, false),
                            child: Text(loc.isArabic ? 'تراجع' : 'Non', style: const TextStyle(fontFamily: 'Tajawal')),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black),
                            onPressed: () => Navigator.pop(dCtx, true),
                            child: Text(loc.isArabic ? 'تأكيد الإلغاء واستئناف الدوام' : 'Confirmer', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && mounted) {
                      final api = context.read<AuthService>().api;
                      final int eId = (emp['employeeId'] ?? emp['Id'] ?? emp['id'] ?? 0) as int;
                      await api.cancelCheckOut(eId);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              loc.isArabic ? '✅ تم إلغاء الانصراف واستئناف دوام العون بنجاح' : 'Sortie annulée avec succès',
                              style: const TextStyle(fontFamily: 'Tajawal'),
                            ),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                        _loadData(silent: false);
                      }
                    }
                  },
                  icon: const Icon(Icons.restore, color: Color(0xFFD4AF37), size: 18),
                  label: Text(
                    loc.isArabic ? 'إلغاء الانصراف الخاطئ واستئناف الدوام' : 'Annuler la sortie (Erreur)',
                    style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFD4AF37)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFD4AF37)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
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
    final bool hasPhoto = v['hasPhoto'] == true || v['HasPhoto'] == true;
    final int visitId = int.tryParse('${v['id'] ?? v['Id'] ?? 0}') ?? 0;
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
            ] else if (hasPhoto && visitId > 0) ...[
              FutureBuilder<Map<String, dynamic>?>(
                future: context.read<AuthService>().api.getVisitDetails(visitId),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 90,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37)),
                      ),
                    );
                  }
                  final p = snap.data?['Photo']?.toString() ?? snap.data?['photo']?.toString();
                  if (p == null || p.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(p),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  );
                },
              ),
            ],
            if (lat != null && lng != null)
              Text(
                '${loc.isArabic ? "الإحداثيات الجغرافية" : "Coordonnées GPS"}: $lat, $lng',
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.white70),
              ),
            const SizedBox(height: 10),

            // 📋 Legal Metadata (Paper PV, Partner Inspector, Mission Type)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt_long, color: Color(0xFFD4AF37), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        loc.isArabic ? 'رقم المحضر الورقي (Avis de passage): ' : 'N° PV / Avis : ',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.TextSecondary),
                      ),
                      Expanded(
                        child: Text(
                          (v['paperPvNumber'] ?? v['PaperPvNumber'] ?? (loc.isArabic ? 'غير مسجل' : 'Non spécifié')).toString(),
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.people_alt, color: Color(0xFF10B981), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        loc.isArabic ? 'العون المرافق (الثنائي الرقابي): ' : 'Binôme : ',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.TextSecondary),
                      ),
                      Expanded(
                        child: Text(
                          (v['partnerInspectorName'] ?? v['PartnerInspectorName'] ?? (loc.isArabic ? 'مهمة فردية' : 'Mission solo')).toString(),
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.assignment, color: Color(0xFFF59E0B), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        loc.isArabic ? 'طبيعة المهمة: ' : 'Type de mission : ',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: AppTheme.TextSecondary),
                      ),
                      Expanded(
                        child: Text(
                          (v['missionType'] ?? v['MissionType']) == 'market_observation'
                              ? (loc.isArabic ? 'ملاحظة السوق واستطلاع الأسعار' : 'Observation du marché')
                              : ((v['missionType'] ?? v['MissionType']) == 'administrative_inquiry'
                                  ? (loc.isArabic ? 'تحقيق إداري واستدعاء' : 'Enquête administrative')
                                  : (loc.isArabic ? 'رقابة وقمع الغش' : 'Contrôle & Répression des fraudes')),
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFCD34D)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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

  Widget _infoRow(IconData icon, String label, String value, {Color? valueColor}) {
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
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.white,
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
                                  _focusOnInspectorTrack(emp);
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
    required List<Map<String, dynamic>> inFieldList,
    required List<Map<String, dynamic>> atHQList,
    required int visitsCount,
    required List<Map<String, dynamic>> notRegisteredList,
    required List<Map<String, dynamic>> checkedOutList,
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
          _legend(
            loc.isArabic ? 'في الميدان' : 'Terrain',
            inFieldList.length,
            const Color(0xFFD4AF37),
            onTap: () => _showCategoryPersonnelModal(
              context,
              loc.isArabic ? 'المفتشون في الميدان' : 'Agents sur le terrain',
              inFieldList,
              const Color(0xFFD4AF37),
            ),
          ),
          const SizedBox(width: 8),
          _legend(
            loc.isArabic ? 'بالمقر' : 'Au siège',
            atHQList.length,
            AppTheme.SuccessColor,
            onTap: () => _showCategoryPersonnelModal(
              context,
              loc.isArabic ? 'الموظفون الحاضرون بالمقر' : 'Présents au siège',
              atHQList,
              AppTheme.SuccessColor,
            ),
          ),
          const SizedBox(width: 8),
          _legend(loc.isArabic ? 'معاينات اليوم' : 'Visites', visitsCount, const Color(0xFFF59E0B)),
          if (checkedOutList.isNotEmpty) ...[
            const SizedBox(width: 8),
            _legend(
              loc.isArabic ? 'انصرف' : 'Sortis',
              checkedOutList.length,
              const Color(0xFF94A3B8),
              onTap: () => _showCategoryPersonnelModal(
                context,
                loc.isArabic ? 'الموظفون المنصرفون اليوم' : 'Agents sortis aujourd\'hui',
                checkedOutList,
                const Color(0xFF94A3B8),
                isCheckout: true,
              ),
            ),
          ],
          const SizedBox(width: 8),
          _legend(
            isWeekend
                ? (loc.isArabic ? 'لم يسجل (عطلة)' : 'Non pointé (W-E)')
                : (loc.isArabic ? 'لم يسجل' : 'Non pointé'),
            notRegisteredList.length,
            isWeekend ? const Color(0xFF64748B) : AppTheme.DangerColor,
            onTap: () => _showCategoryPersonnelModal(
              context,
              loc.isArabic ? 'غير المسجلين للحضور اليوم (غياب)' : 'Non enregistrés (absents)',
              notRegisteredList,
              AppTheme.DangerColor,
              isAbsent: true,
            ),
          ),
          const SizedBox(width: 8),
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

    // Find Head of Inspectorate in _mapData (by headEmpId or headNameAr)
    Map<String, dynamic>? headEmpRecord;
    if (insp.headEmpId != null) {
      try {
        headEmpRecord = _mapData.firstWhere(
          (e) => (e['employeeId'] ?? e['Id'] ?? e['id']) == insp.headEmpId,
        );
      } catch (_) {}
    }
    if (headEmpRecord == null && insp.headNameAr != null && insp.headNameAr!.isNotEmpty) {
      try {
        headEmpRecord = _mapData.firstWhere((e) {
          final n = (e['name'] ?? e['NomAr'] ?? '').toString();
          return n.contains(insp.headNameAr!);
        });
      } catch (_) {}
    }

    String currentFilter = 'all';
    String searchQuery = '';

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

          if (searchQuery.trim().isNotEmpty) {
            final q = searchQuery.trim().toLowerCase();
            displayedList = displayedList.where((e) {
              final n = (e['name'] ?? e['NomAr'] ?? e['Nom'] ?? '').toString().toLowerCase();
              final g = (e['grade'] ?? e['Grade'] ?? '').toString().toLowerCase();
              return n.contains(q) || g.contains(q);
            }).toList();
          }

          // Sort: Put Head of Inspectorate at the top if present
          if (headEmpRecord != null && displayedList.contains(headEmpRecord)) {
            displayedList = [
              headEmpRecord,
              ...displayedList.where((e) => e != headEmpRecord),
            ];
          }

          return Directionality(
            textDirection: loc.isArabic ? TextDirection.rtl : TextDirection.ltr,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.88,
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
                          color: (insp.isMainDirectorate ? const Color(0xFFD4AF37) : const Color(0xFF881337)).withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: insp.isMainDirectorate ? const Color(0xFFD4AF37) : const Color(0xFF881337),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          insp.isMainDirectorate ? Icons.account_balance : Icons.apartment,
                          color: insp.isMainDirectorate ? const Color(0xFFD4AF37) : Colors.white,
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
                  const SizedBox(height: 12),

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

                  // 👑 بطاقة مسؤول / رئيس المفتشية الإقليمية الرسمية (مثبتة في الصدارة للمدير)
                  if (insp.headNameAr != null && insp.headNameAr!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E1238), Color(0xFF1A0A22)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD4AF37), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                            ),
                            child: const Center(
                              child: Icon(Icons.stars, color: Color(0xFFD4AF37), size: 22),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD4AF37),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        loc.isArabic ? 'مسؤول الهيكل' : 'Chef',
                                        style: const TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        insp.headTitleAr ?? (loc.isArabic ? 'رئيس المفتشية' : 'Chef d\'inspection'),
                                        style: const TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontSize: 11,
                                          color: Color(0xFFE2E8F0),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  insp.headNameAr!,
                                  style: const TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD4AF37),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Live Status Pill of the Head
                          Builder(
                            builder: (_) {
                              final isPres = headEmpRecord != null && presentInHQ.contains(headEmpRecord);
                              final isFld = headEmpRecord != null && inField.contains(headEmpRecord);
                              Color c = const Color(0xFFF87171);
                              String t = loc.isArabic ? 'لم يسجل' : 'Absent';
                              IconData ic = Icons.cancel;
                              if (isPres) {
                                c = const Color(0xFF10B981);
                                t = loc.isArabic ? 'حاضر بالمقر' : 'Au siège';
                                ic = Icons.check_circle;
                              } else if (isFld) {
                                c = const Color(0xFF38BDF8);
                                t = loc.isArabic ? 'في الميدان' : 'Terrain';
                                ic = Icons.explore;
                              }
                              return InkWell(
                                onTap: headEmpRecord != null
                                    ? () {
                                        Navigator.pop(ctx);
                                        _showInspectorModal(headEmpRecord!);
                                      }
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: c.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: c, width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(ic, color: c, size: 13),
                                      const SizedBox(width: 4),
                                      Text(
                                        t,
                                        style: TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: c,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

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

                  // Quick search box inside modal
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 6),
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F0D28),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TextField(
                      style: const TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 12.5),
                      onChanged: (val) => setModalState(() => searchQuery = val),
                      decoration: InputDecoration(
                        hintText: loc.isArabic ? 'بحث بالاسم أو الرتبة...' : 'Recherche par nom ou grade...',
                        hintStyle: const TextStyle(fontFamily: 'Tajawal', color: Colors.white38, fontSize: 11.5),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37), size: 17),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),

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

                              final name = (emp['name'] ?? emp['NomAr'] ?? emp['Nom'] ?? (loc.isArabic ? 'مفتش' : 'Agent')).toString();
                              final grade = (emp['grade'] ?? emp['Grade'] ?? (loc.isArabic ? 'مفتش رئيسي' : 'Inspecteur')).toString();
                              final service = (emp['service'] ?? emp['Service'] ?? '').toString();

                              final isHead = (insp.headEmpId != null && (emp['employeeId'] ?? emp['Id'] ?? emp['id']) == insp.headEmpId) ||
                                             (insp.headNameAr != null && insp.headNameAr!.isNotEmpty && name.contains(insp.headNameAr!));

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

                              return InkWell(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _showInspectorModal(emp);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isHead ? const Color(0xFF281133) : const Color(0xFF1F0D28),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isHead ? const Color(0xFFD4AF37) : statusColor.withValues(alpha: 0.3),
                                      width: isHead ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isHead
                                              ? const Color(0xFFD4AF37).withValues(alpha: 0.2)
                                              : statusColor.withValues(alpha: 0.15),
                                          border: Border.all(
                                            color: isHead ? const Color(0xFFD4AF37) : statusColor,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            isHead ? Icons.stars : statusIcon,
                                            color: isHead ? const Color(0xFFD4AF37) : statusColor,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    name,
                                                    style: TextStyle(
                                                      fontFamily: 'Tajawal',
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: isHead ? const Color(0xFFD4AF37) : Colors.white,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isHead) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFD4AF37),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      loc.isArabic ? 'مسؤول المفتشية' : 'Chef d\'inspection',
                                                      style: const TextStyle(
                                                        fontFamily: 'Tajawal',
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'الرتبة: $grade ${service.isNotEmpty ? '• $service' : ''}',
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
