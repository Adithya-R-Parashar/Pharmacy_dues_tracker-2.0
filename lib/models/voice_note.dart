class VoiceNote {
  final int? id;
  final int pharmacyId;
  final String filePath;
  final int? durationSeconds;
  final String createdAt; // Format: yyyy-MM-dd HH:mm:ss

  VoiceNote({
    this.id,
    required this.pharmacyId,
    required this.filePath,
    this.durationSeconds,
    required this.createdAt,
  });

  factory VoiceNote.fromMap(Map<String, dynamic> map) {
    return VoiceNote(
      id: map['id'] as int?,
      pharmacyId: map['pharmacy_id'] as int,
      filePath: map['file_path'] as String,
      durationSeconds: map['duration_seconds'] as int?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'pharmacy_id': pharmacyId,
      'file_path': filePath,
      'duration_seconds': durationSeconds,
      'created_at': createdAt,
    };
  }
}
