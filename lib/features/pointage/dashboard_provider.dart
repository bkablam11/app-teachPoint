// lib/features/pointage/dashboard_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/models.dart';
import '../../core/network/sync_service.dart';

class DashboardState {
  final TeacherProfile? profile;
  final List<ClassEntity> allClasses;
  final ClassEntity? selectedClass;
  final SyllabusLesson? nextLesson;
  final double totalMonthBrut;
  final double totalMonthTaxe;
  final double totalMonthNet;
  final double totalMonthHours;
  final int pendingSyncCount;
  final bool isClockedIn;
  final DateTime? clockInTime;

  DashboardState({
    this.profile,
    this.allClasses = const [],
    this.selectedClass,
    this.nextLesson,
    this.totalMonthBrut = 0.0,
    this.totalMonthTaxe = 0.0,
    this.totalMonthNet = 0.0,
    this.totalMonthHours = 0.0,
    this.pendingSyncCount = 0,
    this.isClockedIn = false,
    this.clockInTime,
  });

  DashboardState copyWith({
    TeacherProfile? profile,
    List<ClassEntity>? allClasses,
    ClassEntity? selectedClass,
    SyllabusLesson? nextLesson,
    double? totalMonthBrut,
    double? totalMonthTaxe,
    double? totalMonthNet,
    double? totalMonthHours,
    int? pendingSyncCount,
    bool? isClockedIn,
    DateTime? clockInTime,
  }) {
    return DashboardState(
      profile: profile ?? this.profile,
      allClasses: allClasses ?? this.allClasses,
      selectedClass: selectedClass ?? this.selectedClass,
      nextLesson: nextLesson ?? this.nextLesson,
      totalMonthBrut: totalMonthBrut ?? this.totalMonthBrut,
      totalMonthTaxe: totalMonthTaxe ?? this.totalMonthTaxe,
      totalMonthNet: totalMonthNet ?? this.totalMonthNet,
      totalMonthHours: totalMonthHours ?? this.totalMonthHours,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
      isClockedIn: isClockedIn ?? this.isClockedIn,
      clockInTime: clockInTime ?? this.clockInTime,
    );
  }
}

class DashboardNotifier extends StateNotifier<AsyncValue<DashboardState>> {
  DashboardNotifier() : super(const AsyncValue.loading()) {
    refreshData();
  }

  void selectClass(ClassEntity classe) async {
    if (state.value == null) return;
    state = AsyncValue.data(state.value!.copyWith(selectedClass: classe));
    await refreshData(chosenClassId: classe.id);

    final db = await DatabaseHelper.instance.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM syllabus_lessons WHERE class_id = ?', [classe.id]),
    ) ?? 0;

    if (count == 0) {
      try {
        await SyncService.instance.fetchClassProgression(classe.id, classe.nomClasse, classe.ongletProgression);
        await refreshData(chosenClassId: classe.id);
      } catch (_) {}
    }
  }

  Future<void> refreshData({String? chosenClassId}) async {
    try {
      final db = await DatabaseHelper.instance.database;

      final profRows = await db.query('profile', limit: 1);
      final profile = profRows.isNotEmpty ? TeacherProfile.fromMap(profRows.first) : null;

      final clsRows = await db.query('classes', orderBy: 'nom_classe ASC');
      final classes = clsRows.map((e) => ClassEntity.fromMap(e)).toList();

      ClassEntity? currentClass;
      if (chosenClassId != null) {
        currentClass = classes.firstWhere((c) => c.id == chosenClassId, orElse: () => classes.first);
      } else if (state.value?.selectedClass != null) {
        currentClass = classes.firstWhere((c) => c.id == state.value!.selectedClass!.id, orElse: () => classes.first);
      } else if (classes.isNotEmpty) {
        currentClass = classes.first;
      }

      SyllabusLesson? nextLesson;
      if (currentClass != null) {
        final lessonRows = await db.query(
          'syllabus_lessons',
          where: 'class_id = ? AND statut = ?',
          whereArgs: [currentClass.id, 'A_VENIR'],
          orderBy: 'ordre_sequence ASC',
          limit: 1,
        );
        if (lessonRows.isNotEmpty) {
          nextLesson = SyllabusLesson.fromMap(lessonRows.first);
        }
      }

      // NE CALCULE QUE LES HEURES DU MOIS QUI NE SONT PAS ENCORE MARQUÉES COMME PAYÉES
      final stats = await db.rawQuery('''
        SELECT 
          SUM(heures_validees) as sum_h, 
          SUM(montant_total) as sum_brut,
          SUM(montant_taxe) as sum_taxe,
          SUM(montant_net) as sum_net
        FROM attendance_records 
        WHERE (statut_paiement IS NULL OR statut_paiement = 'NON_PAYE')
      ''');

      final totalHours = (stats.first['sum_h'] as num?)?.toDouble() ?? 0.0;
      final totalBrut = (stats.first['sum_brut'] as num?)?.toDouble() ?? 0.0;
      final totalTaxe = (stats.first['sum_taxe'] as num?)?.toDouble() ?? 0.0;
      final totalNet = (stats.first['sum_net'] as num?)?.toDouble() ?? 0.0;

      final queueCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM sync_queue WHERE status = ?', ['PENDING']),
          ) ?? 0;

      state = AsyncValue.data(
        DashboardState(
          profile: profile,
          allClasses: classes,
          selectedClass: currentClass,
          nextLesson: nextLesson,
          totalMonthHours: totalHours,
          totalMonthBrut: totalBrut,
          totalMonthTaxe: totalTaxe,
          totalMonthNet: totalNet > 0 ? totalNet : (totalBrut - totalTaxe),
          pendingSyncCount: queueCount,
          isClockedIn: state.value?.isClockedIn ?? false,
          clockInTime: state.value?.clockInTime,
        ),
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void startClockIn() {
    final current = state.value ?? DashboardState();
    state = AsyncValue.data(
      current.copyWith(
        isClockedIn: true,
        clockInTime: DateTime.now(),
      ),
    );
  }

  void cancelClockIn() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
        isClockedIn: false,
        clockInTime: null,
      ),
    );
  }

  // RÉINITIALISATION APRÈS PAIEMENT DE LA VACATION
  Future<int> resetMonthVacationsAsPaid() async {
    final db = await DatabaseHelper.instance.database;
    final count = await db.update(
      'attendance_records',
      {'statut_paiement': 'PAYE'},
      where: 'statut_paiement IS NULL OR statut_paiement = ?',
      whereArgs: ['NON_PAYE'],
    );

    // Rafraîchit immédiatement le tableau de bord à 0 FCFA
    await refreshData();
    return count;
  }

  Future<void> completeClockOut() async {
    final s = state.value;
    if (s == null || !s.isClockedIn || s.clockInTime == null || s.selectedClass == null) return;

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

    final arrivee = "${s.clockInTime!.hour.toString().padLeft(2, '0')}:${s.clockInTime!.minute.toString().padLeft(2, '0')}";
    final depart = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final dateCours = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final diffMinutes = now.difference(s.clockInTime!).inMinutes;
    double duree = diffMinutes / 60.0;
    if (duree < 0.25) {
      duree = s.nextLesson?.volumeHoraire ?? 2.0;
    } else {
      duree = (duree * 2).round() / 2;
    }

    final taux = s.selectedClass!.tauxHoraire;
    final montantBrut = duree * taux;
    final taxePourcent = s.profile?.tauxTaxePourcent ?? 7.5;
    final montantTaxe = montantBrut * (taxePourcent / 100.0);
    final montantNet = montantBrut - montantTaxe;

    final recordId = const Uuid().v4();
    final teacherMatricule = s.profile?.teacherId ?? '1001';

    final recordData = {
      'id': recordId,
      'teacher_id': teacherMatricule,
      'class_id': s.selectedClass!.id,
      'lesson_id': s.nextLesson?.id,
      'date_cours': dateCours,
      'heure_arrivee': arrivee,
      'heure_depart': depart,
      'heures_validees': duree,
      'taux_applique': taux,
      'montant_total': montantBrut,
      'montant_taxe': montantTaxe,
      'montant_net': montantNet,
      'statut_paiement': 'NON_PAYE',
      'remarque': s.nextLesson != null
          ? "${s.nextLesson!.chapitre} - ${s.nextLesson!.titreLecon}"
          : "Séance d'enseignement",
      'created_at': now.toIso8601String(),
    };

    await db.transaction((txn) async {
      await txn.insert('attendance_records', recordData);

      if (s.nextLesson != null) {
        await txn.update(
          'syllabus_lessons',
          {
            'statut': 'FAIT',
            'date_realisee': dateCours,
          },
          where: 'id = ?',
          whereArgs: [s.nextLesson!.id],
        );
      }
    });

    await SyncService.instance.enqueue('CLOCK_IN_OUT', {
      ...recordData,
      'nom_classe': s.selectedClass!.nomClasse,
      'matiere': s.selectedClass!.matiere,
      'enseignant': "${s.profile?.nom} ${s.profile?.prenoms}",
    });

    state = AsyncValue.data(
      s.copyWith(
        isClockedIn: false,
        clockInTime: null,
      ),
    );

    await refreshData();
  }
}

final dashboardProvider = StateNotifierProvider<DashboardNotifier, AsyncValue<DashboardState>>((ref) {
  return DashboardNotifier();
});