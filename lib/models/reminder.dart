class Reminder {
  final int? id;
  final int? pharmacyId; // Nullable, populated only when reminderType = 'pharmacy'
  final String reminderType; // 'pharmacy' or 'salesman'
  final String? salesmanName; // Nullable, populated only when reminderType = 'salesman'
  final String scheduledDate; // Format: yyyy-MM-dd
  final String? scheduledTime; // Format: HH:mm, nullable
  final String status; // 'pending', 'done', 'rescheduled'
  final int? notificationId;
  final String? notes;
  final String createdAt; // Format: yyyy-MM-dd HH:mm:ss

  Reminder({
    this.id,
    this.pharmacyId,
    required this.reminderType,
    this.salesmanName,
    required this.scheduledDate,
    this.scheduledTime,
    required this.status,
    this.notificationId,
    this.notes,
    required this.createdAt,
  });

  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as int?,
      pharmacyId: map['pharmacy_id'] as int?,
      reminderType: map['reminder_type'] as String? ?? 'pharmacy',
      salesmanName: map['salesman_name'] as String?,
      scheduledDate: map['scheduled_date'] as String,
      scheduledTime: map['scheduled_time'] as String?,
      status: map['status'] as String,
      notificationId: map['notification_id'] as int?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'pharmacy_id': pharmacyId,
      'reminder_type': reminderType,
      'salesman_name': salesmanName,
      'scheduled_date': scheduledDate,
      'scheduled_time': scheduledTime,
      'status': status,
      'notification_id': notificationId,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  @override
  String toString() {
    return 'Reminder(id: $id, pharmacyId: $pharmacyId, reminderType: $reminderType, salesmanName: $salesmanName, scheduledDate: $scheduledDate, scheduledTime: $scheduledTime, status: $status, notificationId: $notificationId, notes: $notes, createdAt: $createdAt)';
  }
}
