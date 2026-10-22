// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:printing/printing.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'features/pointage/history_screen.dart';
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
  bool _isOnWifi = false;

  @override
  void initState() {
    super.initState();
    _checkNetworkStatus();
    Connectivity().onConnectivityChanged.listen((results) {
      if (mounted) {
        setState(() {
          _isOnWifi = results.contains(ConnectivityResult.wifi);
        });
      }
    });
  }

  Future<void> _checkNetworkStatus() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnWifi = connectivity.contains(ConnectivityResult.wifi);
      });
    }
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
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            tooltip: 'Historique des Séances',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
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
                // 1. BADGE DE CERTIFICATION DU RÉSEAU (WIFI vs 4G)
                _buildNetworkBadge(),
                const SizedBox(height: 10),

                // 2. SÉLECTEUR DE CLASSE INTERACTIF
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

                // 3. CARTE FINANCIÈRE
                _buildFinanceCard(data),
                const SizedBox(height: 14),

                // 4. BANDEAU DE L'EMPLOI DU TEMPS OFFICIEL DÉTECTÉ
                _buildTodayScheduleCard(data),
                const SizedBox(height: 14),

                // 5. CAHIER DE TEXTE (LEÇON SUIVANTE)
                _buildSyllabusPreviewCard(context, data),
                const SizedBox(height: 24),

                // 6. GROS BOUTON 1-CLIC D'ÉMARGEMENT DIRECT
                _buildOneClickAttendanceButton(context, data),
                const SizedBox(height: 24),

                // 7. DÉTAILS ADMINISTRATIFS
                _buildDetailsCard(data),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNetworkBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isOnWifi ? const Color(0xFF10B981).withOpacity(0.12) : const Color(0xFFF59E0B).withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _isOnWifi ? const Color(0xFF10B981) : const Color(0xFFF59E0B), width: 0.8),
      ),
      child: Row(
        children: [
          Icon(_isOnWifi ? Icons.wifi : Icons.wifi_off_rounded,
              size: 18, color: _isOnWifi ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isOnWifi
                  ? "Présence Certifiée • Connecté au Réseau de l'Établissement"
                  : "Connexion Données Mobiles (4G) • Émargement toléré",
              style: TextStyle(
                color: _isOnWifi ? const Color(0xFF0F5132) : const Color(0xFF664D03),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayScheduleCard(DashboardState state) {
    final slot = state.todayCurrentSlot;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF0F172A).withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded, size: 20, color: Color(0xFF0F172A)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot != null
                      ? "Créneau du jour : ${slot.jourNom} ${slot.heureDebut} - ${slot.heureFin} (${slot.dureeHeures}H)"
                      : "Aujourd'hui : Aucun créneau fixe à l'emploi du temps",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                ),
                Text(
                  slot != null
                      ? "Classe : ${slot.nomClasse} • ${slot.matiere}"
                      : "Vous pouvez émarger pour la classe sélectionnée ci-dessus.",
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
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

  // LE NOUVEAU BOUTON 1-CLIC BASÉ SUR L'EMPLOI DU TEMPS
  Widget _buildOneClickAttendanceButton(BuildContext context, DashboardState state) {
    final isSigned = state.isAlreadySignedToday;
    final duree = state.todayCurrentSlot?.dureeHeures ?? 2.0;

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              if (isSigned) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Séance d'aujourd'hui déjà émargée avec succès !")),
                );
              } else {
                _showSignDialog(context, state);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 175,
              height: 175,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSigned ? const Color(0xFF64748B) : const Color(0xFF10B981),
                boxShadow: [
                  BoxShadow(
                    color: (isSigned ? const Color(0xFF64748B) : const Color(0xFF10B981)).withOpacity(0.35),
                    blurRadius: 20,
                    spreadRadius: 4,
                  )
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSigned ? Icons.check_circle_rounded : Icons.fingerprint_rounded,
                    size: 54,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isSigned ? "COURS ÉMARGÉ\nAUJOURD'HUI" : "ÉMARGER\nLA SÉANCE (${duree.toStringAsFixed(0)}H)",
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
          Text(
            isSigned
                ? "Séance validée et enregistrée pour aujourd'hui"
                : "1 clic = Validation immédiate du créneau (${state.selectedClass?.nomClasse ?? ''})",
            style: TextStyle(
              color: isSigned ? const Color(0xFF10B981) : Colors.black54,
              fontSize: 11,
              fontWeight: isSigned ? FontWeight.bold : FontWeight.normal,
            ),
          )
        ],
      ),
    );
  }

  void _showSignDialog(BuildContext context, DashboardState state) {
    final slot = state.todayCurrentSlot;
    final duree = slot?.dureeHeures ?? 2.0;
    final classeName = state.selectedClass?.nomClasse ?? "";

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text("Émarger la séance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Classe : $classeName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text("Créneau : ${slot?.heureDebut ?? '13:30'} - ${slot?.heureFin ?? '16:30'} ($duree Heures officielles)"),
            const SizedBox(height: 6),
            if (state.nextLesson != null)
              Text("Leçon : ${state.nextLesson!.titreLecon}",
                  style: const TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic)),
            const Divider(height: 20),
            const Text(
              "Confirmez-vous votre présence pour ce créneau ? Les heures seront ajoutées immédiatement à votre bordereau mensuel.",
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () async {
              Navigator.of(ctx, rootNavigator: true).pop();
              await ref.read(dashboardProvider.notifier).signAttendance1Click();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Séance de $classeName émargée avec succès ($duree H) !"),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            child: const Text("Émarger maintenant", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
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