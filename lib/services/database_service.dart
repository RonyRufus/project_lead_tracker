import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/project_lead.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _db;

  Future<Database> get db async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'project_leads.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE leads (
            id TEXT PRIMARY KEY,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            timestamp TEXT NOT NULL,
            rawTranscript TEXT DEFAULT '',
            buildingType TEXT DEFAULT '',
            architectName TEXT DEFAULT '',
            phoneNumber TEXT DEFAULT '',
            companyName TEXT DEFAULT '',
            notes TEXT DEFAULT '',
            address TEXT DEFAULT '',
            isManual INTEGER DEFAULT 0
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_timestamp ON leads (timestamp DESC)');
      },
    );
  }

  Future<String> insertLead(ProjectLead lead) async {
    final database = await db;
    await database.insert(
      'leads',
      lead.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return lead.id;
  }

  Future<List<ProjectLead>> getAllLeads() async {
    final database = await db;
    final maps = await database.query(
      'leads',
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => ProjectLead.fromMap(m)).toList();
  }

  Future<ProjectLead?> getLeadById(String id) async {
    final database = await db;
    final maps = await database.query(
      'leads',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ProjectLead.fromMap(maps.first);
  }

  Future<List<ProjectLead>> searchLeads(String query) async {
    if (query.isEmpty) return getAllLeads();
    final database = await db;
    final q = '%${query.toLowerCase()}%';
    final maps = await database.query(
      'leads',
      where: '''
        LOWER(buildingType) LIKE ? OR
        LOWER(architectName) LIKE ? OR
        LOWER(phoneNumber) LIKE ? OR
        LOWER(companyName) LIKE ? OR
        LOWER(notes) LIKE ? OR
        LOWER(address) LIKE ? OR
        LOWER(rawTranscript) LIKE ?
      ''',
      whereArgs: [q, q, q, q, q, q, q],
      orderBy: 'timestamp DESC',
    );
    return maps.map((m) => ProjectLead.fromMap(m)).toList();
  }

  Future<void> updateLead(ProjectLead lead) async {
    final database = await db;
    await database.update(
      'leads',
      lead.toMap(),
      where: 'id = ?',
      whereArgs: [lead.id],
    );
  }

  Future<void> deleteLead(String id) async {
    final database = await db;
    await database.delete('leads', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getLeadCount() async {
    final database = await db;
    final result =
        await database.rawQuery('SELECT COUNT(*) as count FROM leads');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    final database = await db;
    await database.close();
    _db = null;
  }
}
