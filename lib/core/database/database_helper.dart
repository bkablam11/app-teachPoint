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
    await _autoRepair(_database!);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 7,
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
      CREATE TABLE schedules (
        id TEXT PRIMARY KEY,
        jour_semaine INTEGER NOT NULL,
        jour_nom TEXT NOT NULL,
        heure_debut TEXT NOT NULL,
        heure_fin TEXT NOT NULL,
        duree_heures REAL NOT NULL,
        class_id TEXT NOT NULL,
        nom_classe TEXT NOT NULL,
        matiere TEXT NOT NULL
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
        created_at TEXT NOT NULL
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

    await _seedDefaultData(db);
  }

  Future<void> _autoRepair(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schedules (
        id TEXT PRIMARY KEY,
        jour_semaine INTEGER NOT NULL,
        jour_nom TEXT NOT NULL,
        heure_debut TEXT NOT NULL,
        heure_fin TEXT NOT NULL,
        duree_heures REAL NOT NULL,
        class_id TEXT NOT NULL,
        nom_classe TEXT NOT NULL,
        matiere TEXT NOT NULL
      )
    ''');

    await _seedDefaultData(db);
  }

  Future<void> _seedDefaultData(Database db) async {
    // 1. Profil par défaut
    final prof = await db.query('profile', limit: 1);
    if (prof.isEmpty) {
      await db.insert('profile', {
        'id': 'prof_1',
        'teacher_id': '1001',
        'nom': 'KABLAM',
        'prenoms': 'Edjabrou Ulrich Blanchard',
        'etablissement': 'ESIAS POLYTECHNIQUE (Groupe Adama Sanogo)',
        'contact': '+225 07 48 78 22 05',
        'taux_taxe_pourcent': 7.5,
        'sheets_web_app_url': 'https://script.google.com/macros/s/AKfycbzEHBCrdaK2ExJ9Eg2uZ7rEdlgg6CsY8ag1kGF6h897bk7iza0b5gYyeRnorznPO4TG-g/exec',
        'app_version': '1.0.0'
      });
    }

    // 2. Classes par défaut (Garantit que la liste n'est JAMAIS vide)
    final cls = await db.query('classes');
    if (cls.isEmpty) {
      await db.insert('classes', {
        'id': 'cls_2a_gc_bat',
        'nom_classe': '2A BTS GC-BAT',
        'matiere': 'Mathématiques Générales',
        'taux_horaire': 5000.0,
        'annee_scolaire': '2026-2027',
        'onglet_progression': 'PROG_2A_BTS_GC_BAT'
      });
      await db.insert('classes', {
        'id': 'cls_1a_ida',
        'nom_classe': '1A BTS IDA',
        'matiere': 'Mathématiques Financières & R.O',
        'taux_horaire': 4000.0,
        'annee_scolaire': '2026-2027',
        'onglet_progression': 'PROG_1A_BTS_IDA'
      });
      await db.insert('classes', {
        'id': 'cls_1a_fcge',
        'nom_classe': '1A BTS FCGE',
        'matiere': 'Mathématique Financière et R.O',
        'taux_horaire': 4000.0,
        'annee_scolaire': '2026-2027',
        'onglet_progression': 'PROG_1A_BTS_FCGE'
      });
    }

    // 3. Emploi du temps par défaut
    final sch = await db.query('schedules');
    if (sch.isEmpty) {
      await db.insert('schedules', {
        'id': 'sch_jeudi',
        'jour_semaine': 4, // Jeudi
        'jour_nom': 'JEUDI',
        'heure_debut': '13:30',
        'heure_fin': '16:30',
        'duree_heures': 3.0,
        'class_id': 'cls_2a_gc_bat',
        'nom_classe': '2A BTS GC-BAT',
        'matiere': 'Mathématiques Générales'
      });
      await db.insert('schedules', {
        'id': 'sch_ven_1',
        'jour_semaine': 5, // Vendredi
        'jour_nom': 'VENDREDI',
        'heure_debut': '13:30',
        'heure_fin': '15:30',
        'duree_heures': 2.0,
        'class_id': 'cls_1a_fcge',
        'nom_classe': '1A BTS FCGE',
        'matiere': 'Mathématique Financière et R.O'
      });
      await db.insert('schedules', {
        'id': 'sch_ven_2',
        'jour_semaine': 5, // Vendredi
        'jour_nom': 'VENDREDI',
        'heure_debut': '15:35',
        'heure_fin': '17:35',
        'duree_heures': 2.0,
        'class_id': 'cls_1a_ida',
        'nom_classe': '1A BTS IDA',
        'matiere': 'Mathématiques Financières & R.O'
      });
    }
  }
}