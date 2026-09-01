# Revue d’assemblage d’intégration — lot 3 texte effectif

Date : 2026-09-01

Branche : `codex/integrate-effective-text-reviewed`

Base d’intégration avant lot :
`23851fda2fded1264aa90d34747d44b1a19918fa`

Tête assemblée examinée :
`9beb2127ff2294e2eb745796ab529a0e46a6e6ae`

Produit de référence final :
`7ca05ac8193ed029c7ec5b02c8ffaff08d21b8e0`

## Verdict

**ACCEPTÉ.**

L’assemblage n’a omis, dupliqué ni altéré aucun octet produit, test ou
configuration du lot 3. Les arbres `lib/`, `test/` et `example/`, ainsi que
`analysis_options.yaml` et `pubspec.yaml`, sont identiques à ceux du produit
de référence `7ca05ac`. Le journal d’implémentation est lui aussi identique.
Les seules différences avec cette référence sont la décision de fixtures déjà
présente dans la base d’intégration `23851fd` et les trois rapports finaux
ajoutés par l’intégration.

Les trois rapports conservent leur historique de findings, ferment chaque
finding et portent un verdict final `ACCEPTÉ` sans contradiction. Les cinq
fixtures/licences ont les tailles et hashes décidés, notamment la licence Noto
de 4 301 octets au SHA-256 complet `c3dd4c678171e42146614fd4fd132f474df05f7bd12d1348b4c5af50172c0e8f`.

Les matrices demandées sont vertes sous Flutter 3.41.0 et 3.47.2 : analyse
fatale sans diagnostic, 21/21 tests ciblés, 77/77 tests complets et 9/9 tests
explicites de leak/cycle de vie. Le format autoritatif haut et les deux chemins
de la politique de lock de l’exemple sont également verts. Aucun finding
actionnable ne reste.

## Historique et intégrité de l’assemblage

La plage `23851fd..9beb212` contient exactement onze commits, tous à un seul
parent : trois commits produit suivis de huit commits documentaires. Elle ne
contient aucun merge ni revert.

Les trois cherry-picks produit ont le même patch-id stable que leurs autorités :

| Autorité | Commit assemblé | Patch-id stable | Résultat |
|---|---|---|---|
| `cac342c` | `2881c8a` | `73ecbb6f3bd2d31f00038f0736acd274ac38a937` | identique |
| `129dfbc` | `5dadbce` | `481db3d1e7611b121e33180313643435433d1eeb` | identique |
| `7ca05ac` | `a32960c` | `b5b01414f180608804514e3bc9fff442b481b650` | identique |

Les huit commits suivants ne modifient que les trois rapports attendus :

- `3df347e`, `37dc10e`, `dd82ec6` :
  `lot-3-effective-text-review.md` ;
- `e032968`, `b86ba2f`, `633c447` :
  `lot-3-effective-text-accessibility-review.md` ;
- `2ade91e`, `9beb212` : `lot-3-text-fixtures-review.md`.

Cette séquence conserve la première revue, l’acceptation corrective et, pour
les deux premières revues, la vérification finale de provenance. Aucun de ces
commits ne touche `lib/`, `test/`, un manifeste, un lock ou l’exemple. Aucun
patch produit n’apparaît une seconde fois, en totalité ou en partie, après
`a32960c`.

Le diff cumulatif exact contre le parent `23851fd` porte sur quinze chemins :

- deux sources produit modifiées ;
- quatre fichiers Dart de test modifiés ou ajoutés ;
- trois TTF, deux licences et le journal ajoutés ;
- les trois rapports finaux ajoutés.

Il ne modifie aucun manifeste, lock, fichier d’exemple, configuration
d’analyse, CI, documentation publique ou version. `git diff --check` ne
signale aucune erreur.

## Comparaison octet pour octet avec `7ca05ac`

`git diff --quiet 7ca05ac..9beb212 -- lib test analysis_options.yaml
pubspec.yaml pubspec.lock example` retourne 0. Les objets Git comparés sont :

| Surface | Objet `7ca05ac` | Objet assemblé | Résultat |
|---|---|---|---|
| arbre `lib/` | `b6a2f6c5a7d61f2b1db9062fa5bfb50dd6b0c882` | même objet | identique |
| arbre `test/` | `9a855fd6bdc63f27da6878c112d7683b988b6a95` | même objet | identique |
| arbre `example/` | `2a71e44c83f196dd0aae2c82044f84dd21286a5d` | même objet | identique |
| `analysis_options.yaml` | `7ecb563db457534b266c002a51c10a1e0fc3a145` | même blob | identique |
| `pubspec.yaml` | `8726352b50234565181ec990d91566ab0fa3f918` | même blob | identique |

`maintenance/implementation/lot-3-effective-text.md` est aussi identique à
la référence. Le diff complet `7ca05ac..9beb212` contient seulement :

- `maintenance/decisions/text-metric-fixtures.md`, hérité de la base
  d’intégration et absent de la branche produit historique ;
- les trois rapports de revue finaux.

L’histoire merge/revert antérieure à `23851fd` n’a donc ni annulé ni remplacé
partiellement le lot lors de son assemblage sur cette base.

## Cohérence des trois rapports finaux

### Revue produit

`lot-3-effective-text-review.md` conserve la première revue `9b948ea`, décrit
les trois findings P1 initiaux, puis documente séparément leur résolution :
groupe legacy hétérogène, témoins métriques gras/direction/locale/hauteur et
égalité/hash du scaler. Son verdict final est `ACCEPTÉ` et affirme qu’aucun
finding n’est ouvert.

### Revue accessibilité

`lot-3-effective-text-accessibility-review.md` conserve la première revue
`02dd06d`, clôt ses deux findings P1 de preuve et documente en plus la
restauration de la compatibilité des groupes. Son verdict final est `ACCEPTÉ`
et affirme qu’aucun défaut produit ni lacune bloquante ne reste.

### Revue fixtures

`lot-3-text-fixtures-review.md` conserve le finding supply-chain initial,
documente sa résolution par `13eabfe` et distingue clairement la réduction
future du hinting comme recommandation non bloquante. Son verdict final est
`ACCEPTÉ` et affirme qu’aucun finding actionnable ne reste.

Les trois récits emploient des SHA de branches de revue distinctes, ce qui est
attendu, mais convergent sur les mêmes octets finaux. Aucun rapport ne porte
un verdict `CHANGEMENTS REQUIS` ou `REJETÉ`. Les formulations de provenance
historique de l’OFL diffèrent selon le périmètre des revues, sans produire de
divergence sur l’autorité finale : tous annoncent 4 301 octets, le texte
OFL-1.1 complet et le SHA-256 `c3dd4c…` présent dans l’assemblage.

## Fixtures et licences

| Fichier | Octets | SHA-256 vérifié |
|---|---:|---|
| `auto_size_metric_roboto_regular.ttf` | 2 660 | `893780a2a9c1b15a9ee784b1e34568ff755d3ff9815c9fa755febe303d7bd9c1` |
| `auto_size_metric_roboto_bold.ttf` | 2 632 | `bab0b1b36298647122dfaee2e27c0bcb564c43f954be771e90abc94812fafa6d` |
| `auto_size_metric_naskh_locl.ttf` | 5 212 | `d51e94755847f96a7cb9fdd53c91962ec6772a4d6b54c764e05b85e8d987af5a` |
| `LICENSE-Roboto.txt` | 11 358 | `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30` |
| `LICENSE-NotoNaskhArabic.txt` | 4 301 | `c3dd4c678171e42146614fd4fd132f474df05f7bd12d1348b4c5af50172c0e8f` |

`file` reconnaît les trois binaires comme TrueType. `fc-scan` retrouve Noto
Naskh Arabic Regular, Roboto Regular et Roboto Bold. `hb-shape` sélectionne
`uni066C` avec une avance 329 en arabe et `ThousandsSepFarsi` avec une avance
455 en farsi. Ces contrôles concordent avec la décision et les rapports.

Les avertissements Fontconfig sur ses répertoires de cache non inscriptibles
dans le sandbox n’affectent ni la lecture des fontes ni les résultats
retournés.

## Matrice rejouée

Toolchains exactes :

```text
Flutter 3.41.0 • framework 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • framework d3b14c8769 • Dart 3.13.2
```

| Gate | Flutter 3.41.0 | Flutter 3.47.2 |
|---|---:|---:|
| analyse `lib test example/main.dart` avec infos et warnings fatals | 0 diagnostic | 0 diagnostic |
| `effective_text_configuration` + `text_scaler` | 21/21 | 21/21 |
| suite racine complète | 77/77 | 77/77 |
| `leak_tracking` + `text_painter_lifecycle` | 9/9 | 9/9 |

Le chemin 3.47.2 a été exécuté dans le checkout assemblé. Le formatter Dart
3.13.2, en mode `--output=none --set-exit-if-changed`, a contrôlé 24 fichiers
de `lib`, `test` et `example` sans changement.

La politique de lock de l’exemple a été appliquée telle que décidée :

- sous 3.47.2, `example/pubspec.lock` a passé
  `pub get --enforce-lockfile`, puis l’analyse fatale sans diagnostic ;
- sous 3.41.0, `9beb212` a été extrait par `git archive` dans
  `/private/tmp/auto-size-text-lot3-assembly-min.mJJ7kM`, le lock haut a été
  déplacé hors de son nom reconnu, puis les résolutions racine et exemple ont
  été faites naturellement ; l’exemple a résolu `meta 1.17.0` et
  `vector_math 2.2.0`, puis son analyse fatale a réussi.

Les tests Flutter ont nécessité l’ouverture de sockets localhost par leur
harness ; l’échec initial du sandbox sur ces sockets a été remplacé par les
exécutions autorisées ci-dessus. Il ne s’agissait pas d’un échec de test.

## Audit `find-bugs`

### Surface lue

Les quinze fichiers du diff `23851fd..9beb212` ont été lus ou inspectés dans
leur totalité :

- `lib/src/auto_size_text.dart` et
  `lib/src/auto_size_text_layout.dart` ;
- `test/basic_test.dart`, `test/utils.dart`,
  `test/text_scaler_test.dart` et
  `test/effective_text_configuration_test.dart` ;
- le journal d’implémentation et les trois rapports ;
- les deux licences textuelles ;
- les répertoires, métadonnées, tailles, hashes et comportement de shaping des
  trois TTF.

La décision `text-metric-fixtures.md`, la politique
`example-lock-policy.md`, le diff cumulatif, les changements de chacun des onze
commits et les objets de la référence `7ca05ac` ont aussi été inspectés.

### Entrées et effets

La surface produit reçoit le texte, les styles, contraintes, scalers et options
publiques du widget, ainsi que la configuration héritée de Flutter. Elle met à
jour l’état local d’un `AutoSizeGroup`, crée des `TextPainter` bornés au layout
et appelle un `TextScaler` éventuellement fourni par l’application. Les tests
lisent seulement trois chemins de fixtures constants et enregistrent ces
fontes localement avec `FontLoader`.

Le lot n’ajoute aucune requête de base de données, identité, authentification,
autorisation, session, primitive cryptographique, secret, commande externe ou
appel réseau.

### Checklist

| Classe | Conclusion |
|---|---|
| Injection commande/SQL/template et XSS | hors surface ; aucune donnée ne construit une commande, requête ou sortie HTML |
| Authentification, autorisation/IDOR, CSRF et session | hors surface |
| Race et TOCTOU | aucun accès externe read-then-write ; rebuilds et état de groupe couverts |
| Cryptographie et divulgation | aucun secret ou primitive ; aucun chemin absolu dans `lib/`, `test/`, l’exemple ou les configs |
| Ressources et disponibilité | painters libérés dans `finally`, recherches logarithmiques, validations numériques et leak 9/9 sur les deux SDK |
| Logique métier et compatibilité | scalers, overrides, direction, locale, hauteur, groupes legacy et API dépréciée couverts ; exactitude supplémentaire garantie par l’identité à `7ca05ac` |
| Supply-chain des fixtures | tailles/hashes exacts, licences adjacentes, `locl` et poids vérifiés, aucun chargement réseau |

Aucun finding de sécurité, de logique, de compatibilité ou de qualité
actionnable n’a été trouvé. Cette revue d’assemblage ne rejoue pas les mutants,
la reproduction des sous-ensembles ni une validation OTS : leurs preuves sont
conservées dans les rapports finaux, tandis que l’identité octet pour octet
établit qu’aucun de leurs objets audités n’a été altéré pendant l’intégration.

## État final

Avant création de ce rapport, le checkout canonique était propre après tous
les contrôles. Cette revue ne modifie aucun produit, test, fixture, manifeste,
lock ou autre documentation. Son seul livrable est le présent rapport.
