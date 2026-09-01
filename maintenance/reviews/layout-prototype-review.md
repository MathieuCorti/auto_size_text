# Revalidation indépendante du prototype layout — lot 8

## Verdict final

**NOTE ACCEPTÉE.** Le second spike ferme les P1/P2/P3 de la première revue et
rend le dossier NO-GO reproductible sur Flutter 3.41.0 et 3.47.2. Aucun finding
P0 à P3 ne reste ouvert sur la note.

Le **NO-GO du contrat actuel est confirmé** : les lots 9 et 10 restent
suspendus, aucun `S7` n'est créé et aucun finding layout n'est fermé. Ce verdict
porte sur le cumul actuel « replacement arbitraire inactive non montée + mesure
dry/intrinsic exacte avant wet + aucun mesureur fourni ». Il n'interdit pas un
contrat futur plus simple qui préserverait le montage lazy et fournirait un
fallback dry sûr, borné et documenté plutôt qu'une exactitude impossible. Ce
choix relève du mainteneur et d'une révision explicite du roadmap, pas de cette
revalidation.

## Périmètre et provenance

- base Gate Cœur : `aac54f3eac23aa7c47a5439baf179f9394588aaa` ;
- première archive : `dba563961a66ca09d40f471e3a72e5649752602f` ;
- première note : `ea5b52df8f15a364dec5fcd243d5931d00ffb959` ;
- première revue : `92b83e6b985c2a7878b87e89c40fb1a260abe38f` ;
- archive source complète du spike2 :
  `06169f7ec5cd1d7ed99428b0144fd02508f94633` ;
- cherry-pick local de cette preuve : `b39d28e` ;
- note finale auditée : `41a6e21`.

Les quatre fichiers de preuve de `06169f7` et `b39d28e` sont byte-identiques.
Le cherry-pick ajoute le rapport antérieur à son arbre parce qu'il se trouve sur
la branche de revue, mais ne modifie aucun des quatre artefacts du spike2.

| Fichier historique | Lignes | SHA-256 |
| --- | ---: | --- |
| `tool/layout_spike/spike.dart` | 1 136 | `2f49d3101031e1a52e607d72fcc32a42b5a68991a5d0463ad412448c3d077d35` |
| `tool/layout_spike/evidence.dart` | 456 | `13860dbb9f9625b05c8bc5908870dbab826a27b3649d0e15e7fbbb91025f9419` |
| `test/layout_spike_gate_test.dart` | 745 | `da456f7e8c988e8bfb85fec97717d68a21cecc275c603d23a2cd04746624eb0a` |
| `test/layout_spike_evidence_test.dart` | 517 | `ae7ba0990a2378c4ba5e9e9ca1781ed991cf876c9d607d8243a6305289794c79` |

Les **2 854 lignes** ont été inspectées. Les fichiers sont absents du tip,
conformément au caractère jetable du lot 8 ; aucun code produit n'est conservé.

## Fermeture des findings initiaux

### P1 — Blocker lazy et lifecycle : fermé

Le commit de preuve contient maintenant un vrai
`ConstrainedLayoutBuilder`/render object lazy. Son wet peut reconstruire la
branche sous `invokeLayoutCallback`; son dry ne peut interroger que la branche
déjà montée.

Le test archive la séquence complète :

| Étape | Contrainte | Résultat | Lifecycle |
| --- | ---: | ---: | --- |
| wet fit | 150 | texte `120 × 70` | `text.init = 1` |
| dry overflow | 50 | texte historique `50 × 70` | inchangé |
| wet overflow | 50 | replacement `30 × 40` | texte disposé, replacement initialisée |
| wet fit | 150 | texte `120 × 70` | replacement disposée, nouveau texte initialisé |

Le dry et le wet rendent donc bien des tailles différentes sous les mêmes
contraintes quand seule la branche active historique est disponible. Les
compteurs de wet/dry layout, `initState`/`dispose`, sémantique, hit testing et
taps rendent la preuve discriminante. Le test démonte ensuite l'arbre et
vérifie les disposals finaux.

Le blocker n'est plus une simple déduction documentaire : il est archivé,
rejouable et identique sur les deux pins.

### P2 — Portée de l'eager mount : fermé

La note ne promet plus un dry exact pour tout widget arbitraire. Deux
contre-exemples montent puis activent une replacement contenant respectivement :

1. un `LayoutBuilder` ;
2. un subtree explicitement wet-only.

Dans les deux cas, la demande dry lève le `FlutterError` attendu. La conclusion
est correctement bornée : eager rend le subtree disponible, mais ne lui confère
pas une capacité dry. Cette option ne peut être exacte que si le sous-arbre
nécessaire est entièrement dry-capable, et elle modifie le lifecycle historique.

### P2 — Intrinsics exacts et APIs children distinctes : fermé

Un child témoin retourne volontairement trois largeurs différentes : min
intrinsic 11, dry 23 et max intrinsic 37. Le spike est comparé à un
`RenderParagraph` indépendant possédant un child équivalent.

Les quatre valeurs concordent exactement sur les deux SDK :

```text
minWidth=11, maxWidth=37, minHeight=20, maxHeight=20
```

Les appels avec argument infini concordent aussi. Les compteurs prouvent que
les largeurs utilisent `getMinIntrinsicWidth`/`getMaxIntrinsicWidth`, tandis
que les hauteurs passent par `getDryLayout`; les APIs intrinsèques de hauteur du
child ne sont pas utilisées, comme dans `RenderParagraph`. Le mutant
`intrinsic_uses_dry` est tué sur les deux pins.

### P3 — Baseline zéro, cache, interaction inline et API protégée : fermé

Les probes manquants sont désormais conservés et discriminants :

- facteur zéro avec child sans dry baseline : l'erreur n'est pas masquée ;
- facteur zéro avec baseline valide 6 : baseline et taille finales zéro ;
- le mutant `zero_baseline_shortcut` échoue ;
- un facteur externe changé sans invalidation laisse `getDryLayout` à
  `12 × 8`, tandis que le helper explicite rend `24 × 16` ;
- le mutant `explicit_dry_uses_cache` échoue ;
- un child inline au facteur 0,5 est peint, hit-testé et reçoit le
  `PointerDownEvent` avec la bonne transformation ;
- le tag `PlaceholderSpanIndexSemanticsTag(0)`, le registrar de
  `SelectionArea`, les boxes de sélection et le recognizer sont vérifiés ;
- wrapper et paragraphe sont disposés, avec mutants dédiés à la transformation
  et au disposal.

La note qualifie maintenant correctement `invokeLayoutCallback` : nom public
au sens Dart, mais membre **`@protected`**, réservé à une sous-classe pendant
son wet layout et généralement déconseillé par la documentation Flutter. Deux
probes capturent les assertions de mutation sans callback, puis le chemin
normal démontre trois cycles configure/layout, trois layouts paragraphe et six
layouts inline sans assertion récursive.

## Matrice indépendante

Le commit `b39d28e` a été extrait avec `git archive` dans un répertoire
temporaire. Sur les deux SDK exacts :

- Flutter 3.41.0, framework
  `44a626f4f0027bc38a46dc68aed5964b05a83c18` ;
- Flutter 3.47.2, framework
  `d3b14c876900e553bc736ca19295fc09e3853e8e`.

Commandes rejouées :

```text
flutter pub get --no-example
dart format --output=none <les quatre fichiers du spike2>
flutter analyze <les quatre fichiers du spike2>
flutter test test/layout_spike_gate_test.dart \
  test/layout_spike_evidence_test.dart --reporter expanded
```

Résultat sur chaque pin :

| Contrôle | 3.41.0 | 3.47.2 |
| --- | ---: | ---: |
| Format | 4 fichiers, 0 changement | 4 fichiers, 0 changement |
| Analyse | aucune issue | aucune issue |
| Tests | 28/28 | 28/28 |
| Lock exemple | SHA canonique | SHA canonique |

Le SHA-256 final d'`example/pubspec.lock` est
`115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7`.

### Mutants

Les 11 mutants ont été exécutés séparément avec les deux fichiers de test et
leur `--plain-name` ciblé. Chacun retourne exit 1 sur les deux SDK :

| Mutant | 3.41.0 | 3.47.2 |
| --- | ---: | ---: |
| `linear_search` | tué | tué |
| `wet_uses_dry` | tué | tué |
| `dry_publish` | tué | tué |
| `skip_final_layout` | tué | tué |
| `zero_division` | tué | tué |
| `no_dispose` | tué | tué |
| `intrinsic_uses_dry` | tué | tué |
| `zero_baseline_shortcut` | tué | tué |
| `explicit_dry_uses_cache` | tué | tué |
| `no_inline_transform` | tué | tué |
| `no_wrapper_dispose` | tué | tué |

Les compteurs hérités restent identiques : `C=1024`, `P=3`, 10 évaluations,
10 layouts paragraphe et 30 layouts children ; groupe local 40/rendu 18 avec
un relayout final et zéro publication dry ; non-monotone candidat sûr 1 en deux
évaluations ; painters 4/4 puis 5/5 après exception.

## Revalidation de l'architecture

La composition hors replacement reste crédible et minimale :

```text
RenderBox fitter
└─ petit sous-type de RenderParagraph
   └─ wrappers inline par run
```

- Wet configure paragraphe et wrappers dans la fenêtre protégée, wet-layoutte
  chaque candidat et laisse le candidat final effectivement rendu.
- Dry ne mute ni render object, ni groupe, ni cache de facteur ; les painters
  temporaires sont libérés en `finally`.
- Les backends intrinsic width, dry/height et wet child restent distincts ; un
  child wet-only fonctionne jusqu'à une demande dry réelle.
- Le wrapper duplique une petite frontière de transformation depuis des APIs
  publiques, pas le painter, la sélection ou la sémantique de
  `RenderParagraph`.
- Le coût monotone observé est `O(log C)` pour le paragraphe et
  `O(P log C)` pour les placeholders. Le non-monotone reste borné,
  déterministe et sûr sans promesse d'optimum global.
- Groupe, baseline, scaling par run, référence zéro, paint, hit test,
  sémantique, sélection et ressources disposent maintenant d'une preuve
  exécutable proportionnée au rôle de prototype.

Aucun type privé Flutter n'est importé. `WidgetSpan.extractFromInlineSpan`
reste inutilisable tel quel parce que ses wrappers privés figent le facteur au
build. La note borne honnêtement cette duplication et sépare les résultats de
tests des observations de source.

## Confirmation du NO-GO, sans sur-spécifier la suite

Le test lazy confirme qu'on ne peut pas obtenir une mesure exacte d'une branche
non montée avant le wet sans mesureur indépendant. Un eager mount ne résout pas
les descendants wet-only et change le lifecycle. Le NO-GO suit donc le contrat
et C4 du roadmap : nouveau choix explicite, nouvelle note et nouvelle revue
avant les lots 9/10.

Cette conclusion ne transforme pas l'exactitude universelle en objectif
permanent. Si le produit privilégie une amélioration robuste de l'amont et
l'absence de crash, le mainteneur peut choisir de conserver lazy et définir un
fallback dry sûr/documenté pour une replacement non mesurable. Cette voie devra
simplement remplacer explicitement l'exigence d'égalité dry/wet du contrat
actuel ; elle n'a pas à satisfaire les preuves d'une architecture que le
produit ne choisit plus.

## Inventaire et checklist finale

Lus intégralement :

- `maintenance/layout-prototype-decision.md` au commit `41a6e21` ;
- les 1 136 lignes de `tool/layout_spike/spike.dart` au commit de preuve ;
- les 456 lignes de `tool/layout_spike/evidence.dart` ;
- les 745 lignes de `test/layout_spike_gate_test.dart` ;
- les 517 lignes de `test/layout_spike_evidence_test.dart`.

Ont aussi été reconfirmés : lots 8 à 10 du roadmap, C4/C5 et gates de sa revue,
contrats du plan/review layout, ainsi que les sources Flutter des deux pins pour
`RenderObject`, `RenderBox`, `RenderParagraph`, `WidgetSpan` et
`LayoutBuilder`.

Surface d'entrée : spans, contraintes, scalers, snapshot de groupe et callbacks
locaux. Aucun serveur, base, stockage, authentification, autorisation, session,
secret ou cryptographie.

| Risque | Conclusion |
| --- | --- |
| Injection, XSS, SQL, commandes | hors surface |
| Authentification, autorisation/IDOR, CSRF, session | hors surface |
| Cryptographie, secrets, divulgation | hors surface |
| Race/état | snapshot dry immuable, zéro publication dry, lifecycle lazy archivé |
| Disponibilité/DoS | erreurs dry honnêtes, aucun fallback factice présenté comme exact, coût borné |
| Ressources | painters, paragraphe et wrappers couverts au teardown et après exception |
| Logique métier | blocker, eager, intrinsics, zéro, cache, groupe et non-monotonie couverts |

Appareil physique, web/profile et suite produit complète ne sont pas requis
pour accepter cette **note de prototype NO-GO** et ne deviennent pas de
nouvelles conditions exploratoires. Le répertoire d'archive et tous les
artefacts temporaires ont été supprimés après revalidation.

## Décision de sortie

**NOTE ACCEPTÉE ; NO-GO du contrat actuel confirmé ; lots 9/10 suspendus.**
