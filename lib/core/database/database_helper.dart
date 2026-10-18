// lib/core/database/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database == null) {
      _database = await _initDB('teachpoint_esias.db');
    }
    // S'assure que les colonnes existent systématiquement à chaque appel
    await _autoRepair(_database!);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE profile (
        id TEXT PRIMARY KEY,
        teacher_id TEXT NOT NULL DEFAULT '1001',
        nom TEXT NOT NULL,
        prenoms TEXT NOT NULL,
        etablissement TEXT NOT NULL,
        contact TEXT NOT NULL,
        taux_taxe_pourcent REAL DEFAULT 7.5,
        sheets_web_app_url TEXT NOT NULL,
        app_version TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE classes (
        id TEXT PRIMARY KEY,
        nom_classe TEXT NOT NULL,
        matiere TEXT NOT NULL,
        taux_horaire REAL NOT NULL,
        annee_scolaire TEXT NOT NULL,
        onglet_progression TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE syllabus_lessons (
        id TEXT PRIMARY KEY,
        class_id TEXT NOT NULL,
        semaine_numero INTEGER NOT NULL,
        chapitre TEXT NOT NULL,
        titre_lecon TEXT NOT NULL,
        objectifs TEXT,
        volume_horaire REAL NOT NULL,
        statut TEXT NOT NULL,
        date_realisee TEXT,
        ordre_sequence INTEGER NOT NULL,
        FOREIGN KEY(class_id) REFERENCES classes(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE attendance_records (
        id TEXT PRIMARY KEY,
        teacher_id TEXT NOT NULL DEFAULT '1001',
        class_id TEXT NOT NULL,
        lesson_id TEXT,
        date_cours TEXT NOT NULL,
        heure_arrivee TEXT NOT NULL,
        heure_depart TEXT NOT NULL,
        heures_validees REAL NOT NULL,
        taux_applique REAL NOT NULL,
        montant_total REAL NOT NULL,
        montant_taxe REAL DEFAULT 0.0,
        montant_net REAL DEFAULT 0.0,
        statut_paiement TEXT DEFAULT 'NON_PAYE',
        remarque TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY(class_id) REFERENCES classes(id),
        FOREIGN KEY(lesson_id) REFERENCES syllabus_lessons(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');
  }

  Future<void> _autoRepair(Database db) async {
    try {
      await db.execute('ALTER TABLE attendance_records ADD COLUMN statut_paiement TEXT DEFAULT "NON_PAYE"');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE attendance_records ADD COLUMN montant_taxe REAL DEFAULT 0.0');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE attendance_records ADD COLUMN montant_net REAL DEFAULT 0.0');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE attendance_records ADD COLUMN teacher_id TEXT DEFAULT "1001"');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE profile ADD COLUMN taux_taxe_pourcent REAL DEFAULT 7.5');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE profile ADD COLUMN teacher_id TEXT DEFAULT "1001"');
    } catch (_) {}

    try {
      await db.execute('ALTER TABLE classes ADD COLUMN onglet_progression TEXT DEFAULT ""');
    } catch (_) {}

    final prof = await db.query('profile', limit: 1);
    if (prof.isEmpty) {
      await db.insert('profile', {
        'id': 'prof_1',
        'teacher_id': '1001',
        'nom': 'KABLAM',
        'prenoms': 'Edjabrou Ulrich Blanchard',
        'etablissement': 'ESIAS POLYTECHNIQUE (Groupe Adama Sanogo)',
        'contact': '+225 07 00 00 00 00',
        'taux_taxe_pourcent': 7.5,
        'sheets_web_app_url': 'https://script.google.com/macros/s/AKfycbzEHBCrdaK2ExJ9Eg2uZ7rEdlgg6CsY8ag1kGF6h897bk7iza0b5gYyeRnorznPO4TG-g/exec',
        'app_version': '1.0.0'
      });
    }
  }
}