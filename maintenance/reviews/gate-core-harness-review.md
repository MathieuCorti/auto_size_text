# Gate Cœur — contre-revue finale du harness

Date : 2026-09-01

Base S1 : `e9f75af9c3ef54bee2cbd3fcc0a53b44e7811968`

Base du correctif de harness : `9ec35e9f1481d346c7df5516de618b151de95097`

Tête revue : `37dc11913a905a106d04c8f977971389c95d2cd5`

Commits de reprise relus : `d1c131e`, `c652042` et `37dc119`. Ils sont les
cherry-picks des commits documentés `8301d7a`, `f4e4576` et de leur journal.

## Verdict

**PASS.** Le finding P2 de la contre-revue précédente est résolu. Aucun
finding P0, P1, P2 ou P3 n'est confirmé dans la reprise du harness, ses tests
ou son journal. Aucun correctif supplémentaire n'est recommandé.

`renderParagraphFits` est un témoin indépendant utilisable pour décider si le
`RenderParagraph` final satisfait le même prédicat de fit que le produit. Il
ne réutilise aucun symbole privé d'`auto_size_text`, ne lit pas l'état du
`State` produit et ne prend pas un `Text` source non résolu. Les quatre
régressions permanentes sont rouges avec l'ancien helper sur les deux SDK et
vertes à la tête. La matrice complète est verte sur le SDK haut, le plancher
naturel et le plancher downgradé.

## Indépendance et absence de tautologie

Le témoin reçoit un vrai `RenderParagraph` obtenu après montage d'un `Text`.
C'est Flutter, et non le helper ni l'algorithme privé d'`AutoSizeText`, qui a
donc déjà résolu l'héritage et construit le `InlineSpan` rendu. Le helper ne
fait appel qu'aux propriétés publiques de `RenderParagraph` et aux API
publiques `TextPainter`, `TextSelection` et `BoxConstraints`.

Il reproduit dans le harness le prédicat attendu, sans appeler
`_checkTextFits`, `_EffectiveTextConfiguration`,
`_UnbreakableTextSnapshot` ni aucune autre déclaration privée du package. La
segmentation de test est locale et ne partage aucun code avec celle du
produit. Ce double calcul est nécessaire : la taille publique du render object
est déjà contrainte et ne suffit pas, seule, à distinguer un texte ajusté d'un
texte tronqué par les contraintes.

Les attentes ne sont pas dérivées du helper : mot Ahem connu, limites exactes,
assertion publique et métriques de fixtures donnent les verdicts attendus. La
preuve rouge est directe : sur `d1c131e`, les quatre tests donnent 0/4 sous
Flutter 3.41.0 et 3.47.2, avec successivement `true` au lieu de `false`, aucun
rejet de zéro, un `StateError` de direction et `false` au lieu de `true` pour
le strut. Sur `c652042`/la tête, les mêmes quatre cas donnent 4/4 sur les deux
pins.

Le test rempli « should allow unlimited lines when maxLines is null » reste
également discriminant vis-à-vis du rendu final : le mutant de forwarding
`widget.maxLines ?? 1` réduit sa hauteur à une ligne et le rend rouge. Le test
du helper à `maxLines: 4` tue séparément la perte du `maxLines` dans son
`TextPainter`. Les preuves ne confondent donc plus forwarding final et mesure.

## Équivalence de `renderParagraphFits`

### Configuration résolue

| Élément du produit | Source du témoin | Résultat |
|---|---|---|
| texte et styles/runs | `paragraph.text` | identique au rendu, sans reconstruire le `Text` source |
| alignement et direction | `textAlign`, `textDirection` | valeurs effectives non nulles |
| scaler | `textScaler` | scaler explicite ou ambiant déjà résolu, y compris non linéaire |
| maximum de lignes | `maxLines` | `null` conservé, valeur finie transmise inchangée |
| ellipsis/overflow | `overflow` puis `\u2026` | même règle que le produit |
| locale | `locale` | locale explicite ou héritée résolue par Flutter |
| strut | `strutStyle` | strut effectif, override ambiant de hauteur compris |
| largeur/hauteur de texte | `textWidthBasis`, `textHeightBehavior` | valeurs effectives transmises |
| politique de wrap | `softWrap`, `overflow` | largeur finie pour wrap/ellipsis, infinie sinon |
| contraintes | `paragraph.constraints` | `minWidth`, `maxWidth`, `maxHeight` et `constrain` identiques |

Le painter principal appelle `layout` avec le même `minWidth` et le même
`layoutMaxWidth` que le produit. Il compare ensuite la taille de texte non
contrainte à `constraints.constrain(textSize)` et à
`didExceedMaxLines`. Les bornes de largeur et hauteur, y compris une hauteur
infinie, ont donc le même sens. Le probe temporaire distingue aussi
`softWrap:false` : forcer toujours `constraints.maxWidth` rend le cas clip
rouge avec `true` au lieu de `false`.

`TextWidthBasis` et `TextHeightBehavior` sont lus sur le render object, pas sur
le widget source. Les fixtures métriques existantes confirment direction,
locale, largeur de base et hauteur ; un probe dédié choisit une borne entre
les hauteurs normale et compacte et une borne entre les glyphes arabes et
farsi. Omettre la locale donne `true` au lieu de `false`; omettre le
`TextHeightBehavior` donne `false` au lieu de `true`.

### `wrapWords:false`, UTF-16 et espaces insécables

Le painter auxiliaire conserve le `InlineSpan` complet du paragraphe et est
mis en page à largeur infinie. Seule la chaîne visuelle
`toPlainText(includeSemanticsLabels: false)` sert à déterminer les offsets ;
les largeurs viennent des boîtes du span original, de sorte que styles, runs
et boîtes bidi ne sont pas aplatis.

Les offsets `RegExpMatch.start/end` et `TextSelection` sont des offsets UTF-16
dans une chaîne Dart. L'expression exclut les séparateurs `\s`, sauf U+00A0
NBSP et U+202F NNBSP explicitement réintégrés à la plage. Elle ignore donc les
plages vides autour de séparateurs consécutifs et conserve les espaces
insécables à l'intérieur du run, comme le scanner du produit.

Un probe temporaire utilise `A😀\u00A0A B` et choisit une largeur strictement
entre la sélection UTF-16 `0..4` et la plage correcte `0..5`. La tête refuse
le texte sur les deux SDK. Traiter NBSP comme un séparateur ou retrancher une
unité à l'endpoint produit `true` au lieu de `false`. Le même probe accepte le
corpus avec espace ordinaire.

### `maxLines` et cycle de vie

- `maxLines == null` reste illimité dans le painter principal ; le painter de
  plages est toujours illimité, conformément au produit.
- une valeur finie est transmise sans clamp ; le cas permanent à quatre lignes
  devient rouge si elle est supprimée ;
- `maxLines == 0` ne peut pas produire de `RenderParagraph` valide : le test
  monte le vrai widget et observe l'`AssertionError` public, au lieu de laisser
  un helper source normaliser zéro.

Les deux painters sont possédés localement et chacun est entouré d'un
`try/finally`. Le painter auxiliaire est libéré lors du retour anticipé et des
exceptions ; le principal l'est après fit, overflow ou exception. Le test
permanent de lifecycle suit le painter principal avec leak tracking. Un probe
leak-tracking temporaire supplémentaire a couvert le retour anticipé du
painter de plages et le chemin `wrapWords:false` qui utilise les deux painters :
2/2 sur chacun des SDK.

## Mutants et probes

Tous les mutants ont été appliqués séparément dans une extraction temporaire,
puis abandonnés.

| Mutant temporaire | Signal rouge observé |
|---|---|
| ne pas transmettre `RenderParagraph.maxLines` | `false` attendu, `true` obtenu dans `maxlines_test.dart` |
| supprimer la mesure des plages indivisibles | `false` attendu, `true` obtenu avec le mot Ahem illimité |
| remplacer le scaler résolu par `noScaling` | `false` attendu, `true` obtenu |
| omettre le strut effectif | borne serrée : `false` attendu, `true` obtenu |
| traiter NBSP comme séparateur | `false` attendu, `true` obtenu |
| tronquer l'endpoint UTF-16 d'une unité | `false` attendu, `true` obtenu |
| omettre la locale | farsi : `false` attendu, `true` obtenu |
| omettre `TextHeightBehavior` | hauteur compacte : `true` attendu, `false` obtenu |
| contraindre toujours la largeur malgré `softWrap:false` | `false` attendu, `true` obtenu |

Le probe élargi, sans accès privé, couvre trois groupes : UTF-16/NBSP et
espace ordinaire ; `maxLines` null/fini et `softWrap:false` ; locale et
`TextHeightBehavior`. Il donne 3/3 sur Flutter 3.41.0 et 3.47.2. Aucun fichier
de probe ou mutant ne reste dans le worktree canonique.

## Matrice indépendante

Toolchains réellement exécutées :

- Flutter 3.47.2, révision `d3b14c8769`, Dart 3.13.2 ;
- Flutter 3.41.0, révision `44a626f4f0`, Dart 3.11.0.

| Contrôle | 3.47.2 | 3.41.0 naturel | 3.41.0 downgradé |
|---|---:|---:|---:|
| résolution racine hors ligne | PASS | PASS | PASS, 9 dépendances abaissées |
| résolution/analyse exemple | PASS | PASS | PASS, 1 dépendance abaissée |
| format `lib test example/main.dart` | 28 fichiers, 0 changement | non autoritatif | non autoritatif |
| analyse fatale `lib test example/main.dart` | PASS | PASS | PASS |
| analyse fatale du package exemple | PASS | PASS | PASS |
| quatre reproductions à la tête | 4/4 | 4/4 | incluses ci-dessous |
| ciblés helper, config effective, wrap et lifecycle | 45/45 | 45/45 | 45/45 |
| suite complète canonique | 125/125 | 125/125 | 125/125 |
| probe UTF-16/config/contraintes | 3/3 | 3/3 | non requis |
| probe leak-tracking des deux chemins helper | 2/2 | 2/2 | non requis |

Le rouge `d1c131e` a été rejoué séparément : 0/4 sur chacun des deux SDK. Le
graphe minimum abaissé et tous les probes ont été confinés à des archives
temporaires.

## Tests, API et hygiène

Les nouveaux tests sont des widget tests déterministes. Ils n'utilisent ni
temps mural, ni `Future.delayed`, ni `pumpAndSettle`, ni timeout, ni accès
privé, ni `dynamic` pour contourner l'API. Ils montent de vrais widgets, lisent
un `RenderParagraph` public et utilisent des bornes fixes ou des fixtures
métriques. Le test zéro observe l'assertion publique. Aucun test n'appelle le
helper pour recalculer sa propre valeur attendue.

- `git diff --check e9f75af..37dc119` : PASS ;
- `git diff --check e9f75af...37dc119` : PASS ;
- 55 fichiers sur S1→tête avant ce rapport, aucun sous `demo/` ou `example/`,
  aucun lock ;
- six fichiers fonctionnels/documentaires dans les trois cherry-picks de
  reprise, plus le présent rapport de review déjà antérieur dans la lignée ;
- `example/pubspec.lock` reste byte-identique, SHA-256
  `115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7` ;
- aucun changement de démo, d'API publique, de fixture ou de lock ;
- le format autoritatif a été exécuté après résolution haute, sans diff ;
- aucun merge, push, tag ou publication n'a été effectué.

## Audit pré-conclusion

Fichiers du delta relus intégralement, état final et diff :

1. `maintenance/implementation/gate-core-fixes.md` ;
2. `test/maxlines_test.dart` ;
3. `test/preset_font_sizes_test.dart` ;
4. `test/text_fit_oracle_test.dart` ;
5. `test/text_painter_lifecycle_test.dart` ;
6. `test/utils.dart`.

Contexte relu : `lib/src/auto_size_text.dart`, les primitives de plages dans
`lib/src/auto_size_text_layout.dart`, `test/wrap_words_test.dart`,
`test/effective_text_configuration_test.dart`, le rapport précédent et les
instructions `find-bugs`, `developing-flutter`, Effective Dart et testing.
Aucun `AGENTS.md` additionnel n'existe dans le worktree ; l'instruction
PostHog fournie au chantier n'est pas applicable à cette revue locale.

Checklist `find-bugs` : injection, XSS, authentification,
autorisation/IDOR, CSRF, session, cryptographie, secrets et divulgation sont
hors surface ; le delta ne contient ni entrée distante, ni réseau, ni base,
ni template, ni identité. Les catégories applicables ont été vérifiées :
logique métier, limites numériques, disponibilité, opérations bornées,
exceptions, ownership des painters, courses et cycle de vie du render tree.
Aucun problème n'est confirmé. Aucune zone du périmètre demandé n'est restée
non vérifiée.
