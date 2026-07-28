class Pharmacy {
  final int? id;
  final String partyCode;
  final String name;
  final String? salesman;
  final String? city;
  final String createdAt; // Format: yyyy-MM-dd HH:mm:ss

  Pharmacy({
    this.id,
    required this.partyCode,
    required this.name,
    this.salesman,
    this.city,
    required this.createdAt,
  });

  factory Pharmacy.fromMap(Map<String, dynamic> map) {
    return Pharmacy(
      id: map['id'] as int?,
      partyCode: map['party_code'] as String,
      name: map['name'] as String,
      salesman: map['salesman'] as String?,
      city: map['city'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'party_code': partyCode,
      'name': name,
      'salesman': salesman,
      'city': city,
      'created_at': createdAt,
    };
  }

  @override
  String toString() {
    return 'Pharmacy(id: $id, partyCode: $partyCode, name: $name, salesman: $salesman, city: $city, createdAt: $createdAt)';
  }
}
