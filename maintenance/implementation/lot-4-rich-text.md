# Lot 4 — RichText fidèle, référence zéro et mots insécables

Date : 2026-09-01

Branche : `codex/impl-rich-text`

Parent exact : `3a1c343e88325b0020452be7c3258a902d87558f`

Tête : commit contenant ce journal ; SHA final communiqué dans le compte rendu

## Périmètre livré

- mesure de `AutoSizeText.rich` avec le `TextSpan` source conservé comme enfant
  d'un parent synthétique portant le style effectif ;
- composition du scaler candidat par run selon
  `userScaler.scale(runSize * candidate / reference)` ;
- application fidèle des overrides MediaQuery de hauteur, espacement des lettres
  et espacement des mots à chaque `TextSpan` standard ;
- référence racine zéro sans ratio ni epsilon : taille du parent égale au
  candidat et scaler utilisateur direct ;
- détection historique des mots pour `wrapWords: false`, avec U+00A0 NBSP et
  U+202F NNBSP conservés comme caractères liants ;
- mesure des plages visuelles sur l'arbre riche non aplati, avec offsets UTF-16
  et agrégation de toutes les boîtes retournées par Flutter ;
- snapshot immuable du texte visuel et de sa segmentation construit une fois
  par configuration, hors de la recherche de candidats ;
- conservation des recognizers, callbacks de survol, curseurs, métadonnées de
  sémantique, locales, `spellOut`, arbres source et clés de `Text` ;
- erreur déterministe appartenant au package lorsqu'un `WidgetSpan` est
  rencontré avant que le lot 10 fournisse les dimensions de placeholders.

Hors périmètre : modèle de groupe moderne, render object et intrinsics dédiés,
support automatique de `WidgetSpan`, démo, CI, manifeste, locks, documentation
publique et version.

## Fichiers

- `lib/src/auto_size_text.dart` ;
- `lib/src/auto_size_text_layout.dart` ;
- `test/rich_text_test.dart` ;
- `test/wrap_words_test.dart` ;
- présent journal.

## Arbre riche et scaler candidat

La mesure installe toujours un parent synthétique avec le style de mesure
effectif. Le `TextSpan` riche fourni par l'appelant est son unique enfant et
n'est ni aplati, ni muté. Sans override de métrique, l'objet source lui-même est
conservé. Le `Text` final reçoit également l'arbre source et le style avant
override ; Flutter applique ainsi ses overrides une seule fois au rendu.

Lorsqu'un override de hauteur ou d'espacement existe, le clone récursif ne
reconstruit que les nœuds dont `runtimeType == TextSpan`. Chaque clone copie le
texte, une nouvelle liste d'enfants, le style fusionné, `recognizer`,
`mouseCursor`, `onEnter`, `onExit`, `semanticsLabel`, `semanticsIdentifier`,
`locale` et `spellOut`. Un sous-type inconnu de `TextSpan` et un `WidgetSpan`
restent les mêmes objets. Aucune promesse d'alias entre deux clones standards
distincts n'est introduite.

Pour une référence positive `F`, un run logique de taille `S` est envoyé au
scaler utilisateur comme `S * C / F`. Le cas discriminant permanent utilise
`F = 20`, `C = 10`, `S = 40` et un scaler non linéaire
`U(x) = x + x² / 100` : la sortie vaut 24 et non 22. Le même scaler candidat
sert à tous les runs, au painter et au `RenderParagraph` final.

Pour `F = 0`, le parent synthétique et le style du `Text` final portent
directement `fontSize: C`, tandis que le scaler reste exactement `U`. Un enfant
explicite de taille 20 reste donc `U(20)` et un enfant explicite de taille zéro
reste nul. Cette branche n'effectue aucune division, substitution epsilon ou
linéarisation. Elle couvre texte simple et riche, minimum nul ou positif,
contraintes réelles, remplacement d'overflow et `textKey` sur le `Text` exact.

## `wrapWords: false`

La chaîne servant uniquement aux offsets vient de
`toPlainText(includeSemanticsLabels: false)`. Les séparateurs historiques
restent ceux de `RegExp(r'\s')`, sauf NBSP et NNBSP qui ne terminent pas une
plage. Les indices `[start, end)` sont donc les indices en code units Dart et
aucun pseudo-mot n'est obtenu par `substring`, concaténation ou reconstruction
d'un `TextSpan` plat.

Pour chaque candidat, un seul painter supplémentaire effectue un layout sans
wrap sur l'arbre fidèle. Chaque plage est demandée avec
`getBoxesForSelection`; sa largeur est la somme de
`abs(box.right - box.left)` sur toutes les boîtes. Cette somme est nécessaire
pour les plages bidirectionnelles : le témoin `A\u00A0אב` produit plusieurs
boîtes disjointes sur Flutter 3.41.0 et 3.47.2. Une première boîte, un maximum
isolé ou une bounding box globale ne sont pas des oracles valides.

Le découpage des plages est linéaire dans la chaîne d'offsets. Le coût de leur
mesure dépend ensuite du nombre de plages et de boîtes renvoyées par Flutter ;
aucune revendication plus forte sur les détails internes du moteur n'est faite.
La chaîne et ses ranges sont matérialisées une seule fois dans une
`List<TextRange>.unmodifiable`, locale à l'invocation de calcul. Chaque candidat
réutilise ce snapshot, tout en conservant son propre painter et son propre
layout auxiliaire. `wrapWords: true` transmet `null` et ne calcule ni chaîne ni
ranges. Il n'existe aucun cache global, mutable ou partagé entre rebuilds.

La préparation visible du package coûte donc `O(N)` par configuration, puis au
plus `K × E` requêtes de boîtes pour `K` plages et `E` candidats testés. La
recherche de candidats conserve sa complexité logarithmique du lot 2. La
complexité interne de Flutter pour une requête de boîtes n'est pas revendiquée.

Ce lot conserve volontairement les opportunités historiques espace, tabulation
et retour de ligne. Il n'implémente pas l'algorithme général Unicode Line
Breaking.

## Preuves rouges sur le parent S4

Les nouvelles régressions ont d'abord été exécutées avec Flutter 3.47.2 sur le
parent exact, sans code produit du lot 4. Les échecs produit observés étaient :

- une racine riche partiellement stylée conservait 30 au lieu du candidat 20,
  car le style parent effectif n'était pas hérité par l'arbre mesuré ;
- les overrides d'espacement mesuraient le candidat 20 au lieu de 10 ;
- une référence riche zéro lançait l'`ArgumentError` exigeant une référence
  positive dans le scaler composé ;
- `WidgetSpan` atteignait l'assertion opaque de Flutter sur l'absence de
  dimensions de placeholder au lieu d'une frontière appartenant au package ;
- les mots riches traversant plusieurs spans et les plages liées par NBSP ou
  NNBSP étaient mesurés après aplatissement/reconstruction et ne sélectionnaient
  pas le candidat attendu.

Le cas non linéaire, les métadonnées et l'immuabilité n'ont pas été présentés
comme rouges lorsqu'ils passaient déjà ou lorsque le premier échec provenait du
harness. Les assertions finales ont été conservées pour empêcher les
régressions conjointes.

### Fixture demi-surrogate exclue

Une fixture exploratoire séparait les deux code units d'un emoji entre deux
`TextSpan`. `toPlainText` concatène alors visuellement l'emoji, mais le rendu
fidèle appelle `TextSpan.build` puis `ParagraphBuilder.addText` séparément pour
chaque run. Sur les deux SDK exacts, chaque moitié déclenche
`ArgumentError: string is not well-formed UTF-16`, signalé via
`FlutterError.onError`, avant substitution par U+FFFD.

La pile minimale observée est :

```text
TextPainter.layout
TextPainter._createParagraph
TextSpan.build
_NativeParagraphBuilder.addText
```

`RenderParagraph` suit la même construction. Le premier probe masquait ces
erreurs Flutter ; la fixture a donc été exclue après arbitrage plutôt que de
transformer un input invalide en contrat du package. L'implémentation reste
fidèle à l'arbre et ne concatène aucun pseudo-run.

## Correctif après les deux revues du lot

Les revues indépendantes `632edad` et `f6419e7` ont toutes deux demandé le même
correctif bloquant : sur la tête initiale `719d6a8`, la chaîne visuelle et le
scan des ranges étaient exécutés dans `_checkTextFits`, donc une fois par
candidat de la dichotomie.

La régression permanente utilise uniquement dans le test un sous-type privé de
la classe publique `TextSpan` et compte ses appels à `computeToPlainText`, sans
accès à un helper privé. Avec une grille virtuelle d'environ `1 000 000 001`
candidats, une boîte
de taille nulle et un replacement empêchant le rendu final du span, elle a été
exécutée avant le correctif sur `719d6a8` : attendu 1, réel 30 avec Flutter
3.47.2. Ce rouge reproduit exactement le finding des deux revues, qui avaient
également mesuré 30 sur Flutter 3.41.0.

Le snapshot est désormais construit dans `_calculateFontSize` avant
`findLargestThatFits`. Le même test obtient exactement 0 appel avec
`wrapWords: true`, 1 avec `wrapWords: false`, puis un appel supplémentaire et
un seul après changement d'override et après remplacement du span entre pumps.
Le painter auxiliaire, son layout non wrappé, les requêtes de boîtes, leur somme
bidi et le `dispose` protégé par `finally` restent propres à chaque candidat.

## Preuves vertes

Toolchains exactes :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
```

### Flutter 3.47.2

| Commande | Résultat |
|---|---|
| format `lib test example`, puis contrôle sans changement | 25 fichiers, 0 changement |
| analyse scoped fatale `lib test example/main.dart` | aucun diagnostic |
| `test/rich_text_test.dart test/wrap_words_test.dart` | 21/21 |
| compteur domaine milliardaire / corpus alterné | 0 pour wrap vrai, puis exactement 1 par configuration ; vert sans seuil mural |
| suite racine complète | 96/96 |
| suites explicites cycle de vie/leak | 9/9 |
| exemple : `pub get --enforce-lockfile`, analyse fatale | succès, aucun diagnostic |

### Flutter 3.41.0

L'état final corrigé a été copié dans
`/private/tmp/auto-size-text-lot4-fix-min.qzbod1/repo`, sans `.git`, locks ni
répertoires générés avant résolution.

| Commande | Résultat |
|---|---|
| `flutter pub get --no-example` racine | succès, 26 dépendances résolues naturellement |
| analyse scoped fatale `lib test example/main.dart` | aucun diagnostic |
| deux suites ciblées du lot | 21/21 |
| compteur domaine milliardaire / corpus alterné | 0 pour wrap vrai, puis exactement 1 par configuration ; vert sans seuil mural |
| suite racine complète | 96/96 |
| suites explicites cycle de vie/leak | 9/9 |
| exemple sans lock : `flutter pub get`, analyse fatale | succès, aucun diagnostic |
| `flutter pub downgrade --no-example`, puis suite complète `--no-pub` | 9 dépendances abaissées ; 96/96 |

Le painter témoin est reconstruit depuis le vrai `RenderParagraph` dans les cas
discriminants. Les tests comparent `textSize`, `didExceedMaxLines`, la taille
contrainte et la baseline sèche, en plus des boîtes de sélection par run.

## Tests permanents ajoutés

La suite riche couvre la racine partielle, les enfants imbriqués et leurs
taille, poids, famille, hauteur et espacements, le scaler multi-run non linéaire,
le clone exhaustif et l'identité des sous-types, le recognizer réellement
déclenché, les callbacks de survol, le curseur actif, les labels et identifiants
de sémantique, la priorité du label widget, puis l'immuabilité du source à
travers plusieurs rebuilds avec et sans overrides.

La référence zéro couvre simple et riche, minimum nul et positif, enfant
explicite positif ou nul, contrainte qui tient ou déborde, remplacement et clé
du `Text`. La suite `wrapWords` couvre espaces, tabulations, LF, CRLF, NBSP,
NNBSP, séparateurs consécutifs, mots multi-spans, mélange de plages, emoji
complet avant NBSP, labels sémantiques exclus des offsets et plage bidi à
plusieurs boîtes. `wrapWords: true` conserve son comportement historique.
Un corpus de 256 code units alternant caractère et séparateur exerce le cas à
nombreuses plages sans imposer de seuil temporel dépendant de la machine.
Le compteur sur domaine milliardaire verrouille séparément 0 segmentation pour
`wrapWords: true`, une segmentation par configuration pour `false` et le
recalcul exact après changement du span ou d'un override entre pumps.

Le test `WidgetSpan` vérifie seulement l'erreur déterministe et l'identité de
la source. Il ne promet ni mesure, ni rendu, ni support anticipé du lot 10.

## Limites et risques transmis

- `WidgetSpan` reste volontairement non supporté tant que des
  `PlaceholderDimensions` fidèles ne peuvent pas être obtenues automatiquement ;
- les opportunités de wrap restent historiques, avec les deux espaces liants
  explicitement corrigés, sans promesse UAX #14 générale ;
- le modèle moderne de groupe, les intrinsics et le render object dédié restent
  hors lot ; les groupes conservent le comportement hérité du parent S4 ;
- aucun fichier de démo, CI, exemple, manifeste, lock, documentation publique
  ou version n'est modifié ;
- aucun merge, push, tag ou changement distant n'est effectué.
