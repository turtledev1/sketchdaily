import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Opens the SketchDaily sqflite database.
///
/// The `date` column stores `yyyy-MM-dd` so we can dedupe per local day.
class AppDatabase {
  AppDatabase._();

  static const _dbName = 'sketchdaily.db';
  static const _dbVersion = 1;

  static Database? _db;

  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.join(docsDir.path, _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sessions (
            date TEXT PRIMARY KEY NOT NULL,
            duration_seconds INTEGER NOT NULL,
            completed_at INTEGER NOT NULL,
            photo_id TEXT NOT NULL,
            image_url TEXT NOT NULL,
            photographer_name TEXT NOT NULL,
            photographer_url TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }
}
