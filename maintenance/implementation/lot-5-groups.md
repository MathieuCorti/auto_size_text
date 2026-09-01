# Lot 5 — Groupes hétérogènes

Date : 2026-09-01

Branche : `codex/impl-groups`

Parent exact : `c9a1adc006365feb3e1750069ca1e115c3f20237`

Tête produit et tests : `713be70` ; le commit suivant contient uniquement ce
journal.

## Périmètre livré

Le lot conserve l'API publique existante et sépare désormais les quatre
quantités du contrat de groupe :

```text
L = plus grand candidat logique local qui tient réellement
P = U.scale(L), rapport racine effectif fini publié
G = minimum des P finis des membres inscrits
R = plus grand candidat du domaine propre tel que R <= L et U.scale(R) <= G
```

- le calcul local et `overflowReplacement` ne dépendent jamais de la
  projection de groupe ;
- seul `P` est écrit dans le groupe ; `R` n'est jamais republié ;
- le rendu reçoit `R` et la composition de scaler normale du lot 4, y compris
  pour les runs enfants et les scalers non linéaires ;
- si aucun candidat n'atteint `G`, la recherche rend le plus petit candidat du
  domaine propre, sans modifier `P` ;
- la recherche réutilise le domaine virtuel et sa dichotomie, sans scan ni
  matérialisation ;
- les groupes homogènes conservent leur résultat historique.

Hors périmètre : nouvelle API, render object, intrinsics, `WidgetSpan`, démo,
CI, manifeste, lock, documentation publique et publication.

## Implémentation

`_calculateFontSize` produit toujours `L` à partir du fit réel. Le helper
commun `_checkedEffectiveFontSize` appelle le scaler utilisateur, rejette toute
sortie non finie ou négative, puis canonicalise uniquement le zéro. Cette
validation précède toute écriture de rapport.

Chaque état mémorise le dernier `P` écrit. Il ne rappelle le groupe que lors
d'une transition exacte de `P`, ou après un transfert qui réinitialise cette
mémoire. Une simple projection ou un rebuild de synchronisation ne peut donc
écrire `R`. La projection appelle `findLargestThatFits` sur `_CandidateSet` et
court-circuite `candidate > L` avant d'appeler `U.scale(candidate)`. La seconde
borne est la comparaison exacte et inclusive `U.scale(candidate) <= G`, sans
epsilon, inversion du scaler ou interpolation entre deux candidats.

La valeur rendue est ensuite traitée comme un vrai candidat logique. Les
anciennes branches qui remplaçaient le style racine par `G`, `noScaling` ou un
ratio linéaire ont été supprimées. Cela préserve les runs riches avec scalers
quadratiques et les plateaux, y compris lorsque plusieurs candidats ont la
même taille racine effective.

Une sortie invalide de `U(L)` lève avant publication. Si `P=U(L)` est fini mais
qu'une autre sortie invalide est rencontrée seulement pendant la projection,
la projection lève `ArgumentError` ; aucune valeur invalide n'entre dans la map
ou dans `G`, et le `P` fini déjà écrit reste publié. Il n'existe pas de rollback
transactionnel spéculatif. La régression permanente récupère ensuite sans
réinscription. Elle retire ensuite le voisin qui imposait `G=25` et utilise un
troisième membre de domaine `{70,50}` : le rapport `P=50` conservé impose
encore son rendu à 50. Un rollback vers `+∞` rendrait ce témoin à 70.

## Convergence et cycle de vie

Le contrôleur recalcule le minimum après chaque écriture ou suppression de
rapport. Le retrait est effectif avant la notification : un membre transféré
ou disposé ne contribue plus et n'est pas rappelé par l'ancien groupe.

Le transfert dans `didUpdateWidget` compare les contrôleurs avec `identical`.
`AutoSizeGroup` étant sous-classable, deux instances distinctes peuvent
légalement redéfinir `==` et comparer égales sans représenter la même
appartenance. Le retrait, l'inscription et la remise à zéro du cache sont donc
fondés sur l'identité. L'audit de toutes les occurrences n'a trouvé aucune
autre comparaison contrôleur-à-contrôleur : les autres gardes portent sur
`null` ou sur la présence d'un état dans la map interne.

Le marqueur `_notificationPending` est posé avant `scheduleMicrotask`. Tous les
changements synchrones de `G` d'une époque partagent donc une seule tâche. Au
run, le marqueur est consommé et un snapshot des membres courants est parcouru ;
chaque callback revalide encore l'inscription et `mounted`. Une hausse causée
par le retrait du minimum programme ainsi une vague bornée pour les survivants,
sans callback tardif ni oscillation.

Le test permanent utilise une `ZoneSpecification` et sépare les compteurs de
tâche planifiée et exécutée. Pour la baisse synchrone `40 -> 35 -> 30`, il
exige exactement `1/1` ; la frame témoin ne programme plus rien. Un probe privé
temporaire a en plus tracé séparément `schedule`, `run` et l'identité de chaque
callback. Sur les deux SDK, l'époque initiale et l'époque mutée ont chacune
produit exactement une ligne `schedule`, une ligne `run` et une ligne callback
pour chacun des trois membres encore inscrits. La vague de teardown n'avait
aucun membre et donc aucun callback. Les traces et le code de probe ont été
supprimés ; aucune API ou instrumentation produit ne reste.

## Preuves rouges sur S5

Les premières régressions ont été commitées dans `1ef0f8f`. À cet instant le
code produit était encore byte-identique au parent S5. Sous Flutter 3.41.0 :

```text
flutter test test/group_constraints_test.dart
1 succès, 10 échecs discriminants
```

Les échecs observés couvraient notamment : grille régulière `26 -> 30`, grille
fractionnaire `.4 -> .45`, preset disjoint `20 -> 30`, minimum inaccessible
`20 -> 10`, projection linéaire dans le mauvais domaine, quadratique `40 ->
50`, dépassement d'un ULP accepté, plateau rendu avec le scaler de groupe,
voisin projeté sous son domaine et absence d'`ArgumentError` pendant une
projection invalide. Le compteur du domaine virtuel géant était déjà vert et
n'a pas été présenté artificiellement comme rouge.

Le témoin plateau racine zéro renforcé a été rejoué depuis une extraction du
parent exact `c9a1adc`, avec le même fichier de test, sur les deux pins :

```text
U0(x) = max(0, x - 30), F=20, D={10,20,30}, run Ahem S=100
largeur disponible=95, L=20, P=G=0
attendu box du run=70 ; S5 réel=0.0
```

Le même témoin rend `70` sur la tête. Il distingue la perte de `L` du mutant
qui testerait seulement la borne effective et choisirait 30, donc une box 120.

Le défaut de coalescence a été isolé avec le code de groupe S5 et le test final
de zone : deux baisses synchrones planifiaient et exécutaient `2/2` microtâches
pour une seule frame visible ; attendu `1/1`. Compter seulement les frames ou
les appels de scaler aurait masqué ce défaut.

Le sous-ensemble parent suivant a donné 13 succès et un seul échec, celui du
preset disjoint :

```text
flutter test --no-pub test/group_test.dart test/group_builder_test.dart \
  test/preset_font_sizes_test.dart
```

Les invariants de préservation ne sont pas déclarés rouges : replacement fondé
sur le fit local, retrait/dispose sans callback tardif, transfert et détachement,
groupe homogène, identité stable de `AutoSizeGroupBuilder`. Les probes S5 les
donnaient déjà verts ; les tests de tête les maintiennent verts.

## Correctifs après revue indépendante

La revue générale `fb306d0` a trouvé deux faiblesses, corrigées sans modifier
le contrat mathématique.

La première était test-only : l'ancien cas d'erreur laissait B publier 25. A
rendait donc 20 après récupération que son rapport fini 50 ait été retenu ou
illégalement remplacé par `+∞`. Le test final ajoute C, qui publie 70 avec le
domaine `{70,50}`, puis retire B. Sur le produit intact, C rend 50. Avec le
mutant temporaire `_remove(this); _register(this);` dans le chemin d'exception,
les deux SDK échouent avec `Expected: 50, Actual: 70.0`. Le mutant a été retiré.

La seconde était produit : `oldWidget.group != widget.group` consultait
l'égalité surchargée de deux contrôleurs. Le test utilise deux sous-classes
distinctes mais égales, transfère A de g1 à g2, puis change son rapport de 20 à
30. Sur `b7bd149`, les deux SDK rendaient `A/B/C=20/20/40` au lieu de
`20/40/20`; une publication suivante pouvait en plus atteindre l'assertion
d'inscription. `!identical(oldWidget.group, widget.group)` donne après le
transfert `20/40/20`, puis `30/40/20` sans exception ni frame résiduelle.

## Régressions permanentes

`test/group_constraints_test.dart` couvre les grilles régulières et
fractionnaires, presets disjoints, minimum inaccessible, scalers linéaires
hétérogènes, quadratique, égalité exacte contre excès d'un ULP, plateau
classique, plateau racine zéro avec run enfant `0/120/70`, replacement local,
sortie invalide atteinte seulement pendant la projection, coalescence de zone
et domaine virtuel d'environ mille milliards de candidats. Ce dernier reste
sous 200 appels publics au scaler, sans seuil mural.

`test/group_test.dart` couvre le transfert `didUpdateWidget`, notamment entre
contrôleurs égaux mais non identiques, la variation de rapport après transfert,
le passage à `group: null`, le changement de domaine et de scaler sans
duplication de membre, la remontée après retrait du minimum, le dispose avant
notification et la frame témoin stable. `test/group_builder_test.dart`
verrouille l'identité du groupe. `test/preset_font_sizes_test.dart` verrouille
les domaines disjoints et l'immuabilité des listes. `test/text_scaler_test.dart`
conserve le groupe homogène historique et attend désormais que les membres
hétérogènes restent chacun dans leur domaine.

## Matrice verte finale

Toolchains exactes :

```text
Flutter 3.41.0 • revision 44a626f4f0 • engine cc8e596aa65130a0678cc59613ed1c5125184db4 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • engine 1cf1c4773fb941c4c74a7f8bb144a8837596c0f4 • Dart 3.13.2
```

### Flutter 3.47.2

| Commande | Résultat |
|---|---|
| `flutter pub get --no-example` | succès |
| exemple : `flutter pub get --enforce-lockfile` | succès, lock canonique inchangé |
| `dart format --output=none --set-exit-if-changed lib test example` | 26 fichiers, 0 changement |
| `flutter analyze --no-pub --fatal-infos --fatal-warnings lib test` | aucun diagnostic |
| exemple : même analyse fatale | aucun diagnostic |
| ciblés groupes/presets/scalers/rich/replacement/lifecycle/leak | 61/61 |
| `flutter test --no-pub --reporter compact` | 115/115 |
| probe privé schedule/run/callback | `1/1/1` par membre et par époque stable |

La commande ciblée exacte portait sur :

```text
test/group_constraints_test.dart test/group_test.dart
test/group_builder_test.dart test/preset_font_sizes_test.dart
test/text_scaler_test.dart test/rich_text_test.dart
test/overflow_replacement_test.dart test/text_painter_lifecycle_test.dart
test/leak_tracking_test.dart
```

### Flutter 3.41.0

La tête a été extraite sans `.git` dans un répertoire temporaire. Le lock
d'exemple canonique haute a été déplacé dans cette extraction avant la
résolution naturelle minimale, conformément à la politique de lock. Aucun lock
du worktree n'a changé.

| Commande | Résultat |
|---|---|
| racine : `flutter pub get --no-example` | succès, 26 dépendances |
| exemple sans lock : `flutter pub get` | succès, 10 dépendances |
| analyse fatale `lib test` | aucun diagnostic |
| exemple : analyse fatale | aucun diagnostic |
| mêmes ciblés | 61/61 |
| suite complète avant downgrade | 115/115 |
| `flutter pub downgrade --no-example` | succès, 9 dépendances abaissées |
| suite complète après downgrade `--no-pub` | 115/115 |
| probe privé schedule/run/callback | `1/1/1` par membre et par époque stable |

Les deux extractions de rouge, l'extraction minimale et celle du probe ont été
supprimées après usage. Le ciblage explicite lifecycle/leak représente 9/9
tests et n'a signalé ni painter orphelin ni callback après dispose.

## Commits

- `1ef0f8f` — `test: specify heterogeneous group projection` ;
- `c2b7825` — `fix: project heterogeneous group constraints` ;
- `06f0326` — `test: strengthen zero plateau group oracle` ;
- `b7bd149` — `docs: record lot 5 implementation evidence` ;
- `8505ee6` — `test: cover group report retention and identity` ;
- `713be70` — `fix: compare group controllers by identity` ;
- commit suivant — mise à jour du journal après revue.

## Limites et risques transmis

- la dichotomie suppose, comme le contrat, un fit local monotone et un scaler
  monotone non décroissant ; aucun comportement n'est promis pour un scaler
  fini mais non monotone ;
- l'impossibilité pour un domaine d'atteindre `G` est une divergence locale
  volontaire : son minimum peut avoir une taille effective supérieure à `G` ;
- une erreur de projection n'annule pas une publication finie antérieure ;
  cette frontière est testée et documentée ;
- aucun hook privé permanent n'a été ajouté pour compter les callbacks. Le
  compteur schedule/run reste dans le test, tandis que les callbacks ont été
  prouvés sur les deux pins par le probe retiré et par les locks lifecycle ;
- la démo appartient au lot 6 et n'est pas incluse dans les analyses de ce lot ;
  le package et l'exemple canonique sont tous deux analysés fatalement ;
- une première invocation haute `--no-pub`, écartée des gates, avait réutilisé
  un `package_config` du pin minimal et produit un mismatch de SDK. Toutes les
  commandes archivées ci-dessus ont été rejouées après la résolution propre de
  chaque pin ;
- aucun merge, push, tag, `pub publish`, changement distant ou fichier
  temporaire n'est conservé.
