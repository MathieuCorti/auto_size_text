# Revue indépendante du lot 2 — domaine de candidats

Date : 2026-09-01

Base exacte : `d77c08ea846474632e94888a7fa74f1ec0dc44ab`

Tête initialement revue : `af54facdc4b74071355d461772aa3e41c906a06a`

Rapport initial : `3cf3d13`

Tête corrigée re-revue : `ecf7a9d1d5f100af2edd6792e914aa9bcfb85e05`

Périmètre : `_CandidateSet`, grille régulière, presets, dichotomie,
validations runtime, compatibilité des entrées publiques et preuves du lot 2.
La re-revue porte sur `3cf3d13..ecf7a9d` et sur le cumul
`d77c08e...ecf7a9d`. Aucun correctif produit ou test n'a été ajouté par la
revue ; seul le présent rapport est modifié.

## Verdict final

**ACCEPTÉ.**

Les trois findings P1 de la première revue sont résolus, chacun par un test
public permanent qui échoue pour sa cause propre sur `af54fac` et passe sur
`ecf7a9d`. Aucun finding ouvert n'a été identifié dans le delta correctif ni
dans le cumul du lot.

La grille régulière reste virtuelle en `O(1)`, strictement croissante et
bornée par l'upper exact. La recherche rend le plus grand candidat qui tient,
avec fallback sur le minimum, en `O(log C)`. Les presets sont snapshotés,
validés dans l'ordre exact avant déduplication, dédupliqués sans mutation de
la source, puis exposés en ordre ascendant. Les validations publiques
requises sont des `if/throw ArgumentError`, y compris lorsque des opérandes
finies produisent un débordement avant le painter.

## Re-revue des trois findings P1

Les trois tests permanents ont été copiés sur une archive propre de
`af54fac`, sans reprendre le code corrigé. Sous Flutter 3.47.2, la sélection
des trois tests termine avec trois échecs :

- le preset est rejeté à tort sur `minFontSize` ;
- les augmentations exactes d'un ULP et après quasi-doublon ne lèvent rien ;
- le produit avec `double.maxFinite` produit des assertions Flutter et des
  erreurs de layout, pas `ArgumentError`.

La même sélection sur `ecf7a9d` passe 3/3. Les tests invoquent uniquement les
constructeurs publics `AutoSizeText` et `AutoSizeText.rich`.

### P1 résolu — Les paramètres de grille sont ignorés en mode preset

**Test permanent :**
`should ignore regular grid parameters for both preset constructors`, dans
`test/preset_font_sizes_test.dart`.

`_validateCandidateInputs` ne traite désormais que la référence de style et
le facteur explicite, qui restent actifs dans les deux modes.
`_validateRegularCandidateInputs` n'est appelée qu'après avoir constaté
l'absence de presets. Des presets valides avec `min=-1`, `max=0` et `step=0`
passent donc pour les deux constructeurs, conformément à la documentation
publique « Is being ignored ».

Le delta ne rend pas permissives les entrées régulières : leurs validations
runtime sont identiques, simplement déplacées sur la branche qui les
consomme. Les tests historiques de paramètres réguliers invalides restent
verts.

### P1 résolu — L'ordre exact précède la tolérance des presets

**Test permanent :**
`should reject exact preset increases before near-equal deduplication`, dans
`test/preset_font_sizes_test.dart`.

La fabrique copie d'abord la liste source, canonicalise chaque zéro et compare
chaque paire source adjacente avec l'ordre exact `value > previous`. Elle ne
fait intervenir la tolérance qu'au second passage, contre le dernier
représentant conservé. Elle rejette ainsi :

- `[20, 20 + 1 ULP, 10]` ;
- `[20, 20 - 1 ULP, 20, 10]`.

Les séquences descendantes quasi égales restent valides et gardent le plus
grand représentant exact. Le stockage final est une liste ascendante non
modifiable ; la mutation ultérieure de la liste du caller ne peut pas changer
le domaine.

### P1 résolu — Les valeurs calculées non finies lèvent `ArgumentError`

**Test permanent :**
`should reject a non-finite calculated scale before text layout`, dans
`test/min_max_font_size_test.dart`.

La scale calculée dans le prédicat de recherche et la taille effective finale
sont désormais contrôlées par `_requireFiniteNonNegative` avant toute remise
au painter, au groupe ou au widget `Text`. Avec un `textScaleFactor` fini égal
à `double.maxFinite`, les styles de référence 20 et 0 lèvent un unique
`ArgumentError`; aucune `AssertionError` Flutter n'est nécessaire. Le cas
historique fini `fontSize=20`, facteur 2, continue de produire 40.

Ces gardes sont des branches runtime. Elles restent donc actives avec les
assertions désactivées et précèdent les assertions complémentaires de
`_validateProperties`. Les sous-flux vers zéro restent finis, acceptés et
canonicalisés en `+0.0`.

## Invariants numériques de `_CandidateSet`

Les probes temporaires de la première revue ont été supprimés après exécution.
Le delta correctif ne modifie ni la construction d'une grille régulière, ni
son indexeur, ni la dichotomie ; leurs résultats restent donc applicables au
cumul corrigé. Les quatre suites publiques ciblées ont en outre été rejouées
sur les deux SDK.

- 315 petites combinaisons `(minimum, upper, step)` ont concordé valeur par
  valeur avec une liste exhaustive indépendante. Pour chaque domaine, tous
  les seuils monotones ont donné le même résultat que la recherche linéaire.
- 4 000 grilles déterministes autour de puissances de deux, jusqu'aux hautes
  magnitudes finies, étaient strictement croissantes lorsqu'elles étaient
  acceptées. Les rejets conservateurs permis par l'oracle n'ont pas été
  assimilés à des erreurs.
- La tolérance terminale est inclusive à `8 × 2^-52` : le dernier point est
  remplacé par l'upper exact ; à neuf epsilons, l'upper devient un candidat
  distinct.
- Si minimum et upper sont quasi égaux, le singleton conserve l'upper exact.
  `-0.0` devient `+0.0`, `double.minPositive` fusionne avec zéro et
  `double.maxFinite` est accepté comme singleton.
- Le ratio doit être fini et inférieur ou égal à `2^53 - 1` avant
  `floor()`/conversion d'indice. Le milieu de recherche est calculé par
  `left + (right - left) ~/ 2`, sans addition d'indices susceptible de
  déborder et sans passage par `double`.
- Une grille ne contient ni `List`, ni génération ou boucle proportionnelle à
  sa longueur : minimum, upper, pas, longueurs et booléen suffisent en espace
  constant. Seuls les presets allouent le snapshot `O(P)` requis.
- La dichotomie mémorise le plus grand candidat qui tient et rend le minimum
  avec `fits=false` si aucun candidat ne tient.

Le test permanent `min=0.1`, `upper=100000000`, `step=0.1` représente environ
un milliard de candidats. Une instrumentation indépendante a compté
exactement 30 appels à `_CountingTextSpan.build`; le test force un
`overflowReplacement`, de sorte que le rendu final n'ajoute pas un build au
compteur. Sa borne permanente `<= 40` mesure donc bien la complexité
logarithmique de la recherche, et non une matérialisation préalable.

## Référence zéro, bornes extrêmes et absence d'élargissement

Le correctif n'élargit pas la règle spéciale de référence zéro : elle reste
limitée au chemin simple déjà présent
(`referenceFontSize == 0 && data != null`). Les tests publics
`should accept zero lower inputs and an infinite maximum` et
`should reject a non-finite calculated scale before text layout`
passent ensemble sur la tête corrigée : les cas valides `-0.0`, référence
simple zéro et facteur zéro conservent une taille effective `+0.0`, tandis que
le seul produit non fini est rejeté.

Le comportement complet de référence zéro pour le constructeur rich reste
hors lot, comme prévu pour les lots ultérieurs. La correction ne lui ajoute
aucune nouvelle sémantique ; elle garantit seulement qu'une valeur dérivée
infinie n'atteint plus les assertions internes de Flutter.

Les signatures, paramètres, valeurs par défaut, exports et symboles publics
sont inchangés. Le delta correctif touche deux fichiers privés, les deux
fichiers de tests permanents correspondants et le journal du lot. Aucun
fichier de groupe, API de rendu ou autre domaine fonctionnel n'est modifié.

## Matrice finale indépendante

SDK exacts exécutés :

```text
Flutter 3.41.0 • 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • d3b14c8769 • Dart 3.13.2
```

### Flutter 3.47.2

| Contrôle | Résultat |
|---|---|
| Trois régressions correctives sélectionnées | 3/3 |
| Quatre suites ciblées du lot | 31/31 |
| Suite racine complète | 56/56 |
| Cycle de vie + signal de fuite | 9/9 |
| Analyse scoped `lib test example/main.dart` | code 1 attendu ; exactement 9 informations historiques `deprecated_member_use`, 0 warning, 0 erreur |
| Exemple, `pub get --enforce-lockfile`, puis analyse fatale | succès ; aucun diagnostic ; SHA-256 du lock inchangé (`115848eb…b1f7`) |
| Format canonique `lib test example` | 22 fichiers, 0 changement |

### Flutter 3.41.0

La tête corrigée a été extraite dans une copie fraîche sans artefact généré ;
le lock canonique haut de l'exemple a été déplacé avant toute résolution.

| Contrôle | Résultat |
|---|---|
| `pub get --no-example` | succès ; 26 dépendances résolues naturellement |
| Quatre suites ciblées du lot | 31/31 |
| Suite racine complète | 56/56 |
| Cycle de vie + signal de fuite | 9/9 |
| Analyse scoped `lib test example/main.dart` | code 1 attendu ; les mêmes 9 informations historiques, 0 warning, 0 erreur |
| Exemple sans lock, résolution puis analyse fatale | succès ; 10 dépendances, `meta 1.17.0`, `vector_math 2.2.0`, aucun diagnostic |
| Format des sept fichiers Dart du lot | 7 fichiers, 0 changement |
| `pub downgrade --no-example`, puis suite complète `--no-pub` | 9 dépendances abaissées ; 56/56 |

Le format complet avec Dart 3.11 voudrait toujours réécrire deux fichiers du
lot 1, tandis qu'aucun des sept fichiers Dart du lot 2 n'est concerné. La
politique du dépôt retient le format canonique haut, entièrement propre ;
cette divergence préexistante n'est pas imputable au lot 2.

## Reproduction du parent et cohérence documentaire

Les quatre fichiers de tests du lot, copiés sur une archive propre de
`d77c08e`, donnent sous Flutter 3.47.2 le rouge attendu : code 1, 13 tests
passés et 15 échecs. Les causes couvrent les anciennes assertions de
divisibilité, les types d'erreur runtime, l'upper quasi égal, les alias tardifs
et le quotient non représentable. Le journal corrigé annonce désormais le
même compteur 13/15.

Le journal de lot documente aussi le cycle correctif rouge sur `af54fac`, puis
la matrice 31/56/9 sur `ecf7a9d`. Ses affirmations ont été reproduites
indépendamment.

## Surface lue et checklist `find-bugs`

Les cinq fichiers du delta `3cf3d13..ecf7a9d` et les neuf fichiers du cumul
`d77c08e...ecf7a9d` ont été lus intégralement, avec le code voisin de layout,
groupe, helpers de test, manifests et options d'analyse. Ont également été lus
l'oracle numérique, le journal du lot, le lot 2 et la gate finale de la
roadmap, les plans/audits/revues du cœur, la politique de lock de l'exemple et
les instructions `developing-flutter`, Effective Dart, testing et
`find-bugs`.

| Classe de risque | Conclusion finale |
|---|---|
| Logique numérique | Conforme sur les propriétés, extrêmes et probes décrits ; aucun finding ouvert. |
| Ressources / déni de service | Grille `O(1)`, recherche `O(log C)`, presets `O(P)` requis ; compteur logarithmique pertinent. |
| État / mutation / concurrence | Snapshot des presets ; aucun nouveau flux asynchrone, état partagé ou modification de groupe. |
| Runtime release | Invalides et dérivés non finis rejetés par `ArgumentError` hors `assert`. |
| Compatibilité / API | Signatures et entrées valides historiques conservées ; paramètres réellement ignorés restaurés en mode preset. |
| Injection, auth, secrets, crypto, réseau | Hors surface : aucune commande, requête, identité, persistance ou donnée sensible ajoutée. |

Le lot 2 satisfait donc sa gate de revue finale sur la tête
`ecf7a9d1d5f100af2edd6792e914aa9bcfb85e05`.
