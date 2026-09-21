# Feuille de route d'implémentation consolidée

> Historical record of the completed 4.0.0 migration. This roadmap is not an
> active work plan, approval requirement, or validation gate. Current engineering
> instructions are in root `AGENTS.md` and `.gtm/engineering_policy.md`.

Date : 2026-09-01
Base documentaire et produit : `dev` / `d0fe48d60715ec749f9a1761416abc1b6f368dcf`
Objet : prochaine modernisation majeure d'`auto_size_text`, sans publication,
tag, fermeture d'issue ou mutation distante.

## Décision exécutive

Cette feuille de route remplace, pour l'ordonnancement de l'implémentation, les
plans individuels de `maintenance/plans/`. Les audits et revues restent les
preuves détaillées. En cas de divergence, les corrections des revues
indépendantes sont appliquées ici.

Le chantier comprend **13 lots d'implémentation** et quatre gates de validation.
Tous les bugs confirmés qui bloquent la release sont inclus. Les demandes de
fonctionnalités, les PR historiques dangereuses, la publication et les actions
GitHub nécessitant des credentials sont exclues.

Les décisions structurantes sont les suivantes :

- la cible de version est `4.0.0`, car le relèvement du minimum et le changement
  observable de `textKey` sont cassants même si `textScaleFactor` reste
  temporairement compatible ;
- le minimum **cible** du package et de l'exemple est Flutter `3.41.0` / Dart
  `3.11.0`, avec `sdk: '>=3.11.0 <4.0.0'` et `flutter: '>=3.41.0'` ;
- Flutter `3.41.6` n'est pas le minimum : ses tests historiques sont une preuve
  complémentaire seulement. Le tag `3.41.0` est le premier stable contenant
  les trois overrides `MediaQuery` nécessaires ;
- ni le bundle exact `3.41.0`, ni Flutter `3.47.2` / Dart `3.13.2` n'ont été
  exécutés par les audits/revues. **Aucun lot produit ne peut être mergé avant
  le gate SDK exact du lot 0** ;
- si `3.41.0` échoue pour une raison propre au SDK et non corrigeable dans ce
  package, le chantier s'arrête. Passer à `3.41.6` exige une décision de support
  écrite, une justification des correctifs `3.41.1` à `3.41.5` exclus, puis la
  mise à jour atomique du pubspec, de la CI et de la documentation. Un test
  réussi sur `3.41.6` ne permet jamais d'annoncer `3.41.0` ;
- la pin haute à exécuter pour ce plan est Flutter `3.47.2` / Dart `3.13.2`,
  référence officielle au jour des audits. Elle doit être revérifiée dans
  l'archive officielle avant le lot 0 et avant la validation finale ;
- `TextScaler? textScaler` est ajouté aux deux constructeurs ;
  `double? textScaleFactor` reste disponible, déprécié, validé en runtime et
  mutuellement exclusif avec `textScaler` ;
- les corrections intrinsics et `WidgetSpan` restent release-blocking, mais ne
  commencent qu'après un prototype GO. Une garde ou un
  `placeholderDimensions` public ne les remplace pas ;
- `demo/` reste dans Git, conserve ses six écrans, devient une application
  testée sur sa propre toolchain et est exclu de l'archive pub ;
- `example/` reste l'exemple canonique livré ;
- Codecov, OIDC, tag, publication, réglages de branche, fermeture d'issues et
  toute autre mutation distante sont hors de ce plan.

## Modèle de branches et d'intégration

Le coordinateur crée localement `codex/impl-integration` sur `d0fe48d`. Chaque
agent travaille dans un worktree distinct, sur la branche indiquée ci-dessous.
Une branche est créée depuis le **SHA d'intégration validé** demandé, jamais
depuis une branche de lot encore en revue. Les agents n'effectuent ni merge
dans l'intégration, ni push, ni opération GitHub.

Notations de base :

| Repère | Contenu validé attendu |
|---|---|
| `S0` | `d0fe48d60715ec749f9a1761416abc1b6f368dcf` |
| `S1` | `S0` + lot 0 |
| `S2` à `S6` | chaîne cœur : lots 1 à 5, dans cet ordre |
| `S7` | `S6` + décision GO du lot 8 |
| `S8` | `S7` + lot 9 |
| `S9` | `S8` + lot 10 |
| `S10` | `S9` + lots parallèles 6 et 7 validés |
| `S11` | `S10` + lot 11 |
| `S12` | `S11` + lot 12 |

Le coordinateur enregistre le SHA réel de chaque repère dans le journal local
du chantier. Les noms `S1`…`S12` ne sont pas des tags Git à créer.

Règles communes de merge et de revert :

1. Chaque lot contient ses régressions et le changement qu'elles protègent.
2. Les nouveaux tests sont démontrés rouges sur le parent du lot pour la cause
   visée, puis verts sur sa tête ; les logs sont joints à la revue, pas
   nécessairement committés.
3. Un reviewer qui n'a pas écrit le lot vérifie le diff complet, les tests et
   les risques explicités ci-dessous.
4. Le coordinateur merge un lot seulement si ses critères d'acceptation et la
   gate intermédiaire applicable sont satisfaits. Il ne résout pas un conflit
   produit en combinant deux intentions : le lot est rebasé par son auteur et
   revu à nouveau.
5. Un lot qui change une API, un domaine numérique ou une frontière render est
   reverté **en entier** si une régression bloquante ne peut pas être corrigée
   dans son périmètre. Aucun fallback approximatif non spécifié n'est conservé
   pour rendre la suite verte. Les deux approximations explicitement adoptées
   par le GO lean du lot 8 — texte minimum pour une replacement lazy et
   placeholder zéro en dry/intrinsic — font partie du contrat, pas d'un
   rattrapage de test.
6. Aucun lot ne cherry-pick une PR amont entière. Les idées utiles sont
   réimplémentées et testées sur la base courante.

## Dépendances et parallélisme réel

```text
S0
 └─ lot 0 — fondation SDK/lints/harness
     ├─ lot 1 ─ lot 2 ─ lot 3 ─ lot 4 ─ lot 5 ─ Gate Cœur
     │                                             └─ lot 8 (prototype GO)
     │                                                 └─ lot 9 ─ lot 10
     ├─ lot 6 — démo ─────────────────────────────────────────────┐
     └─ lot 7 — archive ──────────────────────────────────────────┤
                                                                  └─ Gate Architecture
                                                                      └─ lot 11 — CI
                                                                          └─ lot 12 — docs/version
                                                                              └─ Gate Finale
```

Après le lot 0, trois agents peuvent réellement avancer sans modifier les
mêmes surfaces :

- un agent sur la chaîne cœur, **un seul lot cœur à la fois** ;
- un agent sur la démo (`demo/**`) ;
- un agent sur l'archive (`.pubignore`).

Les lots 1 et 2 ne sont pas parallèles en pratique : tous deux modifient
`lib/src/auto_size_text.dart`, le harness et des tests voisins. Les lots 3 à 5
sont volontairement empilés, car leur unité de taille et leur domaine de
candidats doivent rester uniques. Les lots 9 et 10 sont également séquentiels :
`WidgetSpan` se construit sur la frontière render stabilisée par les
intrinsics. Le lot CI attend l'union de toutes les pistes afin de ne pas masquer
une baseline rouge avec des exclusions temporaires.

Le chemin critique est : **0 → 1 → 2 → 3 → 4 → 5 → Gate Cœur → 8 → 9 → 10 →
Gate Architecture → 11 → 12 → Gate Finale**. Les lots 6 et 7 sont hors chemin
critique s'ils terminent avant le lot 10.

## Critères communs de qualité

- La recherche reste logarithmique dans le nombre de candidats ; aucun tableau
  proportionnel à la plage de tailles n'est matérialisé.
- Tout `TextPainter` temporaire est libéré dans un `finally`; tout painter
  persistant est libéré par son propriétaire.
- Mesure et rendu utilisent la même configuration de paragraphe. Une
  transformation déjà appliquée au painter n'est pas réappliquée par `Text`.
- Aucune passe dry ou intrinsèque ne lit une référence de groupe mutable, ne
  publie une taille, ne planifie une microtâche ou ne modifie un cache observable.
- Les entrées qui protègent l'algorithme sont validées en runtime par
  `ArgumentError`, sans dépendre des assertions release.
- Les fichiers de test touchés utilisent `group()` et des noms « should … ».
- Le format est produit une seule fois par la pin Flutter haute ; analyse et
  tests sont exécutés sur le minimum exact et sur la pin haute dès que la gate
  correspondante les rend disponibles.
- Il n'est pas demandé d'atteindre 100 % de couverture. Chaque test doit pouvoir
  échouer si le comportement réel régresse.

## Lot 0 — Fondation SDK, lints, dépendances et harness

**Branche :** `codex/impl-foundation-sdk`
**Base :** `S0`
**Dépendances :** aucune
**Bloque :** tous les lots produit

### Surface

- `pubspec.yaml`, `example/pubspec.yaml` ;
- `analysis_options.yaml`, `.gitignore` ;
- `example/pubspec.lock` ;
- fichiers Dart modifiés uniquement par format/lints mécaniques ;
- configuration de test de fuite et dépendance dev bornée seulement si
  `flutter_test` ne suffit pas.

`demo/pubspec.yaml` et `demo/pubspec.lock` appartiennent au lot 6.

### Travail

- déclarer Flutter `>=3.41.0` et Dart `>=3.11.0 <4.0.0` à la racine et dans
  l'exemple ;
- remplacer `pedantic` par `flutter_lints: ^6.0.0`, vérifier sa résolution sur
  les deux pins et inclure `package:flutter_lints/flutter.yaml` ; déclarer la
  dépendance directement dans chaque package autonome qui consomme cette
  configuration ;
- supprimer `strong-mode`, l'ignore `include_file_not_found` et les règles
  obsolètes ; n'ajouter que des options strictes reconnues par `3.41.0` ;
- limiter l'ignore Git à `/pubspec.lock`, versionner le lock de l'exemple et
  prouver qu'il est consommable avec `--enforce-lockfile` sur minimum et haute ;
- choisir un mécanisme de leak tracking qui observe les ressources natives. Si
  une dépendance directe est nécessaire, la résoudre avec une plage bornée sur
  le minimum ; `any` est interdit ;
- formater le diff mécanique avec la pin haute uniquement ;
- conserver une allowlist de commande, pas un ignore analyzer global, pour les
  seules dépréciations `textScaleFactor` encore présentes avant le lot 3.

### Validation précise

1. Installer/exécuter le **bundle exact** Flutter `3.41.0` et la pin haute
   `3.47.2`; archiver leurs sorties `flutter --version` dans la revue.
2. Sur `3.41.0` : `flutter pub get`, résolution verrouillée de l'exemple,
   analyse sans erreur/warning et avec seulement l'allowlist d'infos connue,
   puis `flutter test`.
3. Sur `3.47.2` : mêmes contrôles, plus
   `dart format --output=none --set-exit-if-changed lib test example`.
4. Vérifier que les trois overrides `MediaQuery` compilent depuis un petit test
   de capacité sur le minimum ; ce test peut être retiré lorsque le lot 3 les
   exerce réellement.
5. `flutter pub downgrade` puis `flutter test --no-pub` sur `3.41.0`.

### Acceptation, risques, revue, revert

- **Acceptation :** les deux SDK exacts ont réellement exécuté les commandes ;
  aucune dépendance discontinue, aucun include manquant, aucun changement de
  comportement ou d'attente historique.
- **Risques :** grand diff de lints, lock incompatible entre SDK, faux test de
  fuite, annonce prématurée du minimum.
- **Reviewer attendu :** mainteneur Flutter/outillage indépendant, qui compare
  manifests, résolution et sorties des deux SDK.
- **Merge :** seulement après Gate SDK ci-dessous. **Revert :** lot entier si
  `3.41.0` ne peut pas consommer la résolution ou si une correction de lint
  change le comportement ; une éventuelle cible `3.41.6` revient en décision,
  elle n'est pas substituée silencieusement.

**Findings couverts :** CORE-09 (partie contrat), audit outillage SDK/lints,
lockfiles, harness et matrice minimale ; ne ferme encore aucun bug produit.

## Lot 1 — Cycle de vie des `TextPainter`

**Branche :** `codex/impl-painter-dispose`
**Base :** `S1`
**Dépendance :** lot 0

### Surface

- `lib/src/auto_size_text.dart` ;
- `test/text_painter_lifecycle_test.dart` ;
- `test/flutter_test_config.dart`, `test/utils.dart` si nécessaires.

### Travail et tests

Encadrer séparément le painter principal et celui de `wrapWords: false` par
`try/finally`, y compris sur retour anticipé et exception. Corriger aussi tout
painter conservé dans les helpers de test.

Tests de fuite, démontrés rouges en retirant chacun des `dispose` : texte simple
qui tient, minimum qui échoue, mot trop large avec retour anticipé, chemin
`wrapWords: false` qui tient, exception, rebuilds répétés et membre de groupe
retiré. Le signal doit suivre la ressource de paragraphe native ou les hooks de
leak Flutter, pas seulement le GC de l'objet Dart.

### Acceptation, risques, revue, revert

- **Acceptation :** aucun résultat de taille historique ne change ; tous les
  sites d'allocation ont un propriétaire et un `finally`.
- **Risque :** test faussement vert ou double-dispose après refactor ultérieur.
- **Reviewer attendu :** reviewer Dart/Flutter ressources, distinct de l'auteur.
- **Merge :** après suite complète sur minimum et haute. **Revert :** entier si
  les tests n'observent pas réellement la ressource native.

**Findings couverts :** issue #150.

## Lot 2 — Domaine de candidats, grille et validations runtime

**Branche :** `codex/impl-candidate-domain`
**Base :** `S2` (`S1` + lot 1)
**Dépendance :** lot 1 uniquement pour éviter un conflit de surface

### Surface

- nouveau `lib/src/auto_size_text_layout.dart` et déclaration `part` dans
  `lib/auto_size_text.dart` ;
- `lib/src/auto_size_text.dart` ;
- `test/step_granularity_test.dart`, `test/min_max_font_size_test.dart`,
  `test/preset_font_sizes_test.dart`, `test/text_fits_test.dart`.

### Contrat

- `_CandidateSet` reste virtuel, fini et strictement croissant après
  déduplication ; il est entièrement contenu dans `[min, upper]` ;
- `min` et la borne haute/référence exacte sont présents ; cette dernière ne
  crée pas un quasi-doublon ;
- les candidats réguliers sont `min + index * step`, jamais
  `floor(min / step) * step` ;
- la tolérance de quasi-égalité est relative :
  `8 × 2^-52 × max(1, |a|, |b|)`. Toute valeur calculée est ensuite contrainte
  aux bornes exactes ;
- si la précision ne permet plus à `min + step` de progresser, l'entrée produit
  un `ArgumentError` plutôt qu'un domaine non strict ;
- la dichotomie retourne toujours une valeur du domaine, y compris quand aucun
  candidat ne tient, et ne matérialise pas la plage ;
- presets : copie non mutante, non vide, valeurs finies et >= 0, ordre
  non-croissant, doublons acceptés puis dédupliqués ; aucun tri silencieux ;
- min, référence et pas sont finis et >= 0 ; pas >= 0,1 ; maximum fini positif
  ou `double.infinity`, et >= min ; l'ancien `textScaleFactor`, lorsqu'il est
  présent, est fini et >= 0. Toute violation lève `ArgumentError` en runtime.

### Tests précis

- `0.3/0.1`, `16.3/1`, `12/5`, intervalle inférieur à un pas et plage non
  multiple du pas ;
- référence `33.5` exacte puis contrainte voisine sélectionnant le précédent ;
- plage historique 12..60/pas 1 inchangée ; très grand ratio intervalle/pas
  sans allocation linéaire ;
- min/max/pas/référence/textScaleFactor NaN, infinis, négatifs, nuls invalides
  et désordonnés via l'API publique, avec `ArgumentError` ;
- presets descendants, doublons, zéro, liste inchangée ; listes vide,
  croissante, négative ou non finie rejetées ;
- tests capables de tourner sans assertions et migration des anciennes attentes
  `AssertionError` concernées.

### Acceptation, risques, revue, revert

- **Acceptation :** aucune sortie sous min/hors presets, référence exacte
  conservée, complexité logarithmique mesurée par compteur.
- **Risques :** quasi-doublons flottants, dépassement d'indice, changement des
  anciennes entrées invalides — ce dernier est intentionnel et documenté.
- **Reviewer attendu :** reviewer algorithmique/numérique indépendant.
- **Merge :** seulement si tous les résultats historiques valides sont
  inchangés. **Revert :** lot entier en cas de domaine non strict ou de coût
  proportionnel au nombre de tailles.

**Findings couverts :** CORE-06, CORE-11, #145 ; durcissement partiel de #151,
qui reste ouverte faute de reproduction originale.

## Lot 3 — `TextScaler` et configuration effective du texte simple

**Branche :** `codex/impl-effective-text`
**Base :** `S3` (`S2` + lot 2)
**Dépendances :** lots 1 et 2

### Surface

- `lib/src/auto_size_text.dart`, `lib/src/auto_size_text_layout.dart` ;
- `test/basic_test.dart`, `test/text_fits_test.dart`,
  `test/overflow_replacement_test.dart`, `test/utils.dart` ;
- nouveaux `test/text_scaler_test.dart` et
  `test/effective_text_configuration_test.dart` ;
- fontes regular/bold déterministes et licence seulement si nécessaires.

README et changelog ne sont pas modifiés ici ; ils appartiennent au lot 12.

### Contrat et travail

- ajouter `TextScaler? textScaler` aux deux constructeurs ; conserver les
  constructeurs `const` ;
- annoter les paramètres des deux constructeurs et le champ historique
  `textScaleFactor` avec `@Deprecated` ; garder l'assertion d'exclusion mutuelle
  et répéter la vérification en runtime avec `ArgumentError` ;
- priorité : scaler explicite, sinon ancien facteur converti en
  `TextScaler.linear`, sinon `MediaQuery.textScalerOf(context)` ;
- valider tout résultat utilisé d'un scaler comme fini et >= 0 ; documenter
  qu'un scaler personnalisé doit être monotone non décroissant ;
- pour une référence positive, le scaler composé calcule
  `userScaler.scale(logicalSize * candidate / reference)` ; il possède une
  égalité et un `hashCode` fondés sur scaler source, candidat et référence ;
- construire une configuration privée immuable du texte **simple** : style
  parent effectif, gras, overrides de hauteur/letter/word spacing, strut
  effectif, direction, locale, alignement, soft-wrap, overflow, maxLines,
  `TextWidthBasis` et `TextHeightBehavior` ambiants ;
- reproduire la largeur de `RenderParagraph` : largeur contrainte si wrap ou
  ellipsis, infinie sinon, puis comparaison à la contrainte réelle ;
- transmettre au `Text` final les entrées appropriées pour que Flutter applique
  les overrides une seule fois. Le painter de mesure est équivalent au rendu,
  pas une transformation réinjectée puis doublée.

Les runs riches hétérogènes, le clonage récursif et la référence zéro sont
réservés au lot 4. Les comportements ambiants de #80/#81 sont respectés sans
ajouter de paramètres publics.

### Tests précis

- scaler absent, ambiant, explicite no-scaling, linéaire et non linéaire ;
  ancien facteur et exclusion mutuelle ; résultats NaN/infini/négatif rejetés ;
- comportement historique #25 et groupes homogènes linéaires inchangés ;
- changement de scaler/MediaQuery entre deux pumps ;
- `boldText` avec fontes aux métriques distinctes ;
- chacun des overrides spacing/height, puis bascule entre frames ;
- strut forcé 100 dans hauteur 60, avec et sans override ;
- softWrap explicite/hérité, clip/ellipsis et `overflowReplacement` ;
- direction RTL et locale héritées puis explicites ; héritage
  `textWidthBasis`/`textHeightBehavior` sans nouvelle API ;
- comparaison des métriques du painter au `RenderParagraph` réellement rendu,
  et non simple inspection d'un widget `Text`.

### Acceptation, risques, revue, revert

- **Acceptation :** aucun usage produit de `MediaQuery.textScaleFactorOf` ou du
  paramètre déprécié de `TextPainter`; mesure et rendu simples concordent.
- **Risques :** composition dans le mauvais ordre, double application des
  overrides, relayouts dus à une égalité incorrecte, hausse volontaire de
  réduction en gras.
- **Reviewer attendu :** spécialiste Flutter texte/accessibilité indépendant.
- **Merge :** après tests minimum + haute et analyse fatale sans allowlist
  `textScaleFactor`. **Revert :** entier si un scaler non linéaire est réduit à
  un facteur ou si la parité n'est prouvée que par inspection de widget.

**Findings couverts :** CORE-02, CORE-03 pour texte simple, #140, #104, #119.

## Lot 4 — RichText fidèle, NBSP/NNBSP et référence zéro

**Branche :** `codex/impl-rich-text`
**Base :** `S4` (`S3` + lot 3)
**Dépendance :** lot 3

### Surface

- `lib/src/auto_size_text.dart`, `lib/src/auto_size_text_layout.dart` ;
- `test/wrap_words_test.dart`, `test/text_scaler_test.dart`,
  `test/overflow_replacement_test.dart` ;
- nouveau `test/rich_text_test.dart`.

### Travail

- placer le `TextSpan` original comme enfant intact d'un parent synthétique
  portant le style effectif ; ne jamais le muter ni recopier seulement quelques
  champs ;
- appliquer récursivement les overrides uniquement aux `TextSpan` standards en
  conservant toutes leurs métadonnées ; laisser sous-types inconnus et
  `WidgetSpan` intacts ;
- pour `wrapWords: false`, mesurer des plages dans le painter non wrappé en
  conservant les runs et indices UTF-16. Les espaces ordinaires, tabulations et
  retours explicites sont des opportunités de séparation ; U+00A0 et U+202F ne
  le sont jamais. Un moteur UAX #14 complet est exclu ;
- référence racine zéro : le parent synthétique reçoit le candidat, les tailles
  explicites des descendants restent inchangées ; aucune division par zéro ni
  epsilon caché ;
- préserver recognizers, semantics et arbre source. Le support automatique des
  `WidgetSpan` n'est pas revendiqué avant le lot 10.

### Tests précis

- span racine partiellement stylé ; enfants imbriqués avec tailles, weights,
  familles, hauteur et espacements différents ; scaler linéaire/non linéaire
  sur plusieurs runs ; sous-type inconnu intact ;
- mot sur plusieurs spans, espace normal, tabulation, retour, NBSP, NNBSP et
  chaîne mixte ;
- recognizer déclenché, semantics conservées, arbre identique après rebuilds ;
- référence zéro simple et riche, min zéro/positif, descendant explicite,
  contrainte minuscule et replacement ;
- painter/rendu concordants pour runs hétérogènes.

### Acceptation, risques, revue, revert

- **Acceptation :** aucune perte de run ou de métadonnée, aucune coupure NBSP,
  aucune division par zéro, aucun double override.
- **Risques :** indices UTF-16/bidi, perte sémantique lors du clonage, coût du
  contrôle des plages.
- **Reviewer attendu :** reviewer RichText/Unicode indépendant.
- **Merge :** après tests rouges ciblés et suite complète. **Revert :** entier
  si l'arbre appelant est muté ou si un flattening réapparaît.

**Findings couverts :** CORE-04, CORE-07, #142 ; complément RichText de CORE-02
et CORE-03.

## Lot 5 — Groupes hétérogènes

**Branche :** `codex/impl-groups`
**Base :** `S5` (`S4` + lot 4)
**Dépendances :** lots 2 à 4

### Surface

- `lib/src/auto_size_group.dart`, `lib/src/auto_size_text.dart`,
  `lib/src/auto_size_text_layout.dart` ;
- `test/group_test.dart`, `test/group_builder_test.dart`,
  `test/preset_font_sizes_test.dart` ;
- nouveau `test/group_constraints_test.dart`.

### Contrat et tests

Chaque membre conserve son candidat logique local qui a effectivement tenu et
publie au groupe sa taille racine effective. Au rendu, il choisit le plus grand
candidat de son propre domaine qui respecte simultanément :

1. `candidate <= localCandidateThatFit` ;
2. `effectiveSize(candidate) <= groupLimit`.

La double borne est obligatoire pour les scalers à plateau. Si aucun candidat
ne peut atteindre la limite commune, le membre rend son minimum/petit preset et
diverge sans modifier la valeur publiée aux autres. La projection est
logarithmique sous l'hypothèse documentée d'un scaler monotone non décroissant.

Tests : minima/maxima/pas différents ; grille fractionnaire ; presets
disjoints et presets donnant la même taille effective ; scalers linéaires,
non linéaires et scaler plateau ; run enfant qui échoue au candidat supérieur ;
replacement lié au fit local ; retrait, changement de groupe, dispose avant
microtâche, remontée bornée et absence d'oscillation.

### Acceptation, risques, revue, revert

- **Acceptation :** aucun membre sous min/hors domaine/au-dessus du candidat
  local ; groupes homogènes historiques inchangés ; convergence bornée.
- **Risques :** confusion unités logiques/effectives, plateau, boucle de
  microtâches, publication déclenchée par une simple projection.
- **Reviewer attendu :** reviewer état/layout indépendant.
- **Merge :** fin de la chaîne cœur, puis Gate Cœur. **Revert :** entier si une
  oscillation ou un candidat étranger au domaine est observé.

**Finding couvert :** CORE-05, plus branche `didUpdateWidget` manquante du
harness historique.

## Lot 6 — Exemple avancé et démo moderne

**Branche :** `codex/impl-demo`
**Base :** `S1`
**Dépendance :** lot 0 ; peut avancer en parallèle des lots 1 à 5

### Surface

- `demo/pubspec.yaml`, `demo/pubspec.lock`, `demo/lib/**`,
  `demo/test/**`, `demo/android/**`, `demo/.metadata`, `demo/.gitignore` ;
- aucun fichier `lib/**` du package et aucun pubspec racine.

### Travail et tests

- déclarer dans le pubspec de la démo le minimum exact de la toolchain utilisée
  pour régénérer son scaffold. Ne pas annoncer `3.41.0` sans exécuter la démo
  dessus ; déclarer directement `flutter_lints` pour que l'include racine soit
  résolu depuis ce package autonome ;
- supprimer `bottom_navy_bar` et `material_design_icons_flutter`, utiliser
  `NavigationBar` et les icônes Flutter, préserver les six destinations et le
  basculement simple/rich ;
- déplacer les appels `SystemChrome` hors de `build` et utiliser l'API actuelle ;
- rendre le groupe de `sync_demo.dart` privé/final/stable et vérifier `mounted`
  avant le redémarrage différé ;
- régénérer Android avec la pin de démo : embedding v2, Plugin DSL, Maven
  Central et niveaux supportés. Ne pas migrer manuellement l'ancien scaffold ;
- si un wrapper est conservé, garder le JAR généré cohérent et ajouter le
  `distributionSha256Sum` officiel ; aucun `local.properties` ;
- smoke widget test des six destinations, bascule rich, animation de groupe et
  dispose avant délai ; build APK debug. Aucun keystore de release.

### Acceptation, risques, revue, revert

- **Acceptation :** lock forcé, analyse, smoke tests et APK debug verts sur la
  toolchain déclarée ; aucun changement du package racine.
- **Risques :** large diff généré, cycle de vie masqué, dépendance native
  accidentelle.
- **Reviewer attendu :** reviewer Flutter/Android indépendant, avec inspection
  séparée du code Dart et du scaffold généré.
- **Merge :** peut être intégré après sa revue à tout moment après `S1`, mais
  doit être présent avant `S10`. **Revert :** lot entier si la régénération
  modifie la promesse de plateforme du package ou supprime une démo.

**Findings couverts :** CORE-08, CORE-10, #146, partie démo de l'audit outillage.

## Lot 7 — Archive pub déterministe

**Branche :** `codex/impl-pub-archive`
**Base :** `S1`
**Dépendance :** décision ferme de conserver `demo/` hors archive
**Parallèle :** lots cœur et lot 6

### Surface

- nouveau `.pubignore` uniquement, sauf petit test/script d'assertion si sa
  nécessité est démontrée.

### Travail et validation

Puisque `.pubignore` remplace `.gitignore` pour Pub, reprendre explicitement
les exclusions générées : `/.dart_tool/`, `/build/`, `/doc/api/`,
`/pubspec.lock`, IDE, couverture, fichiers locaux, clés/signatures. Ajouter
`/maintenance/`, `/demo/`, `/.github/` et `/example/pubspec.lock`.

Le dry-run doit refuser : maintenance, démo, workflow, locks, build, chemin
`/Users/` ou chemin Windows personnel, `local.properties`, secret/clé et
wrapper historique. Il doit affirmer la présence de `lib/`, `test/`,
`example/main.dart`, `example/pubspec.yaml`, `README.md`, `CHANGELOG.md`,
`LICENSE`, `pubspec.yaml` et `analysis_options.yaml`. Les tests restent dans
l'archive. Aucun `pub publish` réel.

### Acceptation, risques, revue, revert

- **Acceptation :** `flutter pub publish --dry-run` sans warning/hint de
  contenu et liste complète contrôlée positivement/négativement.
- **Risque :** exclusion trop large ou fausse confiance tirée de la taille.
- **Reviewer attendu :** reviewer packaging/supply-chain indépendant.
- **Merge :** après revue, avant `S10`. **Revert :** entier si un fichier requis
  disparaît ou si une exclusion dépend seulement du `.gitignore`.

**Findings couverts :** archive de l'audit outillage, fuite historique de
chemins locaux, exclusion de la démo et des documents internes.

## Lot 8 — Prototype bloquant de l'architecture layout

**Branche :** `codex/spike-layout-gate`
**Base :** `S6` (`S5` + lot 5)
**Dépendance :** Gate Cœur
**Nature :** prototype sans code produit persistant

### Livrable et questions obligatoires

Le seul livrable conservé est une note
`maintenance/layout-prototype-decision.md` avec verdict GO/NO-GO, preuves sur
les deux SDK et architecture minimale. Les fichiers de spike sont supprimés
avant revue.

Le prototype doit démontrer :

- mise à jour du span/scaler final via un petit sous-type ou une composition de
  `RenderParagraph`, sans copier son painter privé, sa sélection ou sa
  sémantique ;
- API publique identique sur Flutter `3.41.0` et la pin haute ; aucun type privé ;
- relayout wet d'un enfant inline à plusieurs scales dans un même
  `performLayout`, puis état final correct, sans `markNeedsLayout` récursif ;
- chemins dry et wet distincts : un child sans dry layout fonctionne en wet
  ordinaire ; le mini-probe WidgetSpan retourne des métriques zéro en
  dry/intrinsic sans consulter ce child ;
- le mini-probe WidgetSpan du gate porte sur un seul placeholder et démontre
  seulement wet automatique/taille et isolation de ses six métriques non-wet.
  Paint, transform, hit test, sémantique, disposal du nouveau wrapper et ordre
  multi-placeholder restent à prouver au lot 10 ;
- baselines dry/wet pour alignements supportés ; scaling différent par taille
  de run ; taille de run zéro sans division ;
- branche `overflowReplacement` inactive non montée ; aucune politique eager ;
  dry/intrinsics ne consultent jamais la replacement et retournent le
  paragraphe au plus petit candidat si wet doit choisir cette branche ;
- snapshot immuable de limite de groupe, aucune publication dry ;
- libération des painters de recherche et possédés ;
- comportement d'un enfant volontairement non monotone. La décision doit
  documenter que la recherche logarithmique garantit le plus grand candidat
  pour les enfants monotones ; pour un enfant non monotone, elle garantit un
  résultat déterministe et sûr, pas un optimum global, sauf fallback borné
  démontré par le spike.

### Acceptation, risques, revue, revert

- **GO :** la note prouve toutes les questions sans nouvelle API publique, type
  privé, eager mount ou copie substantielle de `RenderParagraph`, et borne le
  coût à `O(log C)` pour le texte. `O(P log C)` reste la cible d'acceptation du
  lot 10, pas une propriété du mini-probe lean à un placeholder. La note
  documente les deux divergences admises : replacement lazy et placeholder
  WidgetSpan zéro en dry/intrinsic.
- **NO-GO :** les lots 9 et 10 ne démarrent pas ; la release production reste
  bloquée. Un nouveau design retourne en revue, sans garde approximative.
- **Reviewer attendu :** expert Flutter render/layout indépendant, idéalement
  différent des reviewers des lots 3 à 5.
- **Merge :** seule une décision GO revue crée `S7`. **Revert :** la note peut
  être revertée si ses preuves ne sont pas reproductibles ; aucun code produit
  n'est à conserver.

**Findings préparés :** #28/#30/#37/#77/#129/#147 et CORE-01/#61/#106 ; aucun
de ces findings n'est fermé par le prototype.

## Lot 9 — Render object texte et intrinsics

**Branche :** `codex/impl-intrinsics`
**Base :** `S7`
**Dépendance :** GO du lot 8

### Surface

- nouveau `lib/src/auto_size_text_render_object.dart` ;
- `lib/auto_size_text.dart`, `lib/src/auto_size_text.dart`,
  `lib/src/auto_size_text_layout.dart` ;
- nouveaux `test/intrinsics_test.dart` et tests render dédiés ;
- adaptations de `test/utils.dart`, `test/basic_test.dart`,
  `test/group_test.dart`, `test/overflow_replacement_test.dart` et lifecycle.

### Contrat

- remplacer `LayoutBuilder` par la frontière validée du prototype, pour texte
  simple et riche **sans `WidgetSpan`** ; le noyau de lots 2 à 5 n'est pas
  dupliqué ;
- `computeMinIntrinsicWidth(height)` et `computeMaxIntrinsicWidth(height)`
  choisissent avec largeur non bornée et `maxHeight == height`, puis retournent
  respectivement les largeurs intrinsèques min et max du paragraphe choisi ;
- `computeMinIntrinsicHeight(width)` et `computeMaxIntrinsicHeight(width)`
  choisissent avec `maxWidth == width`, hauteur non bornée, puis retournent la
  hauteur ; dimensions infinies non converties en tight ; `maxLines` reste
  actif ; résultat contraint par `constraints.constrain` ;
- `computeDryBaseline` emploie le même candidat et la même branche que
  `computeDryLayout` ;
- dry/intrinsics calculent le candidat local avec un snapshot immuable de groupe
  fourni par la configuration, jamais via une lecture directe du groupe. Dry et
  wet calculent d'abord le même candidat local non groupé, puis projettent la
  taille rapportée sur ce même snapshot. Seul wet publie le candidat local,
  après avoir rendu ;
- l'égalité dry/wet est exigée pour des contraintes et un snapshot identiques
  tant que le texte est la branche wet choisie. Si le texte local déborde même
  au minimum, dry layout, dry baseline et les quatre intrinsics retournent de
  façon déterministe les métriques contraintes du paragraphe à ce minimum,
  tandis que wet monte et layoutte la replacement ; cette divergence est
  contractuelle. Une publication wet peut changer le snapshot de la frame
  suivante : entre deux frames de convergence, on exige pureté, borne et
  convergence, pas une égalité avec l'ancien snapshot ;
- `overflowReplacement` conserve le cycle de vie actuel : la branche inactive
  n'est ni montée, ni layoutée, ni peinte, ni hit-testée, ni sémantique. Dry et
  intrinsics ne construisent, ne consultent et ne mesurent jamais le widget
  replacement, y compris après un wet overflow ;
- recognizers, semantics et sélection existante via `SelectionArea` sont
  préservés par réutilisation de `RenderParagraph`, pas par copie ;
- `textKey` continue à trouver le paragraphe rendu mais ne garantit plus une
  instance de `Text`. Ce contrat majeur est testé et documenté au lot 12.

### Tests précis

- reproductions rouges/vertes : `IntrinsicWidth`, `IntrinsicHeight` dans
  list/card/row, `Chip`, `FilterChip`, `DataTable`, `PaginatedDataTable` ;
  `Row + Expanded` comme non-régression seulement ;
- appels répétés aux quatre intrinsics, dry layout et dry baseline avant/après
  wet ; contraintes tight/loose, minima non nuls, un/deux axes infinis ;
- parité taille/baseline/candidat hors groupe ; pureté et convergence avec
  groupe, changement/retrait/dispose avant microtâche ;
- stateful replacement : compteurs `initState`/`dispose`, flips fit/overflow,
  une seule branche visible/sémantique ; replacement avec `LayoutBuilder` et
  descendant qui rejette toutes les métriques dry/intrinsic, jamais appelé par
  ces chemins mais correctement layouté en wet ;
- texte simple/riche, wrap, maxLines, presets, scaler non linéaire,
  `textKey`, recognizers, semantics et `SelectionArea` ;
- leak tracking de tous les painters et compteur prouvant `O(log C)`.

### Acceptation, risques, revue, revert

- **Acceptation :** les six issues intrinsic ne reproduisent plus d'exception,
  aucun `LayoutBuilder` n'est utilisé comme frontière du texte, aucune copie
  importante de logique privée, aucune mutation dry, replacement strictement
  lazy et fallback texte minimum documenté, comportements historiques
  préservés.
- **Risques :** contrat intrinsic incorrect, groupe observé pendant dry,
  replacement monté à tort, rupture sélection/sémantique, changement `textKey`.
- **Reviewer attendu :** revue architecturale render indépendante obligatoire.
- **Merge :** après tests sur minimum + haute et comparaison à
  `RenderParagraph` témoin. **Revert :** entier si une API privée, une copie de
  sélection/sémantique ou une mutation dry est nécessaire.

**Issues fermables par ce lot :** #28, #30, #37, #77, #129, #147. Il ne ferme
pas CORE-01/#61/#106.

## Lot 10 — `WidgetSpan` automatique

**Branche :** `codex/impl-widget-span`
**Base :** `S8` (`S7` + lot 9)
**Dépendances :** lots 8 et 9

### Surface

- `lib/src/auto_size_text_render_object.dart`,
  `lib/src/auto_size_text_layout.dart`, `lib/src/auto_size_text.dart` ;
- nouveau `test/widget_span_test.dart` ;
- tests lifecycle, groupe, RichText, replacement et intrinsics concernés.

### Contrat

- extraire les `WidgetSpan` en ordre logique 1:1 sans paramètre public de
  dimensions ; conserver `TextParentData.span` et les tags sémantiques avec des
  types publics seulement ;
- facteur inline par run et candidat :
  `candidateScaler.scale(inheritedLogicalRunSize) / inheritedLogicalRunSize`,
  avec le comportement de taille zéro vérifié contre Flutter `3.41.0` ;
- ce facteur affecte contraintes inverses, taille, baseline, transformation de
  paint et hit testing ; dimensions fournies dans le même ordre au painter ;
- wet utilise `child.layout` et la baseline réelle pour les candidats
  spéculatifs, puis laisse chaque child au candidat final ;
- le wrapper interne ne consulte jamais les métriques non-wet d'un child
  arbitraire : dry size, dry baseline et les quatre intrinsics du placeholder
  valent zéro. Un child sans dry layout reste donc supporté en wet ordinaire,
  sans crash si un ancêtre demande ensuite dry/intrinsic ;
- `overflowReplacement` reste hors de la liste des placeholders et la branche
  inactive ne garde pas les widgets inline montés ;
- complexité normale `O(P log C)`. L'hypothèse de monotonie des widgets inline
  est documentée ; un child non monotone doit rester déterministe et borné,
  sans promesse d'optimum global. La géométrie dry/intrinsic à placeholder zéro
  peut différer du wet et sélectionner un autre candidat ; cette divergence est
  explicitement admise.

### Tests précis

- placeholder fixe, contraint, multiple, ellipsé et ordre 1:1 ;
- alignements top/middle/bottom, baselines alphabetic/ideographic ;
- tailles héritées de runs différentes, scaler linéaire/non linéaire, zéro,
  comparaison avec `RichText` témoin ;
- wrap vrai/faux sans flatten, maxLines, groupe, replacement ;
- paint/transform/hit test/interaction, sémantique enfant, recognizer,
  `SelectionArea`, arbre source inchangé et aucun enfant dupliqué ;
- child sans dry en wet ordinaire ; child non monotone selon le contrat décidé ;
- child témoin qui lève sur dry layout, dry baseline et les quatre intrinsics :
  six métriques zéro au wrapper, aucun appel au child, wet/paint/hit/sémantique
  toujours fonctionnels ;
- leak tracking, rebuild, retrait de groupe et compteur `P log C`.

### Acceptation, risques, revue, revert

- **Acceptation :** aucun `WidgetSpan` valide n'exige de dimensions manuelles,
  wet identique au témoin final pour le candidat rendu, métriques dry/intrinsic
  zéro documentées pour le placeholder arbitraire, aucun crash du child
  wet-only, cycle de vie et semantics intacts.
- **Risques :** scale par run faux, baseline, divergence dry/wet, coût caché,
  enfant non monotone, duplication de child.
- **Reviewer attendu :** second reviewer render/inline indépendant, distinct du
  reviewer du lot 9.
- **Merge :** suivi de Gate Architecture. **Revert :** lot 10 seul si les
  intrinsics texte du lot 9 restent corrects ; revert 9+10 si la frontière
  render commune est en cause.

**Findings fermables :** CORE-01, #61, #106.

## Lot 11 — CI sûre et gates automatisés

**Branche :** `codex/impl-ci`
**Base :** `S10` (lots 1 à 10, démo et archive réunis)
**Dépendances :** Gates Cœur et Architecture, lots 6 et 7, décision humaine sur
les branches déclenchant `push` (information seulement, aucun credential)

### Surface

- `.github/workflows/dart.yml` ou remplacement unique `.github/workflows/ci.yml` ;
- petits scripts locaux de validation uniquement si cela évite une divergence
  CI/local ; README/badge attendent le lot 12.

### Workflow requis

- événements `pull_request`, `push` sur les branches décidées et
  `workflow_dispatch`; `permissions: contents: read`, timeouts et concurrence ;
- toutes les actions fixées à un SHA complet vérifié dans leur dépôt officiel,
  avec tag humain en commentaire ; Flutter à des patchs exacts, jamais `stable` ;
- aucun `curl | bash`, Codecov, secret ou permission d'écriture ;
- diff-check base PR→HEAD ou before→HEAD avec historique suffisant ; traiter le
  SHA nul/premier push, sinon omettre ce contrôle plutôt que vérifier un diff vide.

Jobs bloquants :

| Job | Toolchain | Gates |
|---|---|---|
| `quality` | pin haute exacte | `git diff --check`, format arbre complet, analyse fatale racine |
| `compat` | matrice `3.41.0` + haute | pub get, analyse fatale racine, tests ; lock exemple forcé et analyse exemple |
| `downgrade` | `3.41.0` | `flutter pub downgrade`, puis tests `--no-pub` |
| `demo` | toolchain déclarée du lot 6 | lock forcé, analyse, smoke test, APK debug |
| `package` | pin haute exacte | dartdoc, dry-run et assertions positives/négatives du lot 7 |

### Acceptation, risques, revue, revert

- **Acceptation :** workflow syntaxiquement validé, chaque commande reproduite
  localement, analyse du minimum explicite, aucune référence mutable ou secret.
- **Risques :** SHA inventé, cache/lock trompeur, diff-check vide, baseline
  masquée par `continue-on-error`.
- **Reviewer attendu :** reviewer CI/supply-chain indépendant qui vérifie
  l'origine de chaque SHA.
- **Merge :** seulement quand tous les jobs sont verts sur la tête du lot, sans
  mutation distante requise par le plan. **Revert :** workflow entier si une
  action ne peut être épinglée ou si le job minimum n'analyse pas réellement.

**Findings couverts :** CORE-09 final, CI/supply-chain, matrice, downgrade,
archive et démo de l'audit outillage.

## Lot 12 — Documentation, changelog, métadonnées et version

**Branche :** `codex/impl-release-docs`
**Base :** `S11`
**Dépendances :** API et CI finales ; décision humaine sur le dépôt canonique

### Gate de gouvernance locale

Avant de lancer l'agent, un mainteneur fournit explicitement : dépôt canonique,
issue tracker, branche affichée par les badges, titulaire des contacts et preuve
qu'un uploader/admin pub.dev pourra publier `auto_size_text`. Cela ne donne à
l'agent aucun credential et ne l'autorise à aucune mutation distante.

Sans cette décision, le lot reste bloqué : ne pas inventer d'URL, de publisher,
de contact de sécurité ou de financement. L'absence d'autorité interdit tag et
publication, mais ne déclenche pas un renommage de package.

### Surface et travail

- `pubspec.yaml`, `README.md`, `CHANGELOG.md` et doc comments publiques ;
- templates `.github/ISSUE_TEMPLATE/**`, `.github/FUNDING.yml`,
  `.github/no-response.yml`, éventuellement `SECURITY.md`, uniquement selon la
  gouvernance réelle.

- passer la version à `4.0.0` ; ajouter `repository` canonique et les autres URL
  seulement si approuvées ;
- changelog factuel : minimum cassant, `TextScaler`, compatibilité dépréciée de
  l'ancien facteur, corrections réellement mergées, intrinsics, WidgetSpan,
  groupes, démo/CI/archive. Ne revendiquer ni #151 ni #80/#81 ;
- guide de migration : SDK, exclusivité des scalers, règle référence zéro,
  scaler monotone, changement de `textKey` vers le paragraphe sans garantie de
  type `Text`, comportement des groupes et limite des widgets inline non
  monotones ;
- README : liens/badges réels, liste complète incluant `strutStyle` et
  `textScaler`, corrections de syntaxe, retrait de l'affirmation de performance
  sans benchmark et licence reliée à `LICENSE` ;
- documenter `AutoSizeGroup` et tous les symboles publics ;
- retirer assignations/financements obsolètes non approuvés ; ne créer
  `SECURITY.md` qu'avec canal surveillé ; garder no-response uniquement si son
  application est confirmée.

### Validation, revue, revert

- `dart format --output=none`, analyse/test minimum + haute, analyse exemple,
  `dart doc --dry-run`, dry-run d'archive et vérification version/changelog ;
- **Reviewer attendu :** reviewer API/release indépendant, qui compare chaque
  claim au diff final et vérifie qu'aucun secret/credential n'est demandé ;
- **Merge :** seulement après gouvernance et validations propres au lot ; ce
  merge crée `S12`, qui est ensuite soumis à la Gate Finale. **Revert :** lot
  documentation/version entier si l'identité n'est pas confirmée ou si un
  correctif annoncé manque au SHA final.

**Findings couverts :** version majeure, README/API/badges, métadonnées,
gouvernance et documentation de l'audit outillage. Le lot ne tague et ne publie
rien.

## Gates intermédiaires et finale

### Gate SDK — après lot 0

Bloquant pour tout merge produit :

- sorties exactes de Flutter `3.41.0`/Dart `3.11.0` et de la pin haute ;
- résolution, analyse selon allowlist, tests et downgrade du lot 0 ;
- minimum déclaré égal au bundle réellement exécuté ;
- aucune affirmation que `3.41.0` ou `3.47.2` était déjà testé avant ce gate.

### Gate Cœur — après lot 5

- format haute ; analyse fatale et suite complète sur minimum + haute ;
- tests rouges/verts archivés pour #150, grille, scaling/configuration,
  RichText/NBSP/zéro et groupes ;
- résultats linéaires historiques inchangés ; aucun painter orphelin, taille
  hors domaine ou projection au-dessus du candidat local ;
- revue indépendante du diff cumulé des lots 1 à 5, en plus des revues de lot.

Ce gate ne permet pas une release : intrinsics et WidgetSpan restent ouverts.

### Gate Architecture — après lot 10

- reproductions des six compositions intrinsèques et des WidgetSpan rouges sur
  leur parent, vertes sur la tête ;
- tests directs intrinsics/dry/baseline, pureté de groupe, replacement,
  selection/semantics, lifecycle et complexité ;
- tests explicites des divergences admises : texte minimum quand wet choisit la
  replacement, puis placeholder zéro pour WidgetSpan dry/intrinsic ; aucune
  consultation des subtrees arbitraires dans ces chemins ;
- matrice minimum + haute ; benchmark reproductible texte simple et inline ;
- revue séparée des lots 9 et 10, puis revue du diff cumulé ;
- aucun type privé Flutter, API manuelle de dimensions ou copie de champ texte.

### Gate Finale — sur `S12`

La validation finale s'exécute sur le SHA exact destiné à une éventuelle future
release, sans rien publier :

1. arbre Git propre et `git diff --check` sur la plage réellement livrée ;
2. pin haute : format complet `lib test example demo/lib`, analyse fatale,
   tests, dartdoc et dry-run ;
3. Flutter `3.41.0` : pub get, analyse fatale, tests, exemple avec lock forcé ;
4. Flutter `3.41.0` : pub downgrade puis tests `--no-pub` ;
5. démo : lock forcé, analyse, smoke tests et APK debug sur sa toolchain ;
6. suites ciblées leak, grille, scaler/config, RichText, groupe, intrinsics et
   WidgetSpan ;
7. archive : aucune entrée interdite, toutes les entrées requises présentes ;
8. version `4.0.0`, changelog, README, API et URLs concordants ;
9. un reviewer final indépendant confirme la couverture de la matrice ci-dessous
   et l'absence de cycle de dépendances.

Une validation réussie signifie « artefact local prêt à être proposé ». Elle
n'autorise ni tag, ni push, ni publication, ni fermeture d'issue.

## Matrice de couverture des must-fix

| Finding / issue | Lot qui ferme | Preuve principale |
|---|---:|---|
| CORE-01, #61, #106 — `WidgetSpan` | 10 | wet automatique, run scaling, fallback dry zéro, lifecycle |
| CORE-02, #140 — scaling moderne | 3 + 4 + 5 + 10 | scaler composé simple/runs/groupes/placeholders |
| CORE-03, #104, #119 — configuration effective | 3 + 4 | gras, overrides, strut, wrap, direction/locale, métriques |
| CORE-04 — RichText/wrapWords | 4 | parent synthétique, runs conservés |
| CORE-05 — groupes hétérogènes | 5 | double borne locale/effective et scaler plateau |
| CORE-06, #145 — grille | 2 | domaine virtuel ancré au minimum |
| CORE-07 — référence zéro | 4 | sémantique explicite sans division |
| CORE-08, CORE-10, #146 — démo | 6 | résolution, smoke, Android, cycle de vie |
| CORE-09 — SDK/lints/CI | 0 + 11 | pins exactes, analyse minimum, workflow sûr |
| CORE-11 — presets | 2 | runtime, ordre, finitude, non-mutation |
| #150 — painters | 1 + 9/10 | finally puis propriétaires render |
| #142 — NBSP/NNBSP | 4 | segmentation conservant les runs |
| #28/#30/#37/#77/#129/#147 — intrinsics/dry | 8 + 9 | prototype GO puis render object pur |
| Tests vides/changement de groupe | 2 + 5 | vraies assertions et didUpdateWidget |
| Archive/données locales | 7 + 11 | `.pubignore`, dry-run et assertions CI |
| Documentation/version/métadonnées | 12 | claims comparés au SHA final |

#151 reste « besoin d'information » : le lot 2 bloque les valeurs non finies et
le pas nul, mais aucune fermeture n'est revendiquée sans reproduction. Les
éléments déjà corrigés, obsolètes ou à reproduire de l'audit amont ne reçoivent
pas de lot spéculatif.

## Exclusions et garde-fous de périmètre

Demandes de fonctionnalités exclues : #36, #38, #40, #43, #45, #47, #54,
#57, #60, #66, #68, #73, #78, #79, #80, #81, #84, #95, #100, #111, #118,
#120, #121, #127, #131, #136, #152 et #153. En particulier, aucun paramètre
public `textWidthBasis`/`textHeightBehavior`, callback de taille, thème de
groupe, nouvelle stratégie d'overflow, équilibrage de lignes, letter-spacing
automatique, champ éditable ou moteur UAX #14 complet n'est ajouté.

PR historiques :

- **ne jamais cherry-pick** #102, #148 ou #154 ;
- #149 indique seulement les deux allocations à corriger : réimplémenter avec
  `try/finally`, sans `any` ni activation leak répétée ;
- #139 n'autorise pas une API publique `placeholderDimensions` ;
- #122 ne sert qu'à un backlog #80/#81 hors release ;
- #135, #124, #116, #113, #94, #91 et #50 restent hors périmètre.

Sont également exclus : renommage de package, backport <3.41, Codecov, OIDC,
Dependabot, protections de branche, installation d'app GitHub, tag, publication
pub.dev, clôture/commentaire d'issue ou PR, et tout usage de credentials. Ces
actions exigent une décision et une autorisation séparées après la réussite de
la Gate Finale.

## Contrôle d'absence de cycles

Le graphe est acyclique : le lot 0 est l'unique racine ; les lots cœur 1→5 et
layout 8→10 sont des chaînes strictes ; les lots 6 et 7 ne dépendent que du lot
0 et rejoignent la chaîne avant le lot 11 ; le lot 11 dépend de cette union ; le
lot 12 est terminal. Aucun lot ne dépend d'une documentation ou d'une CI qu'il
est lui-même chargé de produire.
