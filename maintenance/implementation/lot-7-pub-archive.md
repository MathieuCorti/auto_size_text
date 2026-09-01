# Lot 7 — Archive pub déterministe

Date : 2026-09-01

Branche : `codex/impl-pub-archive`

Parent exact : `e9f75af9c3ef54bee2cbd3fcc0a53b44e7811968`

Tête : commit contenant ce journal ; SHA final communiqué dans le compte rendu

## Périmètre livré

- nouveau `.pubignore` autonome : aucune exclusion de publication ne dépend de
  `.gitignore` ;
- exclusions explicites des états et sorties Dart/Flutter, IDE, couverture,
  projets plateforme générés, lock racine, documents internes, démo, GitHub,
  lock de l'exemple, configurations locales, credentials, clés et signatures ;
- exclusion défensive du wrapper Gradle historique (`gradle-wrapper.jar`,
  `gradlew`, `gradlew.bat`) ;
- conservation volontaire de `test/**` et de l'exemple canonique ;
- aucun script permanent : les assertions shell temporaires suffisent et
  portent sur le flux `.tar.gz` que Pub annonce réellement construire.

Aucun code produit, test, manifeste, lock, workflow, document public ou fichier
de démo n'est modifié. Aucune publication réelle n'a été lancée.

## Toolchain exacte

```text
Flutter 3.47.2 • revision d3b14c8769
Engine 1cf1c4773fb941c4c74a7f8bb144a8837596c0f4
Dart 3.13.2 • DevTools 2.60.0
```

Binaire exécuté :
`/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter`.

Toutes les commandes Flutter ont reçu
`--no-version-check --suppress-analytics`. Les commandes `publish` ont toutes
reçu `--dry-run` ; aucune n'a reçu `--force` et aucune publication n'a eu lieu.

## Preuve rouge sur le parent

Commande exécutée sur le parent exact, avant création de `.pubignore` :

```sh
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --no-version-check --suppress-analytics pub publish --dry-run
```

La commande retourne 0 parce que l'ancien contenu est techniquement
publiable, mais le gate de contenu est rouge : archive compressée de **209 KB**
contenant `maintenance/**`, `demo/**`, le wrapper historique
`demo/android/gradle/wrapper/gradle-wrapper.jar`, `gradlew` et `gradlew.bat`.
Pub annonce 0 warning ; le défaut attendu est donc exclusivement un défaut de
contenu que le code de sortie seul ne détecte pas. Les tests sont déjà présents
et doivent le rester.

## Preuve verte et archive réelle

Commandes exécutées avec le `.pubignore` final :

```sh
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --no-version-check --suppress-analytics pub publish --dry-run
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --no-version-check --suppress-analytics pub publish --dry-run --verbose
```

Les deux commandes retournent 0. Le mode verbeux trace explicitement
`Creating .tar.gz stream containing:` ; les assertions portent sur cette liste
du flux d'archive, pas sur une estimation issue de Git. Résultat : **14 KB
compressés, 26 fichiers**, 0 warning de package et aucun hint de contenu.

Liste exacte des fichiers du flux `.tar.gz` :

```text
CHANGELOG.md
LICENSE
README.md
analysis_options.yaml
example/main.dart
example/pubspec.yaml
lib/auto_size_text.dart
lib/src/auto_size_group.dart
lib/src/auto_size_group_builder.dart
lib/src/auto_size_text.dart
pubspec.yaml
test/basic_test.dart
test/flutter_test_config.dart
test/group_builder_test.dart
test/group_test.dart
test/leak_tracking.dart
test/leak_tracking_test.dart
test/maxlines_test.dart
test/min_max_font_size_test.dart
test/overflow_replacement_test.dart
test/preset_font_sizes_test.dart
test/sdk_floor_api_test.dart
test/step_granularity_test.dart
test/text_fits_test.dart
test/utils.dart
test/wrap_words_test.dart
```

Présences affirmées : `lib/`, `test/`, `example/main.dart`,
`example/pubspec.yaml`, `README.md`, `CHANGELOG.md`, `LICENSE`, `pubspec.yaml`
et `analysis_options.yaml`. Les 15 fichiers de test restent publiés.

Absences affirmées dans les entrées : `maintenance/`, `demo/`, `.github/`,
`.dart_tool/`, `build/`, `coverage/`, tout `pubspec.lock`,
`local.properties`, clés/signatures/credentials et wrapper Gradle. Chaque
fichier du flux a également été recherché pour `/Users/`, `C:\Users\` et
`C:/Users/` : aucun chemin personnel n'est présent.

## Indépendance vis-à-vis de `.gitignore`

Une copie a été créée dans
`/private/tmp/auto-size-text-pubignore.ZZVyL9`, sans répertoire Git et en
omettant tous les `.gitignore` :

```sh
rsync -a --exclude='.git' --exclude='.gitignore' ./ \
  /private/tmp/auto-size-text-pubignore.ZZVyL9/
```

Les 14 sentinelles suivantes existaient réellement pendant le dry-run :

```text
.dart_tool/package_config.json
pubspec.lock
example/pubspec.lock
.github/workflows/dart.yml
maintenance/implementation-roadmap.md
demo/android/gradle/wrapper/gradle-wrapper.jar
build/private-path.txt
coverage/lcov.info
example/android/local.properties
example/android/app/release.keystore
example/android/gradle/wrapper/gradle-wrapper.jar
example/android/gradlew
lib/src/.env.local
lib/src/signing.key
```

Les fixtures de build/couverture contenaient `/Users/archive-fixture/` ;
`local.properties` contenait `C:\Users\archive-fixture\...`. Aucun de ces noms
ou contenus n'apparaît dans le flux d'archive. Le replay suivant retourne 0,
produit la même liste de 26 fichiers et la même taille annoncée de 14 KB :

```sh
cd /private/tmp/auto-size-text-pubignore.ZZVyL9
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --no-version-check --suppress-analytics pub publish --dry-run --verbose
```

Assertions exécutées sur la section `Creating .tar.gz stream containing:` du
log verbeux :

```text
.gitignore files: 0
excluded sentinels present on disk during dry-run: 14/14
required entries: 9/9 present
forbidden entry names: absent
personal paths in archived file contents: absent
archive file count: 26
```

## Diagnostics distincts du contenu

Le dry-run signale seulement que `material_color_utilities 0.13.1` et
`test_api 0.7.13` sont disponibles mais incompatibles avec le graphe résolu ;
c'est une information de résolution transitive, pas un problème d'archive.

Le log verbeux expose aussi les 6 informations analyzer
`deprecated_member_use` déjà connues dans `lib/src/auto_size_text.dart`, liées
à la migration `TextScaler` réservée au lot 3. Elles ne sont ni masquées ni
corrigées dans ce lot de packaging. Le validateur conclut néanmoins
`Package has 0 warnings.` et n'émet aucun hint de contenu.

La version reste volontairement `3.0.0` : son changement et le changelog de la
future release appartiennent au lot 12. Le dry-run ne publie pas et rappelle
que le serveur pourra appliquer des contrôles supplémentaires. La disponibilité
future de la version, l'autorité pub.dev et les contrôles serveur restent donc
hors de la preuve locale de ce lot.

## Risques et limites

- La liste et la taille doivent être rejouées sur la tête finale après l'union
  `S9 + D6 + P7` ; une taille faible ne remplace jamais les assertions.
- Les motifs de secrets couvrent les conventions usuelles, mais aucun filtre
  de nom ne peut identifier un secret arbitraire dans un fichier public : la
  recherche de chemins/contenus sensibles reste une gate de release.
- L'exclusion récursive des projets `android/` et `ios/` est intentionnelle
  pour ce package Dart/Flutter sans implémentation plateforme ; si le package
  devient un plugin, la politique devra être revue avant publication.
- Cette piste reste parallèle et ne doit pas être mergée dans l'intégration
  avant `S9`. Une validation de compatibilité et une revue packaging
  indépendante sont requises avant l'union `S10`.
- Aucun merge, push, tag, credential ou changement distant n'est effectué.
