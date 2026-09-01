# Lot 2 — Domaine de candidats, grille et validations runtime

Date : 2026-09-01

Branche : `codex/impl-candidate-domain`

Parent exact : `ae52fe6d15a688621b2470d3f4a10555a410d686`

Tête : commit contenant ce journal ; SHA final communiqué dans le compte rendu

## Périmètre livré

- nouveau `_CandidateSet` privé dans
  `lib/src/auto_size_text_layout.dart`, déclaré comme `part` de la bibliothèque ;
- grille régulière virtuelle ancrée sur `minFontSize`, sans tableau
  proportionnel à la plage ;
- minimum, upper clampé et référence terminale exacte, avec tolérance relative
  `8 * 2^-52 * max(1, abs(a), abs(b))` ;
- dichotomie par indices qui renvoie le plus grand candidat qui tient, ou le
  plus petit candidat avec `fits == false` si aucun ne tient ;
- snapshot des presets, validation de l'ordre exact non croissant avant toute
  tolérance, déduplication des voisins exacts ou quasi égaux et stockage
  ascendant non modifiable, sans tri ni mutation de la liste appelante ;
- validations runtime par `ArgumentError` de min/max/pas pour la grille
  régulière, et de la référence, de l'ancien `textScaleFactor`, des valeurs
  calculées et des presets pour les deux modes ;
- acceptation et canonisation de `-0.0` en `0.0` pour les entrées qui admettent
  zéro ;
- conservation des assertions de construction existantes seulement comme
  compléments après les validations runtime.

Hors périmètre : `TextScaler`, configuration effective du paragraphe,
changements RichText, groupes hétérogènes, render/layout, démo, CI, packaging,
documentation publique et version.

## Fichiers

- `lib/auto_size_text.dart` ;
- `lib/src/auto_size_text.dart` ;
- `lib/src/auto_size_text_layout.dart` ;
- `test/step_granularity_test.dart` ;
- `test/min_max_font_size_test.dart` ;
- `test/preset_font_sizes_test.dart` ;
- `test/text_fits_test.dart` ;
- présent journal.

## Contrat numérique et complexité

Les candidats réguliers sont calculés uniquement par
`min + index * step`. Le quotient intervalle/pas est contrôlé avant `floor()` :
il doit être fini et inférieur ou égal au plus grand indice entier exactement
représentable, `2^53 - 1`. La progression est également rejetée si le premier
pas n'avance pas depuis le minimum ou si la magnitude rend possibles des alias
entre indices successifs. Ces rejets sont des `ArgumentError`, pas des
assertions.

Chaque valeur calculée est contrainte aux bornes exactes. Si le dernier pas est
quasi égal à l'upper, l'upper exact le remplace ; sinon l'upper est ajouté comme
dernier candidat. Lorsque `min < upper` mais que les deux bornes sont quasi
égales, le domaine contient une seule valeur et l'upper exact gagne. C'est la
seule exception documentée à la présence littérale du minimum, nécessaire pour
ne pas créer un quasi-doublon.

La grille régulière utilise `O(1)` mémoire. Une recherche fait `O(log C)`
évaluations pour `C` candidats. Le test permanent avec
`min=0.1`, `upper=100000000`, `step=0.1`, soit environ un milliard de
candidats, instrumente les builds de paragraphe et exige au plus 40
évaluations. Aucun temps mural n'est utilisé comme gate. Les presets coûtent
`O(P)` mémoire pour le snapshot nécessaire de leurs `P` valeurs, puis
`O(log P)` évaluations.

## Preuve rouge sur le parent S2

Les tests candidats ont été exécutés sur le code produit du parent exact avant
l'implémentation :

```sh
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --no-version-check --suppress-analytics test --no-pub \
  --reporter expanded \
  test/step_granularity_test.dart \
  test/min_max_font_size_test.dart \
  test/preset_font_sizes_test.dart \
  test/text_fits_test.dart
```

Résultat : code 1, 13 tests passés et 15 échecs. Les causes attendues sont
distinctes et visibles dans les sorties :

- `0.3/0.1`, `16.3/1` et les plages `12/5` non multiples échouent sur les
  assertions de divisibilité ancrées à zéro ;
- la grille quasi égale renvoie `1.0` au lieu de l'upper exact
  `1.0000000000000009` ;
- les valeurs min/max/pas/référence/facteur invalides produisent une assertion,
  une autre erreur ou aucune erreur, jamais l'`ArgumentError` requis ;
- les presets vides ou invalides ne produisent pas l'`ArgumentError` runtime
  attendu ;
- une grille à `1e15` avec un pas `0.1` accepte des indices aliasés et le ratio
  non représentable n'est pas rejeté ;
- `-0.0`/référence zéro atteint l'ancien calcul de facteur invalide.

Les contrôles de conservation déjà vrais sur S2 — résultats historiques,
presets descendants immuables et compteur logarithmique — sont des gates de
non-régression ; ils ne sont pas présentés comme des preuves rouges artificielles.

## Correctifs après revue finale

La revue `3cf3d13` a demandé trois corrections P1. Trois régressions publiques
permanentes, nommées `should…`, ont d'abord été exécutées isolément sur la tête
d'implémentation `9eb90b406565f50f75ae1d7f99e4b2b7d0a5c8ec`. Elles étaient
toutes rouges pour leur cause propre :

- les deux constructeurs avec presets et paramètres de grille ignorés
  (`min=-1`, `max=0`, `step=0`) recevaient encore un `ArgumentError` sur le
  minimum ;
- les remontées exactes d'un ULP, notamment
  `[20, 20.000000000000004, 10]`, étaient absorbées par la tolérance et
  acceptées ;
- `textScaleFactor=double.maxFinite` multiplié par une taille non nulle
  atteignait Flutter et produisait cinq assertions de rendu au lieu d'un
  `ArgumentError` applicatif.

Après correction, les trois tests isolés passent. La validation min/max/pas
est désormais strictement propre au mode grille ; référence, facteur explicite
et presets restent validés dans tous les modes où ils s'appliquent. Les presets
sont d'abord vérifiés paire par paire dans leur ordre source exact, puis
seulement dédupliqués avec la tolérance. Enfin, chaque facteur de layout et
chaque taille effective calculés sont contrôlés avant d'être transmis à
Flutter. Le test du débordement couvre séparément le facteur non fini et la
taille effective non finie avec référence zéro, puis conserve un cas de produit
fini historique.

## Preuves vertes

Toolchains exactes :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
```

### Flutter 3.47.2

| Commande | Résultat |
|---|---|
| format `lib test example`, puis contrôle `--output=none --set-exit-if-changed` | 22 fichiers, 0 changement au contrôle final |
| analyse scoped `lib test example/main.dart` | exactement les 9 informations historiques `deprecated_member_use`, 0 warning, 0 erreur, aucune information nouvelle |
| exemple : `pub get --enforce-lockfile`, puis analyse fatale `--no-pub` | succès, lock canonique haut inchangé, aucun diagnostic |
| quatre suites ciblées du lot | 31/31 |
| suite racine complète | 56/56 |
| tests explicites de cycle de vie/leak | 9/9 |

### Flutter 3.41.0

L'état courant a été copié dans
`/private/tmp/auto-size-text-lot2-min-final`, sans lock racine, sans lock
exemple et sans répertoire généré, conformément à la politique du lot 0.

| Commande | Résultat |
|---|---|
| `flutter pub get --no-example` | succès, 26 dépendances résolues naturellement |
| analyse scoped `lib test example/main.dart` | les mêmes 9 informations historiques, 0 warning, 0 erreur |
| exemple sans lock : `flutter pub get`, puis analyse fatale `--no-pub` | succès, 10 dépendances, `meta 1.17.0`, `vector_math 2.2.0`, aucun diagnostic |
| quatre suites ciblées du lot | 31/31 |
| suite racine complète | 56/56 |
| tests explicites de cycle de vie/leak | 9/9 |
| `flutter pub downgrade --no-example`, puis suite `--no-pub` | 9 dépendances abaissées ; 56/56 |

Les tests invalides appellent l'API publique et exigent le type
`ArgumentError`. La validation runtime s'exécute avant les assertions
complémentaires ; leur preuve ne dépend donc pas d'un `AssertionError` actif.

## Changements intentionnels sur les entrées invalides

- les min/références/facteurs explicites non finis ou négatifs sont rejetés ;
- le pas non fini ou inférieur à `0.1` est rejeté ;
- le maximum doit être fini et strictement positif, ou
  `double.infinity`, et supérieur ou égal au minimum ;
- les domaines dont les indices ne peuvent pas progresser strictement ou être
  représentés de façon portable sont rejetés ;
- les presets doivent être non vides, finis, non négatifs et non croissants ;
  les doublons/quasi-doublons adjacents restent acceptés et sont dédupliqués ;
- en mode presets, min/max/pas sont réellement ignorés et ne sont ni validés
  ni assertés ;
- une hausse exacte de preset est rejetée avant toute tolérance, même si elle
  ne représente qu'un ULP ;
- un facteur de layout ou une taille effective calculés non finis sont rejetés
  par `ArgumentError` avant Flutter ;
- les anciennes entrées non multiples du pas deviennent valides, car le pas
  est désormais relatif au minimum plutôt qu'à zéro.

Toutes ces différences concernent des entrées auparavant protégées uniquement
par assertions ou donnant un résultat indéfini. Les entrées historiques
valides conservent leurs résultats, notamment le domaine 12..60/pas 1, la
référence fractionnaire 33.5, les presets descendants et le facteur linéaire
historique.

## Limites

- le traitement complet d'une référence zéro dans un arbre RichText appartient
  toujours au lot 4 ; ce lot garantit seulement que zéro n'est pas rejeté par
  la validation du domaine et évite le facteur `0/0` du texte simple ;
- le scaler ambiant et la migration `TextScaler` restent au lot 3 ;
- la projection de groupe sur le domaine individuel reste au lot 5 ;
- aucun fichier de démo, CI, exemple, manifeste, lock, documentation publique
  ou version n'est modifié ;
- aucun merge, push, tag ou changement distant n'est effectué.
