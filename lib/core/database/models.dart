// lib/core/database/models.dart

class TeacherProfile {
  final String id;
  final String teacherId; // Identifiant unique (ex: KABLAM)
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
    teacherId: map['teacher_id'] ?? 'KABLAM',
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
  final String ongletProgression; // Nom exact de l'onglet dans Google Sheets

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
  final String statut;
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
    semaineNumero: map['semaine_numero'],
    chapitre: map['chapitre'],
    titreLecon: map['titre_lecon'],
    objectifs: map['objectifs'],
    volumeHoraire: (map['volume_horaire'] as num).toDouble(),
    statut: map['statut'],
    dateRealisee: map['date_realisee'],
    ordreSequence: map['ordre_sequence'],
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
  final double montantTotal;
  final double montantTaxe;
  final double montantNet;
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
    'remarque': remarque,
    'created_at': createdAt,
  };

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) => AttendanceRecord(
    id: map['id'],
    teacherId: map['teacher_id'] ?? 'KABLAM',
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
    remarque: map['remarque'],
    createdAt: map['created_at'],
  );
}