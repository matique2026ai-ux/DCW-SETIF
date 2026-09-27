class User {
  final int? id;
  final String username;
  final String passwordHash;
  final String role;
  final int? employeeId;
  final String? fullName;
  final String? serviceName;
  final String? deviceId;
  final bool mustChangeCredentials;

  User({
    this.id,
    required this.username,
    required this.passwordHash,
    required this.role,
    this.employeeId,
    this.fullName,
    this.serviceName,
    this.deviceId,
    this.mustChangeCredentials = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'password_hash': passwordHash,
      'role': role,
      'employee_id': employeeId,
      'full_name': fullName,
      'service_name': serviceName,
      'device_id': deviceId,
      'must_change_credentials': mustChangeCredentials,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String? ?? '',
      role: map['role'] as String,
      employeeId: map['employee_id'] as int?,
      fullName: map['full_name'] as String?,
      serviceName: map['service_name'] as String? ?? map['service'] as String?,
      deviceId: map['deviceId'] as String? ?? map['device_id'] as String?,
      mustChangeCredentials: map['mustChangeCredentials'] == true || map['must_change_credentials'] == true,
    );
  }
}
