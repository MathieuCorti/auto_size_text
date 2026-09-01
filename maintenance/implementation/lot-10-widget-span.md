# Lot 10 — `WidgetSpan` automatique

Date : 2026-09-02

Branche : `codex/impl-widget-span`

Parent S8 exact : `4794200df27ba042a4c8a8ebbe82719c499340f6`

Tests rouges : `ccf6ca3` ; implémentation principale : `efcc544` ; régressions
replacement : `48bf4da` et `85218bf` ; correctif final : `061b561`. Le commit
suivant contient uniquement ce journal.

## Périmètre livré

`AutoSizeText.rich` accepte désormais les `WidgetSpan` sans dimension ni API
publique supplémentaire. Le parent render du lot 9 monte le paragraphe inline
au début du wet layout, puis configure sous `invokeLayoutCallback` son
`TextScaler` et ses wrappers pour chaque candidat. Chaque évaluation layoutte
le vrai `RenderParagraph` et ses vrais enfants ; le paragraphe et les wrappers
restent finalement au candidat rendu.

L'extraction interne suit le preorder logique avec `visitDirectChildren` et
produit exactement un child par `WidgetSpan`. Elle n'appelle pas
`WidgetSpan.extractFromInlineSpan`, dont le facteur est figé au build. Les
seuls éléments de protocole Flutter utilisés sont publics :

- `PlaceholderSpanIndexSemanticsTag(index)` pour relier les nœuds sémantiques ;
- un `ParentDataWidget<TextParentData>` qui conserve le `WidgetSpan` exact dans
  `TextParentData.span` ;
- un `MultiChildRenderObjectWidget` interne qui crée un petit sous-type de
  `RenderParagraph` ;
- un wrapper de scaling `RenderBox` autour de chaque child.

L'arbre `InlineSpan` reçu n'est jamais muté. Les transformations de spacing
existantes conservent l'identité de chaque `WidgetSpan`, et le child original
n'est monté qu'une fois. Le paragraphe inline reconstruit seulement son root
effectif autour du `TextSpan` source, comme le chemin `Text.rich` du lot 9.

## Facteur par run et comportement wet

Le run logique hérité est recalculé en preorder à chaque candidat. Son facteur
est :

```text
candidateScaler.scale(inheritedLogicalRunSize) / inheritedLogicalRunSize
```

Un run logique zéro reçoit le facteur zéro sans division et sans appel au
scaler, conformément au témoin Flutter 3.41.0. Une référence typographique
zéro reste également finie : le root prend le candidat effectif, tandis qu'un
run explicitement non nul continue d'utiliser la courbe utilisateur.

Le wrapper inverse la contrainte de largeur avant `child.layout`, multiplie la
taille et la baseline wet, puis applique le même facteur au paint transform et
au hit test. Le facteur zéro layoutte le child sous largeur infinie, expose une
taille nulle et ne peint ni ne hit-teste une géométrie dégénérée. Les
alignements top, middle, bottom, alphabetic et ideographic restent délégués au
vrai `RenderParagraph`.

Le chemin wet mesure chaque candidat par layout réel. La recherche et la
projection de groupe réutilisent les deux dichotomies existantes ; pour `P`
placeholders, le coût normal reste `O(P log C)`. Un child non monotone termine
de façon bornée et déterministe, sans revendication d'optimum global.

## Dry, intrinsics et replacement

Le contrat lean du lot 8 est conservé. Le wrapper retourne sans consulter le
child arbitraire :

- `Size.zero` pour le dry layout ;
- `0.0` pour la dry baseline ;
- `0.0` pour les quatre intrinsics.

Les `TextPainter` temporaires du snapshot reçoivent, dans l'ordre preorder
exact, des `PlaceholderDimensions` nulles portant néanmoins l'alignement et la
baseline du span. Ils sont toujours disposés en `finally`. Dry et intrinsics
peuvent donc sélectionner un autre candidat et une autre géométrie que wet ;
cette approximation est volontaire et aucune parité géométrique n'est promise
pour un widget arbitraire.

`overflowReplacement` reste strictement lazy. Quand elle devient active, le
paragraphe et tous les widgets inline sont démontés avant de monter la
replacement. Lors d'un rebuild encore-overflow, une `GlobalKey` interne stable
reparente ce même sous-arbre autour de la mesure wet : la replacement et le
paragraphe restent des branches mutuellement exclusives, et l'état de la
replacement n'est ni réinitialisé ni disposé. Le même mécanisme accepte une
`GlobalKey` utilisateur partagée entre le `WidgetSpan` et la replacement,
puisque ces deux emplacements ne sont jamais montés simultanément. Les chemins
non-wet ne construisent ni la replacement ni les widgets inline, même après un
flip wet.

## Preuves rouges sur S8

Le commit `ccf6ca3` ajoute `test/widget_span_test.dart` sans modifier le code
produit. Sur `4794200`, Flutter 3.47.2 termine à **0/10** : chaque composition
atteint l'`UnsupportedError` transitoire du lot 4. Les échecs couvrent déjà les
reproductions #61/#106, ordre/cardinalité, alignements, scaling par run, six
métriques wet-only, interaction, sémantiques, groupe/replacement,
non-monotonie, lifecycle et compteur. Le témoin explicite de référence zéro a
été ajouté avec la comparaison finale au cours de l'implémentation.

## Preuves vertes

La suite finale lot 10 contient **13 tests** concentrés :

- placeholders fixe, contraint, multiple et ellipsé, ordre preorder 1:1,
  `TextParentData.span` exact et absence de child dupliqué ;
- géométrie finale comparée à `RichText` pour top/middle/bottom et baselines
  alphabetic/ideographic ;
- runs 20/40/0 sous scaler non linéaire, référence zéro et comparaison au
  témoin `RichText` ;
- wrapper wet-only dont le child lève sur dry layout, dry baseline et quatre
  intrinsics : les six compteurs child restent à zéro tandis que wet fonctionne ;
- paint, transform, hit test, tap du child, recognizer texte, sémantique enfant
  et `SelectionArea` ;
- wrap vrai/faux, `maxLines`, groupe et replacement lazy qui démonte l'inline ;
- child non monotone déterministe et borné ;
- domaine `C=1024`, `P=3`, sous borne `P log C` ;
- rebuild, retrait de groupe, flips replacement, disposal et leak tracking ;
- conservation du `State` d'une replacement déjà active pendant un rebuild
  toujours-overflow ;
- exclusivité des branches avec une `GlobalKey` utilisateur partagée entre le
  child inline et la replacement.

Le test RichText historique a été retourné : il exige maintenant le support
automatique sous overrides de spacing et vérifie que le `WidgetSpan` source
reste identique.

## Matrice verte

Toolchains exactes :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
```

| Contrôle | Flutter 3.41.0 | Flutter 3.47.2 |
| --- | ---: | ---: |
| format `lib test example/main.dart` | 33 fichiers ; 2 formes lot 9 réécrites puis restaurées | 33 fichiers, 0 changement final |
| analyse fatale `lib test example/main.dart` | aucun diagnostic | aucun diagnostic |
| analyse fatale séparée dans `example/` | aucun diagnostic | aucun diagnostic |
| ciblé lot 10 | 13/13 | 13/13 |
| ciblés lot 10 + rich/render/intrinsics/group/replacement/wrap/scaler | inclus dans le full | inclus dans le full |
| lifecycle/leak ciblé | 23/23 | 23/23 |
| suite complète | 156/156 | 156/156 |

Le downgrade 3.41.0 a abaissé six dépendances racine et deux dépendances de
l'exemple. Le formatteur Dart 3.11 a changé mécaniquement deux appels de tests
du lot 9 ; Dart 3.13 les a restaurés. Après la matrice, `pub upgrade` 3.47.2 a
restauré les locks byte-identiques à S8 :

```text
pubspec.lock         SHA-1 8d64fa6447216488e1ca9ca5e1406dd83c5e9455
example/pubspec.lock SHA-1 6ce414e74d7d5b4d7143e1a3cfaa1528127994d9
```

`git diff --check`, le diff depuis S8 et le status final sont propres.

## Challenge indépendant et P1 clos

Le challenge indépendant a d'abord reproduit les deux témoins S8 initiaux sur
les deux pins. Il a ensuite trouvé qu'une replacement déjà active était
spéculativement démontée puis remontée à chaque rebuild encore-overflow. Le
commit rouge `48bf4da` fixe le contrat attendu : `initState` reste à un et
aucun `dispose` intermédiaire n'a lieu.

Une première correction `8dc609f`, qui conservait simultanément un élément
replacement détaché et un élément paragraphe de mesure, satisfaisait ce témoin
mais violait l'exclusivité des branches. Une `GlobalKey` légalement partagée
entre le child inline et la replacement déclenchait alors deux exceptions sur
3.41.0 et 3.47.2. Le témoin rouge `85218bf` capture ce cas. `061b561` remplace
le double élément par le reparentage public d'un unique élément replacement.

Le challenger a rejoué indépendamment les deux P1 et les deux témoins S8 :
**4/4** sous Flutter 3.41.0 et **4/4** sous Flutter 3.47.2. Les P1 sont clos.

## Limites transmises

- la géométrie dry/intrinsic d'un `WidgetSpan` est volontairement nulle et
  peut diverger du wet ;
- la dichotomie ne promet aucun optimum global pour un child non monotone ;
- la baseline nulle utilisée par le painter auxiliaire `wrapWords: false`
  n'est qu'un oracle de largeur ; le vrai layout wet emploie la baseline child ;
- aucune démo, nouvelle API publique, CI, merge, push, tag ou publication ne
  fait partie de ce lot.

## Commits

- `ccf6ca3` — `test: reproduce automatic WidgetSpan failures` ;
- `efcc544` — `feat: support automatic WidgetSpan layout` ;
- `48bf4da` — `test: preserve active inline replacement state` ;
- `8dc609f` — première correction replacement, remplacée par `061b561` ;
- `85218bf` — `test: keep replacement branches GlobalKey-exclusive` ;
- `061b561` — `fix: reparent active overflow replacement` ;
- commit suivant — présent journal.
