# Questly — la liste de tâches qui se joue

Application iOS native (SwiftUI + SwiftData) de gestion de tâches **gamifiée**,
avec un **calendrier complet** : jour, semaine, mois, année, agenda,
time-blocking par glisser-déposer et lecture du calendrier système.

> **Nom & identité** — l'app s'appelle « Questly » et le bundle est
> `com.navidjan.questly`. Les deux se changent en une ligne
> (`PRODUCT_BUNDLE_IDENTIFIER` et `INFOPLIST_KEY_CFBundleDisplayName` dans les
> réglages de la cible).

---

## Ouvrir le projet

```bash
open QuestlyApp/Questly.xcodeproj
```

- **Xcode 16 ou plus récent** (le projet utilise les groupes synchronisés :
  tout fichier ajouté dans `Questly/` entre automatiquement dans la cible,
  sans toucher au `.pbxproj`).
- **iOS 17.0 minimum**, iPhone et iPad.
- Aucune dépendance externe : un seul package local, `QuestlyKit`, déjà
  référencé par le projet.
- Signature : choisir son équipe dans *Signing & Capabilities* au premier lancement.

### Lancer les tests du cœur métier

```bash
cd QuestlyApp/Packages/QuestlyKit && swift test
```

**159 tests, tous au vert** — ils couvrent la courbe d'XP, le moteur de
récompenses, les séries, la récurrence (y compris changement d'heure et années
bissextiles), l'analyseur de langage naturel, le planificateur et les
statistiques.

---

## Ce que fait l'app

### Gestion de tâches

| | |
|---|---|
| **Saisie naturelle** | « Appeler le dentiste demain 14h30 #santé p2 » crée la quête, la date, l'heure, l'étiquette et la priorité |
| **Organisation** | projets (campagnes), étiquettes, sous-quêtes, notes, pièces jointes de contexte |
| **Listes intelligentes** | Boîte de réception, Aujourd'hui, À venir, En retard, N'importe quand, Un jour, Épinglées, Boss, Accomplies |
| **Tri & regroupement** | intelligent, échéance, priorité, difficulté, alphabétique, XP · groupé par date, priorité, projet, domaine ou difficulté |
| **Récurrence** | quotidienne / hebdo / mensuelle / annuelle, tous les N, jours de semaine choisis, jour du mois (dont « dernier jour »), fin après N fois ou à une date, et mode **« X jours après accomplissement »** |
| **Rappels** | notification à l'échéance ou N minutes avant, revue du soir, alerte de série en danger |
| **Balayages** | reporter à aujourd'hui / demain, épingler, promouvoir en boss, supprimer |
| **Recherche** | plein texte sur titres, notes et étiquettes, insensible aux accents |
| **Export** | JSON complet (quêtes, projets, historique, progression) |

### Calendrier, de A à Z

- **Jour** — timeline horaire, trait de l'instant présent, bande « toute la journée ».
- **Semaine** — sept colonnes, pagination par balayage, en-tête tapable.
- **Mois** — grille 6×7 avec pastilles par domaine, teinte de charge, couronne
  des boss ; la journée choisie s'ouvre juste en dessous avec ses créneaux.
- **Année** — douze mini-mois teintés par l'activité.
- **Agenda** — liste continue des jours à venir, chargée par tranches.
- **Time-blocking** — on fait **glisser une quête du tiroir sur la timeline**
  pour réserver un créneau ; un appui long sur un bloc le **déplace** (aimanté
  au quart d'heure), le menu contextuel le redimensionne.
- **Calendrier iOS** — les évènements système s'affichent en lecture seule et
  bloquent les créneaux, pour que la planification reste honnête.
- **Planification automatique** — « Planifier ma journée » range les quêtes du
  jour dans les trous libres : échéance d'abord, puis priorité, en plaçant
  l'exigeant dans la fenêtre de pointe. Le plan est **proposé, jamais imposé**.

### La couche jeu

- **XP et niveaux** — la récompense dépend de la difficulté, de la priorité, de
  la durée, des sous-quêtes, de la concentration investie et de la ponctualité.
  La fiche affiche le **détail ligne par ligne** : aucune récompense n'est magique.
- **Combos** — enchaîner des quêtes en moins de 5 minutes fait monter un
  multiplicateur (jusqu'à +25 %), avec sablier à l'écran.
- **Séries** — jours consécutifs, jusqu'à +30 % d'XP. Trois soupapes évitent la
  spirale de culpabilité : la journée en cours ne casse jamais la série, les
  **gels** comblent un trou isolé, les **jours de repos** sont neutres.
- **Boss** — une grosse quête devient un combat : ses points de vie sont des
  minutes de concentration, chaque session de Donjon lui en retire.
- **Attributs** — six domaines de vie (Corps, Esprit, Cœur, Œuvre, Fortune,
  Foyer) montent en niveau séparément. Le tableau de quêtes cible
  automatiquement le domaine délaissé.
- **Quêtes du jour** — trois quotidiennes + un défi hebdomadaire, **générés de
  façon déterministe** (même jour = mêmes quêtes, un rafraîchissement ne rebat
  pas les cartes).
- **Hauts faits** — 50+ trophées en 8 catégories, dont des secrets.
- **Économie** — pièces et gemmes, échoppe (potions d'XP, gels de série, jours
  de repos, coffres, ambiances, apparence), coffres à butin animés.
- **Héros** — avatar composé d'emojis et de symboles système : visage,
  couvre-chef, familier, aura, cadre. Zéro image à charger, net à toute taille.

### Concentration (le Donjon)

Minuteur Pomodoro complet — durées réglables, enchaînement automatique
travail/pause/grande pause, compteur de distractions, journal des sessions du
jour, et le temps continue de courir correctement en arrière-plan (les calculs
partent des dates, pas d'un décompte de tics).

### Chroniques

Graphiques Swift Charts : XP dans le temps avec moyenne mobile, quêtes par jour,
rythme hebdomadaire, heures fortes, équilibre entre domaines, carte de chaleur
annuelle. Puis des **observations en français** — « le mardi est ton jour fort »,
« tes estimations sont fiables », « le domaine Cœur dort ».

### Le reste

- 8 ambiances visuelles, fond « aurore » animé, verre dépoli, confettis, éclats
  de validation, textes d'XP flottants, haptique différenciée par évènement.
- Réglages : heures de travail, fenêtre de pointe, jours travaillés, premier
  jour de la semaine, durées de concentration, notifications, réduction des
  animations, réinitialisation, export.
- Raccourcis Siri : « Ajouter une quête », « Résumé de ma journée »,
  « Démarrer une session ».
- Onboarding en quatre écrans qui sème des quêtes de départ adaptées aux
  domaines choisis.

---

## Syntaxe de saisie rapide

| Écrire | Effet |
|---|---|
| `demain`, `lundi`, `lundi prochain`, `dans 3 jours`, `15/03`, `20 mars`, `fin du mois` | échéance |
| `14h30`, `9h`, `09:15`, `7:30pm`, `ce soir`, `ce matin` | heure |
| `30min`, `2 heures`, `pendant 1h30` | durée estimée |
| `p1` … `p4` (ou `!1` … `!4`), `urgent`, `important` | priorité |
| `#étiquette`, `@contexte` | étiquettes |
| `+projet` | projet |
| `*facile`, `*ardu`, `*épique`, `*légendaire` | difficulté (donc XP) |
| `%corps`, `%esprit`, `%cœur`, `%œuvre`, `%fortune`, `%foyer` | domaine de vie |
| `!boss` | boss (XP ×2, barre de PV) |
| `tous les jours`, `chaque lundi`, `tous les 3 jours`, `en semaine`, `le 5 du mois` | répétition |
| `rappel 30min avant` | rappel |

L'anglais est reconnu en parallèle (`tomorrow`, `every 2 weeks`, `9am`, `in 5 days`…).
Le domaine de vie est **deviné** à partir des mots (« courses » → Foyer,
« facture » → Fortune) quand il n'est pas précisé.

Deux conventions à connaître : `14h` est une **heure**, `2 heures` est une
**durée** ; et `15/03` est lu **jour/mois**.

---

## Architecture

```
QuestlyApp/
├── Questly.xcodeproj          projet (groupes synchronisés Xcode 16)
├── Packages/QuestlyKit/       cœur métier, sans UI ni base de données
│   ├── Sources/QuestlyKit/
│   │   ├── Core/              énumérations, outils de dates
│   │   ├── Gamification/      XP, niveaux, séries, hauts faits, quêtes, économie
│   │   ├── Parsing/           analyseur de langage naturel
│   │   ├── Recurrence/        moteur de récurrence
│   │   ├── Scheduling/        créneaux libres, planification automatique
│   │   └── Stats/             statistiques et observations
│   └── Tests/                 159 tests
└── Questly/
    ├── App/                   point d'entrée, conteneur, coque
    ├── Data/                  modèles SwiftData + QuestlyStore
    ├── DesignSystem/          thèmes, composants, effets
    ├── Features/              Today, Tasks, Calendar, Focus, Hero, Stats, Settings…
    ├── Services/              haptique, notifications, EventKit, réglages, Siri
    └── Resources/             catalogue d'assets
```

Deux principes structurent le tout :

1. **Les règles du jeu vivent dans `QuestlyKit`**, en Foundation pur. Aucune
   dépendance à SwiftUI ni à SwiftData, donc testable en une seconde et
   réutilisable par un widget ou une extension.
2. **Une seule porte d'écriture** : les vues lisent via `@Query` (SwiftData les
   tient à jour) et passent toutes par `QuestlyStore` pour écrire. XP, séries,
   quêtes, hauts faits et récurrences sont donc appliqués au même endroit,
   jamais dupliqués dans une vue.

Le modèle de données respecte les contraintes CloudKit (valeurs par défaut
partout, aucune contrainte d'unicité) : activer la synchronisation iCloud ne
demandera pas de migration.

---

## État de vérification

Ce qui est **prouvé** :

- `QuestlyKit` compile (Swift 6.0.3) et passe **159 tests unitaires**, dont les
  cas pénibles : passage à l'heure d'été, 31 janvier → 28 février, année
  bissextile, fins de série, ordre des règles dans l'analyseur.

Ce qui **ne l'est pas** :

- La cible iOS (SwiftUI + SwiftData) **n'a pas pu être compilée ici** : ces
  frameworks n'existent que dans le SDK Apple, indisponible sur cette machine.
  Le code a été relu et vérifié par analyse statique (types déclarés/référencés,
  équilibre syntaxique, collisions de noms, API disponibles en iOS 17), et les
  constructions douteuses ont été testées séparément avec le vrai compilateur.
  **Attendez-vous malgré tout à quelques ajustements au premier build dans Xcode** —
  c'est la première compilation réelle de cette couche.

---

## Pistes suivantes

- Widgets WidgetKit (quête du jour, série, anneau d'XP) et Live Activity pour le
  minuteur — `QuestlyKit` est déjà prêt à être partagé avec une extension.
- Synchronisation iCloud (le schéma est compatible, il reste à activer la
  capacité et à passer `cloudKitDatabase` au `ModelConfiguration`).
- Icône d'application : `Questly/Resources/Assets.xcassets/AppIcon.appiconset`
  attend un PNG 1024×1024.
