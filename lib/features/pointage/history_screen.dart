// lib/features/pointage/history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/models.dart';
import 'dashboard_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final currencyFmt = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
  List<AttendanceRecord> _records = [];
  Map<String, ClassEntity> _classesMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final db = await DatabaseHelper.instance.database;

    final clsRows = await db.query('classes');
    final classesList = clsRows.map((e) => ClassEntity.fromMap(e)).toList();
    _classesMap = {for (var c in classesList) c.id: c};

    final rows = await db.query('attendance_records', orderBy: 'date_cours DESC, created_at DESC');

    setState(() {
      _records = rows.map((e) => AttendanceRecord.fromMap(e)).toList();
      _loading = false;
    });
  }

  Future<void> _deleteRecord(AttendanceRecord record) async {
    final c = _classesMap[record.classId];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer cette séance ?"),
        content: Text("Voulez-vous supprimer le pointage du ${record.dateCours} pour ${c?.nomClasse ?? 'cette classe'} ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final db = await DatabaseHelper.instance.database;

              // Si cette séance était liée à une leçon du syllabus, on la remet à A_VENIR
              if (record.lessonId != null) {
                await db.update(
                  'syllabus_lessons',
                  {'statut': 'A_VENIR', 'date_realisee': null},
                  where: 'id = ?',
                  whereArgs: [record.lessonId],
                );
              }

              await db.delete('attendance_records', where: 'id = ?', whereArgs: [record.id]);
              await _loadHistory();
              await ref.read(dashboardProvider.notifier).refreshData();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Séance supprimée.')),
                );
              }
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // DIALOGUE INTELLIGENT RELIÉ À LA PROGRESSION OFFICIELLE
  void _showSessionDialog({AttendanceRecord? recordToEdit}) async {
    if (_classesMap.isEmpty) return;

    final isEditing = recordToEdit != null;
    String selectedClassId = isEditing ? recordToEdit.classId : _classesMap.keys.first;

    final db = await DatabaseHelper.instance.database;

    // Charger les leçons officielles de cette classe
    Future<List<SyllabusLesson>> getLessonsForClass(String classId) async {
      final rows = await db.query(
        'syllabus_lessons',
        where: 'class_id = ?',
        whereArgs: [classId],
        orderBy: 'ordre_sequence ASC',
      );
      return rows.map((e) => SyllabusLesson.fromMap(e)).toList();
    }

    List<SyllabusLesson> classLessons = await getLessonsForClass(selectedClassId);

    // Identifiant de la leçon sélectionnée ("AUTRE" si remarque libre)
    String selectedLessonChoice = isEditing
        ? (recordToEdit.lessonId ?? "AUTRE")
        : (classLessons.isNotEmpty ? classLessons.first.id : "AUTRE");

    final dateCtrl = TextEditingController(text: isEditing ? recordToEdit.dateCours : DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final debutCtrl = TextEditingController(text: isEditing ? recordToEdit.heureArrivee : "13:30");
    final finCtrl = TextEditingController(text: isEditing ? recordToEdit.heureDepart : "16:30");
    final heuresCtrl = TextEditingController(text: isEditing ? recordToEdit.heuresValidees.toString() : "3.0");
    final customRemarqueCtrl = TextEditingController(text: isEditing ? (recordToEdit.remarque ?? "") : "Séance d'enseignement");

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isAutre = selectedLessonChoice == "AUTRE";

          return AlertDialog(
            title: Text(isEditing ? "Modifier la séance" : "Régulariser une séance passée",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. CLASSE CONCERNÉE
                  DropdownButtonFormField<String>(
                    value: _classesMap.containsKey(selectedClassId) ? selectedClassId : _classesMap.keys.first,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: "Classe", border: OutlineInputBorder()),
                    items: _classesMap.values.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text("${c.nomClasse} (${c.matiere})", overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (val) async {
                      if (val != null) {
                        final lessons = await getLessonsForClass(val);
                        setDialogState(() {
                          selectedClassId = val;
                          classLessons = lessons;
                          selectedLessonChoice = lessons.isNotEmpty ? lessons.first.id : "AUTRE";

                          final c = _classesMap[val];
                          if (c != null) {
                            if (c.nomClasse.contains("GC")) {
                              debutCtrl.text = "13:30";
                              finCtrl.text = "16:30";
                              heuresCtrl.text = "3.0";
                            } else {
                              debutCtrl.text = "13:30";
                              finCtrl.text = "15:30";
                              heuresCtrl.text = "2.0";
                            }
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // 2. LISTE DÉROULANTE DE LA PROGRESSION (OU AUTRE)
                  DropdownButtonFormField<String>(
                    value: (classLessons.any((l) => l.id == selectedLessonChoice) || selectedLessonChoice == "AUTRE")
                        ? selectedLessonChoice
                        : "AUTRE",
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Leçon au programme (Syllabus)",
                      helperText: "Sélectionnez la leçon ou 'Autre'",
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      ...classLessons.map((l) {
                        return DropdownMenuItem<String>(
                          value: l.id,
                          child: Text(
                            "S${l.semaineNumero} : ${l.titreLecon}",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        );
                      }),
                      const DropdownMenuItem<String>(
                        value: "AUTRE",
                        child: Text("✍️ [ Autre séance / Remarque libre ]", style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedLessonChoice = val;
                          if (val != "AUTRE") {
                            final match = classLessons.firstWhere((l) => l.id == val);
                            customRemarqueCtrl.text = "${match.chapitre} - ${match.titreLecon}";
                            heuresCtrl.text = match.volumeHoraire.toString();
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  // Si "AUTRE" est choisi : champ de saisie libre
                  if (isAutre) ...[
                    TextField(
                      controller: customRemarqueCtrl,
                      decoration: const InputDecoration(
                        labelText: "Précisez l'intitulé / Thème du cours",
                        hintText: "Exemple: Séance de révision",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // 3. DATE
                  TextField(
                    controller: dateCtrl,
                    decoration: const InputDecoration(labelText: "Date (AAAA-MM-JJ)", helperText: "Exemple: 2026-10-15", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),

                  // 4. HORAIRES
                  Row(
                    children: [
                      Expanded(child: TextField(controller: debutCtrl, decoration: const InputDecoration(labelText: "Début", border: OutlineInputBorder()))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: finCtrl, decoration: const InputDecoration(labelText: "Fin", border: OutlineInputBorder()))),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 5. VOLUME HORAIRE
                  TextField(
                    controller: heuresCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Volume horaire (H)", border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                onPressed: () async {
                  final classe = _classesMap[selectedClassId] ?? _classesMap.values.first;
                  final duree = double.tryParse(heuresCtrl.text.trim()) ?? 2.0;

                  // Calcul financier automatique (Taux, Brut, Taxe 7.5%, Net)
                  final montantBrut = duree * classe.tauxHoraire;
                  final montantTaxe = montantBrut * 0.075;
                  final montantNet = montantBrut - montantTaxe;

                  final lessonIdToSave = selectedLessonChoice == "AUTRE" ? null : selectedLessonChoice;
                  final remarqueToSave = selectedLessonChoice == "AUTRE"
                      ? customRemarqueCtrl.text.trim()
                      : () {
                          final match = classLessons.where((l) => l.id == selectedLessonChoice);
                          return match.isNotEmpty ? "${match.first.chapitre} - ${match.first.titreLecon}" : customRemarqueCtrl.text.trim();
                        }();

                  if (isEditing) {
                    await db.update(
                      'attendance_records',
                      {
                        'class_id': selectedClassId,
                        'lesson_id': lessonIdToSave,
                        'date_cours': dateCtrl.text.trim(),
                        'heure_arrivee': debutCtrl.text.trim(),
                        'heure_depart': finCtrl.text.trim(),
                        'heures_validees': duree,
                        'taux_applique': classe.tauxHoraire,
                        'montant_total': montantBrut,
                        'montant_taxe': montantTaxe,
                        'montant_net': montantNet,
                        'remarque': remarqueToSave,
                      },
                      where: 'id = ?',
                      whereArgs: [recordToEdit.id],
                    );
                  } else {
                    await db.insert('attendance_records', {
                      'id': const Uuid().v4(),
                      'teacher_id': '1001',
                      'class_id': selectedClassId,
                      'lesson_id': lessonIdToSave,
                      'date_cours': dateCtrl.text.trim(),
                      'heure_arrivee': debutCtrl.text.trim(),
                      'heure_depart': finCtrl.text.trim(),
                      'heures_validees': duree,
                      'taux_applique': classe.tauxHoraire,
                      'montant_total': montantBrut,
                      'montant_taxe': montantTaxe,
                      'montant_net': montantNet,
                      'statut_paiement': 'NON_PAYE',
                      'remarque': remarqueToSave,
                      'created_at': DateTime.now().toIso8601String(),
                    });
                  }

                  // COCHE AUTOMATIQUEMENT LA LEÇON DU PROGRAMME EN 'FAIT'
                  if (lessonIdToSave != null) {
                    await db.update(
                      'syllabus_lessons',
                      {
                        'statut': 'FAIT',
                        'date_realisee': dateCtrl.text.trim(),
                      },
                      where: 'id = ?',
                      whereArgs: [lessonIdToSave],
                    );
                  }

                  Navigator.pop(ctx);
                  await _loadHistory();
                  await ref.read(dashboardProvider.notifier).refreshData();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEditing ? 'Séance et programme mis à jour !' : 'Séance enregistrée dans le programme !'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                },
                child: Text(isEditing ? "Enregistrer les modifications" : "Enregistrer",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique des Émargements", style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task_rounded, color: Colors.white),
            tooltip: 'Régulariser une séance passée',
            onPressed: () => _showSessionDialog(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.black26),
                      const SizedBox(height: 12),
                      const Text("Aucun émargement enregistré.", style: TextStyle(color: Colors.black54)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text("Régulariser une séance passée", style: TextStyle(color: Colors.white)),
                        onPressed: () => _showSessionDialog(),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final r = _records[index];
                    final c = _classesMap[r.classId];
                    final isPaid = r.statutPaiement == 'PAYE';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: isPaid ? const Color(0xFF10B981).withOpacity(0.5) : Colors.black12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPaid ? const Color(0xFF10B981) : const Color(0xFF0F172A),
                          child: Text(
                            "${r.heuresValidees}H",
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          "${c?.nomClasse ?? 'Classe'} • ${r.dateCours}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${r.heureArrivee} - ${r.heureDepart}", style: const TextStyle(fontSize: 11, color: Colors.black54)),
                            const SizedBox(height: 2),
                            Text(r.remarque ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 2),
                            Text(
                              "Net : ${currencyFmt.format(r.montantNet)}  (Brut: ${currencyFmt.format(r.montantTotal)})",
                              style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Color(0xFF0F172A), size: 20),
                              tooltip: 'Modifier cette séance',
                              onPressed: () => _showSessionDialog(recordToEdit: r),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              tooltip: 'Supprimer ce pointage',
                              onPressed: () => _deleteRecord(r),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}