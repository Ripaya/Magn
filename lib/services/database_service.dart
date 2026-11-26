import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/app_settings.dart';
import '../models/focus_preset.dart';
import '../models/focus_session.dart';
import '../models/session_label.dart';

/// Local-first SQLite repository matching the Magn schema:
/// `presets`, `labels`, `sessions`, and `app_settings`.
class DatabaseService {
  static const String _dbName = 'magn_focus_dial.db';
  static const int _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);
    _db = await openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: _onCreate,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE presets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        mode TEXT NOT NULL,
        focus_sec INTEGER NOT NULL,
        short_break_sec INTEGER NOT NULL,
        long_break_sec INTEGER NOT NULL,
        cycles_before_long_break INTEGER NOT NULL,
        auto_start_break INTEGER NOT NULL DEFAULT 0,
        auto_start_focus INTEGER NOT NULL DEFAULT 0,
        is_built_in INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE labels (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color_hex TEXT NOT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        mode TEXT NOT NULL,
        label_id TEXT,
        started_at INTEGER NOT NULL,
        ended_at INTEGER NOT NULL,
        planned_sec INTEGER NOT NULL,
        actual_sec INTEGER NOT NULL,
        completed INTEGER NOT NULL DEFAULT 1,
        notes TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_sessions_started_at ON sessions(started_at DESC)
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Seed built-in smart presets
    for (final preset in FocusPreset.defaults) {
      await db.insert('presets', preset.toDbMap());
    }

    // Seed clean initial focus labels
    final now = DateTime.now().millisecondsSinceEpoch;
    final defaultLabels = [
      SessionLabel(
        id: 'label_general',
        name: 'General',
        colorHex: '#475569',
        createdAtMs: now,
      ),
      SessionLabel(
        id: 'label_coding',
        name: 'Coding',
        colorHex: '#2563EB',
        createdAtMs: now + 1,
      ),
      SessionLabel(
        id: 'label_study',
        name: 'Study',
        colorHex: '#059669',
        createdAtMs: now + 2,
      ),
      SessionLabel(
        id: 'label_writing',
        name: 'Writing',
        colorHex: '#7C3AED',
        createdAtMs: now + 3,
      ),
    ];

    for (final label in defaultLabels) {
      await db.insert('labels', label.toDbMap());
    }
  }

  // ── Settings ────────────────────────────────────────────────────────────────

  Future<AppSettings> loadSettings() async {
    final db = await database;
    final rows = await db.query('app_settings');
    final map = <String, String>{
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    return AppSettings.fromKeyValueMap(map);
  }

  Future<void> saveSettings(AppSettings settings) async {
    final db = await database;
    final batch = db.batch();
    settings.toKeyValueMap().forEach((key, value) {
      batch.insert(
        'app_settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await batch.commit(noResult: true);
  }

  // ── Labels ──────────────────────────────────────────────────────────────────

  Future<List<SessionLabel>> loadLabels({bool includeArchived = false}) async {
    final db = await database;
    final rows = await db.query(
      'labels',
      where: includeArchived ? null : 'is_archived = 0',
      orderBy: 'created_at ASC',
    );
    return rows.map(SessionLabel.fromDbMap).toList();
  }

  Future<void> upsertLabel(SessionLabel label) async {
    final db = await database;
    await db.insert(
      'labels',
      label.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> archiveLabel(String id) async {
    final db = await database;
    await db.update(
      'labels',
      {'is_archived': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Presets ─────────────────────────────────────────────────────────────────

  Future<List<FocusPreset>> loadPresets() async {
    final db = await database;
    final rows = await db.query('presets');
    return rows.map(FocusPreset.fromDbMap).toList();
  }

  Future<void> upsertPreset(FocusPreset preset) async {
    final db = await database;
    await db.insert(
      'presets',
      preset.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deletePreset(String id) async {
    final db = await database;
    await db.delete(
      'presets',
      where: 'id = ? AND is_built_in = 0',
      whereArgs: [id],
    );
  }

  // ── Sessions ────────────────────────────────────────────────────────────────

  Future<List<FocusSession>> loadSessions({int? limit}) async {
    final db = await database;
    final rows = await db.query(
      'sessions',
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map(FocusSession.fromDbMap).toList();
  }

  Future<void> upsertSession(FocusSession session) async {
    final db = await database;
    await db.insert(
      'sessions',
      session.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSession(String id) async {
    final db = await database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  // ── Export & Backup ─────────────────────────────────────────────────────────

  Future<String> exportAsJson() async {
    final labels = await loadLabels(includeArchived: true);
    final sessions = await loadSessions();
    final payload = {
      'app': 'Magn',
      'schema_version': _dbVersion,
      'exported_at_utc': DateTime.now().toUtc().toIso8601String(),
      'labels': labels.map((e) => e.toJson()).toList(),
      'sessions': sessions.map((e) => e.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<String> exportAsCsv() async {
    final labels = await loadLabels(includeArchived: true);
    final labelMap = {for (final l in labels) l.id: l.name};
    final sessions = await loadSessions();

    final buffer = StringBuffer();
    buffer.writeln(
      'id,mode,label,started_at_iso,ended_at_iso,planned_sec,actual_sec,completed,notes',
    );
    for (final s in sessions) {
      final labelName = _csvEscape(labelMap[s.labelId] ?? 'General');
      final notes = _csvEscape(s.notes);
      buffer.writeln(
        '${s.id},${s.mode.storageKey},$labelName,'
        '${s.startedAt.toIso8601String()},${s.endedAt.toIso8601String()},'
        '${s.plannedSec},${s.actualSec},${s.completed},$notes',
      );
    }
    return buffer.toString();
  }

  Future<int> importFromJson(String rawJson) async {
    final decoded = jsonDecode(rawJson) as Map<String, dynamic>;
    final db = await database;
    final batch = db.batch();

    final rawLabels = decoded['labels'] as List<dynamic>? ?? const [];
    for (final item in rawLabels) {
      final label = SessionLabel.fromJson(item as Map<String, dynamic>);
      batch.insert(
        'labels',
        label.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final rawSessions = decoded['sessions'] as List<dynamic>? ?? const [];
    for (final item in rawSessions) {
      final session = FocusSession.fromJson(item as Map<String, dynamic>);
      batch.insert(
        'sessions',
        session.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    return rawSessions.length;
  }

  String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}
