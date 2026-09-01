# Revue lot 4 — RichText, performance et ressources

Date : 2026-09-01

Parent exact du lot : `3a1c343e88325b0020452be7c3258a902d87558f`

Candidat initial : `719d6a8df5f699b9ac8963dfb3034e56f71d12ad`

Correctif contre-revu : `413ea87b156c2512f01fe39cc2bad524eca9b333`

Correctif dans ce worktree : `6daaaa5ed39ebc0cba1acbf69c92ce8c807f40e4`

Branche de revue : `codex/review-rich-text-performance`

## Verdict final

**ACCEPTÉ.**

Le finding bloquant de la première revue est fermé. Pour
`wrapWords: false`, le texte visuel et ses ranges UTF-16 sont maintenant
calculés exactement une fois par évaluation de configuration, avant la
recherche. Pour `wrapWords: true`, ils ne sont jamais calculés. Le snapshot est
local, immuable et abandonné à la fin du calcul ; aucun cache global, mutable
ou partagé entre rebuilds n'est introduit.

La recherche de tailles reste virtuelle et logarithmique. Chaque candidat de
`wrapWords: false` conserve un seul painter auxiliaire et un seul layout non
wrappé, jamais un painter par range. Chaque plage effectue au plus une requête
de boxes, toutes les boxes sont additionnées, et chaque painter est disposé par
un `finally`.

Aucun finding performance, ressources ou disponibilité ne reste actionnable
dans le périmètre du lot 4.

## Finding initial et fermeture

La première revue, commit `f6419e7`, avait rejeté `719d6a8` parce que
`toPlainText(includeSemanticsLabels: false)` et
`_unbreakableTextRanges` étaient dans `_checkTextFits`, donc dans la closure de
`findLargestThatFits`. Une grille virtuelle d'environ un milliard de valeurs
répétait ainsi le scan trente fois.

Le correctif déplace les seules opérations indépendantes du candidat :

- `lib/src/auto_size_text.dart:471-476` construit
  `_UnbreakableTextSnapshot` avant `findLargestThatFits` ;
- `lib/src/auto_size_text_layout.dart:87-98` produit une fois le texte visuel,
  le scanne et stocke seulement une `List<TextRange>.unmodifiable` ;
- `_checkTextFits` reçoit cette liste et n'appelle plus `toPlainText` ;
- la branche `widget.wrapWords ? null : ...` court-circuite entièrement la
  segmentation lorsque le wrapping de mots reste autorisé.

### Preuve rouge/verte indépendante

Le test permanent corrigé a été copié sans modification sur `719d6a8`, dans
une archive temporaire isolée, puis ciblé par son nom exact :

```text
should segment once per configuration outside candidate search
```

| SDK exact | `719d6a8` | `6daaaa5` |
|---|---|---|
| Flutter 3.41.0 | rouge : `Expected <1>, Actual <30>` | vert dans la suite 96/96 |
| Flutter 3.47.2 | rouge : `Expected <1>, Actual <30>` | vert dans la suite 96/96 |

Le rouge arrive à la première configuration `wrapWords: false`, après que le
même test a déjà vérifié zéro appel pour `wrapWords: true`. Ce n'est donc ni un
test trivial, ni une assertion sur un fake sans rapport avec le produit : le
sous-type de `TextSpan` observe l'appel public réel à `computeToPlainText` et a
échoué exactement sur le défaut revu.

## Validité du compteur permanent

`test/wrap_words_test.dart` utilise un compteur local au test et un sous-type
privé de `TextSpan`. Il ne dépend d'aucun helper privé du package et ne modifie
pas le code produit.

Le fixture force une grille régulière d'environ `1 000 000 001` valeurs avec :

- référence `100 000 000` ;
- minimum et pas `0,1` ;
- boîte `0 × 0` ;
- `overflowReplacement`, qui empêche le rendu final du span de polluer le
  compteur.

Les assertions verrouillent successivement :

1. zéro appel avec `wrapWords: true` ;
2. exactement un appel avec `wrapWords: false` malgré trente candidats ;
3. exactement un nouvel appel après changement d'override ;
4. exactement un nouvel appel après remplacement du span source.

Le test prouve donc à la fois l'absence de segmentation inutile, la borne d'un
scan par build/configuration et l'absence de cache réutilisé à travers une
configuration devenue différente.

## Delta sémantique

### Même texte visuel que le painter

Pour le constructeur simple, le snapshot reçoit un `TextSpan` contenant
exactement `widget.data`. Pour le constructeur riche, il reçoit
`measurementTextSpan`, c'est-à-dire le span source ou son clone fidèle de
spacing. Les overrides ne changent ni texte, ni ordre, ni offsets, ni labels ;
`includeSemanticsLabels: false` reste explicite.

Le painter candidat reçoit ensuite le parent synthétique et le même
`measurementTextSpan`. Le snapshot et le painter observent donc la même suite
de code units. Aucun `substring`, `split`, `join`, flattening de style ou
normalisation n'est réintroduit.

La garde `WidgetSpan` reste avant le snapshot. Le lot n'essaie donc pas de
mesurer un arbre avec placeholders non dimensionnés.

### Rebuilds et ownership

Le snapshot est une variable `final` locale à `_calculateFontSize`. Sa liste
est non modifiable. Il n'existe :

- aucun champ d'état pour le texte ou les ranges ;
- aucune clé de cache par span, scaler, contraintes ou `MediaQuery` ;
- aucune écriture dans le `TextSpan` ou ses listes ;
- aucune valeur réutilisée au pump suivant.

Un changement de span, d'override, de scaler ou de contrainte reconstruit donc
la configuration et le snapshot. Le `Text` final continue de recevoir l'arbre
source, sans clone mis en cache ou double override observable.

## Cartographie finale du coût

Notations :

- `N` : code units du texte visuel ;
- `K` : ranges non vides, avec `K <= ceil(N / 2)` ;
- `S` : `TextSpan` standards clonés sous override ;
- `E` : candidats effectivement évalués ;
- `B(r)` : boxes renvoyées par Flutter pour le range `r`.

### Préparation par configuration

| Ressource | Borne finale |
|---|---|
| `wrapWords: true` | Zéro `toPlainText`, zéro scan, zéro liste de ranges. |
| `wrapWords: false` | Un `toPlainText` de taille `N`, un scan UTF-16 et une liste immuable de `K` paires d'offsets. |
| Clone riche | Zéro sans override ; sinon `O(S)`, une seule fois avant la recherche. |
| Domaine régulier | Stockage constant : minimum, borne, pas, longueurs et flags ; aucune liste proportionnelle à `C`. |
| Recherche | `E <= ceil(log2(L + 1))` évaluations pour `L` candidats. |

Pendant la construction du snapshot, le pic inclut la chaîne visuelle de
taille `N` et la liste de `K` ranges. La chaîne n'est pas conservée dans
`_UnbreakableTextSnapshot`; seule la liste d'offsets vit pendant la recherche.
Cette matérialisation `O(K)` est exactement celle autorisée par l'oracle
adversarial et remplace les `E` chaînes/scans du code rejeté.

### Par candidat avec `wrapWords: false`

| Ressource | Borne finale |
|---|---|
| Painter auxiliaire | Exactement un. |
| Layout auxiliaire | Exactement un, à largeur infinie. |
| Requêtes de boxes | Au plus une par range, avec retour au premier dépassement : `<= K`. |
| Largeur d'un range | `sum(abs(right - left))` sur les `B(r)` boxes. |
| Painter principal | Zéro après rejet d'un range ; sinon exactement un. |
| Layout principal | Zéro ou un, parallèlement au painter principal. |
| Dispose | Un par painter créé, dans son `finally`. |
| Pic de painters package | Un : l'auxiliaire est disposé avant le principal. |

Il n'existe aucun painter ni layout par range. Pour `E` candidats, le nombre
total de painters/layouts/disposals reste dans `[E, 2E]` et les requêtes de
boxes restent `<= K × E`.

## Probes et bornes conservées

Les probes temporaires de la première revue avaient instrumenté les deux
révisions et les deux SDK. Le correctif ne touche ni la recherche, ni la
création/layout/dispose des painters, ni la boucle de boxes ; leurs compteurs
restent applicables :

| Entrée, un candidat | Ranges | Appels boxes | Boxes | Painters/layouts/disposals |
|---|---:|---:|---:|---:|
| simple `A/espace`, 2 048 code units | 1 024 | 1 024 | 1 024 | 2 / 2 / 2 |
| riche `A/espace`, 2 048 runs | 1 024 | 1 024 | 1 024 | 2 / 2 / 2 |
| simple ou riche `A/NBSP`, 2 048 code units/runs | 1 | 1 | 1 | 1 / 1 / 1 |
| mixte `A/espace/A/NBSP`, 2 048 runs | 513 | 513 | 513 | 2 / 2 / 2 |
| bidi multi-box, 1 280 code units | 1 | 1 | 513 | 1 / 1 / 1 |
| plage NBSP unique, 65 537 code units | 1 | 1 | 1 | 1 / 1 / 1 |

Le fixture bidi confirme que le coût mémoire temporaire dépend de `B(r)` :
une requête a renvoyé 513 boxes, toutes consommées par le fold, sans
accumulation inter-ranges.

Une grille de `1 000 000 001` valeurs a produit 30 évaluations et seulement 35
lectures indexées. Elle n'a matérialisé aucune liste de candidats. Sur 1 000
rebuilds, les compteurs donnaient exactement 2 000 painters, 2 000 layouts,
2 000 disposals, zéro painter vivant à la fin et un pic de un.

### Croissance informative `N/2N/4N`

Les mesures murales initiales utilisaient un seul candidat pour les corpus de
croissance ; le déplacement du snapshot ne change donc pas leur nombre de
scans. Elles restent un signal sur les boxes et les milliers de runs :

| SDK | Cas candidat | `N` | `2N` | `4N` |
|---|---|---:|---:|---:|
| 3.41 | simple `A/espace` | 4,53 ms (8 192) | 13,17 ms | 23,60 ms |
| 3.47 | simple `A/espace` | 5,29 ms (8 192) | 13,39 ms | 25,05 ms |
| 3.41 | riche `A/espace/NBSP` | 4,04 ms (512 runs) | 5,25 ms | 10,15 ms |
| 3.47 | riche `A/espace/NBSP` | 5,02 ms (512 runs) | 6,17 ms | 10,11 ms |

Ces courbes restent proches d'une croissance linéaire sur les fenêtres
mesurées. Elles ne constituent pas un seuil de test et ne contractualisent pas
la complexité interne de Flutter.

## Vérifications finales sur SDK exacts

Les validations ont été relancées indépendamment sur une archive propre de
`6daaaa5` :

```text
Flutter 3.41.0, revision 44a626f4f0, Dart 3.11.0
Flutter 3.47.2, revision d3b14c8769, Dart 3.13.2
```

| Commande | Flutter 3.41.0 | Flutter 3.47.2 |
|---|---|---|
| analyse `--fatal-infos --fatal-warnings lib test example/main.dart` | aucun diagnostic | aucun diagnostic |
| suite racine complète `--no-pub` | 96/96 | 96/96 |
| test compteur permanent | vert dans la suite | vert dans la suite |
| lifecycle/leak, retours anticipés et exception | verts dans la suite | verts dans la suite |

## Disponibilité : limites exactes

- **Coût `O(N)` inévitable :** produire une fois le texte visuel, le scanner
  une fois, stocker `K` offsets et cloner les `S` spans lorsque Flutter impose
  un override.
- **Coût candidat attendu :** un layout fidèle et jusqu'à `K` appels de boxes
  par candidat. La correction ne tente pas de fusionner les ranges et ne perd
  aucun style.
- **Risque interne non borné par l'API :** Flutter documente le résultat de
  `getBoxesForRange`, pas sa complexité. Le nombre `B(r)` de boxes est lui aussi
  dépendant du bidi et des runs.
- **DoS démontré :** aucun. Les corpus 32 768/65 537 code units, 2 048 runs, le
  domaine milliardaire et 1 000 rebuilds terminent sur les deux SDK sans fuite
  ni croissance explosive dans les fenêtres observées.

## Recommandations non bloquantes

- Conserver hors suite fonctionnelle un benchmark sans seuil mural pour suivre
  les courbes 8k/16k/32k et les milliers de spans.
- Garder le fixture bidi multi-box afin de détecter une future accumulation de
  listes ou une réduction erronée à une seule box.
- Continuer à documenter que la complexité native de Flutter n'est pas une
  garantie du package.

## Pré-conclusion `find-bugs`

Fichiers du correctif lus intégralement :

- `lib/src/auto_size_text.dart` ;
- `lib/src/auto_size_text_layout.dart` ;
- `maintenance/implementation/lot-4-rich-text.md` ;
- `test/wrap_words_test.dart`.

Le diff complet `413ea87^..413ea87` a été relu, ainsi que la revue performance
initiale, le lot 4 de la roadmap, les oracles RichText et adversarial, les
tests RichText/lifecycle et les délégations Flutter
`TextPainter.getBoxesForSelection` / `Paragraph.getBoxesForRange`.

Surface d'entrée : texte simple, arbre et métadonnées `InlineSpan`, code units
UTF-16, contraintes, direction/locale, overrides `MediaQuery`, scalers et
domaine numérique de candidats. Le correctif n'ajoute aucun accès réseau,
fichier, base de données, session, authentification, autorisation ou
cryptographie.

Checklist : injection, XSS, authentification, autorisation/IDOR, CSRF, session,
cryptographie et information disclosure non applicables ; aucune race, TOCTOU,
mutation partagée ou cache périmé ; domaine numérique non matérialisé ; aucune
régression métier observée ; painters et exceptions sûrs ; finding DoS/ressource
initial fermé. La complexité native de `getBoxesForRange` reste la seule zone
impossible à borner par revue de l'API et est explicitement documentée comme
limitation, pas comme garantie.
