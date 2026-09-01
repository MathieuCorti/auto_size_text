# Revue lot 4 — RichText, performance et ressources

Date : 2026-09-01

Candidat revu : `719d6a8df5f699b9ac8963dfb3034e56f71d12ad`

Parent exact : `3a1c343e88325b0020452be7c3258a902d87558f`

Branche de revue : `codex/review-rich-text-performance`

## Verdict

**CHANGEMENTS REQUIS.**

Le lot respecte les bornes de painters, de layouts, de requêtes de boxes et de
dispose. Il ne matérialise pas le domaine de candidats, ne conserve aucun cache
observable, ne mute pas l'arbre source et ne montre aucune fuite sur les probes
ou sur les tests `leak_tracker`.

Un point reste cependant bloquant : le texte visuel et sa segmentation UTF-16
sont recalculés pour chaque candidat de la dichotomie. Cela viole explicitement
le budget de l'oracle adversarial corrigé, qui exige un seul scan de `N` par
évaluation de configuration. Le défaut multiplie un coût et une allocation de
taille `N` par le nombre de candidats effectivement testés.

Ce défaut est un risque de disponibilité réel et évitable, mais les preuves ne
permettent pas de le qualifier de DoS asymptotiquement non borné : la
dichotomie borne le multiplicateur et Flutter ne documente pas la complexité
interne de `Paragraph.getBoxesForRange`.

## Finding bloquant

### [P1] La segmentation indépendante du candidat est répétée dans la dichotomie

**Fichier :** `lib/src/auto_size_text.dart:473-492`, `:511-526`

**Sévérité :** moyenne pour le produit, bloquante pour le gate du lot 4.

`findLargestThatFits` appelle `_checkTextFits` pour chaque candidat. Ce dernier
appelle à nouveau :

```dart
final plainText = text.toPlainText(includeSemanticsLabels: false);
for (final range in _unbreakableTextRanges(plainText)) { ... }
```

Le contenu et les offsets du texte ne dépendent pourtant ni du candidat ni de
son scaler. Le clone de spacing est déjà correctement calculé hors de la
closure, lignes 465-470 ; le même principe doit s'appliquer au texte visuel et
aux ranges.

L'oracle adversarial corrigé `6251a04`, section « Budget de segmentation et
risque de disponibilité », impose :

- un seul calcul du texte visuel et des ranges par configuration ;
- un passage UTF-16 sur `N` ;
- au plus `K × E` requêtes de boxes, où `E` est le nombre de candidats testés.

Le compteur temporaire donne, pour un domaine virtuel de
`1 000 000 001` candidats :

| SDK | Candidats testés `E` | `toPlainText` | Scans de ranges | Attendu |
|---|---:|---:|---:|---:|
| Flutter 3.41.0 | 30 | 30 | 30 | 1 |
| Flutter 3.47.2 | 30 | 30 | 30 | 1 |

La lecture du code généralise directement la preuve : le coût de segmentation
est `Θ(E × N)` au lieu du budget `Θ(N)`. Avec la limite exacte du domaine du
lot 2, `E <= ceil(log2(L + 1))` et reste borné ; la correction demeure exigée
par le gate et évite un multiplicateur pouvant atteindre quelques dizaines.

**Correction requise, non produite dans cette revue :** calculer le texte visuel
et matérialiser uniquement ses `TextRange` une fois dans
`_calculateFontSize`, avant `findLargestThatFits`, puis passer ces ranges à
`_checkTextFits`. Ne pas mettre en cache ce résultat entre builds ou entre
configurations. Ajouter un test déterministe qui impose exactement un scan
pour plusieurs candidats, sans seuil de temps mural.

## Cartographie structurelle du coût

Notations :

- `N` : code units du texte visuel ;
- `K` : plages non vides, avec `K <= ceil(N / 2)` ;
- `S` : `TextSpan` standards clonés sous override ;
- `E` : candidats effectivement testés par la dichotomie ;
- `B(r)` : boxes rendues par Flutter pour une plage `r`.

### Par évaluation de configuration

| Ressource | Borne observée dans le candidat |
|---|---|
| Domaine de candidats | Stockage constant pour une grille régulière ; accès indexé, recherche `O(log L)`. |
| Clone RichText | Zéro sans override ; sinon `S` nouveaux spans et une nouvelle liste par nœud standard ayant des enfants. Le clone est hors de la boucle candidats. |
| Texte visuel et segmentation | Actuellement `E` chaînes de taille `N` et `E` scans RegExp ; doit devenir un seul texte et un seul scan. |
| Painter auxiliaire | Exactement un par candidat avec `wrapWords:false`. |
| Layout auxiliaire | Exactement un layout non wrappé par painter auxiliaire. |
| Requêtes de boxes | Au plus une par plage et candidat, arrêt au premier dépassement : `<= K × E`. |
| Painter principal | Zéro si une plage échoue ; sinon exactement un par candidat. |
| Layout principal | Zéro ou un, parallèlement au painter principal. |
| Dispose | Exactement un par painter créé ; les deux chemins sont protégés par `finally`. |
| Pic de painters du package | Un : l'auxiliaire est disposé avant la création éventuelle du principal. |

Il n'existe donc aucun painter ni layout par plage. Pour `E` candidats, le
nombre total de painters et de layouts appartient à `[E, 2E]`, et le nombre de
disposals lui est égal.

### Mémoire transitoire

Le nouveau chemin évite les `split` et `join` du parent. Les ranges sont
actuellement produits en streaming, sans substring ni copie de span par plage.
Chaque appel de boxes produit toutefois une liste temporaire. Sur les deux SDK,
`TextPainter.getBoxesForSelection` délègue à
`Paragraph.getBoxesForRange`; le moteur copie un vecteur C++ vers un
`Float32List`, puis décode les éléments en `TextBox` Dart. Le pic lié à une
requête est donc proportionnel à `B(r)`, pas seulement au nombre de ranges.

Le probe bidi `A\u00A0אב\u00A0` répété a produit 513 boxes pour une seule
plage. La liste a été libérée après le fold et le painter après le retour
anticipé. Aucune accumulation inter-plages n'est présente.

Le clone de spacing est linéaire dans les spans standards et local au build.
Avec 2 048 runs plats, les compteurs donnent 2 049 clones (racine comprise),
une liste enfant, quelle que soit la taille du domaine candidat. Sans override,
le span source est réutilisé. Les probes ont vérifié après chaque pump
l'identité de la liste source et l'absence de changement de style.

## Probes reproductibles et résultats

Les probes temporaires ont instrumenté les deux révisions dans des copies
isolées. Ils ont été exécutés sous les toolchains exactes :

```text
Flutter 3.41.0, revision 44a626f4f0, Dart 3.11.0
Flutter 3.47.2, revision d3b14c8769, Dart 3.13.2
```

Chaque mesure murale est la médiane de trois pumps après warm-up. Elle est un
signal diagnostique seulement : aucun seuil temporel n'est proposé comme gate.
Les compteurs d'opérations sont, eux, déterministes.

### Croissance `N/2N/4N`

Temps médians en millisecondes :

| SDK | Révision | Cas | `N` | `2N` | `4N` |
|---|---|---|---:|---:|---:|
| 3.41 | parent | simple, `A/espace` | 2,02 (8 192) | 3,27 | 6,19 |
| 3.41 | candidat | simple, `A/espace` | 4,53 (8 192) | 13,17 | 23,60 |
| 3.47 | parent | simple, `A/espace` | 3,27 (8 192) | 4,77 | 8,67 |
| 3.47 | candidat | simple, `A/espace` | 5,29 (8 192) | 13,39 | 25,05 |
| 3.41 | parent | riche, `A/espace/NBSP` | 1,35 (512 runs) | 1,48 | 2,39 |
| 3.41 | candidat | riche, `A/espace/NBSP` | 4,04 (512 runs) | 5,25 | 10,15 |
| 3.47 | parent | riche, `A/espace/NBSP` | 1,25 (512 runs) | 1,48 | 1,93 |
| 3.47 | candidat | riche, `A/espace/NBSP` | 5,02 (512 runs) | 6,17 | 10,11 |

Le candidat reste proche d'une croissance linéaire sur ces fenêtres. Il est
plus coûteux que le parent pour les milliers de runs, ce qui est cohérent avec
le clone fidèle et les appels de boxes. Les courbes ne démontrent pas une
croissance quadratique, mais ne peuvent pas contractualiser le coût interne de
Flutter.

### Compteurs discriminants

| Entrée, un candidat | Ranges | Appels boxes | Boxes | Painters/layouts/disposals | Clones |
|---|---:|---:|---:|---:|---:|
| simple `A/espace`, 2 048 code units | 1 024 | 1 024 | 1 024 | 2 / 2 / 2 | 0 |
| riche `A/espace`, 2 048 runs | 1 024 | 1 024 | 1 024 | 2 / 2 / 2 | 2 049 |
| simple `A/NBSP`, 2 048 code units | 1 | 1 | 1 | 1 / 1 / 1 | 0 |
| riche `A/NBSP`, 2 048 runs | 1 | 1 | 1 | 1 / 1 / 1 | 2 049 |
| mixte `A/espace/A/NBSP`, 2 048 runs | 513 | 513 | 513 | 2 / 2 / 2 | 2 049 |
| bidi multi-box, 1 280 code units | 1 | 1 | 513 | 1 / 1 / 1 | 0 |
| plage NBSP unique, 65 537 code units | 1 | 1 | 1 | 1 / 1 / 1 | 0 |

La plage unique de 65 537 code units a pris 5,08/9,93 ms dans le candidat sur
3.41/3.47, contre 10,84/15,10 ms sur le parent, qui produisait 32 769 éléments
par `split`. Ce cas confirme l'amélioration mémoire/temps du chemin NBSP et
l'absence de copie par plage.

### Domaine virtuel et cycle de vie

Pour une grille régulière de `1 000 000 001` candidats, les deux SDK ont
observé 30 évaluations et seulement 35 lectures indexées. Aucune liste
proportionnelle au domaine n'a été créée. Dans le candidat : 30 painters
auxiliaires, 10 painters principaux, 40 layouts et 40 disposals. Le parent
créait 60 painters/layouts/disposals dans le même fixture.

Sur 1 000 rebuilds, les deux SDK donnent exactement :

```text
1 000 painters auxiliaires + 1 000 painters principaux
= 2 000 layouts = 2 000 disposals
livePainters final = 0 ; peakLivePainters = 1
```

Les suites permanentes ciblées
`text_painter_lifecycle_test.dart`, `wrap_words_test.dart` et
`rich_text_test.dart` passent aussi 28/28 sur les deux SDK. Les tests lifecycle
incluent le suivi des ressources natives, les retours anticipés, l'exception de
layout, les rebuilds et le retrait d'un groupe.

## Disponibilité : ce qui est prouvé et ce qui ne l'est pas

- **`O(N)` inévitable :** produire le texte visuel une fois, le scanner une
  fois, construire/layout le paragraphe fidèle et cloner les `S` spans lorsque
  Flutter impose un override.
- **Risque interne non borné par un contrat :** les `K` appels natifs de boxes
  par candidat et le nombre `B(r)` de boxes. Flutter documente le résultat, pas
  la complexité de `getBoxesForRange`. Le lot ne peut revendiquer mieux.
- **Défaut réel :** le scan et la chaîne `toPlainText` sont répétés `E` fois.
  C'est une violation déterministe du budget et une amplification évitable.
- **DoS démontré :** aucun. Les probes 32 768 code units, 65 537 code units,
  2 048 runs, domaine virtuel milliardaire et 1 000 rebuilds terminent sur les
  deux SDK, sans fuite ni croissance murale explosive. Une entrée texte reste
  naturellement non bornée par l'API appelante.

## Mutation, cache et ownership

Le diff ne met en cache ni ranges, ni painter, ni clone, ni résultat de
candidat. Chaque build reconstruit sa configuration et son clone local. Le
`Text` final reçoit toujours le span source ; l'arbre de mesure reçoit le clone
éventuel. Les listes source ne sont ni triées, ni remplacées, ni écrites.

Cette absence de cache évite toute observation d'une ancienne configuration
après changement de scaler, spacing ou contraintes. La correction du finding
doit rester locale à une seule invocation de `_calculateFontSize` pour
conserver cette propriété.

## Recommandations non bloquantes après correction

- Conserver un probe de benchmark hors suite fonctionnelle, sans seuil mural,
  pour surveiller les courbes 8k/16k/32k et les milliers de spans.
- Documenter que `K` appels natifs par candidat sont intentionnels et que la
  complexité moteur n'est pas promise.
- Garder un fixture bidi qui compte plusieurs centaines de boxes afin de
  détecter une future accumulation des listes ou un calcul sur une seule box.

## Pré-conclusion `find-bugs`

Fichiers du diff lus intégralement :

- `lib/src/auto_size_text.dart` ;
- `lib/src/auto_size_text_layout.dart` ;
- `maintenance/implementation/lot-4-rich-text.md` ;
- `test/rich_text_test.dart` ;
- `test/wrap_words_test.dart`.

Ont aussi été relus : le lot 4 de la roadmap, l'oracle RichText, l'oracle
adversarial corrigé `6251a04`, les sources `TextPainter`/`Paragraph` des deux
SDK et les tests lifecycle existants.

Surface d'entrée : texte simple, topologie et métadonnées `InlineSpan`, code
units UTF-16, contraintes, direction/locale, overrides `MediaQuery`, scalers et
domaine numérique de candidats. Aucun accès réseau, fichier, base de données,
session, authentification, autorisation ou cryptographie n'est ajouté.

Checklist : injection, XSS, authentification, autorisation/IDOR, CSRF, session,
cryptographie et information disclosure non applicables ; aucune race ou
mutation partagée trouvée ; domaine numérique non matérialisé ; disposal et
exceptions sûrs ; un finding de disponibilité/DoS au sens du budget de scan ;
aucun autre défaut performance ou ressources confirmé. La complexité native de
`getBoxesForRange` reste la seule zone impossible à borner par revue de l'API.
