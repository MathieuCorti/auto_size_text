# Revue lean des preuves du prototype layout — lot 8

## Verdict final

**PREUVES ACCEPTÉES.**

La correction documentaire `c2b2047` ferme le blocage de la première revue.
Elle retire le probe indépendant non archivé de la preuve du gate, borne le
mini-probe `WidgetSpan` aux seules propriétés réellement présentes dans
`f554255` et reporte explicitement les garanties restantes au lot 10.

Le GO reste cohérent : le lot 8 valide la frontière render, le fallback texte
minimum de la replacement lazy et le principe des six métriques non-wet zéro ;
le lot 9 doit encore livrer et éprouver le chemin texte complet, puis le lot 10
doit livrer et éprouver le wrapper `WidgetSpan` complet. Aucune propriété non
prouvée du nouveau wrapper n'est désormais présentée comme acquise par le gate.

Cette revalidation porte uniquement sur les deux documents modifiés par
`c2b2047`. Aucun nouveau probe ou cas de test n'a été créé.

## Fermeture du finding B1

Le finding initial portait sur trois généralisations absentes de l'archive :
paint/transform/hit/sémantique du nouveau wrapper, cardinalité/ordre de
plusieurs placeholders et un probe élargi annoncé sans source ni sortie.

`c2b2047` les corrige de façon complète :

- le wet du mini-probe est limité aux métriques observées : child `12 × 8`,
  wrapper `12 × 6` ;
- les six métriques non-wet zéro et l'absence d'appel au child restent les
  seules garanties du wrapper lean revendiquées ;
- la note dit désormais explicitement que le test ne contient qu'un
  `WidgetSpan` et ne prouve ni paint, transform, hit, sémantique, disposal du
  nouveau wrapper, duplication, cardinalité ou ordre multi-placeholder ;
- le probe indépendant non archivé n'est plus compté comme preuve ;
- les onze mutants historiques sont distingués des quatre mutants `lean_*` ;
  les mutants historiques de transform/disposal ne sont plus attribués au
  nouveau wrapper ;
- le disposal prouvé est borné aux painters temporaires lean, au paragraphe
  historique et à l'ancien wrapper ; celui du wrapper zéro est remis au lot 10 ;
- `O(P log C)` est conservé comme résultat du spike historique et comme cible
  du lot 10, mais retiré des critères GO du mini-probe lean à un placeholder.

Le roadmap reprend les mêmes limites dans le lot 8 et place au lot 10 les
preuves de paint, transform, hit test, sémantique, disposal du nouveau wrapper,
ordre 1:1 et complexité `O(P log C)`. Les tests précis du lot 10 contiennent
déjà les cas multiple, ordre, interaction, semantics, child wet-only,
leak/rebuild et compteur. B1 est donc fermé sans diminuer la gate produit qui
suit le prototype.

## Correspondance entre claims et archive `f554255`

### Replacement lazy et fallback texte minimum

`test/layout_spike_lean_test.dart:9-181` archive :

- replacement `LayoutBuilder` initialement non construite et non montée ;
- descendant wet-only layouté normalement lors du flip overflow ;
- dry layout répété, dry baseline et quatre intrinsics avant puis après wet ;
- fallback au candidat minimum, contraint à `40 × 10`, distinct du wet
  replacement `30 × 40` ;
- contrainte alternative à 39, stabilité du fallback et absence de cache de
  branche active ;
- aucune construction/lifecycle/publication supplémentaire pendant les appels
  non-wet ;
- `initState` puis `dispose` uniques de la replacement ;
- égalité entre painters temporaires créés et disposés.

Les mutants `lean_reads_active_child` et `lean_fallback_max_candidate` rendent
respectivement le dry dépendant de `_RenderLayoutBuilder` et le fallback égal
au candidat maximum. Ils sont tués sur les deux pins.

### Texte sans replacement active

`test/layout_spike_lean_test.dart:184-263` compare les quatre intrinsics du
parent lean à un `SpikeAutoParagraph` témoin, sans monter la replacement, sans
publication non-wet et sans painter orphelin.

Les preuves historiques du même tree couvrent le sous-type de
`RenderParagraph`, les backends intrinsic min/max distincts, les hauteurs dry,
les baselines et alignements, le snapshot de groupe, les runs de tailles
différentes, le child non monotone, les ressources et la fenêtre
`invokeLayoutCallback`. La note distingue correctement ces preuves historiques
des quatre nouveaux tests lean.

Les combinaisons exhaustives tight/loose, axes infinis, scaler non linéaire,
`maxLines`, exception de scaler et les surfaces de sélection/sémantique du
chemin produit ne sont pas attribuées au gate lean. Le roadmap les maintient
comme tests obligatoires du lot 9 ou du lot 10 selon la surface concernée.

### Mini-probe `WidgetSpan`

`test/layout_spike_lean_test.dart:265-360` contient exactement un placeholder.
Il prouve :

- wet réel du child `12 × 8` et du wrapper `12 × 6` ;
- `Size.zero`, baseline zéro et quatre intrinsics zéro du wrapper ;
- appels non-wet du paragraphe sans crash ;
- compteurs non nuls pour chacune des six APIs du wrapper ;
- aucun appel dry/baseline/intrinsic au child témoin, qui lèverait sinon.

Les mutants `lean_placeholder_calls_child_dry` et
`lean_placeholder_calls_child_intrinsic` sont tués par les crash paths attendus
sur les deux pins. La décision ne revendique plus paint, transform, hit,
sémantique, disposal ou ordre multiple depuis ce test unique.

### Zéros, coût et ressources

Le quatrième test lean (`:363-392`) prouve que la référence typographique zéro
reste finie et sans exception. Les tests historiques du même commit prouvent
les runs inline zéro, `C=1024`/`P=3` avec 10 évaluations et 30 layouts children,
la terminaison non monotone et les disposals historiques. Le texte de
`c2b2047` attribue chacun de ces résultats à la bonne génération de spike.

## Provenance, diff et API

Chaîne auditée :

```text
dd1d0ad  base demandée
└─ 69f068e  restauration du spike2
   └─ f554255  archive canonique lean
      └─ 7a2f6a7  suppression des six artefacts et décision GO
         └─ fffff95  première revue des preuves lean
            └─ c2b2047  correction documentaire auditée
```

Constats :

- `c2b2047` modifie uniquement
  `maintenance/implementation-roadmap.md` et
  `maintenance/layout-prototype-decision.md` ;
- son diff contient 44 ajouts et 22 suppressions, sans erreur de whitespace ;
- les six artefacts de `f554255` sont inchangés et restent absents du tip ;
- les diffs de `lib/**`, des manifests, de `example/pubspec.lock`, de README et
  du changelog sont vides entre `dd1d0ad` et `c2b2047` ;
- le diff API/package est vide et aucune nouvelle API publique n'est conservée ;
- le worktree était propre à `c2b2047` avant la mise à jour de ce rapport.

L'extraction exacte de `f554255` conserve les six longueurs et SHA-256 publiés :

| Artefact | Lignes | SHA-256 |
| --- | ---: | --- |
| `tool/layout_spike/spike.dart` | 1 140 | `b33726d3c8482c632bfb60e41e01a5816edd319856010654f751ab4cfc476f3d` |
| `tool/layout_spike/evidence.dart` | 456 | `13860dbb9f9625b05c8bc5908870dbab826a27b3649d0e15e7fbbb91025f9419` |
| `tool/layout_spike/lean.dart` | 679 | `6487bc49bd3178b9f15bc87cc7e0737e973cc0e95cabae8acb8f0b30b18ff27a` |
| `test/layout_spike_gate_test.dart` | 745 | `da456f7e8c988e8bfb85fec97717d68a21cecc275c603d23a2cd04746624eb0a` |
| `test/layout_spike_evidence_test.dart` | 517 | `ae7ba0990a2378c4ba5e9e9ca1781ed991cf876c9d607d8243a6305289794c79` |
| `test/layout_spike_lean_test.dart` | 460 | `2ccf6c79523b43cce6f76061553c7d6d3d40a6521078b60b7b6cebe58b8f916f` |

## Matrice et mutants déjà rejoués

La correction est exclusivement documentaire ; les blobs testés n'ont pas
changé. La première revue a exécuté l'extraction exacte avec :

- Flutter 3.41.0, framework `44a626f4f0`, Dart 3.11.0 ;
- Flutter 3.47.2, framework `d3b14c8769`, Dart 3.13.2.

| Contrôle | Flutter 3.41.0 | Flutter 3.47.2 |
| --- | --- | --- |
| Format | 6 fichiers, 0 changement | 6 fichiers, 0 changement |
| Analyse | aucune issue | aucune issue |
| Tests | 32/32 | 32/32 |
| Mutants ciblés | 15/15 exit 1 | 15/15 exit 1 |

Les sorties communes restent :

```text
SPIKE_LEAN_LAZY dry=Size(40.0, 10.0) baseline=7.500
wetReplacement=Size(30.0, 40.0) replacementBuilds=1 lifecycle=1/1
SPIKE_LEAN_PLACEHOLDER wet=Size(12.0, 6.0)
dry=Size(0.0, 0.0) baseline=0 childDry=never
SPIKE_COUNTERS C=1024 P=3 evaluations=10 paragraph=10 children=30
SPIKE_GROUP local=40.0 render=18.0 finalRelayouts=1
SPIKE_NON_MONOTONE candidate=1.0 fits=true evaluations=2
SPIKE_PAINTERS created=4 disposed=4
SPIKE_PAINTERS_EXCEPTION created=5 disposed=5
```

Les quinze mutants restent correctement bornés : onze portent sur le spike
historique, quatre sur le contrat lean. Aucun mutant historique n'est utilisé
comme substitut à une preuve future du wrapper zéro.

## Lock et observation non bloquante

`example/pubspec.lock` est byte-identique à `dd1d0ad`, `f554255`, `7a2f6a7` et
`c2b2047`, SHA-256
`115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7`.

Lors du replay initial, `flutter pub get --no-example` sous 3.41.0 n'a pas
réécrit le lock exemple. La phrase de la décision sur deux versions décrit donc
une manipulation antérieure, pas un effet reproduit par la séquence publiée.
Cette observation reste non bloquante : l'état final, son hash et l'absence de
diff sont exacts.

## Cohérence GO et roadmap

La séparation finale est sans cycle ni promesse prématurée :

1. lot 8 : architecture minimale, replacement strictement lazy, fallback texte
   minimum, six métriques placeholder zéro et absence de consultation du child ;
2. lot 9 : implémentation texte simple/riche sans `WidgetSpan`, matrice
   tight/loose/infinis, scaler, `maxLines`, groupe, lifecycle, sémantique et
   complexité `O(log C)` ;
3. lot 10 : wrapper `WidgetSpan` complet, ordre 1:1, scale/baseline, paint,
   transform, hit, sémantique, disposal, multi-placeholder, non-monotonie et
   complexité `O(P log C)` ;
4. Gate Architecture : matrice des deux lots, divergences admises, benchmark et
   revues séparées puis cumulée.

Le GO autorise donc l'enchaînement du lot 9 puis du lot 10, mais ne ferme aucune
issue à lui seul. Les findings intrinsics ne deviennent fermables qu'au lot 9
et les findings `WidgetSpan` qu'au lot 10.

## Inventaire et revue qualité

Ont été lus intégralement : les deux documents corrigés, le présent rapport et
les six artefacts de `f554255`. Surface : documents, contraintes, spans,
widgets, render objects, compteurs et injection locale `SPIKE_MUTANT`. Aucun
réseau, base de données, authentification, autorisation, session ou
cryptographie. Injection, XSS, CSRF, IDOR, fuite de secret et race externe sont
non applicables. Le coût, les caches, le lifecycle et les ressources sont
attribués aux preuves ou aux lots futurs correspondants.

Aucun finding sécurité, logique ou reproductibilité ne reste ouvert sur la
correction `c2b2047`. La présente mise à jour du rapport est le seul changement
de cette revalidation.
