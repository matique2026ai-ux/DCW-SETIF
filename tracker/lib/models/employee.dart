class Employee {
  final int id;
  final String? name;
  final String? firstName;
  final String? nameAr;
  final String? firstNameAr;
  final String? service;
  final String? grade;

  Employee({
    required this.id,
    this.name,
    this.firstName,
    this.nameAr,
    this.firstNameAr,
    this.service,
    this.grade,
  });

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: (map['Id'] ?? map['id'] ?? 0) as int,
      name: (map['Nom'] ?? map['name']) as String?,
      firstName: (map['Prenom'] ?? map['first_name']) as String?,
      nameAr: (map['NomAr'] ?? map['name_ar']) as String?,
      firstNameAr: (map['PrenomAr'] ?? map['first_name_ar']) as String?,
      service: (map['Service'] ?? map['service']) as String?,
      grade: (map['Grade'] ?? map['grade']) as String?,
    );
  }
}
