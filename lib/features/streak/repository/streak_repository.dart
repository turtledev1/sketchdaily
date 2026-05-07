import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/storage/database.dart';

class SketchSessionRecord {
  const SketchSessionRecord({
    required this.date,
    required this.durationSeconds,
    required this.completedAt,
    required this.photoId,
    required this.imageUrl,
    required this.photographerName,
    required this.photographerProfileUrl,
  });

  /// `yyyy-MM-dd` for the local calendar day.
  final String date;
  final int durationSeconds;
  final DateTime completedAt;

  /// Image metadata captured at the moment the user "locked in" the prompt
  /// by starting the timer.
  final String photoId;
  final String imageUrl;
  final String photographerName;
  final String photographerProfileUrl;
}

/// Writes and reads a per-day log of completed sketch sessions.
///
/// Hydrated state (current streak, longest streak, set of completed dates)
/// lives in [StreakCubit]. This repository is the append-only history log —
/// future "show my last 30 days" views will read from here.
class StreakRepository {
  StreakRepository();

  static final DateFormat _isoDate = DateFormat('yyyy-MM-dd');

  Database? _db;

  Future<void> init() async {
    _db = await AppDatabase.instance();
  }

  Future<Database> _requireDb() async {
    return _db ??= await AppDatabase.instance();
  }

  static String formatDate(DateTime date) => _isoDate.format(DateTime(date.year, date.month, date.day));

  Future<void> recordSession({
    required DateTime completedAt,
    required int durationSeconds,
    required String photoId,
    required String imageUrl,
    required String photographerName,
    required String photographerProfileUrl,
  }) async {
    final db = await _requireDb();
    await db.insert(
      'sessions',
      {
        'date': formatDate(completedAt),
        'duration_seconds': durationSeconds,
        'completed_at': completedAt.millisecondsSinceEpoch,
        'photo_id': photoId,
        'image_url': imageUrl,
        'photographer_name': photographerName,
        'photographer_url': photographerProfileUrl,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore, // first session of the day wins
    );
  }

  Future<List<SketchSessionRecord>> recentSessions({int limit = 30}) async {
    final db = await _requireDb();
    final rows = await db.query(
      'sessions',
      orderBy: 'completed_at DESC',
      limit: limit,
    );
    return rows.map(_rowToRecord).toList();
  }

  /// Returns the session for a specific local date, or null if none exists.
  /// Used by the heatmap tile to surface the saved image after the fact.
  Future<SketchSessionRecord?> sessionForDate(DateTime date) async {
    final db = await _requireDb();
    final rows = await db.query(
      'sessions',
      where: 'date = ?',
      whereArgs: [formatDate(date)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToRecord(rows.first);
  }

  static SketchSessionRecord _rowToRecord(Map<String, Object?> row) {
    return SketchSessionRecord(
      date: row['date']! as String,
      durationSeconds: row['duration_seconds']! as int,
      completedAt: DateTime.fromMillisecondsSinceEpoch(
        row['completed_at']! as int,
      ),
      photoId: row['photo_id']! as String,
      imageUrl: row['image_url']! as String,
      photographerName: row['photographer_name']! as String,
      photographerProfileUrl: row['photographer_url']! as String,
    );
  }

  Future<void> clear() async {
    final db = await _requireDb();
    await db.delete('sessions');
  }
}
