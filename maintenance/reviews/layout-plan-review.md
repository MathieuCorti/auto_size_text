# Revue indépendante de la décision d’architecture layout

Date : 2026-09-01

Décision revue : `maintenance/plans/layout-architecture-decision.md`, commit
`b89942c5280eeccf8fc04b99f83b76fcb97dc228`.

Base produit de la décision : `dev`, commit
`8d459dd95c82265b3ae1a59d3fe3ad28a69751bd`.

Périmètre : intrinsics, dry layout, `WidgetSpan`, groupe,
`overflowReplacement`, sémantique, cycle de vie et coût du futur moteur. Aucun
code produit n’a été modifié.

## Verdict

**GO conditionnel pour un noyau de mesure isolé suivi d’un render object
interne ; NO-GO inchangé pour une release tant que le lot n’est pas validé.**

La cause architecturale est confirmée. Une garde `WidgetSpan`, un cas spécial
`Chip`/`DataTable` ou une façade qui invente une dimension ne peut pas corriger
les requêtes intrinsèques et sèches reçues avant le callback du
`LayoutBuilder`. De même, un painter isolé ne peut pas mesurer automatiquement
un vrai enfant inline. La direction « moteur de fit sans contexte + participant
au protocole render » est donc la bonne.

La stratégie n’est toutefois pas implémentable telle qu’écrite sans rendre
explicites quatre compromis :

1. les intrinsics n’ont pas le même contrat qu’un layout sous deux bornes ;
2. un enfant inline doit avoir un chemin de mesure **wet** pendant
   `performLayout` distinct du chemin dry/intrinsèque ;
3. `RenderInlineChildrenContainerDefaults` ne fournit ni toute la sémantique du
   paragraphe ni sa sélection ;
4. retirer le `Text` interne change le contrat documenté de `textKey` et le
   harness historique.

Les modifications obligatoires ci-dessous doivent être intégrées au plan avant
de commencer le lot. Elles ne changent pas le verdict render object, mais elles
en bornent l’API, le risque et les critères d’acceptation.

## Nature du changement

Les deux familles sont bien des **correctifs de bugs existants**, pas de
nouvelles fonctionnalités :

- `AutoSizeText` promet le comportement de `Text` et les compositions
  intrinsèques valides échouent depuis les issues #28/#30/#37/#77/#129/#147 ;
- `AutoSizeText.rich` accepte un `TextSpan`, la documentation le présente comme
  l’équivalent de `Text.rich`, mais un `WidgetSpan` valide plante avant rendu.

Le lot ne doit donc ajouter aucun constructeur, callback, builder, champ
éditable, paramètre de placeholder, texte sélectionnable spécialisé ou symbole
exporté. Préserver la sélection déjà obtenue via `SelectionArea`, les
recognizers et les sémantiques n’est pas une extension : c’est une exigence de
non-régression.

Une garde explicite de `WidgetSpan` et le `dispose` des painters restent des
patches de confinement légitimes, livrables séparément. La garde transforme un
crash opaque en limitation déterministe ; elle ne ferme pas CORE-01/#61/#106 et
ne débloque pas la release. Le `dispose` ferme #150, mais n’appartient au lot
layout que si le lot cycle de vie n’a pas déjà été livré.

## Modifications obligatoires à la stratégie

### 1. Faire du moteur pur livré par les lots cœur une précondition

Le render object ne doit pas réimplémenter simultanément la grille, le scaling,
le style effectif, RichText, `wrapWords` et les groupes. Le lot commence sur une
base où le domaine de candidats et l’évaluation du paragraphe sont déjà isolés
et testés.

La frontière interne minimale est :

- une configuration immuable, résolue au niveau widget ;
- un domaine de `C` candidats sans liste matérialisée ;
- une évaluation d’un candidat qui reçoit les contraintes et une liste 1:1 de
  `PlaceholderDimensions` ;
- un résultat contenant candidat local, candidat appliqué après groupe,
  `fits`, métriques du paragraphe et baseline ;
- un orchestrateur render qui demande les métriques des enfants, sans laisser
  le noyau lire un `BuildContext`, un groupe ou un `RenderObject`.

Le noyau peut muter un painter local à l’intérieur d’un appel puis le libérer en
`finally`; il ne conserve aucun cache observable entre intrinsics, dry et wet.
Le render object ne doit pas recopier un second algorithme de fit.

### 2. Spécifier les intrinsics au lieu de les qualifier d’« exacts »

Les quatre méthodes intrinsèques ne reçoivent jamais les deux axes bornés. Le
plan doit fixer les contraintes synthétiques et le résultat attendu :

- `computeMinIntrinsicWidth(height)` et
  `computeMaxIntrinsicWidth(height)` sélectionnent avec largeur non bornée et
  `maxHeight == height`, puis retournent respectivement la largeur intrinsèque
  minimale et maximale du paragraphe choisi ;
- `computeMinIntrinsicHeight(width)` et
  `computeMaxIntrinsicHeight(width)` sélectionnent avec
  `maxWidth == width` et hauteur non bornée, puis retournent la hauteur du
  paragraphe choisi ;
- une dimension infinie n’est pas convertie en contrainte tight ; sans borne
  utile, le candidat initial/maximal autorisé est utilisé ;
- `maxLines` peut encore faire échouer un candidat sous hauteur non bornée ;
- la sélection de `overflowReplacement` utilise exactement ces contraintes
  synthétiques, pas un résultat de layout antérieur.

Ces règles doivent être vérifiées contre `RenderParagraph` pour le calcul des
métriques : ses largeurs intrinsèques interrogent les intrinsics des enfants,
alors que ses hauteurs et son dry layout utilisent leur layout sec. Employer
indistinctement `getDryLayout` dans les quatre méthodes serait une divergence.

`computeDryBaseline` sélectionne le même candidat et le même enfant actif que
`computeDryLayout`. La baseline wet vient du layout final, sans refaire une
sélection avec un autre instantané de groupe. Les contraintes tight/loose et
les `minWidth`/`minHeight` non nuls doivent être traités par
`constraints.constrain`, comme le fait `RenderParagraph`.

### 3. Séparer impérativement les backends inline dry et wet

Le texte actuel plante parce que ses painters n’ont aucune dimension. Le
correctif ne peut pas se limiter à appeler `getDryLayout` pour chaque candidat :
un enfant render valide peut savoir faire un layout humide sans implémenter le
dry layout, et `RichText` ordinaire sait alors le rendre.

Le render object doit proposer deux chemins au même sélecteur :

- intrinsics, `computeDryLayout` et `computeDryBaseline` utilisent uniquement
  intrinsics, `getDryLayout` et `getDryBaseline` des enfants, sans mutation ;
- `performLayout` peut appeler `child.layout` et la baseline réelle pour les
  candidats spéculatifs, puis laisse chaque enfant dans le layout du candidat
  final avant peinture.

Un enfant qui ne supporte pas le dry layout peut donc rester utilisable dans un
layout humide ordinaire ; il échoue seulement lorsqu’un ancêtre exige lui-même
du dry/intrinsèque, comme avec `RichText`. Le plan actuel, qui demande du dry à
chaque candidat même pendant le wet layout, doit être corrigé sur ce point.

Le groupe n’est publié qu’après le candidat wet final. Les layouts
spéculatifs des enfants ne peuvent ni publier un candidat ni changer l’enfant
actif d’overflow.

### 4. Reproduire exactement le scaling public de `WidgetSpan`

Sur les deux SDK contrôlés, `RichText` extrait les widgets inline et applique à
chaque enfant un facteur dérivé de la taille de police héritée de son run et du
`TextScaler`. Sous un scaler ×2, un enfant inline 10×12 occupe 20×24. Avec un
scaler non linéaire, deux `WidgetSpan` héritant de tailles de run différentes
peuvent donc recevoir deux facteurs différents.

« La même échelle effective des enfants » doit être remplacé par ce contrat :

```text
facteurInline = scalerDuCandidat.scale(tailleLogiqueHéritéeDuRun)
                / tailleLogiqueHéritéeDuRun
```

Le facteur agit aussi sur la contrainte de largeur donnée au child, sa taille,
sa baseline, la transformation de paint et le hit testing. Le cas d’une taille
de run nulle doit suivre la règle du SDK minimal retenu, sans division par zéro.

`WidgetSpan.extractFromInlineSpan` calcule ce facteur au build, alors que le
candidat n’est connu qu’au layout. Son utilisation directe avec un scaler fixe
ne suffit donc pas. Avant le chantier complet, un spike jetable doit prouver
qu’un adaptateur interne :

- extrait les spans dans l’ordre logique ;
- conserve l’association `TextParentData.span` et les tags sémantiques ;
- évalue un facteur différent par run et par candidat ;
- donne les mêmes tailles, baselines et positions qu’un `RichText` témoin pour
  le candidat final ;
- n’utilise aucun type privé de Flutter.

Une seule dimension est fournie par placeholder et dans l’ordre, y compris
quand un placeholder est ensuite ellipsé. Un `overflowReplacement` n’est jamais
inclus dans la liste parcourue par `RenderInlineChildrenContainerDefaults`, car
ce mixin suppose que chacun de ses enfants correspond à un `PlaceholderSpan`.

### 5. Réutiliser `RenderParagraph` ou démontrer une parité équivalente

Le mixin inline couvre parent data, position, paint et hit testing des enfants.
Il ne couvre pas à lui seul :

- la sémantique des runs, recognizers et identifiants ;
- la fusion ordonnée de la sémantique des placeholders ;
- l’inscription et le découpage sous `SelectionArea` ;
- clipping/fade/ellipsis, caret et géométrie de sélection ;
- le cycle de vie des painters de rendu et d’intrinsics.

Recopier ces centaines de lignes privées serait une nouvelle implémentation de
texte et contredirait le périmètre. La première option à prototyper est un petit
sous-type interne de `RenderParagraph` : le fitter utilise ses propres painters
locaux pour les candidats, puis le paragraphe public reçoit uniquement le span,
le scaler et les échelles inline du candidat final avant `super.performLayout`.
Le spike doit démontrer que cette voie reste pure en dry et compatible avec les
setters publics du SDK minimal. Si elle est impossible, le plan revient en
revue avant toute copie de logique sémantique ou de sélection.

### 6. Rendre explicites les changements d’observation et de cycle de vie

Le critère « tests publics existants sans modification » contredit le retrait
du `Text` interne. Le harness actuel appelle `find.byType(Text)`, caste le widget
et lit son style. `textKey` est en outre documenté comme la clé du « resulting
Text widget ».

Le plan doit choisir l’une des deux voies :

1. démontrer que `textKey` reste attaché à une vraie instance de `Text` ; ou
2. conserver `find.byKey(textKey)` mais annoncer que la cible devient le
   paragraphe auto-size interne, mettre à jour la documentation et migrer les
   tests d’implémentation vers des métriques render.

La seconde voie est réaliste mais constitue un changement observable de contrat,
même sans nouvelle signature. Les 23 **résultats comportementaux** historiques
restent identiques ; les attentes qui imposent le type interne peuvent changer.

`overflowReplacement` pose un second choix. Monter en permanence le paragraphe
et le remplacement simplifie dry/wet, mais change `initState`, `dispose`, les
tickers et les effets de build par rapport au `LayoutBuilder` actuel. Si deux
enfants sont conservés :

- seul l’enfant actif est peint, hit-testé, exposé aux sémantiques et inscrit à
  la sélection ;
- l’enfant replacement est dans un slot extérieur au conteneur inline ;
- la politique d’eager mount est documentée et testée avec des widgets à état ;
- un flip fit/overflow ne duplique ni ne perd les enfants `WidgetSpan`.

Un élément personnalisé qui construit un enfant depuis `performLayout`, comme
la PR #102, n’est pas repris sans une justification séparée et une preuve de
cycle de vie. Aucun widget n’est construit pendant une méthode dry ou
intrinsèque.

### 7. Figer le groupe par valeur, pas par référence mutable

La configuration render reçoit un `double` immuable représentant le minimum de
groupe observé au build. Elle ne lit pas `group._fontSize` en direct pendant une
passe : un frère peut publier entre la requête dry du parent et le layout wet.

Le flux requis est :

1. dry/intrinsics lisent l’instantané et ne publient rien ;
2. wet choisit et rend avec le même instantané ;
3. wet publie ensuite le candidat local ;
4. la microtâche coalescée provoque le rebuild/relayout suivant si le minimum a
   changé.

Le callback de publication ne survit pas au `State`. Changement de groupe,
retrait, dispose pendant une microtâche et remontée de taille doivent être
testés. Le lot conserve la politique historique des groupes hétérogènes si le
lot cœur correspondant n’a pas encore changé cette politique ; il ne doit pas
en créer une troisième dans le render object.

### 8. Borner honnêtement la complexité

Pour `C` candidats et `P` placeholders, la cible raisonnable est :

- texte simple : `O(log C)` évaluations de candidat ;
- `wrapWords: false` : au plus deux layouts de paragraphe par évaluation, sans
  aplatir les runs ;
- widgets inline : `O(P log C)` requêtes child et un nombre logarithmique de
  layouts de paragraphe ;
- aucune liste de `C` tailles ni cache mutable en dry ;
- tous les painters temporaires libérés en `finally`, tous les painters
  persistants libérés par leur propriétaire puis `super.dispose`.

Cette borne repose sur la monotonie de « tient/ne tient pas ». Un widget inline
arbitraire peut changer de taille de façon non monotone selon la contrainte
inversement mise à l’échelle. Le plan ne peut donc pas promettre à la fois, sans
qualification, le plus grand candidat exact pour tout `WidgetSpan` et une
dichotomie stricte.

Le spike doit inclure un enfant volontairement non monotone. Il faut ensuite
soit documenter l’hypothèse de monotonie conservée par l’algorithme historique,
soit définir un fallback de correction et son pire coût. Le compteur de test
porte sur les cas monotones normaux ; un benchmark mur-clock seul n’est pas un
gate stable.

## Pièges des PR historiques

Aucune PR ne doit être reprise intégralement.

### PR #102

Le patch confirme et aggrave les risques signalés par les audits :

- 2 768 ajouts/957 suppressions, champ éditable, sélection et builder publics ;
- groupe et builder de groupe commentés ;
- défaut `wrapWords` déplacé vers `false` dans le fitter/builder ;
- aucune implémentation de `computeDryLayout` ou `computeDryBaseline` ;
- intrinsics qui mutent `_longestWordWidth` et fitter à cache interne ;
- painters jamais libérés et `WidgetSpan` toujours sans dimensions ;
- sous-arbre construit depuis `performLayout` par callback d’élément ;
- `setupParentData` teste par erreur `ListWheelParentData` au lieu de son propre
  parent data.

Seule l’intuition « le fit doit vivre à la frontière render » est conservée.

### PR #148

Elle remplace les paramètres de painter par `TextScaler.linear`, mais utilise
`widget.textScaleFactor ?? 1.0` et perd donc le scaler ambiant. Elle ne corrige
ni dry layout, ni intrinsics, ni scaling non linéaire. Sa migration Android
conserve un enregistrement manuel de plugins et mélange démo/outillage au lot
produit.

### PR #154

Elle supprime `textScaleFactor` immédiatement, ajoute
`semanticsIdentifier` dans le même diff, calcule un résultat non linéaire puis
le reconvertit en `TextScaler.linear`, et retire `dart:typed_data` alors que le
helper de fonte utilise encore `ByteData`/`Uint8List`. Son parent synthétique de
RichText est une bonne intuition isolée ; ni son API ni son scaler ne sont une
base de portage.

## Tests obligatoires révisés

### Reproductions et contrats render

- tests rouges puis verts pour `IntrinsicHeight` dans une liste/card/row,
  `IntrinsicWidth`, `Chip`, `FilterChip`, `DataTable` et
  `PaginatedDataTable` ;
- appels directs répétés aux quatre intrinsics, au dry layout et à la dry
  baseline, avant et après un wet layout ;
- contraintes tight/loose, minima non nuls, un axe infini puis deux axes
  infinis ;
- égalité dry/wet de taille, baseline et candidat avec un enfant qui respecte
  son contrat dry ;
- enfant inline sans dry layout : wet ordinaire fonctionnel, erreur dry limitée
  au chemin qui la demande.

### `WidgetSpan`

- fixe, contraint et multiple, ordre 1:1, placeholder ellipsé ;
- alignements top/middle/bottom et baselines alphabetic/ideographic ;
- tailles de runs héritées différentes, scaler linéaire puis non linéaire,
  comparés à un `RichText` témoin ;
- `wrapWords` vrai/faux sans aplatir styles ou placeholders, `maxLines`, groupe
  et replacement ;
- paint, transform, hit testing, recognizer, sémantique enfant et
  `SelectionArea` ;
- arbre source inchangé après rebuilds et aucun enfant dupliqué.

### Groupe, remplacement et cycle de vie

- aucune mutation/notification après appels dry répétés ;
- convergence wet, changement/retrait de groupe, dispose avant microtâche ;
- sémantique et sélection exposent uniquement texte ou replacement actif ;
- compteurs `initState`/`dispose` lors des flips et retrait du widget ;
- painters temporaires, painter final et cache intrinsèque libérés, y compris
  après exception et retour anticipé.

### Performance et matrice

- compteur de candidats, layouts de paragraphe et mesures children en fonction
  de `C` et `P`, avec cas `wrapWords: false` séparé ;
- benchmark reproductible avant/après pour texte simple et placeholders ;
- SDK minimum exact décidé par le plan outillage et stable courante exacte ;
- les reproductions 3.35.3/3.44.0 restent une preuve de cause, pas la matrice de
  support finale ;
- format, analyse ciblée puis globale, suite complète et smoke profile de
  l’exemple avant release.

## Ordre corrigé et gates

1. Décider et rendre exécutable le plancher SDK.
2. Livrer/stabiliser le noyau de mesure des lots cœur, sans render object.
3. Écrire les reproductions rouges et le spike jetable
   `RenderParagraph`/inline : dry, wet sans dry child, scaling, sémantique,
   sélection et replacement.
4. Revenir en revue si le spike nécessite une API publique, des types privés
   Flutter ou une copie de `RenderParagraph`.
5. Implémenter le render object et le wrapper d’overflow au périmètre validé.
6. Exécuter cycle de vie, complexité, matrice SDK et revue finale.

La gate de release du document reste correcte. Elle devient vérifiable une fois
les contrats et compromis ci-dessus intégrés.

## Vérifications indépendantes

Un test widget temporaire, supprimé après exécution, a vérifié sous Flutter
3.35.3/Dart 3.9.2 puis Flutter 3.44.0/Dart 3.12.0 :

| Cas | 3.35.3 | 3.44.0 | Résultat |
|---|---:|---:|---|
| `ListView > Card > IntrinsicHeight > Row > Expanded > AutoSizeText` | reproduit | reproduit | erreur intrinsic de `_RenderLayoutBuilder` |
| `Chip(label: AutoSizeText(...))` | reproduit | reproduit | dry layout non supporté |
| `AutoSizeText.rich` avec `WidgetSpan` | reproduit | reproduit | assertion `dimensions != null` |
| `RichText` témoin, enfant 10×12, scaler ×2 | 20×24 | 20×24 | scaling inline confirmé |

Commande sur chaque SDK :

```text
flutter test test/layout_review_temp_test.dart --reporter compact
00:00 +4: All tests passed!
```

Les tests attendaient les trois erreurs de baseline et le comportement du
témoin Flutter. Le fichier, `.dart_tool`, `build`, les lockfiles et les patches
de PR téléchargés ont ensuite été supprimés.

Les sources Flutter 3.35.3 et 3.44.0 consultées confirment :

- `RenderParagraph` possède un painter final et un cache de painter intrinsèque
  paresseux, les libère et gère directement sélection et sémantique ;
- ses intrinsics de largeur et de hauteur n’interrogent pas les enfants de la
  même manière ;
- son dry layout emploie le layout sec des enfants, son wet layout leur layout
  réel ;
- `WidgetSpan.extractFromInlineSpan` applique le scaling par taille de run.

## Inventaire, surface et limites

Lus intégralement : la décision, les audits cœur/issues et leurs revues, les
sections SDK pertinentes de l’audit/revue outillage, les quatre fichiers
produit, les onze fichiers de test, le README/pubspec et le plan cœur associé.
Les patches complets #102/#148/#154 ont été téléchargés puis leurs statistiques
et zones render/fitter/API inspectées. Les implémentations Flutter de `RenderParagraph`,
`RenderInlineChildrenContainerDefaults`, `RichText` et `WidgetSpan` ont été
contrôlées sur les deux SDK locaux.

Surface de sécurité : widget local sans réseau produit, stockage,
authentification, autorisation, session, secret ou cryptographie. Injection,
XSS, CSRF, IDOR et cryptographie sont inapplicables. Les risques pertinents sont
la disponibilité (assertions), l’épuisement de ressources (layouts/painters),
les effets de bord de groupe et le cycle de vie des sous-arbres ; ils sont
couverts par les modifications et tests ci-dessus.

Limites : Flutter 3.47.2 n’est pas installé localement ; aucun appareil, web ou
golden n’a été exécuté ; le spike d’implémentation demandé n’a volontairement
pas été conservé. La faisabilité précise du sous-type `RenderParagraph`, le
comportement d’un child non monotone et le coût réel des layouts wet multiples
restent donc des gates, pas des hypothèses validées.
