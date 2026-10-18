// lib/features/syllabus/syllabus_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/models.dart';
import '../../core/network/sync_service.dart';
import '../pointage/dashboard_provider.dart';

class SyllabusScreen extends ConsumerStatefulWidget {
  final ClassEntity selectedClass;
  const SyllabusScreen({super.key, required this.selectedClass});

  @override
  ConsumerState<SyllabusScreen> createState() => _SyllabusScreenState();
}

class _SyllabusScreenState extends ConsumerState<SyllabusScreen> {
  List<SyllabusLesson> _lessons = [];
  bool _loading = true;
  bool _syncingCloud = false;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  Future<void> _loadLessons() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      'syllabus_lessons',
      where: 'class_id = ?',
      whereArgs: [widget.selectedClass.id],
      orderBy: 'ordre_sequence ASC',
    );

    setState(() {
      _lessons = rows.map((e) => SyllabusLesson.fromMap(e)).toList();
      _loading = false;
    });
  }

  // TÉLÉCHARGEMENT SPÉCIFIQUE À CETTE CLASSE
Future<void> _syncCurrentClassProgression() async {
    setState(() => _syncingCloud = true);
    try {
      final targetOnglet = widget.selectedClass.ongletProgression.isNotEmpty
          ? widget.selectedClass.ongletProgression
          : "PROG_${widget.selectedClass.nomClasse.replaceAll(' ', '_').replaceAll('-', '_').toUpperCase()}";

      final count = await SyncService.instance.fetchClassProgression(
        widget.selectedClass.id,
        widget.selectedClass.nomClasse,
        targetOnglet,
      );

      await _loadLessons();
      await ref.read(dashboardProvider.notifier).refreshData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count séances téléchargées pour ${widget.selectedClass.nomClasse} !'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _syncingCloud = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doneCount = _lessons.where((l) => l.statut == 'FAIT').length;
    final progress = _lessons.isEmpty ? 0.0 : doneCount / _lessons.length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Cahier de texte : ${widget.selectedClass.nomClasse}",
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            Text(widget.selectedClass.matiere, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: _syncingCloud
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.cloud_download_rounded, color: Colors.white),
            tooltip: 'Télécharger la progression de cette classe',
            onPressed: _syncingCloud ? null : _syncCurrentClassProgression,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A)))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Progression : $doneCount / ${_lessons.length} séances validées",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                          Text("${(progress * 100).toStringAsFixed(0)} %",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF10B981))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.black12,
                        color: const Color(0xFF10B981),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: _lessons.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.table_chart_outlined, size: 48, color: Colors.black26),
                                const SizedBox(height: 12),
                                Text(
                                  "Aucune leçon pour ${widget.selectedClass.nomClasse}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "L'onglet cible est : ${widget.selectedClass.ongletProgression.isEmpty ? widget.selectedClass.nomClasse : widget.selectedClass.ongletProgression}\nClique sur le bouton pour télécharger la progression :",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                                  icon: const Icon(Icons.cloud_download_rounded, color: Colors.white),
                                  label: Text("Télécharger ${widget.selectedClass.nomClasse}", style: const TextStyle(color: Colors.white)),
                                  onPressed: _syncCurrentClassProgression,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _lessons.length,
                          itemBuilder: (context, index) {
                            final l = _lessons[index];
                            final isDone = l.statut == 'FAIT';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(color: isDone ? const Color(0xFF10B981) : Colors.black12),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isDone ? const Color(0xFF10B981) : const Color(0xFF0F172A),
                                  child: Text(
                                    "S${l.semaineNumero}",
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(
                                  l.chapitre,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: isDone ? const Color(0xFF10B981) : const Color(0xFF0F172A),
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l.titreLecon, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                    const SizedBox(height: 4),
                                    if (l.objectifs != null && l.objectifs!.isNotEmpty)
                                      Text("Obj : ${l.objectifs}",
                                          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black45)),
                                    if (isDone && l.dateRealisee != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text("Fait le : ${l.dateRealisee}",
                                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                trailing: Icon(
                                  isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: isDone ? const Color(0xFF10B981) : Colors.black26,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}