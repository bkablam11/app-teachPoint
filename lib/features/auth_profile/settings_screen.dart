// lib/features/auth_profile/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/database_helper.dart';
import '../../core/database/models.dart';
import '../pointage/dashboard_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nomCtrl;
  late TextEditingController _prenomsCtrl;
  late TextEditingController _etabCtrl;
  late TextEditingController _contactCtrl;
  late TextEditingController _taxeCtrl;

  List<ClassEntity> _classesList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = await DatabaseHelper.instance.database;
    final profList = await db.query('profile', limit: 1);
    final prof = profList.isNotEmpty ? TeacherProfile.fromMap(profList.first) : null;

    final clsRows = await db.query('classes', orderBy: 'nom_classe ASC');
    _classesList = clsRows.map((e) => ClassEntity.fromMap(e)).toList();

    _nomCtrl = TextEditingController(text: prof?.nom ?? 'KABLAM');
    _prenomsCtrl = TextEditingController(text: prof?.prenoms ?? 'Edjabrou Ulrich Blanchard');
    _etabCtrl = TextEditingController(text: prof?.etablissement ?? 'ESIAS POLYTECHNIQUE (Groupe Adama Sanogo)');
    _contactCtrl = TextEditingController(text: prof?.contact ?? '+225 07 00 00 00 00');
    _taxeCtrl = TextEditingController(text: (prof?.tauxTaxePourcent ?? 7.5).toString());

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomsCtrl.dispose();
    _etabCtrl.dispose();
    _contactCtrl.dispose();
    _taxeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final db = await DatabaseHelper.instance.database;
    await db.update('profile', {
      'nom': _nomCtrl.text.trim(),
      'prenoms': _prenomsCtrl.text.trim(),
      'etablissement': _etabCtrl.text.trim(),
      'contact': _contactCtrl.text.trim(),
      'taux_taxe_pourcent': double.tryParse(_taxeCtrl.text.trim()) ?? 7.5,
    });

    await ref.read(dashboardProvider.notifier).refreshData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil enregistré avec succès !'), backgroundColor: Color(0xFF10B981)),
      );
      Navigator.pop(context);
    }
  }

  // BOÎTE DE DIALOGUE POUR RÉINITIALISER LE MOIS PAYÉ
  void _confirmResetMonth() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.monetization_on_outlined, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text("Vacations Payées ?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "Avez-vous perçu votre virement/chèque de vacation pour ce mois ?\n\nCette action remettra le solde affiché à 0 FCFA pour démarrer le nouveau mois. Vos séances passées restent archivées et votre progression de cours continue.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              Navigator.pop(ctx);
              final count = await ref.read(dashboardProvider.notifier).resetMonthVacationsAsPaid();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$count séances archivées comme payées. Compteur remis à 0 FCFA !'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text("Oui, remettre à 0 FCFA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
// Dans lib/features/auth_profile/settings_screen.dart

  void _showClassDialog({ClassEntity? classToEdit}) {
    final isEditing = classToEdit != null;

    // LISTES DÉROULANTES NORMÉES POUR LE BTS
    final classesDisponibles = [
      "1A BTS FCGE",
      "2A BTS FCGE",
      "1A BTS IDA",
      "2A BTS IDA",
      "1A BTS GC-BAT",
      "2A BTS GC-BAT",
      "1A BTS RHCOM",
      "2A BTS RHCOM",
      "1A BTS RIT",
      "2A BTS RIT",
      "1A BTS GEC",
      "2A BTS GEC",
      "Autre classe..."
    ];

    final matieresDisponibles = [
      "Mathématiques Générales",
      "Mathématiques Financières & R.O",
      "Mathématiques Financières",
      "Recherche Opérationnelle",
      "Statistiques et Probabilités",
      "Résistance des Matériaux & Béton Armé",
      "Algorithmique et Programmation",
      "Bases de Données & SQL",
      "Comptabilité Générale",
      "Autre matière..."
    ];

    String selectedNomClasse = classesDisponibles.contains(classToEdit?.nomClasse)
        ? classToEdit!.nomClasse
        : (isEditing ? "Autre classe..." : "1A BTS FCGE");

    String selectedMatiere = matieresDisponibles.contains(classToEdit?.matiere)
        ? classToEdit!.matiere
        : (isEditing ? "Autre matière..." : "Mathématiques Générales");

    final customClasseCtrl = TextEditingController(text: isEditing ? classToEdit!.nomClasse : '');
    final customMatiereCtrl = TextEditingController(text: isEditing ? classToEdit!.matiere : '');
    final tauxCtrl = TextEditingController(text: classToEdit != null ? classToEdit.tauxHoraire.toStringAsFixed(0) : "4000");

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isCustomClasse = selectedNomClasse == "Autre classe...";
          final isCustomMatiere = selectedMatiere == "Autre matière...";

          return AlertDialog(
            title: Text(isEditing ? "Modifier la classe" : "Ajouter une classe",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. LISTE DÉROULANTE POUR LA CLASSE
                  DropdownButtonFormField<String>(
                    value: selectedNomClasse,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: "Niveau & Filière (Classe)", border: OutlineInputBorder()),
                    items: classesDisponibles.map((cls) {
                      return DropdownMenuItem(value: cls, child: Text(cls, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedNomClasse = val);
                    },
                  ),
                  if (isCustomClasse) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: customClasseCtrl,
                      decoration: const InputDecoration(labelText: "Préciser la classe", border: OutlineInputBorder()),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // 2. LISTE DÉROULANTE POUR LA MATIÈRE
                  DropdownButtonFormField<String>(
                    value: selectedMatiere,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: "Discipline / Matière", border: OutlineInputBorder()),
                    items: matieresDisponibles.map((mat) {
                      return DropdownMenuItem(value: mat, child: Text(mat, style: const TextStyle(fontSize: 12)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedMatiere = val);
                    },
                  ),
                  if (isCustomMatiere) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: customMatiereCtrl,
                      decoration: const InputDecoration(labelText: "Préciser la matière", border: OutlineInputBorder()),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // 3. TAUX HORAIRE
                  TextField(
                    controller: tauxCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Taux horaire Brut (FCFA)", border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
                onPressed: () async {
                  final finalClasse = isCustomClasse ? customClasseCtrl.text.trim() : selectedNomClasse;
                  final finalMatiere = isCustomMatiere ? customMatiereCtrl.text.trim() : selectedMatiere;

                  if (finalClasse.isEmpty) return;

                  // GÉNÉRATION AUTOMATIQUE ET INFAILLIBLE DU NOM D'ONGLET
                  final targetOnglet = "PROG_${finalClasse.replaceAll(' ', '_').replaceAll('-', '_').toUpperCase()}";

                  final db = await DatabaseHelper.instance.database;

                  if (isEditing) {
                    await db.update(
                      'classes',
                      {
                        'nom_classe': finalClasse,
                        'matiere': finalMatiere,
                        'taux_horaire': double.tryParse(tauxCtrl.text.trim()) ?? 4000.0,
                        'onglet_progression': targetOnglet,
                      },
                      where: 'id = ?',
                      whereArgs: [classToEdit.id],
                    );
                  } else {
                    await db.insert('classes', {
                      'id': const Uuid().v4(),
                      'nom_classe': finalClasse,
                      'matiere': finalMatiere,
                      'taux_horaire': double.tryParse(tauxCtrl.text.trim()) ?? 4000.0,
                      'annee_scolaire': '2026-2027',
                      'onglet_progression': targetOnglet,
                    });
                  }

                  Navigator.pop(ctx);
                  await _loadData();
                  await ref.read(dashboardProvider.notifier).refreshData();
                },
                child: Text(isEditing ? "Modifier" : "Ajouter", style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }
  void _confirmDeleteClass(ClassEntity classe) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Supprimer ${classe.nomClasse} ?"),
        content: const Text("Cette action supprimera la classe ainsi que son cahier de texte associé."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final db = await DatabaseHelper.instance.database;
              await db.transaction((txn) async {
                await txn.delete('attendance_records', where: 'class_id = ?', whereArgs: [classe.id]);
                await txn.delete('syllabus_lessons', where: 'class_id = ?', whereArgs: [classe.id]);
                await txn.delete('classes', where: 'id = ?', whereArgs: [classe.id]);
              });

              Navigator.pop(ctx);
              await _loadData();
              await ref.read(dashboardProvider.notifier).refreshData();
            },
            child: const Text("Supprimer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil Enseignant & Classes", style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle("1. IDENTITÉ DE L'ENSEIGNANT"),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nomCtrl,
                decoration: const InputDecoration(labelText: "Nom de famille", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Champ requis" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _prenomsCtrl,
                decoration: const InputDecoration(labelText: "Prénoms", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Champ requis" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactCtrl,
                decoration: const InputDecoration(labelText: "Contact / Téléphone", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _etabCtrl,
                decoration: const InputDecoration(labelText: "Établissement", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _taxeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Retenue Fiscale / Taxe à la source (%)",
                  suffixText: "%",
                  helperText: "Exemple : 7.5% en Côte d'Ivoire (AIRSI) déduit du brut",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle("2. VOS CLASSES (${_classesList.length})"),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFF10B981), size: 28),
                    tooltip: "Ajouter une classe",
                    onPressed: () => _showClassDialog(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ..._classesList.map((c) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(c.nomClasse, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text("${c.matiere} • ${c.tauxHoraire.toStringAsFixed(0)} FCFA/h",
                          style: const TextStyle(fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Color(0xFF0F172A), size: 20),
                            onPressed: () => _showClassDialog(classToEdit: c),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () => _confirmDeleteClass(c),
                          ),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 24),

              // SECTION 3 : CLÔTURE MENSUELLE & REMISE À ZÉRO
              _buildSectionTitle("3. CLÔTURE DU MOIS & PAIEMENT"),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Vous avez reçu votre salaire de vacation ?",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Cliquez ci-dessous pour archiver les heures perçues et remettre le compteur du tableau de bord à 0 FCFA pour le mois suivant.",
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      ),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text("Marquer comme payé & Repartir à 0 FCFA", style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _confirmResetMonth,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _saveProfile,
                child: const Text("ENREGISTRER LE PROFIL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A), letterSpacing: 0.5),
    );
  }
}