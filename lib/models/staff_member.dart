// models/staff_member.dart

class StaffMember {
  final String id;
  final String name;
  final String role; // طبيب / موظف

  StaffMember({required this.id, required this.name, required this.role});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role};

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id'],
      name: json['name'],
      role: json['role'],
    );
  }
}
