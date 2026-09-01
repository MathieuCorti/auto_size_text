# Oracle de décision — RichText fidèle du lot 4

Date : 2026-09-01

Base d'étude : `d77c08ea846474632e94888a7fa74f1ec0dc44ab`

Périmètre : contrat et tests du lot 4. Ce document n'est pas un plan de
réécriture et n'autorise aucun support anticipé des `WidgetSpan` ou des
intrinsics.

## Verdict

Le correctif minimal n'aplatit jamais l'arbre riche. Il fait de la configuration
effective du lot 3 un `TextSpan` parent synthétique et place le span fourni par
l'appelant sous ce parent. Pour une référence positive, un candidat agit sur
chaque taille de run **avant** le scaler utilisateur. Pour une référence nulle,
le candidat remplace seulement la taille du parent synthétique et aucun ratio
n'existe.

`wrapWords: false` ajoute un prédicat de fit : chaque plage visuelle non vide
reliée par du texte qui ne contient pas de séparateur autorisé doit tenir dans
la largeur. Le comportement historique de `RegExp(r'\s')` est conservé, sauf
que U+00A0 et U+202F ne sont jamais des séparateurs. Cette règle ferme #142 ;
elle n'est pas une implémentation de l'UAX #14.

L'acceptation du lot repose sur des métriques de `RenderParagraph`, des actions
réelles et un arbre source observé avant/après rebuild. Inspecter seulement les
propriétés d'un widget `Text`, compter les lignes du painter final ou comparer
deux helpers issus du même code ne constitue pas une preuve.

## Preuves Flutter qui bornent le contrat

Les sources locales exactes des tags Flutter `3.41.0` et `3.47.2` ont été
comparées. Les points pertinents sont identiques sur les deux tags :

- `Text.build` résout `DefaultTextStyle`, le gras, les overrides ambiants et le
  scaler, crée un parent `TextSpan` effectif, puis met le `textSpan` fourni dans
  sa liste d'enfants ;
- l'utilitaire privé d'override clone seulement les enfants pour lesquels
  `child is TextSpan && child.runtimeType == TextSpan` ;
- ce clone recopie `text`, `children`, `style`, `recognizer`, `mouseCursor`,
  `onEnter`, `onExit`, `semanticsLabel`, `semanticsIdentifier`, `locale` et
  `spellOut` ; les autres sous-types restent les mêmes objets ;
- `TextSpan.build` transmet le même `TextScaler` à chaque style de l'arbre. Le
  scaler reçoit donc la taille logique propre à chaque run explicite ;
- `RichText` extrait et possède les vrais enfants des `WidgetSpan` et
  `RenderParagraph` attend leurs `PlaceholderDimensions`. Un `TextPainter`
  isolé ne peut pas inventer ces dimensions.

La différence d'API de construction directement pertinente en 3.47.2 est en
aval : `RichText` transmet aussi le device-pixel ratio à `RenderParagraph`. Le
chemin public `Text`/`RichText` du lot 4 l'hérite automatiquement ; une future
frontière render doit le traiter au lot 9.

Deux probes widget temporaires, exécutés sous Flutter 3.41.6 et 3.44.0 puis
supprimés, ont confirmé :

- avec des tailles parentes/enfant 20/40, un scaler instrumenté reçoit
  `20`, puis `40` pendant le layout ;
- sous override d'espacement, le `TextSpan` standard est cloné avec ses
  métadonnées, tandis qu'un sous-type de `TextSpan` reste identique ;
- `RegExp(r'\s')` reconnaît U+00A0 et U+202F ;
- le moteur peut tout de même faire une coupure d'urgence dans `AA\u00A0BB` et
  `AA\u202FBB` lorsque la largeur est trop petite. Les line metrics du rendu ne
  peuvent donc pas servir à découvrir les plages que `wrapWords: false` doit
  protéger.

## Définitions

- **Référence `F`** : taille logique finie et non négative du style parent
  effectif, après héritage et fallback à 14, mais avant auto-size et avant
  `TextScaler`.
- **Candidat `C`** : taille logique autorisée par le domaine du lot 2. Il ne
  signifie pas « taille de chaque run ».
- **Taille de run `S`** : taille logique explicite du run ou taille héritée du
  parent synthétique.
- **Scaler utilisateur `U`** : scaler explicite, sinon ancien facteur converti
  en scaler linéaire, sinon scaler ambiant, selon le lot 3.
- **Arbre de mesure** : arbre équivalent à celui que `Text.build` donnera au
  `RenderParagraph`, utilisé par les painters temporaires.
- **Arbre source** : `TextSpan` et listes fournis par l'appelant. Ils restent
  sous sa propriété et ne sont jamais modifiés.

## Invariants bloquants

### 1. Héritage et topologie

Le parent synthétique porte le style effectif. Le `TextSpan` source est son
enfant ; son `text`, ses enfants et son style restent à leur position logique.

Les règles suivantes sont obligatoires :

1. un style racine partiel, par exemple seulement une couleur, hérite de la
   taille, famille, poids et hauteur du parent effectif ;
2. un style explicite de descendant surcharge seulement ses propriétés
   renseignées ; les autres restent héritées ;
3. la référence reste `F`, pas `textSpan.style?.fontSize` ; un span racine à
   200 sous le parent implicite 14 conserve donc le domaine logique 12..14 par
   défaut et ses runs sont redimensionnés par le ratio du candidat ;
4. l'ordre, l'imbrication, le texte racine avant enfants et les limites de runs
   sont inchangés ;
5. aucun `toPlainText` ne remplace l'arbre utilisé pour mesurer le paragraphe ou
   une plage de `wrapWords`.

Le pattern historique suivant est interdit : construire un nouveau span avec
`style: source.style ?? parentStyle`, `text`, `children` et `recognizer`
seulement. Il perd l'héritage lorsque le style source est partiel et perd des
métadonnées.

### 2. Candidat et scaling par run

Si `F > 0`, le scaler du candidat est défini, pour toute taille de run `S`, par :

```text
A(C, F, U).scale(S) = U.scale(S * C / F)
```

Le même objet sémantique de scaler candidat, ou un objet égal, est transmis au
painter de mesure et au `Text` final. Les styles de run ne sont pas multipliés
par `C / F` en plus du scaler. La sortie `U.scale(C)` ne devient jamais un
`TextScaler.linear(U.scale(C) / F)` : ce remplacement n'est équivalent que pour
un scaler linéaire et casse les runs hétérogènes.

Conséquences attendues avec `F = 20`, `C = 10` :

| Run logique | Entrée de `U.scale` | Résultat attendu |
|---:|---:|---|
| hérité 20 | 10 | `U.scale(10)` |
| explicite 40 | 20 | `U.scale(20)` |
| explicite 0 | 0 | `U.scale(0)` |

Cette table est le test discriminant contre une linéarisation globale : pour
un scaler non linéaire tel que `U.scale(s) = s + s² / 100`, le run à 40 vaut
24, pas 22.

### 3. Référence zéro

Si `F == 0`, aucune branche du code ne calcule `C / F`, `1 / F`, une estimation
linéaire ou un epsilon de remplacement.

- le parent synthétique reçoit `fontSize: C` ;
- le scaler transmis est `U`, sans composition par ratio ;
- un run sans taille explicite hérite donc de `C` et rend `U.scale(C)` ;
- les tailles explicites des descendants, y compris zéro, restent inchangées
  et rendent `U.scale(S)` ;
- le même contrat s'applique au constructeur simple et au constructeur riche.

Si tous les runs ont une taille explicite, changer `C` peut ne changer aucune
métrique. Ce plateau est valide : la recherche choisit selon le domaine du lot
2 et le fit réel ; elle n'invente pas un ratio pour rendre le problème
strictement monotone. Si le seul candidat ne tient pas, `textFits` est faux et
`overflowReplacement` est choisi lorsqu'il existe.

### 4. Clonage sans mutation et sans perte de métadonnées

Sans override ambiant, le span source peut rester identique sous le parent
synthétique. Lorsqu'un override de hauteur, letter spacing ou word spacing
impose un clone, la règle de Flutter est reproduite exactement :

- seul un objet dont `runtimeType == TextSpan` est reconstruit ;
- sa liste d'enfants reconstruite est une nouvelle liste, dans le même ordre ;
- son style devient `style?.merge(override) ?? override` ;
- les dix champs `text`, `recognizer`, `mouseCursor`, `onEnter`, `onExit`,
  `semanticsLabel`, `semanticsIdentifier`, `locale`, `spellOut` et enfants sont
  recopiés sans substitution ;
- `recognizer`, cursor/callbacks et objets inconnus sont conservés par identité,
  pas clonés ; leur cycle de vie reste celui de l'appelant ;
- tout sous-type de `InlineSpan`, y compris un sous-type de `TextSpan`, et tout
  `WidgetSpan` restent les mêmes objets. Le lot 4 ne suppose rien de leur
  implémentation privée.

Le code ne trie, ne remplace ni ne modifie `source.children`. La documentation
Flutter déclare déjà non supportée la mutation par l'appelant de cette liste
après construction ; le lot 4 ne promet pas d'isolation contre une telle
mutation externe.

### 5. Overrides appliqués une seule fois

Avant le lot 9, le rendu final reste un widget `Text`, qui applique lui-même les
overrides ambiants. Le moteur de mesure construit un arbre **équivalent** à la
sortie de `Text.build`; il ne réinjecte pas un arbre déjà transformé dans un
`Text` qui le transformerait une seconde fois.

Le seul oracle est la parité avec un `Text.rich` témoin rendu dans le même
contexte. Une égalité entre le painter produit et un helper qui appelle la même
fonction de clonage ne détecte pas un double override.

### 6. `wrapWords: false` et #142

Le prédicat supplémentaire travaille sur le texte visuel brut :
`toPlainText(includeSemanticsLabels: false)`. Un `semanticsLabel` ne doit jamais
changer la taille choisie. Les offsets sont des offsets UTF-16 `[start, end)`,
comme `TextSelection` et `TextPainter.getBoxesForSelection`.

La classification minimale est :

- conserver les séparateurs que le `RegExp(r'\s')` historique reconnaît ;
- retirer exactement U+00A0 NO-BREAK SPACE et U+202F NARROW NO-BREAK SPACE de
  cet ensemble ;
- traiter les séparateurs consécutifs comme une seule frontière et ignorer les
  plages vides de début/fin ;
- ne normaliser, supprimer ni remplacer aucun caractère dans le paragraphe.

Ainsi :

| Texte visuel | Plages à contrôler |
|---|---|
| `AA BB` | `AA`, `BB` |
| `AA\tBB` | `AA`, `BB` |
| `AA\nBB` ou `AA\r\nBB` | `AA`, `BB` |
| `AA\u00A0BB` | `AA\u00A0BB` |
| `AA\u202FBB` | `AA\u202FBB` |
| `AA\u00A0BB CC\u202FDD` | `AA\u00A0BB`, `CC\u202FDD` |
| `AA\u00A0 BB` | `AA\u00A0`, `BB` |

Chaque plage est mesurée au candidat sur l'arbre fidèle, dans un painter non
wrappé. Les runs, ligatures, letter/word spacing, direction, locale, scaler et
indices d'origine restent donc actifs. Avec du bidi, une sélection peut rendre
plusieurs boxes ; le test porte sur l'avance visuelle totale de la plage, pas
sur la largeur d'une seule box. Une plage plus large que `maxWidth` fait échouer
le candidat avant même si le painter final aurait effectué une coupure
d'urgence.

Ce contrat ne décide rien pour les tirets, slashs, soft hyphens, zero-width
spaces, règles CJK, dictionnaires de langue ou autres classes Unicode. Leur
classification historique n'est pas promue en garantie normative et aucun test
du lot 4 ne doit prétendre valider l'UAX #14.

### 7. Interactions, souris et sémantiques

Quand `AutoSizeText.semanticsLabel` est nul, les informations de chaque span
restent observables comme avec `Text.rich` : label, identifier, attributs de
locale/spell-out et action du recognizer. Quand le label du widget est fourni,
sa priorité historique sur les labels des spans est conservée.

Le hit testing du texte doit encore atteindre le même `GestureRecognizer`.
Entrer puis sortir avec une souris appelle les mêmes `onEnter`/`onExit`, et le
curseur actif reste le `mouseCursor` du span. Une preuve limitée à l'identité
des callbacks ne suffit pas : au moins une interaction réelle est exigée.

### 8. `textKey` avant la frontière render

Au lot 4, `textKey` garde son contrat observable actuel : lorsque la branche
texte est active, `find.byKey(textKey)` trouve exactement un widget `Text`, y
compris pour `AutoSizeText.rich` et pour `F == 0`. Le test doit faire
`tester.widget<Text>`, pas seulement `findsOneWidget`.

Quand `overflowReplacement` est actif, la branche texte n'est pas montée et
`textKey` ne trouve rien, comme aujourd'hui. Le changement majeur où la clé
identifie un paragraphe sans garantir le type `Text` appartient au lot 9 et à
sa migration, pas au lot 4.

## Cas et résultats de référence

| Cas | Résultat exigé |
|---|---|
| parent 30, span racine `color` seulement | run à 30 avant scaler, mêmes métriques que `Text.rich` témoin |
| parent 20, enfant explicite 40, candidat 10 | entrées scaler 10 et 20 ; topologie et ratios 1:2 conservés |
| mot `AB`/`CD` réparti sur deux spans 12/48 | largeur de la plage calculée avec les deux runs ; le gros run peut faire rejeter le candidat |
| override spacing après deux pumps | une seule application à chaque pump ; mesure et rendu changent ensemble |
| source standard + sous-type inconnu | standard cloné seulement si nécessaire ; sous-type identique |
| NBSP/NNBSP avec largeur entre mot simple et segment lié | candidat haut accepté pour espace normal, rejeté pour NBSP et NNBSP |
| label sémantique contenant des espaces mais texte visuel lié | même candidat que sans label sémantique |
| `F=0`, `min=0`, run hérité | candidat 0, appel `U.scale(0)`, aucune exception/NaN |
| `F=0`, minimum positif | parent au candidat minimal positif ; run explicite inchangé |
| `F=0`, enfant explicite trop large | échec de fit réel et replacement actif s'il est fourni |
| rich text avec `textKey`, branche texte active | la clé trouve un `Text` ; recognizer et sémantiques fonctionnent |

## Tests bloquants

Tous les nouveaux fichiers utilisent `group()` et des noms « should ... ». Les
fontes regular et bold déterministes préparées au lot 3 sont chargées avant les
comparaisons. Les tolérances sont limitées aux erreurs de raster/layout
documentées ; les candidats logiques restent comparés exactement.

### A. Oracle métrique et choix du candidat

1. Construire un `Text.rich` témoin avec le span source, le même contexte et un
   scaler candidat indépendant implémentant la formule de cet oracle.
2. Comparer au `RenderParagraph` réellement rendu par `AutoSizeText.rich` :
   hauteur, baseline, nombre de lignes et rectangles de sélections couvrant les
   différents runs. La largeur contrainte du widget seule ne suffit pas.
3. Utiliser au moins deux candidats/presets et choisir une contrainte située
   entre leurs métriques témoins. Prouver que le candidat sélectionné est le
   plus grand qui tient, puis que son rendu égale le témoin correspondant.
4. Répéter avec imbrication, font sizes 20/40, poids, famille, hauteur,
   letter/word spacing, direction RTL et texte avec emoji afin d'exercer les
   offsets UTF-16.

Ces tests doivent échouer si l'arbre est aplati, si une taille enfant est
ignorée ou si mesure et rendu partagent une même transformation erronée.

### B. Scaling linéaire et non linéaire

- scaler linéaire : préserver les résultats historiques ;
- scaler instrumenté non linéaire : observer des entrées distinctes pour le
  parent et l'enfant et comparer leurs boxes au témoin ;
- cas discriminant 20/40, candidat 10 : obtenir `U.scale(10)` et
  `U.scale(20)`, jamais un coefficient global ;
- bascule du scaler entre deux pumps : nouveau candidat/métriques sans arbre
  source modifié ;
- override spacing + scaler : prouver par métriques qu'aucun des deux n'est
  appliqué deux fois.

Le helper historique `effectiveFontSize`, fondé sur
`textScaleFactor * style.fontSize`, est interdit dans ces tests :
`TextScaler.textScaleFactor` n'est qu'une estimation pour un scaler non
linéaire.

### C. `wrapWords: false` et Unicode

- même mot réparti entre au moins trois spans de tailles/styles différentes ;
- paires identiques avec U+0020, tabulation, LF, CRLF, U+00A0 et U+202F ;
- chaîne mixte `AA\u00A0BB CC\u202FDD` ;
- séparateurs en début/fin et consécutifs ;
- emoji ou paire surrogate avant/après NBSP pour détecter un offset UTF-16
  décalé ;
- run bidi produisant plusieurs boxes ;
- `semanticsLabel` dont les espaces diffèrent du texte visuel.

Chaque test place la largeur entre les avances témoins de deux candidats. Il
assert le candidat et les boxes du rendu, pas seulement le résultat d'une
fonction de segmentation. Un test séparé garde `wrapWords: true` inchangé.

### D. Aliasing, métadonnées et mutation

- capturer l'identité du span racine, de sa liste et de tous ses descendants ;
- pomper sans override, puis avec chaque override séparé et combiné, puis
  revenir sans override ;
- après chaque pump, vérifier que toutes les références et valeurs de l'arbre
  source sont inchangées ;
- inspecter l'arbre final : clones/listes nouveaux pour les `TextSpan` standards
  transformés, identité conservée pour recognizer, cursor/callbacks, sous-type
  inconnu et `WidgetSpan` ;
- utiliser un `UnmodifiableListView` ou une liste non modifiable dans un cas :
  toute tentative de mutation du source fait échouer le test immédiatement.

### E. Interaction et sémantiques

- cibler par `getBoxesForSelection` le run reconnu et vérifier que tap/long
  press appelle le recognizer original ;
- activer les sémantiques et vérifier label, identifier, locale/spell-out et
  action ; vérifier séparément la priorité du label de widget ;
- déplacer un `TestGesture` de type souris dans puis hors de la box du run,
  vérifier `onEnter`, `onExit` et
  `mouseTracker.debugDeviceActiveCursor(device)` ;
- répéter après override et rebuild pour détecter la perte de métadonnées dans
  un clone.

Le test démonte le widget avant de disposer le recognizer détenu par le test.

### F. Référence zéro, replacement et clé

- simple et riche, `F=0/min=0`, sans exception, valeur non NaN et métriques du
  témoin ;
- simple et riche, `F=0/min>0` ;
- enfant implicite puis enfant explicite zéro/non zéro sous scaler instrumenté ;
- contrainte minuscule avec et sans `overflowReplacement` ;
- à branche texte active, `tester.widget<Text>(find.byKey(textKey))` ; à branche
  replacement active, absence de cette clé ;
- plusieurs rebuilds et changement min/scaler pour exclure une valeur en cache
  issue d'une ancienne division.

### G. Tests négatifs de frontière

- un sous-type inconnu reste présent et fonctionnel ; aucun cast en
  `TextSpan` standard n'est toléré ;
- un `WidgetSpan` reste identique pendant les transformations d'arbre, mais
  aucun test du lot 4 ne prétend que sa mesure/rendu fonctionne ;
- les reproductions intrinsic/dry restent attribuées au lot 9 ; aucun cas
  spécial `Chip`, `DataTable` ou façade d'estimation n'entre dans ce diff.

## Frontières fermes avec les lots 9 et 10

### `WidgetSpan` — lot 10

Le lot 4 ne fournit ni `PlaceholderDimensions`, ni dimension zéro/estimée, ni
paramètre public, ni fallback au plus petit candidat. Une garde package-owned
qui transforme l'assertion opaque en `UnsupportedError` déterministe est une
défense transitoire acceptable, mais elle ne ferme ni CORE-01, ni #61/#106 et
ne débloque aucune release.

Jusqu'au lot 10, la seule garantie du transformateur RichText est que le
`WidgetSpan` source n'est ni cloné, ni supprimé, ni dupliqué. Au lot 10,
`RichText`/`RenderParagraph` devient l'oracle : extraction 1:1 des enfants,
dimensions réelles dry/wet, baseline, scaling hérité par run, paint, transform,
hit test et sémantique enfant. Aucun de ces engagements n'est anticipé ici.

### Intrinsics et dry layout — lot 9

Le lot 4 garde `LayoutBuilder`; il ne corrige pas `IntrinsicWidth`,
`IntrinsicHeight`, `Chip`, `DataTable`, les quatre intrinsics, dry layout ou dry
baseline. Ajouter une estimation ou lire un cache de layout humide serait une
régression architecturale. La release reste bloquée jusqu'aux gates des lots 9
et 10 même si tous les tests de cet oracle sont verts.

## Pièges historiques à rejeter

- **Commit/#9 `af90871`** : il a introduit le clone partiel
  `source.style ?? parentStyle`. C'est l'origine directe de la perte
  d'héritage et de métadonnées ; ne pas « compléter quelques champs » autour de
  ce pattern.
- **Commit/#17 `a663d57`** : il a défini les mots via `split(RegExp(r'\s+'))`.
  Conserver sa valeur par défaut `wrapWords: true`, mais pas son modèle de
  segmentation/aplatissement.
- **PR #154** : le parent synthétique est une intuition récupérable ; convertir
  ensuite le résultat non linéaire en `TextScaler.linear` est précisément le
  défaut interdit par la table 20/40. La suppression immédiate de l'ancien
  facteur et l'ajout de `semanticsIdentifier` sont aussi hors lot.
- **PR #148 et #135** : le fallback à 1/no-scaling perd le scaler ambiant. Leur
  migration ne prouve ni scaling par run, ni parité RichText.
- **PR #122** : transmettre une propriété au `Text` final seulement crée un
  paragraphe mesuré différent du paragraphe rendu.
- **PR #139** : exposer des dimensions de placeholder transfère au client un
  détail de layout et laisse l'usage existant en défaut. Ce n'est pas le lot 4.
- **PR #102** : son render box sans dry layout, ses intrinsics mutables, ses
  painters non libérés, la suppression du groupe et le changement de défaut de
  `wrapWords` la rendent impropre à tout cherry-pick.

Aucune PR historique ne doit être reprise intégralement. Un test qui devient
vert en linéarisant, en supprimant un span, en ignorant un placeholder ou en
mesurant un texte monostyle est un faux correctif.

## Exclusions

Sont explicitement hors lot 4 :

- moteur UAX #14, dictionnaires de césure et segmentation locale générale ;
- `WidgetSpan` automatique, placeholders manuels et toute nouvelle API inline ;
- render object, intrinsics, dry layout, dry baseline et changement de contrat
  `textKey` ;
- sélection spécialisée, `SelectableText`, champ éditable ou builder riche ;
- changement des valeurs par défaut, du domaine de candidats, des groupes ou
  de la priorité `overflowReplacement` ;
- optimisation fondée sur un cache qui rendrait mesure et rendu observables à
  des frames différentes.

## Gate du lot 4

Le lot est acceptable seulement si tous les tests A à G pertinents sont verts
sur Flutter 3.41.0 et 3.47.2 exacts, si au moins un test de chaque famille a été
démontré rouge sur le code précédent, si la suite complète reste verte et si
le diff produit ne contient ni traitement de placeholder, ni render object, ni
nouvelle API. Toute mutation de l'arbre source, perte de métadonnée, division
par zéro, linéarisation d'un scaler non linéaire ou double override impose le
revert entier du lot.
