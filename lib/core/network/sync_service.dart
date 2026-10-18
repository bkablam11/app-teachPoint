// lib/core/network/sync_service.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';

class SyncService {
  static final SyncService instance = SyncService._init();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  bool _isSyncing = false;

  SyncService._init();

  void initializeAutoSync() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.isNotEmpty && !results.contains(ConnectivityResult.none)) {
        processQueue();
      }
    });
  }

  Future<void> enqueue(String action, Map<String, dynamic> payload) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('sync_queue', {
      'action': action,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'status': 'PENDING',
    });

    processQueue();
  }

  Future<int> processQueue() async {
    if (_isSyncing) return 0;
    _isSyncing = true;

    int syncedCount = 0;
    try {
      final db = await DatabaseHelper.instance.database;
      final profileData = await db.query('profile', limit: 1);
      if (profileData.isEmpty) return 0;

      final url = profileData.first['sheets_web_app_url'] as String?;
      if (url == null || url.trim().isEmpty || !url.startsWith('https://script.google.com')) {
        return 0;
      }

      final pendingItems = await db.query(
        'sync_queue',
        where: 'status = ?',
        whereArgs: ['PENDING'],
        orderBy: 'id ASC',
        limit: 25,
      );

      for (var item in pendingItems) {
        final id = item['id'] as int;
        final action = item['action'] as String;
        final payload = jsonDecode(item['payload'] as String);

        try {
          final response = await _dio.post(
            url,
            data: jsonEncode({
              'action': action,
              'payload': payload,
            }),
            options: Options(headers: {'Content-Type': 'application/json'}),
          );

          if (response.statusCode == 200 || response.statusCode == 302) {
            await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
            syncedCount++;
          }
        } catch (_) {
          break;
        }
      }
    } finally {
      _isSyncing = false;
    }
    return syncedCount;
  }

  /// 1. TÉLÉCHARGE L'ENVIRONNEMENT D'UN ENSEIGNANT VIA SON TEACHER_ID
  Future<int> fetchTeacherEnvironment(String teacherId) async {
    final db = await DatabaseHelper.instance.database;
    final prof = await db.query('profile', limit: 1);
    if (prof.isEmpty) throw Exception("Profil introuvable");

    final url = prof.first['sheets_web_app_url'] as String;
    if (url.isEmpty) throw Exception("URL Google Sheets manquante");

    final response = await _dio.get(url, queryParameters: {
      'action': 'GET_TEACHER_ENV',
      'teacher_id': teacherId.trim().toUpperCase(),
    });

    if (response.statusCode == 200) {
      final data = response.data;

      // Mise à jour Profil
      if (data['profile'] != null) {
        final p = data['profile'];
        await db.update('profile', {
          'teacher_id': p['teacher_id'],
          'nom': p['nom'],
          'prenoms': p['prenoms'],
          'etablissement': p['etablissement'],
          'contact': p['contact'],
          'taux_taxe_pourcent': (p['taux_taxe_pourcent'] as num).toDouble(),
        });
      }

      // Mise à jour Classes
      int classesCount = 0;
      if (data['classes'] != null) {
        final List clsList = data['classes'];
        for (var c in clsList) {
          final id = c['id'].toString();
          final existing = await db.query('classes', where: 'id = ?', whereArgs: [id]);
          final classMap = {
            'id': id,
            'nom_classe': c['nom_classe'].toString(),
            'matiere': c['matiere'].toString(),
            'taux_horaire': (c['taux_horaire'] as num).toDouble(),
            'annee_scolaire': c['annee_scolaire'].toString(),
            'onglet_progression': c['onglet_progression'] ?? '',
          };

          if (existing.isEmpty) {
            await db.insert('classes', classMap);
          } else {
            await db.update('classes', classMap, where: 'id = ?', whereArgs: [id]);
          }
          classesCount++;
        }
      }
      return classesCount;
    } else {
      throw Exception("Erreur de connexion (Code ${response.statusCode})");
    }
  }

  /// 2. TÉLÉCHARGE LA PROGRESSION CLASSE PAR CLASSE
  Future<int> fetchClassProgression(String classId, String className, String sheetName) async {
    final db = await DatabaseHelper.instance.database;
    final prof = await db.query('profile', limit: 1);
    if (prof.isEmpty) throw Exception("Profil introuvable");

    final url = prof.first['sheets_web_app_url'] as String;
    if (url.isEmpty) throw Exception("URL Google Sheets manquante");

    // Utilise le nom d'onglet dédié s'il existe, sinon le nom de la classe
    final targetSheet = sheetName.isNotEmpty ? sheetName : className;

    final response = await _dio.get(url, queryParameters: {
      'action': 'GET_CLASS_PROGRESSION',
      'sheet_name': targetSheet,
    });

    if (response.statusCode == 200) {
      final data = response.data;
      final List lessons = data['lessons'] ?? [];

      if (lessons.isEmpty) return 0;

      int count = 0;
      for (var l in lessons) {
        final sem = (l['semaine_numero'] as num).toInt();
        final chap = (l['chapitre'] ?? '').toString();
        final titre = (l['titre_lecon'] ?? '').toString();
        final obj = (l['objectifs'] ?? '').toString();
        final vol = (l['volume_horaire'] as num?)?.toDouble() ?? 2.0;

        final existing = await db.query(
          'syllabus_lessons',
          where: 'class_id = ? AND semaine_numero = ?',
          whereArgs: [classId, sem],
        );

        if (existing.isEmpty) {
          await db.insert('syllabus_lessons', {
            'id': const Uuid().v4(),
            'class_id': classId,
            'semaine_numero': sem,
            'chapitre': chap.isEmpty ? "Semaine $sem" : chap,
            'titre_lecon': titre,
            'objectifs': obj,
            'volume_horaire': vol,
            'statut': 'A_VENIR',
            'date_realisee': null,
            'ordre_sequence': sem * 10,
          });
          count++;
        } else {
          // Met à jour les libellés sans toucher au statut 'FAIT'
          await db.update(
            'syllabus_lessons',
            {
              'chapitre': chap.isEmpty ? "Semaine $sem" : chap,
              'titre_lecon': titre,
              'objectifs': obj,
              'volume_horaire': vol,
            },
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
          count++;
        }
      }
      return count;
    } else {
      throw Exception("Erreur de téléchargement : ${response.statusCode}");
    }
  }
}