# Revue indépendante — lot 6 : modernisation de la démo

Date : 2026-09-01
Relecteur : Codex, revue indépendante D6
Parent imposé : `e9f75af9c3ef54bee2cbd3fcc0a53b44e7811968` (S1)
Candidat relu : `f88fb7d826785f637c7fccf95010252caac9d63d`
Candidat équivalent annoncé : `5c5d325243b0c0a0cdc6ea4e4a85807792b1265b`

## Verdict

**ACCEPTÉ**

Aucun finding actionnable n'a été identifié dans le périmètre D6.

Ce verdict accepte le contenu du lot, pas son intégration immédiate. Conformément à la roadmap corrigée, D6 reste une branche parallèle basée sur S1. Il ne doit pas être fusionné avant S9 et devra alors être revalidé sur l'API finale avant S10.

## Findings

Aucun.

Note informative, non bloquante : l'APK debug reproduit localement a le SHA-256 `4e82ad3d65a5d1c14213868562a456b62bee00ac4cc9d185242462deee1db3cc`, alors que le journal D6 consigne `6a3f0aa…`. Sa taille, son identité, ses SDK, son contenu et sa signature debug sont cohérents. Un APK debug local n'est pas présenté par le lot comme un artefact reproductible bit à bit ; cette différence de hash global ne constitue donc pas un défaut.

## Périmètre et méthode

La revue a suivi intégralement :

- le skill `developing-flutter`, ainsi que ses références `effective-dart.md` et `testing.md` ;
- le skill `find-bugs`, notamment l'inventaire exhaustif, la lecture intégrale des fichiers, la validation des tests par mutation et l'audit sécurité avant conclusion ;
- `maintenance/implementation-roadmap.md` et sa revue finale ;
- les audits et revues core, outillage et démo pertinents ;
- le journal `maintenance/implementation/lot-6-demo.md`.

Le diff relu est strictement `e9f75af...f88fb7d`. `git diff --check` ne signale rien. Les 41 chemins modifiés ont tous été lus intégralement ; les fichiers supprimés ont été lus depuis le parent, les PNG ont été inspectés par dimensions/hash et le JAR comme archive et par hash.

Les commits `f88fb7d` et `5c5d325` ont le même parent, le même message et le même arbre Git `21b532019fb1f27f476a4e40824c5f9d61300428`. Leur diff est vide : ils sont bien équivalents.

## Surface du changement

Le candidat modifie uniquement `demo/**` et ajoute le journal D6. Il ne modifie ni la bibliothèque racine, ni son `pubspec.yaml`, ni `example/`, ni les analyses/CI, ni les archives. Une comparaison explicite avec le parent sur `lib`, `pubspec.yaml`, `example`, `analysis_options.yaml`, `CHANGELOG.md` et `README.md` est vide.

Le lot contient 1 147 insertions et 420 suppressions. Il modernise la démo sans déplacer la politique de compatibilité de la bibliothèque racine.

## Comportements Flutter conservés

Les six écrans historiques sont toujours présents et joignables :

1. `MaxLinesDemo` ;
2. `MinFontSizeDemo` ;
3. `SyncDemo` / groupe ;
4. `StepGranularityDemo` ;
5. `PresetFontSizesDemo` ;
6. `OverflowReplacementDemo`.

Le contenu et les interactions propres à chaque démonstration sont conservés. Les changements Dart observés sont la mise au format actuel, l'emploi de `const`, la modernisation du shell Material et les corrections de cycle de vie prévues par le lot. Le réordonnancement de `child`/`replacement` dans `Visibility` ne change pas le comportement.

La navigation utilise une `NavigationBar` avec exactement six `NavigationDestination`, six libellés visibles et des icônes Material. L'index sélectionné pilote bien le corps affiché.

Une vérification sémantique temporaire, exécutée hors branche, confirme le rôle de barre d'onglets, un rôle d'onglet par destination, les libellés `Tab n of 6`, les actions de tap/focus et l'état sélectionné. L'accessibilité de base de la navigation est donc présente sans couche sémantique artisanale inutile.

Les appels `SystemChrome` ne sont plus dans `build`. `main` initialise le binding, attend l'orientation paysage et le mode immersif courant, puis appelle `runApp`. Ces effets globaux ne sont ainsi pas rejoués à chaque reconstruction.

Dans la démonstration synchronisée :

- le `AutoSizeGroup` est un champ `final` stable du `State` ;
- les variantes normale et riche partagent la même instance ;
- le callback différé vérifie `mounted` avant de relancer l'animation.

## Qualité des tests

`demo/test/demo_smoke_test.dart` contient quatre tests nommés avec `should`, regroupés par comportement :

- présence des six destinations et ouverture effective de chacun des six écrans ;
- bascule de la variante normale vers un véritable `AutoSizeText.rich` ;
- progression de l'animation et stabilité d'identité du groupe ;
- fin d'animation, destruction du widget et callback différé sans exception.

Les tests ne se limitent pas à l'absence de crash : ils vérifient widgets, textes, types et identités attendus. Leur capacité à détecter les deux régressions critiques a été démontrée dans des clones temporaires hors branche :

- recréer le groupe dans `build` fait échouer le test d'identité ;
- supprimer la garde `mounted` fait échouer le test de destruction avec un appel de contrôleur après `dispose`.

Les deux autres tests ont également des assertions directes sur le routage exact et la construction riche ; un écran manquant/mal câblé ou une fausse bascule riche les ferait échouer.

## Comparaison au template Android Flutter 3.47.2

Un projet témoin a été généré avec le bundle exact :

```text
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter create \
  --no-pub \
  --platforms=android \
  --project-name demo \
  --org com.github.leisim.auto_size_text \
  --android-language kotlin \
  <répertoire temporaire>
```

Le bundle annonce Flutter 3.47.2, révision `d3b14c876900e553bc736ca19295fc09e3853e8e`, moteur `1cf1c477…`, Dart 3.13.2 et DevTools 2.60.0.

La comparaison récursive de `demo/android` avec ce témoin ne laisse que :

- le label applicatif historique volontairement conservé, `AutoSizeText Demo` au lieu de `demo` ;
- les fichiers du wrapper volontairement régénérés pour Gradle 9.3.1 ;
- l'absence souhaitée des fichiers locaux non versionnables `local.properties` et `demo_android.iml`.

Tous les autres fichiers texte Android et les cinq icônes PNG sont identiques au template exact.

### Configuration vérifiée

| Élément | Résultat |
|---|---|
| Embedding Flutter | v2, `io.flutter.embedding.android.FlutterActivity`, métadonnée `flutterEmbedding=2`, aucun enregistrement manuel |
| Scripts | Kotlin DSL, Plugin DSL moderne |
| Loader Flutter | `dev.flutter.flutter-plugin-loader` 1.0.0 |
| Plugin Flutter app | `dev.flutter.flutter-gradle-plugin`, appliqué après Android |
| AGP | 9.1.0 |
| Kotlin | 2.4.0 |
| Gradle | 9.3.1 |
| Java/Kotlin cible | JVM 17 |
| JDK du bundle | Android Studio JDK 21.0.10 vu par `flutter doctor -v`, compatible avec la chaîne |
| Dépôts | `google()`, `mavenCentral()`, `gradlePluginPortal()` seulement |
| Namespace | `com.github.leisim.auto_size_text.demo` |
| Application ID | `com.github.leisim.auto_size_text.demo` |
| compileSdk / targetSdk | 36 / 36 |
| minSdk | 24 |
| NDK | 28.2.13676358 via la valeur Flutter 3.47.2 |
| Version | code 2, nom 1.0.0, issus du pubspec |

Le manifeste principal conserve l'activité launcher exportée, le thème normal, les `configChanges` actuels, `taskAffinity=""` et la requête `PROCESS_TEXT`. Il ne demande aucune permission. `INTERNET` n'est présent que dans les variantes debug/profile du template. L'APK debug ne contient en plus que la permission interne de receiver dynamique AndroidX attendue.

Le bloc release reprend le template officiel : il emploie provisoirement la signature debug pour permettre `flutter run --release`. Aucun keystore de publication, `key.properties`, certificat ou secret n'est versionné.

Il n'existe aucun plugin Pub natif. Le `GeneratedPluginRegistrant` produit au build a une méthode d'enregistrement vide et reste généré/ignoré. `.flutter-plugins-dependencies` est absent. Les bibliothèques natives de l'APK sont celles du moteur Flutter et de la validation debug.

## Wrapper Gradle et fichiers binaires

Le wrapper est cohérent avec Gradle 9.3.1 :

- URL : `https://services.gradle.org/distributions/gradle-9.3.1-all.zip` ;
- validation d'URL activée et délai réseau fixé ;
- SHA-256 distribution : `17f277867f6914d61b1aa02efab1ba7bb439ad652ca485cd8ca6842fccec6e43` ;
- SHA-256 JAR : `b3a875ddc1f044746e1b1a55f645584505f4a10438c1afea9f15e92a7c42ec13`.

Ces deux valeurs correspondent à la page officielle [Gradle release checksums](https://gradle.org/release-checksums/) pour 9.3.1. Le JAR versionné, valide comme ZIP, est identique à la ressource `gradle-wrapper.jar` de la distribution officielle. Une régénération indépendante avec Gradle 9.3.1 donne des fichiers Unix et propriétés identiques octet pour octet ; le `.bat` ne diffère que par la normalisation CRLF → LF documentée dans le journal.

Les cinq PNG sont des images valides aux dimensions attendues (48, 72, 96, 144 et 192 px), avec les mêmes tailles et SHA-256 que le template Flutter 3.47.2.

## Contrat de version de la démo

`demo/pubspec.yaml` exige honnêtement :

```yaml
environment:
  sdk: '>=3.13.2 <4.0.0'
  flutter: '>=3.47.2'
```

Ces minima correspondent exactement au bundle de génération et à l'API utilisée. Ils sont limités à la démo. Le package racine n'est pas modifié et ne prétend pas relever son propre minimum.

`.metadata` porte la révision stable exacte Flutter 3.47.2 et déclare uniquement `lib/main.dart` comme fichier utilisateur non géré. L'omission d'une entrée iOS du témoin est normale : ce lot ne crée que la plateforme Android et ne prétend pas régénérer iOS.

## Reproduction des validations

Toutes les commandes Flutter/Dart ont utilisé exclusivement `/private/tmp/flutter-sdk-3.47.2/flutter/bin`. Les validations finales sont :

| Validation | Résultat |
|---|---|
| `flutter pub get --enforce-lockfile` dans `demo/` | succès |
| SHA-256 de `pubspec.lock` avant/après | inchangé : `a33b1dd565ee362192f89e445a471e6110ec619195bc595a2c84c6f3bf1c98fb` |
| `dart format --output=none --set-exit-if-changed lib test` | succès, 11 fichiers, 0 changement |
| `flutter analyze --no-pub --fatal-infos --fatal-warnings` | succès, aucune issue |
| `flutter test --no-pub --reporter expanded` | succès, 4/4 tests |
| `flutter build apk --debug --no-pub` | succès |
| `git diff --check` | succès |
| état Git après validation | propre |

L'APK produit mesure 150 330 646 octets, soit environ 143,4 Mio, cohérent avec les 143 Mio du journal. `aapt` confirme le package, la version, les SDK et le label attendus. `apksigner verify` confirme une signature APK v2 avec un certificat Android Debug RSA 2048, sans clé de publication.

Après les validations, aucun `local.properties`, `key.properties`, keystore, JKS, `.iml`, `GeneratedPluginRegistrant.java` ni `.flutter-plugins-dependencies` n'est présent dans l'arbre de travail. Les artefacts de build restent ignorés et aucun fichier généré indésirable n'est suivi.

## Sécurité et chaîne d'approvisionnement

L'inspection du diff et des fichiers complets conclut :

- aucun secret, jeton, clé privée, identifiant ou URL authentifiée ;
- aucun `local.properties`, keystore ou configuration de signature de production ;
- aucun dépôt Maven tiers, `jcenter`, téléchargement ad hoc, pipe réseau vers un shell ou dépendance Git ;
- wrapper Gradle épinglé par checksum officiel ;
- lockfile Pub versionné avec checksums hébergés officiels ;
- dépendances directes minimales : SDK Flutter et package local en production, `flutter_test` et `flutter_lints` en développement ;
- aucune permission sensible, persistance, saisie utilisateur, authentification, autorisation ou accès réseau applicatif ajouté.

Checklist `find-bugs` :

- injection SQL/commande : non applicable, aucun interpréteur, base ou commande alimentée par l'utilisateur ;
- XSS : non applicable, aucune surface Web/HTML ;
- authentification, autorisation, IDOR, session, CSRF : non applicables ;
- race/TOCTOU : aucun accès partagé externe ; le seul callback différé sensible est protégé par `mounted` ;
- cryptographie : aucune cryptographie applicative ; signature debug standard seulement ;
- divulgation d'information : aucun secret, log sensible ou chemin local suivi ;
- déni de service : aucune boucle, entrée non bornée ou ressource externe ajoutée ;
- logique métier : les six démonstrations et leurs interactions sont couvertes ;
- supply chain : versions, dépôts, lockfile, wrapper et checksums vérifiés.

## Inventaire exhaustif des 41 chemins relus

1. `demo/.gitignore`
2. `demo/.metadata`
3. `demo/android/.gitignore`
4. `demo/android/app/build.gradle` (supprimé, lu depuis le parent)
5. `demo/android/app/build.gradle.kts`
6. `demo/android/app/src/debug/AndroidManifest.xml`
7. `demo/android/app/src/main/AndroidManifest.xml`
8. `demo/android/app/src/main/java/com/github/leisim/auto_size_text/demo/MainActivity.java` (supprimé, lu depuis le parent)
9. `demo/android/app/src/main/kotlin/com/github/leisim/auto_size_text/demo/MainActivity.kt`
10. `demo/android/app/src/main/res/drawable-v21/launch_background.xml`
11. `demo/android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
12. `demo/android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
13. `demo/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
14. `demo/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` (renommage exact de l'ancienne ressource drawable)
15. `demo/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
16. `demo/android/app/src/main/res/values-night/styles.xml`
17. `demo/android/app/src/main/res/values/styles.xml`
18. `demo/android/app/src/profile/AndroidManifest.xml`
19. `demo/android/build.gradle` (supprimé, lu depuis le parent)
20. `demo/android/build.gradle.kts`
21. `demo/android/gradle.properties`
22. `demo/android/gradle/wrapper/gradle-wrapper.jar`
23. `demo/android/gradle/wrapper/gradle-wrapper.properties`
24. `demo/android/gradlew`
25. `demo/android/gradlew.bat`
26. `demo/android/settings.gradle` (supprimé, lu depuis le parent)
27. `demo/android/settings.gradle.kts`
28. `demo/lib/animated_input.dart`
29. `demo/lib/main.dart`
30. `demo/lib/max_lines_demo.dart`
31. `demo/lib/min_font_size_demo.dart`
32. `demo/lib/overflow_replacement_demo.dart`
33. `demo/lib/preset_font_sizes_demo.dart`
34. `demo/lib/step_granularity.dart`
35. `demo/lib/sync_demo.dart`
36. `demo/lib/text_card.dart`
37. `demo/lib/utils.dart`
38. `demo/pubspec.lock`
39. `demo/pubspec.yaml`
40. `demo/test/demo_smoke_test.dart`
41. `maintenance/implementation/lot-6-demo.md`

## Limites explicites

La revue n'a pas exécuté l'application sur un appareil physique ni réalisé de golden test visuel ; ce n'est pas requis pour le lot et les comportements structurants ont été couverts par tests widget, sémantique temporaire et inspection. Aucun APK release n'a été construit, le livrable demandé étant l'APK debug. Le script Windows n'a pas été exécuté sur Windows ; sa seule différence avec la régénération officielle est la terminaison de ligne documentée.

Enfin, la compatibilité de D6 avec les changements d'API qui seront intégrés jusqu'à S9 n'est, par construction, pas vérifiable sur ce parent S1. C'est pourquoi l'acceptation présente n'autorise pas une fusion anticipée et la revalidation finale reste obligatoire.
