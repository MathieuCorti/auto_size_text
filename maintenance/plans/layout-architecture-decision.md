# Décision d’architecture — layout, intrinsics et `WidgetSpan`

Date : 2026-09-01
Base analysée : `dev` à `8d459dd95c82265b3ae1a59d3fe3ad28a69751bd`

## Décision

**NO-GO pour une release production tant que le lot render/layout borné ci-dessous
n’est pas livré. GO pour ce lot, et DEFER pour toute réécriture ou nouvelle
fonctionnalité au-delà de ce périmètre.**

Il n’existe pas de garde `WidgetSpan` ni de durcissement local de la mesure qui
permette de différer sans risque le problème structurel. Les deux pannes ont des
déclencheurs distincts, mais la même frontière de correction sûre : le composant
qui choisit la taille doit participer au protocole de layout Flutter et posséder
les enfants inline qu’il mesure.

- Les intrinsics et le dry layout échouent avant même que le callback du
  `LayoutBuilder` courant ne puisse agir. Un cas spécial `Chip`, `DataTable` ou
  ancêtre connu ne peut donc pas intercepter le prochain parent qui interrogera
  ces métriques.
- Un `WidgetSpan` n’est pas mesurable à partir du seul `TextSpan`. Il faut obtenir
  une `PlaceholderDimensions` par enfant, pour chaque échelle candidate, avec
  largeur, hauteur et baseline cohérentes avec le layout réel.
- Retourner zéro, une taille estimée ou la taille maximale dans une façade
  `RenderBox` ferait seulement taire les assertions : cela violerait le contrat
  dry/wet de Flutter et déplacerait les défauts vers le clipping, les tables, les
  baselines et `overflowReplacement`.

Le plus petit correctif sûr est donc **un render object interne dédié**, sans
nouvelle API publique, sans portage de champ texte et sans reprise de la PR #102.
Une garde explicite ou la libération des painters peut être livrée en défense
temporaire, mais **ne débloque pas la release** et ne ferme aucune issue de layout.

## Preuves

### Chemin courant et causes

La lecture complète de `lib/` et de la suite `test/` montre ce chemin :

1. `_AutoSizeTextState.build` retourne toujours un `LayoutBuilder`
   (`lib/src/auto_size_text.dart:241-275`).
2. Son callback calcule un candidat et publie immédiatement ce candidat au
   groupe (`:257-265`).
3. La recherche dichotomique appelle `_checkTextFits` pour chaque candidat
   (`:308-367`).
4. `_checkTextFits` transmet le `TextSpan` à un `TextPainter` sans dimensions de
   placeholders (`:370-410`). Avec `wrapWords: false`, il alloue un second
   painter et aplatit tous les runs stylés en texte brut (`:372-394`).
5. Aucun des painters n’est libéré.
6. La suite existante ne couvre ni intrinsics, ni dry layout, ni `WidgetSpan`.

Ce sont bien deux causes, pas une seule assertion :

| Famille | Cause racine | Pourquoi un patch au painter ne suffit pas |
|---|---|---|
| #28, #30, #37, #77, #129, #147 | `_RenderLayoutBuilder` ne fournit pas d’intrinsics ni de dry layout exploitables | La demande est traitée par l’ancêtre render object avant le callback widget |
| #61, #106 | le painter de recherche n’a ni enfants inline ni `PlaceholderDimensions` | Les dimensions dépendent du layout sec/réel de chaque enfant et de l’échelle candidate |

Le groupe ajoute une contrainte d’architecture. `AutoSizeGroup._updateFontSize`
modifie sa carte, son minimum et planifie des notifications
(`lib/src/auto_size_group.dart:13-31`). Appeler cette méthode depuis une passe
intrinsèque ou sèche rendrait la mesure observable et non déterministe.

### Reproductions locales

Un test widget temporaire, supprimé après le spike, a monté quatre cas sous
`MaterialApp` et intercepté les erreurs Flutter attendues :

| Cas | Flutter 3.35.3 | Flutter 3.44.0 | Erreur observée |
|---|---:|---:|---|
| `IntrinsicHeight > Row > Expanded > AutoSizeText` | reproduit | reproduit | `LayoutBuilder does not support returning intrinsic dimensions` |
| `Chip(label: AutoSizeText(...))` | reproduit | reproduit | `_RenderLayoutBuilder does not support dry layout` |
| `DataTable` dont le label est un `AutoSizeText` | reproduit | reproduit | `LayoutBuilder does not support returning intrinsic dimensions` |
| `AutoSizeText.rich` avec un `WidgetSpan(SizedBox(...))` | reproduit | reproduit | assertion `dimensions != null` |

Commande exécutée sur chaque SDK :

```text
flutter test test/layout_spike_temp_test.dart --reporter compact
00:00 +4: All tests passed!
```

Les quatre tests attendaient explicitement les erreurs pour établir la
reproduction. Le fichier temporaire, `.dart_tool`, `build` et les lockfiles
générés ont ensuite été supprimés. Le worktree était revenu propre avant la
création du présent document.

Les tickets amont donnent les mêmes déclencheurs :

- [#28](https://github.com/simc/auto_size_text/issues/28),
  [#30](https://github.com/simc/auto_size_text/issues/30) et
  [#37](https://github.com/simc/auto_size_text/issues/37) montrent respectivement
  un parent intrinsèque autour d’un `Row`, `IntrinsicHeight` et
  `PaginatedDataTable` ;
- [#77](https://github.com/simc/auto_size_text/issues/77) identifie le contrat
  `RenderBox` comme cause commune ;
- [#129](https://github.com/simc/auto_size_text/issues/129) reproduit
  `computeMaxIntrinsicWidth` via `DataTable` ;
- [#147](https://github.com/simc/auto_size_text/issues/147) reproduit le chemin
  dry layout via `Chip` sur Flutter moderne. Le ticket framework associé
  [flutter/flutter#153460](https://github.com/flutter/flutter/issues/153460) a été
  fermé comme défaut du package tiers ;
- [#61](https://github.com/simc/auto_size_text/issues/61) et
  [#106](https://github.com/simc/auto_size_text/issues/106) reproduisent
  l’assertion `WidgetSpan` à partir d’un `TextSpan` par ailleurs valide.

### Contrats Flutter actuels

Les API officielles imposent les propriétés suivantes :

- [`RenderBox.computeDryLayout`](https://api.flutter.dev/flutter/rendering/RenderBox/computeDryLayout.html)
  doit produire la même taille que le layout réel sous les mêmes contraintes et
  doit utiliser `getDryLayout` pour les enfants ;
- [`RenderBox.computeDryBaseline`](https://api.flutter.dev/flutter/rendering/RenderBox/computeDryBaseline.html)
  doit rester sans effet de bord et correspondre à la baseline réelle ;
- [`TextPainter.setPlaceholderDimensions`](https://api.flutter.dev/flutter/painting/TextPainter/setPlaceholderDimensions.html)
  exige une dimension par placeholder, dans le même ordre ;
- [`WidgetSpan`](https://api.flutter.dev/flutter/widgets/WidgetSpan-class.html)
  est un vrai enfant widget. Le chemin `RichText`/`RenderParagraph`, et non un
  painter isolé, assure son layout ;
- [`RenderParagraph`](https://api.flutter.dev/flutter/rendering/RenderParagraph-class.html)
  implémente aujourd’hui intrinsics, dry layout, dry baseline et enfants inline ;
- [`RenderInlineChildrenContainerDefaults`](https://api.flutter.dev/flutter/rendering/RenderInlineChildrenContainerDefaults-mixin.html)
  fournit les conventions officielles de layout, peinture et hit testing des
  enfants inline ;
- [`TextPainter.dispose`](https://api.flutter.dev/flutter/painting/TextPainter/dispose.html)
  libère les ressources natives du paragraphe.

L’implémentation Flutter 3.44 locale confirme que `RenderParagraph` calcule les
dimensions inline avec le layout sec pour les méthodes sèches, avec le layout
réel pour `performLayout`, alimente ensuite le painter et libère ses painters à
la destruction. C’est le protocole à réutiliser, pas du code privé à copier.

## Options comparées

| Option | Exactitude layout/`WidgetSpan` | Compatibilité et comportement | Performance et cycle de vie | Risque / verdict |
|---|---|---|---|---|
| A. Garde `WidgetSpan` + mesure courante durcie | Ne corrige aucun intrinsic/dry. Une erreur explicite reste une incompatibilité ; retirer/estimer le placeholder sous-mesure le texte ; afficher directement `Text.rich` désactive l’auto-size | Peut préserver l’API en surface, mais casse le contrat annoncé de `AutoSizeText.rich`, les groupes, `overflowReplacement` ou les baselines selon le fallback | `try/finally` peut corriger les fuites, sans corriger l’architecture | **Rejetée comme déblocage release.** Acceptable uniquement comme défense transitoire clairement documentée |
| A’. Façade `RenderBox` autour du `LayoutBuilder` retournant zéro/une estimation | Une estimation ne peut pas égaler le wet layout pour texte, remplacement et enfants arbitraires | Cache les assertions mais reste fausse pour tables, baselines, groupes et prochaines variantes de parents | Ajoute deux chemins de mesure divergents | **Rejetée.** Faux correctif |
| B. PR [#102](https://github.com/simc/auto_size_text/pull/102) ou cherry-pick partiel | Bonne intuition `RenderBox`, mais pas de `computeDryLayout`; les intrinsics mutent `_longestWordWidth`; `WidgetSpan` n’obtient toujours pas ses dimensions | 2 768 ajouts/957 suppressions, `wrapWords` passe de vrai à faux, `AutoSizeGroup` est neutralisé et de nouvelles APIs (`SelectableAutoSize`, champ texte, builder) changent le produit | Painters non libérés ; copie d’une ancienne implémentation de champ texte | **Rejetée comme code.** Conserver seulement l’idée d’une frontière render object |
| C. Render object interne ciblé + noyau de mesure pur | Peut répondre à tous les chemins avec la même logique et les dimensions réelles/sèches de chaque enfant inline | Préserve les deux constructeurs, les valeurs par défaut, les clés, le groupe, `wrapWords`, la sémantique et le remplacement sans ajouter d’API | Recherche logarithmique conservée ; painters possédés et libérés ; coût intrinsèque contrôlable et testable | **Retenue.** Seule option minimale qui respecte le contrat Flutter |

### Pourquoi la PR #102 n’est pas une base de portage

Le patch et ses fichiers render/fitter ont été inspectés à la tête
`ea8ad8d0e55850952d34cd9c5d94604a408e0025`. En plus du périmètre excessif :

- aucun `computeDryLayout` ni `computeDryBaseline` n’est présent ;
- les méthodes intrinsèques passent par un fitter qui modifie un cache ;
- le groupe et ses tests sont commentés/retirés ;
- le défaut public `wrapWords: true` devient `false` ;
- le fitter conserve des `TextPainter` sans `dispose` ;
- le `WidgetSpan` est toujours envoyé au painter sans protocole d’enfants inline.

Une variante « PR #102 moins les nouveautés » conserverait donc les défauts les
plus risqués tout en payant le coût d’une réécriture. Elle n’est pas plus petite
que l’option C.

## Stratégie minimale retenue

### 1. Préserver l’enveloppe publique

Conserver sans changement :

- `AutoSizeText` et `AutoSizeText.rich`, tous leurs paramètres et leurs valeurs
  par défaut, notamment `wrapWords: true` ;
- `key` et l’identité actuellement exposée par `textKey` ;
- `AutoSizeGroup`, `overflowReplacement`, `semanticsLabel`, les runs et
  recognizers du span ;
- le résultat de sélection actuel pour le texte simple, les presets et le pas,
  sauf correctif déjà décidé dans un autre lot.

Le `State` continue de résoudre `DefaultTextStyle`, `Directionality`, locale,
échelle ambiante et inscription au groupe. Il construit ensuite un widget render
interne immuable, keyed par `textKey`, au lieu d’un `LayoutBuilder`.

### 2. Une seule primitive de mesure

Extraire une fonction interne de fit qui reçoit toute la configuration résolue,
les contraintes et les métriques de placeholders, puis retourne au minimum :

- candidat local choisi ;
- taille effectivement utilisée ;
- `fits` ;
- taille et baseline du paragraphe.

Cette primitive ne lit pas le `BuildContext`, ne construit pas de widget, ne
notifie pas le groupe et ne modifie pas de cache observable. Intrinsics, dry et
wet l’appellent avec les mêmes règles. Les painters courts sont libérés dans un
`finally`; si un painter est conservé, son propriétaire le met à jour et le
libère dans `dispose`.

### 3. Posséder les vrais enfants inline

Utiliser un `MultiChildRenderObjectWidget`/`RenderBox` interne, ou une composition
équivalente qui respecte `RenderInlineChildrenContainerDefaults`, avec :

- les enfants extraits des `WidgetSpan`, en ordre 1:1 ;
- un slot séparé facultatif pour `overflowReplacement` ;
- le calcul sec des largeur, hauteur et baseline de chaque enfant avant chaque
  candidat, puis le calcul réel et le positionnement pour le candidat retenu ;
- la même échelle effective des enfants inline que celle utilisée pour le texte ;
- peinture, hit testing et sémantique des enfants sans duplication.

Il ne faut ni exposer un paramètre public `placeholderDimensions`, ni demander au
client de mesurer ses widgets, ni copier les champs privés de `RenderParagraph`.
Le render object de Flutter est le modèle de protocole, pas une source à forker.

### 4. Rendre dry, intrinsics et baseline purs

Implémenter explicitement :

- les quatre méthodes intrinsèques ;
- `computeDryLayout` ;
- `computeDryBaseline` ;
- `performLayout` et la baseline réelle avec la même primitive.

Une passe sèche peut lire un instantané stable du minimum de groupe, mais elle ne
peut publier aucun candidat, planifier aucune microtâche, modifier aucun cache de
fit ou changer un enfant. Pour un instantané de groupe donné, le wet layout doit
produire la même taille et la même baseline. Seul le wet layout publie ensuite le
candidat local ; si le minimum du groupe change, les membres sont relayoutés au
tour suivant selon la coalescence existante.

Cette séparation évite qu’un simple appel à `getDryLayout` modifie la police d’un
autre widget. Elle conserve le comportement du groupe sans résoudre dans ce lot
les divergences déjà documentées entre membres ayant des minima/presets
hétérogènes.

### 5. Conserver les invariants de `wrapWords`

La refonte ne change ni la valeur par défaut ni le sens de `wrapWords`. La
mesure d’un span riche ne doit pas l’aplatir ni perdre les styles/children.
Les corrections Unicode ou de segmentation plus larges restent dans leur lot,
mais ce chantier doit fournir un point de mesure unique afin qu’elles ne créent
pas un nouveau décalage dry/wet.

### 6. Coût maîtrisé

Conserver la recherche dichotomique : au plus un nombre logarithmique de layouts
de paragraphe dans le nombre de candidats, sans passe linéaire cachée. Les
dimensions d’enfants peuvent varier avec l’échelle ; elles doivent donc être
recalculées quand le candidat varie, mais jamais plus d’une fois par enfant et
par candidat. Les intrinsics Flutter peuvent être coûteux par nature : ne pas les
mémoriser dans un cache mutable pendant une passe sèche.

## Frontières du lot

### Inclus

- suppression du `LayoutBuilder` comme moteur de `AutoSizeText` ;
- noyau de mesure partagé par intrinsic/dry/wet ;
- quatre intrinsics, dry layout et dry baseline exacts ;
- support automatique des `WidgetSpan`, y compris layout, baseline, peinture,
  hit testing et mise à l’échelle ;
- maintien de `overflowReplacement`, `textKey`, sémantique, groupe et
  `wrapWords` ;
- propriété et libération explicites de tous les `TextPainter` ;
- tests et petit benchmark de complexité du fitter.

### Exclus

- `AutoSizeTextField`, texte sélectionnable, builder public ou autre widget ;
- paramètre public de dimensions de placeholders ;
- refonte du modèle `AutoSizeGroup` ou nouvelle politique pour des contraintes
  hétérogènes ;
- nouvelles fonctionnalités de parité avec `Text` ;
- changement du défaut ou de la sémantique de `wrapWords` ;
- corrections Unicode générales, migration publique `TextScaler`, refonte des
  exemples ou modernisation tooling, sauf adaptation interne strictement requise
  pour compiler le render object sur les SDK supportés.

Si une correction hors de cette liste paraît nécessaire, elle doit devenir un
lot séparé. Elle ne doit pas agrandir silencieusement le chantier layout.

## Critères d’acceptation

Le lot est terminé seulement si tous les points suivants sont vrais.

### Compatibilité

- Aucun changement de signature, valeur par défaut ou symbole exporté.
- Les tests publics existants restent verts sans modification d’attente.
- Des tests figent `wrapWords: true`, les deux constructeurs, `textKey`,
  `semanticsLabel`, recognizers et `overflowReplacement`.
- Le comportement de groupe converge sur deux membres après wet layout ; monter,
  changer de groupe et disposer un membre ne laisse ni notification tardive ni
  référence active.

### Layout

- `IntrinsicWidth`, `IntrinsicHeight`, `Row + Expanded`, `DataTable`,
  `PaginatedDataTable`, `Chip` et `FilterChip` montent sans exception.
- Pour plusieurs contraintes bornées et non bornées, `getDryLayout` égale la
  taille après `layout` avec le même instantané de groupe.
- Dry baseline et baseline réelle sont égales ; les quatre intrinsics sont finis,
  déterministes et cohérents avec le paragraphe final.
- Appeler intrinsics, dry layout ou dry baseline plusieurs fois ne modifie ni le
  groupe, ni la police du rendu suivant, ni le nombre de notifications.
- `overflowReplacement` participe lui-même au dry/wet layout et n’est jamais
  construit depuis `computeDryLayout`.

### `WidgetSpan`

- Un placeholder fixe, plusieurs placeholders, un placeholder contraint et un
  placeholder à baseline sont mesurés et peints à la bonne position.
- Chaque placeholder a exactement une `PlaceholderDimensions`, dans l’ordre du
  span, en dry comme en wet.
- Les enfants inline suivent l’échelle effective du candidat ; un candidat plus
  petit peut faire passer un cas qui débordait, sans désaccord entre mesure et
  rendu.
- Les mêmes cas sont couverts avec `wrapWords` vrai/faux, `maxLines`, groupe et
  `overflowReplacement`.
- Les widgets inline restent interactifs et leurs sémantiques ne sont pas perdus.

### Ressources et performance

- Chaque painter court est libéré même après retour anticipé ou exception ; tout
  painter persistant est libéré au `dispose` et remplacé proprement après mise à
  jour de configuration.
- Un test de fuite couvre texte simple, `wrapWords: false`, `WidgetSpan`, rebuilds
  et retrait d’un groupe.
- Le nombre de layouts de paragraphe par fit reste logarithmique dans le nombre de
  candidats ; un compteur de test interdit une recherche linéaire accidentelle.
- Un benchmark avant/après est conservé pour texte simple et span avec enfant.
  Toute régression significative doit être expliquée avant merge ; elle ne peut
  pas être compensée par un cache mutable en dry layout.

### Matrice et qualité

- Les régressions passent sur le SDK minimal supporté et sur le stable Flutter
  courant, au minimum en debug ; le smoke test de l’exemple passe aussi en
  profile avant release.
- `flutter analyze` est propre et la suite complète passe.
- La revue finale confirme : aucune nouvelle API, aucun code de champ texte ou
  sélection, aucun painter orphelin, aucune mutation de groupe/cache en passe
  sèche, et aucune différence dry/wet non documentée.

## Ordre d’exécution et gate release

1. Écrire d’abord les reproductions rouges intrinsic/dry/`WidgetSpan` et les
   assertions d’absence d’effets de bord de groupe.
2. Introduire le noyau de mesure pur et le render object interne, sans changer
   l’algorithme public.
3. Brancher les enfants inline et le remplacement, puis la baseline et les
   sémantiques.
4. Ajouter disposal/leak tests et compteur de complexité.
5. Exécuter la matrice SDK, comparer les métriques et réaliser une revue ciblée
   des invariants ci-dessus.

**Gate : ne pas publier la version production avant satisfaction de ces critères.**
Un patch préalable de garde ou de `dispose` réduit l’impact d’un crash ou d’une
fuite, mais ne change pas cette gate. La PR #102 ne doit être ni mergée ni
cherry-pickée ; ses idées doivent être réimplémentées au périmètre strict de ce
document.
