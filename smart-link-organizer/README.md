# Smart Link Organizer

Plugin Obsidian pour garder un vault bien rangé : détection des liens cassés,
repérage des notes en double ou similaires, et suggestions de liens
manquants.

## Fonctionnalités

- **Trouver les liens cassés** — liste tous les `[[wikilinks]]` qui pointent
  vers des notes inexistantes, avec un bouton pour créer la note manquante
  en un clic (dossiers parents créés automatiquement si besoin).
- **Trouver les notes similaires / doublons** — compare chaque paire de
  notes sur deux critères : proximité du contenu (similarité de Jaccard sur
  les mots significatifs, FR/EN) et proximité du titre (distance de
  Levenshtein). Utile pour repérer des notes redondantes ou des fautes de
  frappe dans les titres.
- **Suggérer des liens pour la note active** — repère les mentions en texte
  brut d'autres titres de notes dans la note ouverte, et propose de les
  transformer en `[[lien]]` en un clic.

Les trois commandes sont accessibles via la palette de commandes
(`Ctrl/Cmd+P`), et un raccourci vers « Trouver les liens cassés » est
disponible dans la barre latérale (icône lien).

## Réglages

- **Seuil de similarité de contenu** et **Seuil de similarité de titre** :
  ajustent la sensibilité de la détection de doublons.
- **Dossiers ignorés** : exclut certains dossiers (templates, archives...)
  de tous les scans.
- **Longueur minimale des titres suggérés** : évite de proposer des liens
  vers des notes dont le titre est trop court pour être pertinent.
- **Limite de sécurité pour le scan de similarité** : le scan de notes
  similaires compare chaque paire de notes (coût quadratique). Au-delà de
  cette taille de vault, le scan est bloqué pour éviter de figer Obsidian ;
  augmente la valeur si ton vault est grand et que tu es prêt à attendre.

## Installation manuelle

1. Compile le plugin (voir ci-dessous) ou récupère `main.js`,
   `manifest.json` et `styles.css` directement depuis ce dossier.
2. Copie ces trois fichiers dans
   `<ton-vault>/.obsidian/plugins/smart-link-organizer/`.
3. Dans Obsidian : Réglages → Plugins tiers → active « Smart Link
   Organizer ».

## Développement

```bash
npm install
npm run dev     # build en mode watch
npm run build   # build de production (tsc + esbuild minifié)
```
