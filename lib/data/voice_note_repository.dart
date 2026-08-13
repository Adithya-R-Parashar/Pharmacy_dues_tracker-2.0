import 'dart:io';
import '../models/voice_note.dart';
import 'database_helper.dart';

class VoiceNoteRepository {
  Future<int> insert(VoiceNote note) async {
    final db = await DatabaseHelper.instance.database;
    return await db.insert('voice_notes', note.toMap());
  }

  /// Newest first.
  Future<List<VoiceNote>> getByPharmacy(int pharmacyId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'voice_notes',
      where: 'pharmacy_id = ?',
      whereArgs: [pharmacyId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => VoiceNote.fromMap(m)).toList();
  }

  /// Deletes the DB row AND the underlying audio file on disk.
  Future<void> delete(VoiceNote note) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('voice_notes', where: 'id = ?', whereArgs: [note.id]);
    final file = File(note.filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
