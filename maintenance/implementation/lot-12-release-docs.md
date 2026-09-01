# Lot 12 — Documentation et préparation de la release 4.0.0

Date : 2026-09-02

Branche : `codex/impl-release-docs`

Parent exact : `d1fdaa79888f7330b7b37619a1ba84f89132d7ff`

Tête : commit contenant ce journal ; SHA final communiqué dans le compte rendu

## Périmètre livré

- passage de la version package à `4.0.0` et description Pub actualisée ;
- déclaration du fork de release exact comme `repository` Pub ;
- README public réécrit autour des contrats 4.x réellement exercés : texte
  simple/riche, groupes, candidats réguliers/presets, remplacement, scaling
  non linéaire, `WidgetSpan` humide et limites sèches lean ;
- migration 3.x intégrée au README, sans guide séparé ;
- changelog 4.0.0 factuel, séparant ruptures, compatibilité, correctifs et
  outillage, sans prétendre fermer les tickets amont ;
- commentaires dartdoc publics corrigés ou complétés sans changement de
  signature ni de comportement ;
- suppression de la collecte de fonds historique, de la configuration Probot
  non vérifiée et de l'assignation automatique à l'ancien mainteneur ;
- exemples de versions obsolètes retirés des formulaires GitHub ;
- version de la dépendance path actualisée mécaniquement dans les locks des
  applications `example/` et `demo/` ;
- deux espaces finaux Markdown signalés par Gate Architecture supprimés.

Aucun changement de moteur, ajout fonctionnel, badge, service, workflow,
publication, tag, push ou merge n'appartient à ce lot.

## Métadonnées et gouvernance

Le remote `origin`, retenu par la revue comme fork de release, est
`https://github.com/MathieuCorti/auto_size_text.git` ; le champ `repository`
reprend donc exactement `https://github.com/MathieuCorti/auto_size_text`.
`upstream` reste `https://github.com/simc/auto_size_text.git`. L'ancien
`homepage` vers `leisim` a été retiré et aucun `homepage`, `issue_tracker` ou
`funding` n'est inventé. L'autorité Pub reste à vérifier : aucun tag ou publish
réel ne doit la précéder.

La base technique demandée ne contient pas la future piste CI du lot 11. Le
changelog ne revendique donc aucune modernisation CI et le workflow historique
reste un risque de release distinct, hors périmètre de ce lot.

## Validations

Toolchains exactes :

```text
Flutter 3.41.0 • Dart 3.11.0
Flutter 3.47.2 • Dart 3.13.2
```

| Gate | Résultat |
|---|---|
| Format Dart haut | 43 fichiers, 0 changement |
| Analyse package haut, infos/warnings fatals | 0 diagnostic |
| Tests package haut | 156/156 |
| Snippets README compilés et rendus | 1/1, aucune exception |
| Exemple haut, lock imposé | résolution et analyse vertes |
| Démo haut, lock imposé | analyse verte, smoke 4/4 |
| Résolution naturelle minimum | analyse verte, tests 156/156, exemple vert |
| `pub downgrade` minimum | tests 156/156, exemple vert |
| `dart doc --dry-run` haut | 0 warning, 0 erreur |
| Liens locaux README | 3/3 présents |
| `git diff --check` | propre |

Le dry-run Pub 3.13.2 construit l'archive `auto_size_text 4.0.0` de **69 KB**
avec **44 fichiers**. Les huit présences affirmées (`README.md`,
`CHANGELOG.md`, `LICENSE`, `pubspec.yaml`, `analysis_options.yaml`,
`example/main.dart`, `example/pubspec.yaml`, `lib/auto_size_text.dart`) sont
présentes. Les entrées `maintenance/`, `demo/`, `.github/`, `.dart_tool/`,
build, couverture, locks, fichiers locaux, secrets usuels et wrappers Gradle
sont absentes. Une recherche sur chaque fichier archivé ne trouve aucun chemin
`/Users/`, `C:\\Users\\` ou `C:/Users/`.

Le dry-run strict `flutter pub publish --dry-run` retourne **0**, annonce
**0 warning** et conserve l'archive de **69 KB / 44 fichiers**. L'option
`--dry-run` est restée active et aucune publication n'a eu lieu.

## Décisions et limites publiques

- Les presets sont documentés comme non croissants, les doublons adjacents
  restant acceptés ; le domaine régulier est décrit avec son pas et ses bornes.
- Un groupe partage la plus petite taille effective représentable par chaque
  domaine ; il ne promet pas une taille logique identique entre domaines ou
  scalers hétérogènes.
- `TextScaler` ambiant ou explicite conserve le scaling non linéaire ;
  `textScaleFactor` reste un pont linéaire déprécié et mutuellement exclusif.
- Les enfants `WidgetSpan` sont mesurés automatiquement en layout humide. Leurs
  six contributions sèches/intrinsèques restent nulles par contrat lean.
- Le remplacement d'overflow demeure lazy ; ses requêtes sèches/intrinsèques
  utilisent la géométrie du texte au candidat minimal, pas celle du widget de
  remplacement.
- Les corrections sont rattachées aux familles de défauts amont, sans prétendre
  modifier l'état de leurs tickets.

## Risques restants

- issue tracker explicite et droits Pub non établis ;
- workflow CI historique présent sur cette base exacte ;
- divergences dry/wet lean documentées pour remplacement et `WidgetSpan` ;
- contrôles serveur Pub non couverts par le dry-run local.
