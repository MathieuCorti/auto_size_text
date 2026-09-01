# Audit du cœur `auto_size_text`

Date : 2026-09-01

Référence auditée : `master` / `f22397751271605ac46e8740d9e48ed631a74cb0`

Branche du rapport : `codex/audit-core`

Périmètre : package Flutter, tests, exemple minimal, démo et outillage qui
conditionne leur validation. Aucun code produit n'a été modifié.

## Synthèse

Le cœur historique reste fonctionnel pour les cas couverts : les 23 tests
existants passent sur Flutter 3.35.3 et 3.44.0, et la couverture de lignes est
de 98,7 %. Cette couverture est trompeuse sur les variantes de comportement :
neuf reproductions ciblées supplémentaires ont confirmé des défauts absents de
la suite.

Les risques prioritaires sont :

1. `AutoSizeText.rich` plante dès qu'un `WidgetSpan` est présent ;
2. la mise à l'échelle moderne `TextScaler`, notamment non linéaire, est perdue ;
3. la mesure ne reproduit pas plusieurs réglages appliqués au rendu
   (`softWrap`, `MediaQuery.boldText`, héritage de style RichText) ;
4. un groupe peut rendre un membre sous son `minFontSize` ou hors de ses tailles
   prédéfinies ;
5. la recherche discrète rejette des décimaux valides en debug et peut passer
   sous le minimum en release ;
6. la démo publiée n'est plus résoluble avec Dart moderne et la CI ne peut plus
   exécuter son étape de formatage.

Aucune vulnérabilité de sécurité classique n'a été trouvée. La surface exposée
est une API de widgets en mémoire, sans réseau, stockage, authentification,
cryptographie ni traitement de secrets.

## Environnement, commandes et résultats

### État initial

```text
pwd
# /private/tmp/auto-size-text-audit-core

git status --short --branch
# ## codex/audit-core

git rev-parse HEAD
# f22397751271605ac46e8740d9e48ed631a74cb0
```

Hôte : macOS arm64, fuseau `Asia/Bangkok`.

### SDK de référence local

```text
fvm flutter --version
# Flutter 3.35.3 stable, Dart 3.9.2, DevTools 2.48.0

/Users/mathieu/fvm/versions/3.44.0/bin/flutter --version
# Flutter 3.44.0 stable, Dart 3.12.0, DevTools 2.57.0
```

### Résolution, analyse et tests

| Commande | Résultat |
|---|---|
| `fvm flutter pub get` | Succès. `pedantic 1.11.1` est signalé comme abandonné. L'exemple minimal est également résolu. |
| `fvm flutter analyze` | Échec, 27 diagnostics : 12 erreurs provenant de la démo non résolue/obsolète et 15 informations. |
| `fvm flutter analyze lib test example/main.dart` | Échec, 11 informations : 6 usages produit de `textScaleFactor`/`textScaleFactorOf`, 3 usages équivalents dans les tests et 2 imports inutiles. |
| `fvm flutter test` | Succès, 23 tests, Flutter 3.35.3. |
| `flutter 3.44.0 pub get` | Succès pour le package et l'exemple minimal. |
| `flutter 3.44.0 analyze lib test example/main.dart` | Échec, les mêmes 11 informations. |
| `flutter 3.44.0 test` | Succès, 23 tests. |
| `flutter 3.44.0 test --coverage` | Succès, 154/156 lignes produit, soit 98,7 %. Seules les lignes 235-236 de `auto_size_text.dart` (changement de groupe) ne sont pas exécutées. |
| `cd demo && fvm flutter pub get` | Échec du solveur : `bottom_navy_bar >=0.1.1 <6.0.0-nullsafety.0` n'est pas null-safe. |
| `dart 3.12.0 format --output=none --set-exit-if-changed lib test example demo/lib` | Deux fichiers différeraient du format moderne (`auto_size_group_builder.dart`, `group_builder_test.dart`) ; l'inclusion de `pedantic` a aussi produit un avertissement de résolution. Aucun fichier n'a été écrit. |
| `dart 3.12.0 pub publish --dry-run` | 0 avertissement, 1 indication : `>=2.12.0 <3.0.0` est interprété comme `<4.0.0` et devrait être explicité. L'archive inclut la démo cassée. |

La commande CI actuelle
`flutter/bin/cache/dart-sdk/bin/dartfmt` ne peut pas fonctionner sur Flutter
3.44.0 : le binaire `dartfmt` n'existe plus.

### Reproductions ciblées temporaires

Un fichier de test temporaire, supprimé après exécution, a exercé neuf cas sur
Flutter 3.44.0. Les attentes étaient des témoins du défaut observé, donc leur
succès confirme les reproductions :

```text
softWrap false should size against unwrapped width                 PASS
group should not render a member below its minFontSize             PASS
rich root style should inherit sizing style during measurement     PASS
rich wrapWords false should measure styled child words             PASS
WidgetSpan dimensions should participate in measurement            PASS
ambient nonlinear TextScaler should not be reduced to a factor     PASS
ambient boldText should participate in measurement                 PASS
decimal minFontSize multiple should not fail validation            PASS
zero reference font size should not bypass fit measurement         PASS
```

Le cas `WidgetSpan` attendait et a reçu l'assertion Flutter
`widget_span.dart: dimensions != null`, dont la pile remonte à
`_checkTextFits` ligne 406.

## Inventaire des fichiers lus intégralement

### Code produit

- `lib/auto_size_text.dart`
- `lib/src/auto_size_text.dart`
- `lib/src/auto_size_group.dart`
- `lib/src/auto_size_group_builder.dart`

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

### Exemple minimal et démo Dart

- `example/pubspec.yaml`
- `example/main.dart`
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

### Configuration, documentation et plateforme pertinentes

- `pubspec.yaml`
- `analysis_options.yaml`
- `README.md`
- `CHANGELOG.md`
- `LICENSE`
- `.gitignore`
- `.github/workflows/dart.yml`
- `.github/FUNDING.yml`
- `.github/no-response.yml`
- `demo/.metadata`
- `demo/.gitignore`
- `demo/android/.gitignore`
- `demo/android/settings.gradle`
- `demo/android/gradle.properties`
- `demo/android/build.gradle`
- `demo/android/gradle/wrapper/gradle-wrapper.properties`
- `demo/android/app/build.gradle`
- `demo/android/app/src/main/AndroidManifest.xml`
- `demo/android/app/src/main/java/com/github/leisim/auto_size_text/demo/MainActivity.java`
- `demo/android/app/src/main/res/values/styles.xml`
- `demo/android/app/src/main/res/drawable/launch_background.xml`

Les GIF/PNG/JAR binaires, scripts Gradle générés et modèles d'issues GitHub
n'ont pas été lus : ils n'affectent ni l'algorithme du package ni les chemins
de build diagnostiqués. Les implémentations Flutter 3.35/3.44 pertinentes de
`Text`, `TextPainter`, `RenderParagraph`, `MediaQuery` et `TextScaler` ont été
consultées aux points nécessaires pour comparer mesure et rendu.

## Architecture et invariants

### Flux principal

1. `AutoSizeText` est un `StatefulWidget` qui s'enregistre éventuellement dans
   un `AutoSizeGroup`.
2. `LayoutBuilder` fournit les contraintes maximales disponibles.
3. Le style explicite est fusionné avec `DefaultTextStyle`; une taille de 14 est
   injectée si `fontSize` est nul.
4. `_calculateFontSize` construit un `TextSpan`, résout une échelle utilisateur,
   puis recherche par dichotomie la plus grande taille qui passe
   `_checkTextFits`.
5. `_checkTextFits` crée un `TextPainter`; avec `wrapWords == false`, un second
   painter vérifie chaque mot sur une ligne artificielle.
6. Sans groupe, la taille trouvée est rendue. Avec groupe, le minimum publié par
   le groupe est rendu et les membres sont notifiés par microtâche.
7. Si la taille minimale ne suffit pas, `overflowReplacement` remplace le texte ;
   sinon le `Text` final applique `overflow`.

### Invariants attendus

- Mesure et rendu doivent utiliser exactement le même arbre de spans, le même
  style effectif, la même stratégie de wrap et la même mise à l'échelle.
- La taille retournée doit appartenir à `[minFontSize, maxFontSize]`, ou à
  `presetFontSizes` lorsque cette liste est fournie.
- `stepGranularity` définit des candidats discrets sans jamais autoriser une
  taille sous le minimum.
- `maxLines`, largeur et hauteur doivent tous être respectés.
- `wrapWords == false` interdit de couper un mot pour déclarer qu'il tient.
- Un groupe partage une taille quand les contraintes de chaque membre le
  permettent ; il ne doit pas violer les minima ou presets individuels.
- La mise à l'échelle d'accessibilité utilisée pour mesurer doit être celle
  utilisée pour rendre.
- Un changement de widget/groupe doit désenregistrer l'ancien état et ne pas
  notifier un état démonté.

Les findings ci-dessous correspondent aux violations confirmées de ces
invariants.

## Findings priorisés

### CORE-01 — Haute — `WidgetSpan` fait planter `AutoSizeText.rich`

**Emplacement :** `lib/src/auto_size_text.dart:310-315`,
`lib/src/auto_size_text.dart:396-406`.

**Problème.** Le constructeur public accepte un `TextSpan` dont les enfants
peuvent être des `WidgetSpan`. Le `TextPainter` de mesure reçoit ces spans sans
`PlaceholderDimensions`. Flutter exige ces dimensions au moment de construire
le paragraphe.

**Preuve/reproduction.** Dans un `SizedBox`, construire
`AutoSizeText.rich(TextSpan(children: [WidgetSpan(child: SizedBox(...)),
TextSpan(text: 'XXXXX')]))`. Sur Flutter 3.44.0, le build lève
`'widget_span.dart': 'dimensions != null'` depuis
`_AutoSizeTextState._checkTextFits` ligne 406, avant de produire un `Text`.
La suite existante ne contient aucun `WidgetSpan`.

**Impact.** Crash immédiat d'un usage pourtant accepté par le type public et
présenté comme équivalent à `Text.rich`; impossible de protéger cet usage avec
`overflowReplacement`.

**Correction minimale.** Choisir explicitement un contrat :

- soit mesurer les placeholders réels via une implémentation de layout capable
  de fournir les `PlaceholderDimensions` à chaque candidat ;
- soit, en attendant ce support, détecter tout `WidgetSpan` et produire une
  erreur API claire et déterministe également en release, avec documentation.

**Tests de régression.** Un `WidgetSpan` de largeur/hauteur fixes seul, puis avec
du texte, sous contraintes de largeur et de hauteur; vérifier taille choisie,
absence d'exception et remplacement en cas d'impossibilité.

### CORE-02 — Haute — `TextScaler` non linéaire est remplacé par un facteur linéaire

**Emplacement :** `lib/src/auto_size_text.dart:32`, `:57`, `:179-189`,
`:317-318`, `:382`, `:400`, `:425`, `:440`.

**Problème.** L'API ne propose que `double? textScaleFactor`. En l'absence de
valeur explicite, elle lit le getter déprécié
`MediaQuery.textScaleFactorOf`, multiplie les tailles elle-même, puis force le
`Text` final à l'échelle linéaire 1 (ou à un ratio linéaire pour RichText). Or
`TextScaler.textScaleFactor` n'est qu'une estimation de compatibilité et ne
représente pas une courbe non linéaire.

**Preuve/reproduction.** Avec un `TextScaler` de test tel que
`scale(30) == 36` mais `textScaleFactor == 2`, un texte de référence 30 est
rendu par ce package à une taille effective 60 au lieu de 36. Les analyseurs
Flutter 3.35 et 3.44 signalent les six usages produit comme dépréciés.

**Impact.** Taille et décision de fit incorrectes avec les réglages
d'accessibilité modernes, particulièrement pour RichText dont les tailles de
spans devraient être transformées différemment. Risque d'overflow, de texte
inutilement petit/grand, de remplacement erroné et de rupture lors de la
suppression future des anciennes API.

**Correction minimale.** Ajouter `TextScaler? textScaler` avec la même priorité
que `Text` (scaler explicite, sinon ancien facteur converti en scaler linéaire,
sinon scaler ambiant). Utiliser un même scaler effectif, composé avec le ratio
d'auto-size, dans tous les `TextPainter` et dans le `Text` final; ne pas le
réduire à son getter de compatibilité.

**Tests de régression.** Scaler linéaire et scaler de test non linéaire, texte
simple et spans de tailles différentes, changement de `MediaQuery` entre deux
frames, limites min/max et presets sous scaling.

### CORE-03 — Haute — La mesure n'applique pas le même wrap/style d'accessibilité que le rendu

**Emplacement :** `lib/src/auto_size_text.dart:242-255`,
`lib/src/auto_size_text.dart:370-410`, `lib/src/auto_size_text.dart:413-443`.

**Problème.** `_checkTextFits` fait toujours
`textPainter.layout(maxWidth: constraints.maxWidth)` et ne connaît pas
`softWrap`. Le `Text` final reçoit pourtant `softWrap`, y compris sa valeur
héritée de `DefaultTextStyle`. De plus, le style mesuré n'intègre pas
`MediaQuery.boldTextOf(context)`, alors que `Text.build` met le rendu en gras.

**Preuves/reproductions.**

- Dans une boîte 100×100, `softWrap: false` avec
  `XXXXX XXXXX XXXXX` choisit 19. Le painter non wrappé du texte final dépasse
  100 : le calcul l'avait autorisé à revenir à la ligne.
- Avec deux fontes Roboto locales, une largeur placée entre la métrique normale
  et la métrique bold et `MediaQueryData(boldText: true)`, le package conserve
  30 parce qu'il mesure la fonte normale, tandis que la fonte réellement
  rendue dépasse la largeur.

**Impact.** Overflow visuel malgré une réponse `textFits == true`,
`overflowReplacement` non affiché, et comportement incorrect précisément avec
un réglage d'accessibilité. Le même écart existe quand `softWrap: false` vient
du `DefaultTextStyle`.

**Correction minimale.** Construire une configuration effective unique avant
la recherche, identique à celle de `Text.build` : style avec bold ambiant,
`softWrap` et `overflow` résolus. Pour la mesure, utiliser une largeur infinie
quand le rendu ne wrappe pas (sauf le cas ellipsis géré par Flutter), puis
comparer la largeur obtenue à la contrainte.

**Tests de régression.** `softWrap` explicite et hérité, avec/sans ellipsis,
`overflowReplacement`, `boldText` avec une fonte dont les métriques changent,
et bascule de ces valeurs entre deux pumps.

### CORE-04 — Haute — La mesure RichText ne reproduit ni l'héritage ni les styles des mots

**Emplacement :** `lib/src/auto_size_text.dart:308-315`,
`lib/src/auto_size_text.dart:372-386`, `lib/src/auto_size_text.dart:429-441`.

**Problème.** Pour mesurer, le code remplace le style parent par
`widget.textSpan?.style ?? style` et copie seulement quelques champs du span.
Pour rendre, `Text.rich` place au contraire le span original sous le style de
`AutoSizeText`. Le painter spécial de `wrapWords == false` a un second défaut :
il aplatit tout en chaîne et applique uniquement le style racine, perdant les
styles des enfants.

**Preuves/reproductions.**

- Un style parent à 30 et un span racine ne définissant que `fontWeight` sont
  déclarés ajustés à 30 dans une largeur de 100; le span correctement imbriqué
  dépasse 100.
- Avec `wrapWords: false`, un enfant à 100 sous une référence à 20 reste plus
  large que la boîte parce que le contrôle mot-par-mot l'a mesuré à 20; le
  painter général autorise ensuite la coupure du mot.

**Impact.** Taille trop grande ou trop petite, mots coupés malgré
`wrapWords: false`, overflow ou remplacement incorrect. Les spans comportant
font family, weight, height ou letter spacing sont concernés.

**Correction minimale.** Fabriquer le span de mesure comme `Text` : un parent
portant le style effectif et le contenu simple, ou le span RichText original
comme enfant intact. Pour `wrapWords: false`, préserver les runs stylés lors de
la vérification des mots au lieu de reconstruire un span monostyle.

**Tests de régression.** Span racine partiellement stylé, enfants imbriqués de
tailles/weights/familles différents, recognizer et semantics conservés, mots
stylés avec `wrapWords: false`, puis équivalence des métriques painter/rendu.

### CORE-05 — Moyenne — Un groupe contourne les contraintes individuelles

**Emplacement :** `lib/src/auto_size_text.dart:257-267`,
`lib/src/auto_size_group.dart:13-31`.

**Problème.** Chaque membre calcule une taille valide, mais la ligne 265 rend
ensuite directement `group._fontSize`. Aucun clamp n'est refait pour le membre.
Le minimum du groupe peut donc être inférieur au `minFontSize` d'un autre
membre. De même, avec des listes de presets différentes, la taille d'un autre
membre peut ne pas appartenir à la liste autorisée.

**Preuve/reproduction.** Deux membres partagent un groupe : le premier, étroit,
a `minFontSize: 10`; le second a `minFontSize: 20`. La taille publiée par le
premier est appliquée au second, qui est observé sous 20. Les tests actuels
utilisent toujours les mêmes minima, styles et granularités.

**Impact.** Texte sous la limite de lisibilité choisie par l'appelant et
violation de la promesse de `presetFontSizes`. La README indique au contraire
qu'un membre bloqué par son minimum peut diverger du groupe.

**Correction minimale.** Réconcilier la taille de groupe avec les candidats
valides de chaque membre avant le rendu : clamp au minimum et, pour les presets,
choix d'une valeur autorisée appropriée. Un membre incapable d'adopter la taille
commune doit diverger comme le documente l'API, sans modifier la valeur publiée
aux autres membres.

**Tests de régression.** Minima/maxima différents, presets disjoints,
granularités différentes, scaling différent, retrait/changement de groupe et
retour à une taille supérieure.

### CORE-06 — Moyenne — La discrétisation flottante est instable et peut franchir le minimum

**Emplacement :** `lib/src/auto_size_text.dart:286-301`,
`lib/src/auto_size_text.dart:320-367`.

**Problème.** La validation exige
`minFontSize / stepGranularity % 1 == 0`, comparaison exacte inadaptée aux
doubles. En debug, `0.3 / 0.1` n'est pas représenté comme l'entier exact attendu
et déclenche l'assertion. En release, toutes ces assertions disparaissent et
la borne gauche utilise `floor`; une paire réellement non multiple peut alors
produire une taille sous `minFontSize`.

**Preuve/reproduction.** `minFontSize: 0.3`, `maxFontSize: 0.5` et
`stepGranularity: 0.1` lèvent l'assertion malgré un multiple décimal valide.
L'expression ligne 332 transforme par ailleurs, par exemple, minimum 12 et pas
5 en indice 2, donc candidat 10 si les assertions sont désactivées.
`test/step_granularity_test.dart` est vide.

**Impact.** Différence debug/release, rejet d'entrées valides et violation
possible de la limite de lisibilité en production.

**Correction minimale.** Définir la grille relativement au minimum ou utiliser
`ceil(min / step)` pour la borne basse, sans précondition de divisibilité
exacte. Valider explicitement les valeurs finies et employer une tolérance si
une contrainte de multiple est conservée.

**Tests de régression.** Pas 0.1/minimum 0.3, pas non diviseur du minimum,
fraction de style 33.5, bornes exactes et voisines; exécuter le comportement
algorithmique avec assertions actives et désactivées.

### CORE-07 — Moyenne — Une taille de référence zéro invalide la mesure

**Emplacement :** `lib/src/auto_size_text.dart:245-251`,
`lib/src/auto_size_text.dart:325-347`.

**Problème.** Une taille nulle est remplacée par 14, mais une taille explicite
zéro est conservée. Le calcul divise ensuite par `style.fontSize`, créant une
échelle infinie appliquée à un span de taille zéro. Le painter peut considérer
ce span comme ajusté, puis le rendu utilise une taille positive issue du
minimum.

**Preuve/reproduction.** Dans une largeur de 1, `fontSize: 0` avec le minimum
par défaut produit un `Text` effectif à 12; sa largeur réelle dépasse 1, mais le
calcul l'a déclaré ajusté. Aucun remplacement n'est déclenché.

**Impact.** Faux positif de fit et overflow. `TextStyle(fontSize: 0)` est une
valeur Flutter autorisée et peut servir à une transition animée.

**Correction minimale.** Ne plus représenter un candidat par une division sur
la taille de référence. Construire/transformer le style candidat directement,
ou traiter explicitement la référence zéro avec une sémantique documentée et
une mesure réelle du candidat positif.

**Tests de régression.** Référence zéro en texte simple et RichText, contraintes
minuscules, minimum zéro et positif, `overflowReplacement`.

### CORE-08 — Moyenne — La démo distribuée ne se résout plus sur Dart moderne

**Emplacement :** `demo/pubspec.yaml:6-17`, `demo/lib/main.dart:20-25`,
`demo/android/build.gradle:1-9`, `demo/android/app/build.gradle:11-25`,
`demo/android/app/src/main/AndroidManifest.xml:7-20`,
`demo/android/app/src/main/java/com/github/leisim/auto_size_text/demo/MainActivity.java:4-11`.

**Problème.** `bottom_navy_bar ^4.2.0` est pré-null-safety, les dépendances de
la démo ne sont donc pas résolubles sous Dart 3. `SystemChrome` utilise aussi
`setEnabledSystemUIOverlays`, supprimé. Le projet Android repose sur Gradle 4.4,
AGP 3.1.2, SDK 27 et l'ancien embedding `io.flutter.app`.

**Preuve.** `cd demo && fvm flutter pub get` échoue avant analyse. L'analyse
globale produit ensuite 12 erreurs dans la démo. Le dry-run de publication
montre que toute cette démo fait partie de l'archive du package.

**Impact.** Exemple avancé inutilisable par les mainteneurs et consommateurs,
analyse globale rouge, signal de compatibilité trompeur dans le package publié.

**Correction minimale.** Mettre à jour ou retirer les deux dépendances UI,
remplacer l'API SystemChrome, puis régénérer les fichiers de plateforme avec un
Flutter supporté au lieu de migrer manuellement l'ancien embedding.

**Tests de régression.** Dans la CI : `cd demo && flutter pub get`,
`flutter analyze`, un widget test de navigation/démos, et au moins un build
Android debug.

### CORE-09 — Moyenne — La CI n'est plus un garde-fou valide

**Emplacement :** `.github/workflows/dart.yml:11-19`, `pubspec.yaml:6-15`,
`analysis_options.yaml:1-46`.

**Problème.** Le workflow clone Flutter manuellement puis appelle `dartfmt`,
binaire retiré des SDK modernes. Il n'exécute pas `flutter analyze`. La
configuration repose sur `pedantic`, abandonné, et sur d'anciens réglages
`strong-mode`. La contrainte SDK `<3.0.0` est seulement réinterprétée par Pub
comme `<4.0.0`, ce que le dry-run signale.

**Preuve.** Le binaire attendu par la ligne 17 n'existe pas sous Flutter 3.44.0.
L'analyse ciblée retourne 11 diagnostics et l'analyse globale 27, sans qu'aucune
étape CI actuelle ne les bloque explicitement.

**Impact.** Un push moderne échoue avant les tests ou laisse passer les erreurs
d'analyse selon l'environnement; absence de baseline reproductible et risque de
publication d'API déjà dépréciées.

**Correction minimale.** Utiliser une action Flutter maintenue et une version
épinglée, remplacer `dartfmt` par `dart format --output=none
--set-exit-if-changed`, migrer vers `flutter_lints`/`lints`, exécuter
`flutter analyze` puis `flutter test`, et expliciter une plage SDK réellement
supportée.

**Tests de régression.** Workflow sur la version Flutter minimale et la stable
courante; format, analyse package/exemple, tests et dry-run de publication.

### CORE-10 — Faible — La démo de groupe recrée son contrôleur à chaque frame

**Emplacement :** `demo/lib/sync_demo.dart:18-20`, `:30-40`, `:53-56`.

**Problème.** L'état possède un champ `group`, mais `build` le masque par
`final group = AutoSizeGroup()`. L'animation appelle `setState` à chaque tick :
tous les membres changent donc de groupe à chaque frame. Le callback différé
ligne 38 relance aussi le contrôleur sans vérifier `mounted`, contrairement à
`animated_input.dart`.

**Preuve.** Lecture du flux : chaque tick modifie `_scale`, déclenche `build`,
crée une nouvelle instance, puis `didUpdateWidget` désenregistre/réenregistre
les deux textes et planifie des microtâches de groupe. Si l'écran est démonté
pendant les trois secondes d'attente, `forward` cible un contrôleur disposé.

**Impact.** Rebuilds/microtâches inutiles, démonstration de synchronisation
instable et assertion possible après navigation.

**Correction minimale.** Utiliser un champ privé final `_group` stable et tester
`mounted` avant de relancer l'animation différée.

**Tests de régression.** Vérifier l'identité du groupe sur plusieurs ticks,
la synchronisation pendant l'animation et l'absence d'exception après dispose
avant expiration du délai.

### CORE-11 — Faible — Les préconditions de `presetFontSizes` ne sont pas validées

**Emplacement :** `lib/src/auto_size_text.dart:121-124`,
`lib/src/auto_size_text.dart:302-305`, `lib/src/auto_size_text.dart:323-365`.

**Problème.** Le contrat exige une liste descendante, mais la validation vérifie
seulement qu'elle n'est pas vide. L'algorithme inverse ensuite la liste et
effectue une dichotomie qui suppose un ordre croissant. Il ne rejette pas non
plus les valeurs négatives, NaN ou infinies.

**Preuve.** Une liste `[40, 20, 30]` devient `[30, 20, 40]`; selon la contrainte,
la dichotomie peut retourner 20 alors que 30 tient. Le seul test fournit
`[100, 50, 5]`, donc uniquement le chemin valide.

**Impact.** Résultat silencieusement sous-optimal en debug et erreurs de painter
ou d'index en release pour certaines valeurs invalides.

**Correction minimale.** Valider une liste non vide, finie, non négative et
monotone, ou trier une copie si l'ordre ne doit plus faire partie du contrat.
La liste fournie par l'appelant ne doit pas être mutée.

**Tests de régression.** Ordre correct, ordre incorrect, doublons, zéro, valeurs
négatives/non finies et liste vide, y compris assertions désactivées.

## Zones propres et vérifications négatives

- Les 23 tests existants passent de manière identique sous Flutter 3.35.3 et
  3.44.0.
- Pour du texte simple et des entrées valides, largeur, hauteur, `maxLines`,
  min/max, presets descendants et `overflowReplacement` suivent le comportement
  historique attendu.
- La dichotomie est logarithmique dans le nombre de candidats; aucun parcours
  linéaire de toutes les tailles n'a été trouvé.
- Le groupe réduit et réaugmente correctement sa valeur dans les scénarios
  homogènes existants. Les notifications sont coalescées par microtâche et
  vérifient `mounted`.
- `dispose` retire l'état du groupe; aucun listener global ou abonnement externe
  persistant n'existe.
- `maxLines` explicite et celui de `DefaultTextStyle` sont résolus avant mesure.
- `semanticsLabel` est transmis au `Text` final; les spans originaux, y compris
  leurs recognizers et labels sémantiques, sont conservés au rendu.
- La null-safety du code produit compile sous Dart 3.9 et 3.12 malgré une version
  de langage 2.12. Aucun cast non sûr dépendant d'une entrée externe n'a échoué
  dans les chemins valides.

### Checklist sécurité adaptée

| Catégorie | Conclusion |
|---|---|
| Injection SQL/commande/template/header | Non applicable : aucune base, shell, requête ou template interprété. |
| XSS | Non applicable : package Flutter natif sans HTML généré. |
| Authentification/autorisation/IDOR/CSRF/session | Non applicable : aucune identité ni opération distante. |
| Cryptographie/secrets/information disclosure | Non applicable : aucun secret, log ou primitive cryptographique. |
| Race/TOCTOU | Groupe et microtâches inspectés; contrôle `mounted` présent dans le cœur. Seul le callback de démo CORE-10 est fautif. |
| Déni de service | La recherche de taille est logarithmique. Le coût `wrapWords` répète toutefois aplatissement/regex/painters à chaque candidat; pas classé sans benchmark ni entrée hostile. |
| Logique métier/numérique | Défauts confirmés CORE-03 à CORE-07 et CORE-11. |

## Lacunes de tests constatées

- `test/step_granularity_test.dart` ne contient qu'un `main()` vide.
- Le test « Unlimited maxLines if parameter null » de
  `test/maxlines_test.dart:35` est vide.
- Aucun test ne couvre `WidgetSpan`, `TextScaler`, `boldText`, `softWrap`, locale
  ou direction héritée, rich spans partiellement stylés, référence zéro,
  presets invalides ou contraintes hétérogènes de groupe.
- La couverture de lignes élevée ne mesure pas ces branches sémantiques.
- Les helpers `doesTextFit`, `prepareTests` et `OverflowNotifier` de
  `test/utils.dart` ne sont utilisés par aucun test. `doesTextFit` calcule en
  outre un `maxLines` local pour `wrapWords == false` mais passe finalement
  `text.maxLines` au painter.

## Inconnues et limites

- Aucun test sur appareil, golden, navigateur ou moteur de fonte de production
  n'a été exécuté. Les erreurs de métriques dépendantes de locale/fallback
  peuvent donc être plus larges que les reproductions Roboto/Ahem.
- Le scaling non linéaire a été vérifié avec un `TextScaler` déterministe de
  test, pas avec chaque courbe système Android/iOS.
- La démo n'a pas pu être analysée ou construite dans son propre package après
  l'échec du solveur. Les erreurs postérieures à la migration des dépendances
  restent inconnues.
- Aucun build release de test n'a été produit. Les conséquences des assertions
  supprimées sont déduites directement des `floor`, index et divisions du code.
- Le support complet de `WidgetSpan` nécessite probablement une mesure de
  render objects; son coût architectural doit être prototypé avant estimation.

## Découpage recommandé en lots indépendants

1. **Compatibilité de scaling et parité texte simple** — CORE-02 et CORE-03 :
   introduire `TextScaler`, centraliser la configuration effective, corriger
   `softWrap`/bold, ajouter les tests d'accessibilité.
2. **RichText** — CORE-01 et CORE-04 : reconstruire l'arbre de mesure fidèle,
   corriger `wrapWords`, puis décider/supporter explicitement `WidgetSpan`.
3. **Groupes hétérogènes** — CORE-05 uniquement : réconciliation des contraintes
   par membre et tests min/presets/scaling.
4. **Recherche numérique et validation** — CORE-06, CORE-07 et CORE-11 : grille
   de candidats robuste, référence zéro et validations finies/monotones.
5. **Outillage package** — CORE-09 : SDK, lints, format/analyse/tests et matrice
   CI, sans changement de comportement produit.
6. **Démo** — CORE-08 et CORE-10 : dépendances/UI, régénération plateformes,
   groupe stable et cycle de vie de l'animation.

Chaque lot produit doit inclure ses tests de régression dans le même commit. Les
lots 3 à 6 ne dépendent pas des refactorings RichText; les lots 1 et 2 peuvent
partager ensuite une petite fabrique de configuration de painter, mais doivent
rester revus séparément pour limiter le risque de régression de layout.
