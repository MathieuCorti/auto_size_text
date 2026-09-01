# Revue indépendante du lot 7 — Archive pub déterministe

Date : 2026-09-01

Branche de revue : `codex/review-pub-archive`

Base exacte : `e9f75af9c3ef54bee2cbd3fcc0a53b44e7811968` (`S1`)

Candidat revu : `69a8c1d109e531e4e5f7b3a8c22a6fb871e9a702`

Candidat équivalent : `b2b9b72` ; `git diff --quiet 69a8c1d b2b9b72`
retourne 0.

## Verdict

**ACCEPTÉ.**

Aucun finding actionnable n'a été trouvé. Le lot remplace correctement la
dépendance historique à `.gitignore` par un `.pubignore` autonome, conserve
les 26 fichiers publics attendus et exclut les surfaces internes, générées ou
sensibles prescrites par la feuille de route.

Ce verdict accepte la tête parallèle `P7`; il **n'autorise pas son intégration
avant `S9`**. Conformément à la correction C2 de la revue finale, `P7` reste
hors de `codex/impl-integration` jusqu'à l'union revue
`S9 + D6 + P7 → S10`. Aucun merge, push, tag ou publish réel n'a été effectué
pendant cette revue.

## Périmètre et ascendance contrôlés

```text
HEAD:       69a8c1d109e531e4e5f7b3a8c22a6fb871e9a702
HEAD^:      e9f75af9c3ef54bee2cbd3fcc0a53b44e7811968
merge-base: e9f75af9c3ef54bee2cbd3fcc0a53b44e7811968
```

Avant ajout du présent rapport, le diff complet
`git diff e9f75af...HEAD` contient exactement :

```text
A  .pubignore
A  maintenance/implementation/lot-7-pub-archive.md
```

Les deux fichiers changés ont été lus intégralement : 75 lignes pour
`.pubignore`, 200 lignes pour le journal. Le diff représente 275 ajouts et ne
touche ni code produit, ni test, ni manifeste, ni lock, ni workflow, ni démo,
ni document public. `git diff --check e9f75af...HEAD` retourne 0.

## Preuve rouge sur le parent exact

Le parent a été extrait sans modification dans un répertoire temporaire :

```sh
git archive --format=tar e9f75af |
  tar -xf - -C /private/tmp/auto-size-text-review-parent.Zm8qon

cd /private/tmp/auto-size-text-review-parent.Zm8qon
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --no-version-check --suppress-analytics pub publish --dry-run
```

La commande retourne 0, mais le gate de contenu est rouge : **209 KB**
compressés, avec `maintenance/**`, `demo/**`,
`demo/android/gradle/wrapper/gradle-wrapper.jar`, `gradlew` et `gradlew.bat`.
Pub annonce déjà 0 warning sur le parent ; le défaut est donc bien la
composition de l'archive, pas la validité syntaxique du package.

## Preuve verte sur le candidat

Toolchain réellement exécutée :

```text
Flutter 3.47.2 • revision d3b14c8769
Engine 1cf1c4773fb941c4c74a7f8bb144a8837596c0f4
Dart 3.13.2 • DevTools 2.60.0
```

Commandes :

```sh
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --no-version-check --suppress-analytics pub publish --dry-run

/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --no-version-check --suppress-analytics pub publish --dry-run --verbose
```

Les deux commandes retournent 0. Le log verbeux a été contrôlé à partir de la
section autoritative `Creating .tar.gz stream containing:`. Résultat :

```text
taille compressée : 14 KB
fichiers :          26
tests :             15
warnings Pub :      0
```

Liste de fichiers observée dans le flux `.tar.gz` :

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

Les neuf assertions positives passent : `lib/`, `test/`,
`example/main.dart`, `example/pubspec.yaml`, `README.md`, `CHANGELOG.md`,
`LICENSE`, `pubspec.yaml` et `analysis_options.yaml` sont présents. Les quinze
fichiers sous `test/` restent publiés.

La comparaison avec les fichiers suivis est exacte : après retrait des seules
surfaces intentionnellement internes (`.github/`, `maintenance/`, `demo/`,
`example/pubspec.lock`, `.gitignore` et `.pubignore`), `git ls-files` retourne
précisément ces mêmes 26 fichiers. Aucun fichier public actuel n'est donc
écarté par une règle trop large.

Les recherches négatives dans la liste et dans le contenu des 26 fichiers ne
trouvent :

- ni `maintenance/`, `demo/`, `.github/`, `.dart_tool/`, `build/`,
  `coverage/`, `android/` ou `ios/` ;
- ni `pubspec.lock`, `local.properties`, secret, clé, signature, credential ou
  wrapper Gradle ;
- ni chemin `/Users/`, `C:\Users\` ou `C:/Users/`.

## Copie indépendante de `.gitignore`

Une copie a été créée avec :

```sh
rsync -a --exclude='.git' --exclude='.gitignore' ./ \
  /private/tmp/auto-size-text-review-pubignore.jtuJQb/
```

La copie ne contient aucun `.gitignore` ni répertoire Git. Les quatorze
sentinelles prescrites existaient réellement sur disque pendant le dry-run :

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

Les sentinelles de build/couverture contenaient `/Users/archive-fixture/` et
`local.properties` contenait `C:\Users\archive-fixture\...`. Le replay
Flutter 3.47.2 retourne 0, garde **14 KB / 26 fichiers / 15 tests / 0 warning**
et n'archive aucun de ces noms ou contenus. Cela prouve que le résultat ne
dépend ni de Git ni de `.gitignore`.

## Inspection des 64 motifs de `.pubignore`

Les 64 motifs actifs ont été lus individuellement. Une matrice synthétique a
ensuite placé au moins une sentinelle correspondant à chaque motif dans la
copie sans Git : états racine et imbriqués, chaque suffixe IDE/couverture/clé,
les répertoires de secrets et les trois artefacts wrapper. Après ce test, le
dry-run garde exactement la même liste de 26 fichiers.

| Lignes | Famille | Contrôle d'étendue |
|---|---|---|
| 2–14 | État Dart/Flutter, build, dartdoc et lock racine | Les formes racine et récursives couvrent l'état généré du package et de l'exemple. `/.packages`, `/doc/api/` et `/pubspec.lock` sont volontairement ancrés ; le lock applicatif imbriqué est traité explicitement ligne 44. Aucun fichier suivi publiable ne correspond à ces règles. |
| 17–27 | macOS et IDE | Les noms et suffixes sont usuels, récursifs quand nécessaire. Ils sont larges par nature, mais aucun fichier public suivi ne porte un de ces noms ou suffixes. |
| 30–38 | Projets Android/iOS et couverture | Les règles récursives `android/` et `ios/` sont intentionnellement larges pour ce package Flutter pur, sans implémentation plateforme. Elles excluent bien les sentinelles imbriquées sans toucher `example/main.dart`. Si le package devient un plugin, cette politique devra être revue avant publication, comme le journal le précise. |
| 41–44 | Matériel du dépôt et lock de l'exemple | Les quatre ancrages sont exacts : GitHub, maintenance, démo et `example/pubspec.lock` disparaissent, tandis que tout le code, les tests, l'exemple canonique et les documents publics restent présents. |
| 47–70 | Configuration locale, credentials, clés et signatures | Chaque nom, répertoire et suffixe a été exercé dans la matrice. L'étendue récursive est adaptée à la prévention de fuite et ne masque aucun fichier public actuel. Ces motifs ne constituent pas une DLP universelle ; la recherche de contenus sensibles sur le SHA final reste obligatoire. |
| 73–75 | Wrapper Gradle historique | Le JAR et les deux scripts sont exclus à la racine comme en profondeur ; le wrapper réel de la démo et les sentinelles de l'exemple n'entrent pas dans le flux. |

Les doublons explicites racine/récursif (`.dart_tool`, `.pub`, plugins Flutter,
`.DS_Store`, IDE, build, plateformes et couverture) sont défensifs et ne
réintroduisent aucun chemin. Aucune insuffisance ni exclusion trop large n'est
matérielle pour l'arbre et le contrat actuels.

## Diagnostics non bloquants

Le dry-run affiche deux informations qui ne sont pas des warnings de contenu :

- `material_color_utilities 0.13.0` a `0.13.1` disponible ;
- `test_api 0.7.12` a `0.7.13` disponible.

Ces deux packages sont transitifs et leurs versions courantes sont imposées par
le graphe du SDK Flutter 3.47.2. Le message « newer versions incompatible with
dependency constraints » décrit la résolution, pas l'archive et pas une
dépendance directe obsolète introduite par ce lot.

Le validateur verbeux expose aussi les six informations
`deprecated_member_use` déjà présentes dans
`lib/src/auto_size_text.dart`. Elles concernent `textScaleFactor` et
`textScaleFactorOf`, n'ont pas été introduites ni masquées par le lot 7 et
appartiennent à la migration `TextScaler` du lot 3. La conclusion du validateur
reste exactement `Package has 0 warnings.` ; aucun hint de contenu n'est émis.
Le rappel « The server may enforce additional checks » est la limite normale
d'un dry-run local et n'autorise pas une publication.

## Revue `find-bugs` et sécurité

### Cartographie de surface

| Fichier changé | Surface |
|---|---|
| `.pubignore` | Sélection locale des fichiers entrant dans l'artefact Pub ; aucune exécution produit, entrée utilisateur, requête, identité, session ou opération cryptographique. |
| `maintenance/implementation/lot-7-pub-archive.md` | Journal Markdown interne, lui-même exclu de l'archive. |

### Checklist complète

| Classe | Conclusion |
|---|---|
| Injection / commande / SQL / template | Hors surface : aucun code exécutable ni donnée distante interprétée par le diff. |
| XSS | Hors surface : aucun HTML ou rendu web généré. |
| Authentification | Hors surface. |
| Autorisation / IDOR | Hors surface ; l'autorité pub.dev n'est ni revendiquée ni utilisée. |
| CSRF | Hors surface. |
| Race / TOCTOU | Hors surface ; sélection déterministe et lecture seule lors du dry-run. |
| Session | Hors surface. |
| Cryptographie | Aucune opération cryptographique ; les artefacts de clés/signatures usuels sont exclus. |
| Divulgation d'information | Contrôlée : fichiers locaux, credentials conventionnels et chemins personnels absents du flux réel, y compris avec sentinelles. |
| Déni de service | Hors surface : deux fichiers texte, aucune boucle ni allocation runtime ajoutée. |
| Logique métier | Contrôlée par égalité exacte des 26 fichiers, 9/9 présences, 15 tests et assertions négatives. |
| Supply chain | Le wrapper historique et la démo sont exclus ; aucune action, dépendance ou binaire n'est ajouté. |

## Sources lues et limites

Ont été consultés pour cette revue :

- `developing-flutter`, ses références Effective Dart et testing, et
  `find-bugs` ;
- le lot 7, les gates archive/CI/finale de
  `maintenance/implementation-roadmap.md` ;
- la revue finale de la feuille de route, notamment C2, C6 et C7 ;
- les passages packaging, archive, démo, wrapper, chemins locaux et lockfiles
  des audits et de leurs revues indépendantes ;
- la revue du plan outillage sur `.pubignore` et les assertions positives et
  négatives ;
- `maintenance/decisions/example-lock-policy.md` intégralement ;
- le journal du lot 7 intégralement.

Restent volontairement non prouvés à ce stade : les contrôles serveur pub.dev,
l'autorité future de publication, le contenu après l'union avec `S9` et `D6`,
et la détection d'un secret arbitraire placé sous un nom apparemment public.
Ils relèvent respectivement de la gouvernance, du replay obligatoire à `S10`
et de la gate finale de contenu. Aucune de ces limites n'invalide le lot 7 sur
sa base `S1`.

## Commandes de clôture

```sh
git diff --check e9f75af...HEAD
git diff --name-status e9f75af...HEAD
git diff --quiet 69a8c1d b2b9b72
git status --short --branch
```

Les trois contrôles de diff retournent 0. Avant ajout du présent rapport,
`git status --short --branch` ne montrait que la branche propre
`codex/review-pub-archive`.
