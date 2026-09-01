# Revue indépendante de l'audit du cœur `auto_size_text`

Date : 2026-09-01

Rapport revu : `maintenance/audits/core-audit.md`, commit
`072f54ef83c3f72736bf0e56b8f04019dcea4bc5`

Référence produit : `master`, commit
`f22397751271605ac46e8740d9e48ed631a74cb0`

Périmètre de la revue : vérification des onze findings, de leurs preuves, de
leurs priorités et des corrections proposées. Aucun code produit ni test
permanent n'a été modifié.

## Verdict global

L'audit est solide et exploitable, sous réserve de corriger son plan avant
implémentation : neuf findings sont confirmés et deux doivent être reformulés.
Aucun finding n'est non prouvé, doublon ou à reprioriser.

Les deux corrections de fond sont les suivantes :

1. CORE-03 couvre une famille plus large d'écarts entre mesure et rendu que
   `softWrap` et `boldText`. Flutter 3.44 applique également les overrides
   d'accessibilité de hauteur et d'espacement, les valeurs ambiantes de
   direction, locale et métriques de paragraphe, ainsi qu'un strut effectif.
   Deux reproductions complémentaires confirment respectivement un overflow dû
   à `letterSpacingOverride` et un faux positif de fit dû au scaling de
   `StrutStyle`.
2. CORE-06 mélange un défaut confirmé sur des doubles valides avec un effet
   release obtenu en violant la précondition de divisibilité actuelle. Le plan
   peut supprimer cette précondition et ancrer la grille sur le minimum, mais le
   rapport doit distinguer clairement le bug actuel de ce changement de contrat.

Le plan original présente aussi CORE-09 comme indépendant de CORE-02. Ce n'est
pas le cas : exposer `TextScaler` impose de fixer d'abord la version minimale de
Flutter/Dart supportée. Cette décision doit précéder la modification de l'API et
être couverte par la matrice CI.

## Verdict par finding

### CORE-01 — Confirmé — priorité haute conservée

**Preuve.** `AutoSizeText.rich` accepte un `TextSpan` contenant un
`WidgetSpan`, transmet ce dernier au `TextPainter` de mesure et n'appelle jamais
`setPlaceholderDimensions`. La reproduction sous Flutter 3.44.0 reçoit bien
l'assertion `dimensions != null` depuis `_checkTextFits`. `Text.rich` documente
explicitement `WidgetSpan` comme un `InlineSpan` supporté, et la README affirme
que `AutoSizeText.rich` fonctionne exactement comme `Text.rich`.

**Correction requise au plan.** Le finding est exact, mais l'alternative
« erreur déterministe en release » n'est qu'une stabilisation, pas une
correction fonctionnelle. Elle contredit le contrat public actuel. Le support
réel des placeholders doit former un lot séparé, après la remise à plat du span
de mesure de CORE-04. Si une limitation explicite est retenue temporairement,
elle doit être documentée comme telle et ne pas être comptée comme résolution
de CORE-01.

**Garde-fou de périmètre.** Ne pas construire un moteur générique de rich text.
Mesurer uniquement les enfants inline réellement acceptés par `Text.rich`, avec
leurs dimensions de layout et la même configuration de paragraphe que le rendu.

### CORE-02 — Confirmé — priorité haute conservée

**Preuve.** Le code lit `MediaQuery.textScaleFactorOf`, utilise cette estimation
comme facteur linéaire, puis neutralise le scaling du `Text` simple. Avec un
scaler de test pour lequel `scale(30) == 36` et `textScaleFactor == 2`, le widget
produit une taille effective de 60. Les six usages produit de l'ancienne API
sont également signalés par l'analyseur.

**Correction requise au plan.** Ajouter `TextScaler? textScaler` sans supprimer
`textScaleFactor`, conserver la priorité et l'exclusion mutuelle de `Text`, et
utiliser exactement le même scaler composé pour mesure et rendu. La composition
doit être définie par comportement : pour RichText, appliquer le ratio
d'auto-size aux tailles logiques de chaque run avant le scaler utilisateur, au
lieu de réduire celui-ci à `textScaleFactor`.

**Compatibilité.** Fixer et tester la version minimale Flutter/Dart qui expose
`TextScaler` avant ce changement. Une hausse de minimum est une décision de
versionnage, même si les constructeurs existants restent compatibles.

### CORE-03 — À reformuler — priorité haute conservée

**Partie confirmée.** La mesure ignore `softWrap` et mesure toujours avec
`constraints.maxWidth`. Le rendu résout au contraire `softWrap` depuis
`DefaultTextStyle`. `Text.build` applique aussi `MediaQuery.boldTextOf`, absent
de la mesure. La reproduction `softWrap: false` produit un texte final dont la
largeur non wrappée dépasse la contrainte alors que le calcul le déclare ajusté.

**Omissions critiques à intégrer au finding.** La parité avec `Text.build` doit
aussi couvrir :

- `MediaQueryData.lineHeightScaleFactorOverride`,
  `letterSpacingOverride` et `wordSpacingOverride` ;
- le `StrutStyle` effectif, y compris l'override de hauteur ;
- `textDirection` et `locale` ambiants lorsque les paramètres sont nuls ;
- `DefaultTextStyle.textWidthBasis`, `textHeightBehavior` et le
  `DefaultTextHeightBehavior` ambiant ;
- la résolution de l'overflow effectif depuis le style et
  `DefaultTextStyle`, nécessaire pour la sémantique particulière de
  `softWrap: false` avec ellipsis.

Une reproduction supplémentaire avec `letterSpacingOverride: 50` conserve la
taille 30 pendant le calcul, puis le `RichText` final dépasse une largeur de 100.
Une seconde reproduction avec `StrutStyle(fontSize: 100,
forceStrutHeight: true)` dans une hauteur de 60 montre que la mesure réduit le
strut avec son ancien `textScaleFactor`, tandis que le `Text` simple final garde
un strut de 100 et n'affiche pas `overflowReplacement`.

**Correction requise au plan.** Construire une petite configuration effective
partagée par les painters et le rendu. Pour la largeur, reproduire la règle de
`RenderParagraph` : largeur contrainte si le texte wrappe ou si l'overflow est
ellipsis, largeur infinie sinon, puis comparer la largeur obtenue à la
contrainte. Éviter de recopier sans nécessité l'intégralité de `Text.build` ; ne
résoudre que les propriétés qui influencent le layout rendu par cette API.

### CORE-04 — Confirmé — priorité haute conservée

**Preuve.** Le span de mesure choisit `widget.textSpan?.style ?? style` au lieu
de placer le span fourni sous le style effectif de `AutoSizeText`. Un style
racine partiel perd donc l'héritage du parent. Le contrôle `wrapWords: false`
appelle en outre `toPlainText` et reconstruit un span monostyle, ce qui efface les
runs enfants. Les deux comportements ont été reproduits sous Flutter 3.44.0.

**Correction requise au plan.** Pour le painter général, créer un parent portant
le style effectif et conserver `widget.textSpan` comme enfant intact. Cette
approche est plus petite et plus sûre que de recopier les propriétés du span.
Pour le contrôle des mots, conserver les runs et leurs styles lors de la mesure
des limites de mots. Ne pas modifier le span de l'appelant, ses recognizers ou
ses informations sémantiques.

### CORE-05 — Confirmé — priorité moyenne conservée

**Preuve.** Après avoir calculé un candidat individuel valide, le membre rend
directement `group._fontSize`. Deux membres avec des minima 10 et 20 conduisent
le second sous 20. Le même chemin accepte une taille étrangère à ses presets.
La README documente au contraire qu'un membre bloqué par son minimum peut
diverger du groupe.

**Correction requise au plan.** Projeter la taille commune sur l'ensemble des
candidats valides du membre. Un simple `clamp` ne suffit pas pour les presets ou
les granularités : il peut créer une taille non autorisée. Le membre qui ne peut
pas adopter la taille commune doit diverger sans réécrire la valeur publiée aux
autres. Définir cette projection dans les mêmes unités que le scaler effectif de
CORE-02.

### CORE-06 — À reformuler — priorité moyenne conservée

**Partie confirmée.** `0.3 / 0.1` n'est pas exactement entier en binaire ; la
validation actuelle rejette donc un multiple décimal valide. La reproduction
reçoit l'assertion attendue. `floor(min / step)` peut aussi produire un candidat
sous le minimum si la précondition de divisibilité n'est pas respectée.

**Nuance requise.** L'exemple release `minFontSize: 12,
stepGranularity: 5` viole aujourd'hui la précondition documentée par
l'assertion. Il prouve que le chemin release n'est pas défensif, mais pas qu'une
entrée valide selon le contrat actuel passe sous le minimum. Le rapport doit
séparer ce point du faux rejet de `0.3 / 0.1`.

**Correction requise au plan.** Ancrer les candidats sur `minFontSize`
(`min + index * step`) est plus cohérent avec la documentation et garantit que
le minimum reste un candidat. Supprimer alors la divisibilité exacte au lieu
d'ajouter une tolérance fragile. Valider séparément que minimum, maximum et pas
sont finis et ordonnés. Garder la recherche par indices entiers.

### CORE-07 — Confirmé — priorité moyenne conservée

**Preuve.** Avec un style de référence nul, le candidat minimal positif est
divisé par zéro. La reproduction dans une largeur de 1 produit sans exception
un `Text` final à 12 dont la largeur réelle dépasse 1 ; aucun remplacement n'est
affiché. Flutter accepte `TextStyle(fontSize: 0)` et ce cas peut apparaître
pendant une animation.

**Correction requise au plan.** Éliminer la division par la taille de référence
du chemin de texte simple. Pour RichText, la sémantique du ratio lorsque la
référence est zéro doit être explicite et testée ; ne pas introduire un epsilon
silencieux qui modifierait les ratios.

### CORE-08 — Confirmé — priorité moyenne conservée

**Preuve.** `fvm flutter pub get` dans `demo/` échoue parce que
`bottom_navy_bar` n'est pas null-safe. L'analyse globale voit ensuite douze
erreurs de démo, dont `setEnabledSystemUIOverlays` supprimé. Les fichiers Android
utilisent Gradle 4.4, AGP 3.1.2, SDK 27 et l'ancien embedding. Le dry-run de
publication inclut bien `demo/`.

**Correction requise au plan.** Préférer les composants Material intégrés si
cela permet de supprimer les deux dépendances UI obsolètes sans changer les six
écrans. Déplacer aussi les appels `SystemChrome` hors de `build`, où ils sont
actuellement répétés à chaque rebuild. Régénérer la plateforme Android avec la
version Flutter minimale retenue plutôt que migrer Gradle et l'embedding à la
main.

### CORE-09 — Confirmé — priorité moyenne conservée

**Preuve.** Le binaire `dartfmt` visé par le workflow n'existe pas dans Dart
3.12. Le workflow suit `stable` sans version, n'exécute pas l'analyseur et repose
sur `checkout@v1`. `pedantic` est abandonné, les clés `strong-mode` sont
obsolètes et le dry-run interprète la contrainte `<3.0.0` comme `<4.0.0`.

**Correction requise au plan.** Traiter d'abord ce finding comme contrat de
compatibilité et garde-fou : choisir une version Flutter minimale, épingler la
toolchain et les actions par version ou SHA, remplacer `dartfmt`, puis faire
tourner les tests. L'activation d'un `flutter analyze` global vert dépend de
CORE-02 et CORE-08 ; elle doit fermer le chantier, pas bloquer les lots
intermédiaires. La migration de lints doit rester un changement mécanique
séparé des corrections de layout.

### CORE-10 — Confirmé — priorité faible conservée

**Preuve.** Le champ `group` est masqué dans `build` par une nouvelle instance.
Chaque tick d'animation change donc le groupe des deux membres montés ; les
quatre branches normales/rich de `Visibility` reçoivent la nouvelle instance.
Le callback différé peut appeler un contrôleur disposé, alors que
`animated_input.dart` vérifie déjà `mounted` dans le cas équivalent.

**Correction requise au plan.** Utiliser un champ privé final stable et vérifier
`mounted` dans le callback différé. Tester le comportement visible de
synchronisation et l'absence d'exception après dispose ; un test couplé à
l'identité du champ privé n'est pas nécessaire.

### CORE-11 — Confirmé — priorité faible conservée

**Preuve.** La seule validation porte sur la non-vacuité. Une liste
`[40, 20, 30]` est inversée en `[30, 20, 40]` puis donnée à une dichotomie qui
suppose l'ordre croissant. Avec une contrainte de hauteur située entre 30 et 40,
la reproduction retourne 20 alors que 30 tient.

**Correction requise au plan.** Conserver le contrat descendant et valider une
suite finie, non négative et monotone non croissante. Les doublons ne cassent pas
la dichotomie ; les accepter ou les rejeter doit être documenté, pas décidé par
accident. Ne pas trier silencieusement : cela élargirait le contrat et pourrait
masquer une erreur de l'appelant. Continuer à travailler sur une copie et ne
jamais muter la liste fournie.

## Matrice de risques

| Finding | Probabilité d'exposition | Impact utilisateur | Confiance de la revue | Risque du correctif |
|---|---:|---:|---:|---:|
| CORE-01 | Moyenne | Élevé : crash | Élevée | Élevé : layout des placeholders |
| CORE-02 | Élevée sur accessibilité moderne | Élevé : fit et lisibilité faux | Élevée | Élevé : API et composition du scaler |
| CORE-03, overrides et strut | Moyenne à élevée | Élevé : overflow/remplacement faux | Élevée | Élevé : parité multi-paramètres |
| CORE-04 | Moyenne pour RichText | Élevé : overflow/mots coupés | Élevée | Moyen à élevé |
| CORE-05 | Faible à moyenne | Moyen : minimum/presets violés | Élevée | Moyen après CORE-02 |
| CORE-06 | Moyenne avec pas décimaux | Moyen : assertion/limite violée | Élevée | Moyen : grille historique |
| CORE-07 | Faible | Moyen : overflow silencieux | Élevée | Moyen : sémantique zéro RichText |
| CORE-08 | Certaine pour la démo moderne | Moyen : démo inutilisable | Élevée | Moyen : régénération plateforme |
| CORE-09 | Certaine sur stable actuelle | Moyen : absence de garde-fou | Élevée | Faible à moyen |
| CORE-10 | Certaine pendant l'animation | Faible : churn/assertion navigation | Élevée | Faible |
| CORE-11 | Faible sur entrées hors contrat | Faible à moyen | Élevée | Faible |

## Lots recommandés, ordonnés

1. **Contrat de compatibilité et CI minimale — première partie de CORE-09.**
   Choisir le minimum Flutter/Dart, épingler la toolchain, remplacer `dartfmt`
   et faire tourner les 23 tests sur minimum et version courante. Ne pas mélanger
   la migration de lints avec le code de layout.
2. **Parité du texte simple et scaling moderne — CORE-02, CORE-03 et omissions
   de cette revue.** Ajouter `textScaler` en conservant l'ancien paramètre,
   centraliser la configuration effective, corriger soft-wrap, overrides,
   strut, direction, locale et métriques. Ajouter les tests de bascule entre
   frames.
3. **Arbre RichText fidèle — CORE-04.** Conserver le span original sous le style
   parent et corriger `wrapWords: false`, sans encore prendre en charge le layout
   des widgets inline.
4. **Placeholders inline — CORE-01.** Implémenter et profiler la mesure de
   `WidgetSpan` sur la base stabilisée du lot 3. Une erreur explicite temporaire
   ne clôt pas ce lot.
5. **Groupes hétérogènes — CORE-05.** Définir les unités après CORE-02, projeter
   la valeur commune sur les candidats du membre et tester minima, presets,
   granularités et scalers différents.
6. **Recherche et validations numériques — CORE-06, CORE-07 et CORE-11.** Ancrer
   la grille au minimum, supprimer la division par la référence zéro et valider
   les presets sans les trier.
7. **Démo et fermeture CI — CORE-08, CORE-10 et fin de CORE-09.** Remplacer les
   dépendances UI, régénérer Android, stabiliser le groupe, ajouter un smoke test
   de démo, puis rendre format, analyse globale, tests et build Android bloquants.

Chaque lot produit doit contenir ses tests de régression. Les lots 2 à 5 doivent
être revus séparément : les erreurs portent sur des relations de layout et une
refactorisation unique rendrait les régressions difficiles à localiser.

## Preuves et commandes exécutées

| Commande | Résultat indépendant |
|---|---|
| `git diff --name-status master...HEAD` | Un seul fichier initial : `maintenance/audits/core-audit.md`. |
| `fvm flutter test` | 23 tests passent sur Flutter 3.35.3. |
| `flutter 3.44.0 test --coverage` | 23 tests passent ; `LF=156`, `LH=154`, soit 98,7 %. |
| `fvm flutter analyze lib test example/main.dart` | 11 informations : six dépréciations produit, trois tests et deux imports. |
| `fvm flutter analyze` | 27 diagnostics : douze erreurs de démo et quinze informations. |
| `cd demo && fvm flutter pub get` | Échec du solveur sur `bottom_navy_bar` non null-safe. |
| `dart 3.12 format --output=none --set-exit-if-changed lib test example demo/lib` | Deux fichiers différeraient : `auto_size_group_builder.dart` et `group_builder_test.dart`. Aucun fichier écrit. |
| Test d'absence de `dart-sdk/bin/dartfmt` sous Flutter 3.44.0 | Binaire absent. |
| `dart 3.12 pub publish --dry-run` | Démo incluse ; 0 avertissement, 1 indication sur la contrainte SDK. |
| Suite témoin temporaire, Flutter 3.44.0 | Neuf reproductions du rapport passent. |
| Reproduction temporaire `letterSpacingOverride` | Passe et confirme l'overflow omis de CORE-03. |
| Reproduction temporaire `StrutStyle` | Passe et confirme mesure à moins de 60 puis rendu effectif à plus de 60. |

Les tests temporaires attendaient le comportement défectueux observé. Ils ont
été supprimés après exécution, de même que les artefacts de résolution et de
couverture créés pendant la revue.

## Fichiers inspectés

Lus intégralement :

- `maintenance/audits/core-audit.md` ;
- `lib/auto_size_text.dart`, `lib/src/auto_size_text.dart`,
  `lib/src/auto_size_group.dart`, `lib/src/auto_size_group_builder.dart` ;
- les onze fichiers Dart de `test/` ;
- `README.md`, `CHANGELOG.md`, `pubspec.yaml`, `analysis_options.yaml`,
  `.github/workflows/dart.yml` ;
- `demo/pubspec.yaml`, `demo/lib/main.dart`, `demo/lib/sync_demo.dart`,
  `demo/lib/animated_input.dart` ;
- `demo/.metadata`, les Gradle racine/app/wrapper, `settings.gradle`,
  `AndroidManifest.xml` et `MainActivity.java` de la démo.

Extraits Flutter 3.44 inspectés aux chemins de comportement concernés :

- `widgets/text.dart` pour le style effectif, les overrides, le scaler et les
  valeurs héritées ;
- `rendering/paragraph.dart` pour la largeur effective selon soft-wrap et
  ellipsis, et le layout des placeholders ;
- `painting/text_painter.dart` et `painting/text_style.dart` pour le scaler, le
  strut et les dimensions de placeholders ;
- `widgets/media_query.dart` pour les scalers et overrides d'accessibilité.

## Checklist de sécurité et limites

| Catégorie | Résultat |
|---|---|
| Injection, XSS, auth, autorisation, CSRF, session | Hors surface : aucune entrée distante, base, template HTML ou identité. |
| Cryptographie, secrets, divulgation | Hors surface : aucune primitive, persistance, requête ou journalisation sensible. |
| Race/TOCTOU | Groupe et microtâches revus ; contrôle `mounted` présent dans le cœur. Défaut de callback de démo confirmé en CORE-10. |
| Déni de service | Recherche logarithmique confirmée. Coût de `wrapWords` non classé sans benchmark ni entrée hostile. |
| Logique métier et numérique | Findings confirmés ci-dessus ; aucune autre omission critique évidente hors parité Text/strut. |

Non vérifié complètement : comportement sur appareil et web, courbes système
non linéaires réelles, build release sans assertions, migration/build Android de
la démo après résolution des dépendances, et coût d'une implémentation complète
de `WidgetSpan`. Ces limites n'affaiblissent pas les reproductions et preuves de
code retenues.
