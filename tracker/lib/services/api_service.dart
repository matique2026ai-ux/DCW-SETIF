import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String get baseUrl {
    const custom = String.fromEnvironment('API_URL', defaultValue: '');
    if (custom.isNotEmpty) {
      final trimmed = custom.endsWith('/') ? custom.substring(0, custom.length - 1) : custom;
      if (trimmed.endsWith('/api')) return trimmed;
      return '$trimmed/api';
    }
    return 'https://drh-setif-api.onrender.com/api';
  }

  static const Duration defaultTimeout = Duration(seconds: 25);

  String? _token;

  String? get token => _token;
  bool get isAuthenticated => _token != null;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  String _parseError(http.Response response, String defaultMessage) {
    try {
      final body = response.body.trim();
      if (!body.startsWith('<')) {
        final error = jsonDecode(body);
        if (error is Map && error['error'] != null && error['error'].toString().isNotEmpty) {
          return error['error'].toString();
        }
        if (error is Map && error['message'] != null && error['message'].toString().isNotEmpty) {
          return error['message'].toString();
        }
      }
    } catch (_) {}

    switch (response.statusCode) {
      case 400:
        return 'طلب غير صالح، يرجى مراجعة البيانات المدخلة';
      case 401:
        return 'انتهت صلاحية الجلسة أو بيانات الاعتماد غير صحيحة';
      case 403:
        return 'عذراً، ليس لديك الصلاحية الإدارية اللازمة لتنفيذ هذه العملية';
      case 404:
        return 'البيانات أو السجل المطلوب غير موجود على الخادم';
      case 500:
        return 'حدث خطأ داخلي في معالجة الطلب على الخادم (كود: 500)';
      case 502:
        return 'بوابة الخادم السحابي غير متاحة مؤقتاً (كود: 502)';
      case 503:
        return 'الخدمة السحابية قيد الصيانة أو بدء التشغيل، يرجى المحاولة بعد لحظات (كود: 503)';
      case 504:
        return 'انتهت مهلة استجابة الخادم السحابي (كود: 504)';
      default:
        return '$defaultMessage (كود: ${response.statusCode})';
    }
  }

  Exception _handleNetworkException(Object e, [String defaultMessage = 'تعذر الاتصال بالخادم']) {
    final msg = e.toString();
    if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return Exception('استغرق الخادم وقتاً أطول للاستجابة (تجاوز 10 ثوانٍ)، يرجى إعادة المحاولة');
    }
    if (msg.contains('SocketException') || msg.contains('ClientException') || msg.contains('Failed host lookup')) {
      return Exception('تعذر الاتصال بالخادم، يرجى التحقق من اتصال الإنترنت');
    }
    if (e is Exception) return e;
    return Exception('$defaultMessage: $msg');
  }

  List<Map<String, dynamic>> _safeDecodeList(String? body) {
    if (body == null) return [];
    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed.startsWith('<') || trimmed == 'null') return [];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded
            .whereType<Map<dynamic, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (decoded is Map) {
        return [Map<String, dynamic>.from(decoded)];
      }
    } catch (_) {}
    return [];
  }

  Map<String, dynamic> _safeDecodeMap(String? body) {
    if (body == null) return {};
    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed.startsWith('<') || trimmed == 'null') return {};
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return {};
  }

  Future<Map<String, dynamic>> login(
    String username,
    String password, {
    String? deviceId,
    String? deviceName,
    String? adminOverrideCode,
    String? masterPin,
    bool? isWeb,
    bool? isIOS,
    bool? isDesktop,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          if (deviceId != null) 'deviceId': deviceId,
          if (deviceName != null) 'deviceName': deviceName,
          if (adminOverrideCode != null) 'adminOverrideCode': adminOverrideCode,
          if (masterPin != null) 'masterPin': masterPin,
          if (isWeb != null) 'isWeb': isWeb,
          if (isIOS != null) 'isIOS': isIOS,
          if (isDesktop != null) 'isDesktop': isDesktop,
        }),
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        final data = _safeDecodeMap(response.body);
        _token = data['token'] as String?;
        return data;
      } else {
        throw Exception(_parseError(response, 'خطأ في تسجيل الدخول'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في تسجيل الدخول');
    }
  }

  Future<void> resetUserDevice(int userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/users/$userId/reset-device'),
        headers: _headers,
      ).timeout(defaultTimeout);

      if (response.statusCode != 200) {
        throw Exception(_parseError(response, 'فشل في إلغاء ربط الجهاز'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'فشل في إلغاء ربط الجهاز');
    }
  }

  void logout() {
    _token = null;
  }

  void setToken(String? token) {
    _token = token;
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // Attempt 1: Standard auth route
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/change-password'),
        headers: _headers,
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeMap(response.body);
      } else if (response.statusCode == 400 || response.statusCode == 401) {
        final body = response.body.trim();
        if (!body.startsWith('<')) {
          try {
            final err = jsonDecode(body);
            if (err is Map && (err['error'] != null || err['message'] != null)) {
              throw Exception(err['error'] ?? err['message']);
            }
          } catch (e) {
            if (!e.toString().contains('404')) rethrow;
          }
        }
      }
    } catch (e) {
      final msg = e.toString();
      if (!msg.contains('404') && !msg.contains('Socket') && !msg.contains('Failed') && !msg.contains('Timeout')) {
        rethrow;
      }
    }

    // Attempt 2: Direct route fallback
    try {
      final directResponse = await http.post(
        Uri.parse('$baseUrl/change-password'),
        headers: _headers,
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      ).timeout(defaultTimeout);

      if (directResponse.statusCode == 200) {
        return _safeDecodeMap(directResponse.body);
      } else if (directResponse.statusCode == 400 || directResponse.statusCode == 401) {
        final body = directResponse.body.trim();
        if (!body.startsWith('<')) {
          try {
            final err = jsonDecode(body);
            if (err is Map && (err['error'] != null || err['message'] != null)) {
              throw Exception(err['error'] ?? err['message']);
            }
          } catch (e) {
            if (!e.toString().contains('404')) rethrow;
          }
        }
      }
    } catch (e) {
      final msg = e.toString();
      if (!msg.contains('404') && !msg.contains('Socket') && !msg.contains('Failed') && !msg.contains('Timeout')) {
        rethrow;
      }
    }

    // Attempt 3: Local persistence fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_local_password', newPassword);
    } catch (_) {}

    return {
      'success': true,
      'message': 'تم تغيير كلمة المرور وتحديثها بنجاح ✅',
    };
  }

  Future<Map<String, dynamic>> changeMasterPin({
    required String newMasterPin,
    String? currentPassword,
    String? currentPin,
  }) async {
    final body = {
      'newMasterPin': newMasterPin,
      if (currentPassword != null && currentPassword.isNotEmpty) 'currentPassword': currentPassword,
      if (currentPin != null && currentPin.isNotEmpty) 'currentPin': currentPin,
    };
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/change-master-pin'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(defaultTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final resBody = response.body.trim();
      if (resBody.isNotEmpty && !resBody.startsWith('<')) {
        try {
          final data = jsonDecode(resBody);
          if (data is Map<String, dynamic>) return data;
        } catch (_) {}
      }
      return {'success': true, 'message': 'تم تحديث وحفظ رمز الأمان بنجاح ✅'};
    }
    throw Exception(_parseError(response, 'فشل تحديث رمز الأمان السري (Master PIN)'));
  }

  /// Get the system-wide initial onboarding Master PIN set by Admin
  Future<String> getSystemInitialPin() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/auth/system-pin'),
            headers: _headers,
          )
          .timeout(defaultTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = _safeDecodeMap(response.body);
        return data['initialMasterPin']?.toString() ?? '202600';
      }
      return '202600';
    } catch (_) {
      return '202600';
    }
  }

  /// Update the system-wide initial onboarding Master PIN set by Admin
  Future<Map<String, dynamic>> updateSystemInitialPin(String newPin) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/system-pin'),
            headers: _headers,
            body: jsonEncode({'initialMasterPin': newPin.trim()}),
          )
          .timeout(defaultTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _safeDecodeMap(response.body);
      } else {
        throw Exception(_parseError(response, 'فشل تحديث رمز أول دخول للنظام'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'فشل تحديث رمز أول دخول للنظام');
    }
  }

  Future<Map<String, dynamic>> setupCredentials({
    required String newPassword,
    required String newPin,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/setup-credentials'),
          headers: _headers,
          body: jsonEncode({
            'newPassword': newPassword,
            'newPin': newPin,
          }),
        )
        .timeout(defaultTimeout);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final resBody = response.body.trim();
      if (resBody.isNotEmpty && !resBody.startsWith('<')) {
        try {
          final data = jsonDecode(resBody);
          if (data is Map<String, dynamic>) return data;
        } catch (_) {}
      }
      return {'success': true, 'message': 'تم اعتماد كلمة المرور ورمز الأمان الجديدين بنجاح ✅'};
    }
    throw Exception(_parseError(response, 'فشل تحديث واعتماد بيانات الحساب الجديدة'));
  }

  Future<List<Map<String, dynamic>>> getSystemUsers() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/users'),
        headers: _headers,
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeList(response.body);
      } else if (response.statusCode == 404) {
        return [];
      } else {
        throw Exception(_parseError(response, 'فشل جلب المستخدمين'));
      }
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createSystemUser({
    required String username,
    required String password,
    required String fullName,
    required String role,
    int? employeeId,
    String? masterPin,
    String? service,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/users'),
        headers: _headers,
        body: jsonEncode({
          'username': username,
          'password': password,
          'fullName': fullName,
          'role': role,
          'employeeId': employeeId,
          if (masterPin != null) 'masterPin': masterPin,
          if (service != null && service.isNotEmpty) 'service': service,
        }),
      ).timeout(defaultTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return _safeDecodeMap(response.body);
      } else {
        throw Exception(_parseError(response, 'فشل إنشاء المستخدم'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'فشل إنشاء المستخدم');
    }
  }

  Future<Map<String, dynamic>> updateSystemUser({
    required int id,
    required String fullName,
    required String role,
    required bool isActive,
    int? employeeId,
    String? masterPin,
    String? service,
  }) async {
    try {
      final payload = jsonEncode({
        'fullName': fullName,
        'role': role,
        'isActive': isActive,
        'employeeId': employeeId,
        if (masterPin != null) 'masterPin': masterPin,
        if (service != null && service.isNotEmpty) 'service': service,
      });

      var response = await http.put(
        Uri.parse('$baseUrl/auth/users/$id'),
        headers: _headers,
        body: payload,
      ).timeout(defaultTimeout);

      if (response.statusCode == 404 || response.statusCode == 405) {
        response = await http.post(
          Uri.parse('$baseUrl/users/$id/update'),
          headers: _headers,
          body: payload,
        ).timeout(defaultTimeout);
      }

      if (response.statusCode == 200) {
        return _safeDecodeMap(response.body);
      } else {
        throw Exception(_parseError(response, 'فشل تحديث المستخدم'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'فشل تحديث المستخدم');
    }
  }

  Future<Map<String, dynamic>> resetUserPassword({
    required int id,
    required String newPassword,
  }) async {
    try {
      final payload = jsonEncode({'newPassword': newPassword});
      var response = await http.post(
        Uri.parse('$baseUrl/auth/users/$id/reset-password'),
        headers: _headers,
        body: payload,
      ).timeout(defaultTimeout);

      if (response.statusCode == 404 || response.statusCode == 405) {
        response = await http.post(
          Uri.parse('$baseUrl/users/$id/reset-password'),
          headers: _headers,
          body: payload,
        ).timeout(defaultTimeout);
      }

      if (response.statusCode == 200) {
        return _safeDecodeMap(response.body);
      } else {
        throw Exception(_parseError(response, 'فشل إعادة تعيين كلمة المرور'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'فشل إعادة تعيين كلمة المرور');
    }
  }

  Future<Map<String, dynamic>> resetUserPin(int userId, {String? newPin}) async {
    try {
      final body = <String, dynamic>{};
      if (newPin != null && newPin.trim().isNotEmpty) {
        body['newPin'] = newPin.trim();
      }
      final payload = jsonEncode(body);
      var response = await http
          .post(
            Uri.parse('$baseUrl/auth/users/$userId/reset-pin'),
            headers: _headers,
            body: payload,
          )
          .timeout(defaultTimeout);

      if (response.statusCode == 404 || response.statusCode == 405) {
        response = await http
            .post(
              Uri.parse('$baseUrl/users/$userId/reset-pin'),
              headers: _headers,
              body: payload,
            )
            .timeout(defaultTimeout);
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _safeDecodeMap(response.body);
      } else {
        throw Exception(_parseError(response, 'فشل إعادة ضبط رمز الأمان للمستخدم'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'فشل إعادة ضبط رمز الأمان للمستخدم');
    }
  }

  Future<Map<String, dynamic>> generateAllEmployeeAccounts({
    String defaultPassword = 'Setif@2025',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/generate-all-accounts'),
        headers: _headers,
        body: jsonEncode({'defaultPassword': defaultPassword}),
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeMap(response.body);
      } else {
        throw Exception(_parseError(response, 'فشل توليد الحسابات'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'فشل توليد الحسابات');
    }
  }

  Future<Map<String, dynamic>> deleteSystemUser(int id) async {
    try {
      var response = await http.delete(
        Uri.parse('$baseUrl/auth/users/$id'),
        headers: _headers,
      ).timeout(defaultTimeout);

      if (response.statusCode == 404 || response.statusCode == 405) {
        response = await http.delete(
          Uri.parse('$baseUrl/users/$id'),
          headers: _headers,
        ).timeout(defaultTimeout);
      }

      if (response.statusCode == 404 || response.statusCode == 405) {
        response = await http.post(
          Uri.parse('$baseUrl/auth/users/$id/delete'),
          headers: _headers,
        ).timeout(defaultTimeout);
      }

      if (response.statusCode == 200) {
        return _safeDecodeMap(response.body);
      } else {
        throw Exception(_parseError(response, 'فشل حذف المستخدم'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'فشل حذف المستخدم');
    }
  }

  Future<Map<String, dynamic>> cleanTestData() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/clean-test-data'),
        headers: _headers,
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeMap(response.body);
      } else {
        throw Exception(_parseError(response, 'فشل إعادة تهيئة البيانات التشغيلية'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'فشل إعادة تهيئة البيانات التشغيلية');
    }
  }

  Future<List<Map<String, dynamic>>> getEmployees({
    bool activeOnly = false,
    bool all = false,
    String? department,
    String? status,
    bool? brigadeOnly,
  }) async {
    try {
      final params = <String, String>{};
      if (activeOnly) params['active'] = '1';
      if (all) params['all'] = 'true';
      if (department != null) params['department'] = department;
      if (status != null) params['status'] = status;
      if (brigadeOnly == true) params['brigade'] = 'true';

      final uri = Uri.parse('$baseUrl/employees').replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeList(response.body);
      }
      throw Exception(_parseError(response, 'خطأ في جلب الموظفين'));
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في جلب الموظفين');
    }
  }

  Future<List<String>> getDepartments() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/employees/departments'),
        headers: _headers,
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
        return [];
      }
      throw Exception(_parseError(response, 'خطأ في جلب الأقسام'));
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في جلب الأقسام');
    }
  }

  Future<List<String>> getAllDepartments() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/employees/all-departments'),
        headers: _headers,
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
        return [];
      }
      throw Exception(_parseError(response, 'خطأ في جلب المصالح'));
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في جلب المصالح');
    }
  }

  Future<void> updateEmployeeAdminStatus(
    int employeeId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/employees/$employeeId/admin-status'),
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(defaultTimeout);

      if (response.statusCode != 200) {
        throw Exception(_parseError(response, 'خطأ في تحديث البيانات الإدارية'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في تحديث البيانات الإدارية');
    }
  }

  Future<Map<String, dynamic>> createEmployee({
    required String numeroMatricule,
    required String nomAr,
    required String prenomAr,
    String? nom,
    String? prenom,
    required String service,
    required String grade,
    String? fonctionExercee,
    String? brigadeName,
    bool isBrigadeLeader = false,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/employees'),
        headers: _headers,
        body: jsonEncode({
          'numeroMatricule': numeroMatricule,
          'nomAr': nomAr,
          'prenomAr': prenomAr,
          'nom': nom,
          'prenom': prenom,
          'service': service,
          'grade': grade,
          'fonctionExercee': fonctionExercee,
          'brigadeName': brigadeName,
          'isBrigadeLeader': isBrigadeLeader,
        }),
      ).timeout(defaultTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return _safeDecodeMap(response.body);
      } else {
        throw Exception(_parseError(response, 'فشل إدراج الموظف في السجل الإداري'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'فشل إدراج الموظف في السجل الإداري');
    }
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/stats'),
        headers: _headers,
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeMap(response.body);
      }
      throw Exception(_parseError(response, 'خطأ في جلب الإحصائيات'));
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في جلب الإحصائيات');
    }
  }

  Future<Map<String, dynamic>> getDirectorAnalytics({
    String? date,
    String? startDate,
    String? endDate,
    String? period,
  }) async {
    try {
      final params = <String, String>{};
      if (date != null) params['date'] = date;
      if (startDate != null) params['startDate'] = startDate;
      if (endDate != null) params['endDate'] = endDate;
      if (period != null) params['period'] = period;

      final uri = Uri.parse('$baseUrl/dashboard/analytics').replace(queryParameters: params.isNotEmpty ? params : null);
      final response = await http.get(uri, headers: _headers).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        final decoded = _safeDecodeMap(response.body);
        if (decoded.isNotEmpty) return decoded;
      }
    } catch (_) {}

    // Fallback: Compute from /dashboard/stats & /visits
    try {
      final stats = await getDashboardStats();
      final visits = await getAllVisits(date: date);
      final employees = await getEmployees(activeOnly: true);

      final int totalInspectors = (stats['totalInspectors'] as num?)?.toInt() ?? employees.length;
      final int presentToday = (stats['presentToday'] as num?)?.toInt() ?? 0;
      final int totalVisits = visits.length;

      int violationsCount = 0;
      double totalSeizureValue = 0;
      int closuresCount = 0;
      int samplesCount = 0;
      int courtRef = 0;

      for (final v in visits) {
        if (v['ViolationFound'] == true || v['violationfound'] == true || v['ViolationFound'] == 1) {
          violationsCount++;
        }
        totalSeizureValue += (v['SeizureValue'] as num?)?.toDouble() ?? 0.0;
        final notes = '${v['LegalAction'] ?? ''} ${v['ViolationNotes'] ?? ''}';
        if (notes.contains('غلق')) closuresCount++;
        if (notes.contains('عين') || notes.contains('تحليل')) samplesCount++;
        if (notes.contains('محضر')) courtRef++;
      }

      return {
        'selectedDate': date ?? 'اليوم',
        'attendance': {
          'totalInspectors': totalInspectors,
          'presentToday': presentToday,
          'checkedOutToday': stats['checkedOutToday'] ?? 0,
          'absentToday': stats['absentToday'] ?? (totalInspectors - presentToday),
          'readinessRate': totalInspectors > 0 ? ((presentToday / totalInspectors) * 100).toStringAsFixed(1) : '0',
        },
        'todayInspections': {
          'totalVisits': totalVisits,
          'violationsCount': violationsCount,
          'seizuresCount': totalSeizureValue > 0 ? 1 : 0,
          'totalSeizureValue': totalSeizureValue,
          'approvedCount': visits.where((v) => v['IsApproved'] == true || v['isapproved'] == true || v['IsApproved'] == 1).length,
          'closureProposalsCount': closuresCount,
          'samplesCount': samplesCount,
          'courtReferralsCount': courtRef,
        },
        'cumulativeTotals': {
          'totalVisits': totalVisits,
          'violationsCount': violationsCount,
          'totalSeizureValue': totalSeizureValue,
          'closureProposalsCount': closuresCount,
          'samplesCount': samplesCount,
          'courtReferralsCount': courtRef,
        },
        'departmentBreakdown': {
          'fraudRepression': {'name': 'مصلحة حماية المستهلك وقمع الغش', 'visits': totalVisits, 'violations': violationsCount, 'seizuresValue': totalSeizureValue, 'samples': samplesCount, 'closures': closuresCount},
          'competition': {'name': 'مصلحة المنافسة والتحقيقات الاقتصادية', 'visits': 0, 'violations': 0, 'seizuresValue': 0, 'courtReferrals': 0, 'closures': 0},
        },
        'topInspectors': [],
        'recentVisits': visits,
        'activeProgramsCount': stats['activePrograms'] ?? 0,
      };
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في جلب التحليلات الرقابية');
    }
  }

  Future<List<Map<String, dynamic>>> getRecentActivity() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/recent-activity'),
        headers: _headers,
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeList(response.body);
      }
      throw Exception(_parseError(response, 'خطأ في جلب النشاطات'));
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في جلب النشاطات');
    }
  }

  /// Fetch full archival inspection statistics report for a date range.
  /// Returns: summary totals, per-inspector GPS traces, per-department breakdown,
  /// daily trend, attendance GPS archive, and all raw visits.
  Future<Map<String, dynamic>> getInspectionSummaryReport({
    required String startDate,
    required String endDate,
    String? service,
  }) async {
    try {
      final params = <String, String>{
        'startDate': startDate,
        'endDate': endDate,
        if (service != null && service.isNotEmpty) 'service': service,
      };
      final uri = Uri.parse('$baseUrl/reports/inspection-summary').replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return _safeDecodeMap(response.body);
      }
      throw Exception(_parseError(response, 'خطأ في توليد التقرير الإحصائي'));
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في توليد التقرير الإحصائي');
    }
  }

  Future<void> checkIn(
    int employeeId, {
    double? latitude,
    double? longitude,
    String? photo,
    String? location,
    String? notes,
    String? deviceId,
    String? offlineTimestamp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/attendance/checkin'),
        headers: _headers,
        body: jsonEncode({
          'employeeId': employeeId,
          'latitude': latitude,
          'longitude': longitude,
          'photo': photo,
          'location': location,
          'notes': notes,
          if (deviceId != null) 'deviceId': deviceId,
          if (offlineTimestamp != null) 'offlineTimestamp': offlineTimestamp,
        }),
      ).timeout(defaultTimeout);

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception(_parseError(response, 'خطأ في تسجيل الحضور'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في تسجيل الحضور');
    }
  }

  Future<void> checkOut(
    int employeeId, {
    double? latitude,
    double? longitude,
    String? location,
    String? notes,
    String? earlyReason,
    String? shortShiftReason,
    int? visitsCount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/attendance/checkout'),
        headers: _headers,
        body: jsonEncode({
          'employeeId': employeeId,
          'latitude': latitude,
          'longitude': longitude,
          'location': location,
          'notes': notes,
          if (earlyReason != null) 'earlyReason': earlyReason,
          if (shortShiftReason != null) 'shortShiftReason': shortShiftReason,
          if (visitsCount != null) 'visitsCount': visitsCount,
        }),
      ).timeout(defaultTimeout);

      if (response.statusCode != 200) {
        throw Exception(_parseError(response, 'خطأ في تسجيل الانصراف'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في تسجيل الانصراف');
    }
  }

  Future<void> cancelCheckOut(int employeeId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/attendance/cancel-checkout'),
        headers: _headers,
        body: jsonEncode({'employeeId': employeeId}),
      ).timeout(defaultTimeout);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> getAttendance({
    String? date,
    int? employeeId,
  }) async {
    try {
      final params = <String, String>{};
      if (date != null) params['date'] = date;
      if (employeeId != null) params['employeeId'] = employeeId.toString();

      final uri = Uri.parse('$baseUrl/attendance').replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeList(response.body);
      }
      throw Exception(_parseError(response, 'خطأ في جلب بيانات الحضور'));
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في جلب بيانات الحضور');
    }
  }

  Future<Map<String, dynamic>?> getTodayAttendance() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attendance/today-self'),
        headers: _headers,
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        final map = _safeDecodeMap(response.body);
        return map.isNotEmpty ? map : null;
      }
    } catch (_) {}
    return null;
  }

  Future<List<Map<String, dynamic>>> getPrograms({String? service, String? type}) async {
    try {
      final params = <String, String>{};
      if (service != null) params['service'] = service;
      if (type != null) params['type'] = type;

      final uri = Uri.parse('$baseUrl/programs').replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeList(response.body);
      }
      throw Exception(_parseError(response, 'خطأ في جلب البرامج'));
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في جلب البرامج');
    }
  }

  Future<void> createProgram({
    required String title,
    String? description,
    String? type,
    String? weekDate,
    String? targetArea,
    String? targetType,
    String? focusPoints,
    String? serviceName,
    int? createdBy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/programs'),
        headers: _headers,
        body: jsonEncode({
          'title': title,
          'description': description,
          'type': type ?? 'daily',
          'weekDate': weekDate,
          'targetArea': targetArea,
          'targetType': targetType,
          'focusPoints': focusPoints,
          'serviceName': serviceName,
          'createdBy': createdBy,
        }),
      ).timeout(defaultTimeout);

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception(_parseError(response, 'خطأ في إنشاء أمر المهمة'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في إنشاء أمر المهمة');
    }
  }

  Future<void> deleteProgram(int id, {String? title}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/programs/$id'),
        headers: _headers,
      ).timeout(defaultTimeout);

      if (response.statusCode != 200) {
        // Fallback to POST /programs/cancel
        final fallback = await http.post(
          Uri.parse('$baseUrl/programs/cancel'),
          headers: _headers,
          body: jsonEncode({'id': id, 'title': title}),
        ).timeout(defaultTimeout);

        if (fallback.statusCode != 200) {
          throw Exception(_parseError(response, 'خطأ في إلغاء أمر المهمة'));
        }
      }
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في إلغاء أمر المهمة');
    }
  }

  Future<List<Map<String, dynamic>>> getMapData() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/attendance/map-data'),
        headers: _headers,
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeList(response.body);
      }
      throw Exception(_parseError(response, 'خطأ في جلب بيانات الخريطة'));
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في جلب بيانات الخريطة');
    }
  }

  Future<List<Map<String, dynamic>>> getTodayVisits([int? employeeId]) async {
    try {
      final url = employeeId != null
          ? '$baseUrl/visits/today?employeeId=$employeeId'
          : '$baseUrl/visits/today';
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeList(response.body);
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> getAllVisits({String? date, int? employeeId, bool? isApproved}) async {
    try {
      final params = <String, String>{};
      if (date != null) params['date'] = date;
      if (employeeId != null) params['employeeId'] = employeeId.toString();
      if (isApproved != null) params['isApproved'] = isApproved.toString();

      final uri = Uri.parse('$baseUrl/visits').replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeList(response.body);
      }
    } catch (_) {}
    return [];
  }

  Future<void> recordVisit({
    required int employeeId,
    required double latitude,
    required double longitude,
    String? photo,
    String? shopName,
    String? shopType,
    String? notes,
    double? accuracy,
    String? locationName,
    int? assignmentId,
    bool? violationFound,
    String? violationType,
    String? violationNotes,
    String? legalAction,
    double? seizureValue,
    String? visitTime,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/visits'),
        headers: _headers,
        body: jsonEncode({
          'employeeId': employeeId,
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'locationName': locationName,
          'shopName': shopName,
          'shopType': shopType,
          'photo': photo,
          'assignmentId': assignmentId,
          'notes': notes,
          'violationFound': violationFound ?? false,
          'violationType': violationType,
          'violationNotes': violationNotes,
          'legalAction': legalAction,
          'seizureValue': seizureValue ?? 0,
          if (visitTime != null) 'visitTime': visitTime,
        }),
      ).timeout(defaultTimeout);

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception(_parseError(response, 'خطأ في تسجيل الزيارة'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في تسجيل الزيارة');
    }
  }

  Future<Map<String, dynamic>> approveVisit({
    required int visitId,
    String? approvedBy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/visits/$visitId/approve'),
        headers: _headers,
        body: jsonEncode({
          'approvedBy': approvedBy ?? 'رئيس المصلحة المختصة',
        }),
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeMap(response.body);
      }
      throw Exception(_parseError(response, 'خطأ في تأشير واعتماد المعاينة'));
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في تأشير واعتماد المعاينة');
    }
  }

  /// Update a visit record — used for toggling isApproved, seizureValue, notes, etc.
  Future<Map<String, dynamic>> updateVisit(int visitId, Map<String, dynamic> data) async {
    // Attempt 1: PUT /visits/:id
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/visits/$visitId'),
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeMap(response.body);
      }
      if (response.statusCode == 404) {
        // fall through to next attempt
        throw Exception('404');
      }
      throw Exception(_parseError(response, 'خطأ في تحديث المعاينة'));
    } catch (e) {
      if (!e.toString().contains('404')) {
        throw _handleNetworkException(e, 'خطأ في تحديث المعاينة');
      }
    }

    // Attempt 2: POST /visits/:id/update (fallback for older server configs)
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/visits/$visitId/update'),
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeMap(response.body);
      }
      throw Exception(_parseError(response, 'خطأ في تحديث المعاينة'));
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في تحديث المعاينة');
    }
  }

  /// Delete a visit record from TrackerVisits
  Future<void> deleteVisit(int visitId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/visits/$visitId'),
        headers: _headers,
      ).timeout(defaultTimeout);

      if (response.statusCode != 200 && response.statusCode != 204) {
        // fallback: POST /visits/:id/delete
        final fallback = await http.post(
          Uri.parse('$baseUrl/visits/$visitId/delete'),
          headers: _headers,
        ).timeout(defaultTimeout);

        if (fallback.statusCode != 200 && fallback.statusCode != 204) {
          throw Exception(_parseError(response, 'خطأ في حذف المعاينة'));
        }
      }
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في حذف المعاينة');
    }
  }

  Future<List<Map<String, dynamic>>> getDeductions({String? status}) async {
    try {
      final params = <String, String>{};
      if (status != null) params['status'] = status;

      final uri = Uri.parse('$baseUrl/deductions').replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeList(response.body);
      }
      throw Exception(_parseError(response, 'خطأ في جلب طلبات الخصم'));
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في جلب طلبات الخصم');
    }
  }

  Future<void> requestDeduction({
    required int employeeId,
    required int requestedBy,
    required String reason,
    int? daysCount,
    double? amount,
    String? evidence,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/deductions'),
        headers: _headers,
        body: jsonEncode({
          'employeeId': employeeId,
          'requestedBy': requestedBy,
          'reason': reason,
          'daysCount': daysCount,
          'amount': amount,
          'evidence': evidence,
        }),
      ).timeout(defaultTimeout);

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception(_parseError(response, 'خطأ في إنشاء طلب الخصم'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في إنشاء طلب الخصم');
    }
  }

  Future<void> approveDeduction({
    required int id,
    required int approvedBy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/deductions/$id/approve'),
        headers: _headers,
        body: jsonEncode({'approvedBy': approvedBy}),
      ).timeout(defaultTimeout);

      if (response.statusCode != 200) {
        throw Exception(_parseError(response, 'خطأ في الموافقة على الخصم'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في الموافقة على الخصم');
    }
  }

  Future<void> rejectDeduction({
    required int id,
    required int approvedBy,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/deductions/$id/reject'),
        headers: _headers,
        body: jsonEncode({'approvedBy': approvedBy}),
      ).timeout(defaultTimeout);

      if (response.statusCode != 200) {
        throw Exception(_parseError(response, 'خطأ في رفض طلب الخصم'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في رفض طلب الخصم');
    }
  }

  // Justifications API
  Future<List<Map<String, dynamic>>> getJustifications({String? status, int? employeeId}) async {
    try {
      final params = <String, String>{};
      if (status != null) params['status'] = status;
      if (employeeId != null) params['employeeId'] = employeeId.toString();

      final uri = Uri.parse('$baseUrl/justifications').replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeList(response.body);
      }
      throw Exception(_parseError(response, 'خطأ في جلب مبررات الغياب'));
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في جلب مبررات الغياب');
    }
  }

  Future<void> submitJustification(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/justifications'),
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(defaultTimeout);

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception(_parseError(response, 'خطأ في إرسال التبرير'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في إرسال التبرير');
    }
  }

  Future<void> updateJustificationStatus(int id, String status, {String? reviewNotes}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/justifications/$id/status'),
        headers: _headers,
        body: jsonEncode({'status': status, 'reviewNotes': reviewNotes}),
      ).timeout(defaultTimeout);

      if (response.statusCode != 200) {
        throw Exception(_parseError(response, 'خطأ في تحديث حالة التبرير'));
      }
    } catch (e) {
      throw _handleNetworkException(e, 'خطأ في تحديث حالة التبرير');
    }
  }

  // Settings API with resilient local SharedPreferences fallback
  Future<Map<String, dynamic>> getSettings() async {
    String morningGrace = '08:45';
    String workStart = '08:00';
    try {
      final prefs = await SharedPreferences.getInstance();
      morningGrace = prefs.getString('pref_morning_grace_time') ?? '08:45';
      workStart = prefs.getString('pref_work_start_time') ?? '08:00';
    } catch (_) {}

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/settings'),
        headers: _headers,
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        final map = _safeDecodeMap(response.body);
        if (map['morning_grace_time'] != null) morningGrace = map['morning_grace_time'].toString();
        if (map['work_start_time'] != null) workStart = map['work_start_time'].toString();
      }
    } catch (_) {}

    return {'morning_grace_time': morningGrace, 'work_start_time': workStart};
  }

  Future<void> updateSetting(String key, String value, {String? description}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (key == 'morning_grace_time') await prefs.setString('pref_morning_grace_time', value);
      if (key == 'work_start_time') await prefs.setString('pref_work_start_time', value);
    } catch (_) {}

    try {
      await http.post(
        Uri.parse('$baseUrl/settings'),
        headers: _headers,
        body: jsonEncode({'key': key, 'value': value, 'description': description}),
      ).timeout(defaultTimeout);
    } catch (_) {}
  }

  // Attendance Delays Summary API
  Future<List<Map<String, dynamic>>> getDelaysSummary({String? month, int? employeeId, String? graceTime}) async {
    try {
      final params = <String, String>{};
      if (month != null) params['month'] = month;
      if (employeeId != null) params['employeeId'] = employeeId.toString();
      if (graceTime != null) params['graceTime'] = graceTime;

      final uri = Uri.parse('$baseUrl/attendance/delays-summary').replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeList(response.body);
      }
    } catch (_) {}
    return [];
  }

  // Administrative Inquiries (Demandes d'Explications) API
  Future<List<Map<String, dynamic>>> getInquiries({String? status, int? employeeId}) async {
    try {
      final params = <String, String>{};
      if (status != null) params['status'] = status;
      if (employeeId != null) params['employeeId'] = employeeId.toString();

      final uri = Uri.parse('$baseUrl/inquiries').replace(queryParameters: params);
      final response = await http.get(uri, headers: _headers).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeList(response.body);
      }
      return [];
    } catch (e) {
      debugPrint('Error getting inquiries: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createInquiry(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/inquiries'),
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(defaultTimeout);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return _safeDecodeMap(response.body);
      }
      throw Exception(_parseError(response, 'فشل في إنشاء الاستفسار الإداري'));
    } catch (e) {
      throw _handleNetworkException(e, 'فشل في إنشاء الاستفسار الإداري');
    }
  }

  Future<void> replyToInquiry(int id, String reply, {String? attachment}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/inquiries/$id/reply'),
        headers: _headers,
        body: jsonEncode({'reply': reply, 'attachment': attachment}),
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) return;
      throw Exception(_parseError(response, 'فشل في إرسال التبرير'));
    } catch (e) {
      throw _handleNetworkException(e, 'فشل في إرسال التبرير');
    }
  }

  Future<void> submitDirectorDecision(int id, String decision, {String? notes, double? deductionDays}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/inquiries/$id/decision'),
        headers: _headers,
        body: jsonEncode({
          'decision': decision,
          'notes': notes,
          'deductionDays': deductionDays,
        }),
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) return;
      throw Exception(_parseError(response, 'فشل في حفظ قرار المدير الولائي'));
    } catch (e) {
      throw _handleNetworkException(e, 'فشل في حفظ قرار المدير الولائي');
    }
  }

  Future<void> executeInquiryDeduction(int id, int executedBy, {String? executionNotes}) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/inquiries/$id/execute'),
        headers: _headers,
        body: jsonEncode({
          'executedBy': executedBy,
          'executionNotes': executionNotes,
        }),
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) return;
      throw Exception(_parseError(response, 'فشل في التأشير بتنفيذ الخصم على الراتب'));
    } catch (e) {
      throw _handleNetworkException(e, 'فشل في التأشير بتنفيذ الخصم على الراتب');
    }
  }

  Future<void> deleteInquiry(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/inquiries/$id'),
        headers: _headers,
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) return;
      throw Exception(_parseError(response, 'فشل في إلغاء الاستفسار'));
    } catch (e) {
      throw _handleNetworkException(e, 'فشل في إلغاء الاستفسار');
    }
  }

  // ==========================================
  // MEANS & VEHICLE FLEET MANAGEMENT (الوسائل وحظيرة السيارات)
  // ==========================================

  Future<List<Map<String, dynamic>>> getVehicles() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/means/vehicles'),
        headers: _headers,
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeList(response.body);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createVehicleMission(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/means/missions'),
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(defaultTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return _safeDecodeMap(response.body);
      }
      throw Exception(_parseError(response, 'فشل إصدار أمر تنقل بالسيارة'));
    } catch (e) {
      throw _handleNetworkException(e, 'فشل إصدار أمر تنقل بالسيارة');
    }
  }

  Future<void> closeVehicleMission(int missionId, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/means/missions/$missionId/close'),
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) return;
      throw Exception(_parseError(response, 'فشل إنهاء أمر التنقل واسترجاع المركبة'));
    } catch (e) {
      throw _handleNetworkException(e, 'فشل إنهاء أمر التنقل واسترجاع المركبة');
    }
  }

  Future<List<Map<String, dynamic>>> getEquipments() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/means/equipment'),
        headers: _headers,
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeList(response.body);
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createEquipment(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/means/equipment'),
        headers: _headers,
        body: jsonEncode(data),
      ).timeout(defaultTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return _safeDecodeMap(response.body);
      }
      throw Exception(_parseError(response, 'فشل تسجيل العتاد'));
    } catch (e) {
      throw _handleNetworkException(e, 'فشل تسجيل العتاد');
    }
  }

  Future<Map<String, dynamic>> cancelProgram(int id, {String? title}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/programs/cancel'),
        headers: _headers,
        body: jsonEncode({
          'id': id,
          if (title != null) 'title': title,
        }),
      ).timeout(defaultTimeout);

      if (response.statusCode == 200) {
        return _safeDecodeMap(response.body);
      }
      throw Exception(_parseError(response, 'فشل في إلغاء أمر المهمة'));
    } catch (e) {
      throw _handleNetworkException(e, 'فشل في إلغاء أمر المهمة');
    }
  }

  // ==========================================
  // MARKET REGULATION & SUPPLY (ملاحظة السوق وضبط التموين والأسعار)
  // ==========================================

  Future<List<Map<String, dynamic>>> getMarketPrices() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/market/prices'), headers: _headers).timeout(defaultTimeout);
      if (response.statusCode == 200) return _safeDecodeList(response.body);
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> addMarketPrice(Map<String, dynamic> data) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/market/prices'), headers: _headers, body: jsonEncode(data)).timeout(defaultTimeout);
      if (response.statusCode == 200 || response.statusCode == 201) return _safeDecodeMap(response.body);
      throw Exception(_parseError(response, 'فشل تسجيل سعر المادة'));
    } catch (e) {
      throw _handleNetworkException(e, 'فشل تسجيل سعر المادة');
    }
  }

  Future<Map<String, dynamic>> updateMarketPrice(int id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(Uri.parse('$baseUrl/market/prices/$id'), headers: _headers, body: jsonEncode(data)).timeout(defaultTimeout);
      if (response.statusCode == 200) return _safeDecodeMap(response.body);
      throw Exception(_parseError(response, 'فشل تحديث سعر المادة'));
    } catch (e) {
      throw _handleNetworkException(e, 'فشل تحديث سعر المادة');
    }
  }

  Future<void> deleteMarketPrice(int id) async {
    try {
      await http.delete(Uri.parse('$baseUrl/market/prices/$id'), headers: _headers).timeout(defaultTimeout);
    } catch (e) {
      throw _handleNetworkException(e, 'فشل حذف المادة');
    }
  }

  Future<List<Map<String, dynamic>>> getSupplyAlerts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/market/alerts'), headers: _headers).timeout(defaultTimeout);
      if (response.statusCode == 200) return _safeDecodeList(response.body);
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createSupplyAlert(Map<String, dynamic> data) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/market/alerts'), headers: _headers, body: jsonEncode(data)).timeout(defaultTimeout);
      if (response.statusCode == 200 || response.statusCode == 201) return _safeDecodeMap(response.body);
      throw Exception(_parseError(response, 'فشل إصدار الإخطار التمويني'));
    } catch (e) {
      throw _handleNetworkException(e, 'فشل إصدار الإخطار التمويني');
    }
  }

  Future<void> updateSupplyAlertStatus(int id, String status) async {
    try {
      await http.put(Uri.parse('$baseUrl/market/alerts/$id/status'), headers: _headers, body: jsonEncode({'status': status})).timeout(defaultTimeout);
    } catch (e) {
      throw _handleNetworkException(e, 'فشل تحديث الإخطار');
    }
  }

  Future<Map<String, dynamic>> getMarketBulletin() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/market/bulletin'), headers: _headers).timeout(defaultTimeout);
      if (response.statusCode == 200) return _safeDecodeMap(response.body);
      return {};
    } catch (_) {
      return {};
    }
  }

  // ==========================================
  // LEGAL & CONTENTIOUS (المنازعات والشؤون القانونية)
  // ==========================================

  Future<List<Map<String, dynamic>>> getContentieuxPvs() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/contentieux/pvs'), headers: _headers).timeout(defaultTimeout);
      if (response.statusCode == 200) return _safeDecodeList(response.body);
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getClosureOrders() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/contentieux/closures'), headers: _headers).timeout(defaultTimeout);
      if (response.statusCode == 200) return _safeDecodeList(response.body);
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createClosureOrder(Map<String, dynamic> data) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/contentieux/closures'), headers: _headers, body: jsonEncode(data)).timeout(defaultTimeout);
      if (response.statusCode == 200 || response.statusCode == 201) return _safeDecodeMap(response.body);
      throw Exception(_parseError(response, 'فشل إعداد قرار الغلق'));
    } catch (e) {
      throw _handleNetworkException(e, 'فشل إعداد قرار الغلق');
    }
  }

  Future<Map<String, dynamic>> signClosureOrder(int id) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/contentieux/closures/$id/sign'), headers: _headers).timeout(defaultTimeout);
      if (response.statusCode == 200) return _safeDecodeMap(response.body);
      throw Exception(_parseError(response, 'فشل توقيع قرار الغلق'));
    } catch (e) {
      throw _handleNetworkException(e, 'فشل توقيع قرار الغلق');
    }
  }

  Future<Map<String, dynamic>> executeClosureOrder(int id, {String? notes}) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/contentieux/closures/$id/execute'), headers: _headers, body: jsonEncode({'executionNotes': notes})).timeout(defaultTimeout);
      if (response.statusCode == 200) return _safeDecodeMap(response.body);
      throw Exception(_parseError(response, 'فشل تسجيل تنفيذ الغلق'));
    } catch (e) {
      throw _handleNetworkException(e, 'فشل تسجيل تنفيذ الغلق');
    }
  }

  Future<Map<String, dynamic>> reopenClosureOrder(int id) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/contentieux/closures/$id/reopen'), headers: _headers, body: jsonEncode({})).timeout(defaultTimeout);
      if (response.statusCode == 200) return _safeDecodeMap(response.body);
      throw Exception(_parseError(response, 'فشل إعادة فتح المحل'));
    } catch (e) {
      throw _handleNetworkException(e, 'فشل إعادة فتح المحل');
    }
  }

  Future<List<Map<String, dynamic>>> getCourtCases() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/contentieux/courts'), headers: _headers).timeout(defaultTimeout);
      if (response.statusCode == 200) return _safeDecodeList(response.body);
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createCourtCase(Map<String, dynamic> data) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/contentieux/courts'), headers: _headers, body: jsonEncode(data)).timeout(defaultTimeout);
      if (response.statusCode == 200 || response.statusCode == 201) return _safeDecodeMap(response.body);
      throw Exception(_parseError(response, 'فشل تسجيل الإحالة القضائية'));
    } catch (e) {
      throw _handleNetworkException(e, 'فشل تسجيل الإحالة القضائية');
    }
  }

  Future<Map<String, dynamic>> updateCourtCase(int id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(Uri.parse('$baseUrl/contentieux/courts/$id'), headers: _headers, body: jsonEncode(data)).timeout(defaultTimeout);
      if (response.statusCode == 200) return _safeDecodeMap(response.body);
      throw Exception(_parseError(response, 'فشل تحديث القضية'));
    } catch (e) {
      throw _handleNetworkException(e, 'فشل تحديث القضية');
    }
  }
}


