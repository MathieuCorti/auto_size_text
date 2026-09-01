# Oracle numérique du domaine de candidats — lot 2

Date : 2026-09-01
Base inspectée : `S2` / `ae52fe6d15a688621b2470d3f4a10555a410d686`
Objet : critères indépendants pour `_CandidateSet`, la dichotomie et les
validations runtime. Ce document ne prescrit aucun correctif produit.

## Verdict

Le contrat du lot 2 est réalisable, sous deux précisions bloquantes.

1. Tester seulement `min + step > min` ne prouve pas que toute la grille est
   stricte. Sur Dart 3.11.4, `min = 1e15`, `upper = min + 10` et `step = 0.1`
   progressent au premier pas, mais 20 des 100 indices suivants répètent le
   candidat précédent. Un domaine régulier qui rencontre un tel alias doit
   lever `ArgumentError`; masquer les alias derrière des indices distincts ne
   satisfait pas l'invariant de `_CandidateSet`.
2. Lorsque `min < upper` mais que les deux sont quasi égaux, il est impossible
   de conserver les deux valeurs exactes tout en interdisant le quasi-doublon.
   La règle de résolution est : **une seule valeur, `upper` exact gagne**. La
   phrase « `min` est toujours présent » doit donc se lire « le domaine possède
   toujours son extrémité basse, sauf fusion terminale où `upper` la représente
   et reste supérieur ou égal à `min` ».

Ces précisions sont nécessaires à un oracle non contradictoire. Elles ne
changent aucun cas historique réaliste.

## Définitions normatives

Toutes les tailles de cette section sont les **candidats logiques non scalés**.

- `epsilon = 2^-52 = 2.220446049250313e-16`.
- Deux doubles finis `a` et `b` sont quasi égaux si et seulement si :

  ```text
  abs(a - b) <= 8 * epsilon * max(1, abs(a), abs(b))
  ```

- La comparaison est inclusive (`<=`). Il ne faut utiliser ni
  `double.minPositive`, ni une tolérance absolue arbitraire, ni l'epsilon du
  framework Flutter.
- Toute entrée égale à `-0.0` est valide là où `0.0` est valide, puis
  canonisée en `+0.0`. Préserver le bit de signe de zéro n'est pas un contrat.
- `upper` vaut la référence logique exactement contrainte par `min` et `max`.
  Si la référence est dans l'intervalle, son double exact est conservé; sinon
  la borne exacte concernée est conservée. `max == double.infinity` est donc
  compatible avec un `upper` fini puisque la référence doit être finie.

### Domaine régulier

Pour une entrée acceptée, `_CandidateSet` régulier respecte simultanément les
invariants suivants.

1. Il est non vide, fini, virtuel et stocké en espace constant.
2. Ses valeurs observables sont finies, canoniques pour zéro, strictement
   croissantes et incluses dans `[min, upper]`.
3. Les points de grille sont évalués en double comme
   `min + index * step`, avec un indice entier non négatif. Ils ne sont jamais
   ancrés sur zéro et ne proviennent jamais de `floor(min / step) * step`.
4. Aucune conversion double-vers-entier n'a lieu avant d'avoir prouvé que le
   quotient est fini et représentable. Pour rester identique sur VM et web, le
   dernier indice régulier ne dépasse pas `2^53 - 1`.
5. La suite entière des points de grille utilisés doit progresser, pas seulement
   le premier et le dernier couple. Si l'implémentation ne peut pas le prouver
   sans parcours linéaire, elle rejette conservativement le domaine par
   `ArgumentError`. Implémenter une table virtuelle de déduplication ULP par ULP
   pour accepter ces tailles astronomiques est hors périmètre.
6. Les valeurs calculées sont contraintes aux bornes exactes avant exposition.
   Une valeur non finie, un dépassement d'indice ou deux points réguliers égaux
   rendent l'entrée invalide; ils ne sont ni clampés vers un faux candidat ni
   laissés à la dichotomie.
7. Soit `last` le dernier point régulier strict. Si `last` et `upper` sont quasi
   égaux, `last` est remplacé par le double exact `upper`. Sinon, si
   `last < upper`, `upper` est ajouté. Il n'existe jamais deux indices pour ce
   couple terminal.
8. Si `upper == min`, le domaine est le singleton exact `[upper]`, même si
   `min + step == min`; aucun pas n'est nécessaire. Si `upper > min` et qu'un
   point régulier nécessaire ne progresse pas, l'entrée est rejetée.

La tolérance sert à réconcilier la borne terminale exacte. Elle n'autorise pas
une suite régulière non stricte et ne doit pas déplacer un point intérieur.

### Presets

Le domaine de presets suit un oracle distinct.

1. La liste est copiée avant validation et avant recherche. Le snapshot interne
   ne partage aucun stockage mutable avec l'appelant.
2. Elle est non vide; chaque valeur est finie et supérieure ou égale à zéro.
   Les zéros signés sont canonisés.
3. L'ordre public est vérifié **avant** déduplication et doit être exactement
   non croissant. Deux valeurs égales sont donc valides, mais une hausse même
   quasi égale reste une erreur : la tolérance ne devient pas un tri silencieux.
4. Les valeurs adjacentes égales ou quasi égales sont fusionnées avec la même
   tolérance relative. Parce que l'entrée est descendante, la première valeur
   — la plus grande — est conservée. Une chaîne est comparée au représentant
   conservé, pas au dernier élément supprimé, afin d'éviter une dérive
   non-transitive de tolérance.
5. Le domaine interne est l'inverse croissant du snapshot dédupliqué. Chaque
   valeur retournée est donc une valeur exacte fournie par l'appelant, à la
   seule canonisation de `-0.0` près.

Une mutation de la liste source après création de `_CandidateSet` ne change pas
ce domaine. Un nouveau build peut naturellement créer un nouveau snapshot à
partir de la valeur courante du champ public; garantir le comportement d'une
`List` personnalisée qui se modifie pendant ses propres getters est hors
contrat.

### Dichotomie

Le prédicat de fit est supposé monotone : lorsqu'un candidat tient, tous les
candidats plus petits tiennent. La recherche :

- travaille sur les indices entiers du domaine ascendant;
- retourne le plus grand candidat qui tient et `fits == true`;
- retourne le plus petit candidat du domaine et `fits == false` si aucun ne
  tient;
- retourne `upper` exact lorsqu'il tient;
- ne retourne jamais une interpolation, une borne sentinelle ou un preset
  étranger;
- calcule le milieu par arithmétique entière sûre, par exemple à partir de
  `left + (right - left) ~/ 2`, jamais via une division double ni par
  `left + right` susceptible de déborder;
- effectue `O(log2 N)` appels au prédicat et ne matérialise jamais les `N`
  tailles régulières.

Un prédicat non monotone est hors contrat de la dichotomie. Cette hypothèse
devra aussi rester explicite lors de l'arrivée de `TextScaler` au lot 3.

## Validations runtime

Les contrôles sont des branches runtime qui lèvent `ArgumentError`, pas des
assertions. Les assertions peuvent rester en doublon dans les constructeurs
`const`, mais ne constituent jamais la validation.

| Entrée active | Valeurs acceptées | Valeurs rejetées |
|---|---|---|
| `minFontSize` régulier | double fini `>= 0`, dont `-0.0`, subnormal et `double.maxFinite` sous réserve de représentabilité du domaine | NaN, `+/-infinity`, valeur `< 0` |
| référence `style.fontSize` | double fini `>= 0`; `null` devient la référence par défaut; zéro est valide | NaN, `+/-infinity`, valeur `< 0` |
| `stepGranularity` régulier | double fini `>= 0.1` | NaN, `+/-infinity`, valeur `< 0.1`, dont zéro |
| `maxFontSize` régulier | double fini `> 0` ou exactement `double.infinity`, et `>= min` | NaN, `-infinity`, zéro, valeur négative ou `< min` |
| `textScaleFactor` présent | double fini `>= 0`, dont zéro et `double.maxFinite` | NaN, `+/-infinity`, valeur `< 0` |
| `presetFontSizes` actif | snapshot non vide, fini, `>= 0`, exactement non croissant | liste vide, NaN, infini, négatif ou hausse |

Les paramètres `minFontSize`, `maxFontSize` et `stepGranularity` documentés
comme ignorés lorsqu'un preset est fourni ne protègent alors aucun calcul du
domaine et ne doivent pas être utilisés pour rejeter un preset valide. La
référence et l'ancien facteur restent actifs pour mesurer les presets et sont
toujours validés.

Les validations de `overflow`/`overflowReplacement`, `maxLines` et des clés ne
font pas partie du lot numérique. Les convertir en runtime peut être utile,
mais ne doit pas agrandir ce lot sans décision séparée.

Une entrée individuellement finie ne garantit pas qu'un résultat arithmétique
le soit. Tout quotient d'indice, candidat ou facteur effectif calculé dans le
chemin modifié par le lot 2 est contrôlé avant conversion ou remise au painter.
Un résultat NaN ou infini produit `ArgumentError`. Le comportement d'un
`TextPainter` auquel on donnerait une taille finie proche de
`double.maxFinite` n'appartient toutefois pas à l'oracle de `_CandidateSet`;
la prise en charge exacte de paragraphes à cette magnitude est hors contrat.

La référence zéro et `textScaleFactor == 0` sont expressément valides. Rejeter
`TextStyle(fontSize: 0)` pour éviter la division actuelle corrigerait le mauvais
contrat : la sémantique de rendu de la référence zéro appartient au lot 4.

## Table d'oracle

Dans les lignes régulières, `upper` est déjà la référence clampée.

| Cas | Résultat obligatoire |
|---|---|
| `min=.3`, `upper=.5`, `step=.1` | domaine `[.3, .4, .5]`; aucune précondition de divisibilité décimale |
| `min=16.3`, `upper=19.3`, `step=1` | `[16.3, 17.3, 18.3, 19.3]` |
| `min=12`, `upper=33.5`, `step=5` | `[12, 17, 22, 27, 32, 33.5]`; jamais `10` |
| `min=12`, `upper=14`, `step=5` | `[12, 14]`; l'intervalle inférieur au pas garde les deux bornes |
| `min=12`, `upper=60`, `step=1` | domaine historique entier inchangé, de 12 à 60 inclus |
| `min=12`, référence `33.5`, `step=1` | fin `[..., 33, 33.5]`; fit de la borne retourne exactement `33.5`, échec de celle-ci avec fit de 33 retourne 33 |
| dernier pas à un ULP de `upper` | un seul terminal, égal bit pour bit à `upper` |
| `min < upper` mais quasi égaux | singleton `[upper]`, résolution normative de la contradiction des deux bornes |
| `min=-0.0`, `upper=.2`, `step=.1` | premier candidat `+0.0`, puis `.1`, `.2` |
| `min=0`, `upper=double.minPositive`, `step=.1` | singleton `[double.minPositive]`; le plancher `max(1, ...)` les rend quasi égaux et `upper` gagne |
| `min=1e15`, `upper=1e15+10`, `step=.1` | `ArgumentError`; le premier pas progresse mais des indices intérieurs se répètent |
| `min=0`, `upper=double.maxFinite`, `step=.1` | `ArgumentError` avant `floor`/`toInt`; le quotient devient infini |
| quotient ou dernier indice `> 2^53-1` | `ArgumentError` avant toute arithmétique d'indice |
| `min=upper=double.maxFinite` | `_CandidateSet` singleton accepté; aucun pas ni quotient énorme n'est requis |
| aucun candidat ne tient | plus petit candidat exact et `fits == false` |
| la borne haute tient | `upper` exact et `fits == true` |
| presets `[100, 50, 5]` | domaine interne `[5, 50, 100]` |
| presets `[20, 20, 10]` | `[10, 20]` |
| presets `[20 + 1 ULP, 20, 10]` | `[10, 20 + 1 ULP]`; le plus grand représentant exact est conservé |
| presets `[20, 20 + 1 ULP, 10]` | `ArgumentError`; l'ordre augmente avant déduplication |
| presets `[double.minPositive, 0]` | singleton `[double.minPositive]` par quasi-égalité |
| presets `[0, -0.0]` | singleton `[+0.0]` |
| presets `[40, 20, 30]`, `[]`, négatif, NaN ou infini | `ArgumentError` |
| preset valide avec liste non modifiable | même résultat qu'une liste mutable; aucune tentative de tri/reverse en place |

## Preuves numériques et pièges d'implémentation

Un probe temporaire, supprimé après exécution, a été lancé avec Dart 3.11.4,
dans la famille de runtime du minimum :

- `(double.maxFinite / 0.1)` vaut `Infinity`;
- `double.maxFinite.floor()` sature à `9223372036854775807` sur le VM, puis
  l'addition de 1 reboucle à `-9223372036854775808`;
- la documentation `dart:core` de ce SDK précise que les `int` VM sont des
  entiers 64 bits avec wrap, alors que les entiers compilés en JavaScript ne
  sont tous exacts que jusqu'à `2^53`;
- pour `min=1e15`, `step=.1`, les indices 3, 8, 13, etc. répètent le candidat
  précédent malgré `min + step > min`;
- `double.minPositive` est quasi égal à zéro avec la tolérance imposée, et
  `-0.0 >= 0` vaut vrai.

Les erreurs de mise en œuvre les plus probables sont donc :

- appeler `floor`, `ceil`, `round`, `toInt` ou `~/` sur un quotient non fini;
- croire que l'entier Dart est arbitraire ou identique sur VM et web;
- calculer le milieu avec un passage par `double`;
- vérifier seulement le premier ou le dernier incrément d'une grille;
- clamper un indice débordé et créer silencieusement un candidat étranger;
- utiliser `8 * double.minPositive` comme epsilon machine;
- appliquer la tolérance absolue sans facteur de magnitude, ou omettre le
  plancher `1`;
- ajouter `upper` après un dernier pas quasi égal au lieu de le remplacer;
- fusionner `min` et `upper` en gardant `min`, ce qui perd la référence exacte;
- dédupliquer les presets avant de vérifier leur ordre et accepter ainsi une
  liste croissante;
- appeler `sort`, `reverse` en place ou conserver la liste mutable de
  l'appelant;
- laisser NaN traverser une validation fondée seulement sur `< 0` ou `>= 0`;
- rejeter tous les zéros alors que seuls zéro pour `max` et pour `step` sont
  invalides;
- retourner une sentinelle sous le minimum lorsque le premier candidat échoue;
- matérialiser la grille avec `List.generate`, `Iterable.generate(...).toList`
  ou une boucle proportionnelle à `(upper - min) / step`.

## Tests bloquants

Les fichiers de test concernés gardent un `group()` par classe/comportement et
des noms « should ... ». Chaque test public invalide attend `ArgumentError`,
jamais `AssertionError`.

### P0 — requis avant merge

1. **Grille publique :** `.3/.1`, `16.3/1`, `12/5`, intervalle inférieur au
   pas, plage non multiple, historique `12..60/1`, référence `33.5` exacte puis
   candidat 33 sous une contrainte voisine.
2. **Recherche :** borne haute qui tient, candidat intérieur maximal, aucun
   candidat qui tient, domaine singleton et presets. Le résultat appartient
   toujours au domaine et le booléen de fit décrit le candidat local minimal.
3. **Tolérance :** dernier pas égal, à moins de 8 epsilon relatifs, juste à
   l'intérieur et juste à l'extérieur de la frontière; vérifier l'exactitude
   bit à bit de `upper` et l'absence de second terminal.
4. **Progression/indice :** le cas `1e15..1e15+10/.1` est rejeté; quotient
   infini avec `double.maxFinite/.1` et quotient au-delà de `2^53-1` sont
   rejetés avant conversion. Le singleton `double.maxFinite` reste constructible
   au niveau du domaine.
5. **Zéros/subnormaux :** `-0.0` devient `+0.0`, `double.minPositive` suit la
   règle de fusion terminale, et min/référence/facteur zéro restent valides.
6. **Presets :** ordre descendant, égalités exactes, quasi-doublons descendants,
   quasi-hausse rejetée, zéro signé, subnormal, liste vide/croissante/négative/
   non finie, liste non modifiable et liste source inchangée.
7. **Snapshot :** une mutation de la liste source après construction du domaine
   ne modifie ni sa longueur ni ses valeurs. Un rebuild explicite peut prendre
   un nouveau snapshot.
8. **Runtime :** matrice NaN, deux infinis, négatifs et zéros contextuels via
   les deux constructeurs publics. Migrer toutes les anciennes attentes
   `AssertionError` de ce périmètre.
9. **Complexité :** sur un domaine régulier strict d'environ `10^12` candidats,
   un prédicat compteur reste sous 45 appels et aucun stockage ne croît avec
   le ratio. Un timeout seul n'est pas une preuve. Si l'encapsulation privée
   empêche le compteur permanent, la revue joint un probe instrumenté temporaire
   rouge/vert et contrôle statiquement le stockage en espace constant.

### P1 — recommandé dans le même lot

- Exactement les mêmes probes numériques sur Flutter 3.41.0/Dart 3.11.0 et sur
  la pin haute 3.47.2/Dart 3.13.2.
- Un smoke compilé/exécuté sans assertions. À défaut d'un mode release du
  harness widget, la preuve minimale combine tests publics attendant
  `ArgumentError`, inspection des branches `if/throw` et un petit probe AOT ou
  `dart --disable-asserts` adapté à une fonction pure.
- Un test différentiel qui énumère seulement de petits domaines de référence et
  compare toutes les décisions de dichotomie à un oracle linéaire de test. Il
  ne justifie jamais de matérialiser le domaine en production.

## Nécessaire, versus hors contrat

### Nécessaire au lot 2

- domaine régulier virtuel, strict, borné et exact aux extrémités;
- garde de quotient et d'indice avant toute conversion;
- rejet déterministe de toute progression double non stricte;
- snapshot, validation et déduplication déterministes des presets;
- erreurs runtime indépendantes des assertions;
- plus grand fit en temps logarithmique, plus petit candidat si aucun fit;
- aucune valeur NaN/infinie produite par le chemin numérique modifié;
- maintien de #151 ouverte, le lot ne possédant toujours pas sa reproduction
  originale.

### Hors contrat ou overengineering

- nombres décimaux arbitraires, rationnels exacts ou `BigInt` pour accepter plus
  de `2^53-1` intervalles;
- indexation virtuelle de milliards d'alias ULP afin d'accepter une grille qui
  ne progresse plus en double;
- préservation du signe de zéro ou des payloads NaN;
- tolérance à un prédicat de fit non monotone;
- tri réparateur d'une liste de presets croissante;
- protection contre une implémentation exotique de `List` qui se modifie dans
  ses propres accesseurs;
- garantie de layout typographique utile à `double.maxFinite`;
- correction de la division/sémantique RichText de référence zéro (lot 4), des
  scalers non linéaires (lot 3) ou de la projection de groupe (lot 5);
- conversion opportuniste de toutes les assertions non numériques du widget.

## Critères de revue indépendante

Le lot 2 est acceptable seulement si le reviewer peut répondre oui à chaque
point :

- [ ] chaque fabrique de `_CandidateSet` établit non-vacuité, finitude,
      bornage et croissance stricte;
- [ ] la règle `8 * 2^-52 * max(1, ...)` est visible, unique et testée aux deux
      côtés de sa frontière;
- [ ] `upper` exact remplace le quasi-terminal et gagne aussi contre un `min`
      quasi égal;
- [ ] aucun quotient non fini ou indice hors plage n'atteint une conversion en
      `int`;
- [ ] le cas de progression tardivement impossible est rejeté ou réellement
      représenté sans indices alias; une simple vérification `min + step` est
      insuffisante;
- [ ] le chemin régulier ne contient aucune collection ou boucle linéaire dans
      le nombre de tailles;
- [ ] la dichotomie n'utilise que l'arithmétique entière sûre et renvoie une
      valeur du domaine sur tous ses exits;
- [ ] les presets sont copiés avant validation, jamais triés, et leur ordre est
      contrôlé avant déduplication;
- [ ] zéro, `-0.0`, subnormaux, NaN, infinis et `double.maxFinite` suivent la
      table ci-dessus sans dépendre des assertions;
- [ ] les paramètres ignorés en mode preset ne modifient pas son domaine;
- [ ] les tests nouveaux sont rouges sur `ae52fe6` pour la cause qu'ils visent,
      verts sur la tête du lot, et la suite historique valide est inchangée;
- [ ] format, analyse et tests passent sur les pins minimale et haute prévues;
- [ ] aucun test n'encode un tri silencieux, une taille sous le minimum ou la
      fermeture de #151.

Tout domaine non strict, toute conversion saturée/enveloppée, toute allocation
proportionnelle au ratio ou tout résultat hors domaine impose le revert entier
du lot conformément à la feuille de route.
