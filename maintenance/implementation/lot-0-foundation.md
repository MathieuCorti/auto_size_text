# Lot 0 — Fondation SDK, lints, dépendances et harness

Date : 2026-09-01

Branche : `codex/impl-foundation-sdk`

Parent exact : `2e8d57b214e03697440ed27ce382abcf1a64ad92`

Tête : commit contenant ce journal ; SHA final communiqué dans le compte rendu

## Périmètre livré

- contraintes racine et exemple : Dart `>=3.11.0 <4.0.0`, Flutter
  `>=3.41.0` ;
- remplacement de `pedantic` par `flutter_lints: ^6.0.0` dans les deux
  packages autonomes ;
- options analyzer modernes avec casts, inférence et types raw stricts ;
- exclusion explicite `build/**`, requise par la migration Flutter 3.47.2 ;
- ignore Git limité à `/pubspec.lock` ;
- lock canonique de l'exemple généré et forcé par Flutter 3.47.2 ;
- harness opt-in de leak tracking via `FlutterMemoryAllocations`, avec
  `leak_tracker_flutter_testing: ^3.0.10` directement déclaré ;
- test de capacité permanent des trois overrides de métriques `MediaQuery` ;
- corrections de lints, formatage et convention de nommage/organisation des
  tests mécaniques, sans changement d'attente ou de comportement produit.

Hors périmètre : `demo/**`, CI, `.pubignore`, README, changelog, version,
nouvelle API et correctifs produit.

## Fichiers

- configuration et dépendances : `.gitignore`, `analysis_options.yaml`,
  `pubspec.yaml`, `example/pubspec.yaml`, `example/pubspec.lock` ;
- capacité et harness : `test/flutter_test_config.dart`,
  `test/leak_tracking.dart`, `test/leak_tracking_test.dart`,
  `test/sdk_floor_api_test.dart` ;
- lints/format et convention de tests uniquement : `example/main.dart`,
  `lib/auto_size_text.dart`,
  `lib/src/auto_size_group.dart`, `lib/src/auto_size_group_builder.dart`,
  `lib/src/auto_size_text.dart`, `test/basic_test.dart`,
  `test/group_builder_test.dart`, `test/group_test.dart`,
  `test/min_max_font_size_test.dart`,
  `test/overflow_replacement_test.dart`,
  `test/preset_font_sizes_test.dart`, `test/utils.dart` ;
- présent journal : `maintenance/implementation/lot-0-foundation.md`.

## Toolchains exactes

```text
Flutter 3.41.0 • revision 44a626f4f0
Engine cc8e596aa65130a0678cc59613ed1c5125184db4
Dart 3.11.0 • DevTools 2.54.1

Flutter 3.47.2 • revision d3b14c8769
Engine 1cf1c4773fb941c4c74a7f8bb144a8837596c0f4
Dart 3.13.2 • DevTools 2.60.0
```

Bundles exécutés :

- `/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter` ;
- `/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter`.

## Résultats Flutter 3.41.0

| Commande | Résultat |
|---|---|
| copie temporaire sans locks, puis `flutter pub get --no-example` | Succès ; `flutter_lints 6.0.0` et `leak_tracker_flutter_testing 3.0.10` résolus naturellement. |
| `flutter analyze lib test example/main.dart` | Code 1 dû exactement aux 9 informations allowlistées ci-dessous ; 0 erreur, 0 warning, aucune autre information. |
| copie temporaire, `(cd example && flutter pub get)` sans lock | Succès ; 10 dépendances résolues naturellement avec les pins SDK 3.41.0. |
| `(cd example && flutter analyze --no-pub)` | Succès, aucun diagnostic. |
| `flutter test --reporter compact --no-pub` | Succès, 25/25 tests. |
| `flutter pub downgrade --no-example` | Succès ; 9 dépendances abaissées, dont `leak_tracker 11.0.1` et `lints 6.0.0`. |
| `flutter test --reporter compact --no-pub` après downgrade | Succès, 25/25 tests. |
| test leak sans `TextPainter.dispose()` temporaire | Échec attendu : une fuite `notDisposed`, classe `TextPainter`, rattachée au test. |
| replay du test leak avec `dispose()` | Succès, 1/1. |

Les deux nouveaux tests sont inclus dans le total : disponibilité des trois
overrides `MediaQuery`, et capacité du harness à suivre le dispose d'un
`TextPainter` instrumenté.

## Résultats Flutter 3.47.2

| Commande | Résultat |
|---|---|
| `flutter pub get --no-example` | Succès. Un second replay immédiat retourne `Got dependencies!` sans changement suivi. |
| `(cd example && flutter pub get --enforce-lockfile)` | Succès avec le lock canonique généré par 3.47.2 ; aucune mutation. |
| `flutter analyze lib test example/main.dart` | Code 1 dû aux mêmes 9 informations allowlistées ; 0 erreur, 0 warning, aucune autre information. |
| `(cd example && flutter analyze --no-pub)` | Succès, aucun diagnostic. |
| `flutter test --reporter compact --no-pub` | Succès, 25/25 tests. |
| `dart format --output=none --set-exit-if-changed lib test example` | Succès : 20 fichiers, 0 changement après le format mécanique initial. |

Le premier formatage a modifié 9 fichiers puis le binaire Dart a tenté
d'écrire son état de télémétrie hors sandbox. Le même contrôle a été rejoué
avec les permissions appropriées : code 0, aucun fichier modifié.

## Allowlist d'analyse avant le lot 3

La commande scoped doit échouer si un diagnostic diffère de cette liste. Aucun
ignore analyzer global n'est utilisé.

| Règle | Fichier | Ligne:colonne | Usage historique |
|---|---|---:|---|
| `deprecated_member_use` | `lib/src/auto_size_text.dart` | `185:31` | doc `MediaQueryData.textScaleFactor` |
| `deprecated_member_use` | `lib/src/auto_size_text.dart` | `338:46` | `MediaQuery.textScaleFactorOf` |
| `deprecated_member_use` | `lib/src/auto_size_text.dart` | `405:9` | `TextPainter.textScaleFactor` |
| `deprecated_member_use` | `lib/src/auto_size_text.dart` | `423:7` | `TextPainter.textScaleFactor` |
| `deprecated_member_use` | `lib/src/auto_size_text.dart` | `448:9` | `Text.textScaleFactor` |
| `deprecated_member_use` | `lib/src/auto_size_text.dart` | `463:9` | `Text.rich.textScaleFactor` |
| `deprecated_member_use` | `test/utils.dart` | `8:11` | lecture `Text.textScaleFactor` |
| `deprecated_member_use` | `test/utils.dart` | `27:5` | `TextPainter.textScaleFactor` |
| `deprecated_member_use` | `test/utils.dart` | `27:27` | lecture `Text.textScaleFactor` |

Ces usages appartiennent à la migration `TextScaler` du lot 3. Les modifier au
lot 0 changerait le comportement au lieu de rester mécanique.

## Migration automatique de `analysis_options.yaml`

Flutter 3.47.2 exige `build/**` dans les exclusions analyzer et migrait
auparavant ce fichier pendant `pub get`/`test`. Le lot 0 commite explicitement
cette exclusion. Le SHA-256 avant et après deux replays 3.47.2 est resté :

```text
0c9fe2b745a2481769c610ec01461ba15cf583e0bc7b451d74eccb93b90f7dc6
```

Aucune restauration de `analysis_options.yaml` n'a été effectuée. Les replays
n'ont produit aucune mutation suivie supplémentaire.

## Politique du lock de l'exemple

La vérification a établi qu'un lock naturel unique ne peut pas être forcé par
les deux SDK exacts :

- Flutter 3.41.0 contraint `meta: 1.17.0` et `vector_math: 2.2.0` ;
- Flutter 3.47.2 contraint `meta: ^1.18.3` et `vector_math: ^2.4.0` ;
- les intersections sont vides.

Après retrait du `flutter_test` inutilisé de l'exemple, il reste exactement ces
deux incompatibilités imposées par le package SDK `flutter`. Un lock minimum
forcé par la pin haute échoue avec le code 65 et voudrait modifier :

```text
meta 1.17.0 -> 1.19.0
vector_math 2.2.0 -> 2.4.2
```

Le lock inverse échoue symétriquement sur 3.41.0. La décision indépendante
retenue est donc :

- versionner le lock généré par Flutter 3.47.2 ;
- exécuter `--enforce-lockfile` uniquement avec 3.47.2 ;
- pour 3.41.0, copier le même arbre source dans un répertoire temporaire en
  omettant les locks et répertoires générés, résoudre naturellement, puis
  analyser et tester cette copie ;
- rejeter les `dependency_overrides`, le double lock, l'absence de lock et le
  lock minimum canonique.

Cette procédure a été exécutée dans
`/private/tmp/auto-size-text-lot0-min.c5J9sJ/repo`. L'analyse scoped a retrouvé
exactement les 9 informations allowlistées, l'analyse de l'exemple a été verte,
la suite a passé 25/25, puis le downgrade et le replay `--no-pub` ont également
passé 25/25. Le worktree canonique n'a pas été modifié par cette résolution
minimum.

## Correction T2/C7 après revue indépendante

La revue indépendante au commit
`badb159587677441a0d102350432dc679078330b` a demandé une seule correction :
appliquer aux six suites historiques déjà touchées par le lot la convention
commune d'organisation et de nommage des tests. La correction :

- ajoute un `group()` nommé `AutoSizeText`, `AutoSizeGroup` ou
  `AutoSizeGroupBuilder` dans `test/basic_test.dart`,
  `test/group_builder_test.dart`, `test/group_test.dart`,
  `test/min_max_font_size_test.dart`,
  `test/overflow_replacement_test.dart` et
  `test/preset_font_sizes_test.dart` ;
- renomme les 16 descriptions de ces suites afin qu'elles commencent toutes
  par `should` ;
- ne modifie aucun widget construit, helper, appel, ordre d'exécution ou
  attente. `test/utils.dart` reste un helper et n'est pas une suite.

La matrice ciblée a été rejouée après cette correction :

| Environnement / commande | Résultat |
|---|---|
| 3.47.2 — `dart format --output=none --set-exit-if-changed lib test example` | Succès : 20 fichiers, 0 changement. |
| 3.47.2 — exemple `flutter pub get --enforce-lockfile` | Succès ; lock canonique inchangé. |
| 3.47.2 — `flutter analyze --no-pub lib test example/main.dart` | Code 1 attendu ; exactement les 9 informations allowlistées, 0 warning, 0 erreur. |
| 3.47.2 — exemple `flutter analyze --no-pub` | Succès, aucun diagnostic. |
| 3.47.2 — `flutter test --no-pub --reporter compact` | Succès, 25/25 tests. |
| 3.41.0 — résolution naturelle racine et exemple dans une nouvelle copie sans locks | Succès ; 26 dépendances racine et 10 dépendances exemple. |
| 3.41.0 — `flutter analyze --no-pub lib test example/main.dart` | Code 1 attendu ; exactement les mêmes 9 informations allowlistées, 0 warning, 0 erreur. |
| 3.41.0 — exemple `flutter analyze --no-pub` | Succès, aucun diagnostic. |
| 3.41.0 — `flutter test --no-pub --reporter compact` | Succès, 25/25 tests. |

La copie minimum de ce replay est
`/private/tmp/auto-size-text-lot0-review-min.1WqISU/repo`. Les hashes des six
fichiers de suite ont été comparés au worktree canonique avant résolution et
sont identiques. Aucun manifeste, contrainte ou lock n'ayant changé, le
downgrade minimum déjà validé n'a pas été rejoué.

## Limites

- L'analyse globale témoin 3.47.2 retourne le code 1 avec 49 diagnostics,
  notamment les imports UI absents, API système retirée et symboles non résolus
  de `demo/**`. Cette dette connue appartient au lot 6 et n'est ni modifiée ni
  exclue durablement par ce lot. Les résultats verts ci-dessus sont
  exclusivement l'analyse scoped racine et l'analyse séparée de `example/`.
- Les tests de fuite produit appartiennent au lot 1. Le lot 0 fournit et prouve
  seulement le mécanisme opt-in ; le réglage global reste ignoré par défaut
  pour ne pas transformer une dette produit connue en correction cachée.
- Le lock racine de bibliothèque reste ignoré. Le lock de l'exemple est suivi
  dans Git et son enforcement appartient uniquement à la pin haute, selon la
  décision documentée ci-dessus.
- Aucun merge, push, tag ou changement distant n'est effectué par ce lot.
