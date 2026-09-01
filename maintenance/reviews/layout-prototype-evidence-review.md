# Revue indépendante des preuves du prototype layout — lot 8

## Verdict

**PREUVES BLOQUÉES.**

Le noyau expérimental et le **NO-GO** du contrat lazy replacement sont
techniquement corroborés. En revanche, le lot de preuve publié n'est pas
reproductible dans son intégralité depuis le commit temporaire annoncé comme
complet : plusieurs claims matériels de la note proviennent de probes absents
du commit, dont le témoin exact `50 × 70` dry contre `30 × 40` wet. Une
reconstruction indépendante reproduit ce témoin sur les deux SDK, mais elle
oblige le relecteur à inventer le harness manquant et ne répare donc pas la
provenance documentaire.

Les lots 9 et 10 doivent rester suspendus. Le sens prudent de la décision est
bon ; ce sont l'exhaustivité et deux formulations de la preuve qui bloquent son
acceptation formelle.

## Périmètre audité

- base : `aac54f3eac23aa7c47a5439baf179f9394588aaa` ;
- spike : `dba563961a66ca09d40f471e3a72e5649752602f` ;
- tip : `ea5b52df8f15a364dec5fcd243d5931d00ffb959` ;
- note : `maintenance/layout-prototype-decision.md` ;
- spike extrait : `tool/layout_spike/spike.dart` ;
- gate extrait : `test/layout_spike_gate_test.dart` ;
- Flutter 3.41.0 et 3.47.2 déjà épinglés localement.

Les trois fichiers ont été lus intégralement. Les définitions pertinentes des
deux frameworks épinglés ont aussi été confrontées aux signatures annoncées.

## Provenance et arbre Git

La chaîne est linéaire et exacte :

```text
aac54f3 (tree e6de0ef1)
└─ dba5639 (tree e413d4e0) : +745 lignes de test, +1064 lignes de spike
   └─ ea5b52d (tree af39cf9c) : note +247, suppression des 1809 lignes
```

Constats :

- `dba5639` a bien `aac54f3` pour parent et ajoute uniquement les deux fichiers
  annoncés ;
- `ea5b52d` a bien `dba5639` pour parent ; son delta direct contient la note et
  la suppression des deux fichiers temporaires ;
- le diff cumulé `aac54f3..ea5b52d` contient uniquement la note ;
- hors `maintenance/layout-prototype-decision.md`, les arbres de la base et du
  tip ne diffèrent pas ;
- aucun chemin `layout_spike` n'est présent dans l'arbre du tip ; le spike reste
  volontairement accessible dans son histoire par son SHA ;
- le blob de la note au tip est `7baa2d03a0896ed875320ed6e1b63d3f495b8b1e` ;
- l'extraction `git archive dba5639` est byte-identique aux blobs Git pour les
  deux fichiers :
  - `spike.dart` SHA-256
    `33c0574252f605c8f94d427a7d13d73a795efa6c23ba78d1477d04610e4f6582` ;
  - `layout_spike_gate_test.dart` SHA-256
    `da456f7e8c988e8bfb85fec97717d68a21cecc275c603d23a2cd04746624eb0a`.

Le lock `example/pubspec.lock` est identique à la base, au spike, au tip et
après chaque résolution dans l'extraction : SHA-256
`115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7`.
`flutter pub get --no-example` crée bien un lock racine ignoré dans la copie
jetable ; aucun lock suivi n'est modifié.

## Matrice normale rejouée

La séquence annoncée a été exécutée depuis l'extraction exacte de `dba5639`,
avec le binaire de chaque SDK :

```sh
flutter pub get --no-example
dart format --output=none tool/layout_spike/spike.dart test/layout_spike_gate_test.dart
flutter analyze tool/layout_spike/spike.dart test/layout_spike_gate_test.dart
flutter test test/layout_spike_gate_test.dart --reporter expanded
```

| Pin | Framework / Dart | Format | Analyse | Gate |
| --- | --- | --- | --- | --- |
| 3.41.0 | `44a626f4f0` / 3.11.0 | 2 fichiers, 0 changement | aucune issue | 17/17 |
| 3.47.2 | `d3b14c8769` / 3.13.2 | 2 fichiers, 0 changement | aucune issue | 17/17 |

Les outputs discriminants sont identiques sur les deux pins :

- `C=1024`, `P=3` : 10 évaluations, 10 layouts paragraphe, 30 layouts enfants ;
- child wet-only : candidat 20, zéro requête dry pendant les deux largeurs
  intrinsèques ;
- groupe : local 40, render 18, un relayout final ; les trois sélections dry ne
  publient rien ;
- enfant non monotone : candidat 1, `fits=true`, deux évaluations ;
- painters : 4 créés/4 disposés, puis 5/5 après l'exception injectée ;
- six alignements de placeholder, scaling non linéaire et run zéro, lifecycle
  eager, recognizer/sélection/sémantique et quatre intrinsics : verts.

## Mutants

Les sept mutants ont été rejoués avec leur test ciblé. Chacun est tué avec un
exit 1 sur **les deux** pins ; le résultat est donc plus fort que la note pour
`intrinsic_uses_dry`, qu'elle ne revendiquait que sur 3.47.2.

| Mutant | Preuve de discrimination observée |
| --- | --- |
| `linear_search` | 1025 évaluations, contre une borne attendue de 12 |
| `wet_uses_dry` | exceptions de dry pendant le layout wet-only |
| `dry_publish` | 3 publications dry, contre 0 attendu |
| `skip_final_layout` | paragraphe configuré à 40, render attendu à 18 |
| `zero_division` | contraintes `maxWidth=NaN` et facteur `NaN` |
| `no_dispose` | 0 painter disposé, contre 4 créés |
| `intrinsic_uses_dry` | l'intrinsic appelle illégalement le chemin dry du child wet-only |

La fault injection est donc réellement sensible aux propriétés qu'elle prétend
garder.

## Claims corroborés

Le code, la matrice et les mutants corroborent les points suivants :

- recherche binaire virtuelle et bornes `O(log C)` / `O(P log C)` pour la
  fixture monotone ;
- résultat sûr et déterministe, mais non optimal, hors monotonie ;
- configuration wet sous `invokeLayoutCallback`, relayout final après
  projection groupe et publication après l'état effectivement rendu ;
- dry sans mutation du render tree ni publication, avec `TextPainter`
  temporaire disposé en `finally` ;
- distinction min/max intrinsèque pour les children, et chemin wet indépendant
  de `getDryLayout` ;
- extraction preorder des `WidgetSpan`, facteur par run et garde de division
  pour le run zéro ;
- égalité dry/wet des tailles et de la baseline alphabétique sur les six
  alignements testés ;
- conservation de la délégation principale à `RenderParagraph`, dont la
  sélection, les recognizers et la sémantique du child inline ;
- lifecycle eager observé : deux init, aucun dispose aux flips, un dispose par
  branche au teardown, une seule branche sémantique ;
- `LayoutBuilder` rejette le dry spéculatif en debug avec la raison annoncée ;
  après interception, la même instance n'est effectivement pas une base sûre
  pour une autre requête dry.

## Findings bloquants

### B1 — Le « commit temporaire complet » n'archive pas les probes de plusieurs claims

Le commit `dba5639` ne contient que 17 tests. Aucun d'eux ne produit ni ne
vérifie :

- le désaccord lazy exact `50 × 70` dry / `30 × 40` wet et la trace
  `replacement.init → replacement.dispose` ;
- les erreurs exactes obtenues en mutant `RenderParagraph.text` ou
  `textScaler` depuis son propre layout puis depuis celui du parent ;
- le probe spécifique de trois configure/layout, deux placeholders et six
  layouts leaf ;
- le retour dry mémoïsé après mutation externe d'un facteur ;
- les compteurs de paint/hit-test/tags de placeholder annoncés dans la synthèse ;
- le dispose du paragraphe lors des switches lazy.

Le dernier test archivé prouve seulement que `LayoutBuilder.getDryLayout` lève.
Les autres points sont plausibles, et plusieurs se déduisent du code Flutter,
mais ils ne sont pas rejouables avec les commandes documentées. La formulation
« commit temporaire complet du spike » et le résultat global qui suit donnent à
tort l'impression que les 17 tests portent toute la preuve.

Pour contrôler le claim le plus important, un probe de revue non publié a été
reconstruit avec les APIs publiques communes `ConstrainedLayoutBuilder`,
`RenderObjectWithLayoutCallbackMixin` et
`RenderAbstractLayoutBuilderMixin`. Sur les deux pins, il donne :

```text
dry=Size(50.0, 70.0)
wet=Size(30.0, 40.0)
trace=replacement.init → replacement.dispose
```

Ce résultat corrobore le blocker technique, mais ne rend pas l'archive
auto-suffisante : un futur relecteur ne doit pas avoir à réinventer ce probe.

### B2 — « widgets arbitraires » est trop large pour l'option eager

La note présente l'eager mount comme la seule option démontrée qui conserve un
dry exact pour des « widgets arbitraires ». Le témoin eager archivé ne mesure
aucun dry : il ne teste que lifecycle et sémantique, avec des `SizedBox`.

Surtout, l'eager mount ne rend pas dry-mesurable un widget qui ne sait pas
calculer son dry. Le même lot le démontre avec `LayoutBuilder` et
`SpikeWetOnlyBox`. Monter ces widgets à l'avance ne transforme pas leur
`debugCannotComputeDryLayout` en mesure exacte. La formulation doit être
restreinte aux branches montées **dont tout le sous-arbre supporte dry**, ou le
contrat doit autoriser l'échec/dimension fournie.

Cette correction ne renverse pas le NO-GO ; elle le renforce. Elle empêche en
revanche d'accepter l'option eager comme solution générale sans nouveau contrat.

### B3 — Plusieurs garanties sont des inspections de composition, pas des tests du gate

`Offstage` et le wrapper de transformation rendent crédibles les claims de
paint, hit testing et transform. Le gate n'attache toutefois aucun compteur à
ces chemins et ne vérifie pas explicitement les tags
`PlaceholderSpanIndexSemanticsTag`. Le test de tap cible le recognizer du texte,
pas le hit-test du child inline transformé.

Ces claims doivent être soit adoucis en observations d'implémentation, soit
couverts par des assertions dédiées. Ils ne sont pas nécessaires au blocker
replacement, mais ils participent à l'affirmation plus large que tout le noyau
render est validé.

## Surface API et caveats

Aucune divergence de signature revendiquée n'a été trouvée entre les deux pins :

- le constructeur commun de `RenderParagraph` contient bien le sous-ensemble
  listé ; `devicePixelRatio` est ajouté en 3.47.2 ;
- `text`, `textScaler`, `textSize`, `didExceedMaxLines`, `registrar` et
  `selectionColor` ont les types annoncés ;
- `InlineSpan.visitDirectChildren`, `WidgetSpan`, `TextParentData.span`,
  `PlaceholderSpanIndexSemanticsTag`, `TextPainter`, les APIs dry/intrinsic et
  `SelectionContainer.maybeOf` sont communs ;
- `WidgetSpan.extractFromInlineSpan(InlineSpan, TextScaler)` est public sur les
  deux pins, alors que `_AutoScaleInlineWidget` et
  `_RenderScaledInlineWidget` restent privés et figent le facteur fourni au
  build.

Caveats à conserver dans une décision exacte :

- `invokeLayoutCallback` est public au sens Dart mais annoté `@protected`,
  utilisable uniquement pendant layout et explicitement déconseillé par sa
  documentation ;
- `debugCannotComputeDryLayout` est une signalisation de debug ; en release,
  l'implémentation doit rendre une valeur factice et ne fournit toujours aucune
  mesure exacte ;
- `RenderParagraph` lui-même calcule sa baseline publique avec la baseline
  alphabétique, quel que soit l'argument `TextBaseline` ; la preuve archivée ne
  doit donc pas être décrite comme une validation de plusieurs types de
  baseline ;
- le wrapper privé Flutter représente environ 150 lignes render/widget sur ces
  pins, avant parent data et extraction. « Environ cent lignes » est un ordre de
  grandeur, pas une borne de duplication ;
- la branche eager actuelle emploie `Offstage`, qui continue volontairement à
  layout la branche inactive. La note le reconnaît correctement.

## Revue sécurité et qualité

Surface d'attaque : aucun réseau, base de données, authentification, session,
cryptographie ni appel externe dans les trois fichiers revus. L'unique entrée
variable propre au spike est `SPIKE_MUTANT`, limitée à de la fault injection de
test. Les widgets, contraintes et callbacks sont des fixtures locales.

Checklist appliquée aux trois fichiers : injection, XSS, authentification,
autorisation/IDOR, CSRF, session, cryptographie et fuite d'information : non
applicables ; race/TOCTOU : aucune concurrence ; DoS : le mutant linéaire est
volontaire et le chemin normal est borné ; logique métier et ressources : les
cas non-monotone, division zéro et disposal sont couverts. Les seules réserves
actionnables sont les lacunes de preuve B1–B3.

## Conditions d'acceptation

1. Ajouter au commit temporaire reproductible le probe lazy exact, avec ses
   dimensions, sa trace lifecycle, la sémantique et le dispose du paragraphe.
2. Archiver les probes setters/cache/3-cycles cités, ou retirer leurs résultats
   chiffrés et messages exacts de la note.
3. Remplacer « widgets arbitraires » par « sous-arbres supportant dry » et tester
   la limite avec une replacement `LayoutBuilder` ou wet-only.
4. Ajouter des assertions directes pour paint, transform, hit-test child et tags,
   ou reclasser ces points comme déductions de la composition Flutter.
5. Rejouer ensuite la même matrice sur 3.41.0 et 3.47.2 avant de convertir le
   verdict en **PREUVES ACCEPTÉES**.

## Nettoyage

La copie `git archive`, ses locks/caches racine et les deux probes de revue ont
été traités comme jetables. Aucun fichier du spike, aucune dépendance et aucun
changement de lock ne doivent rester dans le worktree de revue. Cette revue
ajoute uniquement le présent rapport.
