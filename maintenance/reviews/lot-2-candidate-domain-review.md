# Revue indépendante du lot 2 — domaine de candidats

Date : 2026-09-01

Base exacte : `d77c08ea846474632e94888a7fa74f1ec0dc44ab`

Tête candidate : `af54facdc4b74071355d461772aa3e41c906a06a`

Périmètre : `_CandidateSet`, grille régulière, presets, dichotomie,
validations runtime, compatibilité des entrées publiques et preuves du lot 2.
Aucun correctif produit ou test permanent n'a été ajouté par cette revue.

## Verdict

**CHANGEMENTS REQUIS.**

La grille régulière et la dichotomie sont solides sur la surface vérifiée : le
domaine reste virtuel en `O(1)`, les petits domaines concordent avec un oracle
exhaustif indépendant, les domaines haute magnitude acceptés restent stricts,
la tolérance terminale est inclusive et la recherche d'environ un milliard de
candidats effectue 30 constructions de paragraphe.

Trois défauts bloquent néanmoins l'acceptation : un preset valide peut être
rejeté à cause de paramètres documentés comme ignorés, une hausse exacte
quasi égale dans les presets est acceptée avant déduplication, et un facteur
d'échelle fini peut produire une valeur dérivée infinie remise à Flutter au
lieu de lever `ArgumentError`. Ces trois cas contredisent directement l'oracle
numérique et ne sont couverts par aucun test permanent.

## Findings

### P1 — Les paramètres réguliers ignorés invalident un domaine de presets

**Emplacement :** `lib/src/auto_size_text.dart:254-261`,
`lib/src/auto_size_text_layout.dart:19-51`.

**Problème.** `_validateCandidateInputs` valide toujours `minFontSize`,
`maxFontSize` et `stepGranularity` avant de choisir la fabrique de domaine.
Pourtant les trois champs publics sont documentés comme ignorés lorsque
`presetFontSizes` est actif, et l'oracle impose de ne pas les utiliser pour
rejeter un preset valide. La référence de style et `textScaleFactor` restent,
eux, actifs et doivent toujours être validés.

**Preuve.** Le probe public temporaire suivant reçoit
`ArgumentError(minFontSize)` sur la tête candidate :

```dart
const AutoSizeText(
  '',
  presetFontSizes: <double>[20, 10],
  minFontSize: -1,
  maxFontSize: 0,
  stepGranularity: 0,
)
```

Le parent `d77c08e` ne consultait que la non-vacuité des presets dans cette
branche. Il s'agit donc aussi d'une régression de compatibilité pour une
configuration valide dans son mode actif, pas seulement d'un choix de
validation plus strict.

**Impact.** Une application qui fournit des presets et laisse des valeurs
sentinelles dans les champs sans effet échoue désormais au build, en debug
comme en release, malgré le contrat public « Is being ignored ».

**Correction attendue.** Séparer les validations toujours actives
(référence, ancien facteur) des validations régulières (minimum, maximum,
pas), puis n'exécuter ces dernières qu'en l'absence de presets. Ajouter un test
public pour les deux constructeurs avec un preset valide et les trois champs
réguliers invalides.

### P1 — Une hausse quasi égale des presets est silencieusement dédupliquée

**Emplacement :** `lib/src/auto_size_text_layout.dart:216-233`.

**Problème.** L'ordre est comparé au dernier représentant déjà dédupliqué et
la condition d'erreur exempte explicitement les valeurs quasi égales :
`value > previous && !nearlyEqual(...)`. L'oracle exige au contraire une
validation exacte, non croissante, du snapshot original **avant** toute
déduplication. La tolérance ne doit jamais transformer une hausse en égalité.

**Preuve.** Un accès temporaire au domaine privé a exécuté :

```dart
_CandidateSet.presets(<double>[20, 20.000000000000004, 10])
```

La fabrique retourne le domaine ascendant `[10, 20]`; elle devait lever
`ArgumentError`. `20.000000000000004` est le double immédiatement supérieur à
20. Le test permanent ne couvre que la direction valide
`[40, 39.99999999999999, 20]` et les hausses bien au-delà de la tolérance.

Le même ordre des opérations peut aussi masquer une remontée après un élément
supprimé, puisque `previous` provient de `uniqueDescending` plutôt que du
snapshot original.

**Impact.** Une liste qui viole explicitement le contrat descendant est
acceptée et réinterprétée silencieusement. Cela retire au caller le diagnostic
runtime déterministe promis par le lot.

**Correction attendue.** Parcourir d'abord le snapshot canonisé en comparant
chaque valeur à la valeur source précédente avec `value > previous`, sans
tolérance. Dédupliquer ensuite les voisins par rapport au représentant
conservé. Tester la hausse d'un ULP et une remontée vers le représentant après
un quasi-doublon supprimé.

### P1 — Un facteur fini déborde avant le painter sans garde `ArgumentError`

**Emplacement :** `lib/src/auto_size_text.dart:352-365`.

**Problème.** La validation accepte correctement tout `textScaleFactor` fini
et non négatif, y compris `double.maxFinite`. Les résultats arithmétiques ne
sont cependant jamais revalidés : `candidate * userScale` peut devenir
`Infinity` à la ligne 359, et `result.value * userScale` peut faire de même à
la ligne 364. La valeur non finie atteint ensuite le painter ou le `Text`
final. L'oracle exige qu'un facteur effectif NaN ou infini produise
`ArgumentError` avant toute remise à Flutter.

**Preuve.** Sous Flutter 3.47.2, ce probe public :

```dart
const AutoSizeText(
  'X',
  style: TextStyle(fontSize: 20),
  textScaleFactor: double.maxFinite,
)
```

ne produit pas `ArgumentError`. Le test observe plusieurs exceptions de
rendu, dont l'assertion Flutter `fontSize.isFinite` depuis
`_LinearTextScaler.scale`, puis des `RenderBox was not laid out`. Ce résultat
dépend donc encore des assertions du framework et peut diverger en release.
Les tests permanents rejettent NaN et les infinis en entrée, mais n'exercent
aucun overflow issu de valeurs individuellement finies.

**Impact.** Une entrée explicitement acceptée par la table runtime peut faire
échouer le pipeline de layout au lieu d'obtenir l'erreur publique stable du
lot. Un résultat infini peut aussi contaminer la valeur publiée à un groupe.

**Correction attendue.** Contrôler la finitude et la non-négativité de chaque
scale et taille effective calculés avant le painter, le groupe et le rendu,
puis lever `ArgumentError` avec le paramètre ou calcul concerné. Ajouter des
tests publics de produits finis et débordants, dont `double.maxFinite`.

## Vérification numérique indépendante

Les probes temporaires ouvraient un accès de lecture au domaine privé, puis ont
été entièrement supprimés. Ils n'ont laissé aucun changement dans le code ou
les tests.

- 315 combinaisons de petites grilles (`minimum`, `upper`, `step`) ont été
  comparées valeur par valeur à une énumération indépendante. Pour chaque
  domaine, tous les seuils monotones de dichotomie ont aussi été comparés à une
  recherche linéaire. Résultat : vert.
- 4 000 grilles déterministes autour de puissances de deux, jusqu'aux hautes
  magnitudes finies, ont vérifié la croissance stricte de chaque domaine
  accepté. Les rejets conservateurs autorisés par l'oracle n'ont pas été
  requalifiés en erreurs. Résultat : vert.
- La frontière terminale à `8 × 2^-52` est inclusive : à huit epsilons le
  dernier point est remplacé par l'upper exact; à neuf epsilons l'upper est un
  candidat distinct. Résultat : vert.
- `-0.0` devient `+0.0`, `double.minPositive` fusionne avec zéro en gardant
  l'upper exact, et le singleton `double.maxFinite` est accepté. Résultat :
  vert.
- Un quotient supérieur à `2^53 - 1` est rejeté avant `floor()`. Le milieu de
  dichotomie reste `left + (right - left) ~/ 2`; aucun passage par `double` ni
  addition `left + right` n'est utilisé. Résultat : vert par probe et lecture.
- Le snapshot des presets ne partage pas le stockage de la liste source et la
  déduplication descendante valide conserve le plus grand représentant exact.
  Résultat : vert hors finding d'ordre ci-dessus.
- Le chemin régulier ne contient ni `List`, ni `Iterable.generate`, ni boucle
  proportionnelle au nombre de candidats. Son état est composé de bornes, pas,
  longueurs et booléen en espace constant.
- Le test permanent `min=0.1`, `upper=100000000`, `step=0.1` représente environ
  un milliard de candidats. Une instrumentation temporaire a mesuré exactement
  30 appels à `_CountingTextSpan.build`, soit le nombre logarithmique de
  paragraphes spéculatifs; le replacement empêche un build final de masquer la
  mesure. La borne permanente `<= 40` est donc pertinente.

Les sous-flux vers zéro restent finis et canoniques, conformément au contrat.
Les overflows vers l'infini ne sont pas tous gardés, comme le démontre le
troisième finding.

## Reproduction rouge et matrice verte

Les deux SDK exacts annoncés ont été exécutés :

```text
Flutter 3.41.0 • 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • d3b14c8769 • Dart 3.13.2
```

### Parent exact

Les quatre fichiers de tests du lot ont été copiés sur une archive propre de
`d77c08e`, puis exécutés avec Flutter 3.47.2. Résultat : code 1,
**13 tests passés et 15 échecs**. Les échecs couvrent les assertions de
divisibilité, les types d'erreur runtime, l'upper quasi égal, les alias tardifs
et le quotient non représentable.

Le journal annonce `12` succès et `15` échecs, soit seulement 27 résultats
alors que les quatre suites actuelles contiennent 28 tests. Cette divergence
documentaire ne change pas la qualité de la preuve rouge : les 15 échecs et
leurs causes ont été reproduits, mais le compteur du journal doit être corrigé
lors de la reprise du lot.

### Flutter 3.47.2

| Contrôle | Résultat indépendant |
|---|---|
| Format canonique `lib test example` | 22 fichiers, 0 changement |
| Analyse scoped `lib test example/main.dart` | exactement 9 informations historiques `deprecated_member_use`, 0 warning, 0 erreur |
| Exemple, lock forcé puis analyse fatale | succès, aucun diagnostic, lock inchangé |
| Quatre suites ciblées du lot | 28/28 |
| Suite racine complète | 53/53 |
| Cycle de vie + signal de fuite | 9/9 |
| `git diff --check d77c08e...HEAD` | succès |

### Flutter 3.41.0

La tête a été extraite dans une copie sans artefact généré; le lock canonique
haut de l'exemple a été déplacé avant toute résolution minimum.

| Contrôle | Résultat indépendant |
|---|---|
| `pub get --no-example` | succès, 26 dépendances |
| Format des sept fichiers Dart modifiés par le lot | 0 changement |
| Analyse scoped `lib test example/main.dart` | les mêmes 9 informations historiques, 0 warning, 0 erreur |
| Exemple sans lock, résolution puis analyse fatale | succès, 10 dépendances, `meta 1.17.0`, `vector_math 2.2.0`, aucun diagnostic |
| Quatre suites ciblées du lot | 28/28 |
| Suite racine complète | 53/53 |
| Cycle de vie + signal de fuite | 9/9 |
| `pub downgrade --no-example`, puis suite `--no-pub` | 9 dépendances changées, 53/53 |

Le format complet `lib test example` avec Dart 3.11 signale deux fichiers du
lot 1 (`test/leak_tracking_test.dart` et
`test/text_painter_lifecycle_test.dart`) que ce formatter ancien réécrirait.
Aucun des sept fichiers Dart du lot 2 n'est concerné. La politique du dépôt
retient le format canonique haut, qui est propre; cette divergence de formatter
préexistante n'est pas un finding du lot 2.

Les tests publics invalides attendent `ArgumentError` et les branches qui les
servent sont des `if/throw` exécutés avant les assertions complémentaires.
Cette inspection, les tests publics sur les deux VM et l'absence de dépendance
à `assert` constituent la preuve sans assertions prévue par l'oracle lorsqu'un
harness widget release n'est pas disponible. Le probe d'overflow démontre la
lacune exacte qui échappe encore à cette preuve.

## Compatibilité et périmètre API

Les signatures, paramètres, valeurs par défaut et types publics ne changent
pas. Le nouveau fichier est un `part` privé et n'ajoute aucun symbole public.
Pour les domaines réguliers historiques valides, les résultats ciblés
12..60/pas 1, min/max, référence 33.5, plus grand fit et fallback au minimum
restent verts.

Le seul changement d'entrée valide hors intention est le premier finding : en
mode preset, des champs sans effet deviennent bloquants. Les comportements de
référence zéro RichText, `TextScaler`, configuration effective et groupes
hétérogènes restent attribués aux lots 3 à 5 et n'ont pas été requalifiés en
défauts du présent lot.

## Surface et checklist `find-bugs`

### Fichiers modifiés lus intégralement

- `lib/auto_size_text.dart` ;
- `lib/src/auto_size_text.dart` ;
- `lib/src/auto_size_text_layout.dart` ;
- `maintenance/implementation/lot-2-candidate-domain.md` ;
- `test/min_max_font_size_test.dart` ;
- `test/preset_font_sizes_test.dart` ;
- `test/step_granularity_test.dart` ;
- `test/text_fits_test.dart`.

Le contexte intégral lu comprend aussi `lib/src/auto_size_group.dart`,
`lib/src/auto_size_group_builder.dart`, `test/utils.dart`, les tests de cycle
de vie et de fuite, les manifests et options d'analyse, la politique de lock de
l'exemple, l'oracle numérique, le journal du lot, les plans/audits/revues du
cœur, le lot 2 et la gate finale de la roadmap, ainsi que les instructions
`developing-flutter`, Effective Dart, testing et `find-bugs`.

### Cartographie d'attaque

Les entrées sont les paramètres publics numériques et presets, la taille de
référence issue du style, le facteur explicite ou ambiant et les contraintes de
layout. Les appels externes se limitent à `MediaQuery`, `TextPainter` et au
rendu `Text`. Aucun accès réseau, base de données, fichier, commande, secret,
authentification, session, primitive cryptographique ou désérialisation n'est
ajouté. Le seul état partagé voisin est `AutoSizeGroup`; aucun fichier de
groupe n'est modifié.

| Classe de risque | Conclusion |
|---|---|
| Injection SQL/commande/template/header, XSS | Hors surface : aucune requête, commande ou sortie HTML. |
| Authentification, autorisation/IDOR, CSRF, session | Hors surface : aucune identité ni opération distante. |
| Cryptographie, secrets, divulgation | Hors surface : aucune primitive, persistance ou journalisation sensible. |
| Race/TOCTOU et état | Aucun nouveau flux asynchrone ou read-then-write; le groupe n'est pas modifié. |
| Déni de service / ressources | Grille régulière `O(1)`, recherche `O(log C)`, presets `O(P)` pour le snapshot requis; aucune allocation proportionnelle au ratio. |
| Logique numérique / métier | Trois findings P1 ci-dessus; les autres invariants testés sont conformes. |
| Compatibilité API | Signatures inchangées; une régression comportementale de mode preset est confirmée. |

## Condition de nouvelle revue

Le lot peut revenir en revue après correction des trois findings, ajout de
tests rouges sur `af54fac`, mise à jour du compteur rouge du journal, puis
rejeu des quatre suites ciblées, de la suite complète, de l'analyse scoped et
de la politique d'exemple sur Flutter 3.41.0 et 3.47.2. Aucun merge du lot 2
n'est acceptable avant cette reprise.
