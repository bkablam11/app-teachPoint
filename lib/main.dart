// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:printing/printing.dart';

import 'core/network/sync_service.dart';
import 'core/updater/update_service.dart';
import 'core/database/database_helper.dart';
import 'core/database/models.dart';
import 'features/reports_pdf/pdf_service.dart';
import 'features/pointage/dashboard_provider.dart';
import 'features/auth_profile/settings_screen.dart';
import 'features/syllabus/syllabus_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await initializeDateFormatting('fr_FR', null);
  SyncService.instance.initializeAutoSync();

  runApp(const ProviderScope(child: TeachPointApp()));
}

class TeachPointApp extends StatelessWidget {
  const TeachPointApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeachPoint',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0F172A),
          secondary: Color(0xFF10B981),
          tertiary: Color(0xFFF59E0B),
          surface: Colors.white,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final currencyFmt = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDirectUpdate(silent: true);
    });
  }

  Future<void> _checkDirectUpdate({bool silent = false}) async {
    try {
      final info = await UpdateService.instance.checkForUpdate();
      if (!mounted) return;

      if (info.hasUpdate) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("Mise à jour disponible"),
            content: Text("Version v${info.latestVersion}\n\n${info.changelog}"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fermer")),
            ],
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final dashState = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("TeachPoint", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            dashState.when(
              data: (data) => Text(
                data.profile != null ? "${data.profile!.prenoms} ${data.profile!.nom}" : "Professeur",
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          dashState.when(
            data: (d) => Container(
              margin: const EdgeInsets.only(right: 6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: d.pendingSyncCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    d.pendingSyncCount > 0 ? "En attente: ${d.pendingSyncCount}" : "Cloud OK",
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
            tooltip: 'Bordereau Général A4',
            onPressed: () => _printPdf(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            tooltip: 'Paramètres & Profil',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: dashState.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF0F172A))),
        error: (err, _) => Center(child: Text("Erreur: $err")),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            await ref.read(dashboardProvider.notifier).refreshData();
            await SyncService.instance.processQueue();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // SÉLECTEUR DE CLASSE INTERACTIF
                if (data.allClasses.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: data.selectedClass?.id,
                        hint: const Text("Sélectionner la classe"),
                        items: data.allClasses.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Text(
                              "📚 ${c.nomClasse} • ${c.matiere}",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                          );
                        }).toList(),
                        onChanged: (newId) {
                          if (newId != null) {
                            final chosen = data.allClasses.firstWhere((c) => c.id == newId);
                            ref.read(dashboardProvider.notifier).selectClass(chosen);
                          }
                        },
                      ),
                    ),
                  ),

                _buildFinanceCard(data),
                const SizedBox(height: 16),
                _buildSyllabusPreviewCard(context, data),
                const SizedBox(height: 24),
                _buildClockButton(context, data),
                const SizedBox(height: 24),
                _buildDetailsCard(data),
              ],
            ),
          ),
        ),
      ),
    );
  }

Widget _buildFinanceCard(DashboardState state) {
    final taxePct = state.profile?.tauxTaxePourcent ?? 7.5;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // EXPANDED ÉVITE DÉFINITIVEMENT LE DÉBORDEMENT DE 13 PIXELS
              Expanded(
                child: Text(
                  "NET À PERCEVOIR (APRÈS TAXE)",
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${state.totalMonthHours} H validées",
                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            currencyFmt.format(state.totalMonthNet),
            style: const TextStyle(
              color: Color(0xFF10B981),
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                "Brut : ${currencyFmt.format(state.totalMonthBrut)}",
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 10),
              Text(
                "•  Taxe ($taxePct%) : -${currencyFmt.format(state.totalMonthTaxe)}",
                style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Classe sélectionnée : ${state.selectedClass?.nomClasse ?? '-'} • Taux Brut : ${currencyFmt.format(state.selectedClass?.tauxHoraire ?? 0)}/h",
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSyllabusPreviewCard(BuildContext context, DashboardState state) {
    final lesson = state.nextLesson;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.menu_book_rounded, size: 18, color: Color(0xFF0F172A)),
                  SizedBox(width: 8),
                  Text(
                    "AU PROGRAMME DE CETTE CLASSE",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              if (state.selectedClass != null)
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SyllabusScreen(selectedClass: state.selectedClass!),
                      ),
                    );
                  },
                  child: const Text("Voir tout >",
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const Divider(height: 12),
          if (lesson != null) ...[
            Text(
              "Semaine ${lesson.semaineNumero} : ${lesson.chapitre}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              lesson.titreLecon,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            if (lesson.objectifs != null && lesson.objectifs!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                "Objectif : ${lesson.objectifs}",
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black45),
              ),
            ]
          ] else ...[
            const Text(
              "Toutes les leçons de cette classe sont validées !",
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClockButton(BuildContext context, DashboardState state) {
    final isClocked = state.isClockedIn;

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              if (!isClocked) {
                ref.read(dashboardProvider.notifier).startClockIn();
              } else {
                _confirmClockOut(context);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isClocked ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                boxShadow: [
                  BoxShadow(
                    color: (isClocked ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withOpacity(0.35),
                    blurRadius: 20,
                    spreadRadius: 4,
                  )
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isClocked ? Icons.stop_rounded : Icons.fingerprint_rounded,
                    size: 54,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isClocked ? "CLÔTURER\nLE COURS" : "POINTER\nL'ARRIVÉE",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (isClocked)
            Text(
              "En cours depuis : ${DateFormat('HH:mm').format(state.clockInTime!)}",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444), fontSize: 13),
            )
          else
            Text(
              "Pointage pour : ${state.selectedClass?.nomClasse ?? '-'}",
              style: const TextStyle(color: Colors.black54, fontSize: 11, fontWeight: FontWeight.bold),
            )
        ],
      ),
    );
  }

  Widget _buildDetailsCard(DashboardState state) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _rowInfo("Enseignant", "${state.profile?.prenoms ?? ''} ${state.profile?.nom ?? ''}"),
            const Divider(height: 16),
            _rowInfo("Établissement", state.profile?.etablissement ?? "ESIAS"),
            const Divider(height: 16),
            _rowInfo("Matière active", state.selectedClass?.matiere ?? "-"),
            const Divider(height: 16),
            _rowInfo("Mode réseau", state.pendingSyncCount > 0 ? "Hors-Ligne (Stocké SQLite)" : "Connecté au Cloud"),
          ],
        ),
      ),
    );
  }

  Widget _rowInfo(String title, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            val,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }

  // BOÎTE DE DIALOGUE : BOUTON ANNULER RÉPARÉ AVEC rootNavigator: true
void _confirmClockOut(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        title: const Text("Clôturer la séance ?"),
        content: const Text(
          "Que souhaitez-vous faire pour cette séance de cours ?",
        ),
        actions: [
          // 1. ANNULER : REMET L'ICÔNE DIRECTEMENT À L'ÉTAT INITIAL VERT SANS ENREGISTRER
          TextButton(
            onPressed: () {
              Navigator.of(dialogCtx, rootNavigator: true).pop();
              ref.read(dashboardProvider.notifier).cancelClockIn(); // REMISE À ZÉRO DU BOUTON
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Pointage annulé : retour à l'état initial."),
                  backgroundColor: Colors.black54,
                ),
              );
            },
            child: const Text("Annuler la séance", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),

          // 2. VALIDER : ENREGISTRE DANS SQLITE, CALCUL DU SALAIRE ET CLÔTURE
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A)),
            onPressed: () async {
              Navigator.of(dialogCtx, rootNavigator: true).pop();
              await ref.read(dashboardProvider.notifier).completeClockOut();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Séance validée et enregistrée avec succès !"),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
            },
            child: const Text("Valider", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // GÉNÈRE LE BORDEREAU GÉNÉRAL REGROUPANT TOUTES LES CLASSES DU MOIS
  Future<void> _printPdf(BuildContext context) async {
    final db = await DatabaseHelper.instance.database;
    final profRows = await db.query('profile', limit: 1);
    final clsRows = await db.query('classes');

    if (profRows.isEmpty || clsRows.isEmpty) return;

    final profile = TeacherProfile.fromMap(profRows.first);
    final classesList = clsRows.map((e) => ClassEntity.fromMap(e)).toList();
    final Map<String, ClassEntity> classesMap = {for (var c in classesList) c.id: c};

    final now = DateTime.now();
    final currentMonthPrefix = "${now.year}-${now.month.toString().padLeft(2, '0')}";

    // RÉCUPÈRE LES COURS DE TOUTES LES CLASSES POUR CE MOIS
    final attRows = await db.query(
      'attendance_records',
      where: 'date_cours LIKE ?',
      whereArgs: ['$currentMonthPrefix%'],
      orderBy: 'date_cours DESC',
    );
    final records = attRows.map((e) => AttendanceRecord.fromMap(e)).toList();

    if (records.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun cours pointé ce mois-ci.')),
        );
      }
      return;
    }

    final pdfBytes = await PdfService.generateVacationReport(
      teacher: profile,
      records: records,
      classesMap: classesMap,
      mois: now.month,
      annee: now.year,
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: 'Bordereau_Vacations_${now.month}_${now.year}.pdf',
    );
  }
}