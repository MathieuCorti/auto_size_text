# Revue indépendante de l'audit outillage

Date de la revue : **2026-09-01**

Rapport revu : `maintenance/audits/tooling-audit.md`, commit
`ec41e69e1df53cc310efbf8e55366c09aab3f7e3`

Référence produit auditée par le rapport :
`f22397751271605ac46e8740d9e48ed631a74cb0`

Périmètre de cette revue : valider les onze findings, leurs preuves, leur
priorité et leurs critères d'acceptation. Aucun correctif produit ou
d'outillage n'est inclus dans cette revue.

## Verdict global

Le rapport est **largement fiable et exploitable**, mais doit être lu avec les
rectifications de cette revue. Les commandes centrales sont reproductibles et
les onze sujets existent. En revanche, les deux niveaux P0 sont trop élevés
selon une échelle de sévérité standard : il n'y a ni incident actif, ni fuite
de secret démontrée, ni indisponibilité du package déjà publié. Ce sont des
**P1 bloquants pour une nouvelle release**. La revue retient donc **0 P0,
4 P1 et 7 P2**.

Cette classification distingue :

- **P0** : incident critique actif ou compromission avérée ;
- **P1** : empêche une validation fiable ou une nouvelle publication sûre ;
- **P2** : dette réelle de maintenance, de qualité ou de gouvernance.

Si le rapport emploie « P0 » comme synonyme interne de « release blocker »,
son intention reste compréhensible. La classification ci-dessous est toutefois
plus utile pour ordonner les travaux.

| Finding | Verdict | Priorité revue | Bloque le vert / la release |
|---|---|---:|---|
| CI cassée et chaîne de livraison | Confirmé, sévérité corrigée | P1 | Oui |
| Démonstrateur non résoluble/non constructible | Confirmé, sévérité corrigée | P1 | Oui s'il est conservé ou livré |
| Analyzer/lints abandonnés | Confirmé avec contrainte de version à préciser | P2 | Oui pour une baseline maintenue |
| Contraintes SDK et politique de compatibilité | Confirmé avec migration à étager | P1 | Oui |
| Identité et autorité pub.dev | Confirmé | P1 | Oui |
| Tests vides et matrice | Partiellement confirmé comme P1 ; dette de tests P2 | P2 | La matrice minimum/courante bloque, pas le style des tests |
| Contenu de l'archive | Confirmé avec corrections matérielles | P2 | Oui avant publication |
| README et documentation | Confirmé | P2 | Les liens/API faux oui ; le reste non |
| Métadonnées maintenance/sécurité | Confirmé avec éléments optionnels | P2 | Partiellement |
| Lockfiles | Confirmé avec correction pour `example/` | P2 | Oui si les applications sont maintenues |
| Dépendances et gates | Confirmé comme signal, pas comme vulnérabilité | P2 | Partiellement |

## Corrections transversales indispensables

1. La stable officielle au 2026-09-01 est bien Flutter **3.47.2**, mais avec
   Dart **3.13.2** précisément. Flutter 3.47 n'est pas installé localement et
   n'a donc toujours pas été exécuté dans cette revue.
2. Le `publish --dry-run` du commit du rapport ne fait plus 71 Ko : il produit
   une archive de **82 Ko** et inclut aussi
   `maintenance/audits/tooling-audit.md`. Les 71 601 octets correspondent en
   revanche exactement à l'archive 3.0.0 déjà publiée. Il faut distinguer
   l'artefact publié, la baseline `f2239775` et le commit documentaire
   `ec41e69e`.
3. L'archive 3.0.0 réellement publiée contient en plus
   `demo/android/local.properties`, absent du worktree actuel, avec deux
   chemins absolus personnels :

   ```properties
   sdk.dir=/Users/simon/Library/Android/sdk
   flutter.sdk=/Users/simon/fvm/versions/stable
   ```

   Ce ne sont pas des secrets, mais c'est une fuite historique d'informations
   locales. L'archive étant immuable, la correction consiste à garantir leur
   absence de toute nouvelle version.
4. Le JAR `demo/android/gradle/wrapper/gradle-wrapper.jar` n'a pas une
   provenance inconnue : son SHA-256
   `16caeaf66d57a0d1d2087fef6a97efa62de8da69afa5b908f40db35afc4342da`
   correspond au wrapper officiel **Gradle 2.10**, alors que
   `gradle-wrapper.properties` télécharge Gradle 4.4. La provenance est donc
   connue, mais l'assemblage est ancien, incohérent et dépourvu de
   `distributionSha256Sum`.
5. Une migration vers les lints officiels doit fixer une version compatible
   avec le plancher choisi ; « prendre la dernière » casserait les anciens SDK :

   | Plancher Dart retenu | Version officielle maximale adaptée |
   |---|---|
   | Dart 2.12 | `lints 1.0.1` ou `flutter_lints 1.0.4` |
   | Dart 3.2 / Flutter 3.16 | `lints 4.0.0` ou `flutter_lints 4.0.0` |
   | Dart 3.7 / Flutter 3.29 | `lints 5.1.1` ou `flutter_lints 5.0.0` |
   | Dart 3.8+ | `lints 6.1.0` ou `flutter_lints 6.0.0` |

## Verdict détaillé par finding

### 1. CI cassée et exposition de la chaîne de livraison

**Verdict : confirmé, P1 plutôt que P0.**

Le workflow ne tourne que sur `push`, utilise `actions/checkout@v1`, clone une
branche mutable, appelle un `dartfmt` absent de Dart 3.12 et exécute un script
Codecov téléchargé au dernier moment avec un token. L'absence de
`permissions:` laisse en outre la portée du `GITHUB_TOKEN` dépendre des
réglages du dépôt. `dartfmt` est bien absent du SDK 3.44.0. La menace
supply-chain est réelle, mais aucune fuite ou compromission n'a été observée ;
P1 est donc la sévérité appropriée.

**Correction nécessaire.** Installer une version Flutter exacte, épingler
toutes les actions par SHA complet, remplacer le formateur, valider les PR et
retirer `curl | bash`. Le premier workflow sûr peut omettre Codecov : la
couverture locale reste disponible sans transfert externe.

**Exigences d'acceptation.**

- `pull_request` et `push` sur les branches protégées déclenchent le workflow ;
- `permissions: contents: read` est la valeur par défaut ; si Codecov utilise
  OIDC, seul son job reçoit aussi `id-token: write` ;
- chaque `uses:` est fixé à un SHA complet vérifié dans le dépôt officiel ;
- Flutter est fixé à un patch exact, avec au moins stable courante et minimum
  supporté ;
- format, résolution, analyse et tests sont bloquants ;
- aucun script réseau non vérifié n'est exécuté ;
- si Codecov est conservé, l'action et la version du CLI qu'elle télécharge
  sont fixées, le fichier de couverture est explicite et l'échec d'upload a
  une politique documentée.

`timeout-minutes` et `concurrency` sont recommandés, mais ne sont pas requis
pour rendre la première baseline verte.

### 2. Démonstrateur non résoluble et Android obsolète

**Verdict : confirmé, P1 conditionnel plutôt que P0.**

Sous Flutter 3.44.0/Dart 3.12.0, `demo/flutter pub get` échoue sur
`bottom_navy_bar` non null-safe et propose notamment `bottom_navy_bar 6.1.0`
et `material_design_icons_flutter 7.0.7296`. L'analyse confirme aussi l'API
`SystemChrome.setEnabledSystemUIOverlays` supprimée. Le scaffold utilise bien
l'embedding v1 retiré en Flutter 3.29, l'application impérative des plugins,
JCenter, API 27, AGP 3.1.2 et Gradle 4.4. Gradle 4.4 ne peut pas tourner sur le
Java 26 local ; la matrice Gradle exige au moins Gradle 9.4 pour Java 26.

Ce finding bloque une release uniquement si `demo/` reste une application
maintenue ou un artefact publié. Il ne rend pas à lui seul la bibliothèque
`lib/` inutilisable.

**Correction nécessaire.** Trancher entre deux options exclusives :

- moderniser le démonstrateur avec le scaffold de la stable retenue ; ou
- le retirer de l'archive et de toute promesse de maintenance, en gardant
  `example/` comme exemple canonique.

Remplacer les deux dépendances visuelles par des widgets/icônes Flutter est une
bonne simplification, mais n'est pas une condition absolue si des versions
maintenues sont justifiées.

**Exigences d'acceptation.**

- option modernisée : `flutter pub get`, `flutter analyze` et au moins
  `flutter build apk` passent avec la stable courante ; embedding v2, Plugin
  DSL, Maven Central, niveaux Android supportés et lockfile versionné ;
- option retirée : `/demo/` est exclu par `.pubignore`, les liens et jobs qui le
  présentent sont retirés, et `example/` reste exécutable ;
- aucun fichier local (`local.properties`) ou wrapper non validé n'entre dans
  l'archive.

### 3. Analyzer et lints abandonnés

**Verdict : confirmé, P2.**

`pedantic 1.11.1` est officiellement discontinué et remplacé par `lints` ou
`flutter_lints`. Le contrôle de format reproduit l'erreur de résolution de
l'include dans les sous-packages. `strong-mode/implicit-casts` et
`implicit-dynamic` sont des modes retirés ; les contrôles actuels sont sous
`analyzer.language` (`strict-casts`, `strict-inference`, éventuellement
`strict-raw-types`). Masquer `include_file_not_found` peut rendre une
configuration silencieusement inopérante.

**Correction nécessaire.** Choisir `flutter_lints` pour ce package Flutter, ou
`lints` si le mainteneur veut volontairement un socle Dart seulement, dans la
version compatible avec le plancher décidé. Migrer ensuite les anciens modes
stricts sans ajouter d'ignore global destiné à faire passer la transition.

**Exigences d'acceptation.**

- aucune dépendance discontinue ;
- l'include est résolu depuis la racine et depuis chaque package autonome
  conservé ;
- aucune option analyzer inconnue ou obsolète ;
- `include_file_not_found` n'est plus ignoré ;
- `flutter analyze` est vert avec les diagnostics rendus fatals en CI ;
- le contrôle de format n'affiche plus d'avertissement de résolution.

### 4. Contraintes SDK et migration TextScaler

**Verdict : confirmé, P1.**

Dart 3 réinterprète bien `>=2.12.0 <3.0.0` en `>=2.12.0 <4.0.0`, ce que le
dry-run signale par un hint. Le minimum 2.12 n'a pas été testé et aucun minimum
Flutter n'est déclaré. La stable 3.47.2/Dart 3.13.2 n'a pas été exécutée. Les
neuf diagnostics `textScaleFactor` sont reproduits. `TextScaler` a été livré en
stable avec Flutter 3.16, associé à Dart 3.2 : le minimum proposé par le rapport
est correct pour une migration complète.

Le rapport présente toutefois trop directement le remplacement du paramètre
public. Une migration progressive peut **ajouter** `textScaler`, conserver
temporairement `textScaleFactor` comme alias linéaire déprécié et interdire que
les deux soient fournis. La suppression du paramètre historique est, elle, une
rupture source certaine. Relever le minimum Flutter exclut également des
consommateurs et doit être versionné comme changement cassant prudent.

**Correction nécessaire.** Séparer :

1. une décision de support et l'explicitation de `<4.0.0` ;
2. une migration produit dédiée vers `TextScaler`, avec recherche de taille et
   rendu qui conservent la stratégie non linéaire au lieu de la réduire à un
   coefficient moyen.

**Exigences d'acceptation.**

- `environment.sdk` et `environment.flutter` reflètent un minimum réellement
  exécuté ;
- CI obligatoire sur **minimum exact + stable exacte courante** ; stable
  précédente est une défense supplémentaire, pas un minimum absolu ;
- si TextScaler est adopté : minimum Flutter 3.16/Dart 3.2 au moins, tests de
  scaling nul, linéaire, système et non linéaire, et documentation des
  interactions avec min/max/presets/groupes ;
- l'ancien paramètre n'est retiré que dans une majeure avec guide de migration ;
- aucun changement TextScaler n'est caché dans un lot de lints ou de CI.

Les tests 3.29.3, 3.41.6 et 3.44.0 donnent une information utile, mais ces trois
versions ne remplacent ni le minimum déclaré ni la stable actuelle.

### 5. Identité et autorité de publication

**Verdict : confirmé, P1 et blocage absolu de release.**

L'API et la page pub.dev confirment `auto_size_text 3.0.0`, publié le
2021-10-27 par `simc.dev`. Le dépôt local a pour `origin`
`MathieuCorti/auto_size_text` et pour `upstream` `simc/auto_size_text`; l'ancien
`leisim/auto_size_text` redirige vers `simc/auto_size_text`. Aucun élément local
ne prouve un rôle uploader ou admin. La version 3.0.0 est immuable.

**Correction nécessaire.** Obtenir une décision écrite sur le nom, le dépôt
canonique, le publisher et le titulaire du droit de publication avant de
préparer un tag.

**Exigences d'acceptation.**

- accès uploader à `auto_size_text` ou accès admin au publisher `simc.dev`
  vérifié sur pub.dev ;
- dépôt GitHub et publisher explicitement validés par leurs propriétaires ;
- `repository`, version et changelog pointent sur cette décision ;
- nouvelle version strictement supérieure à 3.0.0 ;
- OIDC configuré seulement après cette validation, sur le dépôt et le motif de
  tag exacts ;
- en l'absence de droits, nouveau nom et guide de migration traités comme une
  rupture, sans prétendre remplacer le package existant.

### 6. Tests vides et matrice de support

**Verdict : preuves confirmées, priorité globale corrigée à P2.**

`step_granularity_test.dart` ne déclare aucun test, le test maxLines est vide,
le helper de police est inutilisé et référence un fichier absent, et les deux
lignes non couvertes sont bien le changement de groupe dans
`didUpdateWidget`. L'absence de `group()` et les noms historiques relèvent du
standard de test, pas d'un défaut produit démontré. De même, 98,7 % de
couverture n'est pas un problème en soi.

La vraie lacune P1 — minimum et stable actuelle non testés — appartient au
finding SDK précédent. Une matrice minimum + précédente + actuelle,
`pub downgrade`, demo, dartdoc et dry-run à chaque push est souhaitable mais
plus large que le lot minimal nécessaire.

**Correction nécessaire.** Remplacer les placeholders par des tests capables
d'échouer sur une régression et couvrir le changement de groupe. Nettoyer le
helper mort. Regrouper et renommer les tests lors du même lot est conforme au
standard du dépôt, sans en faire un blocage artificiel distinct.

**Exigences d'acceptation.**

- assertions réelles pour `stepGranularity` et `maxLines == null` ;
- test qui remplace un `AutoSizeGroup` par un autre et vérifie
  désinscription/réinscription ;
- helper de police supprimé ou asset présent et helper effectivement utilisé ;
- groupes et noms « should ... » appliqués aux fichiers touchés ;
- minimum + stable courante passent en CI ;
- stable précédente, downgrade, dartdoc et dry-run peuvent être des jobs de
  release/schedule si le temps CI doit rester minimal.

### 7. Archive publiée et artefacts historiques

**Verdict : confirmé, P2, avec deux corrections matérielles.**

Le démonstrateur Android, les scripts, le JAR et les tests sont effectivement
inclus. Les tests sont une convention normale de package et ne sont pas à
exclure par principe. Les éléments réellement indésirables sont le demo cassé
s'il n'est pas maintenu, les documents internes `maintenance/` ajoutés après
la baseline et, historiquement, `demo/android/local.properties` dans la version
3.0.0 publiée.

Le JAR est un wrapper officiel Gradle 2.10 connu, pas un binaire de provenance
inconnue. Il reste anormalement ancien pour une configuration qui vise Gradle
4.4 et ne valide pas le checksum de la distribution.

**Correction nécessaire.** Introduire un `.pubignore` ciblé après avoir décidé
le rôle de `demo/`, toujours exclure `/maintenance/`, et régénérer/valider tout
wrapper conservé.

**Exigences d'acceptation.**

- `flutter pub publish --dry-run` ne liste ni `/maintenance/`, ni fichier
  local, ni demo non maintenu ;
- `example/`, README, changelog, licence, pubspec et API publique restent
  présents ;
- si un wrapper est conservé, JAR cohérent avec la version génératrice,
  `distributionSha256Sum` officiel et validation en CI ;
- la liste complète et la taille de l'archive sont enregistrées dans la
  checklist de release ;
- aucun chemin machine ou secret potentiel n'apparaît dans l'archive.

### 8. README, badges et documentation API

**Verdict : confirmé, P2.**

Les défauts cités sont présents. Le badge GitHub affiche une erreur Shields,
Codecov affiche `unknown` et Appetize répond encore. `dart doc --dry-run` reste
vert. Le score public courant est bien 150/160 : 8 diagnostics statiques et
26/27 symboles documentés, le constructeur `AutoSizeGroup.new` étant manquant.
Ce score concerne toujours l'artefact 3.0.0 analysé avec Flutter 3.44.0, pas le
prochain commit.

**Correction nécessaire.** Avant release, corriger les URLs/badges, erreurs
de syntaxe et coquilles, aligner la liste des paramètres sur l'API réellement
publiée et documenter `AutoSizeGroup`. Les conseils TextScaler doivent attendre
ou accompagner le lot produit correspondant.

**Exigences d'acceptation.**

- tous les liens et badges utilisent le dépôt/workflow canonique et rendent un
  état réel ;
- exemples README analysables et sans accolade surnuméraire ;
- paramètres publics, dont `strutStyle` puis `textScaler` le cas échéant,
  documentés ;
- `dart doc --dry-run` sans diagnostic ;
- affirmation de performance supprimée ou liée à un benchmark reproductible.

La déduplication de la licence dans le README est souhaitable, pas bloquante.

### 9. Métadonnées de maintenance et de sécurité

**Verdict : confirmé, P2.**

Les métadonnées et fichiers GitHub sont obsolètes comme décrit. La correction
doit néanmoins rester liée à des propriétaires réels. `repository` est la
métadonnée importante ; `issue_tracker` peut être omis si `repository` pointe
vers GitHub, car pub.dev en déduit alors l'URL `/issues`.

**Correction nécessaire.** Aligner pubspec, financement, templates et politique
de sécurité sur la gouvernance décidée. Vérifier l'installation no-response ou
retirer sa configuration.

**Exigences d'acceptation.**

- `repository` canonique et, si nécessaire, `issue_tracker` explicite ;
- aucune assignation ou destination de financement d'un ancien mainteneur sans
  son accord ;
- `SECURITY.md` avec versions supportées et canal réellement surveillé ;
- templates avec versions actuelles et sans assignee fantôme ;
- configuration Probot conservée uniquement si l'application est installée.

`CONTRIBUTING.md` et `CODEOWNERS` restent optionnels tant qu'aucun processus ou
propriétaire réel ne peut les remplir.

### 10. Politique de lockfiles

**Verdict : confirmé, avec correction, P2.**

La racine est une bibliothèque et ne doit pas committer son lockfile.
`demo/` est une application. `example/` possède lui aussi un `main`, son propre
pubspec et `publish_to: none` : selon la définition Dart, c'est également une
application exécutable. Laisser son lockfile à une décision non tranchée est
donc trop permissif si cette structure est conservée.

**Correction nécessaire.** Ancrer l'ignore à `/pubspec.lock` pour la
bibliothèque et versionner les lockfiles des applications maintenues. Si
`example/` est simplifié en exemple conventionnel sans package autonome, il
n'aura naturellement plus de lockfile distinct.

**Exigences d'acceptation.**

- `/pubspec.lock` ignoré ;
- `demo/pubspec.lock` suivi si `demo/` est conservé ;
- `example/pubspec.lock` suivi tant que `example/` reste un package
  d'application autonome ;
- CI des applications utilise leur résolution verrouillée, idéalement avec
  `--enforce-lockfile` ;
- inclusion ou exclusion des lockfiles imbriqués dans l'archive décidée via
  `.pubignore`, sans règle Git globale ambiguë.

### 11. Dépendances, advisories et gates

**Verdict : confirmé comme signal de maintenance, P2.**

La surface runtime reste limitée à Flutter. `pedantic` est discontinué, le demo
est bloqué par des dépendances anciennes, et les quatre endpoints advisories
retournent toujours des listes vides lors de cette revue. Cela ne démontre pas
l'absence de vulnérabilité.

Le mot « gate » doit être nuancé : `pub outdated` est d'abord un rapport et ne
doit pas faire échouer une release uniquement parce qu'une transitive plus
récente existe. `pub downgrade` teste les bornes de dépendances, pas le minimum
du SDK Flutter ; dans ce package sans dépendance runtime tierce, son rendement
est limité mais positif.

**Correction nécessaire.** Retirer les dépendances visuelles du demo ou les
mettre à niveau, remplacer `pedantic`, et intégrer les commandes à une
checklist de release ou à un job planifié.

**Exigences d'acceptation.**

- aucune dépendance directe discontinue ou non résoluble ;
- aucun advisory connu non évalué ;
- `pub outdated` produit un rapport examiné, sans politique « tout doit être à
  la dernière version » ;
- `pub downgrade` suivi des tests reste vert si ce gate est retenu ;
- `publish --dry-run` est exécuté sur le commit exact destiné au tag.

## Ce qui est requis et ce qui est seulement souhaitable

### Requis avant de déclarer le dépôt vert

- décision de fenêtre SDK et exécution minimum + stable actuelle ;
- démonstrateur réparé ou sorti du périmètre analysé/livré ;
- format, résolution, analyse et tests sans diagnostic bloquant ;
- configuration lints résoluble et maintenue ;
- CI PR/push épinglée, sans `curl | bash`.

### Requis avant une nouvelle publication

- autorité pub.dev et dépôt canonique confirmés ;
- version/changelog/métadonnées cohérents ;
- contenu de l'archive nettoyé et inspecté sur le commit exact ;
- README/API/liens conformes à la version publiée ;
- aucun fichier local ou document interne dans l'archive.

### Souhaitable mais non bloquant pour le premier lot

- stable précédente en plus de minimum + stable courante ;
- Codecov externe ;
- 100 % de couverture ;
- réécriture immédiate de tous les noms/groupes de tests historiques ;
- `dart doc`, downgrade et dry-run à chaque push plutôt qu'en release/schedule ;
- `CODEOWNERS`, `CONTRIBUTING.md`, benchmark de performance et automation OIDC.

## Lots minimaux ordonnés

1. **Gouvernance sans code** : confirmer droits pub.dev, dépôt canonique, nom,
   fenêtre SDK, version cible et devenir de `demo/`.
2. **Baseline non produit** : migrer les lints dans une version compatible,
   corriger format/diagnostics non produit, remplacer les tests vides, fixer
   les règles de lockfiles.
3. **Démonstrateur et archive** : moderniser ou exclure `demo/`, ajouter le
   `.pubignore`, exclure `/maintenance/`, vérifier les wrappers et le contenu
   exact du dry-run.
4. **CI minimale sûre** : SHA complets, Flutter minimum + 3.47.2, format,
   analyze, tests, PR + push, permissions minimales. Laisser Codecov hors du
   chemin critique initial.
5. **Métadonnées et documentation de release** : pubspec, changelog, README,
   API, sécurité, templates et badges, puis dry-run final.
6. **Migration produit séparée** : TextScaler et accessibilité non linéaire,
   avec minimum Flutter 3.16/Dart 3.2 au moins, compatibilité transitoire et
   version majeure si le minimum ou l'API historique est cassé.
7. **Durcissement optionnel** : stable précédente, downgrade/dartdoc planifiés,
   Codecov épinglé, OIDC pub.dev après protections GitHub validées.

## Validations reproduites

| Vérification | Résultat de la revue |
|---|---|
| Flutter 3.44.0 | Dart 3.12.0, DevTools 2.57.0 |
| Flutter 3.41.6 | Dart 3.11.4, 23 tests verts |
| Flutter 3.29.3 | Dart 3.7.2, 23 tests verts |
| `flutter pub get` 3.44 | 25 dépendances ; `pedantic` discontinué ; 7 plus récentes incompatibles avec la résolution maximale |
| `flutter analyze` | 27 diagnostics : 12 erreurs, 15 infos |
| `flutter analyze lib test example` | 11 infos, code de sortie 1 |
| `flutter test` 3.44 | 23 tests verts |
| Couverture 3.44 | 154/156, 98,7 % ; lignes 235-236 du changement de groupe non couvertes |
| `flutter pub downgrade` puis test sans pub | 23 tests verts |
| `dart format --output=none --set-exit-if-changed` | 26 fichiers, 2 à reformater, warning d'include `pedantic` |
| `demo/flutter pub get` | échec null safety sur `bottom_navy_bar` |
| `dart doc --dry-run` | 0 warning, 0 erreur |
| `publish --dry-run` au commit du rapport | 82 Ko, 0 warning, 1 hint SDK, audit inclus |
| Archive pub.dev 3.0.0 | 71 601 octets, demo/wrapper/tests et `demo/android/local.properties` inclus |
| Advisories pub.dev | listes vides pour les quatre packages cités |
| Wrapper JAR | hash officiel Gradle 2.10 ; propriétés ciblant Gradle 4.4 |
| Badges README | Shields en erreur, Codecov `unknown`, Appetize HTTP 200 |

Non vérifié : exécution Flutter 3.47.2/Dart 3.13.2, minimum Dart 2.12,
construction du demo après migration, paramètres GitHub/Codecov/Probot,
secrets, protections de branches et rôles pub.dev.

## Sources officielles contrôlées

- [Flutter SDK archive](https://docs.flutter.dev/install/archive)
- [Flutter 3.47 release notes](https://docs.flutter.dev/release/release-notes/release-notes-3.47.0)
- [Dart 3.13](https://dart.dev/blog/announcing-dart-3-13)
- [Supported deployment platforms](https://docs.flutter.dev/reference/supported-platforms)
- [Removal of v1 Android embedding](https://docs.flutter.dev/release/breaking-changes/v1-android-embedding)
- [Flutter Gradle Plugin DSL migration](https://docs.flutter.dev/release/breaking-changes/flutter-gradle-plugin-apply)
- [TextScaler migration](https://docs.flutter.dev/release/breaking-changes/deprecate-textscalefactor)
- [Flutter compatibility policy](https://docs.flutter.dev/release/compatibility-policy)
- [Dart 3 migration](https://dart.dev/resources/dart-3-migration)
- [Dart pubspec](https://dart.dev/tools/pub/pubspec)
- [Publishing packages](https://dart.dev/tools/pub/publishing)
- [Automated publishing](https://dart.dev/tools/pub/automated-publishing)
- [Lockfile guidance](https://dart.dev/tools/pub/private-files)
- [Official lints](https://pub.dev/packages/lints/versions)
- [Official Flutter lints](https://pub.dev/packages/flutter_lints/versions)
- [auto_size_text versions](https://pub.dev/packages/auto_size_text/versions)
- [auto_size_text score](https://pub.dev/packages/auto_size_text/score)
- [GitHub secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)
- [Codecov action](https://github.com/codecov/codecov-action)
- [Gradle Java compatibility](https://docs.gradle.org/current/userguide/compatibility.html)
- [Gradle wrapper security](https://docs.gradle.org/current/userguide/best_practices_security.html)
- [Gradle release checksums](https://gradle.org/release-checksums/)

## Inventaire et revue de sécurité

Tous les fichiers texte suivants ont été lus intégralement :

- `maintenance/audits/tooling-audit.md` ;
- `.gitignore`, `analysis_options.yaml`, `pubspec.yaml`, `CHANGELOG.md`,
  `LICENSE`, `README.md` ;
- `.github/FUNDING.yml`, `.github/no-response.yml`,
  `.github/workflows/dart.yml`, `.github/ISSUE_TEMPLATE/bug_report.md`,
  `.github/ISSUE_TEMPLATE/feature_request.md`,
  `.github/ISSUE_TEMPLATE/question.md` ;
- `lib/auto_size_text.dart`, `lib/src/auto_size_group.dart`,
  `lib/src/auto_size_group_builder.dart`, `lib/src/auto_size_text.dart` ;
- `test/basic_test.dart`, `test/group_builder_test.dart`,
  `test/group_test.dart`, `test/maxlines_test.dart`,
  `test/min_max_font_size_test.dart`, `test/overflow_replacement_test.dart`,
  `test/preset_font_sizes_test.dart`, `test/step_granularity_test.dart`,
  `test/text_fits_test.dart`, `test/utils.dart`, `test/wrap_words_test.dart` ;
- `example/pubspec.yaml`, `example/main.dart` ;
- `demo/.gitignore`, `demo/.metadata`, `demo/pubspec.yaml`,
  `demo/lib/animated_input.dart`, `demo/lib/main.dart`,
  `demo/lib/max_lines_demo.dart`, `demo/lib/min_font_size_demo.dart`,
  `demo/lib/overflow_replacement_demo.dart`,
  `demo/lib/preset_font_sizes_demo.dart`, `demo/lib/step_granularity.dart`,
  `demo/lib/sync_demo.dart`, `demo/lib/text_card.dart`,
  `demo/lib/utils.dart` ;
- `demo/android/.gitignore`, `demo/android/app/build.gradle`,
  `demo/android/app/src/main/AndroidManifest.xml`,
  `demo/android/app/src/main/java/com/github/leisim/auto_size_text/demo/MainActivity.java`,
  `demo/android/app/src/main/res/drawable/launch_background.xml`,
  `demo/android/app/src/main/res/values/styles.xml`,
  `demo/android/build.gradle`, `demo/android/gradle.properties`,
  `demo/android/gradle/wrapper/gradle-wrapper.properties`,
  `demo/android/gradlew`, `demo/android/gradlew.bat`,
  `demo/android/settings.gradle`.

Le JAR a été vérifié par taille/hash et comparaison aux checksums officiels ;
les médias ne sont pas pertinents pour les onze findings et n'ont pas été
réinterprétés visuellement.

Checklist sécurité : risque supply-chain confirmé dans la CI ; aucun secret en
clair dans le worktree ; chemins personnels historiques confirmés dans
l'archive publiée ; autorisation pub.dev non vérifiable ; advisories vides mais
non conclusifs. Injection applicative, XSS, CSRF, auth/authz, sessions, SQL,
cryptographie, stockage et races serveur sont non applicables à ce widget local
et à cette revue d'outillage.
