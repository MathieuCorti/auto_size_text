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
vrai paragraphe multi-ligne sans limite. Le helper `doesTextFit` passe au
`TextPainter` le `maxLines` qu'il calcule pour `wrapWords:false`, et garde
correctement `null` comme limite illimitée. Dans une extraction du parent
produit `4ecdc88`, le nouveau test discriminant du helper était rouge avec
`Expected: false`, `Actual: true`; il est vert après la correction. Ces
changements restent strictement dans le harness.

## Matrice

Versions exactes :

- Flutter 3.47.2, révision `d3b14c8769`, Dart 3.13.2 ;
- Flutter 3.41.0, révision `44a626f4f0`, Dart 3.11.0.

| Contrôle | 3.47.2 | 3.41.0 naturel | 3.41.0 downgradé |
|---|---:|---:|---:|
| résolution racine | PASS | PASS | PASS, 9 dépendances abaissées |
| résolution/analyse exemple | PASS | PASS | graphe naturel conservé |
| format `lib test example` après résolution haute | PASS, 27 fichiers | non autoritatif | non autoritatif |
| analyse fatale package `lib test` | PASS | PASS | PASS |
| suites groupes et fuites ciblées | 34/34 | 34/34 | 34/34 |
| suite complète | 121/121 | 121/121 | 121/121 |
| probe compteur | 6/6 | 6/6 | non requis |

Le lock canonique `example/pubspec.lock` est resté byte-identique, SHA-256
`115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7`.
La résolution minimale et son downgrade ont été confinés à une extraction
temporaire ; aucun lock minimum n'a été recopié.

La démo reste explicitement différée au lot 6. Aucun merge, push, tag ou
publication n'a été effectué.
