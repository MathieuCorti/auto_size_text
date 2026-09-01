# Gate Cœur — validation indépendante de l’assemblage

Date : 2026-09-01

Branche auditée : `codex/integrate-gate-core-reviewed`

Tête auditée avant ce rapport :
`f558395cfd512dcd7dc65ad3f8dca89b323ceb81`

Base exacte S6 : `b07066ffe321dff059c9d7d8008b2713e30e1aee`

Tête source approuvée des corrections :
`608527ff31272e06dbaeb5433b50c58b52c0eb9b`

Périmètre : provenance de l’assemblage, identité du produit, des tests et du
journal correctif, chronologie des revues, relecture du diff cumulé, matrice
Flutter 3.47.2/3.41.0, probes de complexité et mutants du harness. Aucun
correctif produit, merge, push, tag ou publication n’est inclus.

## Verdict

**PASS.**

L’assemblage est linéaire depuis S6, les sept commits de correction sont des
reprises exactes par patch-id, et les neuf fichiers produit/tests/journal sont
byte-identiques à la tête source approuvée `608527ff`. Les rapports initiaux
PASS et BLOCKED, les reprises demandées, puis les verdicts finaux ACCEPTÉ/PASS
sont présents dans l’ordre et restent reliés à des objets Git vérifiables.

La matrice indépendante est verte sur Flutter 3.47.2, Flutter 3.41.0 naturel
et Flutter 3.41.0 downgradé. Les compteurs reproduisent `64/4096` sur S6 et
`0/0` sur la tête pour la première vague de 64 membres. Les régressions
permanentes et le probe UTF-16/NBSP tuent tous les mutants essentiels rejoués.
Aucun finding P0, P1, P2 ou P3 n’est ouvert.

## Identités d’entrée

Toolchains exécutées :

```text
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
Engine 1cf1c4773fb941c4c74a7f8bb144a8837596c0f4 • DevTools 2.60.0

Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Engine cc8e596aa65130a0678cc59613ed1c5125184db4 • DevTools 2.54.1
```

Hashes canoniques avant et après les contrôles :

| Fichier | SHA-256 |
|---|---|
| `example/pubspec.lock` | `115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7` |
| `pubspec.yaml` | `667f07143ddc1609167857eb353d83c88aeab0758890345facdf8857a2c1b812` |
| `example/pubspec.yaml` | `09520ff9a078e7f10008b5a3ac4ee79a625080eba359eb115da94798c3e83310` |
| `analysis_options.yaml` | `0c9fe2b745a2481769c610ec01461ba15cf583e0bc7b451d74eccb93b90f7dc6` |

## Provenance de l’assemblage

`git merge-base --is-ancestor b07066f HEAD` retourne zéro. La plage
`b07066f..f558395` contient seize commits à parent unique et aucun merge. Son
ordre est : trois rapports initiaux, sept commits de correction, puis six
commits de revue finale.

Les patch-ids ont été calculés avec :

```sh
git show <commit> --pretty=format: | git patch-id --stable
```

| Source approuvée | Assemblage | Patch-id stable |
|---|---|---|
| `8cf1f0a` | `385287b` | `401fe87d2f7d390d02904170da5c134cadcd6060` |
| `4ecdc88` | `524309c` | `bcdb3d5fca27104f779f2c5d602aa10eba4148a7` |
| `4883bb0` | `727bddb` | `639becdae23e9f3d91b8cdaf071a8b70fba4b1c1` |
| `9ec35e9` | `94efaf1` | `1ba6434c2fc8380c227d37599954698dea8e7d45` |
| `8301d7a` | `b61e30f` | `d449adaaefb18a15105ef8b2c5c08b73a762066f` |
| `f4e4576` | `6a4def4` | `a6a541dea9df9c7b0cca694c491328a06882052a` |
| `608527f` | `b87bf81` | `363e4534c4ee0d9d1e211fd921e156ff4a43e722` |

Le contrôle suivant est vide et retourne zéro :

```sh
git diff --exit-code \
  608527ff31272e06dbaeb5433b50c58b52c0eb9b \
  f558395cfd512dcd7dc65ad3f8dca89b323ceb81 -- \
  lib/src/auto_size_group.dart \
  maintenance/decisions/candidate-domain-oracle.md \
  maintenance/implementation/gate-core-fixes.md \
  test/group_minimum_maintenance_test.dart \
  test/maxlines_test.dart \
  test/preset_font_sizes_test.dart \
  test/text_fit_oracle_test.dart \
  test/text_painter_lifecycle_test.dart \
  test/utils.dart
```

Les blobs source et assemblage sont identiques pour chaque fichier :

| Fichier | Blob Git commun |
|---|---|
| `lib/src/auto_size_group.dart` | `6f108ad35e12615994d95a5c0834914aa8d26186` |
| `maintenance/decisions/candidate-domain-oracle.md` | `0215aa36ba9cde2005298b267f6260ee5bf89541` |
| `maintenance/implementation/gate-core-fixes.md` | `e9d620cd5302adad2d16a8fbda04bbb9f541eaf5` |
| `test/group_minimum_maintenance_test.dart` | `238fc58ff6d1ba994c183e56862840ad67026698` |
| `test/maxlines_test.dart` | `98427a903cc5dd251c9bcdb7dae1238181084db5` |
| `test/preset_font_sizes_test.dart` | `a718b17156d19ab86b5e698c403571fde201f604` |
| `test/text_fit_oracle_test.dart` | `bb067ffffb665e2227e77ff29e5f9b4778bbad38` |
| `test/text_painter_lifecycle_test.dart` | `5ce596838f2ff897f4ef1548e5704176da0a7d71` |
| `test/utils.dart` | `b937e06138f04b51e7dca044bd02fcb148f8fb96` |

## Traçabilité des verdicts

La chronologie conservée ne masque pas les findings intermédiaires :

| Commit d’assemblage | Rapport | Verdict conservé |
|---|---|---|
| `9049e15` | revue cumulative lots 1 à 5 | **PASS**, avec deux dettes P3 |
| `c031d3d` | matrice S6 | **PASS** ; `git diff --check` futur signalé BLOCKED |
| `5179e0d` | compatibilité/API | **BLOCKED**, P2 `M²` du minimum de groupe |
| `926e57f` | première revue des corrections | **CHANGEMENTS REQUIS**, P3 harness `maxLines:null` |
| `6aefb6a` | revue corrective finale | **ACCEPTÉ**, aucun P0–P3 |
| `71a8450`, `7e13508` | contre-revue performance et sanity | **ACCEPTÉ**, aucun P0–P3 |
| `5a8358e` | première contre-revue harness | **BLOCKED** harness, **PASS** produit groupe |
| `f558395` | contre-revue finale harness | **PASS**, aucun P0–P3 |

Les objets cités par les rapports existent encore : `9ec35e9`, `17d9a35`,
`29f50dd`, `37dc119`, `d1c131e` et `c652042`. Les trois reprises du harness
ont la même identité de patch dans leurs trois lignées :

| Source | Revue harness | Assemblage | Patch-id |
|---|---|---|---|
| `8301d7a` | `d1c131e` | `b61e30f` | `d449adaaefb18a15105ef8b2c5c08b73a762066f` |
| `f4e4576` | `c652042` | `6a4def4` | `a6a541dea9df9c7b0cca694c491328a06882052a` |
| `608527f` | `37dc119` | `b87bf81` | `363e4534c4ee0d9d1e211fd921e156ff4a43e722` |

Les neuf fichiers du périmètre sont aussi byte-identiques entre `608527ff`,
`17d9a35`, `37dc119` et `f558395`. Enfin,
`git diff --quiet 9ec35e9..29f50dd -- lib` retourne zéro : la sanity
postérieure du rapport performance n’a pas modifié le produit.

SHA-256 des rapports finaux relus :

| Rapport | SHA-256 |
|---|---|
| `gate-core-cumulative-review.md` | `83cc8f3f919cdb0c24a3303e82ef035f16b2c1c2e2358c546debbc85efddbdd3` |
| `gate-core-matrix.md` | `81ab1c7000b94cd6c1c8f7c712c43f357cefd1b0e19016aa2754cf7c1ce81bdd` |
| `gate-core-compatibility-review.md` | `8a253de245c7ea6fb72f7829d435377a8095e829b8d90eff7a04b9fe1f9a2bbc` |
| `gate-core-fixes-review.md` | `9028b16115ddb3bd3142e0e5cb97f3062795ad0589478fa6d988db4dec30d39d` |
| `gate-core-performance-fix-review.md` | `f7c9041ddcdad6c8cf7e1d6ce259ae471855d7d2bf8f2904d4fbb0e5006a80f8` |
| `gate-core-harness-review.md` | `c6ac8db2f9bfdea7a61a58f0f7d1070aecae804107756570d69bece21b894a0c` |

## Relecture du diff cumulé

Les quinze fichiers de `b07066f...f558395` ont été lus intégralement dans
leur état final et comparés à la base. Le produit ne change que dans
`lib/src/auto_size_group.dart`.

La maintenance incrémentale de `G` couvre exhaustivement les cas valides :

- `new < G` donne immédiatement le nouveau minimum en `O(1)` ;
- si l’ancien rapport n’était pas minimal et `new >= G`, un autre membre
  conserve `G`, donc aucun scan n’est nécessaire ;
- si l’ancien rapport était égal à `G` et remonte, un scan de la map mise à
  jour retrouve le minimum suivant ou un ex aequo ;
- au retrait, seul un rapport fini égal à `G` peut exiger un scan ;
- le marqueur `+infinity` d’un membre non publié ne déclenche ni scan ni faux
  minimum ; le dernier rapport fini retiré ramène `G` à `+infinity`.

Les comparaisons exactes sont cohérentes avec les rapports effectifs finis
validés avant `_updateFontSize`. Le cache membre publie `P`, jamais la
projection `R`. La notification reste conditionnée au changement exact de
`G`, coalescée avant la microtâche, puis revalide présence et `mounted`. Aucun
défaut d’ex aequo, suppression, transfert, cache, frame ou callback tardif
n’est confirmé.

Le helper de test reçoit le `RenderParagraph` réellement résolu. Ses deux
painters sont libérés dans des `finally`. Il transmet direction, scaler,
`maxLines`, ellipsis, locale, strut, `TextWidthBasis` et
`TextHeightBehavior`, applique la politique effective de wrap et compare la
taille non contrainte aux contraintes du render object. La segmentation
indépendante utilise les offsets UTF-16, réintègre NBSP/NNBSP aux plages et
additionne toutes les boîtes de sélection. Aucun appel à l’ancien
`doesTextFit` ne subsiste.

Les tests nouveaux sont des widget tests déterministes et non temporels. Ils
couvrent première publication, baisse, hausse minimum/non-minimum, ties,
retraits, retour au groupe vide, `maxLines` fini/null, configuration ambiante
et ownership des painters. Les mutants ci-dessous démontrent que leurs
oracles peuvent réellement échouer.

### Checklist sécurité et disponibilité

La surface modifiée est une bibliothèque Flutter locale sans réseau, requête,
base, template, authentification, autorisation, session, secret ou
cryptographie. Injection, XSS, CSRF, IDOR et divulgation sont hors surface.

Les catégories applicables ont été contrôlées : logique d’état, races de
microtâches, erreurs, limites numériques, ressources natives et disponibilité.
La première vague passe de `O(M²)` à `O(M)` en incluant le fan-out nécessaire ;
une mise à jour non minimale sans changement de `G` reste `O(1)` de bout en
bout. Aucun finding n’est confirmé.

## Matrice indépendante

Chaque lane utilisait une archive jetable exacte de `f558395`, les options
globales `--suppress-analytics --no-version-check` et le cache local hors
ligne. Le worktree canonique n’a reçu ni résolution minimale ni lock généré.

### Flutter 3.47.2

```sh
flutter pub get --offline --no-example
cd example && flutter pub get --offline --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test example/main.dart
flutter analyze --no-pub --fatal-infos --fatal-warnings \
  lib test example/main.dart
cd example && flutter analyze --no-pub --fatal-infos --fatal-warnings
flutter test --no-pub <les neuf fichiers ciblés>
flutter test --no-pub \
  test/text_painter_lifecycle_test.dart test/leak_tracking_test.dart
flutter test --no-pub
```

### Flutter 3.41.0 naturel puis downgradé

Le lock haut a été déplacé hors de `example/` dans l’extraction avant la
résolution naturelle.

```sh
flutter pub get --offline --no-example
cd example && flutter pub get --offline
flutter analyze --no-pub --fatal-infos --fatal-warnings \
  lib test example/main.dart
cd example && flutter analyze --no-pub --fatal-infos --fatal-warnings
flutter test --no-pub <les neuf fichiers ciblés>
flutter test --no-pub \
  test/text_painter_lifecycle_test.dart test/leak_tracking_test.dart
flutter test --no-pub

flutter pub downgrade --offline --no-example
cd example && flutter pub downgrade --offline
# mêmes analyses et mêmes suites avec --no-pub
```

Les neuf fichiers ciblés étaient :

```text
test/group_minimum_maintenance_test.dart
test/group_constraints_test.dart
test/group_test.dart
test/group_builder_test.dart
test/maxlines_test.dart
test/preset_font_sizes_test.dart
test/text_fit_oracle_test.dart
test/text_painter_lifecycle_test.dart
test/leak_tracking_test.dart
```

| Contrôle | 3.47.2 | 3.41.0 naturel | 3.41.0 downgradé |
|---|---:|---:|---:|
| résolution racine | 26 dépendances | 26 dépendances | PASS, 9 abaissées |
| résolution exemple | lock forcé, inchangé | 10 dépendances | PASS, 1 abaissée |
| format après résolution haute | 28 fichiers, 0 changement | non autoritatif | non autoritatif |
| analyse package | 0 diagnostic | 0 diagnostic | 0 diagnostic |
| analyse exemple | 0 diagnostic | 0 diagnostic | 0 diagnostic |
| ciblés | 50/50 | 50/50 | 50/50 |
| lifecycle/leak explicites | 9/9 | 9/9 | 9/9 |
| suite complète | 125/125 | 125/125 | 125/125 |

Le downgrade racine a sélectionné notamment `leak_tracker 11.0.1`,
`lints 6.0.0` et `vm_service 11.10.0`; l’exemple a abaissé `lints` à 6.0.0.
Ces sélections sont identiques aux preuves archivées.

## Probes et mutants rejoués

### Minimum de groupe

Une instrumentation jetable a compté les appels et visites de
`_recalculateFontSize` sans seuil de temps. Le même test public a été lancé
sur `f558395` et sur S6 `b07066f`, sous Flutter 3.47.2 :

| Chemin | Tête | S6 |
|---|---:|---:|
| première vague ascendante, `M=64` | `0 / 0` | `64 / 4096` |
| hausse d’un non-minimum, `M=4` | `0 / 0` | `1 / 4` |
| hausse du minimum, `M=4` | `1 / 4` | `1 / 4` |

Les deux exécutions donnent 1/1 et impriment les compteurs exacts. Les
compteurs publics temporaires et le test de probe ont ensuite été supprimés
avec leurs extractions.

### Harness résolu et UTF-16/NBSP

Le baseline combinant `maxlines_test.dart`, `text_fit_oracle_test.dart` et un
probe jetable `A😀\u00A0A B` passe 8/8. Le probe calcule une largeur strictement
entre les sélections UTF-16 `0..4` et `0..5`, puis exige que la plage complète
avec NBSP reste indivisible.

Chaque mutant a été appliqué seul dans une copie, exécuté, observé rouge puis
la copie entière a été supprimée :

| Mutant | Exit et signature rouge |
|---|---|
| omettre `RenderParagraph.maxLines` | exit 1, attendu `false`, obtenu `true` |
| supprimer la mesure des plages avec `maxLines:null` | exit 1, attendu `false`, obtenu `true` |
| omettre la direction résolue | exit 1, `TextPainter.textDirection` non défini |
| remplacer le scaler résolu par `noScaling` | exit 1, attendu `false`, obtenu `true` |
| omettre le strut effectif | exit 1, attendu `false`, obtenu `true` |
| traiter NBSP comme séparateur | exit 1, attendu `false`, obtenu `true` |
| tronquer l’endpoint UTF-16 d’une unité | exit 1, attendu `false`, obtenu `true` |

### Incidents de harness/environnement sans finding produit

Deux premiers appels sandboxés ont échoué sur l’écriture des états globaux
Flutter sous `~/.config/flutter` et `~/.pub-cache`; les matrices ont été
rejouées dans de nouvelles extractions avec l’accès normal au cache.

La première version jetable du probe compteur ajoutait une assertion de rendu
hors de son oracle : elle attendait 30 pour tous les membres malgré des
domaines singleton disjoints `[35,30,40,60]`. Elle a échoué pareillement sur
S6 et sur la tête, tandis que les compteurs étaient déjà ceux attendus.
L’assertion étrangère à la complexité a été retirée ; le probe compteur a été
rejoué 1/1 sur les deux commits avec les valeurs exactes ci-dessus. Aucun de
ces essais n’a touché le worktree canonique.

## Propreté finale

Avant création du présent rapport :

```text
git status --short --branch
## codex/integrate-gate-core-reviewed

git diff --check b07066f...f558395
# vide, exit 0

git diff --check e9f75af...f558395
# vide, exit 0

git ls-files -o --exclude-standard
# vide
```

Les quatorze extractions de matrice, probes et mutants ont été supprimées.
Une recherche explicite de leurs préfixes sous `/private/tmp` est vide. Le
lock canonique conserve son SHA-256 et aucun `.dart_tool`, build, lock racine,
probe, compteur ou mutant ne reste dans le worktree. Le commit de cette
validation doit contenir uniquement ce rapport.

## Surface relue et limites

Ont été lus intégralement : les quinze fichiers de la plage
`b07066f...f558395`, les versions initiales et finales des rapports modifiés,
ainsi que le contexte groupe/cache/fit/lifecycle dans
`lib/src/auto_size_text.dart`, `lib/src/auto_size_text_layout.dart` et
`lib/src/auto_size_group_builder.dart`. Les instructions `find-bugs`,
`developing-flutter`, Effective Dart, testing et les instructions AGENTS.md
fournies ont été appliquées. Aucun `AGENTS.md` additionnel n’existe dans le
worktree ; PostHog n’est pas applicable à cette validation locale.

Le navigateur, l’AOT, la démo, les intrinsics, le dry layout et le support de
`WidgetSpan` ne font pas partie de cette Gate Cœur. Le delta produit ne change
aucune primitive spécifique à ces runtimes ou surfaces ; leur absence de la
matrice n’est pas un finding de cet assemblage.
