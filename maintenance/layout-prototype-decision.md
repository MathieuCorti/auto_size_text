# Décision du prototype layout — lot 8

## Verdict

**GO pour le contrat lean révisé.** Les lots 9 et 10 peuvent reprendre sur la
frontière render validée, sans nouvelle API publique du package, sans eager
mount et sans type privé Flutter.

Ce verdict ne réfute pas le NO-GO historique. Le contrat étudié par les deux
premiers spikes demandait simultanément, pour un `overflowReplacement`
arbitraire, une branche inactive non montée et sa géométrie dry exacte avant
tout wet. Le commit `06169f7` a correctement prouvé cette combinaison
impossible sans mesure fournie par l'appelant. Le présent GO la remplace par une
garantie plus simple et explicitement bornée : quand le texte déborde même au
plus petit candidat et que wet choisira la replacement lazy, dry et intrinsics
retournent les métriques contraintes du paragraphe à ce plus petit candidat.
Ils ne prétendent jamais mesurer la replacement.

La priorité retenue est l'absence de crash et d'effet de lifecycle caché. Elle
préserve les signatures et les call sites actuels. L'eager mount et une API de
delegate de mesure sont écartés.

## Contrat adopté

### Texte sans fallback actif

- Le parent est un `RenderBox` et le texte final reste un petit sous-type de
  `RenderParagraph` configuré pendant wet sous `invokeLayoutCallback`.
- Pour le texte simple et riche sans `WidgetSpan`, dry layout, dry baseline et
  les quatre intrinsics sélectionnent le même candidat que wet pour des
  contraintes et un snapshot de groupe identiques.
- Les largeurs intrinsèques emploient les backends min/max du paragraphe ; les
  hauteurs suivent son dry layout. Les contraintes synthétiques du roadmap,
  les minima non nuls et les axes infinis restent applicables.
- Dry et intrinsics sont purs : aucune mutation de render object, aucun build,
  aucune publication de groupe et aucun cache wet consulté.

### `overflowReplacement` lazy

- La replacement inactive n'est ni montée, ni construite, ni layoutée, ni
  peinte, ni hit-testée, ni exposée aux sémantiques.
- Wet mesure le texte, choisit la branche puis monte et layoutte normalement la
  replacement si le plus petit candidat ne tient pas. Un `LayoutBuilder` et un
  descendant wet-only fonctionnent dans cette branche.
- Dry layout, dry baseline et les quatre intrinsics ne montent et ne consultent
  jamais la replacement, y compris quand elle est la branche wet courante.
- Dans ce seul cas d'overflow local, ils mesurent le paragraphe au plus petit
  candidat, appliquent `BoxConstraints.constrain` à sa taille et retournent sa
  baseline. Cette valeur peut volontairement différer de la géométrie wet de la
  replacement.
- Des appels répétés avant et après wet rendent le même fallback fini et borné.
  Ils ne publient rien et ne dépendent ni de la branche active, ni d'une valeur
  de cache rendue périmée par un flip.

### Groupe, coût et ressources

- Le snapshot de groupe est une valeur immuable. Dry ne publie jamais ; wet
  publie le candidat local seulement après le layout final.
- Le domaine reste virtuel et la recherche normale reste `O(log C)` pour le
  texte et `O(P log C)` pour `P` placeholders monotones.
- Un child non monotone garde une terminaison déterministe et un candidat
  réellement testé comme sûr ; aucun optimum global n'est promis.
- Tous les `TextPainter` temporaires lean sont disposés en `finally`. Le spike
  historique vérifie aussi le disposal de son paragraphe et de son ancien
  wrapper inline ; le disposal du nouveau wrapper zéro reste à prouver au lot
  10.
- Une référence typographique zéro et les runs inline de taille zéro produisent
  des facteurs finis, sans division par zéro.

## Mini-probe `WidgetSpan` pour le lot 10

Le spike ne cherche pas une mesure universelle d'un widget arbitraire. Il
valide un fallback interne volontairement approximatif :

- wet layoutte réellement un child wet-only sans métrique manuelle : le child
  mesure `12 × 8` et son wrapper mesure `12 × 6` ;
- le wrapper interne renvoie `Size.zero`, baseline zéro et zéro pour les quatre
  intrinsics pendant dry/intrinsic ; il n'appelle aucune métrique du child ;
- un child témoin qui lève sur dry layout, dry baseline et chacune des quatre
  intrinsics ne reçoit aucun de ces appels.

Cette approximation peut modifier largeur, hauteur de ligne, coupure, baseline
et candidat par rapport au wet. Elle est acceptée comme solution anti-crash
lean, pas comme parité géométrique. Elle ne crée aucun paramètre public de
placeholder. Le test archivé ne contient qu'un `WidgetSpan` : il ne prouve ni
paint, transform, hit test ou sémantique du nouveau wrapper, ni cardinalité et
ordre de plusieurs placeholders. Ces propriétés restent des critères du lot
10.

## Provenance et historique conservé

- Base Gate Cœur historique :
  `aac54f3eac23aa7c47a5439baf179f9394588aaa`.
- Première archive : `dba563961a66ca09d40f471e3a72e5649752602f`.
- Première note NO-GO : `ea5b52df8f15a364dec5fcd243d5931d00ffb959`.
- Revues du premier dossier :
  `92b83e6b985c2a7878b87e89c40fb1a260abe38f`,
  `7a069d53df4a121e50f3b118e50f8c711bacb169` et
  `3d088b6d71b8a5d5abc6626c8ad1d421a3103581`.
- Seconde archive complète ayant fermé le dossier NO-GO exact :
  `06169f7ec5cd1d7ed99428b0144fd02508f94633`.
- Base demandée du nouveau lot 8 :
  `dd1d0aded0a9876896eba21c28119214ceea733f`.
- Restauration reproductible du spike2 : `69f068e`.
- **Archive reproductible du contrat lean : `f554255`.**

Le tree de `f554255` contient les six fichiers temporaires suivants :

| Fichier | Lignes | SHA-256 |
| --- | ---: | --- |
| `tool/layout_spike/spike.dart` | 1 140 | `b33726d3c8482c632bfb60e41e01a5816edd319856010654f751ab4cfc476f3d` |
| `tool/layout_spike/evidence.dart` | 456 | `13860dbb9f9625b05c8bc5908870dbab826a27b3649d0e15e7fbbb91025f9419` |
| `tool/layout_spike/lean.dart` | 679 | `6487bc49bd3178b9f15bc87cc7e0737e973cc0e95cabae8acb8f0b30b18ff27a` |
| `test/layout_spike_gate_test.dart` | 745 | `da456f7e8c988e8bfb85fec97717d68a21cecc275c603d23a2cd04746624eb0a` |
| `test/layout_spike_evidence_test.dart` | 517 | `ae7ba0990a2378c4ba5e9e9ca1781ed991cf876c9d607d8243a6305289794c79` |
| `test/layout_spike_lean_test.dart` | 460 | `2ccf6c79523b43cce6f76061553c7d6d3d40a6521078b60b7b6cebe58b8f916f` |

Ils sont supprimés du tip final. Aucun code produit n'a été conservé.

## Matrice reproductible

Pins exactes :

- Flutter 3.41.0, framework `44a626f4f0`, Dart 3.11.0 ;
- Flutter 3.47.2, framework `d3b14c8769`, Dart 3.13.2.

Séquence de reproduction sur `f554255` avec chaque pin :

```sh
flutter pub get --no-example
dart format --output=none \
  tool/layout_spike/spike.dart \
  tool/layout_spike/evidence.dart \
  tool/layout_spike/lean.dart \
  test/layout_spike_gate_test.dart \
  test/layout_spike_evidence_test.dart \
  test/layout_spike_lean_test.dart
flutter analyze \
  tool/layout_spike/spike.dart \
  tool/layout_spike/evidence.dart \
  tool/layout_spike/lean.dart \
  test/layout_spike_gate_test.dart \
  test/layout_spike_evidence_test.dart \
  test/layout_spike_lean_test.dart
flutter test \
  test/layout_spike_gate_test.dart \
  test/layout_spike_evidence_test.dart \
  test/layout_spike_lean_test.dart \
  --reporter expanded
```

Résultat commun : six fichiers formatés, analyse sans issue et **32/32 tests
verts**. Flutter 3.41.0 réécrit mécaniquement deux versions dans le lock de
l'exemple ; le passage final 3.47.2 les restaure. Le lock au commit et au tip est
byte-identique à la base, SHA-256
`115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7`.

Traces communes importantes :

```text
SPIKE_LEAN_LAZY dry=Size(40.0, 10.0) baseline=7.500
wetReplacement=Size(30.0, 40.0) replacementBuilds=1 lifecycle=1/1
SPIKE_LEAN_PLACEHOLDER wet=Size(12.0, 6.0)
dry=Size(0.0, 0.0) baseline=0 childDry=never
SPIKE_COUNTERS C=1024 P=3 evaluations=10 paragraph=10 children=30
SPIKE_GROUP local=40 render=18 finalRelayouts=1
SPIKE_NON_MONOTONE candidate=1 fits=true evaluations=2
```

Le probe lazy vérifie aussi la replacement `LayoutBuilder` avec descendant
wet-only, les quatre intrinsics avant/après wet, contraintes alternatives,
lifecycle `initState`/`dispose`, absence de publication dry et égalité du
fallback répété. Le probe WidgetSpan vérifie les six métriques sèches zéro et le
wet réel minimal décrit ci-dessus. Les deux autres tests lean comparent les
quatre intrinsics du chemin texte et vérifient qu'une référence typographique
zéro reste finie et sans exception. Les compteurs vérifient aussi que les
painters temporaires lean sont tous disposés.

Aucun probe indépendant non archivé n'est traité comme une preuve de ce gate.
En particulier, tight/loose exhaustif, axes infinis, scaler non linéaire et
`maxLines` combinés à la frontière lean, exception de scaler, paint, transform,
hit test, sémantique et ordre multi-placeholder restent à démontrer par les
lots produit concernés.

### Mutants

Les **15/15 mutants** sont tués avec exit 1 sur les deux pins. Les onze premiers
portent sur le spike historique ; les quatre mutants `lean_*` portent sur le
contrat révisé. Les mutants historiques de transform/disposal ne sont pas une
preuve du nouveau wrapper WidgetSpan lean.

| Mutant | Régression détectée |
| --- | --- |
| `linear_search` | recherche linéaire au lieu de `O(log C)` |
| `wet_uses_dry` | appel dry illégal pendant wet |
| `dry_publish` | publication depuis une requête pure |
| `skip_final_layout` | paragraphe laissé sur un candidat spéculatif |
| `zero_division` | facteur non fini pour un run zéro |
| `no_dispose` | painter temporaire non disposé |
| `intrinsic_uses_dry` | largeur intrinsèque déléguée à dry layout |
| `zero_baseline_shortcut` | protocole historique baseline contourné |
| `explicit_dry_uses_cache` | helper pur remplacé par un cache stale |
| `no_inline_transform` | transformation inline perdue |
| `no_wrapper_dispose` | wrapper non disposé |
| `lean_reads_active_child` | dry consulte la replacement wet active |
| `lean_fallback_max_candidate` | fallback au maximum au lieu du minimum |
| `lean_placeholder_calls_child_dry` | wrapper appelle dry/baseline du child |
| `lean_placeholder_calls_child_intrinsic` | wrapper appelle une intrinsic du child |

## Architecture minimale validée

```text
AutoSizeText
└─ RenderBox parent : sélection, snapshot de groupe, branche lazy
   ├─ texte actif : petit RenderParagraph
   │  └─ wrappers inline internes au lot 10
   └─ replacement active seulement après décision wet
```

Le parent ouvre la fenêtre `invokeLayoutCallback`, configure le paragraphe et
ses wrappers, puis appelle `paragraph.layout`. Le chemin dry construit des
mesures pures avec des painters temporaires. Il n'essaie jamais de reconstruire
un widget.

## Limites exactes du GO

1. En overflow local avec replacement, la géométrie dry/intrinsic est celle du
   texte minimum, pas celle de la replacement. L'égalité dry/wet n'est pas
   promise dans ce cas et seulement dans ce cas pour le lot 9.
2. Pour un `WidgetSpan`, les six métriques non-wet du wrapper sont zéro. Elles
   peuvent diverger du wet, changer le candidat et sous-estimer le paragraphe.
   Le lot 10 doit documenter cette approximation ; il ne promet pas l'égalité
   dry/wet pour ce cas.
3. Le fallback WidgetSpan ne reproduit pas la baseline, la hauteur ou la largeur
   intrinsèque du child. Il vise un résultat fini et sans crash.
4. Le mini-probe WidgetSpan ne prouve pas paint, transform, hit test, sémantique,
   sélection, disposal propre au nouveau wrapper, duplication ou ordre de
   plusieurs placeholders. Le lot 10 doit fournir ces preuves.
5. `invokeLayoutCallback` est public au sens Dart mais annoté `@protected`. Son
   usage reste borné aux sous-classes pendant wet et doit être revérifié à chaque
   mise à jour Flutter.
6. La preuve de baseline du paragraphe porte sur l'alphabétique. Les alignements
   inline historiques sont couverts, sans promesse universelle pour un child
   arbitraire.
7. La recherche logarithmique suppose la monotonie pour l'optimum. Un child non
   monotone reçoit seulement la garantie sûr/déterministe/borné.
8. Le spike n'est pas une implémentation produit et ne ferme aucune issue à lui
   seul. Les lots 9 et 10 doivent encore fournir tests rouges/verts, lifecycle,
   sélection, sémantique, compatibilité et revue indépendante.

## Décision d'implémentation

1. Créer `S7` avec cette note GO, sans aucun fichier de spike au tip.
2. Lot 9 : livrer texte simple/riche sans WidgetSpan, intrinsics exacts hors
   overflow replacement, fallback texte minimum documenté pour la replacement
   lazy et aucune nouvelle API.
3. Lot 10 : ajouter les wrappers WidgetSpan, conserver le wet automatique
   minimal et les six métriques non-wet zéro, puis prouver paint, transform, hit
   test, sémantique, disposal et ordre multi-placeholder, sans demander de
   dimensions à l'appelant.
4. Conserver les gates minimum/haute, les mutants de branche et de placeholder,
   et une revue render indépendante avant intégration.
