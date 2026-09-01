# Gate Cœur — validation matricielle indépendante

Date : 2026-09-01

Branche de vérification : `codex/gate-core-matrix`

SHA produit vérifié : `b07066ffe321dff059c9d7d8008b2713e30e1aee`

Tree produit vérifié : `8b4f4a99231f48a05ce51266d414ebb4e48ed9d2`

## Verdict

**PASS — matrice technique du Gate Cœur.** Le package et l'exemple passent le
format du périmètre cœur, les analyses fatales, la suite complète et les suites
ciblées sur les deux SDK exacts. Flutter 3.41.0 passe aussi après résolution
minimale par `pub downgrade`. Le lock haut reste byte-identique et aucun
fichier généré ne reste dans le worktree.

Ce verdict ne vaut que pour la voie matricielle indépendante. La revue cumulée
des lots 1 à 5 est une voie séparée du gate et n'est pas revendiquée ici.

Deux observations ne changent pas ce PASS, mais doivent rester visibles :

- `demo/` appartient au lot 6 non intégré à S6. Un contrôle lancé avant toute
  résolution de ses dépendances a indiqué huit fichiers `demo/lib` selon le
  format courant. Ce résultat est différé à la lane démo et à l'union ; il
  n'est pas présenté comme un contrôle de format valide de ce package autonome.
- `git diff --check e9f75af...b07066f` est **BLOCKED pour la future Gate
  Finale** par deux fins de ligne Markdown dans
  `maintenance/decisions/candidate-domain-oracle.md:3-4`. Aucun correctif n'a
  été appliqué dans cette branche documentaire de vérification.

## Identité des SDK et hashes d'entrée

| Entrée | Version exécutée |
|---|---|
| Haute | Flutter `3.47.2`, framework `d3b14c8769`, engine `1cf1c4773fb941c4c74a7f8bb144a8837596c0f4`, Dart `3.13.2`, DevTools `2.60.0` |
| Minimum | Flutter `3.41.0`, framework `44a626f4f0`, engine `cc8e596aa65130a0678cc59613ed1c5125184db4`, Dart `3.11.0`, DevTools `2.54.1` |

Les binaires exacts étaient respectivement :

```text
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter
/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter
```

Hashes SHA-256 avant la matrice, puis identiques après nettoyage :

| Fichier | SHA-256 |
|---|---|
| `example/pubspec.lock` | `115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7` |
| `pubspec.yaml` | `667f07143ddc1609167857eb353d83c88aeab0758890345facdf8857a2c1b812` |
| `example/pubspec.yaml` | `09520ff9a078e7f10008b5a3ac4ee79a625080eba359eb115da94798c3e83310` |
| `analysis_options.yaml` | `0c9fe2b745a2481769c610ec01461ba15cf583e0bc7b451d74eccb93b90f7dc6` |

## Matrice Flutter 3.47.2

Les commandes suivantes ont été exécutées dans le worktree canonique. Chaque
commande Flutter utilisait aussi `--no-version-check --suppress-analytics`.

```sh
flutter pub get --no-example
cd example
flutter pub get --enforce-lockfile
cd ..
dart format --output=none --set-exit-if-changed lib test example
flutter analyze --no-pub --fatal-infos --fatal-warnings lib test
cd example
flutter analyze --no-pub --fatal-infos --fatal-warnings
cd ..
flutter test --no-pub --reporter compact
```

| Contrôle | Résultat |
|---|---|
| Résolution racine | PASS ; 26 dépendances, configuration haute fraîche |
| Lock exemple forcé | PASS ; `Got dependencies!`, aucun changement suivi |
| Format cœur | PASS ; 26 fichiers, 0 changement |
| Analyse package `lib test` | PASS ; aucun diagnostic |
| Analyse application `example/` | PASS ; aucun diagnostic |
| Suite complète | PASS ; 115/115 |

Le format a été exécuté après la résolution haute, afin que Dart lise la
version de langage du package. Le lock canonique a conservé le même SHA-256
avant et après `--enforce-lockfile`.

## Matrice Flutter 3.41.0

Une extraction sûre du SHA exact a été créée dans
`/private/tmp/auto-size-text-gate-core-min.MZ0tEb`, puis supprimée. Le lock haut
a été déplacé dans cette extraction avant toute résolution minimale :

```sh
git archive --format=tar b07066ffe321dff059c9d7d8008b2713e30e1aee \
  | tar -xf - -C /private/tmp/auto-size-text-gate-core-min.MZ0tEb
mv example/pubspec.lock example/pubspec.lock.canonical-high
flutter pub get --no-example
cd example
flutter pub get
flutter analyze --no-pub --fatal-infos --fatal-warnings
cd ..
flutter analyze --no-pub --fatal-infos --fatal-warnings lib test
flutter test --no-pub --reporter compact
flutter pub downgrade --no-example
flutter test --no-pub --reporter compact
```

| Contrôle | Résultat |
|---|---|
| Résolution racine naturelle | PASS ; 26 dépendances, notamment `meta 1.17.0` et `vector_math 2.2.0` |
| Résolution exemple naturelle sans lock haut | PASS ; 10 dépendances, `meta 1.17.0`, `vector_math 2.2.0` |
| Analyse package `lib test` | PASS ; aucun diagnostic |
| Analyse application `example/` | PASS ; aucun diagnostic |
| Suite complète avant downgrade | PASS ; 115/115 |
| `pub downgrade --no-example` | PASS ; 9 dépendances abaissées |
| Suite complète après downgrade, `--no-pub` | PASS ; 115/115 |

Le downgrade a notamment sélectionné `leak_tracker 11.0.1`, `lints 6.0.0` et
`vm_service 11.10.0`. Aucun lock de l'extraction n'a été recopié vers le
worktree canonique.

## Suites ciblées

Les mêmes fichiers ont été rejoués sous 3.47.2 avec le graphe haut et sous
3.41.0 avec le graphe downgradé. Tous les appels utilisaient `--no-pub`.

| Axe | Fichiers | 3.47.2 | 3.41.0 downgradé |
|---|---|---:|---:|
| Fuite et lifecycle | `leak_tracking_test.dart`, `text_painter_lifecycle_test.dart` | PASS 9/9 | PASS 9/9 |
| Domaine et grille | `min_max_font_size_test.dart`, `preset_font_sizes_test.dart`, `step_granularity_test.dart` | PASS 29/29 | PASS 29/29 |
| Scaler et configuration | `text_scaler_test.dart`, `effective_text_configuration_test.dart` | PASS 21/21 | PASS 21/21 |
| RichText, NBSP/NNBSP, zéro | `rich_text_test.dart`, `wrap_words_test.dart` | PASS 21/21 | PASS 21/21 |
| Groupes | `group_constraints_test.dart`, `group_test.dart`, `group_builder_test.dart` | PASS 20/20 | PASS 20/20 |
| Exemple canonique | résolution et analyse dans `example/` | PASS | PASS |

## Complexité mesurée sans benchmark mural

Des impressions temporaires ont été ajoutées seulement dans deux extractions
jetables, puis les extractions ont été supprimées. Aucun seuil de temps n'a été
utilisé.

| Compteur public observé | Domaine exercé | 3.47.2 | 3.41.0 downgradé | Gate permanent |
|---|---:|---:|---:|---|
| Builds du `TextSpan` de recherche | environ 1 milliard de candidats | 30 | 30 | `0 < count <= 40` |
| Appels du scaler pendant fit et projection de groupe | environ 1 000 milliards de candidats | 182 | 182 | `count < 200` |
| Appels `computeToPlainText` | wrap vrai, puis trois configurations riches | `0 → 1 → 2 → 3` | `0 → 1 → 2 → 3` | valeurs exactes |
| Microtâches de groupe planifiées/exécutées | deux baisses synchrones | `1/1` | `1/1` | valeurs exactes |

Ces compteurs établissent une croissance logarithmique de la recherche et une
segmentation hors de la boucle de candidats. Ils ne prétendent pas mesurer la
performance absolue de la machine.

## Résultats linéaires historiques

Le témoin S1 exact `e9f75af9c3ef54bee2cbd3fcc0a53b44e7811968`
(tree `1db4fe7b5126f1f54a11c549ad6cb63f5f4f379d`) a été extrait et sa suite
historique a passé **25/25** sous Flutter 3.47.2.

Sur S6, trois témoins explicites ont ensuite passé séparément sur les deux pins,
y compris sur le graphe minimum downgradé :

| Témoin | Résultat historique attendu | 3.47.2 | 3.41.0 downgradé |
|---|---|---:|---:|
| Domaine régulier 12…60 | rend 60 avec espace, 12 sans espace | PASS | PASS |
| Fitting mot simple `wrapWords: false` | rend 20 puis 10 | PASS | PASS |
| Groupe homogène, scaler linéaire 2 | rend `[32, 32]` | PASS | PASS |

La suite complète S6 conserve en plus toutes les assertions historiques
remaniées lors du lot 0. Cette comparaison ne repose pas sur un benchmark ou
sur une inspection de widget seule : les témoins modernes lisent le vrai
`RenderParagraph` lorsque la taille effective l'exige.

## Preuves rouges archivées et relecture

Les cinq parents exacts cités dans les journaux existent dans l'objet Git :

| Lot | Parent rouge exact | Signature archivée vérifiée |
|---|---|---|
| #150 / painters | `e9f75af9c3ef54bee2cbd3fcc0a53b44e7811968` | 20 `TextPainter notDisposed` sur la suite initiale ; 2 sur le chemin `wrapWords: false` isolé ; 1 pour le helper avant son correctif |
| Grille / domaine | `ae52fe6d15a688621b2470d3f4a10555a410d686` | 13 passages et 15 échecs ; décimaux/non-multiples, bornes exactes, validations runtime et ratios non représentables discriminés |
| Scaling / configuration | `a13534cd12842b2e6847feb4963842175a96ee10` | API `textScaler` absente à la compilation ; configuration finale 4 passages/3 échecs avec tailles `23/30`, strut et `softWrap` |
| RichText / NBSP / zéro | `3a1c343e88325b0020452be7c3258a902d87558f` | héritage riche, overrides, zéro, frontière WidgetSpan et plages NBSP/NNBSP rouges ; ancien snapshot de segmentation 30 appels au lieu de 1 |
| Groupes | `c9a1adc006365feb3e1750069ca1e115c3f20237` | première suite 1 passage/10 échecs ; domaine, presets, scalers, ULP, plateau zéro et coalescence discriminés |

Les rapports committés contiennent les commandes, parents, nombres et
signatures. Le roadmap autorise les logs bruts joints aux revues sans exiger
leur commit ; aucun log brut indépendant n'est donc inventé ici. Hashes
SHA-256 des couples journal/revue d'assemblage relus :

| Lot | Journal | Revue indépendante ou assemblage |
|---:|---|---|
| 1 | `765938d297cbc5b619b475f986c3ea23681a3ea439e812399525c826b2a89149` | `787b1f1040b5c8cd0c47cd583744dd5dbfa65a5768a1c9eb0c8f7b60de97340d` |
| 2 | `48d1532b4047dc3cadf968bee3ce203ed46c0bb93aef8f966298f2faf1676db5` | `9cd7ed4e83854a9f77c3f53e0b6bcc9f153ca67464b55246d42e0c4a57d3818c` |
| 3 | `5dcf680d4a0ff28b61428711ceaa8da4b4cffbbe2c66663add1508a9f8d41364` | `f0421f0f00663e68a71df23729a24d0558732be9ddb6cda62f3981ae02d84075` |
| 4 | `d1e60714c11e41a7c6103346e33d5f2284b9bade05acabc968364bdf7c6aa385` | `ddb19cab1b6761a9d6e0a3c1512d834c4b83787ab076b17cf0729fe9e9a75bf5` |
| 5 | `b03037e95b33dbbb0faa8de6cdf568aa87ebc2f38882197f400561c88db17957` | `6c6acd86c1c59d6ad47868954541f09e31aba844a4a55190f65bfcba45fdb23e` |

## Mutants indépendants de cette matrice

Quatre mutations simples ont été appliquées séparément par intention dans une
copie temporaire de S6. La copie contenait les compteurs de test temporaires,
mais aucune modification n'a été reportée dans le worktree.

| Mutant temporaire | Oracle ciblé | Rouge observé |
|---|---|---|
| Suppression du `dispose` du painter principal | premier cas lifecycle | code 1 au `tearDownAll`, `notDisposed.total = 4`, classe `TextPainter`, stack `_checkTextFits` |
| Suppression de la borne `candidate <= localCandidate` | plateau riche à racine zéro | attendu 70, réel 120 |
| NBSP et NNBSP traités comme séparateurs | plage liée riche | attendu 10, réel 20 |
| Grille régulière ancrée à zéro | grille publique `0.3/0.1` | code 1, `ArgumentError` de progression au lieu du candidat valide |

Ces rouges couvrent indépendamment la fuite #150, la double borne de groupe,
la règle Unicode ciblée et l'ancrage au minimum. Les mutations et les
extractions ont été supprimées après capture.

## Format, propreté et limites

Un premier appel de `dart format --output=none` avait été lancé avant
`flutter pub get`. Sans `.dart_tool/package_config.json`, Dart ne pouvait pas
résoudre `flutter_lints` ni la version de langage du package. Il signalait à
tort `test/utils.dart:53-55` :

```diff
-  final fontData = File('test/assets/Roboto-Regular.ttf').readAsBytes().then(
-    (bytes) => ByteData.view(Uint8List.fromList(bytes).buffer),
-  );
+  final fontData = File('test/assets/Roboto-Regular.ttf')
+      .readAsBytes()
+      .then((bytes) => ByteData.view(Uint8List.fromList(bytes).buffer));
```

Le style courant a été introduit au lot 0 par
`547c1aa77691730b19e08922653033d8606614e8`. Après résolution canonique haute,
le contrôle demandé sur `lib test example` passe avec 26 fichiers et zéro
changement. Cette première invocation n'a modifié aucun fichier grâce à
`--output=none`.

Le même appel pré-résolution avait listé huit fichiers `demo/lib`. Ils ne sont
pas corrigés ou validés ici : les changements de la lane lot 6 ne sont pas
intégrés à S6 et ce package autonome doit être formaté après sa propre
résolution lors de l'union.

Après tous les contrôles et avant la création du présent rapport :

```sh
rm -rf .dart_tool build example/.dart_tool pubspec.lock
git status --short
git status --ignored --short
git diff --exit-code
git ls-files -o --exclude-standard
```

Les quatre inspections Git ont une sortie vide et un code 0. Il ne reste ni
`.dart_tool`, ni `build`, ni lock racine ignoré, ni lock minimum, ni probe, ni
mutant. Seul le présent rapport est ajouté par cette branche.

Le diff cœur S1…S6 porte sur 50 fichiers, 14 506 insertions et 342 suppressions.
Sa revue sémantique cumulée est volontairement laissée à la voie de revue
indépendante prévue par le Gate Cœur.

## Statuts finaux de la voie matrice

| Critère | Statut |
|---|---|
| SDK exacts 3.47.2 et 3.41.0 | PASS |
| Lock haut forcé et byte-identique | PASS |
| Résolution minimum sans lock haut | PASS |
| Format cœur haute | PASS |
| Analyses fatales package + exemple, deux SDK | PASS |
| Suites complètes, avant et après downgrade | PASS |
| Suites ciblées et compteurs | PASS |
| Témoins linéaires historiques | PASS |
| Preuves rouges rapportées et mutants discriminants | PASS |
| Absence de dérive et de fichiers temporaires | PASS |
| Revue cumulée lots 1 à 5 | HORS DE CETTE VOIE |
| `git diff --check` futur sur toute la plage | BLOCKED, deux fins de ligne Markdown |
| Gate Cœur — voie matricielle | **PASS** |
