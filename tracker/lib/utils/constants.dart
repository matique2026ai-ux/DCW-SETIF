import 'dart:math';

class InspectorateHQ {
  final String id;
  final String nameAr;
  final String nameFr;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool isMainDirectorate;

  const InspectorateHQ({
    required this.id,
    required this.nameAr,
    required this.nameFr,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 600.0,
    this.isMainDirectorate = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nameAr': nameAr,
    'nameFr': nameFr,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
    'isMainDirectorate': isMainDirectorate,
  };

  factory InspectorateHQ.fromJson(Map<String, dynamic> json) {
    return InspectorateHQ(
      id: json['id']?.toString() ?? 'insp_${DateTime.now().millisecondsSinceEpoch}',
      nameAr: json['nameAr']?.toString() ?? '',
      nameFr: json['nameFr']?.toString() ?? '',
      latitude: (json['latitude'] is num) ? (json['latitude'] as num).toDouble() : double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0,
      longitude: (json['longitude'] is num) ? (json['longitude'] as num).toDouble() : double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0,
      radiusMeters: (json['radiusMeters'] is num) ? (json['radiusMeters'] as num).toDouble() : double.tryParse(json['radiusMeters']?.toString() ?? '600') ?? 600.0,
      isMainDirectorate: json['isMainDirectorate'] == true,
    );
  }

  InspectorateHQ copyWith({
    String? id,
    String? nameAr,
    String? nameFr,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    bool? isMainDirectorate,
  }) {
    return InspectorateHQ(
      id: id ?? this.id,
      nameAr: nameAr ?? this.nameAr,
      nameFr: nameFr ?? this.nameFr,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      isMainDirectorate: isMainDirectorate ?? this.isMainDirectorate,
    );
  }
}

class AppConstants {
  static const String appName = 'DCW-SETIF-TRACKER';
  static const String appNameAr = 'منصة الرقابة والتفتيش الميداني';

  // Main Directorate HQ (مقر مديرية التجارة الداخلية وضبط السوق الوطنية لولاية سطيف — حي المعبودة، شارع جودي حمو)
  static const double hqLatitude = 36.1900575;
  static const double hqLongitude = 5.3990134;
  static const double hqRadiusMeters = 250.0;

  // Regional Inspectorates, Airport Border Inspectorate & Commercial Annexes of Setif Province (Default baseline)
  static const List<InspectorateHQ> defaultInspectorates = [
    InspectorateHQ(
      id: 'hq_setif',
      nameAr: 'المقر الرئيسي للمديرية الولائية (سطيف - المعبودة)',
      nameFr: 'Siège de la Direction de Wilaya (Sétif - El Maabouda)',
      latitude: 36.1900575,
      longitude: 5.3990134,
      radiusMeters: 250.0,
      isMainDirectorate: true,
    ),
    InspectorateHQ(
      id: 'insp_airport_arnat',
      nameAr: 'المفتشية الحدودية لمراقبة الجودة — مطار 8 ماي 1945 (عين أرنات)',
      nameFr: 'Inspection Frontalière — Aéroport 8 Mai 1945 (Aïn Arnat)',
      latitude: 36.1781,
      longitude: 5.3247,
      radiusMeters: 1200.0,
    ),
    InspectorateHQ(
      id: 'insp_eulma',
      nameAr: 'المفتشية الإقليمية للتجارة — العلمة',
      nameFr: 'Inspection Territoriale — El Eulma',
      latitude: 36.1554,
      longitude: 5.6908,
      radiusMeters: 1200.0,
    ),
    InspectorateHQ(
      id: 'insp_ain_oulmene',
      nameAr: 'المفتشية الإقليمية للتجارة — عين ولمان',
      nameFr: 'Inspection Territoriale — Aïn Oulmène',
      latitude: 35.9189,
      longitude: 5.2978,
      radiusMeters: 1200.0,
    ),
    InspectorateHQ(
      id: 'insp_bougaa',
      nameAr: 'المفتشية الإقليمية للتجارة — بوقاعة',
      nameFr: 'Inspection Territoriale — Bougaâ',
      latitude: 36.3325,
      longitude: 5.0886,
      radiusMeters: 1200.0,
    ),
    InspectorateHQ(
      id: 'annex_ain_azel',
      nameAr: 'الملحقة التجارية — عين آزال',
      nameFr: 'Annexe Commerciale — Aïn Azel',
      latitude: 35.8686,
      longitude: 5.4667,
      radiusMeters: 1000.0,
    ),
    InspectorateHQ(
      id: 'annex_ain_kebira',
      nameAr: 'الملحقة التجارية — عين الكبيرة',
      nameFr: 'Annexe Commerciale — Aïn El Kebira',
      latitude: 36.3639,
      longitude: 5.5003,
      radiusMeters: 1000.0,
    ),
    InspectorateHQ(
      id: 'annex_ain_arnat',
      nameAr: 'الملحقة التجارية — عين أرنات',
      nameFr: 'Annexe Commerciale — Aïn Arnat',
      latitude: 36.1833,
      longitude: 5.3167,
      radiusMeters: 1000.0,
    ),
  ];

  static List<InspectorateHQ> _dynamicInspectorates = List.from(defaultInspectorates);

  static List<InspectorateHQ> get allInspectorates => List.unmodifiable(_dynamicInspectorates);

  static void setDynamicInspectorates(List<InspectorateHQ> list) {
    _dynamicInspectorates = List.from(list);
  }

  // Work hours
  static const int workStartHour = 8;
  static const int workEndHour = 16;

  // GPS tracking interval
  static const int gpsTrackingIntervalMinutes = 15;

  // Distance between two GPS points in meters
  static double distanceBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371000;
    final double dLat = _toRad(lat2 - lat1);
    final double dLng = _toRad(lng2 - lng1);
    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  // Check if point is within main HQ radius
  static bool isWithinHQ(double lat, double lng) {
    return isWithinAnyHQ(lat, lng);
  }

  // Check if point is within any official HQ or regional inspectorate/annex
  static bool isWithinAnyHQ(double lat, double lng) {
    for (final insp in allInspectorates) {
      final distance = distanceBetween(lat, lng, insp.latitude, insp.longitude);
      if (distance <= insp.radiusMeters) return true;
    }
    return false;
  }

  // Find nearest inspectorate / HQ
  static InspectorateHQ findNearestHQ(double lat, double lng) {
    if (allInspectorates.isEmpty) {
      return defaultInspectorates.first;
    }
    InspectorateHQ nearest = allInspectorates.first;
    double minDistance = distanceBetween(lat, lng, nearest.latitude, nearest.longitude);

    for (final insp in allInspectorates) {
      final distance = distanceBetween(lat, lng, insp.latitude, insp.longitude);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = insp;
      }
    }
    return nearest;
  }

  // Get detected location label for attendance
  static String getDetectedLocationLabel(double lat, double lng) {
    final nearest = findNearestHQ(lat, lng);
    final distance = distanceBetween(lat, lng, nearest.latitude, nearest.longitude);
    if (distance <= nearest.radiusMeters) {
      return nearest.nameAr;
    }
    return 'مهمة ميدانية خارج المقرات (${nearest.nameAr} - ${distance.round()}م)';
  }

  static double _toRad(double deg) => deg * pi / 180;
}
