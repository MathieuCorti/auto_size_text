# Validation indépendante d’assemblage — lot 5, groupes

Date : 2026-09-01

Branche validée : `codex/integrate-groups-reviewed`

Tête assemblée avant le présent rapport :
`ba2e31fe004ec1cc8a09392c12ee54cee22e8693`

Base technique d’intégration :
`69b9ff3ab3cb7f238efce43cab167be34d177e4e`

Tip d’implémentation approuvé comparé :
`f58083390ef3ffbde800856ca9ec72242b7cd3da`

Worktree exclusif : `/private/tmp/auto-size-text-integrate-groups`

## Verdict

**ACCEPTÉ**

Le lot 5 est correctement assemblé sur la base technique demandée. Les trois
fichiers produit, les cinq fichiers de tests et le journal d’implémentation
sont byte-identiques aux blobs du tip approuvé `f580833`. Les onze commits
d’implémentation ont chacun le même patch-id stable que leur cherry-pick dans
la branche d’intégration.

Les deux documents adversariaux déjà présents dans `69b9ff3` sont conservés
sans changement. Les trois rapports finaux portent explicitement le verdict
`ACCEPTÉ`, et l’historique permet de suivre les exigences initiales, les deux
faiblesses de preuve, le correctif d’identité, les oracles renforcés et leurs
contre-revues finales.

La relecture du diff cumulé n’a trouvé aucune interaction défectueuse avec les
lots 0 à 4. Les matrices Flutter 3.41.0 et 3.47.2, le downgrade, l’exemple et
les contre-preuves mutantes sont conformes. Aucun finding P0, P1, P2 ou P3 ne
reste ouvert.

## Fidélité de l’assemblage

### Comparaison byte-for-byte avec le tip approuvé

`git hash-object` sur l’arbre assemblé a été comparé à
`git rev-parse f580833:<fichier>` dans le worktree d’implémentation. Les neuf
comparaisons sont identiques :

| Fichier | Blob assemblé et tip approuvé |
|---|---|
| `lib/src/auto_size_group.dart` | `f282ec2acded165692c74255dbf08412d7939793` |
| `lib/src/auto_size_text.dart` | `3dde5d2fe6612379f1ac23bee442e7a4afd1269e` |
| `lib/src/auto_size_text_layout.dart` | `24d7ad8470f69b53e724740a8ce69beabb1cd8a6` |
| `maintenance/implementation/lot-5-groups.md` | `f7de7b39d55a75772446ba02ae5c9773bb1dbc9c` |
| `test/group_builder_test.dart` | `5e438ae2659ba8ff69d565c6143793caf9b8929c` |
| `test/group_constraints_test.dart` | `1f994d7f09d7e6ace0c4c968536930a9cf18ef8e` |
| `test/group_test.dart` | `937072560a4bf4b1a947b3db5a660d9f6f0087ab` |
| `test/preset_font_sizes_test.dart` | `4a2592546fb3cb26484d44d72c7e88ce27c067e9` |
| `test/text_scaler_test.dart` | `47a0cdf72a0627c9ba5fe57bfe754d992006c1a4` |

### Documents adversariaux déjà dans la base

La branche d’implémentation et la branche d’intégration divergent depuis
`c9a1adc006365feb3e1750069ca1e115c3f20237`; `69b9ff3` n’est donc pas un
ancêtre de `f580833`. Un diff artificiel `69b9ff3..f580833` présente les deux
documents adversariaux comme supprimés, mais cette suppression ne fait pas
partie du lot produit/tests/journal à assembler.

L’intégration conserve correctement les blobs de sa base :

| Document | Blob dans `69b9ff3` | Blob dans `ba2e31f` |
|---|---|---|
| `maintenance/decisions/group-lifecycle-adversarial-oracle.md` | `400abc1183045b3e6eac8d018d084d95b5ca9fef` | identique |
| `maintenance/reviews/group-lifecycle-adversarial-oracle-review.md` | `0339951feb47af63137d233b1ad22c01cc5926be` | identique |

### Patch-ids des onze commits d’implémentation

Chaque ligne associe le commit du worktree d’implémentation au cherry-pick de
l’intégration et à leur patch-id stable commun :

| Implémentation | Intégration | Patch-id stable |
|---|---|---|
| `1ef0f8f` | `05aed3e` | `29c43f136a36706b0739393a8b32d4361da65edb` |
| `c2b7825` | `60e8db6` | `812196491a206561eabd843d3db1ca05902ca50b` |
| `06f0326` | `9483390` | `2794d1f7ca2a793a60a7bd15e12ecefba2679fba` |
| `b7bd149` | `b32100f` | `c5d8b02f6ade479d555a10a4468c2d75c1630d05` |
| `8505ee6` | `b8c96af` | `f20ee47a050edafb36d29696c8cec61962321079` |
| `713be70` | `f2d2caa` | `537e49caa06e9ff8c3b64d634dd88f93b9bcc540` |
| `d2bcdc9` | `007c761` | `6e1b57598124f012522bbf6e821d47a81ab9361f` |
| `2f87be2` | `ce56e53` | `9d24c018efd12f102c92ff75681752280af66993` |
| `1794808` | `ad4089b` | `4357bf4c8da08355d02d21dec3917786c23550ea` |
| `44435ce` | `dfd1932` | `d8978766cb4e68fa142ec142292faf936c130c05` |
| `f580833` | `5e1043c` | `9de736e8c79c76717d67fec23a035139c557f157` |

Cette correspondance prouve à la fois le contenu final et la conservation de
la progression test rouge, correctif, renforcement et journal.

## Rapports finaux et traçabilité des corrections

Les trois rapports assemblés contiennent exactement les marqueurs suivants :

- `maintenance/reviews/lot-5-groups-review.md:34` : `**ACCEPTÉ.**` ;
- `maintenance/reviews/lot-5-groups-lifecycle-review.md:21` :
  `**ACCEPTÉ**` ;
- `maintenance/reviews/lot-5-groups-projection-review.md:24` :
  `**ACCEPTÉ**`.

Leur historique documentaire est également séquentiel et explicite :

| Rapport | Historique dans l’intégration |
|---|---|
| Revue générale | `929e9dd` revue initiale → `f65d8fa` contre-revue des fixes → `a0101cd` acceptation de l’oracle strict → `ad2ad21` validation de la frame de retrait |
| Revue lifecycle | `43706fe` revue initiale → `aa7f3fe` revalidation des fixes → `e9873bc` revue de l’oracle strict → `15fa10f` acceptation finale |
| Revue projection | `b1249dd` revue initiale → `fd288b3` revalidation des fixes → `71b4af8` acceptation de l’oracle strict → `ba2e31f` sanity finale |

La chaîne exigences → changements → preuves est traçable :

1. `05aed3e` ajoute les régressions de projection hétérogène sur le produit S5,
   puis `60e8db6` implémente la séparation `L/P/G/R`, la projection dans le
   domaine propre et la coalescence.
2. `9483390` renforce le plateau à racine zéro pour distinguer le passage
   direct de `G`, la perte de borne locale et la composition RichText.
3. La revue initiale détecte une preuve insuffisante de conservation du rapport
   et une comparaison de groupes fondée sur `==`. `b8c96af` ajoute les
   régressions de rétention et d’identité ; `f2d2caa` corrige le produit avec
   `identical` ; `007c761` journalise ces changements.
4. La contre-revue montre que le premier oracle de rétention ne tue pas un
   rollback complet. `ce56e53` garde A inchangé, place l’observateur avant A et
   retire seulement B ; `ad4089b` consigne la preuve rouge 70/50.
5. La dernière contre-revue montre que les pompes pouvaient masquer l’absence
   de notification au retrait. `dfd1932` exige la frame intermédiaire ;
   `5e1043c` consigne le rouge `false/true` du mutant no-schedule.

Le produit n’a pas été modifié pour fermer les deux faiblesses test-only. Le
seul correctif produit post-revue est la comparaison d’identité, avec sa
régression permanente.

## Relecture du diff cumulé et interactions lots 0 à 4

Le diff complet `69b9ff3..ba2e31f` et chacun de ses douze fichiers ont été lus
intégralement :

1. `lib/src/auto_size_group.dart` ;
2. `lib/src/auto_size_text.dart` ;
3. `lib/src/auto_size_text_layout.dart` ;
4. `maintenance/implementation/lot-5-groups.md` ;
5. `maintenance/reviews/lot-5-groups-review.md` ;
6. `maintenance/reviews/lot-5-groups-lifecycle-review.md` ;
7. `maintenance/reviews/lot-5-groups-projection-review.md` ;
8. `test/group_builder_test.dart` ;
9. `test/group_constraints_test.dart` ;
10. `test/group_test.dart` ;
11. `test/preset_font_sizes_test.dart` ;
12. `test/text_scaler_test.dart`.

Les deux documents adversariaux conservés depuis la base ont aussi été lus
intégralement. Aucun `AGENTS.md` additionnel n’existe dans ce worktree. Les
instructions PostHog fournies au chantier ne s’appliquent pas à cette
validation Flutter locale. Les guides `developing-flutter`, ses cinq
références, et `find-bugs` ont été appliqués.

Constats d’interaction :

- **Lots 0–1, API et comportement historique.** Aucune nouvelle API, aucun
  manifeste, lock ou exemple produit n’est modifié. Le groupe homogène,
  l’upsizing historique et l’identité d’`AutoSizeGroupBuilder` restent
  couverts. La suite complète conserve tous les tests antérieurs.
- **Lot 2, domaine candidat.** La projection réutilise `_CandidateSet` et sa
  dichotomie par indices. Les presets restent copiés, triés logiquement et
  immuables côté appelant ; les grilles restent virtuelles. Aucune tolérance de
  déduplication n’est réutilisée sur la borne effective exacte.
- **Lot 3, configuration effective et accessibilité.** Seule
  `U.scale(L)` est publiée. Les scalers explicite, legacy ou ambiant restent
  résolus par la configuration existante ; la projection n’utilise jamais le
  getter de compatibilité `textScaleFactor`. Les sorties non finies ou
  négatives sont rejetées avant d’entrer dans le minimum.
- **Lot 4, RichText et ressources.** Le candidat projeté est rendu par le même
  `_CandidateTextScaler`, ce qui conserve la composition par run et les
  plateaux, y compris la référence racine zéro. La projection ne crée aucun
  `TextPainter`; les painters du fit restent libérés dans leurs `finally`.
  `overflowReplacement` dépend toujours du fit local et non de la projection.
- **État partagé.** Le cache contient seulement le dernier `P` publié. Le
  groupe recalcule `G` après écriture ou retrait, coalesce les variations avec
  un marqueur posé avant `scheduleMicrotask`, capture les membres au run puis
  revalide inscription et `mounted`. Le transfert retire avant inscription et
  compare les contrôleurs par identité.
- **Complexité.** La projection est `O(log C)` sans scan ni matérialisation du
  domaine. Le recalcul du minimum reste `O(M)`, comme autorisé par l’oracle.

Aucun conflit entre lots, double scaling, republication de `R`, painter
orphelin, callback tardif, sortie hors domaine ou oscillation stable n’a été
trouvé.

## Matrice indépendante

Toolchains réellement constatées :

```text
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
engine 1cf1c4773fb941c4c74a7f8bb144a8837596c0f4

Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
engine cc8e596aa65130a0678cc59613ed1c5125184db4
```

### Flutter 3.47.2

Commandes principales :

```text
/Users/mathieu/fvm/versions/3.47.2/bin/flutter pub get --no-example

cd example
/Users/mathieu/fvm/versions/3.47.2/bin/flutter pub get --enforce-lockfile
/Users/mathieu/fvm/versions/3.47.2/bin/flutter analyze --no-pub \
  --fatal-infos --fatal-warnings

cd ..
/Users/mathieu/fvm/versions/3.47.2/bin/dart format \
  --output=none --set-exit-if-changed lib test example
/Users/mathieu/fvm/versions/3.47.2/bin/flutter analyze --no-pub \
  --fatal-infos --fatal-warnings lib test
/Users/mathieu/fvm/versions/3.47.2/bin/flutter test --no-pub \
  --reporter compact <les neuf fichiers ciblés>
/Users/mathieu/fvm/versions/3.47.2/bin/flutter test --no-pub \
  --reporter compact test/text_painter_lifecycle_test.dart \
  test/leak_tracking_test.dart
/Users/mathieu/fvm/versions/3.47.2/bin/flutter test --no-pub \
  --reporter compact
```

Résultats : résolution racine 26 dépendances ; résolution d’exemple réussie ;
format 26 fichiers, 0 changement ; analyses package/tests et exemple sans
diagnostic ; ciblés 61/61 ; lifecycle/leak 9/9 ; suite 115/115.

Les neuf fichiers ciblés étaient :

```text
test/group_constraints_test.dart
test/group_test.dart
test/group_builder_test.dart
test/preset_font_sizes_test.dart
test/text_scaler_test.dart
test/rich_text_test.dart
test/overflow_replacement_test.dart
test/text_painter_lifecycle_test.dart
test/leak_tracking_test.dart
```

### Flutter 3.41.0 et downgrade

Le lock haut de l’exemple a été déplacé vers un répertoire temporaire avant la
résolution naturelle minimale, puis restauré après la matrice.

```text
/Users/mathieu/fvm/versions/3.41.0/bin/flutter pub get --no-example

cd example
/Users/mathieu/fvm/versions/3.41.0/bin/flutter pub get
/Users/mathieu/fvm/versions/3.41.0/bin/flutter analyze --no-pub \
  --fatal-infos --fatal-warnings

cd ..
/Users/mathieu/fvm/versions/3.41.0/bin/flutter analyze --no-pub \
  --fatal-infos --fatal-warnings lib test
/Users/mathieu/fvm/versions/3.41.0/bin/flutter test --no-pub \
  --reporter compact <les neuf fichiers ciblés>
/Users/mathieu/fvm/versions/3.41.0/bin/flutter test --no-pub \
  --reporter compact test/text_painter_lifecycle_test.dart \
  test/leak_tracking_test.dart
/Users/mathieu/fvm/versions/3.41.0/bin/flutter test --no-pub \
  --reporter compact
/Users/mathieu/fvm/versions/3.41.0/bin/flutter pub downgrade --no-example
/Users/mathieu/fvm/versions/3.41.0/bin/flutter test --no-pub \
  --reporter compact
```

Résultats : résolution racine 26 dépendances ; résolution d’exemple 10
dépendances ; analyses sans diagnostic ; ciblés 61/61 ; lifecycle/leak 9/9 ;
suite naturelle 115/115 ; neuf dépendances abaissées ; suite après downgrade
115/115.

Après retrait des mutants, `group_constraints_test.dart + group_test.dart` a
été rejoué une dernière fois sur la résolution downgradée : 18/18.

### Lock canonique

Avant la matrice puis après restauration :

```text
SHA-256 115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7
blob Git 42b1f7bc18c27af011d30a4f428618c7fbf7a49f
fichier  example/pubspec.lock
```

Le lock suivi est donc inchangé.

## Mutants et contre-preuves rejoués

Les mutants ont été appliqués séparément avec `apply_patch`, testés sous
Flutter 3.41.0, puis restaurés immédiatement. Aucun code mutant n’a coexisté
avec un autre et aucun changement produit/test ne subsiste.

| Mutant temporaire | Test ciblé | Rouge observé |
|---|---|---|
| Rollback complet `_remove/_register`, cache remis à `null` après erreur de projection | oracle d’invalide | `Expected: 50`, `Actual: 70.0` |
| Suppression de la notification dans `_remove` | même oracle, assertion intermédiaire | `Expected: true`, `Actual: false` |
| Retour à `oldWidget.group != widget.group` | transfert entre contrôleurs égaux | `[20,20,40]` au lieu de `[20,40,20]` |
| Suppression de la borne `candidate <= L` | plateau RichText racine zéro | box `120.0` au lieu de `70` |
| Republication de `U.scale(R)` | presets disjoints | second membre `10.0` au lieu de `30` |
| Projection linéaire | terminal temporaire `102.5`, soit environ 1 024 candidats | `1551` appels, attendu `<200` |

La variante linéaire a volontairement réduit le terminal logique temporaire à
`102.5` pour éviter de scanner le domaine permanent d’environ mille milliards
de candidats. La valeur projetée attendue est restée identique ; seul le
compteur de complexité a échoué. Le terminal permanent a ensuite été restauré
à `100000000000.1` avant le sanity 18/18.

Commandes de test mutantes :

```text
/Users/mathieu/fvm/versions/3.41.0/bin/flutter test --no-pub \
  --reporter expanded test/group_constraints_test.dart \
  --plain-name 'should reject an invalid scaler result reached during projection'

/Users/mathieu/fvm/versions/3.41.0/bin/flutter test --no-pub \
  --reporter expanded test/group_test.dart \
  --plain-name 'should transfer between equal groups using controller identity'

/Users/mathieu/fvm/versions/3.41.0/bin/flutter test --no-pub \
  --reporter expanded test/group_constraints_test.dart \
  --plain-name 'should keep the local rich candidate on a zero-root plateau'

/Users/mathieu/fvm/versions/3.41.0/bin/flutter test --no-pub \
  --reporter expanded test/group_constraints_test.dart \
  --plain-name 'should keep disjoint presets stable without republishing a projection'

/Users/mathieu/fvm/versions/3.41.0/bin/flutter test --no-pub \
  --reporter expanded test/group_constraints_test.dart \
  --plain-name 'should keep projection logarithmic for a trillion virtual candidates'
```

## Audit de surface et sécurité

Les entrées de la surface modifiée sont les propriétés locales du widget, les
contraintes de layout, les domaines de candidats, les scalers et l’identité du
groupe. L’état partagé est limité à une map membre/rapport, un minimum, un
cache par état et une microtâche coalescée. Les seuls appels externes sont les
API Flutter de texte, layout et scheduling.

Il n’existe dans ce diff aucun input réseau, requête de base de données,
authentification, autorisation, session, opération cryptographique ou secret.
Injection, XSS, CSRF, IDOR, cryptographie et divulgation sont hors surface.

Les points applicables de la checklist `find-bugs` ont été contrôlés :

- courses et TOCTOU : ordre écriture/recalcul/notification, pending, snapshot
  au run, revalidation avant callback, transfert et dispose ;
- disponibilité : deux dichotomies logarithmiques, aucune allocation
  proportionnelle au domaine et aucun painter de projection ;
- logique métier : séparation `L/P/G/R`, égalité effective exacte, fallback au
  minimum, erreur non transactionnelle et replacement local ;
- ressources : dispose des painters et absence de callback après dispose ;
- qualité des preuves : rouges S5, six mutants discriminants, frames témoins,
  deux SDK exacts et suites complètes.

Aucune zone demandée n’est restée non vérifiée.

## Nettoyage et état final avant commit

Après les mutants :

```text
git diff -- lib test
# vide

git diff --check
# succès
```

Après restauration du lock, les artefacts générés ont été inventoriés avec
`git clean -ndX`, puis les seuls chemins suivants ont été supprimés :

```text
.dart_tool/
build/
example/.dart_tool/
pubspec.lock
```

`pubspec.lock` à la racine était généré et ignoré ; le lock suivi de l’exemple
n’a pas été supprimé. Avant la création du présent rapport, `git status` était
propre sur `codex/integrate-groups-reviewed`. Le commit final de cette
validation doit contenir uniquement ce document.
