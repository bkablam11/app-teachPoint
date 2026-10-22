# 🎓 TeachPoint — Cahier de Texte & Gestionnaire de Vacations Connecté

<p align="left">
  <img src="https://img.shields.io/badge/Flutter-3.x_%2F_Dart_3-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Platform-Android_SDK_35-3DDC84?logo=android&logoColor=white" alt="Android" />
  <img src="https://img.shields.io/badge/Gradle-9.1.0_%2F_AGP_9-02303A?logo=gradle&logoColor=white" alt="Gradle" />
  <img src="https://img.shields.io/badge/State_Management-Riverpod_2.6-2E7D32" alt="Riverpod" />
  <img src="https://img.shields.io/badge/Database-SQLite_(Offline--First)-003B57?logo=sqlite&logoColor=white" alt="SQLite" />
  <img src="https://img.shields.io/badge/Backend-Google_Sheets_%2B_Apps_Script-34A853?logo=googlesheets&logoColor=white" alt="Google Sheets" />
  <img src="https://img.shields.io/badge/Tax_Compliance-AIRSI_7.5%25-F59E0B" alt="Tax Compliance" />
  <img src="https://img.shields.io/badge/Architecture-Clean_%26_Offline--First-0F172A" alt="Architecture" />
</p>

**TeachPoint** est une application mobile d'ingénierie logicielle conçue pour les enseignants vacataires de l'enseignement supérieur et technique (notamment en filières **BTS** en Côte d'Ivoire).

Elle supprime la contrainte des feuilles d'émargement volantes et des calculs d'heures manuels en fusionnant :
1. **L'émargement officiel en 1 clic** basé sur l'**Emploi du Temps réel** (fini le chronomètre manuel que l'on oublie d'arrêter).
2. **Le suivi financier instantané** : calcul en 0 ms du salaire **Brut**, déduction automatique de la retenue fiscale à la source (**Taxe AIRSI 7,5 %**) et calcul du **Net à percevoir en FCFA**.
3. **Le cahier de texte connecté classe par classe** : progression pédagogique officielle (semaine par semaine) synchronisée avec Google Sheets et cochée automatiquement après chaque séance.
4. **L'historique et la régularisation** : modification ou suppression immédiate des faux pointages et saisie rétroactive des séances passées reliées au syllabus.
5. **La clôture mensuelle des paiements** : archivage en 1 clic des séances réglées pour réinitialiser le tableau de bord à 0 FCFA pour le mois suivant.
6. **Le Bordereau Mensuel Général A4 en PDF** : document administratif certifié regroupant toutes les classes et matières enseignées, prêt à imprimer et à signer.
7. **L'architecture Multi-Enseignants** : chaque enseignant est identifié par un matricule numérique unique (`TEACHER_ID`), permettant à tout un corps professoral de partager la même infrastructure Google Sheets.

---

## 🏛️ Architecture Technique du Projet

Le code source adopte une organisation modulaire stricte garantissant une scalabilité maximale :

```text
lib/
├── core/
│   ├── database/        # Moteur SQLite local, migrations de version & auto-réparation
│   │   ├── database_helper.dart
│   │   └── models.dart  # TeacherProfile, ClassEntity, SyllabusLesson, AttendanceRecord, ScheduleSlot
│   ├── network/         # Client Dio (redirections 302 gérées), SyncService & Connectivity
│   │   └── sync_service.dart
│   └── updater/         # Système d'auto-mise à jour APK directe hors Play Store
│       └── update_service.dart
├── features/
│   ├── auth_profile/    # Paramètres de profil, gestion CRUD des classes & taux horaire
│   │   └── settings_screen.dart
│   ├── pointage/        # Moteur financier, émargement 1-clic, emploi du temps & historique
│   │   ├── dashboard_provider.dart
│   │   └── history_screen.dart
│   ├── syllabus/        # Cahier de texte dynamique classe par classe & Cloud Sync
│   │   └── syllabus_screen.dart
│   └── reports_pdf/     # Moteur de génération vectorielle A4 consolidée (pdf & printing)
│       └── pdf_service.dart
└── main.dart            # Dashboard Fintech, détection réseau local/WiFi & navigation
```

---

## 🔄 Flux de Données & Principe « Offline-First » Absolu

L'application ne bloque jamais l'utilisateur. Toute action est persistée localement avant d'être envoyée au Cloud :

```text
       [ Enseignant appuie sur "ÉMARGER LA SÉANCE" ]
                            │
                            ▼
      [ Écriture Locale Immédiate dans SQLite (0 ms) ]
      ├── 1. Insère l'émargement dans `attendance_records` avec durée officielle
      ├── 2. Coche la leçon en 'FAIT' avec la date du jour dans `syllabus_lessons`
      ├── 3. Calcule : Brut (ex: 12 000 F) - Taxe 7,5% (900 F) = Net (11 100 F)
      └── 4. Empile la tâche en 'PENDING' dans la table locale `sync_queue`
                            │
                            ▼
          [ Mise à jour de l'Interface Utilisateur ]
                            │
                            ▼
             [ Détection Réseau en tâche de fond ]
                            │
        ┌───────────────────┴───────────────────┐
        ▼                                       ▼
 [ Réseau Indisponible ]               [ Connexion Détectée ]
  Données sécurisées                    (WiFi Établissement ou 4G)
  en local dans SQLite                                  │
                                                        ▼
                                           [ Worker SyncService (Dio) ]
                                           ├── Envoi sécurisé vers Code.gs
                                           ├── Gère les redirections HTTP 302
                                           └── Supprime la tâche de `sync_queue`
                                                        │
                                                        ▼
                                         [ Classeur Google Sheets Cloud ]
                                         ├── Onglet 'EMARGEMENTS' (Centralisé)
                                         └── Onglet 'CAHIER_DE_TEXTE' (Suivi)
```

---

## 🗄️ Schéma de la Base de Données Locale (SQLite - Version 7)

```sql
-- 1. Profil Enseignant (Géré automatiquement avec Matricule)
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

-- 2. Classes gérées (Dynamiques, Modifiables, avec nom d'onglet dédié)
CREATE TABLE classes (
    id TEXT PRIMARY KEY,
    nom_classe TEXT NOT NULL,       -- ex: "2A BTS GC-BAT"
    matiere TEXT NOT NULL,          -- ex: "Mathématiques Générales"
    taux_horaire REAL NOT NULL,     -- ex: 5000.0
    annee_scolaire TEXT NOT NULL,   -- ex: "2026-2027"
    onglet_progression TEXT         -- ex: "PROG_2A_BTS_GC_BAT"
);

-- 3. Emploi du Temps Hebdomadaire Officiel
CREATE TABLE schedules (
    id TEXT PRIMARY KEY,
    jour_semaine INTEGER NOT NULL,  -- 1 = Lundi, 4 = Jeudi, 5 = Vendredi...
    jour_nom TEXT NOT NULL,         -- "JEUDI", "VENDREDI"
    heure_debut TEXT NOT NULL,      -- "13:30"
    heure_fin TEXT NOT NULL,        -- "16:30"
    duree_heures REAL NOT NULL,     -- 3.0 ou 2.0
    class_id TEXT NOT NULL,
    nom_classe TEXT NOT NULL,
    matiere TEXT NOT NULL
);

-- 4. Cahier de Texte Prévisionnel (Syllabus)
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

-- 5. Émargements & Décomposition Fiscale (Avec Statut de Paiement)
CREATE TABLE attendance_records (
    id TEXT PRIMARY KEY,
    teacher_id TEXT NOT NULL DEFAULT '1001',
    class_id TEXT NOT NULL,
    lesson_id TEXT,
    date_cours TEXT NOT NULL,
    heure_arrivee TEXT NOT NULL,
    heure_depart TEXT NOT NULL,
    heures_validees REAL NOT NULL,
    taux_applique REAL NOT NULL,
    montant_total REAL NOT NULL,     -- BRUT (Heures x Taux)
    montant_taxe REAL DEFAULT 0.0,   -- RETENUE FISCALE (Brut x 7.5%)
    montant_net REAL DEFAULT 0.0,    -- NET À PERCEVOIR
    statut_paiement TEXT DEFAULT 'NON_PAYE', -- 'NON_PAYE' ou 'PAYE'
    remarque TEXT,
    created_at TEXT NOT NULL
);

-- 6. File d'attente de synchronisation asynchrone
CREATE TABLE sync_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    action TEXT NOT NULL,
    payload TEXT NOT NULL,
    created_at TEXT NOT NULL,
    status TEXT NOT NULL
);
```

---

## 📊 Structure du Classeur Google Sheets Multi-Enseignants

Le classeur Google Sheets centralise l'ensemble de l'établissement sans risque de collision :

| Nom de l'onglet | Rôle & Structure |
| :--- | :--- |
| **`ENSEIGNANTS`** | `TEACHER_ID` \| `NOM` \| `PRENOMS` \| `ETABLISSEMENT` \| `CONTACT` \| `TAUX_TAXE_POURCENT` |
| **`CLASSES`** | `TEACHER_ID` \| `ID_CLASSE` \| `NOM_CLASSE` \| `MATIERE` \| `TAUX_HORAIRE` \| `ANNEE_SCOLAIRE` \| `ONGLET_PROGRESSION` |
| **`EMPLOI_DU_TEMPS`** | `TEACHER_ID` \| `JOUR_SEMAINE` \| `JOUR_NOM` \| `HEURE_DEBUT` \| `HEURE_FIN` \| `DUREE_HEURES` \| `ID_CLASSE` \| `NOM_CLASSE` \| `MATIERE` |
| **`PROG_2A_BTS_GC_BAT`** | Progression officielle 2A BTS GC-BAT (29 Semaines - Maths Générales) |
| **`PROG_1A_BTS_IDA`** | Progression officielle 1A BTS IDA (27 Semaines - Maths Financières & R.O) |
| **`PROG_1A_BTS_FCGE`** | Progression officielle 1A BTS FCGE (27 Semaines - Maths Financières & R.O) |
| **`EMARGEMENTS`** | Feuille d'émargement centralisée avec matricule, heures, brut, taxe et net |
| **`CAHIER_DE_TEXTE`** | Suivi en direct des validations de séances |

---

## 🛠️ Guide de Compilation & Configuration Système

### Prérequis Techniques
* **Flutter SDK** : 3.24+ / Dart 3.x
* **Android Target** : Android SDK 35 (Android 15)
* **Gradle Wrapper** : 9.1.0 (`gradle-9.1.0-bin.zip`)
* **Android Gradle Plugin** : AGP 9.x avec Kotlin DSL (`build.gradle.kts`)
* **Java SDK** : Version 17

### Configuration Android (`android/app/build.gradle.kts`)
```kotlin
plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

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

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
```

---

# 🚀 SECTION AMÉLIORATIONS & NOUVELLES IDÉES (ROADMAP)

Voici les propositions d'évolution à haute valeur ajoutée identifiées lors des tests en conditions réelles :

### 1. ⏰ Rappel Intelligent 10 Minutes Avant le Début du Cours
- **Fonctionnement** : En utilisant le package `flutter_local_notifications`, l'application planifie une notification locale **10 minutes avant chaque créneau officiel** de l'emploi du temps (ex : le Jeudi à 13h20).
- **Message type** : 
  > *« 🔔 Cours dans 10 min : 2A BTS GC-BAT (Salle BTP) — Préparez la Leçon N°2 : Formules de Taylor Young. Cliquez ici pour émarger dès votre arrivée ! »*
- **Bénéfice** : Élimine définitivement les oublis de pointage au moment de rentrer en classe.

### 2. 🟢 Auto-Émargement Passif par Détection du WiFi de l'Établissement (BSSID)
- **Fonctionnement** : En enregistrant l'adresse physique (BSSID / MAC) de la borne WiFi de l'école dans les paramètres, l'application détecte en tâche de fond l'arrivée de l'enseignant dans le bâtiment.
- **Bénéfice** : Une notification apparaît à l'arrivée : *« Vous êtes connecté au réseau ESIAS Polytechnique. Voulez-vous valider votre séance de 13h30 en 1 clic ? »*.

### 3. ✍️ Signature Manuscrite Numérique sur l'Écran (Canvas Vectoriel)
- **Fonctionnement** : Intégration d'un champ de signature tactile au doigt (`signature` package).
- **Bénéfice** : La signature officielle de l'enseignant est directement incrustée dans le cadre « L'Enseignant Vacataire » du bordereau PDF A4. Le PDF exporté est ainsi juridiquement complet et directement transmissible par WhatsApp ou Email à la comptabilité sans impression papier préalable.

### 4. 🤖 Scanner Intelligent de Fiches de Progression par IA (OCR Vision)
- **Fonctionnement** : Prendre en photo la fiche papier remise par le secrétariat avec l'appareil photo du smartphone.
- **Bénéfice** : L'API Google Gemini Vision analyse automatiquement le tableau photographié (Semaines, Chapitres, Titres, Volumes) et remplit instantanément la feuille Google Sheets et la base SQLite locale.

### 5. 📅 Synchronisation Automatique avec Google Agenda
- **Fonctionnement** : Synchronisation bidirectionnelle des créneaux hebdomadaires avec le compte Google Agenda de l'enseignant pour visualiser ses plages de vacation parmi ses rendez-vous personnels.

### 6. 🏢 Mode Multi-Établissements avec Taux Distincts
- **Fonctionnement** : Pour les vacataires intervenant dans plusieurs universités ou écoles différentes (ex : ESIAS, grandes écoles privées, universités publiques), permettre d'associer un établissement, un logo, et un taux horaire propre à chaque groupe de classes.

### 7. 💾 Sauvegarde & Restauration Locale Sécurisée (Fichier JSON / Backup)
- **Fonctionnement** : Bouton permettant d'exporter l'intégralité de la base de données locale dans un fichier de sauvegarde chiffré partageable sur Google Drive ou WhatsApp pour restaurer ses données en 2 secondes en cas de changement de smartphone.

---

# 🧠 LE MASTER PROMPT UNIVERSEL (VERSION FINALE & COMPLÈTE)

> **Mode d'emploi** : Copie et colle l'intégralité du bloc ci-dessous dans n'importe quel LLM (Claude, ChatGPT, DeepSeek, Cursor) pour initialiser, reconstruire ou faire évoluer TeachPoint sans aucune perte de contexte.

```text
Tu es l'Architecte Logiciel Mobile Senior et Développeur Principal Flutter en charge du projet de production :
"TeachPoint — Cahier de Texte & Gestionnaire de Vacations Connecté" (Package : com.teachpoint).

MISSION PRINCIPALE :
TeachPoint est une application mobile Flutter (Dart 3) ciblant Android (SDK 35), conçue pour les enseignants vacataires de l'enseignement supérieur et technique (filières BTS). L'application supprime la corvée administrative des fiches de vacation et cahiers de texte.

FONCTIONNALITÉS ESSENTIELLES :
1. Émargement en 1 Clic basé sur l'Emploi du Temps Hebdomadaire :
   - Détection automatique du créneau selon le jour (ex: Jeudi 13h30-16h30 = 3H, Vendredi 13h30-15h30 = 2H).
   - Pas de chronomètre piégeux : 1 seul clic valide les heures officielles de la séance.
   - Badge de présence certifiée via le réseau local/WiFi de l'établissement vs 4G.
2. Suivi Financier Temps Réel en FCFA :
   - Calcul immédiat du BRUT (Heures x Taux horaire).
   - Déduction de la retenue fiscale à la source (Taxe AIRSI 7.5% paramétrable en Côte d'Ivoire).
   - Calcul du NET À PERCEVOIR sans aucune latence.
3. Cahier de Texte Officiel Dynamique par Classe :
   - Les leçons sont stockées dans des onglets dédiés dans Google Sheets (ex: 'PROG_2A_BTS_GC_BAT', 'PROG_1A_BTS_IDA', 'PROG_1A_BTS_FCGE').
   - Téléchargement en 1 clic dans SQLite. Coche automatique en 'FAIT' lors de l'émargement.
4. Historique, Modification & Régularisation des Séances :
   - Possibilité de supprimer une séance erronée (ex: faux pointage).
   - Possibilité de modifier ou de régulariser une séance passée en choisissant la leçon officielle dans une liste déroulante reliée au syllabus.
5. Clôture Mensuelle des Vacations Payées :
   - Bouton permettant d'archiver les séances réglées ('statut_paiement = PAYE') pour remettre le compteur du tableau de bord à 0 FCFA pour le nouveau mois.
6. Bordereau Mensuel Officiel A4 en PDF :
   - Document récapitulatif consolidé regroupant TOUTES les classes enseignées dans le mois.
   - Tableau complet, totalisateurs (Heures, Brut, Retenue Fiscale, Net) et visas académiques conformes.
7. Architecture Multi-Enseignants :
   - Gestion d'un identifiant numérique unique (TEACHER_ID / Matricule ex: 1001).
   - Plusieurs enseignants peuvent partager le même Google Sheets sans collision.

STACK TECHNIQUE STRICTE :
- Flutter 3.24+ / Dart 3.x
- Android SDK 35 (Android 15), Java 17, Gradle 9.1.0, AGP 9 avec Kotlin DSL (build.gradle.kts)
- Packages : flutter_riverpod: ^2.6.1, sqflite: 2.3.3+1 (sans caret pour compatibilité SDK 35), dio: ^5.4.1 (avec followRedirects: true et maxRedirects: 5 pour les redirections 302 de Google Apps Script), connectivity_plus: ^6.0.5, printing: ^5.15.1, pdf: ^3.11.1, package_info_plus: ^8.0.0.

BASE SQLITE LOCALE (teachpoint_esias.db - Version 7) :
- Tables : 'profile', 'classes', 'schedules', 'syllabus_lessons', 'attendance_records' (avec statut_paiement, montant_taxe, montant_net, teacher_id), 'sync_queue'.
- Règle Offline-First absolue : écriture locale en 0 ms, synchronisation asynchrone en arrière-plan.

BACKEND GOOGLE APPS SCRIPT (Code.gs) :
- Onglets : 'ENSEIGNANTS', 'CLASSES', 'EMPLOI_DU_TEMPS', 'EMARGEMENTS', 'CAHIER_DE_TEXTE', et onglets de progression 'PROG_...'.
- Algorithme de correspondance robuste extrayant strictement le niveau (1A vs 2A) et la filière (FCGE, IDA, GCBAT) pour éviter toute confusion de programme.

EXPÉRIENCE UTILISATEUR & ERGONOMIE :
- Design Fintech / Éducation : Bleu nuit (#0F172A), Vert Émeraude (#10B981) pour les gains Net, Ambre (#F59E0B) pour les alertes fiscales.
- Zéro débordement (RenderFlex overflow) via Expanded et TextOverflow.ellipsis.
- Boîtes de dialogue avec fermeture instantanée via Navigator.of(context, rootNavigator: true).pop().
```
