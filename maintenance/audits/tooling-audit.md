# Audit outillage et maintenance

Date de l'audit : **2026-09-01**

Référence auditée : `master` / `f22397751271605ac46e8740d9e48ed631a74cb0`

Branche de travail : `codex/audit-tooling`

Périmètre : maintenabilité, publication et sûreté de la chaîne de livraison. Aucun code produit n'a été modifié.

## Résumé exécutif

Le cœur de la bibliothèque reste petit, sans dépendance d'exécution tierce autre que le SDK Flutter, et ses 23 tests existants passent avec Flutter 3.29.3, 3.41.6 et 3.44.0. Sous Flutter 3.44.0, la couverture est de 154/156 lignes (98,7 %), `dart doc --dry-run` ne signale rien et `flutter pub publish --dry-run` ne produit aucun avertissement.

Le dépôt n'est toutefois pas livrable de façon fiable aujourd'hui : le workflow CI appelle `dartfmt`, retiré des SDK actuels, exécute du code distant non épinglé avec un secret, et ne valide ni l'analyse ni les pull requests. Le démonstrateur ne résout plus ses dépendances sous Dart 3.12 et son projet Android repose sur l'embedding v1 retiré de Flutter 3.29, Gradle 4.4, AGP 3.1.2, JCenter et l'API Android 27. L'analyse globale échoue donc avec 12 erreurs et 15 informations.

La publication exige en outre une décision de gouvernance : `auto_size_text` 3.0.0 existe déjà sur pub.dev, sous le publisher `simc.dev`, alors que ce fork pointe vers `MathieuCorti/auto_size_text`. Une version publiée est immuable ; il faut vérifier les droits d'uploader/admin, choisir l'identité canonique du projet et publier une nouvelle version. Sans droits sur ce nom, un renommage de package serait une rupture.

Onze constats confirmés sont détaillés ci-dessous : 2 P0, 4 P1 et 5 P2. Les lots recommandés séparent les décisions de gouvernance, les changements purement de maintenance, la migration produit potentiellement cassante et le durcissement de la CI.

## Référence et environnement

| Élément | Valeur observée |
|---|---|
| Système | macOS 26.6.2, arm64 |
| Java | 26.0.1 |
| Flutter de diagnostic principal | 3.44.0, révision `559ffa3f75` |
| Dart principal | 3.12.0 |
| DevTools principal | 2.57.0 |
| Flutter supplémentaires | 3.29.3 / Dart 3.7.2 ; 3.41.6 / Dart 3.11.4 |
| Stable officielle au jour de l'audit | série Flutter 3.47 (correctif 3.47.2) / Dart 3.13 |
| Version du package | 3.0.0 |
| Dernier commit du fork | 2023-06-30 |
| Tag `v3.0.0` | commit de 2021 |

Flutter 3.47 n'était pas installé localement : la compatibilité avec la stable officielle la plus récente n'a pas été exécutée. Flutter 3.44 est la ligne stable immédiatement précédente selon le [calendrier officiel des versions Flutter](https://docs.flutter.dev/install/archive) ; Flutter 3.47 et Dart 3.13 ont été annoncés en août 2026 ([nouveautés Flutter](https://docs.flutter.dev/release/whats-new), [notes Flutter 3.47](https://docs.flutter.dev/release/release-notes/release-notes-3.47.0), [tracker du correctif 3.47.2](https://github.com/flutter/flutter/issues/191758), [annonce Dart 3.13](https://dart.dev/blog/announcing-dart-3-13)). Sources consultées le 2026-09-01.

## Baseline reproductible

Les commandes ont été exécutées depuis la racine du worktree, sauf mention contraire.

| Commande | Résultat |
|---|---|
| `/Users/mathieu/fvm/versions/3.44.0/bin/flutter --version` | Succès : Flutter 3.44.0, Dart 3.12.0, DevTools 2.57.0. |
| `/Users/mathieu/fvm/versions/3.44.0/bin/flutter pub get` | Succès. 25 dépendances résolues ; `pedantic 1.11.1` signalé comme abandonné, remplacé par `lints` ; 7 transitives ont une version plus récente incompatible avec les contraintes résolues. |
| `/Users/mathieu/fvm/versions/3.44.0/bin/flutter analyze` | Échec : 27 diagnostics, dont 12 erreurs et 15 informations. Les 12 erreurs viennent du démonstrateur non résolu/API supprimée ; les informations couvrent notamment `TextScaleFactor`, `MediaQuery.textScaleFactorOf`, `activeColor`, l'ordre `child:` et deux imports de tests inutiles. |
| `/Users/mathieu/fvm/versions/3.44.0/bin/flutter analyze lib test example` | Échec : 11 informations, aucune erreur ni avertissement. Six concernent la migration `TextScaler`, trois les tests de text scale et deux des imports inutiles. Les informations rendent le contrôle non vert dans cet environnement. |
| `/Users/mathieu/fvm/versions/3.44.0/bin/flutter test` | Succès : 23 tests. |
| `/Users/mathieu/fvm/versions/3.44.0/bin/flutter test --coverage --coverage-path=.dart_tool/tooling-audit-lcov.info` | Succès : 23 tests ; 154/156 lignes, soit 98,7 %. `auto_size_group_builder.dart` 5/5, `auto_size_text.dart` 124/126, `auto_size_group.dart` 25/25. |
| `/Users/mathieu/fvm/versions/3.29.3/bin/flutter test` | Succès : 23 tests, Dart 3.7.2. |
| `/Users/mathieu/fvm/versions/3.41.6/bin/flutter test` | Succès : 23 tests, Dart 3.11.4. |
| `/Users/mathieu/fvm/versions/3.44.0/bin/flutter pub downgrade` puis `.../flutter test --no-pub` | Succès : résolution minimale puis 23 tests. |
| `env FLUTTER_ROOT=/Users/mathieu/fvm/versions/3.44.0 /Users/mathieu/fvm/versions/3.44.0/bin/cache/dart-sdk/bin/dart format --output=none --set-exit-if-changed lib test example demo/lib` | Échec attendu du contrôle : 26 fichiers examinés, 2 à reformater (`lib/src/auto_size_group_builder.dart`, `test/group_builder_test.dart`). Avertissement de résolution de l'include `pedantic` lors du passage dans les sous-packages. Aucun fichier modifié avec `--output=none`. |
| `cd demo && /Users/mathieu/fvm/versions/3.44.0/bin/flutter pub get` | Échec : `bottom_navy_bar ^4.2.0` ne fournit pas une résolution null-safe compatible avec Dart 3.12. Le solveur suggère `bottom_navy_bar ^6.1.0` et `material_design_icons_flutter ^7.0.7296`. |
| `/Users/mathieu/fvm/versions/3.44.0/bin/flutter pub outdated --json` | Succès : 7 dépendances transitives ont une version plus récente ; aucune entrée retournée n'est marquée affectée par un advisory. |
| `/Users/mathieu/fvm/versions/3.44.0/bin/flutter pub publish --dry-run` | Succès : archive compressée de 71 Ko, 0 avertissement, 1 suggestion sur la contrainte SDK réinterprétée. L'archive inclut le démonstrateur Android, son wrapper/JAR et les tests. |
| `env FLUTTER_ROOT=/Users/mathieu/fvm/versions/3.44.0 /Users/mathieu/fvm/versions/3.44.0/bin/cache/dart-sdk/bin/dart doc --dry-run` | Succès : 0 avertissement, 0 erreur. |
| Requêtes `GET https://pub.dev/api/packages/{auto_size_text,pedantic,bottom_navy_bar,material_design_icons_flutter}/advisories` | Listes vides le 2026-09-01. Cela signifie « aucun advisory connu par pub.dev », pas « absence garantie de vulnérabilité ». |
| `/Users/mathieu/fvm/versions/3.44.0/bin/cache/dart-sdk/bin/dartfmt --version` | Échec : exécutable absent. Le workflow actuel échoue donc sur un SDK moderne à cette étape. |
| Requêtes HTTP des badges README | Badge GitHub Actions obsolète redirigé vers une erreur Shields ; badge Codecov rendu `unknown` ; démonstration Appetize accessible (HTTP 200). |
| `git diff --check` | Succès avant rédaction du présent rapport. |

Les fichiers générés par les diagnostics (`.dart_tool/`, `build/`, `pubspec.lock`, `example/pubspec.lock`) sont ignorés et ne font pas partie du changement soumis.

## Findings priorisés

### P0 — La CI actuelle est cassée et expose la chaîne de livraison

**Preuve.** `.github/workflows/dart.yml` ne se déclenche que sur `push`, utilise `actions/checkout@v1`, clone la branche Flutter `stable` sans version immuable, invoque l'exécutable retiré `dartfmt`, puis exécute `bash <(curl -s https://codecov.io/bash)` tout en lui donnant `CODECOV_TOKEN`. Il n'exécute pas `flutter analyze` et ne définit ni `permissions` minimales, ni matrice, ni délai maximal. L'appel local à `dartfmt` échoue. Un script réseau non épinglé dispose du secret du job ; aucune fuite n'a été observée, mais l'intégrité de ce code distant n'est pas garantie.

GitHub recommande des permissions minimales et précise que seul un SHA complet rend une action immuable ([Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)). Le dépôt officiel de [checkout](https://github.com/actions/checkout) documente la génération actuelle. Codecov fournit une [action officielle](https://github.com/codecov/codecov-action), également à épingler par SHA ou à retirer. Sources consultées le 2026-09-01.

**Changement minimal.** Remplacer le clonage manuel par une installation Flutter à version exacte, `dartfmt` par `dart format --output=none --set-exit-if-changed`, déclencher `pull_request` et `push` sur les branches protégées, ajouter `permissions: contents: read`, délais et concurrence, puis exécuter get/analyze/test. Épingler chaque action par SHA complet. Utiliser l'action Codecov actuelle avec son mode d'authentification documenté, sans `curl | bash`, ou désactiver l'envoi tant qu'il n'est pas configuré.

### P0 — Le démonstrateur ne peut ni résoudre ses dépendances ni construire sur Flutter actuel

**Preuve.** `demo/pubspec.yaml` contraint Dart à `<3.0.0` et dépend de `bottom_navy_bar ^4.2.0` et `material_design_icons_flutter ^4.0.5755`. `flutter pub get` échoue sous Dart 3.12. Le code utilise aussi `SystemChrome.setEnabledSystemUIOverlays`, retiré. Le projet Android combine Gradle 4.4, AGP 3.1.2, JCenter, `compileSdkVersion`/`targetSdkVersion` 27, `minSdkVersion` 16, l'application impérative du plugin Flutter et l'embedding v1 (`io.flutter.app.FlutterActivity`). L'embedding v1 a été retiré de Flutter 3.29 ([migration officielle](https://docs.flutter.dev/release/breaking-changes/v1-android-embedding)). La DSL déclarative du plugin Gradle est la voie actuelle ([migration officielle](https://docs.flutter.dev/release/breaking-changes/flutter-gradle-plugin-apply)). La politique de plateformes Flutter actuelle commence Android à l'API 24 ([plateformes prises en charge](https://docs.flutter.dev/reference/supported-platforms)). Gradle 4.4 est aussi incompatible avec Java 26 selon la [matrice officielle Gradle/Java](https://docs.gradle.org/current/userguide/compatibility.html). Sources consultées le 2026-09-01.

**Changement minimal.** Décider si `demo/` est un artefact livré ou seulement une démonstration du dépôt. S'il est conservé, régénérer son scaffold avec la stable Flutter retenue, migrer les API supprimées et remplacer les deux composants visuels tiers par `NavigationBar`/icônes Flutter lorsque possible ; c'est plus petit et moins risqué qu'une mise à jour de dépendances inutiles. Résoudre, construire et tester le démonstrateur dans un job séparé, puis versionner son lockfile d'application. S'il n'est pas maintenu, le retirer du dépôt et/ou de l'archive publiée au lieu d'expédier un exemple cassé.

### P1 — La configuration analyzer/lints est abandonnée et masque une erreur d'include

**Preuve.** `pubspec.yaml` utilise `pedantic >=1.11.1 <3.0.0`, annoncé comme abandonné par le solveur. `analysis_options.yaml` inclut `package:pedantic/analysis_options.yaml`, conserve les anciens réglages `strong-mode` et désactive `include_file_not_found`. Le contrôle de format signale que l'include n'est pas résolu depuis certains sous-packages. Les [règles `pedantic`](https://pub.dev/documentation/pedantic/latest/) recommandent elles-mêmes `lints` ou `flutter_lints`; [lints](https://pub.dev/packages/lints) et [flutter_lints](https://pub.dev/packages/flutter_lints) sont les ensembles officiels. Source consultée le 2026-09-01.

**Changement minimal.** Choisir `flutter_lints` ou `lints` dans une version compatible avec le plancher SDK retenu, supprimer les options obsolètes et ne plus masquer `include_file_not_found`. Corriger la dette par petites catégories, puis rendre l'analyse fatale dans la CI. Activer progressivement les contrôles de casts/valeurs dynamiques actuels plutôt que recopier une longue liste de lints figée.

### P1 — Les contraintes SDK sont trompeuses et la politique de compatibilité n'est pas définie

**Preuve.** La racine déclare `sdk: '>=2.12.0 <3.0.0'`, mais Dart 3 réinterprète automatiquement une contrainte null-safe `<3.0.0` en `<4.0.0` ([guide officiel de migration Dart 3](https://dart.dev/resources/dart-3-migration)). C'est pourquoi le package se résout sous Dart 3.12 ; `pub publish --dry-run` demande de rendre cette réalité explicite. Aucune contrainte `flutter:` ne fixe le plancher Flutter. Les tests passent sur les trois SDK locaux mais ni le plancher déclaré Dart 2.12, ni la stable Flutter 3.47 n'ont été exécutés.

Le code et les tests produisent neuf diagnostics liés à `textScaleFactor`. Flutter a déprécié ces API au profit de `TextScaler` pour permettre le redimensionnement non linéaire d'Android 14 ([guide de migration TextScaler](https://docs.flutter.dev/release/breaking-changes/deprecate-textscalefactor)). Flutter ne promet pas une date fixe de suppression après dépréciation ([politique de compatibilité](https://docs.flutter.dev/release/compatibility-policy)). Sources consultées le 2026-09-01.

**Changement minimal.** Documenter une fenêtre supportée, puis déclarer explicitement Dart `<4.0.0` et un plancher Flutter réellement testé. Deux voies raisonnables : maintenir temporairement l'API 3.x avec un SDK ancien réellement testé, ou préparer une majeure qui adopte `TextScaler` et relève le plancher au minimum à Flutter 3.16/Dart 3.2. Une fenêtre récente (minimum, stable précédente, stable actuelle) réduit le coût de CI ; le choix appartient aux mainteneurs.

**Risque de rupture.** Relever le plancher exclut des applications ; remplacer le paramètre public `textScaleFactor` par `TextScaler` modifie l'API et le comportement d'accessibilité. Cette migration doit être séparée des changements d'outillage et annoncée comme potentiellement majeure.

### P1 — L'identité et l'autorité de publication ne sont pas établies

**Preuve.** pub.dev présente `auto_size_text` 3.0.0, publié le 2021-10-27 par `simc.dev` ([versions](https://pub.dev/packages/auto_size_text/versions), [API package](https://pub.dev/api/packages/auto_size_text)). Une version publiée ne peut pas être remplacée. Le `homepage` local pointe vers `github.com/leisim/auto_size_text`, aujourd'hui redirigé vers l'amont, tandis que `origin` est `MathieuCorti/auto_size_text`. Aucun accès aux rôles publisher/uploader n'était disponible pendant l'audit. Le guide officiel couvre le [processus de publication](https://dart.dev/tools/pub/publishing) et la [publication automatisée par OIDC depuis GitHub](https://dart.dev/tools/pub/automated-publishing). Sources consultées le 2026-09-01.

**Changement minimal.** Avant tout tag, confirmer les droits d'uploader/admin auprès de `simc.dev`, choisir le dépôt canonique, mettre à jour `repository`, `homepage`, `issue_tracker`, version et changelog, puis publier une nouvelle version. Configurer l'OIDC pub.dev uniquement après validation des propriétaires et de l'environnement GitHub.

**Risque de rupture.** Sans droits sur `auto_size_text`, publier sous un autre nom impose une migration d'import/dépendance aux utilisateurs. Ne pas déduire l'autorité de publication de l'accès au fork GitHub.

### P1 — La suite passe mais contient des tests vides et aucune vraie matrice de support

**Preuve.** `test/step_granularity_test.dart` ne contient qu'un `main()` vide. Le test « Unlimited maxLines if parameter null » de `test/maxlines_test.dart` a un corps vide. `test/utils.dart` expose un helper mort vers `test/assets/Roboto-Regular.ttf`, fichier absent. Les 2 lignes non couvertes sont la branche `didUpdateWidget` qui change d'`AutoSizeGroup`. Les tests ne sont pas structurés en `group()` et leurs titres ne formulent pas systématiquement le comportement attendu. La CI ne teste ni la version minimale, ni la stable actuelle, ni le downgrade, le démonstrateur, la documentation ou la publication à blanc.

**Changement minimal.** Remplacer les deux tests vides par des assertions utiles, couvrir le changement de groupe, supprimer/réparer le helper mort et organiser les tests par unité/comportement avec des noms « should … ». Après décision de compatibilité, exécuter une matrice minimum + stable précédente + stable actuelle ; ajouter un job de résolution minimale et des contrôles `dart doc`/`pub publish --dry-run`. Conserver la couverture comme signal, sans faire du pourcentage le substitut aux assertions.

### P2 — L'archive pub embarque un démonstrateur Android cassé et des exécutables historiques

**Preuve.** `flutter pub publish --dry-run` inclut `demo/android/gradlew`, `gradlew.bat`, `gradle-wrapper.jar`, le scaffold obsolète et les sources du démonstrateur. L'archive n'est que de 71 Ko compressée : le problème n'est pas la taille, mais la qualité et la provenance des artefacts livrés. Le wrapper JAR a été inspecté par type, taille et SHA-256, sans validation de provenance. Les règles d'inclusion sont documentées dans [Publishing packages](https://dart.dev/tools/pub/publishing) et la structure recommandée dans [Package layout conventions](https://dart.dev/tools/pub/package-layout). La documentation Gradle recommande de vérifier le wrapper et le checksum de distribution ([Gradle Wrapper](https://docs.gradle.org/current/userguide/gradle_wrapper.html), [bonnes pratiques de sécurité](https://docs.gradle.org/current/userguide/best_practices_security.html)). Sources consultées le 2026-09-01.

**Changement minimal.** Moderniser et valider le démonstrateur avant de le livrer, ou ajouter un `.pubignore` ciblé pour exclure `/demo/` si `example/` reste l'exemple officiel. Inspecter à chaque release la liste exacte de `publish --dry-run`. Si un wrapper reste versionné, le régénérer avec la toolchain retenue et fixer `distributionSha256Sum`.

### P2 — README, badges et documentation API décrivent un projet ancien

**Preuve.** Les liens et badges visent majoritairement l'ancien dépôt ; le badge CI est cassé et Codecov affiche `unknown`. Le README contient notamment un lien d'ancre `#roubleshooting`, une accolade isolée, « bonds », « String tool long », omet `strutStyle` dans la liste des paramètres et donne des conseils `textScaleFactor` désormais dépréciés. L'affirmation de performance n'est pas étayée par un benchmark reproductible. La licence MIT est répétée dans le README et `LICENSE`. Le lien Appetize est encore accessible.

`dart doc --dry-run` est vert. Le score pub.dev observé est 150/160 : 8 diagnostics statiques, 96,3 % d'API documentée (26/27), le constructeur `AutoSizeGroup.new` étant le symbole manquant ([score pub.dev](https://pub.dev/packages/auto_size_text/score)). Le score publié correspond à l'artefact 3.0.0 existant ; il ne peut être corrigé que dans une nouvelle version.

**Changement minimal.** Réécrire les URLs/badges vers le dépôt canonique et le nouveau workflow, corriger les coquilles/liste de paramètres, documenter `AutoSizeGroup`, migrer les conseils d'accessibilité vers `TextScaler` au même moment que l'API, et supprimer ou mesurer l'affirmation de performance. Garder une seule formulation canonique de la licence avec lien vers `LICENSE`.

### P2 — Les métadonnées de maintenance et de sécurité sont incomplètes ou obsolètes

**Preuve.** Le pubspec n'a que `homepage`, sans `repository` ni `issue_tracker`. `.github/FUNDING.yml` cible l'ancien mainteneur ; le template question assigne `leisim` et les formulaires demandent des versions anciennes. Il n'existe ni `SECURITY.md`, ni `CONTRIBUTING.md`, ni `CODEOWNERS`. `.github/no-response.yml` suppose une application Probot dont l'installation n'est pas vérifiable localement. GitHub recommande une politique de signalement privée via `SECURITY.md` ([guide de sécurisation de dépôt](https://docs.github.com/en/code-security/getting-started/quickstart-for-securing-your-repository)). Source consultée le 2026-09-01.

**Changement minimal.** Ajouter les métadonnées pub pertinentes, retirer ou réattribuer le financement, actualiser les templates et publier une politique de sécurité avec canal de contact et versions supportées. Ajouter `CONTRIBUTING.md`/`CODEOWNERS` seulement avec des propriétaires réels. Vérifier ou retirer la configuration no-response.

### P2 — La politique de lockfiles doit distinguer bibliothèque, exemple et application

**Preuve.** `.gitignore` ignore tous les `pubspec.lock`. C'est correct pour la bibliothèque racine : les bibliothèques doivent être résolues avec les contraintes de leurs consommateurs. `demo/` est en revanche une application et devrait verrouiller sa résolution une fois réparée. `example/` peut être traité comme exemple de package, mais la décision doit être explicite. Le glossaire officiel recommande de committer le lockfile des applications et non celui des packages réutilisables ([Dart glossary — lockfile](https://dart.dev/resources/glossary)). Source consultée le 2026-09-01.

**Changement minimal.** Remplacer la règle globale par des règles ciblées : ignorer le lockfile racine de la bibliothèque, versionner `demo/pubspec.lock` si le démonstrateur est maintenu comme application, et documenter le choix pour `example/`.

### P2 — Les dépendances sont peu nombreuses, mais les signaux de maintenance doivent devenir des gates

**Preuve.** La bibliothèque n'a aucune dépendance runtime tierce en dehors de `flutter`; la surface supply-chain de production est donc faible. `pedantic` est abandonné. Les deux dépendances directes du démonstrateur sont anciennes et sa résolution échoue. Les quatre endpoints advisory interrogés sur pub.dev ont renvoyé une liste vide le 2026-09-01. pub.dev documente le fonctionnement et les limites des [security advisories](https://dart.dev/tools/pub/security-advisories). Les fiches actuelles sont [bottom_navy_bar](https://pub.dev/packages/bottom_navy_bar) et [material_design_icons_flutter](https://pub.dev/packages/material_design_icons_flutter).

**Changement minimal.** Préférer la suppression des dépendances visuelles non nécessaires du démonstrateur. Ajouter à la maintenance de release `pub outdated`, `pub downgrade` + tests et `publish --dry-run`; traiter les advisories comme un signal, avec mise à jour/résolution rapide, sans prétendre qu'une liste vide prouve l'absence de vulnérabilité.

## Éléments déjà sains

- La bibliothèque est petite et pure Flutter : une seule dépendance d'exécution, le SDK Flutter, sans réseau, base de données, authentification, stockage ou code natif produit.
- Les 23 tests existants passent sur trois lignes Flutter/Dart locales et après `pub downgrade`.
- La couverture de ligne est élevée (98,7 %) et localise précisément le manque restant.
- `dart doc --dry-run` est propre ; la documentation publique publiée atteint 26/27 symboles.
- `flutter pub publish --dry-run` n'émet aucun avertissement et produit une archive modeste.
- `LICENSE` contient une licence MIT complète ; `README.md` et `CHANGELOG.md` existent.
- La racine ignore correctement `.dart_tool/`, `build/`, la sortie dartdoc et le lockfile d'une bibliothèque.
- Le package ne nécessite pas de stanza `platforms` native : pub.dev détecte actuellement Android, iOS, Linux, macOS, web, Windows et WASM pour cette API Flutter pure.
- Aucun advisory connu n'a été retourné par pub.dev pour le package ou les dépendances directes examinées à la date de l'audit.

## Risques de breaking change

| Décision | Risque | Atténuation |
|---|---|---|
| Relever le plancher Dart/Flutter | Exclut les applications sur anciennes toolchains. | Publier la fenêtre de support, tester le minimum réel et réserver une hausse importante à une release annoncée. |
| Remplacer `textScaleFactor` par `TextScaler` | API publique et comportement d'accessibilité changés. | Migration dédiée, tests de scaling linéaire/non linéaire et version majeure si la compatibilité source ne peut être conservée. |
| Renommer le package faute de droits pub.dev | Tous les consommateurs changent leur dépendance et potentiellement leurs imports. | Obtenir les droits sur le nom existant en priorité ; sinon publier un guide de migration et une période de transition. |
| Retirer `demo/` de l'archive ou du dépôt | Liens de démonstration et habitudes de contributeurs peuvent casser. | Garder `example/` exécutable, corriger les liens et annoncer la nouvelle source de démonstration. |
| Passer à des lints actuels | Nombreux diagnostics et éventuellement comportement après corrections mécaniques. | Lot séparé, activation progressive et revue de chaque correction non mécanique. |

## Découpage recommandé en lots

1. **Décisions de gouvernance, sans code** : confirmer les droits pub.dev, le dépôt canonique, le nom/version, la fenêtre SDK et le devenir de `demo/`. C'est le préalable aux autres lots.
2. **Maintenance non produit** : métadonnées/version/changelog, lints/analyzer, format, lockfiles ciblés, politique de sécurité/templates, puis modernisation ou exclusion du démonstrateur. Ce lot doit rendre tous les contrôles locaux verts sans modifier l'API de la bibliothèque.
3. **Compatibilité produit dédiée** : migrer `TextScaler`, préserver l'accessibilité non linéaire, ajouter les tests de groupe/scaling et documenter la rupture. Ne pas cacher cette migration dans le lot CI.
4. **CI durcie une fois la baseline verte** : actions et SDK épinglés, PR + push, permissions minimales, format/analyze/tests/couverture, minimum + stable précédente + stable actuelle, downgrade, démonstrateur, dartdoc et publication à blanc. Ajouter timeouts/concurrency et Codecov sûr ou le supprimer.
5. **Documentation et release** : README/API/badges/liens, vérification de l'archive, tag de nouvelle version, puis publication OIDC seulement après validation des droits et protections GitHub.

## Revue de sécurité outillage

| Classe vérifiée | Conclusion |
|---|---|
| Injection / supply chain | Risque confirmé dans la CI : script Codecov téléchargé puis exécuté sans épinglage ; Flutter stable cloné sans version immuable ; `checkout@v1`. |
| Exposition de secrets | Aucun secret présent dans les fichiers lus. Le token Codecov est transmis à du code distant non épinglé, ce qui augmente le risque sans prouver une fuite. |
| Dépendances / advisories | Aucun advisory pub.dev connu retourné ; `pedantic` abandonné ; démonstrateur non résoluble et dépendances anciennes. |
| Binaire versionné | Wrapper Gradle JAR inspecté par métadonnées/hash seulement ; provenance et signature non vérifiées. |
| XSS, CSRF, auth/authz, sessions, cryptographie, SQL, races de données | Non applicables à cet audit d'un widget local sans serveur, réseau, identité ni stockage. |
| DoS / logique métier du widget | Hors périmètre de cet audit outillage ; à couvrir par l'audit produit/performance. |

Non vérifiable depuis le worktree : protections de branches et règles Actions, installation Codecov/Probot, paramètres Dependabot/secret scanning, valeurs des secrets, rôles pub.dev uploader/admin, provenance historique du wrapper JAR, exécution sur Flutter 3.47/Dart 3.13 et exécution sur le minimum SDK déclaré.

## Inventaire des fichiers inspectés

Tous les fichiers texte suivis ci-dessous ont été lus intégralement. Les binaires ont été inventoriés par type, taille et SHA-256, sans interprétation de leur contenu.

### Racine et métadonnées

- `.gitignore`
- `analysis_options.yaml`
- `pubspec.yaml`
- `CHANGELOG.md`
- `LICENSE`
- `README.md`

### GitHub et automatisation

- `.github/FUNDING.yml`
- `.github/no-response.yml`
- `.github/workflows/dart.yml`
- `.github/ISSUE_TEMPLATE/bug_report.md`
- `.github/ISSUE_TEMPLATE/feature_request.md`
- `.github/ISSUE_TEMPLATE/question.md`

### Bibliothèque

- `lib/auto_size_text.dart`
- `lib/src/auto_size_group.dart`
- `lib/src/auto_size_group_builder.dart`
- `lib/src/auto_size_text.dart`

### Tests

- `test/basic_test.dart`
- `test/group_builder_test.dart`
- `test/group_test.dart`
- `test/maxlines_test.dart`
- `test/min_max_font_size_test.dart`
- `test/overflow_replacement_test.dart`
- `test/preset_font_sizes_test.dart`
- `test/step_granularity_test.dart`
- `test/text_fits_test.dart`
- `test/utils.dart`
- `test/wrap_words_test.dart`

### Exemple

- `example/pubspec.yaml`
- `example/main.dart`

### Démonstrateur

- `demo/.gitignore`
- `demo/.metadata`
- `demo/pubspec.yaml`
- `demo/lib/animated_input.dart`
- `demo/lib/main.dart`
- `demo/lib/max_lines_demo.dart`
- `demo/lib/min_font_size_demo.dart`
- `demo/lib/overflow_replacement_demo.dart`
- `demo/lib/preset_font_sizes_demo.dart`
- `demo/lib/step_granularity.dart`
- `demo/lib/sync_demo.dart`
- `demo/lib/text_card.dart`
- `demo/lib/utils.dart`
- `demo/android/.gitignore`
- `demo/android/app/build.gradle`
- `demo/android/app/src/main/AndroidManifest.xml`
- `demo/android/app/src/main/java/com/github/leisim/auto_size_text/demo/MainActivity.java`
- `demo/android/app/src/main/res/drawable/launch_background.xml`
- `demo/android/app/src/main/res/values/styles.xml`
- `demo/android/build.gradle`
- `demo/android/gradle.properties`
- `demo/android/gradle/wrapper/gradle-wrapper.properties`
- `demo/android/gradlew`
- `demo/android/gradlew.bat`
- `demo/android/settings.gradle`

### Binaires ou médias inspectés par métadonnées seulement

| Fichier | Taille (octets) | SHA-256 |
|---|---:|---|
| `.github/art/group.gif` | 1 437 139 | `fa4097e6766b536b3c16ea7ecd06ed577c5d8ac0250e912dda300e92246ef814` |
| `.github/art/logo.svg` | 4 368 | `da690546e3cd37ebbc50d8a55689d9c0b8918157e529420ca7744f5a936dc797` |
| `.github/art/maxlines.gif` | 609 102 | `0e803ec2a7a36d60d1103fae4278e521d30b6593b0b14fa1d443e3ffbefd3fad` |
| `.github/art/maxlines_rich.gif` | 465 666 | `5a827ebb2c48bbbb2b2b52a2dfb17cb3775b6d04ef5465b92cdd29979a33ffb2` |
| `.github/art/minfontsize.gif` | 642 775 | `0e7634e4e3da30a575cd1a66330cf7026cb06268f6ac7483bc38519b73b98421` |
| `.github/art/overflowreplacement.gif` | 493 841 | `d739960ae0a645eeb34b5fc8ec2b72b84f1083448407bcd701556d89dba63dd3` |
| `.github/art/presetfontsizes.gif` | 605 165 | `27a3ce983bbe7267c5491f2e60b2643f122ebc7488505fcf1377368af4f2d718` |
| `.github/art/stepgranularity.gif` | 689 430 | `1d50ff238116e3ce4989aaf198648b5d2676c320843eda7a50d7862175adbcfe` |
| `demo/android/app/src/main/res/drawable/ic_launcher.png` | 1 031 | `4d470bf22d5c17d84edc5f82516d1ba8a1c09559cd761cefb792f86d9f52b540` |
| `demo/android/gradle/wrapper/gradle-wrapper.jar` | 53 636 | `16caeaf66d57a0d1d2087fef6a97efa62de8da69afa5b908f40db35afc4342da` |

Les métadonnées Git (`status`, branche, remotes, logs, tags et index des fichiers) ainsi que les sorties générées de résolution, analyse, test, couverture, documentation et publication à blanc ont aussi été examinées. Elles ne sont pas des sources suivies à modifier.

## Sources officielles complémentaires

Toutes consultées le 2026-09-01 :

- [Dart pubspec](https://dart.dev/tools/pub/pubspec)
- [Dart formatter](https://dart.dev/tools/dart-format)
- [Dart analyzer](https://dart.dev/tools/analysis)
- [Dart changelog](https://dart.dev/changelog)
- [Dart security advisories](https://dart.dev/tools/pub/security-advisories)
- [Flutter archive](https://docs.flutter.dev/install/archive)
- [Flutter compatibility policy](https://docs.flutter.dev/release/compatibility-policy)
- [GitHub secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)
- [Gradle Wrapper](https://docs.gradle.org/current/userguide/gradle_wrapper.html)

## Conclusion

La bibliothèque elle-même offre une baseline rassurante, mais le dépôt doit d'abord restaurer une chaîne de validation déterministe et trancher son identité de publication. L'ordre sûr est : décisions de gouvernance, réparation/exclusion du démonstrateur et configuration analyzer, migration produit `TextScaler` explicitement versionnée, puis CI épinglée et release automatisée. Une release ne devrait pas être tentée avant que l'analyse globale, le démonstrateur choisi et la matrice de support documentée soient verts.
