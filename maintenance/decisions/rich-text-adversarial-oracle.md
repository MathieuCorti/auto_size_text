# Oracle adversarial — RichText, Unicode et aliasing du lot 4

Date : 2026-09-01

Base revue : `3a1c343` (`S4`), branche d'implémentation attendue
`codex/impl-rich-text`.

Ce document challenge et précise
`maintenance/decisions/rich-text-oracle.md`. Il ne modifie pas son contrat. Les
probes temporaires ont été supprimés et aucun code de production ou de test ne
fait partie de cette décision.

## Verdict

Le gate doit observer le même paragraphe que Flutter, pas une représentation
aplatie qui lui ressemble. La segmentation de `wrapWords: false` part de
`toPlainText(includeSemanticsLabels: false)`, conserve des offsets UTF-16 dans
l'arbre fidèle, puis interroge **toutes** les boxes de chaque plage sur un
painter non wrappé. La largeur d'une plage bidi est la somme des avances de ses
boxes ; ce n'est ni la première box ni l'étendue entre les extrêmes.

Le parent synthétique, la composition du scaler par run, le cas `F == 0` et le
clone de spacing doivent rester exactement parallèles à `Text.build`. Un test
de propriété seul ne suffit pas : le gate combine arbre rendu, métriques,
boxes, interactions et sémantiques réelles.

Le lot 4 ne peut promettre aucune mesure de `WidgetSpan`. Il peut seulement
préserver l'objet pendant une transformation d'arbre qui ne tente pas de le
mesurer.

## Sources et probes croisés

Les sources locales exactes Flutter 3.41.0 et 3.47.2 ont été relues dans :

- `packages/flutter/lib/src/widgets/text.dart`, pour `Text.build` et
  `_OverridingTextStyleTextSpanUtils` ;
- `packages/flutter/lib/src/painting/text_span.dart`, pour l'ordre préfixe,
  `build`, `computeToPlainText`, les métadonnées et le scaling par run ;
- `packages/flutter/lib/src/painting/inline_span.dart`, pour le contrat de
  `toPlainText` ;
- `packages/flutter/lib/src/painting/text_painter.dart` et
  `packages/flutter/lib/src/rendering/paragraph.dart`, pour
  `getBoxesForSelection`, délégué à `Paragraph.getBoxesForRange` ;
- `packages/flutter/lib/src/widgets/widget_span.dart`, pour l'extraction des
  enfants et l'exigence de dimensions réelles.

Les comportements pertinents sont identiques sur les deux SDK. Des probes
temporaires exécutés sur les deux versions ont en outre établi :

- `A😀e\u0301\u00A0אב\u202FZ` occupe dix code units UTF-16 ; sélectionner une
  seule moitié de `😀` ne retourne aucune box, tandis que `[1, 3)` retourne la
  box du glyph entier ;
- `RegExp(r'\s')` reconnaît espace, tabulation, LF, U+00A0 et U+202F ; les deux
  derniers doivent donc être retirés explicitement de l'ensemble des
  séparateurs du package ;
- un NBSP peut subir une coupure d'urgence : à une largeur égale à la moitié de
  son avance non wrappée, `AA\u00A0BB` rend deux lignes. Le line count du
  paragraphe contraint n'est pas l'oracle de la plage liée ;
- en RTL, la plage liée `A\u00A0אב` au milieu d'un paragraphe a deux boxes
  pouvant être physiquement disjointes. Leur somme et leur bounding extent
  divergent ;
- sous overrides de spacing, Flutter clone les `TextSpan` standards et leurs
  listes, conserve recognizer, curseur, callbacks et métadonnées, mais garde un
  sous-type de `TextSpan` et un `WidgetSpan` par identité ;
- deux demi-surrogates placées dans deux `TextSpan.text` distincts sont
  concaténées en un emoji par `toPlainText`, mais chaque ajout au paragraphe
  produit `ArgumentError: string is not well-formed UTF-16`. `TextSpan.build`
  signale l'erreur puis substitue U+FFFD ; le binding widget expose les erreurs
  et invalide le témoin. Ce fixture est donc exclu des tests du lot 4.

### Arbitrage du probe split-surrogate

Le cas minimal rejoué était exactement :

```dart
const splitSurrogateSpan = TextSpan(
  text: '\ud83d',
  children: <InlineSpan>[TextSpan(text: '\ude00')],
);
```

| SDK exact | Commit Flutter | `TextPainter.layout` instrumenté | `Text.rich` / `RenderParagraph` |
|---|---|---|---|
| 3.41.0 | `44a626f4f0027bc38a46dc68aed5964b05a83c18` | Deux `ArgumentError` transmises à `FlutterError.onError`, puis largeur de deux U+FFFD si le handler les capture | Deux exceptions visibles du binding ; témoin invalide |
| 3.47.2 | `d3b14c876900e553bc736ca19295fc09e3853e8e` | Même résultat | Même résultat |

La pile commune part de `_NativeParagraphBuilder.addText`
(`dart:ui/text.dart:3721` en 3.41, `:3724` en 3.47), traverse
`TextSpan.build` (`text_span.dart:298`, puis `:316` pour l'enfant),
`TextPainter._createParagraph` (`text_painter.dart:1203`) et
`TextPainter.layout` (`:1264`). Le chemin widget continue par
`RenderParagraph._layoutTextWithConstraints` / `performLayout` : lignes
852/915 en 3.41 et 903/966 en 3.47.

Le probe initial utilisait un `test` non widget, ne remplaçait pas
`FlutterError.onError` et ne lisait que la largeur après substitution. Il n'a
donc pas aplati l'arbre et n'utilisait pas une autre version, mais il a masqué
les erreurs signalées par `TextSpan.build`. La conclusion métrique qui en avait
été tirée est retirée.

Les valeurs métriques des probes ne sont pas des golden numbers. Les tests
committés dérivent leurs seuils de témoins `Text.rich` indépendants avec les
fontes déterministes du dépôt.

## Définitions de test

- `F` : taille logique du parent effectif avant auto-size et scaler, avec le
  fallback 14 du lot 3 ; elle est finie et `>= 0`.
- `C` : candidat logique du domaine du lot 2.
- `S` : taille logique héritée ou explicite d'un run.
- `U` : scaler utilisateur effectif du lot 3.
- `N` : nombre de code units du texte visuel.
- `K` : nombre de plages liées non vides après coalescence des séparateurs.
- Une plage est `[start, end)`, dans les unités de `String.length`,
  `TextSelection` et `Paragraph.getBoxesForRange`.
- Son avance est `sum(abs(box.right - box.left))` sur **toutes** les boxes du
  painter non wrappé fidèle. Une box de largeur nulle de newline n'entre jamais
  dans une plage non vide, puisque CR/LF sont des séparateurs.

## Matrice entrée, résultat, mutants et exclusions

| Entrée adversariale | Résultat oracle | Test discriminant / mutant tué | Exclusion ou limite explicite |
|---|---|---|---|
| Arbre imbriqué dont le texte racine précède ses enfants | Le parent synthétique porte le style effectif et contient le span source dans un enfant unique. Texte, ordre, profondeur et limites de runs restent inchangés. | Comparer topologie, boxes et métriques au `Text.rich` témoin. Tue le clone racine `style: source.style ?? parentStyle` et tout flattening. | Aucune normalisation Unicode ni fusion de spans équivalents. |
| Span racine avec seulement `color`, parent effectif 30 | Le run hérite taille, famille, poids, hauteur et spacing du parent, puis scale comme un run de taille 30. | Contrainte entre deux candidats témoins, puis égalité des boxes/baseline. Tue la prise de `source.style?.fontSize` comme référence. | Le fallback de fonte suit Flutter ; le lot ne choisit pas une fonte Unicode. |
| Emoji complet dans un span imbriqué avant une frontière | L'emoji compte deux code units. Les frontières après lui sont décalées de deux, jamais d'une ; aucune sélection ne commence ou finit au milieu de la paire. | Préfixe `A😀`, plages attendues `[0, 3)` puis offsets suivants ; une sélection d'une moitié retourne zéro box. Tue un scanner en runes/graphemes dont les offsets sont réutilisés comme UTF-16. | Les graphèmes ne définissent pas les séparateurs ; ils servent seulement à rendre l'erreur d'unité observable. |
| Demi-surrogate haute et basse dans deux `TextSpan.text` voisins | Chaque run est mal formé et produit `ArgumentError: string is not well-formed UTF-16`, même si `toPlainText(false)` concatène les code units en `😀`. Le binding rend le witness/fitter/`RenderParagraph` invalide. | Probe diagnostique seulement : capturer `FlutterError.onError` prouve deux erreurs sur les deux SDK. Ne pas committer ce fixture comme test d'acceptation ou oracle métrique. | Entrée UTF-16 invalide par run, exclue du lot 4. Aucun candidat, range ou rendu de remplacement n'est promis. |
| `e` et U+0301 répartis dans deux spans, puis emoji et bidi dans des descendants | Aucun séparateur n'est inventé entre base, combining mark, spans ou changements de direction. La sélection couvre tous leurs code units et toutes leurs boxes. | Styles différents sur au moins trois spans et seuil entre deux candidats témoins. Tue découpage par enfant et test d'une seule box. | Pas de segmentation par grapheme, dictionnaire ou UAX #29. |
| `AA BB`, `AA\tBB`, `AA\nBB`, `AA\r\nBB` | Deux plages `[AA]`, `[BB]`. Séparateurs consécutifs, de début et de fin sont coalescés ; aucune plage vide. Le paragraphe source n'est pas modifié. | Table exacte des ranges plus choix de candidat et boxes rendues. Tue `split` qui conserve des vides ou compte CRLF comme pseudo-mot. | Les autres caractères reconnus par le `RegExp(r'\s')` historique restent séparateurs sauf U+00A0/U+202F. |
| `AA\u00A0BB`, `AA\u202FBB` | Une seule plage liée dans chaque cas. Si son avance excède `maxWidth`, le candidat échoue même si Flutter pratique une coupure d'urgence. | Largeur entre l'avance témoin du candidat haut et celle du suivant ; assert candidat final et boxes. Tue `RegExp(r'\s+')` sans exceptions et le line-count contraint. | Ne promet pas toutes les classes no-break d'UAX #14. |
| `AA\u00A0BB CC\u202FDD` et `AA\u00A0 BB` | Respectivement deux plages liées ; puis `AA\u00A0` et `BB`. NBSP/NNBSP restent dans les ranges, espace normal les termine. | Asserter offsets UTF-16 exacts avant le test métrique. Tue suppression/trim/normalisation des espaces. | Pas de canonicalisation NBSP vers espace. |
| Texte visuel `AA\u00A0BB`, `semanticsLabel: 'AA BB'`, ou inversement | Les ranges dépendent exclusivement du texte visuel retourné avec `includeSemanticsLabels: false`. Le label ne change ni candidat ni boxes. | Deux arbres identiques hors label, puis même candidat exact et mêmes métriques. Tue l'appel par défaut `toPlainText()`. | Le label continue naturellement d'affecter l'arbre sémantique. |
| Plage liée bidi, par exemple `out A\u00A0אב end`, en LTR puis RTL | `getBoxesForSelection` peut retourner plusieurs boxes. L'avance est leur somme ; l'espace physique laissé par le contenu non sélectionné n'est pas facturé à la plage. | Trois seuils témoins tuent séparément `boxes.single/first`, `max(box.width)` et `max(right)-min(left)`. Vérifier aussi les boxes du `RenderParagraph` final. | Pas de réordonnancement manuel ni de calcul bidi du package. |
| Mot distribué sur trois spans 12/48/24 | Un seul painter fidèle conserve shaping, styles, locale, direction et offsets ; la plage est mesurée via ses boxes. | Largeur entre candidat haut/bas, avec le run 48 rendant le haut trop large. Tue painter monostyle par substring et `words.join('\n')`. | Pas de painter séparé par run ou par mot. |
| `F=20`, `C=10`, runs hérités 20, explicites 40 et 0, `U(s)=s+s²/100` | Entrées de `U` : 10, 20 et 0 ; sorties 11, 24 et 0. Le même scaler composé est donné à la mesure et au rendu. | Recorder qui accepte des appels supplémentaires mais exige ces entrées, plus boxes contre témoin. Tue coefficient global : le run 40 vaudrait 22. | Ne jamais utiliser `textScaleFactor` comme mesure d'un scaler non linéaire. |
| Changement de `U` ou d'override entre deux pumps | Nouveau scaler/arbre de mesure, nouvelles boxes ; source intacte. Chaque spacing est appliqué une seule fois. | Témoin `Text.rich` indépendant avant/après. Tue cache par candidat seul et réinjection d'un arbre déjà overridé dans `Text`. | Aucun cache qui traverse une configuration effective différente. |
| `F=0`, candidat `C`, run hérité | Parent synthétique `fontSize: C`, scaler `U` inchangé ; résultat `U.scale(C)`. Aucun ratio, epsilon, NaN ou no-scaling implicite. | Simple **et** riche, `min=0` puis positif, scaler recorder, boxes témoin. Tue `C/F`, remplacement de zéro par 1 et `TextScaler.noScaling`. | Le plateau est valide ; aucune monotonie artificielle. |
| `F=0`, descendants explicites 0 et 40 | Les descendants gardent 0 et 40 et reçoivent `U.scale(0)` / `U.scale(40)` quel que soit `C`. Seuls les descendants hérités suivent le parent candidat. | Deux candidats, boxes par run, puis cas où tous les runs explicites forment un plateau. Tue multiplication récursive des styles. | Si le plateau tient, la politique normale du domaine choisit le plus grand candidat qui tient. |
| `F=0`, descendant explicite trop large, contrainte minuscule | Le minimum peut échouer réellement. `textFits` est faux ; le replacement est seul monté s'il existe. | Avec/sans replacement et plusieurs rebuilds. Branche texte active : `tester.widget<Text>(find.byKey(textKey))`. Branche replacement : aucune `textKey`. | Aucun fallback qui prétend que le minimum tient. Le type garanti par `textKey` ne change qu'au lot 9. |
| Sans override de spacing | Le span source peut rester le même objet sous le parent synthétique ; toutes ses listes et valeurs restent appartenir à l'appelant. | Captures `identical` avant/après pump et rebuild. Tue clone systématique et mutation en place. | L'identité du parent synthétique n'est pas contractuelle. |
| Override hauteur, letter spacing, word spacing, séparés puis combinés | Chaque objet avec `runtimeType == TextSpan` est cloné ; style mergé ; nouvelle liste au même ordre. Tous les champs de la table ci-dessous sont recopiés. | Comparaison au `RenderParagraph.text` d'un `Text.rich` témoin sous le même `MediaQuery`. Tue clone partiel et double override. | Une égalité entre deux helpers partageant le même clone n'est pas une preuve. |
| Sous-type de `TextSpan`, autre `InlineSpan`, `WidgetSpan` | Même objet, sans descente ni cast supposant un `TextSpan` standard. | Identité dans le clone témoin ; interaction du sous-type si elle est définie. Tue `child is TextSpan` sans garde `runtimeType`. | La présence fidèle du `WidgetSpan` dans le transformateur n'implique pas que `AutoSizeText.rich` puisse le mesurer. |
| Même `TextSpan` standard référencé deux fois | Deux occurrences au même ordre. Sous override, Flutter fabrique deux clones distincts ; l'alias de sortie n'est pas préservé. L'objet source reste inchangé. | Vérifier occurrences et parité Flutter, sans exiger `identical(output[0], output[1])`. Tue mémoïsation qui changerait la politique de Flutter. | L'identité des clones standards n'est pas une API. |
| `UnmodifiableListView<InlineSpan>` comme `children` | Tous les pumps réussissent : l'implémentation ne fait ni écriture, ni tri, ni remplacement dans la liste source. Les listes de clone sont nouvelles. | Snapshot exhaustif + liste non modifiable. Tue `children[i]=`, `sort`, `clear`, `add` et réutilisation d'une liste ensuite modifiée. | La mutation **externe** de `TextSpan.children` après construction est déclarée non supportée par Flutter. |
| Recognizer/callbacks/sémantiques sous override et rebuild | Identités conservées ; tap/long press, entrée/sortie souris et curseur fonctionnent ; label, identifier, locale et spell-out sont observables. Un `AutoSizeText.semanticsLabel` non nul garde sa priorité historique. | Cibler le run par `RenderParagraph.getBoxesForSelection`, envoyer les gestes, activer le semantics handle et inspecter attributs/actions. Tue test limité aux propriétés. | Le test démonte le widget avant de disposer le recognizer détenu par le test. |
| `WidgetSpan` dans l'arbre | La transformation seule ne clone, ne supprime ni ne duplique l'objet. Aucun painter du lot 4 n'invente de `PlaceholderDimensions`. | Preuve structurelle limitée au clone de spacing, avec témoin Flutter. Un test de layout vert grâce à largeur zéro/placeholder ignoré est un échec du gate. | Layout, scaling, paint, baseline, hit test, sémantique enfant, dry et intrinsics sont lot 10. Une garde transitoire ne ferme aucun de ces points. |

## Copie exhaustive des `TextSpan` standards

Sous override, la parité 3.41.0/3.47.2 exige exactement les champs suivants :

| Champ | Oracle d'identité ou de valeur | Mutant tué |
|---|---|---|
| `text` | même `String?` | texte racine omis ou déplacé après les enfants |
| `children` | nouvelle liste, même ordre et mêmes occurrences transformées selon leur type | mutation ou partage de liste de sortie |
| `style` | `style?.merge(override) ?? override` | remplacement du style partiel, double merge |
| `recognizer` | même objet | recognizer recréé, perdu ou disposé par le widget |
| `mouseCursor` | même objet/valeur | retour au curseur dérivé du recognizer |
| `onEnter`, `onExit` | mêmes callbacks | callbacks omis |
| `semanticsLabel` | même valeur | segmentation polluée par le label ou label perdu |
| `semanticsIdentifier` | même valeur | clone basé sur une ancienne signature de `TextSpan` |
| `locale` | même objet/valeur | locale du widget substituée à celle du run |
| `spellOut` | même valeur nullable | `null` transformé en `false` ou attribut perdu |

`TextSpan` ne possède aucun autre champ public à recopier sur les deux SDK
ciblés. Le style, les listes et les spans standards transformés ne sont pas
soumis à un oracle d'identité ; recognizers, curseurs, callbacks, sous-types et
`WidgetSpan` le sont.

## Budget de segmentation et risque de disponibilité

La segmentation ne dépend pas du candidat. Le texte visuel et les ranges
doivent donc être calculés une fois par évaluation de configuration, pas à
nouveau pour chaque candidat.

| Surface | Borne structurelle exigée | Test / revue mutant | Limite de preuve |
|---|---|---|---|
| Scan UTF-16 | Un passage sur `N`, sans `substring`, `split` ou `join` par plage ; `K <= ceil(N / 2)` pour `N > 0`. | Chaîne alternée caractère/espace avec séparateurs initiaux, finaux et consécutifs ; compteur de ranges exact. | `toPlainText` alloue déjà une chaîne de taille `N`. |
| Painters auxiliaires | Au plus un painter fidèle non wrappé par candidat évalué, toujours disposé en `finally`; jamais un painter par plage/run. | Instrumentation d'allocations/lifecycle ou revue bloquante. Tue un coût `K` layouts par candidat. | Le painter principal du fit reste distinct et appartient au coût normal. |
| Requêtes de boxes | Au plus une requête par plage non vide et candidat, avec retour anticipé au premier dépassement. | Compteur déterministe attendu `<= K × candidats_effectivement_évalués`. | Flutter ne documente pas la complexité interne de `getBoxesForRange` ; aucune affirmation `O(N log C)` n'est permise sur le temps moteur. |
| Mémoire | Ranges `[start,end)` seulement ; aucune copie de texte ou d'arbre par plage. Les listes de boxes sont temporaires. | Entrée longue avec styles imbriqués et vérification d'absence de fuite. | Un benchmark mural est informatif, jamais un gate stable à lui seul. |
| Profondeur et aliasing hostile | Ne pas ajouter de traversal récursif autre que le clone requis qui reproduit Flutter ; ne jamais muter pour marquer un nœud visité. | Arbre partagé et listes non modifiables. | Cycles créés par mutation externe et profondeur faisant déjà déborder `Text.build` ne sont pas durcis au lot 4. |

Une chaîne très longue alternant caractère et séparateur impose `K = Θ(N)`.
Même avec une seule mise en page par candidat, le package effectue alors
`Θ(K)` appels natifs de boxes. Comme leur complexité n'est pas contractuelle,
le lot ne revendique pas une résistance DoS asymptotique plus forte. Toute
optimisation qui fusionne les ranges, perd les styles ou observe un autre arbre
est cependant interdite.

## Ordre minimal des preuves rouges/vertes

1. Faire rougir séparément flattening UTF-16, NBSP/NNBSP, bidi multi-box,
   composition non linéaire, `F == 0`, clone incomplet et mutation source sur
   `3a1c343`.
2. Pour chaque choix de candidat, dériver le seuil de deux témoins
   `Text.rich` indépendants ; ne jamais comparer deux helpers du package.
3. Comparer candidat exact, taille, hauteur, baseline et boxes couvrant chaque
   run sur le `RenderParagraph` final. Le line count seul n'accepte aucun cas.
4. Exercer metadata, recognizer, souris et sémantiques après un override puis
   un rebuild ; inspecter ensuite que l'arbre source est inchangé.
5. Rejouer les familles sur Flutter 3.41.0 et 3.47.2 exacts, puis la suite
   complète. Les assertions de candidats logiques sont exactes ; seules les
   métriques moteur utilisent les tolérances déjà justifiées par les fixtures.

## Exclusions fermes

- moteur UAX #14/#29, césure, dictionnaires, soft hyphen, zero-width space,
  règles CJK et normalisation Unicode ;
- validation ou réparation des chaînes UTF-16 invalides par run ; Flutter
  signale `ArgumentError` avant sa substitution interne et ces cas sont
  exclus des witnesses, fitters et tests `RenderParagraph` du lot 4 ;
- support automatique, dimensions, estimation, fallback ou API publique pour
  `WidgetSpan` ;
- render object, intrinsics, dry layout, dry baseline et modification du
  contrat `textKey` ;
- garantie d'isolation contre une mutation externe de `TextSpan.children`,
  préservation d'alias des clones standards ou durcissement des cycles ;
- garantie asymptotique sur l'implémentation native de
  `Paragraph.getBoxesForRange` sans benchmark et compteur dédiés.

Le lot doit être reverté en entier si un test ne devient vert qu'en aplatissant
l'arbre, en convertissant les offsets en runes, en ne lisant qu'une box, en
linéarisant `U`, en inventant un ratio pour `F == 0`, en perdant une métadonnée,
en mutant la source ou en prétendant mesurer un `WidgetSpan`.
