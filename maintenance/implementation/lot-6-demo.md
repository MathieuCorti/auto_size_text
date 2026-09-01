# Lot 6 — Exemple avancé et démo moderne

Date : 2026-09-01

Branche : `codex/impl-demo`

Parent exact : `e9f75af9c3ef54bee2cbd3fcc0a53b44e7811968`

Tête : commit contenant ce journal ; SHA final communiqué dans le compte rendu

Cette tête reste la piste parallèle `D6`. Elle ne doit pas être fusionnée dans
la piste d'intégration avant `S9` et devra être revalidée sur l'API finale avant
l'union `S10`.

## Périmètre livré

- application de démo résoluble avec Flutter `3.47.2` / Dart `3.13.2`, seule
  toolchain sur laquelle ce lot promet et vérifie son scaffold ;
- dépendances visuelles historiques supprimées, `NavigationBar` et icônes
  Material de Flutter utilisées sans package tiers ;
- six destinations conservées : `MaxLines`, `MinFontSize`, `Group`,
  `StepGranularity`, `PresetFontSizes` et `OverflowReplacement` ;
- bascule texte simple / `RichText` conservée ;
- configuration d'orientation et d'interface système déplacée hors de `build`,
  dans l'initialisation asynchrone de `main`, avec
  `SystemUiMode.immersiveSticky` ;
- groupe de synchronisation privé, final et stable entre les frames, avec
  vérification de `mounted` avant le redémarrage différé ;
- scaffold Android neuf, généré par la pin de démo, et smoke tests de la
  navigation et du cycle de vie.

Hors périmètre : `lib/**` et pubspec racine, `example/**`, CI, archive,
documentation/version et toute plateforme autre qu'Android.

## Toolchain et scaffold Android

Bundle exécuté :
`/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter`.

```text
Flutter 3.47.2 • revision d3b14c8769
Engine 1cf1c4773fb941c4c74a7f8bb144a8837596c0f4
Dart 3.13.2 • DevTools 2.60.0
```

Le lien local FVM `stable` pointait encore sur Flutter `3.27.1` et n'a pas été
utilisé. Le manifeste de la démo déclare donc honnêtement Dart
`>=3.13.2 <4.0.0` et Flutter `>=3.47.2`. Aucune compatibilité avec une version
Flutter inférieure n'est revendiquée par ce lot.

Le scaffold a été créé à neuf dans un répertoire temporaire, puis seuls
`demo/android/**` et les métadonnées autorisées ont été transplantés :

```sh
flutter create --no-pub --platforms=android \
  --project-name demo \
  --org com.github.leisim.auto_size_text \
  --android-language kotlin \
  /private/tmp/ast-demo-scaffold.9O1UYE
```

Résultat généré : embedding v2, `MainActivity.kt`, Plugin DSL Kotlin, AGP
`9.1.0`, Kotlin `2.4.0`, Gradle `9.3.1`, Java 17, `google()` et
`mavenCentral()`. `compileSdk`, `targetSdk`, `minSdk` et NDK sont délégués aux
niveaux supportés par Flutter `3.47.2` au lieu d'être figés sur les anciennes
API 16/27.

Le wrapper copié par le template a ensuite été régénéré par Gradle, pas édité
depuis l'ancien wrapper :

```sh
./gradlew wrapper --gradle-version 9.3.1 --distribution-type all \
  --gradle-distribution-sha256-sum \
  17f277867f6914d61b1aa02efab1ba7bb439ad652ca485cd8ca6842fccec6e43
```

- SHA-256 officiel de `gradle-9.3.1-all.zip` :
  `17f277867f6914d61b1aa02efab1ba7bb439ad652ca485cd8ca6842fccec6e43` ;
- SHA-256 du JAR wrapper régénéré, conforme à la référence Gradle 9.3.1 :
  `b3a875ddc1f044746e1b1a55f645584505f4a10438c1afea9f15e92a7c42ec13`.

Aucun `local.properties`, `key.properties`, keystore ou JKS n'est suivi. Le
`local.properties` local produit pour le build a été supprimé après validation.

## Preuve rouge sur le parent

Sur le parent exact et Flutter 3.47.2 :

```sh
cd demo
flutter pub get
```

Échec attendu du solveur : `bottom_navy_bar >=0.1.1
<6.0.0-nullsafety.0` ne supporte pas la null safety. Cette commande établit la
régression réelle corrigée par le lot, sans attribuer le rouge à un défaut
antérieur sans rapport.

## Tests ajoutés

`demo/test/demo_smoke_test.dart` contient deux groupes et quatre tests dont les
noms commencent tous par « should » :

- ouvre réellement chacune des six destinations et vérifie le widget/titre ;
- bascule de texte normal vers le constructeur `AutoSizeText.rich` ;
- vérifie que l'animation avance tout en conservant la même instance de groupe
  pour les deux membres ;
- termine l'animation, démonte `SyncDemo` avant le délai de trois secondes,
  exécute le callback différé et vérifie l'absence d'exception.

Les deux derniers tests auraient échoué sur le parent : le groupe y était
recréé à chaque `build` et le contrôleur redémarré après son `dispose`.

## Validation verte

Toutes les commandes ci-dessous ont été exécutées avec Flutter `3.47.2` / Dart
`3.13.2` depuis `demo/` :

| Commande | Résultat |
|---|---|
| `flutter pub get --enforce-lockfile` | Succès ; SHA-256 du lock inchangé : `a33b1dd565ee362192f89e445a471e6110ec619195bc595a2c84c6f3bf1c98fb`. |
| `dart format --output=none --set-exit-if-changed lib test` | Succès ; aucun fichier à reformater. |
| `flutter analyze --no-pub --fatal-infos --fatal-warnings` | Succès ; aucun diagnostic. |
| `flutter test --no-pub --reporter expanded` | Succès ; 4/4 tests. |
| `flutter build apk --debug --no-pub` | Succès ; `build/app/outputs/flutter-apk/app-debug.apk`. |
| `git diff --check` | Succès après normalisation LF du script Windows généré. |

APK debug : 143 Mio, SHA-256
`6a3f0aa6afd54f77eb21f5f316a90787226287e7fb207edd5c01f565b6812c65`.

Le manifeste Pub ne contient comme dépendances runtime directes que Flutter et
le package local `auto_size_text`. Le `GeneratedPluginRegistrant.java` produit
pendant le build a une méthode `registerWith` vide : aucun plugin ou dépendance
native accidentelle n'a été introduit.

## Fichiers et contrôle de surface

- manifests/lock : `demo/pubspec.yaml`, `demo/pubspec.lock`,
  `demo/.metadata`, `demo/.gitignore` ;
- code : les dix fichiers existants de `demo/lib/**` ;
- tests : `demo/test/demo_smoke_test.dart` ;
- Android : remplacement complet de l'ancien scaffold Groovy/Java v1 par les
  fichiers générés de `demo/android/**` ;
- journal : `maintenance/implementation/lot-6-demo.md`.

Le contrôle `git diff --name-only
e9f75af9c3ef54bee2cbd3fcc0a53b44e7811968...HEAD` doit rester strictement
dans cette allowlist. Aucun `lib/**` racine, pubspec racine, fichier d'exemple,
CI, archive, documentation de version ou fichier secret/local n'appartient à
ce lot.

## Risques et revue attendue

- le diff Android est volontairement large car il remplace un scaffold de 2017
  par le template exact de Flutter 3.47.2 ;
- le minimum de la démo est plus haut que celui du package public et ne doit pas
  être confondu avec la matrice de compatibilité de la bibliothèque ;
- l'APK debug courant est volumineux, notamment à cause des bibliothèques moteur
  et de validation du build debug ; ce n'est pas une dépendance Pub ajoutée ;
- la revue indépendante Flutter/Android et la revalidation de compatibilité sur
  `S9` restent obligatoires avant l'union `S10`.

Aucun merge, push, tag, publication ni mutation distante n'est effectué par ce
lot.
