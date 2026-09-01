# Décision du prototype layout — lot 8

## Verdict

**NO-GO du contrat actuel.** Les lots 9 et 10 ne doivent pas démarrer sur cette
architecture tant que le contrat de `overflowReplacement` n'a pas été revu,
choisi explicitement et validé par un nouveau spike.

Le noyau render est viable sur Flutter 3.41.0 et 3.47.2 : une composition autour
d'un petit sous-type de `RenderParagraph` satisfait la recherche logarithmique,
les chemins wet/dry, les placeholders, les baselines, le scaling par run, les
groupes, la sélection et la sémantique. Le blocage est plus étroit mais
décisif : le contrat du lot 9 exige simultanément une branche replacement
arbitraire inactive non montée et un résultat dry/intrinsic exact avant wet.
Flutter interdit de monter ou reconstruire cette branche depuis
`computeDryLayout`. Accepter silencieusement un eager mount changerait un
contrat de lifecycle observable ; ce prototype ne prend pas cette décision à
la place du mainteneur.

## Périmètre et reproductibilité

- Base Gate Cœur : `aac54f3eac23aa7c47a5439baf179f9394588aaa`.
- Commit temporaire complet du spike :
  `dba563961a66ca09d40f471e3a72e5649752602f`.
- Le commit contient `tool/layout_spike/spike.dart` et
  `test/layout_spike_gate_test.dart`. Ils sont volontairement absents du tip ;
  on peut les relire avec `git show <sha>:<path>` ou tester ce SHA dans un
  worktree jetable.
- Flutter 3.41.0, framework `44a626f4f0`, Dart 3.11.0.
- Flutter 3.47.2, framework `d3b14c8769`, Dart 3.13.2.
- Lock canonique `example/pubspec.lock` inchangé, SHA-256
  `115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7`.

Commandes exécutées sur chacun des deux SDK épinglés, à partir du commit du
spike :

```sh
flutter pub get --no-example
dart format --output=none tool/layout_spike/spike.dart test/layout_spike_gate_test.dart
flutter analyze tool/layout_spike/spike.dart test/layout_spike_gate_test.dart
flutter test test/layout_spike_gate_test.dart --reporter expanded
```

Résultat commun : format propre, analyse sans issue, **17/17 tests verts**.
Les dépendances racine ont été résolues tour à tour ; aucun lock suivi n'a été
modifié.

Les mutants ont été exécutés avec :

```sh
flutter test test/layout_spike_gate_test.dart \
  --dart-define=SPIKE_MUTANT=<mutant> --plain-name '<test ciblé>'
```

Les sept mutants discriminants sont tués (exit 1) : `linear_search`,
`wet_uses_dry`, `dry_publish`, `skip_final_layout`, `zero_division`,
`no_dispose` et `intrinsic_uses_dry`. Les six premiers ont été vérifiés sur les
deux pins ; le septième, ajouté après revue adversariale des intrinsics, a été
vérifié sur 3.47.2, tandis que le chemin normal correspondant est vert sur les
deux pins.

## Architecture minimale viable hors replacement

La frontière minimale est une composition, pas une réécriture du paragraphe :

```text
widget AutoSize
└─ RenderBox parent (sélection de candidat et snapshot de groupe)
   └─ petit RenderParagraph (texte, paint, sélection, sémantique)
      └─ P wrappers inline publics (scale, contraintes, baseline, paint, hit)
```

Le chemin wet effectue une dichotomie sur le domaine virtuel des candidats.
Pour chaque essai, le parent ouvre `invokeLayoutCallback`, configure le
`textScaler` du paragraphe et les facteurs des wrappers, puis appelle
`paragraph.layout`. Si la projection du snapshot de groupe choisit un candidat
différent du dernier essai, un relayout final laisse le paragraphe et tous ses
children dans l'état effectivement rendu. La publication de groupe arrive une
seule fois, après cet état final.

Les setters `RenderParagraph.text` et `RenderParagraph.textScaler` appellent
`markNeedsLayout`. Les muter dans le propre `performLayout` du paragraphe lève
« was mutated in its own performLayout » ; les muter depuis un
`parent.performLayout` ordinaire lève « must not mutate its descendants ».
`invokeLayoutCallback` est donc une dépendance architecturale indispensable.
Les probes sur les deux SDK ont validé trois cycles configure/layout dans une
même passe, sans frame récursive : trois layouts du paragraphe et, pour deux
placeholders, six layouts de leaf ; le dernier scaler, les tailles, offsets,
baselines, paint, hit testing et tags sémantiques restent ceux du candidat final.

Le chemin dry ne mute aucun render object, ne publie rien et emploie un
`TextPainter` temporaire disposé en `finally`. Les dimensions de placeholder
sont calculées par des helpers purs prenant le facteur en argument. Cette règle
évite un piège confirmé sur les deux SDK : après mutation externe du facteur,
`getDryLayout` avec les mêmes contraintes peut rendre la taille précédemment
mémoïsée. Les largeurs intrinsèques utilisent séparément
`getMinIntrinsicWidth`/`getMaxIntrinsicWidth`; dry layout, hauteurs et baselines
utilisent `getDryLayout`/`getDryBaseline`.

Les `WidgetSpan` sont extraits en preorder avec la taille logique héritée du
run. Le facteur est :

```text
runSize == 0 ? 0 : candidateScaler.scale(runSize) / runSize
```

Il s'applique aux contraintes inverses, taille, baseline, transformation de
paint et hit testing. Même avec un facteur zéro, le helper interroge la baseline
dry du child avant de multiplier : il conserve ainsi la distinction Flutter
entre absence/erreur de baseline et baseline valide ramenée à zéro.

## Surface Flutter publique commune exacte

Le spike compile avec la même surface sur les deux pins :

- `RenderParagraph(InlineSpan, {required TextDirection textDirection, ...})`
  avec le sous-ensemble commun `textAlign`, `softWrap`, `overflow`,
  `textScaler`, `maxLines`, `locale`, `strutStyle`, `textWidthBasis`,
  `textHeightBehavior`, `children`, `selectionColor` et `registrar` ; le
  paramètre `devicePixelRatio` ajouté sur 3.47.2 n'est pas utilisé ;
- getters/setters publics `InlineSpan RenderParagraph.text`,
  `TextScaler RenderParagraph.textScaler`, les propriétés de configuration
  ci-dessus, `Size RenderParagraph.textSize`,
  `bool RenderParagraph.didExceedMaxLines`,
  `SelectionRegistrar? RenderParagraph.registrar` et
  `Color? RenderParagraph.selectionColor` ;
- `void RenderObject.invokeLayoutCallback<T extends Constraints>(
  LayoutCallback<T> callback)` ;
- `bool InlineSpan.visitDirectChildren(InlineSpanVisitor visitor)`,
  `WidgetSpan`, `TextParentData.span` et
  `PlaceholderSpanIndexSemanticsTag(int index)` ;
- `RenderBox`, `RenderProxyBox`, `RenderObjectWithChildMixin<RenderBox>`,
  `BoxConstraints`, `getDryLayout`, `getDryBaseline`,
  `getMinIntrinsicWidth`, `getMaxIntrinsicWidth` et `layout` ;
- `TextPainter`, `PlaceholderDimensions`, `setPlaceholderDimensions`,
  `layout`, les métriques publiques et `dispose` ;
- `SelectionContainer.maybeOf`, `SelectionRegistrar` et les APIs publiques de
  `RenderParagraph` pour conserver sélection, recognizers et sémantique.

`WidgetSpan.extractFromInlineSpan` est public et commun, mais son arbre contient
un wrapper de scale privé dont le facteur est figé au build et inaccessible.
Il ne convient donc pas à des candidats choisis pendant layout. La solution
viable doit dupliquer uniquement le petit wrapper inline de transformation
(environ cent lignes), pas le painter, la sélection, la sémantique ni la logique
de `RenderParagraph`. Cette duplication bornée exige des tests de parité à
chaque hausse du minimum Flutter.

## Preuves et compteurs

Résultats identiques sur les deux pins sauf mention contraire :

- `C = 1024`, `P = 3` : 10 évaluations, 10 layouts paragraphe et 30 layouts
  enfants ; le mutant linéaire monte à 1025 évaluations et échoue ; coût
  observé `O(log C)` et `O(P log C)` ;
- projection groupe : candidat local 40, snapshot/render 18, un relayout final,
  une publication wet et zéro publication pour trois sélections dry ; le
  paragraphe est effectivement configuré à 18 ;
- six alignements (`top`, `middle`, `bottom`, `aboveBaseline`,
  `belowBaseline`, `baseline`) : tailles, candidats et baselines dry/wet égaux ;
- scaler non linéaire et runs 20/40/0 : facteurs 0,55 / 0,60 / 0, sans division
  par zéro, tailles égales au `RichText` témoin ;
- child wet-only : wet candidat 20 réussi, largeurs intrinsèques réussies avec
  zéro appel `getDryLayout`, puis FlutterError uniquement à la première requête
  dry ;
- enfant non monotone : candidat 1, `fits == true`, deux évaluations et même
  résultat après remontage ; un candidat supérieur qui tient peut être manqué ;
- painters temporaires : 4 créés/4 disposés sur le chemin normal, puis 5/5
  après exception injectée ; le `RenderParagraph` possédé est disposé une fois ;
- eager replacement expérimental : les deux states sont initialisés une fois,
  seule la branche active est peinte, hit-testée et sémantique, aucun dispose
  lors des flips, puis un dispose par branche au teardown ; l'usage de
  `Offstage` dans ce témoin ne prétend pas éviter le layout de l'inactive ;
- recognizer de texte, sémantique du child inline, tags de placeholder,
  `SelectionArea`, boxes de sélection, paint, transforms et hit testing sont
  conservés par le paragraphe réutilisé ;
- la recherche binaire garantit le plus grand candidat seulement sous
  monotonie. Hors monotonie, elle termine, rend un candidat effectivement
  vérifié comme sûr et reste déterministe ; elle ne promet pas l'optimum global.

Un child conforme peut annoncer l'absence de dry via
`debugCannotComputeDryLayout`. Sur les deux SDK, si cette erreur est interceptée,
Flutter peut laisser son drapeau debug interne de calcul dry engagé. Les probes
dry layout et dry baseline doivent employer des instances fraîches ; aucune
récupération du même `RenderObject` après cette erreur n'est promise.

## Blocage replacement

Le probe lazy a d'abord monté la branche texte sous des contraintes où elle
tient. Une requête `getDryLayout(maxWidth: 50)` a ensuite délégué à cette branche
encore montée et rendu `50 × 70`. Le wet avec les mêmes contraintes a légalement
exécuté le callback de layout, remplacé le texte et rendu la replacement
`30 × 40`. La trace fit → overflow → fit est
`replacement.init → replacement.dispose`, avec une seule branche sémantique et
le paragraphe disposé aux switches attendus.

Ce désaccord n'est pas un bug local réparable dans `computeDryLayout` : ce
dernier ne peut pas exécuter un builder spéculatif qui mute l'arbre. Le
`LayoutBuilder` public signale d'ailleurs exactement cette limite avec
`debugCannotComputeDryLayout`. Pour le lot 10, si la replacement active a
démonté le paragraphe, les render boxes des `WidgetSpan` n'existent plus non
plus et ne peuvent fournir leurs métriques dry.

## Voies de déblocage à décider

1. **Eager mount mitigé.** Monter texte et replacement, mais ne donner paint,
   hit testing, sélection et sémantique qu'à la branche active ; une frontière
   render dédiée peut éviter son layout wet tout en l'ayant disponible pour les
   requêtes dry. C'est la seule option actuellement démontrée en probe qui
   conserve un dry exact pour des widgets arbitraires. Coûts :
   `initState`/ressources des deux branches, mémoire, changement du lifecycle
   historique. Elle exige une décision de produit/API, une documentation
   majeure et un nouveau spike avec compteurs de layout, groupes, focus,
   tickers et replacement contenant des placeholders.
2. **API explicite de mesure.** Demander une taille/dry-measurer de replacement
   indépendante du widget monté. Cela permet le lazy mount mais introduit une
   nouvelle API manuelle, ne peut garantir la parité pour tout widget arbitraire
   et contredit le contrat actuel sans dimensions fournies. À retenir seulement
   si cette restriction/API est explicitement acceptée.
3. **Garantie dry révisée.** Garder le lazy mount et autoriser dry/intrinsics à
   utiliser la branche active mise en cache, ou à échouer lorsqu'un switch
   serait nécessaire. Cela préserve le lifecycle, mais abandonne l'égalité
   dry/wet avant wet et peut maintenir les six compositions intrinsèques
   bloquées. Cette voie doit définir précisément les ancêtres supportés et
   démontrer qu'elle résout encore les issues visées.

Une reconstruction spéculative depuis dry n'est pas une quatrième voie : elle
est interdite par les invariants de mutation Flutter et rendrait les effets de
lifecycle observables pendant une requête supposée pure.

## Plan révisé des lots 9 et 10

1. Suspendre les lots 9/10 et organiser la revue formelle du choix replacement.
2. Modifier explicitement le contrat du roadmap selon l'une des trois voies ;
   ne pas transformer implicitement « non montée » en eager.
3. Refaire un lot 8 ciblé : branche fraîche avant wet, dry layout/baseline et
   quatre intrinsics, flips lifecycle, groupes, semantics/selection, replacement
   avec `WidgetSpan`, minimum + haute et mutants.
4. Après nouveau GO seulement, lot 9 : introduire le parent render et le petit
   `RenderParagraph` pour texte simple/riche sans `WidgetSpan`, snapshot de
   groupe, dry/intrinsics, six reproductions et politique replacement décidée.
5. Lot 10 : ajouter extraction preorder, `TextParentData`, tags sémantiques et
   wrapper de scale public ; couvrir ordre 1:1, runs, zéro, baselines,
   dry/intrinsics distincts, paint/hit/selection, child wet-only, non-monotonie
   et `P log C`.

Jusqu'à ce nouveau GO, aucun code produit issu du spike ne doit être conservé et
aucun finding layout n'est considéré fermé.
