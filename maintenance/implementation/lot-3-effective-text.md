# Lot 3 — `TextScaler` et configuration effective du texte simple

Date : 2026-09-01

Branche : `codex/impl-effective-text`

Parent exact : `a13534cd12842b2e6847feb4963842175a96ee10`

Tête : commit contenant ce journal ; SHA final communiqué dans le compte rendu

## Périmètre livré

- paramètre public `TextScaler? textScaler` sur les deux constructeurs `const` ;
- conservation de `double? textScaleFactor`, déprécié, avec assertion de
  construction et `ArgumentError` runtime si les deux API sont fournies ;
- résolution du scaler dans l'ordre explicite, ancien facteur converti par
  `TextScaler.linear`, puis `MediaQuery.textScalerOf` ;
- composition non linéarisée du scaler source avec chaque candidat, avec
  validations finies et positives ou nulles des entrées et sorties ;
- snapshot immuable de la configuration effective du texte simple, reconstruit
  à chaque layout ;
- mesure et rendu alignés sur les règles Flutter 3.41/3.47 de `Text` et
  `RenderParagraph` ;
- passage de la configuration après overrides au `TextPainter`, mais de la
  configuration avant overrides au `Text` final, accompagnée du scaler
  candidat afin que Flutter n'applique chaque override qu'une fois ;
- maintien strict de la publication de tailles effectives et du rendu sans
  rescaling dans les groupes, comme sur le parent S3 ;
- migration des painters du package vers l'API moderne `textScaler`.

Hors périmètre : runs `RichText`, sémantique complète de référence zéro et
NBSP (lot 4), groupes hétérogènes (lot 5), intrinsics/render personnalisé,
`WidgetSpan`, démo, CI, packaging, documentation publique et version.

## Fichiers

- `lib/src/auto_size_text.dart` ;
- `lib/src/auto_size_text_layout.dart` ;
- `test/basic_test.dart` ;
- `test/utils.dart` ;
- `test/text_scaler_test.dart` ;
- `test/effective_text_configuration_test.dart` ;
- trois TTF de métriques sous-ensembles et leurs deux licences sous
  `test/assets/fonts/` ;
- présent journal.

## Contrat du scaler

Le scaler candidat stocke le scaler source, le candidat logique et la taille
logique de référence. Pour une taille logique `s`, il appelle exactement
`source.scale(s * candidate / reference)`. La recherche ne lit pas
`textScaleFactor` et ne remplace donc jamais un scaler non linéaire par une
pente locale. L'égalité et le hash comprennent les trois composantes.

Les tailles logiques, le candidat, la référence positive utilisée par la
composition, la taille ajustée et la sortie du scaler doivent être finies et
supérieures ou égales à zéro. Une sortie invalide d'un scaler tiers devient un
`ArgumentError` avant d'atteindre le rendu. Les exceptions propres au scaler
source restent propagées. Le cas historique de référence zéro du texte simple
reste supporté sans division ; sa généralisation aux runs riches appartient au
lot 4.

## Oracle de configuration effective

La taille de référence vient du style parent effectif lorsque `inherit` vaut
`true`, ou du style isolé lorsqu'il vaut `false`, avec fallback historique à
14. Le gras ambiant remplace le poids par `w700`. Les overrides MediaQuery de
hauteur de ligne, espacement des lettres et espacement des mots remplacent les
trois métriques correspondantes. Le strut n'est fusionné que lorsqu'un strut a
été explicitement fourni.

Le snapshot contient aussi l'alignement, la direction, la locale, `softWrap`,
l'overflow effectif, `maxLines`, `textWidthBasis` et le
`textHeightBehavior` provenant de `DefaultTextStyle` puis, à défaut, de
`DefaultTextHeightBehavior`.

Le painter utilise `constraints.minWidth`. Son `maxWidth` est la largeur
contrainte quand le texte wrappe ou utilise une ellipsis, et l'infini sinon.
L'ellipsis n'est installée que pour `TextOverflow.ellipsis`. Le résultat tient
si `didExceedMaxLines` est faux et si `constraints.constrain(textSize)` ne
réduit aucune dimension. Les tests reconstruisent un painter témoin depuis le
`RenderParagraph` réellement rendu et comparent les métriques, plutôt que
d'inspecter seulement le widget source.

## Preuves rouges sur le parent S3

Les nouvelles suites ont été placées sur une archive du parent exact, sans
aucun code produit du lot 3, puis exécutées avec Flutter 3.47.2.

La suite `test/text_scaler_test.dart` ne compilait pas : `textScaler` n'était
un paramètre nommé ni de `AutoSizeText` ni de `AutoSizeText.rich`. Cette preuve
couvre directement la nouvelle surface publique.

La version finale de la suite de configuration a été exécutée depuis
`/private/tmp/auto-size-text-lot3-red.9Kw42Q/repo` : code 1, 4 passages et
3 échecs. Les témoins distinguaient trois causes produit :

- un override métrique isolé attendait le candidat 23 mais l'ancien painter
  choisissait 30 ;
- l'override de hauteur du strut ne provoquait pas le remplacement attendu ;
- `softWrap: false` hérité ne déclenchait pas le remplacement alors que la
  largeur réelle du paragraphe débordait.

Les tests n'ont donc pas été rendus rouges par une attente artificielle : ils
comparent le candidat attendu par l'oracle et les métriques réelles de
`RenderParagraph`.

## Correctifs après les deux revues indépendantes

Les revues `9b948ea` et `02dd06d` ont demandé un correctif produit et deux
renforcements de preuves, sans élargir le lot.

### Sémantique historique des groupes

Une régression permanente a d'abord été exécutée sur `cac342c`. Deux membres
utilisaient respectivement le facteur historique 1 avec le preset `[20]` et le
facteur 2 avec le preset `[15]`. Le résultat était rouge exactement pour la
cause signalée : `[15, 30]` au lieu des tailles effectives historiques
`[20, 20]`.

Le résultat de recherche transporte désormais à nouveau sa taille effective.
Le groupe publie cette valeur, choisit le minimum effectif et chaque texte
simple groupé le rend avec `TextScaler.noScaling`, comme le parent. Aucune
projection de domaine ou convergence hétérogène du lot 5 n'est introduite.

### Fixtures de métriques déterministes

Les tests chargent une fois, via `File`, `ByteData.sublistView` et
`FontLoader`, trois sous-ensembles privés versionnés :

| Fixture | Taille | SHA-256 |
|---|---:|---|
| Roboto regular `w400` | 2 660 octets | `893780a2a9c1b15a9ee784b1e34568ff755d3ff9815c9fa755febe303d7bd9c1` |
| Roboto bold `w700` | 2 632 octets | `bab0b1b36298647122dfaee2e27c0bcb564c43f954be771e90abc94812fafa6d` |
| Noto Naskh Arabic avec `locl` | 5 212 octets | `d51e94755847f96a7cb9fdd53c91962ec6772a4d6b54c764e05b85e8d987af5a` |

Les Roboto proviennent des artefacts Flutter identiques des deux SDK et sont
sous Apache-2.0. Noto Naskh provient de la fixture engine identique des deux
SDK et reste sous OFL-1.1. Les licences complètes sont adjacentes. Les binaires
ne sont pas déclarés au manifeste : ils n'entrent pas dans le bundle client.

Chaque cas prouve sa divergence avant le widget : `MMMMMM` choisit 30 en
`w400` mais 29 en `w700`; `<<<<<<` choisit 30 en LTR mais 29 en RTL ; six
U+066C choisissent 30 en locale `ar` mais 26 en `fa` grâce à `locl`; `Hg` à
`height: 3` mesure 90 avec le comportement normal contre 35 avec ascent et
descent externes désactivés, et choisit respectivement 20 et 30 dans une boîte
de hauteur 60. Les tests comparent aussi `textSize`, `didExceedMaxLines`, les
métriques de ligne et, pour la hauteur, la baseline sèche du vrai
`RenderParagraph`. Le remplacement non additif d'une entrée `w900` par `w700`
reste couvert séparément.

### Rouges par mutations isolées de `cac342c`

L'archive jetable
`/private/tmp/auto-size-text-lot3-review-red.N47WFL/mutant` a reçu les tests
finaux puis une seule mutation à la fois. Supprimer le gras de la mesure donne
30 au lieu de 29 ; forcer LTR donne 30 au lieu de 29 ; ignorer la locale
héritée donne 30 au lieu de 26 ; ignorer `TextHeightBehavior` donne 20 au lieu
de 30. Les quatre cas sont rouges pour leur assertion de candidat, avant toute
inspection de propriété.

Le scaler plateau permanent rend 42 dans tous les cas. Il produit pourtant
cinq scalers composés dont source, candidat ou référence varient isolément.
Retirer séparément chacun des trois champs de `==`, puis de `hashCode`, a
produit six exécutions rouges. Avec les trois champs présents, deux
reconstructions identiques sont égales et ont le même hash, alors que les trois
variations restent inégales et possèdent ici des hashes distincts. Aucun type
privé ni API de test n'est exposé : les scalers sont lus sur le
`RenderParagraph` réellement rendu.

## Preuves vertes

Toolchains exactes :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
```

### Flutter 3.47.2

| Commande | Résultat |
|---|---|
| format `lib test example`, contrôle `--output=none --set-exit-if-changed` | 24 fichiers, 0 changement |
| analyse scoped fatale `lib test example/main.dart` | aucun diagnostic ; les 9 informations historiques ont disparu |
| `test/text_scaler_test.dart test/effective_text_configuration_test.dart` | 21/21 |
| suite racine complète | 77/77 |
| suites explicites cycle de vie/leak | 9/9 |
| exemple : `pub get --enforce-lockfile`, analyse fatale | succès, aucun diagnostic |

### Flutter 3.41.0

L'état final a été copié dans
`/private/tmp/auto-size-text-lot3-review-final-min.m0aa19/repo`, sans `.git`,
locks ni répertoires générés avant résolution.

| Commande | Résultat |
|---|---|
| `flutter pub get` racine | succès, 26 dépendances résolues naturellement |
| analyse scoped fatale `lib test example/main.dart` | aucun diagnostic |
| deux suites ciblées du lot | 21/21 |
| suite racine complète | 77/77 |
| suites explicites cycle de vie/leak | 9/9 |
| exemple sans lock : `flutter pub get`, analyse fatale | succès ; `meta 1.17.0`, `vector_math 2.2.0`, aucun diagnostic |
| `flutter pub downgrade`, puis suite complète | 9 dépendances abaissées ; 77/77 |

Le contrôle statique du code produit ne trouve ni appel à
`MediaQuery.textScaleFactorOf`, ni `textScaleFactor` sur un `TextPainter`, ni
shim `dynamic`, `noSuchMethod` ou `Function.apply`. L'ancien paramètre public
reste exercé explicitement par ses tests de compatibilité et de validation.

## Tests permanents ajoutés

La suite scaler couvre les deux constructeurs constants, l'exclusion mutuelle
en assertion et au runtime, l'absence de scaler explicite, le scaler ambiant,
`noScaling`, les scalers linéaire et non linéaire, l'ancien facteur, la priorité
explicite, les sorties non finies ou négatives, le changement entre pumps,
l'égalité/hash isolés du scaler candidat, un groupe homogène sous facteur 2 et
la conservation `[20, 20]` d'un groupe historique hétérogène.

La suite configuration couvre héritage vrai/faux et fallback, gras `w700`,
les trois overrides ensemble, isolément et entre pumps, strut 100/hauteur 60,
`softWrap` hérité et explicite, clip/ellipsis/remplacement, `minWidth` non nul,
RTL/LTR métriquement distincts, locale `ar/fa` avec substitution `locl`,
alignement, `textWidthBasis`, hauteur, baseline et les deux sources de
`textHeightBehavior`. Les tests de groupe historiques, dont la couverture
permanente du scénario #25, restent verts dans la suite complète.

## Limites et risques transmis

- la branche riche passe désormais par l'API moderne, mais l'oracle détaillé
  des runs, la référence zéro complète et NBSP restent strictement au lot 4 ;
- tous les groupes conservent strictement leur unité effective historique ; la
  projection entre scalers ou domaines hétérogènes reste au lot 5 ;
- aucun fichier de démo, CI, exemple, manifeste, lock, documentation publique
  ou version n'est modifié ;
- aucun merge, push, tag ou changement distant n'est effectué.
