# Revue indépendante du lot 3 — Fixtures de métriques texte

Date : 2026-09-01

Branche de revue : `codex/review-text-fixtures`

Base exacte : `a13534cd12842b2e6847feb4963842175a96ee10`

Candidat revu : `129dfbc376e8d7dc907a0cf0e5f55e43d55fa6d9`

Décision de fixtures examinée dans l'intégration :
`/private/tmp/auto-size-text-impl-integration/maintenance/decisions/text-metric-fixtures.md`

## Verdict

**CHANGEMENTS REQUIS.**

Les trois TTF committés sont déterministes par rapport aux recettes actuelles,
leurs sources Flutter 3.41/3.47 sont identiques, leurs poids et leur table
`locl` sont corrects, et les deux suites ciblées passent 21/21 sur les deux
SDK sans réseau pendant leur exécution. La future politique `.pubignore` P7
conserve également les tests, les fontes et les licences.

Un point empêche d'accepter la livraison comme clôture supply-chain : la
licence Noto versionnée ne correspond ni aux octets, ni à la taille, ni au
SHA-256 que la recette déclare autoritaires ; sa provenance exacte et son
propre hash ne sont consignés nulle part.

Un diagnostic non bloquant montre par ailleurs que les trois fontes peuvent
être réduites de 10 504 à 4 744 octets en retirant le hinting, sans casser les
21 tests sur Flutter 3.41.0 ou 3.47.2. La décision n'exige toutefois pas une
minimalité absolue octet par octet : ce résultat reste une recommandation de
durcissement, pas un second finding.

Aucun code produit, asset, licence, manifeste ou test n'a été corrigé pendant
cette revue. Aucun merge, push, tag ou publish réel n'a été effectué.

## Findings

### 1. La licence Noto commitée n'est pas reproductible depuis l'autorité documentée

**Sévérité : moyenne — supply-chain et conformité de provenance.**

La décision donne comme autorité :

```text
taille : 4 301 octets
SHA-256 : c3dd4c678171e42146614fd4fd132f474df05f7bd12d1348b4c5af50172c0e8f
source : blob Flutter 358e88c.../NotoColorEmoji-LICENSE.txt
```

Le fichier réellement committé est :

```text
test/assets/fonts/LICENSE-NotoNaskhArabic.txt
taille : 4 350 octets
SHA-256 : e2729335a9a3c01e2d36ad91bbe096b53e39a442ddcd84d85f358fad7a91a8f0
```

La commande `git show` exacte de la recette reproduit bien le fichier de
4 301 octets et le hash `c3dd…`, mais pas l'asset committé. La version commitée
ajoute le copyright `Copyright 2014 Google Inc. All Rights Reserved.`, change
la mise en lignes et ajoute un saut de ligne final. Après retrait de cette
attribution et normalisation des espaces, les mots des conditions OFL sont
identiques ; il ne s'agit donc pas d'un texte de licence tronqué ou altéré.
L'attribution ajoutée concorde aussi avec le champ copyright du TTF.

La conformité substantielle OFL-1.1 est bonne, mais la chaîne de provenance
promise ne l'est pas : aucun chemin source immuable, aucune transformation
exacte et aucun hash documenté ne produisent les 4 350 octets livrés. De plus,
le sous-ensemble Noto ne conserve que les entrées `name` 0 à 6 ; il garde le
copyright, mais aucune entrée de licence 13/14. L'affirmation de la décision
selon laquelle le TTF conserve sa propre déclaration OFL est donc inexacte et
la licence adjacente est bien l'unique copie complète dans l'archive.

**Correction minimale demandée :** choisir une seule autorité. Soit livrer le
blob déjà documenté, soit conserver l'attribution actuelle mais documenter sa
source immuable et la recette exacte qui la produit, puis remplacer la taille,
le SHA-256 et le total de licences dans la décision et le journal. Le hash
complet des cinq fichiers doit être contrôlé après cette correction.

## Diagnostic non bloquant — hinting et réduction supplémentaire

**Recommandation — réduction d'attaque et taille de l'archive.**

Les répertoires SFNT committés ne contiennent aucune table personnalisée,
couleur, SVG, Graphite, AAT ou signature inconnue. Ils contiennent cependant
les tables de programmes TrueType `fpgm` et `prep`, ainsi que `cvt ` ; les deux
Roboto conservent aussi `hdmx`. Ce bytecode provient bien des fontes Flutter
sources — la reproduction octet pour octet exclut une injection dans ce diff —
mais il reste interprété par le moteur de fontes et n'est utilisé par aucun
oracle de métriques du lot.

Une contre-preuve temporaire a été produite avec HarfBuzz 14.2.1 et
`hb-subset --no-hinting`, en conservant exactement les unicodes et `locl` :

| Fixture | Commitée | Sans hinting | Gain |
|---|---:|---:|---:|
| Roboto regular | 2 660 | 1 564 | 1 096 |
| Roboto bold | 2 632 | 1 596 | 1 036 |
| Noto Naskh `locl` | 5 212 | 1 584 | 3 628 |
| **Total** | **10 504** | **4 744** | **5 760 (54,8 %)** |

Les variantes gardent les familles Regular/Bold, les poids 400/700 et les
avances Noto attendues (`ar`: `uni066C`, 329 ; `fa`:
`ThousandsSepFarsi`, 455). Substituées uniquement dans une copie temporaire du
paquet, elles font passer les deux suites ciblées 21/21 sous Flutter 3.41.0 et
21/21 sous Flutter 3.47.2.

La taille actuelle est déjà très inférieure aux fontes complètes et satisfait
le contrat de sous-ensemble borné de la décision. Elle n'est simplement pas la
taille minimale démontrable pour les propriétés testées et conserve une
surface exécutable évitable.

**Amélioration recommandée :** lors de la correction des assets, envisager de
régénérer les trois fixtures sans hinting avec une version d'outil fixée,
documenter les nouveaux hashes complets et rejouer les mêmes contrôles
3.41/3.47. Le maintien des binaires actuels ne constitue toutefois pas, à lui
seul, un motif de rejet.

## Provenance, hashes et reproduction des binaires actuels

Les cinq assets committés ont les tailles et SHA-256 suivants :

| Fichier | Octets | SHA-256 |
|---|---:|---|
| `auto_size_metric_roboto_regular.ttf` | 2 660 | `893780a2a9c1b15a9ee784b1e34568ff755d3ff9815c9fa755febe303d7bd9c1` |
| `auto_size_metric_roboto_bold.ttf` | 2 632 | `bab0b1b36298647122dfaee2e27c0bcb564c43f954be771e90abc94812fafa6d` |
| `auto_size_metric_naskh_locl.ttf` | 5 212 | `d51e94755847f96a7cb9fdd53c91962ec6772a4d6b54c764e05b85e8d987af5a` |
| `LICENSE-Roboto.txt` | 11 358 | `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30` |
| `LICENSE-NotoNaskhArabic.txt` | 4 350 | `e2729335a9a3c01e2d36ad91bbe096b53e39a442ddcd84d85f358fad7a91a8f0` |

Les sources des deux SDK sont identiques octet pour octet :

| Source Flutter 3.41.0 et 3.47.2 | SHA-256 |
|---|---|
| `Roboto-Regular.ttf` | `79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95` |
| `Roboto-Bold.ttf` | `7d0b991ee3e0be7af01ad7ea8cd2beea6c00a25e679a0226b6737f079aafff86` |
| `NotoNaskhArabic-Regular.ttf` | `6b999662f669b2c9b00c10ce4a110b6f5179c20f3f77e5ccb897e3ab965cf9f5` |
| `Roboto_LICENSE.txt` | `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30` |

Les trois commandes exactes de sous-ensemble de la décision ont été rejouées
dans `/private/tmp/auto-size-text-fixture-audit.S5pZ4t`. Les trois sorties ont
le même SHA-256 que le dépôt et `cmp` retourne 0 pour chacune : reproduction
**octet pour octet** confirmée avec `font-subset` de Flutter 3.47.2 et
HarfBuzz 14.2.1.

## Métadonnées, tables et licences

L'inspection du répertoire SFNT et des tables `OS/2`, `maxp`, `head` et `name`
donne :

| Fixture | Tables remarquables | Poids | Glyphes | Attribution intégrée |
|---|---|---:|---:|---|
| Roboto regular | tables TrueType standard, hinting, pas de layout exotique | 400 | 8 | Copyright 2011 Google Inc. |
| Roboto bold | mêmes tables standard | 700 | 8 | Copyright 2011 Google Inc. |
| Noto Naskh | `GSUB`, `GPOS`, `locl`, hinting standard | 400 | 8 | Copyright 2014 Google Inc. |

`fc-scan` retrouve `Roboto|Regular`, `Roboto|Bold` et
`Noto Naskh Arabic|Regular`. `hb-shape` sélectionne `uni066C` avec avance 329
en arabe et `ThousandsSepFarsi` avec avance 455 en farsi. Le matching final
w400/w700 est exercé par le test Flutter avec les deux faces chargées sous la
même famille privée.

`LICENSE-Roboto.txt` est identique au `Roboto_LICENSE.txt` des deux SDK et
contient l'Apache License 2.0 complète. Les notices copyright intégrées sont
conservées. La licence Noto contient le texte OFL-1.1 complet et le copyright
Google correspondant ; aucun Reserved Font Name n'est déclaré dans ce texte.
Le problème du finding 1 porte sur sa reproduction, pas sur une permission de
redistribution manquante.

Aucune table inattendue ni charge arbitraire ajoutée par le candidat n'a été
trouvée. `ots-sanitize` n'est pas installé sur l'hôte : cette revue ne revendique
donc pas une validation OTS indépendante. Les trois fichiers sont néanmoins
lus par Fontconfig, HarfBuzz et les deux moteurs Flutter, et leur identité avec
les sorties locales réduit fortement le risque d'altération.

## Chargement, portabilité et dépendances

Le helper de `test/effective_text_configuration_test.dart` a été lu
intégralement avec les cas de poids, direction, locale et hauteur :

- `dart:io` n'est importé que par les tests ; aucun chemin ou octet de fixture
  ne fuit dans `lib/` ;
- les trois chemins sont relatifs à la racine du paquet, sans `/Users/`, SDK,
  réseau, catalogue système ou variable d'environnement ;
- `/` est accepté comme séparateur par `dart:io` sur macOS et Linux, et les
  commandes CI exécutent `flutter test` à la racine ;
- `ByteData.sublistView` fournit exactement la vue attendue par `FontLoader`
  sur les deux SDK ;
- les deux faces Roboto sont ajoutées au même loader, et les deux loaders ne
  sont exécutés qu'une fois via `setUpAll` ;
- `pubspec.yaml` ne déclare ni `assets:`, ni `fonts:`, ni ces chemins ; les
  fixtures ne sont donc pas embarquées dans une application consommatrice ;
- le paquet n'ajoute aucune dépendance runtime ou dev, et les tests ne
  contiennent ni client HTTP, ni socket, ni téléchargement.

La lecture relative suppose, comme toute suite Flutter de paquet, une commande
lancée depuis la racine. C'est le cas des commandes locales et de la CI
planifiée. Le chargement a été exécuté sur macOS ; aucune machine Linux n'était
disponible dans cette revue, mais aucun élément du helper n'est spécifique à
macOS.

## Vérifications Flutter 3.41 / 3.47 sans réseau de test

Les dépendances ont d'abord été préparées avec `flutter pub get --offline`,
depuis le cache local, puis les suites ont été lancées avec `--no-pub` :

| SDK | Commande ciblée | Résultat |
|---|---|---|
| Flutter 3.47.2 / Dart 3.13.2 | `flutter test --no-pub test/effective_text_configuration_test.dart test/text_scaler_test.dart` | 21/21 |
| Flutter 3.41.0 / Dart 3.11.0 | même commande | 21/21 |

Le même tableau est vert 21/21 et 21/21 dans la copie temporaire utilisant les
trois variantes sans hinting. L'exécution des tests ne déclenche aucune
résolution, lecture d'asset depuis un SDK, fonte système ou requête réseau ;
seules les trois fixtures versionnées sont lues comme données de fonte.

## Impact de la future archive P7

Une archive Git propre de `129dfbc` a été extraite sans `.git`, puis a reçu
exactement le `.pubignore` accepté de P7 au commit
`b2b9b72b6b5bf5b4b30832494b2bb48eeba43861`. Le dry-run Flutter 3.47.2
retourne 0 :

```text
fichiers publiés :          35
taille compressée :         40 KB
warnings Pub :              0
fixtures/licences présentes : 5/5
```

`test/effective_text_configuration_test.dart`, `test/text_scaler_test.dart`,
les trois TTF et les deux licences figurent explicitement dans la liste. P7 ne
contient aucune règle qui exclut `test/` ou `*.ttf`; les tests publiés restent
donc rejouables. L'impact non compressé réel des cinq assets est 26 212 octets
(10 504 de fontes et 15 708 de licences), et non les 26 163 octets annoncés
par la décision avant l'ajout non documenté de 49 octets à la licence Noto.

Ce dry-run simule l'union mais ne la remplace pas : la gate S10 devra être
rejouée sur le SHA fusionné final.

## Revue `find-bugs` et sécurité

### Surface examinée

| Fichier/surface | Entrées et effets |
|---|---|
| trois TTF | données binaires fixes, parsées uniquement pendant les tests |
| deux licences | texte publié, aucune exécution |
| helper de chargement | trois lectures de fichiers relatifs fixes puis enregistrement local via `FontLoader` |
| cas métriques associés | rendu local Flutter, aucune entrée utilisateur ou appel externe |

Il n'existe dans ce périmètre ni requête de base de données, ni identité,
session, autorisation, secret, cryptographie ou appel réseau.

### Checklist complète

| Classe | Conclusion |
|---|---|
| Injection commande/SQL/template | Hors surface ; aucun nom de fichier ou contenu contrôlé par un utilisateur. |
| XSS | Hors surface ; aucun HTML. |
| Authentification / autorisation / IDOR | Hors surface. |
| CSRF / session | Hors surface. |
| Race / TOCTOU | Pas de lecture puis écriture ; fichiers immuables pendant le test. |
| Cryptographie | SHA-256 utilisé comme contrôle hors runtime, aucun secret. |
| Divulgation | Aucun chemin personnel ou contenu sensible dans helper, TTF ou archive P7. |
| Déni de service | Fichiers bornés à 10 504 octets ; aucune boucle dépendant de données externes. |
| Logique métier | Poids, direction, locale et hauteur ont des témoins divergents et passent sur les deux SDK. |
| Supply-chain | Finding sur la provenance exacte de la licence Noto ; hinting inutile consigné comme recommandation. |

## Fichiers et sources lus, limites

Ont été lus ou inspectés intégralement : les deux licences, les répertoires et
métadonnées des trois TTF, `test/effective_text_configuration_test.dart`, le
journal `maintenance/implementation/lot-3-effective-text.md`, la décision de
fixtures, la future `.pubignore` P7 et sa revue. `test/text_scaler_test.dart` a
été exécuté sur les deux SDK ; il ne charge lui-même aucune fixture.

Le diff produit du lot 3 n'est pas rejugé ici : la mission est volontairement
bornée aux cinq assets, à leur chargement et à leur publication future. La
seule limite d'outil matérielle est l'absence d'`ots-sanitize`; elle est
compensée partiellement, mais pas remplacée, par l'inspection SFNT, Fontconfig,
HarfBuzz, la reproduction binaire et les deux exécutions Flutter.

## Conditions de nouvelle revue

1. Rendre la licence Noto reproductible et aligner son hash/taille/total avec
   la décision.
2. Recalculer les cinq SHA-256 complets et, si les TTF changent, comparer leur
   régénération octet pour octet.
3. Rejouer les 21 tests sur Flutter 3.41.0 et 3.47.2 avec `--no-pub`.
4. Rejouer le dry-run P7 et confirmer la présence des cinq assets et des deux
   suites, sans warning.

Le retrait du hinting peut être traité dans la même correction, mais reste une
recommandation non bloquante.
