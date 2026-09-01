# Décision du prototype layout — lot 8

## Verdict

**NO-GO du contrat actuel, inchangé.** Les lots 9 et 10 restent suspendus. Le
noyau render est faisable, mais le contrat cumule trois exigences incompatibles
pour un `overflowReplacement` arbitraire : branche inactive non montée, métrique
dry/intrinsic exacte avant wet, et aucune abstraction de mesure fournie par
l'appelant.

Le second spike ferme les lacunes de reproductibilité relevées par les trois
revues indépendantes. Il ne choisit pas un nouveau contrat. Une décision
mainteneur reste nécessaire entre eager mount borné, API explicite de mesure et
garantie dry réduite, puis un nouveau lot 8 doit valider ce choix avant tout code
produit.

## Provenance

- Base Gate Cœur : `aac54f3eac23aa7c47a5439baf179f9394588aaa`.
- Première archive du spike :
  `dba563961a66ca09d40f471e3a72e5649752602f`.
- Première note NO-GO :
  `ea5b52df8f15a364dec5fcd243d5931d00ffb959`.
- Revues ayant demandé les corrections :
  `92b83e6b985c2a7878b87e89c40fb1a260abe38f`,
  `7a069d53df4a121e50f3b118e50f8c711bacb169` et
  `3d088b6d71b8a5d5abc6626c8ad1d421a3103581`.
- **Seconde archive complète et reproductible du spike :**
  `06169f7ec5cd1d7ed99428b0144fd02508f94633`.

Le commit `06169f7` contient uniquement ces quatre fichiers temporaires :

| Fichier | Lignes | SHA-256 |
| --- | ---: | --- |
| `tool/layout_spike/spike.dart` | 1 136 | `2f49d3101031e1a52e607d72fcc32a42b5a68991a5d0463ad412448c3d077d35` |
| `tool/layout_spike/evidence.dart` | 456 | `13860dbb9f9625b05c8bc5908870dbab826a27b3649d0e15e7fbbb91025f9419` |
| `test/layout_spike_gate_test.dart` | 745 | `da456f7e8c988e8bfb85fec97717d68a21cecc275c603d23a2cd04746624eb0a` |
| `test/layout_spike_evidence_test.dart` | 517 | `ae7ba0990a2378c4ba5e9e9ca1781ed991cf876c9d607d8243a6305289794c79` |

Ils sont supprimés du tip conformément au lot 8. Le SHA permet de les relire
avec `git show <sha>:<path>` ou de tester le commit dans un worktree jetable.
Aucun code produit n'a été modifié.

## Matrice reproductible

Pins exactes :

- Flutter 3.41.0, framework `44a626f4f0`, Dart 3.11.0 ;
- Flutter 3.47.2, framework `d3b14c8769`, Dart 3.13.2.

Commandes exécutées sur `06169f7` avec chacun des deux SDK :

```sh
flutter pub get --no-example
dart format --output=none \
  tool/layout_spike/spike.dart \
  tool/layout_spike/evidence.dart \
  test/layout_spike_gate_test.dart \
  test/layout_spike_evidence_test.dart
flutter analyze \
  tool/layout_spike/spike.dart \
  tool/layout_spike/evidence.dart \
  test/layout_spike_gate_test.dart \
  test/layout_spike_evidence_test.dart
flutter test \
  test/layout_spike_gate_test.dart \
  test/layout_spike_evidence_test.dart \
  --reporter expanded
```

Résultat commun : 4 fichiers déjà formatés, analyse sans issue et **28/28 tests
verts**. La résolution 3.41.0 a mécaniquement réécrit deux versions dans le lock
exemple ; ces changements non désirés ont été restaurés avant commit. Le
`example/pubspec.lock` final est byte-identique à la base, SHA-256
`115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7`.

### Mutants

Chaque mutant a été exécuté isolément sur son test cible avec :

```sh
flutter test test/layout_spike_gate_test.dart \
  test/layout_spike_evidence_test.dart \
  --dart-define=SPIKE_MUTANT=<mutant> \
  --plain-name '<test ciblé>'
```

Les **11/11 mutants** sont tués avec exit 1 sur **les deux pins** :

| Mutant | Régression détectée |
| --- | --- |
| `linear_search` | 1 025 évaluations au lieu de la borne 12 |
| `wet_uses_dry` | appel dry illégal pendant le wet-only |
| `dry_publish` | trois publications depuis des requêtes dry |
| `skip_final_layout` | paragraphe laissé à 40 au lieu du rendu projeté à 18 |
| `zero_division` | facteur et contrainte `NaN` pour le run zéro |
| `no_dispose` | painters temporaires créés mais non disposés |
| `intrinsic_uses_dry` | largeur intrinsèque déléguée à `getDryLayout` |
| `zero_baseline_shortcut` | baseline zéro retournée sans interroger le child |
| `explicit_dry_uses_cache` | helper pur remplacé par la valeur dry mémoïsée |
| `no_inline_transform` | transformation inline 0,5 perdue |
| `no_wrapper_dispose` | wrapper inline non compté au teardown |

## Preuves exécutables archivées

Cette section ne contient que des résultats rejouables depuis `06169f7`.

### Blocker lazy exact

Le témoin emploie les APIs publiques `ConstrainedLayoutBuilder`,
`RenderObjectWithLayoutCallbackMixin` et
`RenderAbstractLayoutBuilderMixin`. Son dry délègue volontairement au seul
child déjà monté, tandis que le wet peut légalement reconstruire la branche :

| Étape | `maxWidth` | Branche montée | Taille | Lifecycle cumulé |
| --- | ---: | --- | ---: | --- |
| wet fit | 150 | texte | `120 × 70` | `text.init = 1` |
| dry overflow | 50 | texte historique | `50 × 70` | inchangé |
| wet overflow | 50 | replacement | `30 × 40` | `text.dispose = 1`, `replacement.init = 1` |
| wet fit | 150 | texte | `120 × 70` | `replacement.dispose = 1`, `text.init = 2` |
| teardown | — | aucune | — | `text.dispose = 2`, `replacement.dispose = 1` |

Sortie identique sur les deux pins :

```text
SPIKE2_LAZY wetFit=120x70 dryStale=50x70 wetReplacement=30x40
inits={text: 2, replacement: 1}
disposes={text: 1, replacement: 1}
layouts={text: 2, replacement: 1}
dry={text: 1}
taps={text: 1, replacement: 1}
```

Le test vérifie aussi qu'une seule branche est sémantique et hit-testable à
chaque étape. La requête dry n'initialise, ne dispose, ne wet-layoutte et
n'expose aucune branche.

Le désaccord `50 × 70 != 30 × 40` sous les mêmes contraintes est la preuve
directe du NO-GO : le cache de branche active ne satisfait pas le contrat dry,
et reconstruire la branche depuis dry muterait l'arbre.

### Eager : disponibilité, pas capacité dry

Le témoin eager `Stack` + `Offstage` monte les deux states. Le test archivé
prouve le coût de lifecycle : deux `initState`, aucun dispose aux flips, un
dispose par branche au teardown, avec une seule branche sémantique. Le wet
layout de l'inactive et les effets tickers d'`Offstage` restent classés plus bas
comme inspection de source et résultat de la revue lifecycle indépendante.

Deux nouveaux contre-exemples activent successivement une replacement déjà
montée contenant :

1. un `LayoutBuilder` public ;
2. un render subtree wet-only.

Dans les deux cas, la première requête dry lève un `FlutterError` sur 3.41.0 et
3.47.2. La conclusion exacte est :

```text
eager mount
  ⇒ le render subtree existe
  ⇏ ce subtree implémente le protocole dry demandé
```

L'eager ne peut donc offrir une mesure exacte que pour une branche montée dont
**tout le sous-arbre nécessaire est dry-capable**. Il ne résout pas un widget
arbitraire.

### Quatre intrinsics et APIs children distinctes

Un child témoin donne volontairement trois largeurs différentes : min
intrinsic 11, dry 23 et max intrinsic 37. Le spike est comparé à un
`RenderParagraph` indépendant avec un child équivalent.

Résultat commun :

```text
minWidth=11, maxWidth=37, minHeight=20, maxHeight=20
child.minWidth calls=1, child.maxWidth calls=1, child.dry calls=2
child.minHeight calls=0, child.maxHeight calls=0
```

Les appels avec argument infini rendent les mêmes valeurs. Les largeurs passent
donc bien par `getMinIntrinsicWidth` et `getMaxIntrinsicWidth`; les hauteurs
suivent le dry layout du placeholder, comme `RenderParagraph`. La hauteur 20,
et non 17, vient de la hauteur de ligne du paragraphe témoin et est comparée à
une valeur indépendante plutôt qu'à une simple propriété « finie ».

### Run zéro et baseline dry

À facteur zéro, le wrapper interroge encore `child.getDryBaseline` avant de
multiplier :

- child avec dry size mais sans dry baseline : `FlutterError`, non masquée ;
- child avec baseline dry/wet 6 : taille zéro et baseline zéro ;
- le wrapper est disposé une fois au teardown.

Le mutant `zero_baseline_shortcut` prouve que retourner zéro avant la requête au
child invalide bien le premier cas.

### Cache dry du facteur

Le probe calcule `12 × 8`, change ensuite le facteur externe de 1 à 2 sans
`markNeedsLayout`, puis réinterroge le même wrapper avec les mêmes contraintes :

```text
cache RenderBox = 12 × 8
helper pur dryAtScale(2) = 24 × 16
```

Le chemin dry de production devra donc prendre le facteur en argument et ne
jamais dépendre d'une mutation temporaire du wrapper ou de son cache.

### Fenêtre de mutation wet

Avec quatre candidats tous valides et deux placeholders, la dichotomie exécute
exactement trois cycles configure/layout : trois layouts paragraphe et six
layouts leaf. Le candidat final 4, les deux facteurs 1 et l'état configuré final
sont vérifiés.

Deux probes supplémentaires capturent dans un vrai pipeline les assertions :

- setter du paragraphe dans son propre `performLayout` :
  `mutated in its own performLayout` ;
- setter depuis un parent en layout ordinaire :
  `must not mutate its descendants`.

Le parent du spike ouvre donc obligatoirement sa fenêtre
`invokeLayoutCallback`, configure paragraphe et wrappers, puis appelle
`paragraph.layout`. Aucun `markNeedsLayout` récursif ne déclenche d'assertion.

### Inline, sélection, sémantique et ressources

Un child inline au facteur 0,5 vérifie directement :

- passage par `paint` ;
- hit test et réception du `PointerDownEvent` ;
- transformation vers le paragraphe de scale 0,5 ;
- tag `PlaceholderSpanIndexSemanticsTag(0)` ;
- registrar `SelectionArea`, boxes de sélection et recognizer du texte ;
- un dispose du wrapper inline et un dispose du paragraphe au teardown.

Les preuves héritées restent vertes : six alignements de placeholder, scaling
non linéaire des runs 20/40/0, span/scaler mis à jour, child wet-only, snapshot
de groupe sans publication dry, enfant non monotone, lifecycle eager,
recognizer/sémantique et disposal des painters. Les compteurs communs restent :

- `C = 1024`, `P = 3` : 10 évaluations, 10 layouts paragraphe, 30 layouts
  children ;
- groupe : local 40, rendu 18, un relayout final, zéro publication dry ;
- non monotone : candidat sûr 1 en deux évaluations, sans optimum global promis ;
- painters : 4/4 disposés, puis 5/5 après exception injectée.

## Architecture minimale viable hors replacement

```text
widget AutoSize
└─ RenderBox parent (candidats et snapshot de groupe)
   └─ petit sous-type de RenderParagraph
      └─ P wrappers inline (scale, baseline, paint et hit)
```

Le wet dichotomise un domaine virtuel. Sous `invokeLayoutCallback`, le parent
configure le `textScaler` du paragraphe et les facteurs inline, puis wet-layoutte
le paragraphe. Une projection de groupe différente impose un dernier relayout ;
une seule publication suit l'état final.

Le dry ne mute aucun render object et ne publie rien. Il construit les
dimensions de placeholders par helpers purs, utilise un `TextPainter`
temporaire par évaluation et le dispose en `finally`. Les largeurs intrinsèques
ont un backend min/max dédié ; dry layout, hauteurs et baselines emploient les
APIs dry des children.

Le facteur inline reste :

```text
runSize == 0 ? 0 : candidateScaler.scale(runSize) / runSize
```

Il affecte contraintes inverses, taille, baseline, paint et hit testing.

## Surface Flutter publique commune et caveats

Le spike compile sur le sous-ensemble commun suivant :

- `RenderParagraph(InlineSpan, {required TextDirection textDirection, ...})`
  avec `textAlign`, `softWrap`, `overflow`, `textScaler`, `maxLines`, `locale`,
  `strutStyle`, `textWidthBasis`, `textHeightBehavior`, `children`,
  `selectionColor` et `registrar` ; `devicePixelRatio`, ajouté en 3.47.2, est
  volontairement omis ;
- getters/setters `text`, `textScaler` et configuration publique du paragraphe,
  plus `textSize`, `didExceedMaxLines`, `registrar` et `selectionColor` ;
- `InlineSpan.visitDirectChildren`, `WidgetSpan`, `TextParentData.span` et
  `PlaceholderSpanIndexSemanticsTag` ;
- `RenderBox`, `RenderProxyBox`, `RenderObjectWithChildMixin`, `BoxConstraints`,
  `layout`, quatre intrinsics, `getDryLayout` et `getDryBaseline` ;
- `TextPainter`, `PlaceholderDimensions`, `setPlaceholderDimensions`, métriques
  publiques et `dispose` ;
- `SelectionContainer.maybeOf` et `SelectionRegistrar`.

`RenderObject.invokeLayoutCallback<T extends Constraints>(LayoutCallback<T>)`
est public au sens Dart, mais annoté **`@protected`**. Il est réservé aux
sous-classes pendant leur wet layout et sa documentation Flutter en déconseille
généralement l'usage. Le spike respecte cette fenêtre, mais cette dépendance est
un risque de maintenance à revoir à chaque pin Flutter ; ce n'est ni une API
privée ni une permission de muter pendant dry/intrinsic.

`WidgetSpan.extractFromInlineSpan` est public, mais retourne un arbre contenant
les wrappers privés `_AutoScaleInlineWidget` / `_RenderScaledInlineWidget` avec
facteur fixé au build et inaccessible. La réutilisation directe est impossible
pour un candidat choisi pendant layout. Le wrapper privé Flutter représente
environ **150 lignes widget/render** sur ces pins, avant parent data et
extraction. La solution devra assumer une duplication bornée de ce protocole,
pas annoncer « environ cent lignes » comme une borne, et conserver des tests de
parité à chaque changement de SDK. Aucun painter, algorithme de sélection ou
sémantique de `RenderParagraph` n'est copié.

`debugCannotComputeDryLayout` est un signal de debug. En release, l'assertion ne
fournit toujours aucune métrique exacte ; une valeur factice ne transforme pas
un subtree wet-only en subtree dry-capable. Après interception en debug, Flutter
peut laisser son drapeau de calcul dry engagé : les probes d'erreur utilisent
des instances fraîches et ne promettent pas la réutilisation du même
`RenderObject`.

La preuve de baseline du paragraphe porte sur la baseline alphabétique utilisée
par `RenderParagraph`; elle ne revendique pas plusieurs types de baseline.
L'enfant non monotone garantit terminaison, déterminisme et candidat réellement
testé comme sûr, pas le meilleur candidat global.

## Séparation des preuves

### Archivées et exécutées

Toutes les valeurs, traces, messages et compteurs de la section « Preuves
exécutables archivées » viennent des 28 tests au commit `06169f7` et ont été
rejoués sur les deux pins. Les 11 mutants appartiennent au même commit.

### Inspection de source et revues indépendantes

Les points suivants sont des conclusions de lecture, pas des compteurs du
spike2 :

- annotations et recommandations documentaires de `invokeLayoutCallback` ;
- différence `devicePixelRatio` du constructeur `RenderParagraph` ;
- caractère privé et taille approximative des wrappers Flutter ;
- effets généraux d'un eager mount applicatif : `didChangeDependencies`, timers,
  streams, requêtes, focus, tickers, `GlobalKey`, Hero et registrars ;
- impossibilité pour une enveloppe générique de neutraliser un effet arbitraire
  déclenché dans `initState`.

La revue lifecycle `3d088b6` a aussi observé, dans son propre probe indépendant,
que les deux branches `Offstage` sont wet-layoutées et que leurs tickers restent
actifs. Ces résultats motivent la prudence, mais ne sont pas présentés comme des
sorties du commit `06169f7`.

## Options de contrat et recommandation lifecycle

| Option | Dry exact | Lifecycle historique | Limite principale |
| --- | --- | --- | --- |
| Eager mount mitigé | seulement pour subtrees entièrement dry-capable | rompu | effets cachés, double subtree, descendants wet-only toujours bloquants |
| API explicite de mesure + widget lazy | oui si delegate pur et fidèle | conservé | nouvelle API et responsabilité de parité |
| Garantie dry réduite | cache inexact ou erreur honnête | conservé | compositions intrinsèques visées non débloquées |

La revue lifecycle recommande d'étudier en priorité **l'API explicite de mesure
avec branche widget lazy**, car elle rend la responsabilité observable sans
déclencher le lifecycle de la branche inactive. Cette recommandation est
intégrée comme entrée de décision, **pas adoptée ici comme nouveau contrat**.
La forme du delegate doit encore couvrir contraintes, baseline et quatre
intrinsics ; un simple `Size` constant ne suffit pas.

L'eager reste une alternative seulement si le mainteneur accepte explicitement
un changement majeur de lifecycle et un support limité aux subtrees dry-capable.
La garantie dry réduite ne constitue pas, en l'état, un déblocage des lots 9/10.

## Plan révisé

1. Maintenir le NO-GO, l'absence de `S7` et la suspension des lots 9/10.
2. Faire choisir formellement le contrat replacement par le mainteneur ; mettre
   à jour roadmap et documentation sans décision implicite.
3. Refaire un lot 8 ciblé sur le contrat choisi. Pour la voie recommandée :
   branche lazy fraîche, delegate pur, dry layout/baseline, quatre intrinsics,
   contraintes tight/loose et axes infinis, rebuilds, résultats non finis/hors
   contraintes et parité avec le replacement wet réel.
4. Tester l'absence d'`initState`, build, ticker, timer simulé, focus,
   sémantique, sélection et hit de l'inactive. Tester un replacement responsive,
   stateful, avec `WidgetSpan`, ainsi qu'un `LayoutBuilder` explicitement non
   mesurable sans delegate.
5. Si l'eager reste candidat, ajouter compteurs des deux wet layouts, tickers
   avec/sans `TickerMode`, focus, timers, sélection et collisions de clés.
6. Exiger de nouveau minimum + haute, mutants propres au mesureur/branches,
   revue render indépendante et note GO avant les lots 9/10.

Jusqu'à ce nouveau GO, aucun finding layout n'est fermé et aucun code du spike
ne doit rester au tip.
