# Mes Idées — Capture vocale

Application web (PWA) pour capturer des idées à la voix, très rapidement.

## Utilisation

- Ouvrez `index.html` dans un navigateur (Chrome ou Safari récents recommandés).
- Appuyez sur le bouton micro et parlez : chaque fois que vous marquez une pause,
  ce que vous venez de dire est automatiquement enregistré comme une nouvelle idée.
- Appuyez à nouveau sur le micro pour arrêter d'écouter.
- Vous pouvez aussi taper une idée manuellement dans le champ texte.
- Cliquez sur une idée pour la modifier, ou sur 🗑️ pour la supprimer.
- Utilisez la barre de recherche pour retrouver une idée.
- Le menu (⋮) permet d'exporter toutes vos idées en `.json` ou `.txt`, ou de tout effacer.

Toutes les idées sont stockées localement dans le navigateur (`localStorage`) :
rien n'est envoyé à un serveur. La transcription vocale, elle, est fournie par le
moteur de reconnaissance vocale du navigateur (ex. Chrome envoie l'audio aux
serveurs de Google pour le transcrire — c'est une limite du Web Speech API, pas
de cette application).

## Installation sur mobile (PWA)

Ouvrez la page dans Chrome (Android) ou Safari (iOS) puis choisissez
« Ajouter à l'écran d'accueil ». L'app s'ouvre alors en plein écran comme une
app native, et fonctionne hors-ligne pour consulter/éditer vos idées déjà
enregistrées (la reconnaissance vocale nécessite une connexion réseau).

## Déploiement

Ce dossier est 100% statique (aucune dépendance, aucun build). Il peut être
servi tel quel par Netlify, GitHub Pages, ou n'importe quel hébergeur statique,
à l'adresse `/voice-ideas/`.

Pour tester en local :

```bash
cd voice-ideas
python3 -m http.server 8000
# puis ouvrez http://localhost:8000
```

(Un serveur HTTP est nécessaire pour le Service Worker et la géolocalisation du
micro — l'ouverture directe du fichier `index.html` en `file://` fonctionne
aussi pour la capture vocale de base sur la plupart des navigateurs.)
