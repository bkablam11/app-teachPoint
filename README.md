# 🎓 TeachPoint — Cahier de Texte & Gestionnaire de Vacations Connecté

![Flutter](https://img.shields.io/badge/Flutter-3.x%20%7C%20Dart%203-02569B?logo=flutter&logoColor=white)

![Platform](https://img.shields.io/badge/Platform-Android%20%28SDK%2035%29-3DDC84?logo=android&logoColor=white)
![Build Engine](https://img.shields.io/badge/Gradle-9.1.0%20%7C%20AGP%209-02303A?logo=gradle&logoColor=white)
![State Management](https://img.shields.io/badge/State-Riverpod%202.6-2E7D32)
![Database](https://img.shields.io/badge/Database-SQLite%20(Offline--First)-003B57?logo=sqlite&logoColor=white)
![Cloud Sync](https://img.shields.io/badge/Backend-Google%20Apps%20Script%20%26%20Sheets-34A853?logo=googlesheets&logoColor=white)
![Tax Calculation](https://img.shields.io/badge/Tax%20Compliance-AIRSI%207.5%25%20(Côte%20d'Ivoire)-F59E0B)
![License](https://img.shields.io/badge/License-Proprietary-red)

**TeachPoint** est une application mobile de grade production conçue spécifiquement pour les enseignants vacataires de l'enseignement supérieur et technique (notamment en filières **BTS**). Elle élimine la corvée de saisie administrative en combinant :
1. **Un pointage de présence en 1 clic** avec horodatage fiable et arrêt à la demi-heure.
2. **Un suivi financier en direct** : calcul sub-milliseconde du salaire **Brut**, déduction automatique de la retenue fiscale (**Taxe AIRSI 7,5 %** en Côte d'Ivoire) et calcul du **Net à percevoir en FCFA**.
3. **Le cahier de texte connecté** : suivi de la progression pédagogique officielle (semaine par semaine) qui s'incrémente automatiquement à chaque clôture de cours.
4. **Une architecture 100 % Offline-First** : aucune latence, fonctionne sans Internet au fond d'un amphithéâtre et synchronise silencieusement en arrière-plan vers **Google Sheets**.
5. **Génération instantanée du Bordereau Mensuel Officiel A4 en PDF** : conforme aux normes universitaires avec tableau consolidé toutes classes confondues, totalisateurs financiers et espaces pour visas administratifs.

---

## 🏛️ Architecture Technique du Système

L'application repose sur un découpage strict en couches avec persistance locale prioritaire :

```
lib/
├── core/
│   ├── database/        # DatabaseHelper (SQLite, Migrations de version, Auto-repair)
│   │   ├── database_helper.dart
│   │   └── models.dart  # Modèles TeacherProfile, ClassEntity, SyllabusLesson, AttendanceRecord
│   ├── network/         # Client Dio (maxRedirects: 5), SyncService & Détection réseau
│   │   └── sync_service.dart
│   └── updater/         # Système de mise à jour directe d'APK (hors Play Store)
│       └── update_service.dart
├── features/
│   ├── auth_profile/    # Paramètres de profil, gestion CRUD des classes & taux horaire
│   │   └── settings_screen.dart
│   ├── pointage/        # Moteur de calcul financier, bouton haptique 1-clic & StateNotifier
│   │   └── dashboard_provider.dart
│   ├── syllabus/        # Cahier de texte dynamique, progression par classe & Cloud Sync
│   │   └── syllabus_screen.dart
│   └── reports_pdf/     # Moteur de génération vectorielle de bordereau A4 (pdf & printing)
│       └── pdf_service.dart
└── main.dart            # Dashboard UI Fintech / Éducation & Navigation principale
```

---

## 🔄 Flux de Données & Règle « Offline-First » Absolue

```
[ Enseignant clique sur "Clôturer le cours" ]
                    │
                    ▼
      [ Écriture Locale Immédiate dans SQLite ]
      ├── 1. Insère l'émargement dans `attendance_records` (0 ms)
      ├── 2. Coche la leçon en 'FAIT' dans `syllabus_lessons`
      ├── 3. Recalcule le Net en FCFA (Brut - Taxe 7,5%)
      └── 4. Empile l'action en 'PENDING' dans `sync_queue`
                    │
                    ▼
        [ Mise à jour de l'UI à 60 FPS ]
                    │
                    ▼
     [ Écouteur Réseau `connectivity_plus` ]
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
 [ Pas d'Internet ]     [ Connexion Détectée ]
  (Reste en SQLite)             │
                                ▼
                   [ Worker SyncService (Dio) ]
                   ├── Gère la redirection 302 Google
                   ├── Envoie le payload JSON vers Code.gs
                   └── Supprime la tâche de `sync_queue`
                                │
                                ▼
                 [ Classeur Google Sheets Cloud ]
                 ├── Onglet 'EMARGEMENTS' (Historique)
                 └── Onglet 'CAHIER_DE_TEXTE' (Suivi)
```

---

## 🗄️ Schéma de la Base de Données Locale (SQLite)

```sql
-- Profil Enseignant (Géré automatiquement avec Matricule)
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
);

-- Classes gérées (Dynamiques, Modifiables, Supprimables)
CREATE TABLE classes (
    id TEXT PRIMARY KEY,
    nom_classe TEXT NOT NULL,       -- ex: "2A BTS GC-BAT"
    matiere TEXT NOT NULL,          -- ex: "Mathématiques Générales"
    taux_horaire REAL NOT NULL,     -- ex: 5000.0
    annee_scolaire TEXT NOT NULL,   -- ex: "2026-2027"
    onglet_progression TEXT         -- ex: "PROG_2A_BTS_GC_BAT"
);

-- Cahier de texte prévisionnel (Progression officielle)
CREATE TABLE syllabus_lessons (
    id TEXT PRIMARY KEY,
    class_id TEXT NOT NULL,
    semaine_numero INTEGER NOT NULL,
    chapitre TEXT NOT NULL,
    titre_lecon TEXT NOT NULL,
    objectifs TEXT,
    volume_horaire REAL NOT NULL,
    statut TEXT NOT NULL,           -- "A_VENIR" ou "FAIT"
    date_realisee TEXT,
    ordre_sequence INTEGER NOT NULL,
    FOREIGN KEY(class_id) REFERENCES classes(id) ON DELETE CASCADE
);

-- Émargements réels et ventilation fiscale
CREATE TABLE attendance_records (
    id TEXT PRIMARY KEY,
    teacher_id TEXT NOT NULL,
    class_id TEXT NOT NULL,
    lesson_id TEXT,
    date_cours TEXT NOT NULL,
    heure_arrivee TEXT NOT NULL,
    heure_depart TEXT NOT NULL,
    heures_validees REAL NOT NULL,
    taux_applique REAL NOT NULL,
    montant_total REAL NOT NULL,     -- BRUT
    montant_taxe REAL DEFAULT 0.0,   -- TAXE DÉDUITE (ex: 7.5%)
    montant_net REAL DEFAULT 0.0,    -- NET À PERCEVOIR
    remarque TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY(class_id) REFERENCES classes(id),
    FOREIGN KEY(lesson_id) REFERENCES syllabus_lessons(id)
);

-- File d'attente de synchronisation hors-ligne
CREATE TABLE sync_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    action TEXT NOT NULL,
    payload TEXT NOT NULL,
    created_at TEXT NOT NULL,
    status TEXT NOT NULL
);
```

---

## 📊 Structure du Classeur Google Sheets

Le classeur Google Sheets se compose des onglets suivants :
1. **`ENSEIGNANTS`** : Annuaire des enseignants avec identifiant numérique (`TEACHER_ID`), identité et taux de taxe.
2. **`CLASSES`** : Liste des classes reliées par matricule avec nom de l'onglet de progression associé.
3. **Onglets de progression dédiés** :
   - `PROG_2A_BTS_GC_BAT` : 29 semaines (Maths Générales).
   - `PROG_1A_BTS_IDA` : 27 semaines (Maths Financières & R.O).
   - `PROG_1A_BTS_FCGE` : 27 semaines (Mathématique Financière et R.O).
4. **`EMARGEMENTS`** : Feuille d'émargement centralisée consolidant tous les pointages reçus avec décomposition Brut / Taxe / Net.
5. **`CAHIER_DE_TEXTE`** : Enregistrement de l'avancement des séances en temps réel.

---

## 🛠️ Guide d'Installation & Compilation

### Prérequis
* Flutter 3.24+ / Dart 3.x
* Android SDK 35 (Android 15)
* Java 17
* Gradle 9.1.0

### Commandes d'installation
```bash
# Cloner le dépôt
git clone https://github.com/votre-compte/teachpoint.git
cd teachpoint

# Récupérer les dépendances stables
flutter pub get

# Lancer sur smartphone Android connecté
flutter run
```

### Configuration Android requise (`android/app/build.gradle.kts`)
```kotlin
android {
    namespace = "com.teachpoint"
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.teachpoint"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
```

---

# 🚀 ROADMAP : FONCTIONNALITÉS FUTURES RECOMMANDÉES


### 1. ✍️ Signature Manuscrite Vectorielle sur l'Écran
- **Concept** : Permettre à l'enseignant de signer directement sur son smartphone avec son doigt ou un stylet à la fin du mois.
- **Impact** : La signature s'insère automatiquement dans le bordereau PDF dans le cadre « L'Enseignant Vacataire ». Le PDF est directement imprimable ou envoyable par WhatsApp/Email au secrétariat sans avoir besoin d'être imprimé puis re-scanné.

### 2. 🤖 Scanner IA de Fiches de Progression (OCR Vision)
- **Concept** : Utiliser l'appareil photo du téléphone pour prendre en photo n'importe quelle fiche papier remise par l'école.
- **Impact** : Un appel à l'API Google Gemini Vision analyse la photo, détecte les colonnes du tableau (Semaine, Chapitre, Leçon, Volume) et injecte la progression dans SQLite et Google Sheets sans saisie manuelle.

### 3. ⏰ Rappels Intelligents & Notifications d'Avant-Cours
- **Concept** : Notification locale 15 minutes avant le début d'un créneau selon l'emploi du temps hebdomadaire.
- **Impact** : *"Vous avez cours dans 15 minutes en 1A BTS IDA : préparez la leçon N°3 sur les Taux Moyens !"*. Un simple appui sur la notification ouvre directement le bouton de pointage.

### 4. 📅 Synchronisation avec Google Agenda
- **Concept** : Export automatique de l'emploi du temps et des séances effectuées vers le calendrier Google Agenda de l'enseignant.

### 5. 🏢 Gestion Multi-Établissements avec Taux Distincts
- **Concept** : Pour les vacataires qui interviennent dans plusieurs universités ou grandes écoles différentes (ex: ESIAS, INP-HB, Universités privées), permettre d'associer un établissement et un taux horaire propre à chaque classe.

---

# 🧠 LE MASTER PROMPT UNIVERSEL

> **Instructions d'utilisation** : Ce prompt condense **100 % des décisions d'architecture, des schémas de base de données, des règles fiscales et de la logique métier** développés ensemble. Tu peux copier-coller ce bloc dans n'importe quelle IA (Claude 3.7, ChatGPT-4o, DeepSeek R1, Cursor) pour reprendre le projet à l'identique sans aucune perte d'information.

```text
Tu es l'Architecte Logiciel Mobile Senior et Développeur Principal Flutter en charge du projet :
"TeachPoint & Cahier de Texte Connecté" (Package : com.teachpoint).

CONTEXTE MÉTIER :
TeachPoint est une application mobile de production ciblant Android prioritairement (tablettes et smartphones), destinée aux enseignants vacataires de l'enseignement supérieur et technique (filières BTS en Côte d'Ivoire).

MISSIONS CLÉS DU PROJET :
1. Pointage d'émargement en 1 clic (horodatage fiable, calcul des durées avec arrondi à 0.5h).
2. Ventilation financière en direct en FCFA : Calcul du BRUT, déduction fiscale de la taxe AIRSI (7.5% paramétrable), et calcul du NET À PERCEVOIR sans aucune latence.
3. Cahier de texte connecté : Progression pédagogique par classe (semaine par semaine) qui s'incrémente automatiquement après chaque pointage.
4. Architecture Offline-First stricte avec SQLite (sqflite) et table sync_queue. Tout s'écrit en local d'abord (0 ms de latence).
5. Synchronisation asynchrone avec un backend Google Sheets via Google Apps Script (Code.gs). Le client HTTP Dio doit obligatoirement avoir followRedirects: true et maxRedirects: 5 pour gérer la redirection HTTP 302 de Google Apps Script.
6. Génération vectorielle d'un Bordereau Mensuel Récapitulatif officiel au format A4 en PDF (packages pdf et printing) regroupant l'ensemble des cours effectués pour TOUTES les classes de l'enseignant au cours du mois.

ENVIRONNEMENT ET VERSIONS STRICTES (SDK 35 & GRADLE 9) :
- Flutter 3.x / Dart 3.x
- compileSdk = 35, targetSdk = 35
- Gradle 9.1.0 (gradle-9.1.0-bin.zip)
- Android Gradle Plugin AGP 9.x avec Kotlin DSL (build.gradle.kts) et Java 17
- Dependencies : flutter_riverpod: ^2.6.1, sqflite: 2.3.3+1 (fixé impérativement sans caret pour éviter le bug d'Android 16 Baklava 36), connectivity_plus: ^6.0.5, dio: ^5.4.1, printing: ^5.15.1, pdf: ^3.11.1, package_info_plus: ^8.0.0.

MODÈLE DE DONNÉES & MULTI-ENSEIGNANTS :
- Chaque enseignant a un matricule numérique unique (ex: 1001). L'URL du script Google Sheets est intégrée et le matricule est géré en tâche de fond sans saisie fastidieuse.
- Google Sheets gère :
  * L'onglet 'ENSEIGNANTS' (TEACHER_ID, NOM, PRENOMS, ETABLISSEMENT, CONTACT, TAUX_TAXE_POURCENT).
  * L'onglet 'CLASSES' (TEACHER_ID, ID_CLASSE, NOM_CLASSE, MATIERE, TAUX_HORAIRE, ANNEE_SCOLAIRE, ONGLET_PROGRESSION).
  * Les onglets de progression séparés classe par classe (ex: 'PROG_2A_BTS_GC_BAT' avec 29 semaines, 'PROG_1A_BTS_IDA' avec 27 semaines, 'PROG_1A_BTS_FCGE' avec 27 semaines) comprenant les colonnes SEMAINE, CHAPITRE, TITRE_LECON, OBJECTIFS, VOLUME_HORAIRE.
  * L'onglet 'EMARGEMENTS' (ID, TEACHER_ID, ENSEIGNANT, ID_CLASSE, CLASSE, MATIERE, DATE, ARRIVEE, DEPART, HEURES, TAUX, BRUT, TAXE, NET, DATE_SYNC).
  * L'onglet 'CAHIER_DE_TEXTE' (Suivi de la validation des leçons).

SCHÉMA SQLITE LOCAL (teachpoint_esias.db, Version 4) :
- Table 'profile' (id, teacher_id, nom, prenoms, etablissement, contact, taux_taxe_pourcent, sheets_web_app_url, app_version).
- Table 'classes' (id, nom_classe, matiere, taux_horaire, annee_scolaire, onglet_progression).
- Table 'syllabus_lessons' (id, class_id, semaine_numero, chapitre, titre_lecon, objectifs, volume_horaire, statut, date_realisee, ordre_sequence).
- Table 'attendance_records' (id, teacher_id, class_id, lesson_id, date_cours, heure_arrivee, heure_depart, heures_validees, taux_applique, montant_total, montant_taxe, montant_net, remarque, created_at).
- Table 'sync_queue' (id, action, payload, created_at, status).

RÈGLES D'EXPÉRIENCE UTILISATEUR & DESIGN :
- Palette Fintech Institutionnelle : Bleu nuit (#0F172A), Vert Émeraude (#10B981) pour les gains Net, Ambre (#F59E0B) pour la taxe et alertes.
- Aucun débordement graphique (RenderFlex Overflow) : utilisation systématique d'Expanded, TextOverflow.ellipsis et SingleChildScrollView sur les cartes et dialogues.
- Sélecteur de classe sur l'accueil : le changement de classe met à jour le cours au programme et télécharge automatiquement la progression depuis Google Sheets si elle n'est pas encore en local.
- Boîtes de dialogue avec fermeture immédiate via Navigator.of(context, rootNavigator: true).pop().
```