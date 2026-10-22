// lib/core/database/models.dart

class TeacherProfile {
  final String id;
  final String teacherId; // Matricule numérique (ex: 1001)
  final String nom;
  final String prenoms;
  final String etablissement;
  final String contact;
  final double tauxTaxePourcent;
  final String sheetsWebAppUrl;
  final String appVersion;

  TeacherProfile({
    required this.id,
    required this.teacherId,
    required this.nom,
    required this.prenoms,
    required this.etablissement,
    required this.contact,
    this.tauxTaxePourcent = 7.5,
    required this.sheetsWebAppUrl,
    required this.appVersion,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'teacher_id': teacherId,
    'nom': nom,
    'prenoms': prenoms,
    'etablissement': etablissement,
    'contact': contact,
    'taux_taxe_pourcent': tauxTaxePourcent,
    'sheets_web_app_url': sheetsWebAppUrl,
    'app_version': appVersion,
  };

  factory TeacherProfile.fromMap(Map<String, dynamic> map) => TeacherProfile(
    id: map['id'],
    teacherId: map['teacher_id']?.toString() ?? '1001',
    nom: map['nom'],
    prenoms: map['prenoms'],
    etablissement: map['etablissement'],
    contact: map['contact'],
    tauxTaxePourcent: (map['taux_taxe_pourcent'] as num?)?.toDouble() ?? 7.5,
    sheetsWebAppUrl: map['sheets_web_app_url'] ?? '',
    appVersion: map['app_version'] ?? '1.0.0',
  );
}

class ClassEntity {
  final String id;
  final String nomClasse;
  final String matiere;
  final double tauxHoraire;
  final String anneeScolaire;
  final String ongletProgression;

  ClassEntity({
    required this.id,
    required this.nomClasse,
    required this.matiere,
    required this.tauxHoraire,
    required this.anneeScolaire,
    this.ongletProgression = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'nom_classe': nomClasse,
    'matiere': matiere,
    'taux_horaire': tauxHoraire,
    'annee_scolaire': anneeScolaire,
    'onglet_progression': ongletProgression,
  };

  factory ClassEntity.fromMap(Map<String, dynamic> map) => ClassEntity(
    id: map['id'],
    nomClasse: map['nom_classe'],
    matiere: map['matiere'],
    tauxHoraire: (map['taux_horaire'] as num).toDouble(),
    anneeScolaire: map['annee_scolaire'],
    ongletProgression: map['onglet_progression'] ?? '',
  );
}

class SyllabusLesson {
  final String id;
  final String classId;
  final int semaineNumero;
  final String chapitre;
  final String titreLecon;
  final String? objectifs;
  final double volumeHoraire;
  final String statut; // "A_VENIR" ou "FAIT"
  final String? dateRealisee;
  final int ordreSequence;

  SyllabusLesson({
    required this.id,
    required this.classId,
    required this.semaineNumero,
    required this.chapitre,
    required this.titreLecon,
    this.objectifs,
    required this.volumeHoraire,
    required this.statut,
    this.dateRealisee,
    required this.ordreSequence,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'class_id': classId,
    'semaine_numero': semaineNumero,
    'chapitre': chapitre,
    'titre_lecon': titreLecon,
    'objectifs': objectifs,
    'volume_horaire': volumeHoraire,
    'statut': statut,
    'date_realisee': dateRealisee,
    'ordre_sequence': ordreSequence,
  };

  factory SyllabusLesson.fromMap(Map<String, dynamic> map) => SyllabusLesson(
    id: map['id'],
    classId: map['class_id'],
    semaineNumero: (map['semaine_numero'] as num).toInt(),
    chapitre: map['chapitre'],
    titreLecon: map['titre_lecon'],
    objectifs: map['objectifs'],
    volumeHoraire: (map['volume_horaire'] as num).toDouble(),
    statut: map['statut'],
    dateRealisee: map['date_realisee'],
    ordreSequence: (map['ordre_sequence'] as num).toInt(),
  );
}

class AttendanceRecord {
  final String id;
  final String teacherId;
  final String classId;
  final String? lessonId;
  final String dateCours;
  final String heureArrivee;
  final String heureDepart;
  final double heuresValidees;
  final double tauxApplique;
  final double montantTotal; // Montant Brut
  final double montantTaxe;  // Déduction fiscale
  final double montantNet;   // Net perçu
  final String statutPaiement; // "NON_PAYE" ou "PAYE"
  final String? remarque;
  final String createdAt;

  AttendanceRecord({
    required this.id,
    required this.teacherId,
    required this.classId,
    this.lessonId,
    required this.dateCours,
    required this.heureArrivee,
    required this.heureDepart,
    required this.heuresValidees,
    required this.tauxApplique,
    required this.montantTotal,
    required this.montantTaxe,
    required this.montantNet,
    this.statutPaiement = 'NON_PAYE',
    this.remarque,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'teacher_id': teacherId,
    'class_id': classId,
    'lesson_id': lessonId,
    'date_cours': dateCours,
    'heure_arrivee': heureArrivee,
    'heure_depart': heureDepart,
    'heures_validees': heuresValidees,
    'taux_applique': tauxApplique,
    'montant_total': montantTotal,
    'montant_taxe': montantTaxe,
    'montant_net': montantNet,
    'statut_paiement': statutPaiement,
    'remarque': remarque,
    'created_at': createdAt,
  };

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) => AttendanceRecord(
    id: map['id'],
    teacherId: map['teacher_id']?.toString() ?? '1001',
    classId: map['class_id'],
    lessonId: map['lesson_id'],
    dateCours: map['date_cours'],
    heureArrivee: map['heure_arrivee'],
    heureDepart: map['heure_depart'],
    heuresValidees: (map['heures_validees'] as num).toDouble(),
    tauxApplique: (map['taux_applique'] as num).toDouble(),
    montantTotal: (map['montant_total'] as num).toDouble(),
    montantTaxe: (map['montant_taxe'] as num?)?.toDouble() ?? 0.0,
    montantNet: (map['montant_net'] as num?)?.toDouble() ?? (map['montant_total'] as num).toDouble(),
    statutPaiement: map['statut_paiement'] ?? 'NON_PAYE',
    remarque: map['remarque'],
    createdAt: map['created_at'],
  );
}

// CRÉNEAU DE L'EMPLOI DU TEMPS OFFICIEL (EX: JEUDI 13h30-16h30)
class ScheduleSlot {
  final String id;
  final int jourSemaine; // 1 = Lundi, 4 = Jeudi, 5 = Vendredi...
  final String jourNom;   // "JEUDI", "VENDREDI"
  final String heureDebut; // "13:30"
  final String heureFin;   // "16:30"
  final double dureeHeures;// 3.0
  final String classId;
  final String nomClasse;
  final String matiere;

  ScheduleSlot({
    required this.id,
    required this.jourSemaine,
    required this.jourNom,
    required this.heureDebut,
    required this.heureFin,
    required this.dureeHeures,
    required this.classId,
    required this.nomClasse,
    required this.matiere,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'jour_semaine': jourSemaine,
    'jour_nom': jourNom,
    'heure_debut': heureDebut,
    'heure_fin': heureFin,
    'duree_heures': dureeHeures,
    'class_id': classId,
    'nom_classe': nomClasse,
    'matiere': matiere,
  };

  factory ScheduleSlot.fromMap(Map<String, dynamic> map) => ScheduleSlot(
    id: map['id'],
    jourSemaine: (map['jour_semaine'] as num).toInt(),
    jourNom: map['jour_nom'] ?? '',
    heureDebut: map['heure_debut'],
    heureFin: map['heure_fin'],
    dureeHeures: (map['duree_heures'] as num).toDouble(),
    classId: map['class_id'],
    nomClasse: map['nom_classe'] ?? '',
    matiere: map['matiere'] ?? '',
  );
}