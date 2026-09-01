# Oracle de configuration effective du texte simple — lot 3

Date : 2026-09-01

Base inspectée : `S3` / `d77c08ea846474632e94888a7fa74f1ec0dc44ab`

Objet : critères indépendants pour l'API `TextScaler`, sa composition avec un
candidat logique et la parité entre mesure et `RenderParagraph`. Ce document ne
prescrit aucun correctif produit.

## Verdict

Le lot 3 est réalisable sans supprimer l'API historique et sans linéariser le
scaling utilisateur, à trois conditions bloquantes.

1. La configuration doit distinguer les **entrées que le `Text` final doit
   encore transformer** du **paragraphe déjà effectif que le painter doit
   mesurer**. Injecter dans `Text` le style ou le strut déjà transformé par
   `MediaQuery` rendrait le code dépendant de l'idempotence actuelle des
   overrides et autoriserait une double application future.
2. Le candidat reste une taille logique. Pour une référence strictement
   positive, le scaler du candidat applique le ratio avant la courbe
   utilisateur :

   ```text
   candidateScaler.scale(size)
     = userScaler.scale(size * candidate / reference)
   ```

   Ni `TextScaler.textScaleFactor`, ni un ratio calculé après
   `userScaler.scale`, ni un nouveau `TextScaler.linear` ne peut remplacer
   cette composition.
3. Le painter principal reproduit le layout de `RenderParagraph`, y compris
   `minWidth`, la largeur infinie hors wrap, le cas spécial `ellipsis` et la
   comparaison de `textSize` à la taille contrainte. Un test qui inspecte
   uniquement le widget `Text` n'est pas une preuve de parité.

Les sources exactes Flutter `3.41.0` et `3.47.2` donnent le même contrat pour
ces trois points. Le lot peut donc utiliser une seule implémentation, sans shim
par version.

## Périmètre normatif

Cet oracle couvre :

- `AutoSizeText(String, ...)` et le texte simple sans enfant inline ;
- l'ajout des deux paramètres publics aux deux constructeurs, y compris
  `AutoSizeText.rich`, leur dépréciation et leurs validations communes ;
- une référence logique **strictement positive** ;
- la configuration de paragraphe qui affecte le fit du texte simple ;
- le painter principal et le contrôle auxiliaire de `wrapWords: false` pour une
  chaîne simple.

Il ne couvre pas :

- les runs de `AutoSizeText.rich`, leur clonage ou leurs métadonnées ;
- une référence de taille zéro ; elle reste valide selon l'oracle du lot 2,
  mais sa sémantique de rendu appartient au lot 4 et ne doit être ni rejetée,
  ni remplacée par un epsilon dans ce lot ;
- `WidgetSpan` et les dimensions de placeholders ;
- la publication, la projection ou la convergence d'un `AutoSizeGroup` ;
- les intrinsics, le dry layout et le futur render object ;
- de nouveaux paramètres publics `textWidthBasis` ou `textHeightBehavior`.

Le lot 3 peut conserver un smoke historique de groupe homogène linéaire, mais
ce test ne définit aucune nouvelle unité de groupe et ne permet pas de
revendiquer le support des groupes non linéaires.

## Définitions et invariants de scaling

Pour tout appel du fitter de texte simple :

- `reference` est le `fontSize` racine effectif avant accessibilité, après
  fusion avec `DefaultTextStyle` et fallback historique à `14.0` ;
- `candidate` est une valeur logique exacte fournie par `_CandidateSet` ;
- `ratio = candidate / reference` est calculé seulement si `reference > 0` ;
- `userScaler` est le scaler explicite, le scaler linéaire de compatibilité ou
  le scaler ambiant selon la priorité définie plus bas ;
- la taille racine effective est
  `userScaler.scale(candidate)`, ce qui est aussi
  `candidateScaler.scale(reference)` ;
- le style racine conserve `reference` comme `fontSize` : le candidat est porté
  par `candidateScaler`, pas appliqué une seconde fois au style ;
- le même `candidateScaler` est donné au painter et au `Text` final. Il scale
  donc aussi le `fontSize` explicite du strut selon le même ratio ;
- le prédicat de fit suppose que `userScaler.scale` est monotone non
  décroissant sur toutes les tailles atteintes. Un plateau est valide. Un
  scaler décroissant rend la dichotomie non définie et reste hors contrat ;
  échantillonner quelques valeurs ne constitue pas une validation fiable de
  cette propriété.

### Validation de chaque appel

Le wrapper privé valide, avant et après chaque délégation au scaler utilisateur :

1. `size`, `candidate`, `reference` et le résultat de
   `size * candidate / reference` sont finis et supérieurs ou égaux à zéro ;
2. `reference` est strictement positif sur ce chemin ;
3. le résultat de `userScaler.scale(adjustedSize)` est fini et supérieur ou
   égal à zéro ;
4. la taille racine effective utilisée comme résultat du fitter est obtenue par
   cet appel validé, jamais par le getter de compatibilité.

Une violation produit `ArgumentError` en debug comme en release. Une exception
lancée directement par un scaler personnalisé reste son exception et n'est pas
transformée. Les résultats `0.0` sont valides ; NaN, les deux infinis et toute
valeur négative sont rejetés.

Le getter `candidateScaler.textScaleFactor`, requis par l'interface Flutter,
est seulement une estimation de compatibilité. Pour une référence positive,
l'estimation minimale cohérente est la valeur validée
`candidateScaler.scale(reference) / reference`, elle-même contrôlée comme finie
et non négative. Aucun chemin de recherche, mesure, rendu ou résultat ne doit
lire ce getter.

### Égalité et hash

Le scaler composé est immuable. Deux instances sont égales si et seulement si
elles ont :

- le même scaler source selon `userScaler == other.userScaler` ;
- le même `candidate` ;
- la même `reference`.

`hashCode` combine exactement ces trois valeurs, par exemple avec
`Object.hash(userScaler, candidate, reference)`. L'identité est un raccourci
autorisé, pas le seul cas d'égalité. Une différence de candidat ou de référence
doit rester observable même si deux valeurs donnent momentanément la même
sortie sous un scaler à plateau. Cette règle permet aux setters Flutter qui
comparent les scalers d'éviter les relayouts inutiles sans masquer un changement
de domaine logique.

## API publique minimale

Les deux constructeurs restent `const` et reçoivent, à côté de l'ancien
paramètre :

```dart
@Deprecated('Use textScaler instead.')
double? textScaleFactor,
TextScaler? textScaler,
```

Le champ public `textScaleFactor` reste présent et porte lui aussi
`@Deprecated`; un nouveau champ final `TextScaler? textScaler` est ajouté.
Aucun autre symbole public n'appartient au lot.

Chaque liste d'initialisation conserve l'assertion const-compatible :

```text
assert(textScaler == null || textScaleFactor == null)
```

Le chemin runtime répète obligatoirement le contrôle avant de choisir un
scaler et lève `ArgumentError` si les deux valeurs sont présentes. L'assertion
ne remplace pas cette branche, puisqu'elle disparaît en release.

Après exclusion mutuelle, la résolution est exactement :

| Priorité | Condition | Scaler utilisateur |
|---:|---|---|
| 1 | `textScaler != null` | instance explicite, y compris `TextScaler.noScaling` |
| 2 | ancien facteur présent | `TextScaler.linear(textScaleFactor)` après validation runtime du facteur |
| 3 | aucun paramètre | `MediaQuery.textScalerOf(context)` |

Le facteur historique accepte zéro et toute valeur finie positive. NaN, les
deux infinis et les valeurs négatives lèvent `ArgumentError` avant la création
de `TextScaler.linear`. Fournir `TextScaler.noScaling` neutralise seulement
l'accessibilité ambiante ; l'auto-size par `candidate / reference` reste actif.

## Résolution exacte de la configuration effective

La configuration privée est reconstruite à chaque build. Elle ne cache pas de
`BuildContext`, de valeur `MediaQuery` ou de `DefaultTextStyle` entre deux
frames. Les appels `...of(context)` ci-dessous enregistrent ainsi les
dépendances héritées nécessaires au rebuild.

### Styles avant et après `MediaQuery`

Soit `defaultTextStyle = DefaultTextStyle.of(context)`.

1. Le style racine avant accessibilité, `baseStyle`, suit `Text` puis le
   fallback historique du package :

   ```text
   baseStyle = widget.style
   si widget.style == null ou widget.style.inherit :
     baseStyle = defaultTextStyle.style.merge(widget.style)
   si baseStyle.fontSize == null :
     baseStyle = baseStyle.copyWith(fontSize: 14.0)
   ```

2. Le style donné au painter, `measurementStyle`, part de `baseStyle` :

   ```text
   si MediaQuery.boldTextOf(context) :
     measurementStyle = measurementStyle.merge(
       const TextStyle(fontWeight: FontWeight.bold),
     )

   measurementStyle = measurementStyle.merge(TextStyle(
     height: MediaQuery.maybeLineHeightScaleFactorOverrideOf(context),
     letterSpacing: MediaQuery.maybeLetterSpacingOverrideOf(context),
     wordSpacing: MediaQuery.maybeWordSpacingOverrideOf(context),
   ))
   ```

Les valeurs non nulles des trois overrides **remplacent** les propriétés du
style ; elles ne les multiplient pas et ne s'y ajoutent pas. `boldText` remplace
de même le poids par `FontWeight.bold` (`w700`). Flutter 3.41.0 et 3.47.2
transforment donc un poids explicite `w900` en `w700`; calculer le poids le plus
fort ne reproduirait pas `Text.build`.

`MediaQueryData.paragraphSpacingOverride` n'est pas un quatrième override à
copier : `Text.build` contient encore un TODO à son sujet sur les deux tags et
ne l'applique pas à ce paragraphe.

Le span simple du painter est équivalent à celui de `Text.build` : texte de
`widget.data`, `measurementStyle`, et `locale: widget.locale`. Le locale du
span reste la valeur explicite nullable ; le locale de paragraphe est résolu
séparément ci-dessous.

### Strut

Soit `lineHeightOverride` le premier override précédent :

```text
measurementStrut = widget.strutStyle == null
  ? null
  : widget.strutStyle.merge(StrutStyle(height: lineHeightOverride))
```

Un override de hauteur ne crée jamais un strut quand l'appelant n'en a pas
fourni. S'il existe, seul son `height` est remplacé ; famille, fallbacks,
`fontSize`, leading, poids, style et `forceStrutHeight` sont conservés. Le
`candidateScaler` scale ensuite son `fontSize` dans `TextPainter` comme dans
`RenderParagraph`.

### Propriétés du paragraphe

| Propriété effective | Résolution exacte pour la mesure |
|---|---|
| `textAlign` | `widget.textAlign ?? defaultTextStyle.textAlign ?? TextAlign.start` |
| `textDirection` | `widget.textDirection ?? Directionality.of(context)` |
| `span locale` | `widget.locale`, nullable, comme le `TextSpan` créé par `Text.build` |
| `paragraph locale` | `widget.locale ?? Localizations.maybeLocaleOf(context)` |
| `softWrap` | `widget.softWrap ?? defaultTextStyle.softWrap` |
| `overflow` | `widget.overflow ?? measurementStyle.overflow ?? defaultTextStyle.overflow` |
| `maxLines` | `widget.maxLines ?? defaultTextStyle.maxLines` |
| `textWidthBasis` | `defaultTextStyle.textWidthBasis` ; aucune nouvelle API publique |
| `textHeightBehavior` | `defaultTextStyle.textHeightBehavior ?? DefaultTextHeightBehavior.maybeOf(context)` |
| `ellipsis` du painter | `"\u2026"` seulement si l'overflow effectif vaut `TextOverflow.ellipsis`, sinon `null` |

`TextOverflow.visible`, `clip` et `fade` partagent donc un painter sans
ellipsis. Leur différence concerne la peinture de `RenderParagraph`, pas la
décision de largeur du fitter. `TextStyle.overflow` précède bien l'overflow de
`DefaultTextStyle` quand le paramètre du widget est absent.

### Entrées du `Text` final : aucune double application

Le painter consomme `measurementStyle` et `measurementStrut`. Le `Text` final
ne doit pas recevoir ces deux valeurs déjà transformées.

- son `style` est le `widget.style` original ; si et seulement si le
  `baseStyle.fontSize` résolu était nul avant le fallback, une copie du style
  source reçoit `fontSize: 14.0`. `Text.build` effectue ensuite lui-même la
  fusion avec `DefaultTextStyle`, le gras et les trois overrides une fois ;
- son `strutStyle` reste `widget.strutStyle`, afin que `Text.build` fusionne
  l'override de hauteur une fois ;
- son `textScaler` est le `candidateScaler` explicite. `Text.build` ne relit
  donc pas le scaler ambiant et n'applique pas une seconde échelle ;
- `textAlign`, `textDirection`, `locale`, `softWrap`, `overflow` et `maxLines`
  restent les entrées publiques originales. Le `Text` les résout selon le même
  contexte que la configuration de mesure ;
- `textWidthBasis` et `textHeightBehavior`, absents de l'API publique
  `AutoSizeText`, reçoivent les valeurs effectives héritées calculées plus haut ;
- `textKey` et `semanticsLabel` restent transmis comme avant.

Un test bloquant combine deux observations : le `Text` keyed conserve les
entrées pré-override, tandis que le `RenderParagraph` sous-jacent possède le
style, le strut, le scaler et les métriques post-override attendus. L'inspection
du widget seule ne suffit toujours pas.

## Oracle de largeur et de fit

`TextPainter` ne possède pas de propriété `softWrap`. Comme
`RenderParagraph._adjustMaxWidth`, le fitter calcule :

```text
layoutMaxWidth = effectiveSoftWrap
              || effectiveOverflow == TextOverflow.ellipsis
  ? constraints.maxWidth
  : double.infinity
```

Puis il appelle exactement :

```text
painter.layout(
  minWidth: constraints.minWidth,
  maxWidth: layoutMaxWidth,
)
```

Omettre `minWidth` crée une divergence sous contraintes tight ou avec un
minimum non nul, notamment pour `TextWidthBasis.parent`. Avec une largeur
infinie et un alignement non gauche, `TextPainter` effectue lui-même son
relayout intrinsèque ; le fitter ne doit pas introduire un cas spécial
supplémentaire.

Après layout :

```text
textSize = painter.size
renderSize = constraints.constrain(textSize)

fits = !painter.didExceedMaxLines
    && !(renderSize.width < textSize.width)
    && !(renderSize.height < textSize.height)
```

Les comparaisons sont strictes comme dans `RenderParagraph.performLayout`, sans
epsilon typographique. Cette formulation est équivalente à comparer aux maxima
réels sous des `BoxConstraints` valides, tout en reproduisant aussi les minima.
Le fait qu'un overflow soit `visible` ne transforme pas un dépassement en fit :
il change seulement le clipping. Avec ellipsis, le painter peut avoir une
largeur contrainte ; `didExceedMaxLines` reste alors indispensable pour détecter
la troncature.

Le test témoin doit comparer au moins `TextPainter.size` à
`RenderParagraph.textSize`, `didExceedMaxLines` des deux côtés et la taille
contrainte du render object. Comparer seulement `RenderParagraph.size` au
painter serait faux sous contraintes tight, car `size` est déjà contrainte.

### `wrapWords: false`

`wrapWords` est une politique propre au package et ne remplace pas `softWrap`.
Pour une chaîne simple, son contrôle auxiliaire peut transformer les mots en
lignes de test, mais il doit utiliser le même style effectif, le même
`candidateScaler`, le strut, l'alignement, la direction, le locale,
`TextWidthBasis` et `TextHeightBehavior`. Il vérifie chaque mot contre
`constraints.maxWidth` avec un painter sans ellipsis et ne prétend pas être le
`RenderParagraph` final. Ses painters restent libérés dans des `finally` selon
le lot 1.

La segmentation fidèle d'un arbre riche, NBSP/NNBSP et la conservation des
runs appartiennent au lot 4 ; le lot 3 ne doit pas aplatir un span riche sous
prétexte de généraliser ce contrôle.

## Table de tests rouges / verts

Tous les fichiers touchés gardent un `group()` et des noms commençant par
« should ». Les régressions de parité utilisent un vrai `RenderParagraph` et
un painter témoin libéré, pas seulement `tester.widget<Text>`.

| Priorité | Régression capable d'échouer | Rouge attendu sur `d77c08e` | Vert obligatoire du lot 3 |
|---|---|---|---|
| P0 | les deux constructeurs restent `const` et exposent `textScaler` plus l'ancien paramètre déprécié | `textScaler` ne compile pas | les deux appels const compilent ; aucune autre API publique ajoutée |
| P0 | `textScaler` et `textScaleFactor` simultanés, sur les deux constructeurs | aucun contrat d'exclusion moderne | assertion en debug et `ArgumentError` depuis le résolveur runtime sans assertions |
| P0 | ancien facteur NaN, infini ou négatif ; zéro accepté | seules des assertions ou une valeur invalide atteint le painter | `ArgumentError` public pour les invalides, rendu nul valide pour zéro |
| P0 | priorité explicite / ancien / ambiant avec `TextScaler.noScaling` explicite | scaler explicite absent, ambiant réduit à un double | chaque branche produit le scaler exact attendu et `noScaling` masque l'ambiant |
| P0 | scaler non linéaire dont le getter vaut `99` mais `scale(30) == 36` | taille racine calculée depuis le getter, par exemple `30 * 99` | painter et render utilisent `scale(candidate)` ; aucun getter lu |
| P0 | composition non linéaire avec candidat différent de la référence | résultat linéarisé ou ratio appliqué après la courbe | pour plusieurs tailles simples positives, résultat exact `source.scale(size * candidate / reference)` |
| P0 | sorties NaN, infinie et négative, séparément à la racine et à la taille du strut | valeur invalide atteint Flutter ou produit une assertion moteur | chaque sortie réellement appelée lève `ArgumentError`, debug et release |
| P0 | égalité/hash de scalers composés | aucune classe composée | mêmes trois champs : égalité et hash égaux ; source, candidat ou référence différente : inégalité, y compris sous plateau |
| P0 | `DefaultTextStyle`, style `inherit:true`/`false` et fallback 14 | cas partiels mesurés/rendus différemment | `baseStyle` et le style de `RenderParagraph` sont identiques au pipeline Flutter ; aucun double candidat |
| P0 | `boldText` avec fontes regular/bold de métriques distinctes, plus entrée `w900` | la mesure ignore le gras et conserve un candidat trop grand | candidat réduit si nécessaire ; le render porte exactement `FontWeight.bold` (`w700`) ; métriques painter/render égales |
| P0 | chacun des trois overrides isolé, puis modification entre deux pumps | mesure ignore les overrides ou garde l'ancienne frame | height/letter/word remplacent les valeurs source ; nouveau candidat et nouvelles métriques concordent avec le render |
| P0 | strut forcé de taille 100 dans une hauteur 60, strut absent, puis override de hauteur | mesure scale le strut différemment du rendu ; replacement faux | strut absent reste nul ; strut fourni et son override donnent mêmes taille/fit/replacement que `RenderParagraph` |
| P0 | `softWrap:false` explicite et hérité avec `clip`, `fade`, `visible`, puis `ellipsis` | la mesure wrappe toujours à `maxWidth` | largeur infinie pour les trois premiers, contrainte pour ellipsis, puis comparaison à la contrainte réelle et à `didExceedMaxLines` |
| P0 | contraintes avec `minWidth > 0`, tight et loose, sous `parent` puis `longestLine` hérité | painter omet `minWidth` et les bases ambiantes | `painter.size == render.textSize`, taille render égale à `constraints.constrain(textSize)` |
| P0 | `maxLines`, overflow explicite, `TextStyle.overflow`, puis fallback `DefaultTextStyle` | ordre incomplet et ellipsis absent du painter | priorité exacte, troncature détectée, et `overflowReplacement` suit le booléen du plus petit candidat |
| P0 | direction RTL et locale héritées puis explicites, avec fixture dont les métriques diffèrent du fallback LTR/locale par défaut | painter force LTR/null | candidat et métriques identiques au render dans les quatre variantes ; la fixture prouve d'abord que les métriques témoins diffèrent |
| P0 | `DefaultTextStyle.textWidthBasis`, son `textHeightBehavior`, puis `DefaultTextHeightBehavior` quand le premier est nul | ces valeurs ne sont pas transmises aux painters | ordre d'héritage exact et métriques/baselines identiques, sans nouveaux paramètres publics |
| P0 | changement de scaler, bold, overrides et defaults entre deux pumps sans changer l'instance `AutoSizeText` | résultat précédent ou estimation linéaire persiste | nouvelle configuration reconstruite et nouveau `RenderParagraph` concordant |
| P1 | `wrapWords:false` sur texte simple, mot trop large et texte qui tient | contrôle auxiliaire conserve l'ancienne configuration dépréciée | même configuration effective, retour anticipé correct et aucun painter en fuite |
| P1 | historique #25, min/max et presets sous scaling linéaire | risque de changer les résultats valides du package | mêmes tailles effectives et mêmes décisions de fit ; le candidat appartient toujours au domaine du lot 2 |

Un test direction/locale, bold ou `TextHeightBehavior` qui emploie une fixture
où les deux branches ont accidentellement les mêmes métriques n'est pas une
régression valide. Il doit d'abord établir la différence du témoin, puis
vérifier le choix d'`AutoSizeText`.

La preuve release de l'exclusion mutuelle et des validations ne peut pas se
limiter au widget test debug, car l'assertion du constructeur l'intercepte. Le
minimum acceptable est un test direct du résolveur pur plus un petit probe
exécuté avec assertions désactivées ; les deux constructeurs publics restent
couverts en debug.

## Pièges de mise en œuvre

- Lire `MediaQuery.textScaleFactorOf` ou `TextScaler.textScaleFactor` et
  construire ensuite un scaler linéaire.
- Calculer `userScaler.scale(size) * ratio` au lieu de scaler la taille déjà
  multipliée par le ratio.
- Mettre le candidat dans `TextStyle.fontSize` **et** donner le scaler composé,
  ce qui applique deux fois l'auto-size.
- Donner le scaler utilisateur brut au strut : sa taille resterait hors du
  ratio candidat alors que Flutter scale le `StrutStyle.fontSize` avec le
  `TextScaler` du paragraphe.
- Réinjecter `measurementStyle` ou `measurementStrut` dans `Text` et dépendre
  de l'idempotence actuelle des overrides.
- Multiplier `TextStyle.height` par l'override, ajouter les spacing, préserver
  `w900`, ou créer un strut absent : les quatre comportements divergent des
  sources Flutter exactes.
- Appliquer `paragraphSpacingOverride` alors que `Text.build` 3.41/3.47 ne le
  fait pas.
- Oublier `TextStyle.overflow` dans la priorité ou traiter `fade` comme
  ellipsis.
- Utiliser systématiquement `constraints.maxWidth`; utiliser systématiquement
  l'infini est tout aussi faux à cause de `softWrap` et d'ellipsis.
- Passer seulement `maxWidth` au painter et perdre `constraints.minWidth`.
- Déclarer un texte ellipsé comme fit parce que sa largeur contrainte tient,
  sans lire `didExceedMaxLines`.
- Comparer le painter à `RenderParagraph.size` au lieu de `textSize`, ou ne
  comparer que le widget `Text` public.
- Garder les fallbacks historiques `TextDirection.ltr` et `locale: null` au
  lieu de lire les ancêtres effectifs.
- Confondre le locale explicite du `TextSpan` avec le locale effectif du
  paragraphe.
- Cacher la configuration entre builds et manquer une mise à jour d'un aspect
  `MediaQuery` ou de `DefaultTextHeightBehavior`.
- Étendre le lot aux runs riches, à la référence zéro, aux groupes ou aux
  placeholders pour rendre un test prématuré vert.

## Différences Flutter 3.41.0 / 3.47.2

Tags et révisions exacts inspectés :

| Flutter | Dart | Révision framework |
|---|---|---|
| 3.41.0 | 3.11.0 | `44a626f4f0027bc38a46dc68aed5964b05a83c18` |
| 3.47.2 | 3.13.2 | `d3b14c876900e553bc736ca19295fc09e3853e8e` |

| Surface | Comparaison exacte | Conséquence pour le lot 3 |
|---|---|---|
| `Text.build` | pipeline style/bold/trois overrides/strut, priorité des scalers et résolution du paragraphe inchangés | une seule configuration normative |
| `MediaQuery` | getters du scaler, de bold et des trois overrides inchangés ; 3.47 ajoute notamment les rayons d'angle d'écran | aucune branche de compatibilité |
| `RenderParagraph` | `_adjustMaxWidth`, layout min/max, calcul de `textSize`, contrainte de `size` et détection d'overflow inchangés | même oracle de largeur et de fit |
| `RichText` / `RenderParagraph` | 3.47 transmet un `devicePixelRatio` utilisé pour régénérer la peinture web ; absent en 3.41 | n'affecte pas les métriques `TextPainter` du lot 3 |
| `TextPainter` | constructeur, scaler, ellipsis, `textWidthBasis`, `textHeightBehavior`, `layout` et tailles inchangés | même painter témoin |
| `TextPainter` dégénéré | 3.47 ajoute un fallback de hauteur pour certains calculs de caret quand `fontSize` ou le scaler vaut zéro | hors de l'oracle positif du lot 3 ; ne justifie pas de rejeter la référence zéro |
| `TextScaler` | 3.47 corrige la composition de plages de `_ClampedTextScaler.clamp` disjointes | le scaler candidat n'appelle pas `clamp`; aucun effet |

Un probe widget temporaire a été exécuté sur les deux bundles exacts. Il a
comparé un painter manuel au vrai `RenderParagraph` pour style hérité, entrée
`w900` avec bold, trois overrides, strut forcé, scaler non linéaire composé,
alignement, RTL, locale thaïe, `TextWidthBasis`, `TextHeightBehavior`,
`minWidth: 80` et largeur infinie. Un second cas a opposé clip et ellipsis avec
`softWrap: false`. Résultat : **2/2 verts sur 3.41.0 et 2/2 verts sur 3.47.2**.
Le fichier du probe a ensuite été supprimé.

Sources primaires :

- [`Text.build`, Flutter 3.41.0](https://github.com/flutter/flutter/blob/3.41.0/packages/flutter/lib/src/widgets/text.dart) et [3.47.2](https://github.com/flutter/flutter/blob/3.47.2/packages/flutter/lib/src/widgets/text.dart) ;
- [`RichText`, Flutter 3.41.0](https://github.com/flutter/flutter/blob/3.41.0/packages/flutter/lib/src/widgets/basic.dart) et [3.47.2](https://github.com/flutter/flutter/blob/3.47.2/packages/flutter/lib/src/widgets/basic.dart) ;
- [`RenderParagraph`, Flutter 3.41.0](https://github.com/flutter/flutter/blob/3.41.0/packages/flutter/lib/src/rendering/paragraph.dart) et [3.47.2](https://github.com/flutter/flutter/blob/3.47.2/packages/flutter/lib/src/rendering/paragraph.dart) ;
- [`TextPainter`, Flutter 3.41.0](https://github.com/flutter/flutter/blob/3.41.0/packages/flutter/lib/src/painting/text_painter.dart) et [3.47.2](https://github.com/flutter/flutter/blob/3.47.2/packages/flutter/lib/src/painting/text_painter.dart) ;
- [`TextScaler`, Flutter 3.41.0](https://github.com/flutter/flutter/blob/3.41.0/packages/flutter/lib/src/painting/text_scaler.dart) et [3.47.2](https://github.com/flutter/flutter/blob/3.47.2/packages/flutter/lib/src/painting/text_scaler.dart) ;
- [`MediaQuery`, Flutter 3.41.0](https://github.com/flutter/flutter/blob/3.41.0/packages/flutter/lib/src/widgets/media_query.dart) et [3.47.2](https://github.com/flutter/flutter/blob/3.47.2/packages/flutter/lib/src/widgets/media_query.dart) ;
- [migration officielle de `textScaleFactor`](https://docs.flutter.dev/release/breaking-changes/deprecate-textscalefactor).

## Critères bloquants avant merge du lot 3

Le lot n'est acceptable que si tous les points suivants sont vrais.

1. Les preuves rouges du parent sont archivées pour chaque cause P0, puis les
   mêmes tests sont verts sur la tête. Un rouge RichText, groupe ou référence
   zéro ne compte pas pour le lot simple.
2. Les deux constructeurs restent `const`; l'ancien paramètre et son champ sont
   dépréciés mais présents ; exclusion mutuelle et facteur invalide sont
   contrôlés en runtime.
3. Aucun code produit n'utilise `MediaQuery.textScaleFactorOf`, le paramètre
   déprécié de `TextPainter`, le paramètre déprécié de `Text` ou le getter
   `TextScaler.textScaleFactor` pour décider d'une taille.
4. Toute sortie du scaler composée réellement utilisée est finie et non
   négative, et le scaler a une égalité/hash cohérents.
5. Mesure et rendu simples ont le même scaler et le même paragraphe effectif.
   Les tests comparent les métriques au `RenderParagraph` réel, y compris strut,
   héritage et bascules entre frames.
6. Une revue statique confirme que le `Text` final reçoit style/strut
   pré-override et scaler composé, tandis que les painters reçoivent les valeurs
   post-override. Cette séparation ne peut pas être prouvée uniquement par des
   overrides actuellement idempotents.
7. La règle de largeur inclut `constraints.minWidth`, le cas ellipsis et
   `constraints.constrain(textSize)` ; `didExceedMaxLines` participe toujours
   au fit.
8. Tous les painters temporaires, y compris le contrôle `wrapWords: false` et
   les témoins de test, sont libérés dans un `finally`.
9. Sur les bundles exacts Flutter 3.41.0 et 3.47.2 : suite ciblée puis complète
   vertes et `flutter analyze --fatal-infos --fatal-warnings` vert. Le format est
   produit par 3.47.2 puis recompilé et retesté par 3.41.0.
10. Le diff reste limité à l'API/scaling/configuration du texte simple et à ses
    tests. README, changelog, runs RichText, référence zéro, groupes,
    `WidgetSpan`, intrinsics et nouvelle API de parité restent dans leurs lots.

## Hors contrat et overengineering

- Approximer ou reconstituer une courbe Android/iOS à partir de quelques
  échantillons.
- Prouver globalement la monotonicité d'un scaler arbitraire à l'exécution.
- Ajouter un shim `dynamic` pour Flutter antérieur à 3.41.
- Exposer publiquement le scaler composé, la configuration effective,
  `textWidthBasis`, `textHeightBehavior` ou des métriques de paragraphe.
- Remplacer le `Text` final par un nouveau render object dans ce lot.
- Copier les helpers privés récursifs de `Text.build` pour du texte simple.
- Ajouter un epsilon de fit ou compenser les métriques de fonte à la main.
- Définir la référence zéro, les runs hétérogènes, la valeur de groupe ou le
  facteur d'un `WidgetSpan` avant leurs lots dédiés.
