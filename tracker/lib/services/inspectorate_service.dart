import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drh_setif_tracker/utils/constants.dart';
import 'package:drh_setif_tracker/services/api_service.dart';

class InspectorateService extends ChangeNotifier {
  static final InspectorateService instance = InspectorateService._internal();
  InspectorateService._internal();

  List<InspectorateHQ> _inspectorates = List.from(AppConstants.defaultInspectorates);
  bool _isInitialized = false;

  List<InspectorateHQ> get inspectorates => List.unmodifiable(_inspectorates);

  Future<void> initialize({ApiService? api}) async {
    if (_isInitialized) return;
    await loadInspectorates(api: api);
    _isInitialized = true;
  }

  Future<void> loadInspectorates({ApiService? api}) async {
    try {
      // 1. Try local SharedPreferences first for instant offline readiness
      final prefs = await SharedPreferences.getInstance();
      final localJson = prefs.getString('pref_custom_inspectorates');
      if (localJson != null && localJson.isNotEmpty) {
        final dynamic decoded = jsonDecode(localJson);
        if (decoded is List) {
          _inspectorates = decoded.map((m) => InspectorateHQ.fromJson(Map<String, dynamic>.from(m as Map))).toList();
          AppConstants.setDynamicInspectorates(_inspectorates);
          notifyListeners();
        }
      }

      // 2. Sync from backend settings if available
      if (api != null) {
        final settings = await api.getSettings();
        final remoteJson = settings['custom_inspectorates'];
        if (remoteJson != null && remoteJson.toString().isNotEmpty) {
          final dynamic decoded = jsonDecode(remoteJson.toString());
          if (decoded is List) {
            _inspectorates = decoded.map((m) => InspectorateHQ.fromJson(Map<String, dynamic>.from(m as Map))).toList();
            await prefs.setString('pref_custom_inspectorates', remoteJson.toString());
            AppConstants.setDynamicInspectorates(_inspectorates);
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading custom inspectorates: $e');
    }
  }

  Future<void> saveAllInspectorates(List<InspectorateHQ> list, {ApiService? api}) async {
    _inspectorates = List.from(list);
    AppConstants.setDynamicInspectorates(_inspectorates);
    notifyListeners();

    final jsonStr = jsonEncode(_inspectorates.map((e) => e.toJson()).toList());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pref_custom_inspectorates', jsonStr);
    } catch (_) {}

    if (api != null) {
      try {
        await api.updateSetting(
          'custom_inspectorates',
          jsonStr,
          description: 'إحداثيات ونطاقات المقرات والملحقات الإقليمية لولاية سطيف',
        );
      } catch (_) {}
    }
  }

  Future<void> updateInspectorate(InspectorateHQ item, {ApiService? api}) async {
    final index = _inspectorates.indexWhere((e) => e.id == item.id);
    if (index != -1) {
      _inspectorates[index] = item;
    } else {
      _inspectorates.add(item);
    }
    await saveAllInspectorates(_inspectorates, api: api);
  }

  Future<void> addInspectorate(InspectorateHQ item, {ApiService? api}) async {
    _inspectorates.add(item);
    await saveAllInspectorates(_inspectorates, api: api);
  }

  Future<void> deleteInspectorate(String id, {ApiService? api}) async {
    _inspectorates.removeWhere((e) => e.id == id);
    await saveAllInspectorates(_inspectorates, api: api);
  }

  Future<void> resetToDefaults({ApiService? api}) async {
    _inspectorates = List.from(AppConstants.defaultInspectorates);
    await saveAllInspectorates(_inspectorates, api: api);
  }
}
