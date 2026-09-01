# Revue finale des preuves du prototype layout — lot 8

## Verdict

**PREUVES ACCEPTÉES.**

Le spike2 ferme les lacunes de reproductibilité de la première revue. Les 28
tests et les 11 mutants sont archivés, discriminants et rejouables sur Flutter
3.41.0 et 3.47.2. Le NO-GO du contrat cumulant replacement lazy arbitraire,
branche inactive non montée et métrique dry exacte avant wet est correctement
étayé.

Ce verdict accepte les preuves du lot 8, pas un nouveau design. Les lots 9 et
10 restent suspendus jusqu'au choix explicite du futur contrat replacement.

## Provenance

Chaîne auditée :

```text
7a069d5  revue initiale
└─ a7cb410  archive temporaire spike2
   └─ 85e4cf6  suppression du spike2 et note finale
```

Constats :

- `a7cb410` ajoute uniquement quatre fichiers temporaires :
  `tool/layout_spike/{spike,evidence}.dart` et
  `test/layout_spike_{gate,evidence}_test.dart` ;
- `85e4cf6` les supprime et modifie uniquement
  `maintenance/layout-prototype-decision.md` ;
- le diff cumulé `7a069d5..85e4cf6` contient uniquement cette note ;
- aucun fichier `layout_spike` ne reste dans l'arbre du tip ;
- hors note, les arbres de `7a069d5` et `85e4cf6` sont identiques ;
- le worktree était propre avant la présente revue.

La note cite `06169f7` comme archive canonique. Ce commit est un frère, pas un
ancêtre de `85e4cf6`, mais la provenance reste exacte :

- `06169f7` ajoute lui aussi uniquement les quatre fichiers annoncés ;
- ses quatre blobs sont identiques à ceux de `a7cb410` ;
- `git diff 06169f7..a7cb410` contient uniquement la première version du présent
  rapport ; tout le reste de l'arbre est identique.

L'extraction indépendante de `a7cb410` a donné les SHA-256 publiés :

| Fichier | Lignes | SHA-256 |
| --- | ---: | --- |
| `spike.dart` | 1 136 | `2f49d3101031e1a52e607d72fcc32a42b5a68991a5d0463ad412448c3d077d35` |
| `evidence.dart` | 456 | `13860dbb9f9625b05c8bc5908870dbab826a27b3649d0e15e7fbbb91025f9419` |
| `layout_spike_gate_test.dart` | 745 | `da456f7e8c988e8bfb85fec97717d68a21cecc275c603d23a2cd04746624eb0a` |
| `layout_spike_evidence_test.dart` | 517 | `ae7ba0990a2378c4ba5e9e9ca1781ed991cf876c9d607d8243a6305289794c79` |

Le lock `example/pubspec.lock` est byte-identique à `7a069d5`, `a7cb410`,
`06169f7`, `85e4cf6` et après les deux replays : SHA-256
`115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7`.

## Matrice rejouée

Depuis l'extraction exacte de `a7cb410`, la séquence documentée a été exécutée
avec chaque SDK : résolution `--no-example`, format des quatre fichiers,
analyse des quatre fichiers, puis les deux fichiers de tests ensemble.

| Pin | Framework / Dart | Format | Analyse | Tests |
| --- | --- | --- | --- | --- |
| 3.41.0 | `44a626f4f0` / 3.11.0 | 4 fichiers, 0 changement | aucune issue | 28/28 |
| 3.47.2 | `d3b14c8769` / 3.13.2 | 4 fichiers, 0 changement | aucune issue | 28/28 |

Les compteurs hérités restent identiques sur les deux pins :

- `C=1024`, `P=3` : 10 évaluations, 10 layouts paragraphe, 30 layouts enfants ;
- groupe : local 40, rendu 18, un relayout final, zéro publication dry ;
- wet-only : candidat 20 et zéro dry pendant les largeurs intrinsèques ;
- non-monotone : candidat sûr 1, `fits=true`, deux évaluations ;
- painters : 4/4 disposés, puis 5/5 après exception.

## Onze mutants

Chaque mutant a été rejoué isolément avec son test cible. Les **11/11** sortent
avec exit 1 sur **les deux pins**.

| Mutant | Régression observée |
| --- | --- |
| `linear_search` | 1 025 évaluations au lieu de la borne 12 |
| `wet_uses_dry` | erreurs dry pendant le layout wet-only |
| `dry_publish` | 3 publications au lieu de 0 |
| `skip_final_layout` | état 40 au lieu du rendu projeté 18 |
| `zero_division` | facteur et contrainte `NaN` |
| `no_dispose` | 0 painter disposé au lieu de 4 |
| `intrinsic_uses_dry` | largeur intrinsèque envoyée au child dry |
| `zero_baseline_shortcut` | retourne 0 au lieu de propager le `FlutterError` child |
| `explicit_dry_uses_cache` | retourne `12×8` au lieu de `24×16` |
| `no_inline_transform` | transform 1 au lieu de 0,5 |
| `no_wrapper_dispose` | 0 dispose wrapper au lieu de 1 |

Les tests peuvent donc échouer lorsque chaque propriété annoncée est cassée ;
ils ne se contentent pas de confirmer des fixtures inertes.

## Preuves auparavant absentes

Toutes sont maintenant présentes dans `layout_spike_evidence_test.dart` et ont
été observées sur les deux pins.

### Blocker lazy et lifecycle

Sortie commune :

```text
wetFit=120x70
dryStale=50x70
wetReplacement=30x40
inits={text: 2, replacement: 1}
disposes={text: 1, replacement: 1}
layouts={text: 2, replacement: 1}
dry={text: 1}
taps={text: 1, replacement: 1}
```

Le teardown porte ensuite `text.dispose` à 2. Les assertions couvrent aussi la
branche sémantique active et le hit testing de chaque branche montée. Le désaccord
`50×70 != 30×40` sous les mêmes contraintes reproduit directement la limite du
cache de branche lazy.

### Eager et dry-capability

Une replacement eager déjà montée contenant un `LayoutBuilder`, puis une autre
contenant un subtree wet-only, lève dans les deux cas à la première requête dry.
La note corrige donc justement « widget arbitraire » en « subtree entièrement
dry-capable » : eager rend la branche disponible, pas mesurable par magie.

### Intrinsics, baseline et cache

- quatre intrinsics exactes contre `RenderParagraph` témoin :
  `[11, 37, 20, 20]` ;
- appels children distincts : min width 1, max width 1, dry 2, min/max height 0 ;
- mêmes résultats avec argument infini ;
- facteur zéro : l'absence de baseline dry du child reste un `FlutterError`,
  tandis qu'une baseline valide 6 devient 0 après scaling ;
- cache sans invalidation : `12×8`, contre helper à facteur explicite 2 :
  `24×16`.

### Fenêtre wet et inline

- quatre candidats valides et deux placeholders donnent exactement trois
  layouts paragraphe et six layouts leaf, avec candidat final 4 ;
- les deux messages d'assertion sont capturés dans un pipeline réel : mutation
  du paragraphe dans son propre `performLayout`, puis mutation interdite depuis
  un parent ordinaire ;
- le témoin inline vérifie paint, pointer down, hit test, transform 0,5, tag
  `PlaceholderSpanIndexSemanticsTag(0)`, registrar, boxes de sélection,
  recognizer, dispose wrapper et dispose paragraphe.

Ces résultats ferment les anciens findings B1 à B3.

## Claims de source et caveats

La lecture des sources des deux pins confirme les signatures communes décrites
dans la note, l'ajout de `devicePixelRatio` en 3.47.2, les wrappers privés de
`WidgetSpan.extractFromInlineSpan` et leur ordre de grandeur d'environ 150
lignes.

Les caveats sont correctement séparés des sorties du spike :

- `invokeLayoutCallback` est `@protected`, réservé au wet layout et déconseillé
  en usage général ;
- `debugCannotComputeDryLayout` est un signal debug, pas une métrique release ;
- la baseline validée est l'alphabétique employée par `RenderParagraph` ;
- les effets généraux d'un eager mount et les tickers `Offstage` sont attribués
  à l'inspection de source et aux revues lifecycle, pas aux 28 tests ;
- la recommandation d'étudier un mesureur explicite est présentée comme une
  option, pas comme un contrat déjà choisi.

La future décision pourra aussi choisir un fallback dry sûr et documenté pour
une replacement lazy arbitraire ; cela changera le contrat à valider, sans
remettre en cause les preuves actuelles de l'impossibilité d'une exactitude
universelle sans mesure fournie.

## Observation non bloquante

Dans ce replay, `flutter pub get --no-example` n'a pas réécrit le lock exemple ;
son SHA est resté inchangé après chaque pin. La phrase de la note disant que la
résolution 3.41.0 avait réécrit deux versions décrit donc un incident de la
production du spike, pas un effet reproduit par les commandes publiées. Le
résultat vérifiable important — lock final inchangé — est correct.

## Revue sécurité et qualité

Fichiers lus intégralement : la note finale, `spike.dart`, `evidence.dart` et les
deux fichiers de tests ; le gate historique est byte-identique à celui déjà lu
lors de la première revue.

Surface : contraintes/widgets locaux et `SPIKE_MUTANT`; aucun réseau, base de
données, authentification, session, cryptographie ou appel externe. Injection,
XSS, auth, autorisation/IDOR, CSRF, session, cryptographie et fuite : non
applicables. Race/TOCTOU : aucune concurrence. DoS : chemin normal borné, mutant
linéaire volontairement détecté. Logique et ressources : non-monotonie, zéro,
caches et disposals couverts. Aucun finding sécurité ou qualité bloquant.

## Nettoyage

L'extraction, son lock racine ignoré, ses caches et tous les résultats de build
ont été supprimés. Aucun spike, changement de dépendance ou modification de lock
ne reste dans le worktree. La présente mise à jour documentaire est le seul
changement de cette revue.
