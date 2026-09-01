# Assemblage indépendant du lot 4 — RichText

Date : 2026-09-01

Branche vérifiée : `codex/integrate-rich-text-reviewed`

HEAD produit et revues vérifié :
`d44786335500378aaf0c4a7541e6f044dc4e878d`

Arbre Git vérifié :
`267132863f821d017b08ede0eff7c7dfff8bf2c4`

Base S4 : `3a1c343e88325b0020452be7c3258a902d87558f`

Base d'assemblage après oracle corrigé :
`0a4b60d6d677991a7a25ac98a7e3177b5218c792`

Tip produit approuvé comparé :
`413ea87b156c2512f01fe39cc2bad524eca9b333`

Le présent rapport est le seul fichier ajouté par cette validation. Aucun code
produit, test, lock, manifeste ou rapport antérieur n'a été modifié.

## Verdict

**ACCEPTÉ.**

Les cinq fichiers produit, test et journal du lot sont byte-for-byte identiques
à ceux du tip approuvé `413ea87`. Les trois rapports finaux portent
`ACCEPTÉ`, sont identiques à leurs branches de revue respectives et possèdent
un historique documentaire linéaire traçable dans la branche d'assemblage.

La relecture n'a trouvé aucune régression ni interaction actionnable avec les
lots 0 à 3. Les deux SDK exacts passent l'analyse fatale, les suites RichText,
le compteur de segmentation, les tests de fuite/cycle de vie, la suite complète
96/96 et le contrôle de l'exemple selon sa politique de lock. Le downgrade sur
le SDK minimum abaisse neuf dépendances et conserve 96/96 tests verts.

## Intégrité de l'assemblage

### Produit et tests approuvés

La commande suivante termine avec le code `0` et une sortie vide :

```sh
git diff --exit-code \
  413ea87b156c2512f01fe39cc2bad524eca9b333..HEAD -- \
  lib/src/auto_size_text.dart \
  lib/src/auto_size_text_layout.dart \
  maintenance/implementation/lot-4-rich-text.md \
  test/rich_text_test.dart \
  test/wrap_words_test.dart
```

Les modes et les blobs des cinq chemins sont donc identiques :

| Fichier | Blob dans `d447863` | Blob dans `413ea87` |
|---|---|---|
| `lib/src/auto_size_text.dart` | `bee83a3c5ec652380a32167213e5d90ff8691657` | identique |
| `lib/src/auto_size_text_layout.dart` | `02d6cdf69e00e6a3ccfbbe25d6aa5edfc976f8dc` | identique |
| `maintenance/implementation/lot-4-rich-text.md` | `b4cb14e07dd4282b18af41a5b857ee085b412c1e` | identique |
| `test/rich_text_test.dart` | `80c1c50b1bcbede7f95a0b3934dd0e4da0f98362` | identique |
| `test/wrap_words_test.dart` | `5ceb9a02dff1263d99e5c7818b14ac9e56470b5b` | identique |

Les deux commits produit approuvés ont été appliqués sans commit intermédiaire :

```text
53deb49a52e6e1263293541b46c5061ed1337f7e
  parent 0a4b60d6d677991a7a25ac98a7e3177b5218c792
  feat: preserve rich text sizing semantics

20d211cdbbe56f528ff768506f8c40f923cb1301
  parent 53deb49a52e6e1263293541b46c5061ed1337f7e
  perf: snapshot rich text word segmentation
```

Le seul écart non documentaire entre `413ea87` et le HEAD assemblé est attendu :
la branche d'assemblage possède déjà l'oracle adversarial via le merge
`112fec28934cf48bdeac7bf41bfb9023cd549759`, puis sa correction split-surrogate
`0a4b60d`. Le blob final de
`maintenance/decisions/rich-text-adversarial-oracle.md` est
`f587679756ac8c33b7dbbf4d54d80ea6d3f4cba9`. Aucun changement de cet oracle
n'est mêlé aux commits produit `53deb49` et `20d211c`.

### Rapports finaux et traçabilité

| Rapport | Verdict final | Blob assemblé | Tip de revue dont le blob est identique |
|---|---|---|---|
| `lot-4-rich-text-review.md` | `ACCEPTÉ` | `58de16cf17b2771244075cc69f04554b16285b81` | `edfb141` |
| `lot-4-rich-text-unicode-review.md` | `ACCEPTÉ` | `a98ec210f5e9e2d4420d831b50eec5e4647065c0` | `0fa1c67` |
| `lot-4-rich-text-performance-review.md` | `ACCEPTÉ` | `d9a1aa30d9ce1e23da4662e5725765689d74247f` | `abf26d6` |

L'historique `git log --follow` et `git diff-tree` montre, pour chacun, un
commit d'ajout puis un commit de verdict final, sans fichier produit dans ces
commits :

```text
edbd97f -> bf3131a  lot-4-rich-text-review.md
7eba6b0 -> 6a18b49  lot-4-rich-text-unicode-review.md
85e2550 -> d447863  lot-4-rich-text-performance-review.md
```

Les six commits ne touchent que le rapport nommé. Les trois blobs finaux sont
strictement identiques à ceux des tips de revue cités ci-dessus.

## Relecture du diff et interactions avec les lots 0 à 3

Les neuf fichiers du delta `3a1c343..d447863` ont été lus intégralement :

1. `lib/src/auto_size_text.dart` ;
2. `lib/src/auto_size_text_layout.dart` ;
3. `maintenance/decisions/rich-text-adversarial-oracle.md` ;
4. `maintenance/implementation/lot-4-rich-text.md` ;
5. `maintenance/reviews/lot-4-rich-text-review.md` ;
6. `maintenance/reviews/lot-4-rich-text-unicode-review.md` ;
7. `maintenance/reviews/lot-4-rich-text-performance-review.md` ;
8. `test/rich_text_test.dart` ;
9. `test/wrap_words_test.dart`.

Ont aussi été relus avant conclusion : les instructions Developing Flutter,
Effective Dart, Testing et `find-bugs`, la politique normative du lock de
l'exemple et les gates format/matrice/downgrade de la roadmap.

La relecture a confirmé les interactions suivantes :

- le domaine candidat virtuel et la recherche logarithmique du lot 2 restent
  inchangés ; le test du compteur avec domaine milliardaire passe séparément ;
- le scaler utilisateur effectif, les overrides `MediaQuery`, la direction,
  la locale, la strut et les comportements d'overflow du lot 3 sont transmis au
  painter et au rendu riche sans double application ;
- le chemin texte simple, les groupes legacy, les valeurs zéro, les presets et
  le remplacement d'overflow restent couverts par la suite cumulative ;
- chaque `TextPainter` ajouté ou existant dans les chemins touchés est disposé
  dans un `finally`, y compris retour anticipé et exception ;
- le snapshot `wrapWords: false` est local au calcul, non modifiable et créé une
  fois par configuration ; aucun cache partagé entre rebuilds n'est ajouté ;
- l'arbre `TextSpan` source, ses listes, recognizers, callbacks et métadonnées
  ne sont pas mutés ; les offsets restent les code units UTF-16 du texte visuel ;
- la frontière `WidgetSpan` reste une erreur déterministe explicitement hors du
  support de ce lot ; elle ne prétend fermer ni intrinsics ni inline children.

Aucun finding actionnable n'a été confirmé.

## Matrice indépendante

Toolchains réellement exécutées :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
```

Les commandes étaient exécutées avec `CI=true`, analytics désactivée et un
répertoire de configuration temporaire. Les tests ont nécessité le socket
local normal du runner Flutter. Les résolutions Pub ont utilisé le cache local
et le réseau Pub lorsque nécessaire.

### Flutter 3.47.2 — checkout canonique

| Contrôle | Résultat |
|---|---|
| `flutter pub get --no-example` | code 0 ; 26 dépendances, `meta 1.19.0`, `vector_math 2.4.2` |
| `dart format --output=none --set-exit-if-changed lib test example` | code 0 ; 25 fichiers, 0 changement |
| `git diff --check 0a4b60d..HEAD` | code 0 ; sortie vide |
| `flutter analyze --no-pub --fatal-infos --fatal-warnings lib test example/main.dart` | code 0 ; aucun diagnostic |
| `flutter test --no-pub test/rich_text_test.dart test/wrap_words_test.dart` | 21/21 |
| test nommé `should segment once per configuration outside candidate search` | 1/1 |
| `flutter test --no-pub test/leak_tracking_test.dart test/text_painter_lifecycle_test.dart` | 9/9 |
| `flutter test --no-pub` | 96/96 |
| `example/: flutter pub get --enforce-lockfile` | code 0 ; lock haut consommé |
| `example/: flutter analyze --no-pub --fatal-infos --fatal-warnings` | code 0 ; aucun diagnostic |

### Flutter 3.41.0 — archive isolée de `d447863`

L'archive a été créée sous `/private/tmp`, sans `.git`. Le lock haut de
l'exemple a été vérifié puis retiré uniquement de cette archive avant sa
résolution minimum. L'archive et les locks temporaires ont été supprimés après
la matrice.

| Contrôle | Résultat |
|---|---|
| `flutter pub get --no-example` | code 0 ; 26 dépendances, `meta 1.17.0`, `vector_math 2.2.0` |
| format des quatre fichiers Dart touchés par le lot | code 0 ; 4 fichiers, 0 changement |
| analyse fatale scoped `lib test example/main.dart` | code 0 ; aucun diagnostic |
| deux suites RichText ciblées | 21/21 |
| test nommé du compteur de segmentation | 1/1 |
| suites leak et cycle de vie | 9/9 |
| suite racine complète avant downgrade | 96/96 |
| `example/: flutter pub get` sans lock haut | code 0 ; 10 dépendances, `meta 1.17.0`, `vector_math 2.2.0` |
| analyse fatale de l'exemple | code 0 ; aucun diagnostic |
| `flutter pub downgrade --no-example` | code 0 ; 9 dépendances abaissées |
| suite complète `--no-pub` après downgrade | 96/96 |

Le contrôle informatif du formatter 3.41.0 sur les 25 fichiers de l'arbre
retourne le code 1 et nomme uniquement
`test/leak_tracking_test.dart` et
`test/text_painter_lifecycle_test.dart`. Ces deux fichiers sont byte-for-byte
inchangés par le lot 4. Ce résultat n'est pas un gate rouge : la politique
normative exige de formater l'arbre complet uniquement avec la pin haute, puis
de compiler, analyser et tester ce résultat sur le minimum. Les quatre fichiers
Dart du lot sont propres avec le formatter minimum. Aucun reformatage 3.41.0
n'a été appliqué au produit ou aux tests.

### Intégrité des locks et manifests

Les hashes avant et après la matrice dans le checkout canonique sont :

```text
example/pubspec.lock
  115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7
pubspec.yaml
  667f07143ddc1609167857eb353d83c88aeab0758890345facdf8857a2c1b812
example/pubspec.yaml
  09520ff9a078e7f10008b5a3ac4ee79a625080eba359eb115da94798c3e83310
```

Le `/pubspec.lock` racine généré pour la résolution a été supprimé après les
tests, conformément à la politique bibliothèque. Aucun lock minimum n'a été
recopié dans le checkout.

## Audit `find-bugs`

La surface d'entrée du diff est limitée au texte simple, à l'arbre
`InlineSpan`, aux styles et métadonnées, aux scalers, à la configuration Flutter
héritée, aux contraintes et au domaine numérique de candidats. Les effets sont
le layout, le rendu, les interactions locales de spans et la publication locale
d'une taille de groupe.

Le diff n'ajoute aucune entrée réseau, requête de base de données, commande
externe, authentification, autorisation, session, accès fichier, primitive
cryptographique, donnée secrète ou journal runtime.

| Classe de risque vérifiée | Conclusion |
|---|---|
| Injection SQL/commande/template/header | Hors surface ; aucun interpréteur ni commande produit. |
| XSS | Hors surface ; aucun HTML ou rendu web textuel ajouté. |
| Authentification | Hors surface. |
| Autorisation / IDOR | Hors surface. |
| CSRF | Hors surface. |
| Race / TOCTOU | Aucun cache ou état partagé ajouté ; rebuilds et groupes legacy verts. |
| Session | Hors surface. |
| Cryptographie | Hors surface. |
| Divulgation d'information | Aucun secret/log ; erreur `WidgetSpan` bornée et sans contenu appelant. |
| Disponibilité / ressources | Domaine virtuel, scan unique, painters disposés ; compteur, corpus et lifecycle verts. |
| Logique métier / numérique | Zéro, scaler non linéaire, presets, bornes, UTF-16, NBSP/NNBSP et bidi couverts. |

Zones non vérifiées : appareil physique, web, AOT release, intrinsics/dry
layout et support réel de `WidgetSpan`. Elles ne sont pas modifiées ni annoncées
comme fermées par le lot 4 et restent dans les lots ultérieurs.

## Hygiène Git

Avant création du présent rapport :

- `git status --short --branch` n'affichait que le nom de branche ;
- `git ls-files -o --exclude-standard` était vide ;
- aucun `.tmp`, `.orig`, `.rej`, fichier de backup, probe ou lock racine ne
  restait dans le checkout ;
- le worktree minimum isolé avait été supprimé ;
- le lock canonique et les manifests conservaient les hashes ci-dessus.

Le commit qui porte ce rapport doit être documentaire seul. Aucun merge, push,
tag ou publication n'a été effectué.
