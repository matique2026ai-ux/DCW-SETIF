import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drh_setif_tracker/services/api_service.dart';
import 'package:drh_setif_tracker/utils/constants.dart';

class OfflineSyncService {
  static const String _pendingQueueKey = 'offline_pending_queue';
  static const String _cachedVisitsKey = 'offline_cached_visits';
  static const String _cachedAttendanceKey = 'offline_cached_attendance';

  // Add checkin to pending queue
  static Future<void> queueCheckIn(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await getPendingItems();
    final nowIso = DateTime.now().toIso8601String();
    final enrichedPayload = Map<String, dynamic>.from(payload);
    enrichedPayload['offlineTimestamp'] ??= nowIso;

    queue.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': 'checkin',
      'payload': enrichedPayload,
      'createdAt': nowIso,
    });
    await prefs.setString(_pendingQueueKey, jsonEncode(queue));

    // Cache local attendance state
    await prefs.setString(
      _cachedAttendanceKey,
      jsonEncode({
        'isCheckedIn': true,
        'checkInTime': DateTime.now().toString().substring(11, 16),
        'date': DateTime.now().toIso8601String().split('T')[0],
      }),
    );
  }

  // Add checkout to pending queue
  static Future<void> queueCheckOut(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await getPendingItems();
    queue.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': 'checkout',
      'payload': payload,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_pendingQueueKey, jsonEncode(queue));

    // Clear cached attendance
    await prefs.remove(_cachedAttendanceKey);
  }

  // Add visit to pending queue and local cached visits list
  static Future<void> queueVisit(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await getPendingItems();
    final nowIso = DateTime.now().toIso8601String();
    final enrichedPayload = Map<String, dynamic>.from(payload);
    enrichedPayload['visitTime'] ??= nowIso;

    queue.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': 'visit',
      'payload': enrichedPayload,
      'createdAt': nowIso,
    });
    await prefs.setString(_pendingQueueKey, jsonEncode(queue));

    // Also add to local cached visits for immediate UI display
    final cachedVisits = await getCachedVisits();
    cachedVisits.insert(0, {
      'Id': 'offline_${DateTime.now().millisecondsSinceEpoch}',
      'TraderName': payload['shopName'] ?? 'محل تجاري',
      'ActivityType': payload['shopType'] ?? 'تفتيش',
      'VisitTime': DateTime.now().toIso8601String(),
      'Notes': payload['notes'] ?? '',
      'IsOffline': true,
    });
    await prefs.setString(_cachedVisitsKey, jsonEncode(cachedVisits));
  }

  // Get all pending queue items
  static Future<List<Map<String, dynamic>>> getPendingItems() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_pendingQueueKey);
    if (str == null || str.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(str) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  // Get count of pending items
  static Future<int> getPendingCount() async {
    final items = await getPendingItems();
    return items.length;
  }

  // Get cached visits
  static Future<List<Map<String, dynamic>>> getCachedVisits() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_cachedVisitsKey);
    if (str == null || str.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(str) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  // Get cached attendance
  static Future<Map<String, dynamic>?> getCachedAttendance() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_cachedAttendanceKey);
    if (str == null || str.isEmpty) return null;
    try {
      final Map<String, dynamic> decoded = Map<String, dynamic>.from(jsonDecode(str) as Map);
      final today = DateTime.now().toIso8601String().split('T')[0];
      if (decoded['date'] == today) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Sync all pending items to server
  static Future<Map<String, dynamic>> syncAll(ApiService api) async {
    final pending = await getPendingItems();
    if (pending.isEmpty) {
      return {'success': true, 'syncedCount': 0, 'errors': []};
    }

    int syncedCount = 0;
    final List<Map<String, dynamic>> remaining = [];
    final List<String> errors = [];

    for (final item in pending) {
      final type = item['type'];
      final payload = Map<String, dynamic>.from((item['payload'] as Map?) ?? {});

      try {
        if (type == 'checkin') {
          final int empId = (payload['employeeId'] as num?)?.toInt() ?? 1;
          await api.checkIn(
            empId,
            latitude: (payload['latitude'] as num?)?.toDouble(),
            longitude: (payload['longitude'] as num?)?.toDouble(),
            photo: payload['photo'] as String?,
            location: payload['location'] as String?,
            notes: payload['notes'] as String?,
            deviceId: payload['deviceId'] as String?,
            offlineTimestamp: payload['offlineTimestamp'] as String? ?? item['createdAt'] as String?,
          );
          syncedCount++;
        } else if (type == 'checkout') {
          final int empId = (payload['employeeId'] as num?)?.toInt() ?? 1;
          await api.checkOut(
            empId,
            latitude: (payload['latitude'] as num?)?.toDouble(),
            longitude: (payload['longitude'] as num?)?.toDouble(),
            location: payload['location'] as String?,
            notes: payload['notes'] as String?,
            earlyReason: payload['earlyReason'] as String?,
            visitsCount: (payload['visitsCount'] as num?)?.toInt(),
          );
          syncedCount++;
        } else if (type == 'visit') {
          final double lat = (payload['latitude'] as num?)?.toDouble() ?? AppConstants.hqLatitude;
          final double lng = (payload['longitude'] as num?)?.toDouble() ?? AppConstants.hqLongitude;
          final int empId = (payload['employeeId'] as num?)?.toInt() ?? 1;
          await api.recordVisit(
            employeeId: empId,
            latitude: lat,
            longitude: lng,
            shopName: payload['shopName'] as String?,
            shopType: payload['shopType'] as String?,
            notes: payload['notes'] as String?,
            photo: payload['photo'] as String?,
            accuracy: (payload['accuracy'] as num?)?.toDouble(),
            locationName: payload['locationName'] as String?,
            violationFound: payload['violationFound'] == true,
            violationType: payload['violationType'] as String?,
            violationNotes: payload['violationNotes'] as String?,
            legalAction: payload['legalAction'] as String?,
            seizureValue: (payload['seizureValue'] as num?)?.toDouble(),
            visitTime: payload['visitTime'] as String? ?? item['createdAt'] as String?,
          );
          syncedCount++;
        }
      } catch (e) {
        final err = e.toString().toLowerCase();
        if (err.contains('بالفعل') || err.contains('already') || err.contains('مسبق') || err.contains('لم يسجل')) {
          // Record is already processed or expired on server; mark as resolved
          syncedCount++;
        } else {
          // Keep in queue if real network error
          remaining.add(item);
          errors.add('فشل مزامنة $type: $e');
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    if (remaining.isEmpty) {
      await prefs.remove(_pendingQueueKey);
    } else {
      await prefs.setString(_pendingQueueKey, jsonEncode(remaining));
    }

    return {
      'success': errors.isEmpty,
      'syncedCount': syncedCount,
      'remainingCount': remaining.length,
      'errors': errors,
    };
  }

  // Clear all cached local data
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingQueueKey);
    await prefs.remove(_cachedVisitsKey);
    await prefs.remove(_cachedAttendanceKey);
  }
}
