# Corrections de la Gate Cœur

Date : 2026-09-01

Base exacte : `b07066ffe321dff059c9d7d8008b2713e30e1aee` (`S6`)

Branche : `codex/fix-gate-core`

Périmètre : finding P2 de maintenance du minimum de `AutoSizeGroup`,
régressions sémantiques associées et deux dettes P3 du harness. Aucun
changement de démo, d'API publique, de politique de projection, de dry layout
ou de support de `WidgetSpan` n'est inclus.

## Commits atomiques

| Commit | Objet |
|---|---|
| `8cf1f0a` | régressions permanentes des transitions du minimum de groupe |
| `4ecdc88` | maintenance incrémentale du minimum dans le produit |
| `4883bb0` | réparation du harness `maxLines` et suppression des espaces finaux |
| `8301d7a` | quatre régressions rouges des divergences de l'oracle de fit |
| `f4e4576` | témoin `RenderParagraph` résolu et migration de tous ses appels |

Le présent journal est conservé dans un commit documentaire séparé.

## Correction du P2

Le groupe conserve la même map `membre -> rapport` et le même minimum effectif
`G`. Aucune structure auxiliaire ni nouvelle surface n'est introduite.

Lors d'une publication :

- une première publication ou une baisse strictement sous `G` remplace `G`
  directement en `O(1)` ;
- une valeur nouvelle supérieure ou égale à `G` provenant d'un non-minimum
  écrit son rapport sans scan ;
- si l'ancien rapport était exactement égal à `G` et remonte, un scan `O(M)`
  retrouve le minimum, y compris un ex aequo survivant.

Lors d'un retrait, le scan n'est exécuté que pour un rapport fini exactement
égal à `G`. Le marqueur interne `double.infinity` reste « non publié » et ne
déclenche pas de scan. Retirer le dernier rapport fini recalcule correctement
`G` vers `double.infinity`. Les comparaisons et notifications avant/après sont
inchangées : une notification n'est planifiée que si la valeur exacte de `G`
change, avec la coalescence existante.

Les tests permanents couvrent les premières vagues ascendante et descendante,
une baisse, la hausse d'un non-minimum puis sa révélation après retraits, la
hausse du minimum, les ex aequo, le retrait d'un minimum et d'un non-minimum,
le retrait du dernier membre et une nouvelle publication après retour à
`double.infinity`.

## Preuve déterministe de complexité

Deux extractions jetables ont ajouté des compteurs d'appels de
`_recalculateFontSize` et de visites de sa boucle. Le test n'utilise aucun
temps mural. Il construit uniquement des `AutoSizeText` publics à preset
unique, avec clés stables. Les mêmes attentes ont passé sur Flutter 3.41.0 et
3.47.2.

| Scénario | S6 appels/visites | Tête appels/visites |
|---|---:|---:|
| première vague ascendante, `M=64` | `64 / 4096` | `0 / 0` |
| première vague descendante, `M=64` | `64 / 4096` | `0 / 0` |
| baisse, `M=4` | `1 / 4` | `0 / 0` |
| hausse d'un non-minimum, `M=4` | `1 / 4` | `0 / 0` |
| hausse du minimum, `M=4` | `1 / 4` | `1 / 4` |
| retrait du minimum | `1 / 3` | `1 / 3` |
| retrait d'un non-minimum | `1 / 3` | `0 / 0` |

Le probe est donc rouge sur S6 avec `Expected: (0, 0)`,
`Actual: (64, 4096)` pour la première vague, puis vert sur la tête. Les
compteurs et tests de probe ne sont pas présents dans le worktree canonique.

## Mutants

Les mutants ont été appliqués séparément dans l'extraction instrumentée puis
abandonnés.

| Mutant | Oracle rouge observé |
|---|---|
| rescan inconditionnel à chaque publication | première vague : attendu `0/0`, obtenu `64/4096` |
| absence de rescan lorsque l'ancien minimum remonte | tailles attendues `30/30/30`, obtenues `20/20/20` |
| remplacement direct de `G` par la nouvelle valeur d'un minimum, sans traiter les ties | tailles attendues `20/20/20/20`, obtenues `30/20/30/30` |
| rescan au retrait d'un non-minimum | attendu `0/0`, obtenu `1/3` |

## Dettes P3

Les deux espaces finaux de
`maintenance/decisions/candidate-domain-oracle.md:3-4` ont été supprimés.
`git diff --check e9f75af9c3ef54bee2cbd3fcc0a53b44e7811968...HEAD`
est désormais propre.

Le test vide « Unlimited maxLines if parameter null » vérifie maintenant un
vrai paragraphe multi-ligne sans limite. La première réparation mécanique de
`doesTextFit` n'était toutefois pas un oracle fidèle de `wrapWords:false` : le
clamp du nombre de lignes ne modélisait pas la mesure séparée des plages
indivisibles et le helper ignorait plusieurs valeurs ambiantes.

Le helper prend désormais un `RenderParagraph` produit par un vrai `Text`
monté sous son contexte. Sa direction, sa locale, son scaler, son strut, son
`textWidthBasis`, son `textHeightBehavior`, son overflow, son soft-wrap et ses
contraintes sont donc déjà résolus par Flutter. Un painter non wrappé mesure
réellement chaque plage indivisible, espaces insécables compris ; un second
painter conserve le `maxLines` original pour le verdict de paragraphe. Les
deux painters sont libérés dans des blocs `finally`. `maxLines: 0` n'est plus
clampé par un helper source : la construction réelle du paragraphe applique
l'assertion publique `maxLines == null || maxLines > 0`.

Les trois anciens appels ont été migrés : sélection des presets, forwarding de
`maxLines` et test de cycle de vie. Quatre régressions permanentes reproduisent
le rapport externe : emergency wrap avec `maxLines == null`, rejet de zéro,
direction/scaler ambiants et override ambiant du strut. Elles étaient toutes
rouges sur `9ec35e9` sous Flutter 3.41.0 et 3.47.2, respectivement avec
`Actual: true`, retour sans assertion, `StateError` et `Actual: false`. Elles
sont vertes avec le témoin résolu. Aucun code produit ni API publique n'a été
modifié par cette reprise du harness.

Les mutants temporaires du témoin ont été abandonnés après exécution :

| Mutant harness | Oracle rouge observé |
|---|---|
| ne pas transmettre `RenderParagraph.maxLines` | attendu `false`, obtenu `true` dans le témoin `maxLines: 4` |
| supprimer la mesure des plages indivisibles | attendu `false`, obtenu `true` avec le mot Ahem et `maxLines == null` |
| remplacer le scaler ambiant résolu par `noScaling` | attendu `false`, obtenu `true` |
| omettre le strut effectif | attendu `false`, obtenu `true` sous la borne de hauteur serrée |

## Matrice

Versions exactes :

- Flutter 3.47.2, révision `d3b14c8769`, Dart 3.13.2 ;
- Flutter 3.41.0, révision `44a626f4f0`, Dart 3.11.0.

| Contrôle | 3.47.2 | 3.41.0 naturel | 3.41.0 downgradé |
|---|---:|---:|---:|
| résolution racine | PASS | PASS | PASS, 9 dépendances abaissées |
| résolution/analyse exemple | PASS | PASS | PASS, 1 dépendance abaissée |
| format `lib test example/main.dart` après résolution haute | PASS, 28 fichiers inchangés | non autoritatif | non autoritatif |
| analyse fatale cœur `lib test example/main.dart` | PASS | PASS | PASS |
| analyse fatale exemple | PASS | PASS | PASS |
| ciblés harness, groupes et fuites | 50/50 | 50/50 | 50/50 |
| suite complète | 125/125 | 125/125 | 125/125 |
| probe compteur groupe | 6/6 | 6/6 | non requis |

Un appel exploratoire non borné de `flutter analyze` a inclus `demo/`, hors
périmètre et explicitement différée au lot 6 ; il a retrouvé ses dépendances
absentes et API historique. Les analyses autoritatives ci-dessus ont ensuite
été relancées avec le périmètre cœur exact et sont vertes.

Le lock canonique `example/pubspec.lock` est resté byte-identique, SHA-256
`115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7`.
La résolution minimale et son downgrade ont été confinés à une extraction
temporaire ensuite supprimée ; aucun lock minimum n'a été recopié.

La démo reste explicitement différée au lot 6. Aucun merge, push, tag ou
publication n'a été effectué.
