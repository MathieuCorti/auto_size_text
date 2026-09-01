# Gate finale de release 4.0.0

Date : 2026-09-02

Branche : `codex/final-release-gate`

Candidat exact : `97acb13165c57ab99d74374b3e5272a03d3ce0fe`

## Verdict

**PASS — aucun finding P0, P1 ou P2.**

Le candidat fusionné passe les cinq gates du workflow, le downgrade séparé,
les contrôles de release et les probes négatifs de propagation d'erreur. Aucun
fichier produit, test ou document public n'a été modifié. Aucun push, tag ou
publish réel n'a été exécuté.

## Toolchains exactes

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
```

Les binaires locaux employés sont respectivement :

```text
/Users/mathieu/fvm/versions/3.41.0/bin/flutter
/Users/mathieu/fvm/versions/3.47.2/bin/flutter
```

## Matrice exécutée

| Gate | Commandes principales | Résultat |
|---|---|---|
| minimum naturel | `pub get --no-example`, analyse fatale, `test --no-pub` | analyse propre, 156/156 |
| exemple minimum | `pub get`, analyse fatale | résolution et analyse propres |
| downgrade minimum | bootstrap naturel, `pub downgrade --no-example`, analyse fatale, `test --no-pub` | 9 changements réels, analyse propre, 156/156 |
| haute | `pub get --no-example`, analyse fatale, `test --no-pub` | analyse propre, 156/156 |
| exemple haut | `pub get --enforce-lockfile`, analyse fatale | lock accepté sans changement, analyse propre |
| format haut | `dart format --output=none --set-exit-if-changed ...` | 44 fichiers, 0 changement |
| démo haute | lock imposé, analyse fatale, smoke tests, APK debug | analyse propre, 4/4, APK construit |
| dartdoc | `dart doc --output <temp> --dry-run` sous `pipefail` | 0 warning, 0 erreur |
| package | `flutter pub publish --dry-run --verbose` sous `pipefail` | code 0, 0 warning, 69 KB |

Les analyses racine ont employé la portée exacte du workflow :

```sh
flutter analyze --no-pub --fatal-infos --fatal-warnings \
  lib test example/main.dart
```

Les deux suites complètes ont été lancées sans nouvelle résolution :

```sh
flutter test --no-pub
```

## Isolation minimum et downgrade

Les deux gates 3.41 ont utilisé des extractions indépendantes de
`git archive HEAD` sous `/private/tmp`. Dans chaque copie, le lock canonique
haut de `example/` a été déplacé avant toute résolution. Le checkout candidat
n'a donc jamais reçu de résolution minimum.

Après un bootstrap naturel sous Flutter 3.41.0, le downgrade a modifié
exactement les neuf entrées attendues :

```text
async:            2.13.1  -> 2.10.0
boolean_selector: 2.1.2   -> 2.1.0
charcode:          absent  -> 1.2.0
leak_tracker:      11.0.2  -> 11.0.1
lints:             6.1.0   -> 6.0.0
source_span:       1.10.2  -> 1.8.0
string_scanner:    1.4.1   -> 1.1.0
term_glyph:        1.2.2   -> 1.2.0
vm_service:        15.3.0  -> 11.10.0
```

Une comparaison YAML des locks naturel et downgradé a vérifié l'ensemble exact
des noms, pas seulement le résumé de Pub.

## Démo et artefact Android

La commande correspond exactement à la gate CI fusionnée :

```sh
flutter build apk --debug --no-pub
```

Artefact observé avant nettoyage :

```text
demo/build/app/outputs/flutter-apk/app-debug.apk
taille : 150383166 octets
SHA-256 : fdf4eb1e0a871ee1437dac3fd017b252e113debfcfdc00d0ff821f5fc20c8ee1
```

L'APK et tous les répertoires générés ont ensuite été supprimés. Aucun second
APK n'a été construit.

## Documentation et archive Pub

Le dartdoc a écrit uniquement dans un répertoire temporaire. Sa sortie finale
est `Found 0 warnings and 0 errors.`.

Le script `Validate publish archive` a été lu directement depuis le YAML puis
exécuté avec `bash --noprofile --norc -eo pipefail`. Le dry-run strict, sans
`--ignore-warnings`, termine avec :

```text
exit code: 0
Total compressed archive size: 69 KB
Package has 0 warnings.
```

Le listing normalisé contient 50 entrées, répertoires compris, correspondant à
l'arbre Pub de 44 fichiers. Les quatorze assertions positives passent : douze
chemins exacts, plus au moins une entrée sous `lib/` et sous `test/`. Elles
incluent l'exemple canonique et les cinq fontes/licences métriques.

Les assertions négatives trouvent zéro entrée interdite. Sont notamment absents
`maintenance/`, `demo/`, `.github/`, `.dart_tool/`, `build/`, `coverage/`, les
locks, projets plateforme, configurations locales, credentials, clés,
signatures, wrappers Gradle et tout chemin absolu ou personnel. La commande
`git ls-files -ci --exclude-standard` retourne également zéro entrée.

## Workflow et erreurs amont

Le YAML est syntaxiquement lisible et contient exactement les cinq entrées :

```text
compat-minimum, compat-high, downgrade, demo, package
```

`defaults.run.shell` vaut `bash` et les onze blocs `run` passent `bash -n`.
Deux faux outils impriment chacun le marqueur de succès attendu puis retournent
17 en amont de `tee`. Sous la commande de shell GitHub explicite, les deux
pipelines retournent 17 : dartdoc et dry-run Pub ne peuvent pas masquer un
échec amont.

Les commandes réelles du workflow sont cohérentes avec le candidat après les
merges CI et release : toutes les commandes touchées ont été rejouées depuis
les manifests et locks fusionnés, sans adaptation locale du produit.

## Intégrité finale et nettoyage

Les locks suivis sont byte-identiques avant et après la matrice :

```text
example/pubspec.lock SHA-256 6f9c4813d1f0192e841f3791d0a20755ab08eb590da3a172e792472ad4c410b9
demo/pubspec.lock    SHA-256 340bf618b65e5cb30b4f22770a44a1300ebf0172bfdc8a9999b939ef4e31f520
```

`git diff --check` est propre pour le dernier commit et pour l'ensemble
`baa9c89..97acb13`. Avant création de ce rapport, `git status --short`,
`git status --short --ignored` et la recherche de fichiers suivis mais ignorés
étaient vides. Les copies minimum/downgrade, logs, locks temporaires, dartdoc,
APK et sorties Flutter/Gradle ont été supprimés.

## Risques non couverts

- aucune exécution GitHub-hosted Ubuntu ni restauration réelle du cache Actions
  n'a été observée dans cette gate locale macOS ;
- l'APK validé est le build debug exigé par le workflow, pas un artefact release
  signé ou destiné à la distribution ;
- le dry-run ne prouve ni les droits uploader Pub, ni les contrôles serveur
  appliqués lors d'une publication réelle ;
- aucun push, tag, signature de release ou publication distante n'a été tenté.
