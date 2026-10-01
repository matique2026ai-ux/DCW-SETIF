import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drh_setif_tracker/models/user.dart';
import 'package:drh_setif_tracker/models/employee.dart';
import 'package:drh_setif_tracker/services/api_service.dart';

class AuthService extends ChangeNotifier {
  static const String _authUserKey = 'auth_cached_user';
  static const String _authTokenKey = 'auth_cached_token';

  final ApiService _api = ApiService();
  User? _currentUser;
  Employee? _currentEmployee;
  bool _isLoading = false;
  bool _isOfflineLogin = false;

  User? get currentUser => _currentUser;
  Employee? get currentEmployee => _currentEmployee;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isOfflineLogin => _isOfflineLogin;
  ApiService get api => _api;

  Future<bool> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString(_authUserKey);
      final token = prefs.getString(_authTokenKey);
      if (userStr != null && token != null) {
        final userData = jsonDecode(userStr);
        _currentUser = User(
          id: userData['id'] as int?,
          username: (userData['username'] ?? '') as String,
          passwordHash: '',
          role: (userData['role'] ?? 'inspector') as String,
          employeeId: userData['employeeId'] as int?,
          fullName: (userData['fullName'] ?? userData['full_name'] ?? '') as String?,
          deviceId: userData['deviceId'] as String?,
          mustChangeCredentials: userData['mustChangeCredentials'] == true || userData['must_change_credentials'] == true,
        );
        _api.setToken(token);
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  static const String _deviceIdKey = 'device_unique_security_id';
  static const String _trustedMasterPinKey = 'trusted_admin_master_pin';

  static Future<String?> getSavedMasterPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_trustedMasterPinKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveMasterPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_trustedMasterPinKey, pin.trim());
    } catch (_) {}
  }

  static Future<void> clearSavedMasterPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_trustedMasterPinKey);
    } catch (_) {}
  }

  static Future<String> getOrCreateDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString(_deviceIdKey);
      if (id == null || id.isEmpty) {
        final prefix = kIsWeb
            ? (defaultTargetPlatform == TargetPlatform.iOS ? 'DCW-IOS' : 'DCW-WEB')
            : 'DCW-DEV';
        id = '$prefix-${DateTime.now().millisecondsSinceEpoch}-${1000 + (DateTime.now().microsecond % 9000)}';
        await prefs.setString(_deviceIdKey, id);
      }
      return id;
    } catch (_) {
      return 'DCW-DEV-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> login(String username, String password, {String? adminOverrideCode, String? masterPin}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final isIOSWeb = kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS);
      final isMobileWeb = kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);
      final isDesktopWeb = kIsWeb && !isMobileWeb;

      // On Desktop Web, do NOT send mobile deviceId. On iPhone / Mobile Web, generate/read persistent hardware fingerprint!
      final devId = isDesktopWeb ? null : await getOrCreateDeviceId();
      final savedPin = await getSavedMasterPin();
      final effectivePin = (masterPin != null && masterPin.trim().isNotEmpty)
          ? masterPin.trim()
          : savedPin;

      final deviceName = isIOSWeb
          ? 'هاتف iPhone معتمد (Safari)'
          : (isDesktopWeb ? 'متصفح كمبيوتر مكتبي' : 'هاتف معتمد');

      final result = await _api.login(
        username,
        password,
        deviceId: devId,
        deviceName: deviceName,
        adminOverrideCode: adminOverrideCode,
        masterPin: effectivePin,
        isWeb: kIsWeb,
        isIOS: isIOSWeb,
        isDesktop: isDesktopWeb,
      );
      final userData = result['user'];
      final token = result['token'] as String;

      // 🚫 STRICT ENFORCEMENT: Field Inspectors are strictly forbidden from Web login
      final userRole = (userData['role'] ?? '').toString();
      final userRoleId = userData['roleId'] ?? 0;
      if (kIsWeb && (userRole == 'inspector' || userRoleId == 4)) {
        _isLoading = false;
        notifyListeners();
        throw Exception('🚫 الولوج عبر المتصفح غير مصرّح به للمفتشين الميدانيين: حساب المفتش مقيّد حصرياً بتطبيق الهاتف المحمول المصطب (DCW-SETIF-TRACKER). يمنع منعاً باتاً فتح الحساب من متصفح الهاتف أو الكمبيوتر.');
      }

      // If login succeeded with effective PIN, remember on this device
      if (effectivePin != null && effectivePin.isNotEmpty) {
        await saveMasterPin(effectivePin);
      }

      _currentUser = User(
        id: userData['id'] as int?,
        username: (userData['username'] ?? '') as String,
        passwordHash: '',
        role: (userData['role'] ?? 'inspector') as String,
        employeeId: userData['employeeId'] as int?,
        fullName:
            (userData['fullName'] ?? userData['full_name'] ?? '') as String?,
        deviceId: userData['deviceId'] as String? ?? devId,
        mustChangeCredentials: userData['mustChangeCredentials'] == true || userData['must_change_credentials'] == true,
      );

      // Save for offline session persistence
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_authUserKey, jsonEncode(userData));
      await prefs.setString(_authTokenKey, token);

      // 🛡️ Save to Offline Credential Vault for seamless offline login in the field
      final normalizedUser = username.trim().toLowerCase();
      const salt = 'dcw_setif_vault_2026';
      final passHash = sha256.convert(utf8.encode('$password$salt')).toString();
      final vaultData = {
        'userData': userData,
        'token': token,
        'passwordHash': passHash,
        'masterPin': effectivePin,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString('offline_vault_$normalizedUser', jsonEncode(vaultData));

      _isOfflineLogin = false;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      final errStr = e.toString();
      final isNetworkError = errStr.contains('تعذر الاتصال بالخادم') ||
          errStr.contains('SocketException') ||
          errStr.contains('ClientException') ||
          errStr.contains('Failed host lookup') ||
          errStr.contains('TimeoutException') ||
          errStr.contains('timed out') ||
          errStr.contains('Network is unreachable') ||
          errStr.contains('Connection refused');

      if (isNetworkError) {
        // 🚀 SMART OFFLINE FALLBACK: Check if this user has previously logged in on this device
        final prefs = await SharedPreferences.getInstance();
        final normalizedUser = username.trim().toLowerCase();
        final vaultStr = prefs.getString('offline_vault_$normalizedUser');

        if (vaultStr != null && vaultStr.isNotEmpty) {
          try {
            final vault = jsonDecode(vaultStr) as Map<String, dynamic>;
            const salt = 'dcw_setif_vault_2026';
            final enteredHash = sha256.convert(utf8.encode('$password$salt')).toString();
            final storedHash = vault['passwordHash']?.toString();

            if (enteredHash == storedHash) {
              final userData = Map<String, dynamic>.from(vault['userData'] as Map);
              final token = (vault['token'] ?? '') as String;

              // Check web ban
              final userRole = (userData['role'] ?? '').toString();
              final userRoleId = userData['roleId'] ?? 0;
              if (kIsWeb && (userRole == 'inspector' || userRoleId == 4)) {
                _isLoading = false;
                notifyListeners();
                throw Exception('🚫 الولوج عبر المتصفح غير مصرّح به للمفتشين الميدانيين: حساب المفتش مقيّد حصرياً بتطبيق الهاتف المحمول المصطب (DCW-SETIF-TRACKER). يمنع منعاً باتاً فتح الحساب من متصفح الهاتف أو الكمبيوتر.');
              }

              _currentUser = User(
                id: userData['id'] as int?,
                username: (userData['username'] ?? '') as String,
                passwordHash: '',
                role: (userData['role'] ?? 'inspector') as String,
                employeeId: userData['employeeId'] as int?,
                fullName: (userData['fullName'] ?? userData['full_name'] ?? '') as String?,
                deviceId: userData['deviceId'] as String?,
                mustChangeCredentials: false,
              );

              // Restore token and active session
              _api.setToken(token);
              await prefs.setString(_authUserKey, jsonEncode(userData));
              await prefs.setString(_authTokenKey, token);

              _isOfflineLogin = true;
              _isLoading = false;
              notifyListeners();
              return; // Successfully logged in offline!
            } else {
              _isLoading = false;
              notifyListeners();
              throw Exception('كلمة المرور غير صحيحة ❌ (التحقق بدون اتصال)');
            }
          } catch (vaultErr) {
            if (vaultErr.toString().contains('كلمة المرور غير صحيحة') || vaultErr.toString().contains('المتصفح')) {
              rethrow;
            }
          }
        }
      }

      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> completeMandatoryCredentialsSetup({
    required String newPassword,
    required String newPin,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _api.setupCredentials(newPassword: newPassword, newPin: newPin);
      if (_currentUser != null) {
        _currentUser = User(
          id: _currentUser!.id,
          username: _currentUser!.username,
          passwordHash: '',
          role: _currentUser!.role,
          employeeId: _currentUser!.employeeId,
          fullName: _currentUser!.fullName,
          serviceName: _currentUser!.serviceName,
          deviceId: _currentUser!.deviceId,
          mustChangeCredentials: false,
        );
        final prefs = await SharedPreferences.getInstance();
        final userStr = prefs.getString(_authUserKey);
        if (userStr != null) {
          try {
            final map = jsonDecode(userStr) as Map<String, dynamic>;
            map['mustChangeCredentials'] = false;
            map['must_change_credentials'] = false;
            await prefs.setString(_authUserKey, jsonEncode(map));
          } catch (_) {}
        }
        await saveMasterPin(newPin);

        // Update offline vault with new credentials
        final normalizedUser = _currentUser!.username.trim().toLowerCase();
        final vaultStr = prefs.getString('offline_vault_$normalizedUser');
        if (vaultStr != null) {
          try {
            final vault = jsonDecode(vaultStr) as Map<String, dynamic>;
            const salt = 'dcw_setif_vault_2026';
            vault['passwordHash'] = sha256.convert(utf8.encode('$newPassword$salt')).toString();
            vault['masterPin'] = newPin;
            await prefs.setString('offline_vault_$normalizedUser', jsonEncode(vault));
          } catch (_) {}
        }
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    _api.logout();
    _currentUser = null;
    _currentEmployee = null;
    _isOfflineLogin = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authUserKey);
    await prefs.remove(_authTokenKey);
    // Note: We deliberately preserve 'offline_vault_*' on logout so authorized staff can log back in offline in the field!
    notifyListeners();
  }

  void setCurrentEmployee(Employee employee) {
    _currentEmployee = employee;
    notifyListeners();
  }
}
