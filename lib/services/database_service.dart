import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/creation.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'language_stretching.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE creations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        originalWords TEXT NOT NULL,
        sentence TEXT NOT NULL,
        replacedWords TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT
      )
    ''');
  }

  Future<int> insertCreation(Creation creation) async {
    final db = await database;
    return await db.insert(
      'creations',
      {
        'originalWords': creation.originalWords.join(','),
        'sentence': creation.sentence,
        'replacedWords': creation.replacedWords.join(','),
        'createdAt': creation.createdAt.toIso8601String(),
        'updatedAt': creation.updatedAt?.toIso8601String(),
      },
    );
  }

  Future<List<Creation>> getAllCreations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'creations',
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) {
      return Creation(
        id: maps[i]['id'] as int,
        originalWords: (maps[i]['originalWords'] as String).split(','),
        sentence: maps[i]['sentence'] as String,
        replacedWords: (maps[i]['replacedWords'] as String).split(','),
        createdAt: DateTime.parse(maps[i]['createdAt'] as String),
        updatedAt: maps[i]['updatedAt'] != null
            ? DateTime.parse(maps[i]['updatedAt'] as String)
            : null,
      );
    });
  }

  Future<int> updateCreation(Creation creation) async {
    final db = await database;
    return await db.update(
      'creations',
      {
        'sentence': creation.sentence,
        'replacedWords': creation.replacedWords.join(','),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [creation.id],
    );
  }

  Future<int> deleteCreation(int id) async {
    final db = await database;
    return await db.delete(
      'creations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

