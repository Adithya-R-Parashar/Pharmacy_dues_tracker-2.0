class Pharmacy {
  final int? id;
  final String partyCode;
  final String name;
  final String? salesman;
  final String? city;
  final double? totalAmount;
  final double? bucket121180;
  final double? bucket181270;
  final double? bucket271360;
  final String? lastImportDate;
  final String? notes;
  final String createdAt; // Format: yyyy-MM-dd HH:mm:ss

  Pharmacy({
    this.id,
    required this.partyCode,
    required this.name,
    this.salesman,
    this.city,
    this.totalAmount,
    this.bucket121180,
    this.bucket181270,
    this.bucket271360,
    this.lastImportDate,
    this.notes,
    required this.createdAt,
  });

  factory Pharmacy.fromMap(Map<String, dynamic> map) {
    return Pharmacy(
      id: map['id'] as int?,
      partyCode: map['party_code'] as String,
      name: map['name'] as String,
      salesman: map['salesman'] as String?,
      city: map['city'] as String?,
      totalAmount: (map['total_amount'] as num?)?.toDouble(),
      bucket121180: (map['bucket_121_180'] as num?)?.toDouble(),
      bucket181270: (map['bucket_181_270'] as num?)?.toDouble(),
      bucket271360: (map['bucket_271_360'] as num?)?.toDouble(),
      lastImportDate: map['last_import_date'] as String?,
      notes: map['notes'] as String?,
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
      'total_amount': totalAmount,
      'bucket_121_180': bucket121180,
      'bucket_181_270': bucket181270,
      'bucket_271_360': bucket271360,
      'last_import_date': lastImportDate,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  @override
  String toString() {
    return 'Pharmacy(id: $id, partyCode: $partyCode, name: $name, salesman: $salesman, city: $city, totalAmount: $totalAmount, bucket121180: $bucket121180, bucket181270: $bucket181270, bucket271360: $bucket271360, lastImportDate: $lastImportDate, notes: $notes, createdAt: $createdAt)';
  }
}
