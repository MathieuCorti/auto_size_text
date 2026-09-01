# Vérification du plancher Flutter/Dart

Date de vérification : 2026-09-01
Base : `dev` / `d0fe48d60715ec749f9a1761416abc1b6f368dcf`

## Décision

Retenir pour le package et l'exemple :

```yaml
environment:
  sdk: '>=3.11.0 <4.0.0'
  flutter: '>=3.41.0'
```

Flutter **3.41.0 / Dart 3.11.0 est installable et constitue le plancher
technique suffisant** pour le correctif prévu. Il résout les dépendances de la
baseline, exécute les 23 tests historiques et compile le micro-probe des API
modernes. Flutter
3.41.6 / Dart 3.11.4 donne les mêmes résultats et n'apporte aucune API requise
supplémentaire. Le choisir comme minimum exclurait donc sans justification les
correctifs 3.41.0 à 3.41.5.

La stable officielle disponible le jour de cette vérification est Flutter
**3.47.2 / Dart 3.13.2**. Elle doit être la seconde entrée exacte de la matrice,
sans utiliser le canal mutable `stable`.

## Toolchains contrôlées

Le manifeste macOS officiel a été téléchargé puis interrogé :

```sh
curl --fail --location --silent --show-error \
  https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json \
  --output /private/tmp/flutter-releases-macos.json

jq -r '.current_release,
  (.releases[]
    | select(.version == "3.41.0" or .version == "3.41.6" or .version == "3.47.2")
    | [.hash, .channel, .version, .dart_sdk_version, .dart_sdk_arch,
       .archive, .sha256, .release_date]
    | @tsv)' /private/tmp/flutter-releases-macos.json
```

Résultat utile :

| Flutter | Dart | Révision Flutter | Archive ARM64 officielle | SHA-256 officiel |
|---|---|---|---|---|
| 3.41.0 | 3.11.0 | `44a626f4f0027bc38a46dc68aed5964b05a83c18` | `stable/macos/flutter_macos_arm64_3.41.0-stable.zip` | `24aa98db60e36b1dad60f4e0859d3299be2a185519392c58ef06e886daa044f6` |
| 3.41.6 | 3.11.4 | `db50e20168db8fee486b9abf32fc912de3bc5b6a` | `stable/macos/flutter_macos_arm64_3.41.6-stable.zip` | `15a71cc371abe6dafbb267f43fcdd9b4be26c4d5e5dbf49283a79f58dcf9072d` |
| 3.47.2 | 3.13.2 | `d3b14c876900e553bc736ca19295fc09e3853e8e` | `stable/macos/flutter_macos_arm64_3.47.2-stable.zip` | `f456fd6733053d9301828a2e702d6cbec872923126809aa8c48eb0a696d6cc01` |

Le champ `current_release.stable` du manifeste valait
`d3b14c876900e553bc736ca19295fc09e3853e8e`, soit 3.47.2. Le lien FVM local
`stable` pointait encore sur 3.27.1 et n'a donc pas été utilisé.

3.41.0 et 3.47.2, absents du cache FVM local, ont été installés depuis les
bundles officiels :

```sh
curl --fail --location --silent --show-error \
  https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.41.0-stable.zip \
  --output /private/tmp/flutter_macos_arm64_3.41.0-stable.zip

curl --fail --location --silent --show-error \
  https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.47.2-stable.zip \
  --output /private/tmp/flutter_macos_arm64_3.47.2-stable.zip

shasum -a 256 \
  /private/tmp/flutter_macos_arm64_3.41.0-stable.zip \
  /private/tmp/flutter_macos_arm64_3.47.2-stable.zip

unzip -q /private/tmp/flutter_macos_arm64_3.41.0-stable.zip \
  -d /private/tmp/flutter-sdk-3.41.0
unzip -q /private/tmp/flutter_macos_arm64_3.47.2-stable.zip \
  -d /private/tmp/flutter-sdk-3.47.2
```

Les hashes calculés correspondent au manifeste. Les commandes de version ont
ensuite confirmé les bundles réellement exécutés :

```sh
/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --no-version-check --suppress-analytics --version
/Users/mathieu/fvm/versions/3.41.6/bin/flutter \
  --no-version-check --suppress-analytics --version
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --no-version-check --suppress-analytics --version
```

| Flutter | Dart | DevTools | Moteur signalé |
|---|---|---|---|
| 3.41.0 | 3.11.0 | 2.54.1 | `cc8e596aa65130a0678cc59613ed1c5125184db4` |
| 3.41.6 | 3.11.4 | 2.54.2 | `5cdd32777948fa7a648fac915f8da7120ac7e97a` |
| 3.47.2 | 3.13.2 | 2.60.0 | `1cf1c4773fb941c4c74a7f8bb144a8837596c0f4` |

## Baseline actuelle, avant migration

Les commandes suivantes ont été exécutées depuis la racine du worktree. Elles
testent le code actuel ; elles ne prétendent pas valider un correctif qui
n'existe pas encore.

### Flutter 3.41.0

```sh
/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --no-version-check --suppress-analytics pub get
/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --no-version-check --suppress-analytics test --reporter compact
/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --no-version-check --suppress-analytics analyze lib test example/main.dart
/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --no-version-check --suppress-analytics analyze
```

Résultats : résolution racine et exemple réussie, 25 dépendances racine, puis
**23/23 tests verts**. L'analyse ciblée termine avec 11 informations
historiques et le code 1 : neuf usages dépréciés de `textScaleFactor` ou
`textScaleFactorOf`, et deux imports inutiles. L'analyse globale retrouve les
**27 diagnostics déjà audités**, soit 12 erreurs dans la démo non résolue et
15 informations. Ce rouge est la baseline produit/outillage connue, pas un
échec propre à 3.41.0.

### Flutter 3.41.6

```sh
/Users/mathieu/fvm/versions/3.41.6/bin/flutter \
  --no-version-check --suppress-analytics pub get
/Users/mathieu/fvm/versions/3.41.6/bin/flutter \
  --no-version-check --suppress-analytics test --reporter compact
/Users/mathieu/fvm/versions/3.41.6/bin/flutter \
  --no-version-check --suppress-analytics analyze lib test example/main.dart
```

Résultats : résolution racine et exemple réussie, **23/23 tests verts**, et les
mêmes 11 informations ciblées. Aucun avantage de compatibilité ou de qualité
n'a été observé par rapport à 3.41.0.

### Flutter 3.47.2

```sh
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --no-version-check --suppress-analytics pub get
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --no-version-check --suppress-analytics test --reporter compact
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --no-version-check --suppress-analytics analyze lib test example/main.dart
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --no-version-check --suppress-analytics analyze
```

Résultats : résolution racine et exemple réussie, **23/23 tests verts**, 11
informations ciblées et les mêmes 27 diagnostics globaux. Flutter 3.47.2 ajoute
automatiquement `build/**` à `analysis_options.yaml` lors de l'exécution des
commandes sur cette ancienne configuration. Cette modification générée a été
restaurée après vérification ; le futur lot analyzer doit rendre la
configuration courante explicite et le gate CI doit contrôler l'absence de
diff généré.

## Micro-probe des API futures

Un test temporaire, formaté puis supprimé, a compilé et exécuté les signatures
que le correctif utilisera :

- sous-classe composée de `TextScaler`, avec `scale`, égalité, `hashCode` et
  getter de compatibilité `textScaleFactor` ;
- `TextScaler.linear` et `TextScaler.noScaling` ;
- `Text(textScaler: ...)` et `TextPainter(textScaler: ...)` ;
- `MediaQuery.textScalerOf` ;
- `MediaQuery.maybeLineHeightScaleFactorOverrideOf`,
  `maybeLetterSpacingOverrideOf` et `maybeWordSpacingOverrideOf` ;
- champs `MediaQueryData.lineHeightScaleFactorOverride`,
  `letterSpacingOverride` et `wordSpacingOverride`.

Après chaque résolution avec le SDK correspondant, les commandes exactes ont
été :

```sh
/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --no-version-check --suppress-analytics \
  test test/sdk_floor_api_probe_test.dart --reporter expanded
/Users/mathieu/fvm/versions/3.41.6/bin/flutter \
  --no-version-check --suppress-analytics \
  test test/sdk_floor_api_probe_test.dart --reporter expanded
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --no-version-check --suppress-analytics \
  test test/sdk_floor_api_probe_test.dart --reporter expanded
```

Résultat sur les trois SDK :

```text
00:00 +0: SDK floor APIs should expose scaling and MediaQuery override APIs
00:00 +1: All tests passed!
```

Les sources officielles 3.41.0 confirment aussi les signatures :

- `TextScaler` expose déjà son constructeur constant, `linear`, `noScaling`,
  `scale` et le getter de compatibilité ;
- les trois propriétés de `MediaQueryData` sont des `double?` finales ;
- `Text.build` lit les trois méthodes `maybe...OverrideOf`, applique les
  overrides au span et fusionne la hauteur au `StrutStyle` avant de construire
  `RichText`.

Le helper récursif employé par `Text.build` est privé. Le plancher rend donc les
données publiques disponibles, mais le futur correctif doit encore prouver sa
propre transformation fidèle des spans et son absence de double application.

## Comparaison 3.41.0 / 3.41.6 / courante

| Critère | 3.41.0 | 3.41.6 | 3.47.2 |
|---|---:|---:|---:|
| SDK exact installé et exécuté | Oui | Oui, installation FVM existante | Oui |
| Résolution racine + exemple | Oui | Oui | Oui |
| Tests historiques | 23/23 | 23/23 | 23/23 |
| Micro-probe des API futures | 1/1 | 1/1 | 1/1 |
| Analyse ciblée baseline | 11 infos | 11 infos | 11 infos |
| Minimum technique | **Oui** | Oui, mais inutilement plus étroit | Non, entrée courante |

La preuve d'exécution rejoint donc la preuve historique des tags : 3.41.0 est
le premier seuil retenu qui contient tout le contrat moderne nécessaire. Aucun
motif technique ne justifie 3.41.6 comme politique de support.

## Gates exigés après implémentation

La présente baseline ne remplace pas les contrôles du futur diff. Avant de
fusionner le lot SDK puis chaque lot produit :

1. déclarer exactement Dart `>=3.11.0 <4.0.0` et Flutter `>=3.41.0` dans le
   package et l'exemple ;
2. épingler la CI sur **3.41.0** et **3.47.2** tant que 3.47.2 reste la stable
   courante officielle ; ne pas remplacer 3.41.0 par un patch 3.41.x ;
3. sur les deux entrées, exécuter `flutter pub get`,
   `flutter analyze --fatal-infos --fatal-warnings` et `flutter test` ;
4. sur 3.41.0, exécuter en plus `flutter pub downgrade`, puis
   `flutter test --no-pub` ;
5. résoudre et analyser l'exemple sur les deux entrées avec sa politique de
   lockfile finale ; tester la démo sur sa propre toolchain déclarée ;
6. conserver des régressions permanentes qui prouvent les trois overrides,
   scaling absent/linéaire/ambiant/non linéaire, strut, spans riches et égalité
   entre mesure et rendu ; le micro-probe de disponibilité n'est pas ce test
   produit ;
7. interdire tout shim `dynamic` de compatibilité et toute réduction d'un
   scaler non linéaire à un facteur moyen ;
8. vérifier `git diff --exit-code` après les commandes afin qu'aucun upgrade
   automatique d'options, lockfile ou artefact ne soit caché ;
9. formater avec la stable courante seulement, puis compiler, analyser et
   tester ce résultat sur le minimum exact.

Si la pin stable change avant fusion ou release, le manifeste officiel doit
être relu, la nouvelle version exacte installée et toute la seconde entrée
rejouée. Le minimum 3.41.0 ne change pas sans nouvelle décision de support.

## Sources et limites

Sources primaires :

- [manifeste officiel des releases macOS](https://storage.googleapis.com/flutter_infra_release/releases/releases_macos.json) ;
- [archive officielle Flutter](https://docs.flutter.dev/install/archive) ;
- [source `TextScaler` au tag 3.41.0](https://github.com/flutter/flutter/blob/3.41.0/packages/flutter/lib/src/painting/text_scaler.dart) ;
- [source `MediaQuery` au tag 3.41.0](https://github.com/flutter/flutter/blob/3.41.0/packages/flutter/lib/src/widgets/media_query.dart) ;
- [source `Text.build` au tag 3.41.0](https://github.com/flutter/flutter/blob/3.41.0/packages/flutter/lib/src/widgets/text.dart) ;
- [migration officielle de `textScaleFactor`](https://docs.flutter.dev/release/breaking-changes/deprecate-textscalefactor).

Limites :

- le `pubspec` n'a pas été modifié dans cette branche ; la résolution observée
  est celle de la baseline historique et doit être rejouée après le lot T1 ;
- le micro-probe établit la présence et la compatibilité de signature, pas la
  correction de layout, la composition RichText, les intrinsics ou les fuites ;
- l'analyse est volontairement rouge sur les dettes déjà auditées et ne peut
  devenir un gate vert qu'après les lots produit/analyzer/démo correspondants ;
- `flutter_lints`, le downgrade final, les lockfiles finaux, le build de la
  démo et le package dry-run ne faisaient pas partie de cette vérification
  sans changement produit ;
- les sockets localhost du runner et la résolution publique ont nécessité les
  permissions d'environnement adaptées, sans modifier le résultat technique.

Le probe, `.dart_tool`, `build` et les lockfiles générés ont été supprimés avant
le commit. Seul ce rapport est conservé.
