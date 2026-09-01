# Revue lean des preuves du prototype layout — lot 8

## Verdict

**PREUVES BLOQUÉES.**

La provenance, l'archive canonique, la matrice à 32 tests et les 15 mutants
sont reproductibles sur Flutter 3.41.0 et 3.47.2. Le diff final ne conserve que
les deux documents annoncés et ne modifie ni code produit, ni manifeste, ni API
du package.

Le dossier ne suffit toutefois pas à accepter le GO tel qu'il est rédigé. La
note attribue à un « probe indépendant supplémentaire » plusieurs crash paths
et propriétés wet de `WidgetSpan` qui ne sont présents dans aucun artefact de
`f554255`, sans SHA, source, commande ni sortie permettant de les rejouer. Le
mini-probe archivé démontre les six métriques non-wet zéro et un wet layout
réel, mais pas paint, transform, hit test, sémantique, ni l'ordre 1:1 de
plusieurs placeholders. Accepter ces claims exigerait de créer de nouveaux cas
hors du contrat de la présente revue.

## Finding bloquant

### B1 — Le probe supplémentaire et une partie du contrat `WidgetSpan` ne sont pas archivés

La décision affirme :

- que le vrai child inline est peint, transformé, hit-testé et exposé aux
  sémantiques en wet ;
- que les dimensions zéro sont fournies 1:1 au `TextPainter`, dans l'ordre des
  placeholders ;
- qu'un probe indépendant a couvert contraintes tight/loose, axes infinis,
  scaler non linéaire, `maxLines`, texte vide/référence zéro, exception de
  scaler, paint, hit et sémantique sur les deux pins.

Références : `maintenance/layout-prototype-decision.md:73-80` et `:167-174`.

L'archive `f554255` ne contient que quatre tests lean dans
`test/layout_spike_lean_test.dart` :

1. replacement lazy et fallback texte minimum ;
2. quatre intrinsics texte-only ;
3. un unique placeholder zéro autour d'un child wet-only ;
4. référence typographique zéro.

Le troisième test (`:265-360`) vérifie le wet layout et la taille du child, les
six métriques zéro, les compteurs des six APIs et l'absence d'appel dry au
child. Il ne contient ni child peint/interactif/sémantique, ni assertion de
transform, paint, hit ou sémantique. Avec un seul `WidgetSpan`, il ne peut pas
discriminer une perte, une duplication ou une permutation des dimensions zéro.
Les preuves historiques de paint/hit/sémantique dans
`layout_spike_evidence_test.dart` portent sur `_SpikeRenderInlineScale`, pas
sur `SpikeLeanDryPlaceholder` ni sur le chemin lean combiné.

La sortie des 32 tests n'annonce que ces quatre tests lean. La recherche dans
les six artefacts ne trouve aucun autre probe tight/loose, texte vide ou
exception de scaler pour la frontière lean. Le commit qui introduit la phrase
du probe supplémentaire est `7a2f6a7`; aucun autre commit ne l'archive.

**Impact :** les garanties anti-crash centrales sont bien prouvées pour le cas
minimal archivé, mais la note généralise ce résultat à des chemins et à un
protocole multi-placeholder non reproductibles. Le GO et les changements du
roadmap reposent explicitement sur ces garanties. Les preuves restent donc
bloquées jusqu'à ce que les claims soient bornés aux quatre tests archivés ou
que le probe annoncé soit archivé et rejouable. Aucun de ces fixes n'est réalisé
par cette revue.

## Provenance et diff final

Chaîne vérifiée :

```text
dd1d0ad  base demandée
└─ 69f068e  restauration du spike2
   └─ f554255  archive canonique lean
      └─ 7a2f6a7  suppression des six artefacts et décision GO
```

Constats :

- `f554255^ = 69f068e` et `7a2f6a7^ = f554255` ;
- `dd1d0ad..f554255` ajoute exactement les six artefacts temporaires annoncés,
  pour 3 997 lignes ;
- `dd1d0ad..7a2f6a7` modifie exactement
  `maintenance/implementation-roadmap.md` et
  `maintenance/layout-prototype-decision.md` ;
- les six artefacts sont absents de `7a2f6a7` ;
- les diffs de `lib/**`, des manifests, de `example/pubspec.lock`, de README et
  du changelog sont vides entre la base, l'archive et le tip ;
- le diff API/package final est donc vide ; aucune nouvelle API publique n'est
  conservée ;
- le worktree de revue était propre à `7a2f6a7` avant ce rapport.

L'extraction par `git archive f554255` confirme exactement les métadonnées
publiées :

| Artefact | Lignes | SHA-256 |
| --- | ---: | --- |
| `tool/layout_spike/spike.dart` | 1 140 | `b33726d3c8482c632bfb60e41e01a5816edd319856010654f751ab4cfc476f3d` |
| `tool/layout_spike/evidence.dart` | 456 | `13860dbb9f9625b05c8bc5908870dbab826a27b3649d0e15e7fbbb91025f9419` |
| `tool/layout_spike/lean.dart` | 679 | `6487bc49bd3178b9f15bc87cc7e0737e973cc0e95cabae8acb8f0b30b18ff27a` |
| `test/layout_spike_gate_test.dart` | 745 | `da456f7e8c988e8bfb85fec97717d68a21cecc275c603d23a2cd04746624eb0a` |
| `test/layout_spike_evidence_test.dart` | 517 | `ae7ba0990a2378c4ba5e9e9ca1781ed991cf876c9d607d8243a6305289794c79` |
| `test/layout_spike_lean_test.dart` | 460 | `2ccf6c79523b43cce6f76061553c7d6d3d40a6521078b60b7b6cebe58b8f916f` |

## Matrice rejouée sur l'extraction exacte

Pins exécutées :

- Flutter 3.41.0, framework `44a626f4f0`, Dart 3.11.0 ;
- Flutter 3.47.2, framework `d3b14c8769`, Dart 3.13.2.

La séquence documentée a été rejouée avec chaque pin : résolution
`--no-example`, format des six fichiers, analyse des six fichiers, puis les
trois fichiers de tests ensemble.

| Contrôle | Flutter 3.41.0 | Flutter 3.47.2 |
| --- | --- | --- |
| Format | 6 fichiers, 0 changement | 6 fichiers, 0 changement |
| Analyse | aucune issue | aucune issue |
| Tests | 32/32 | 32/32 |

Les sorties communes confirment les compteurs et fallbacks essentiels :

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

Le fallback lazy est identique avant et après wet, la replacement n'est pas
construite par dry/intrinsic, le flip produit `30×40`, puis son state est
disposé au retour au texte. Les quatre intrinsics restent identiques avant et
après wet. Le placeholder wet-only mesure réellement `12×6` au wrapper et ses
six métriques non-wet valent zéro sans appeler le child.

## Quinze mutants

Chaque mutant a été exécuté isolément avec son test cible, sur les deux pins.
Les **15/15** retournent exit 1 sur chaque SDK :

| Mutant | Régression observée |
| --- | --- |
| `linear_search` | 1 025 évaluations au lieu de la borne 12 |
| `wet_uses_dry` | le child wet-only reçoit un dry illégal pendant wet |
| `dry_publish` | 3 publications au lieu de 0 |
| `skip_final_layout` | candidat configuré 40 au lieu du rendu projeté 18 |
| `zero_division` | baseline/facteur `NaN` au lieu de 0 |
| `no_dispose` | 0 painter disposé au lieu de 4 |
| `intrinsic_uses_dry` | `[23,23,20,20]` au lieu de `[11,37,20,20]` |
| `zero_baseline_shortcut` | retourne 0 au lieu de propager le `FlutterError` child |
| `explicit_dry_uses_cache` | `12×8` au lieu de `24×16` |
| `no_inline_transform` | transform 1 au lieu de 0,5 |
| `no_wrapper_dispose` | 0 dispose wrapper au lieu de 1 |
| `lean_reads_active_child` | dry atteint `_RenderLayoutBuilder` et lève |
| `lean_fallback_max_candidate` | fallback `40×20` au lieu de `40×10` |
| `lean_placeholder_calls_child_dry` | le trap lève sur dry layout |
| `lean_placeholder_calls_child_intrinsic` | le trap lève sur min intrinsic width |

Les mutants démontrent correctement les propriétés qu'ils ciblent. Aucun ne
couvre paint/transform/hit/sémantique du nouveau wrapper ou cardinalité/ordre
de plusieurs placeholders ; ils ne ferment donc pas B1.

## Lock et état

`example/pubspec.lock` est byte-identique à `dd1d0ad`, `f554255` et `7a2f6a7`,
avec le SHA-256 publié :
`115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7`.

Observation non bloquante : dans ce replay, `flutter pub get --no-example` avec
3.41.0 n'a pas réécrit le lock exemple, et le passage 3.47.2 n'a donc rien eu à
y restaurer. Les deux pins ont seulement changé le lock racine ignoré de
l'extraction temporaire. La phrase de la décision sur deux versions du lock
exemple décrit au mieux une manipulation antérieure non reproduite par la
séquence publiée ; l'état final et son hash restent exacts.

## Inventaire et revue qualité

Ont été lus intégralement : les deux documents du diff final et les six
artefacts de `f554255`. Surface d'attaque : contraintes, spans, widgets,
render objects, compteurs et `SPIKE_MUTANT` locaux. Aucun réseau, base de
données, authentification, autorisation, session ou cryptographie. Injection,
XSS, CSRF, IDOR, fuite de secret et race externe sont non applicables. Les
risques de logique, coût, cache, lifecycle et ressources correspondent aux
tests et mutants ci-dessus ; l'absence d'archive du probe élargi est la seule
lacune bloquante constatée.

La présente revue ne corrige, ne merge et ne pousse rien. Son rapport est le
seul fichier ajouté au tip de revue.
