# Contre-revue indépendante — lot 5, état et cycle de vie des groupes

Date : 2026-09-01

Branche revue : `codex/review-groups-lifecycle`

Tête revue : `b32100fc1763266211d90748be61e7ed736c4101`

Parent produit du lot : `c9a1adc006365feb3e1750069ca1e115c3f20237`

## Verdict

**ACCEPTÉ**

Aucun finding bloquant ou actionnable n'a été trouvé dans l'état, la
coalescence, la convergence ou le cycle de vie du lot 5.

Le marqueur pending est posé avant la planification et consommé au début du
run. Les changements synchrones de `G` sont réellement coalescés en une seule
tâche planifiée et exécutée. Le snapshot est construit avec les membres
courants au moment du run, puis chaque membre est encore revalidé dans la map
et par `mounted` immédiatement avant son callback.

Le retrait précède le recalcul et la notification. Un état transféré ou
détaché ne reçoit donc aucun callback de son ancien groupe, même lorsqu'une
vague y est déjà pending et qu'il reste monté ailleurs. Un état disposé ne
reste ni dans la map, ni dans un snapshot capturé à la planification, ni dans
une closure membre. Les survivants remontent après une seule vague, sans
`setState` tardif ni fuite observée.

Enfin, `_publishedEffectiveFontSize` reste distinct du candidat rendu. Une
notification de projection recalcule `L` mais n'écrit ni `R`, ni `U(R)`. À
entrées et appartenance stables, la frame de synchronisation ne change donc ni
les rapports, ni `G`, et ne peut pas ouvrir une seconde vague.

## Findings ordonnés

Aucun.

## Vérification indépendante du modèle d'état

La contre-revue a suivi séparément les quatre quantités de l'oracle :

```text
L = candidat logique local issu du fit réel
P = U.scale(L), seul rapport publié
G = minimum courant des P des membres inscrits
R = projection rendue dans le domaine propre, jamais publiée
```

Les transitions suivantes ont été vérifiées dans le code et par probes privés
temporaires :

| Transition | Preuve indépendante |
|---|---|
| Publication synchrone `10/20 -> 30/40` | Deux écritures de rapport et deux changements successifs du minimum donnent exactement `1 schedule`, `1 run` et un callback pour chacun des trois membres courants. La frame de synchronisation puis la frame témoin n'ajoutent aucun événement. |
| Snapshot au run | Un membre inscrit après l'appel réel à `scheduleMicrotask`, mais avant son exécution, apparaît exactement une fois dans les callbacks. Il serait absent d'un snapshot capturé à la planification. |
| Revalidation par membre | Le probe retire un second membre monté après la création du snapshot mais pendant le premier callback. Le second membre n'est pas rappelé. |
| Transfert `g1 -> g2` avec vagues coalescées | Le membre mobile ne reçoit aucun callback de `g1`, reçoit celui de `g2` lorsqu'il y est encore inscrit, et les survivants de chaque groupe sont rappelés une seule fois. |
| Passage `g2 -> null` pendant une époque pending | Le retrait et les variations synchrones de `G2` partagent une vague. Le membre mobile n'est pas rappelé ; les deux survivants le sont. |
| Dispose avant microtâche | Le minimum est retiré avant le run. La trace contient un retrait, un schedule, un run, un seul callback survivant et zéro callback pour l'état disposé. `tester.takeException()` reste nul. |
| `didUpdateWidget`, même groupe | Une configuration invalide avant le nouveau `P` conserve l'ancien rapport fini 20, sans retrait, inscription, écriture ou notification. Le survivant reste projeté à 20. Après récupération à `P=30`, il y a une écriture, une vague et deux callbacks. |
| `AutoSizeGroupBuilder` | L'instance `final _group` reste identique à travers les rebuilds et une remontée. |
| Presets disjoints et frames témoins | Le résultat reste `20/30`. Un rebuild explicite, la frame de synchronisation et la frame témoin n'écrivent aucun rapport et ne laissent aucune frame programmée. |

Le cas du snapshot au run emploie volontairement un hook privé temporaire
placé après l'appel à `scheduleMicrotask`. Il distingue ainsi le moment exact
de capture ; une simple observation des tailles ou d'une frame visible ne le
pourrait pas.

## Probes et mutants

Le probe temporaire instrumentait séparément `register`, `report`, `remove`,
`schedule`, `run` et `callback`, en conservant l'identité du groupe et du
membre. Le test de coalescence ajoutait un `ZoneSpecification` indépendant
pour compter aussi les vraies microtâches planifiées et exécutées depuis
`auto_size_group.dart`.

Les sept scénarios du probe sont passés sur les deux SDK exacts :

| SDK | Révision Flutter | Dart | Probe |
|---|---|---|---|
| Flutter 3.41.0 | `44a626f4f0` | 3.11.0 | 7/7 |
| Flutter 3.47.2 | `d3b14c8769` | 3.13.2 | 7/7 |

Cinq mutants indépendants ont ensuite été appliqués un par un, rendus rouges,
puis restaurés immédiatement :

| Mutant temporaire | Échec discriminant observé |
|---|---|
| Supprimer la garde `_notificationPending` | `schedule=2` au lieu de 1 pour une seule frame de publication. |
| Capturer les listeners à la planification | Le membre ajouté avant le run reçoit 0 callback au lieu de 1. |
| Supprimer `_listeners.containsKey(textState)` avant callback | Deux callbacks sont émis au lieu d'un après le retrait du second membre monté depuis le snapshot. |
| Republier explicitement `U(R)` | Les presets disjoints convergent vers le mauvais point fixe `10/10`; le second membre vaut 10 au lieu de 30. |
| Retirer/réinscrire lors d'un `didUpdateWidget` dans le même groupe | Une mise à jour invalide fait remonter le survivant de 20 à 40 au lieu de conserver le dernier rapport fini. |

Ces rouges montrent que les probes testent le mécanisme réel, et pas seulement
des frames idempotentes ou le comportement du harness. Tous les hooks, helpers,
mutants et le fichier de probe ont été supprimés avant la matrice officielle.
Aucune API, instrumentation ou modification produit temporaire n'est conservée.

## Convergence, callbacks tardifs et ressources

Après la dernière publication pertinente d'une époque stable :

1. une seule microtâche consomme le pending ;
2. les membres inscrits et montés reçoivent chacun un seul `setState` ;
3. une seule frame rend la projection du dernier `G` ;
4. le cache du dernier `P` empêche toute écriture issue de `R` ;
5. la frame témoin ne planifie ni tâche, ni frame supplémentaire.

Le transfert ne transporte pas de rapport : l'ancien groupe retire d'abord le
membre, le nouveau l'inscrit à `+infinity`, puis le build courant publie son
nouveau `P`. Le passage à `null` retire le rapport avant le rendu local. Dans
le même groupe, le rapport n'est pas remis à `+infinity` pendant
`didUpdateWidget`; une erreur avant la prochaine publication ne fait donc pas
remonter les voisins à tort.

Le retrait du dernier minimum programme au plus une vague pour les survivants.
Si le groupe devient vide, `_scheduleNotification` n'ajoute aucune nouvelle
tâche ; une éventuelle tâche déjà pending ne capture aucun état membre et son
snapshot au run est vide. Les tests lifecycle avec leak tracking n'ont signalé
ni `TextPainter` orphelin, ni callback après dispose, ni exception de teardown.

## Matrice exécutée sur l'arbre propre

### Flutter 3.47.2 / Dart 3.13.2

| Commande | Résultat |
|---|---|
| `flutter pub get --no-example` | succès |
| `dart format --output=none --set-exit-if-changed lib test example` | 26 fichiers, 0 changement |
| `flutter analyze --no-pub --fatal-infos --fatal-warnings lib test` | aucun diagnostic |
| ciblés groupes, presets, scalers, RichText, replacement, lifecycle et leak | 60/60 |
| `flutter test --no-pub --reporter compact` | 114/114 |

### Flutter 3.41.0 / Dart 3.11.0

| Commande | Résultat |
|---|---|
| `flutter pub get --no-example` | succès |
| `flutter analyze --no-pub --fatal-infos --fatal-warnings lib test` | aucun diagnostic |
| mêmes ciblés | 60/60 |
| suite complète sur résolution naturelle | 114/114 |
| `flutter pub downgrade --no-example` | succès, 9 dépendances abaissées |
| suite complète après downgrade, `--no-pub` | 114/114 |

La suite ciblée exacte était :

```text
test/group_constraints_test.dart
test/group_test.dart
test/group_builder_test.dart
test/preset_font_sizes_test.dart
test/text_scaler_test.dart
test/rich_text_test.dart
test/overflow_replacement_test.dart
test/text_painter_lifecycle_test.dart
test/leak_tracking_test.dart
```

## Périmètre lu intégralement

Le diff complet du lot, `c9a1adc..b32100f`, et chacun de ses onze fichiers ont
été lus intégralement :

- `lib/src/auto_size_group.dart` ;
- `lib/src/auto_size_text.dart` ;
- `lib/src/auto_size_text_layout.dart` ;
- `maintenance/decisions/group-lifecycle-adversarial-oracle.md` ;
- `maintenance/implementation/lot-5-groups.md` ;
- `maintenance/reviews/group-lifecycle-adversarial-oracle-review.md` ;
- `test/group_builder_test.dart` ;
- `test/group_constraints_test.dart` ;
- `test/group_test.dart` ;
- `test/preset_font_sizes_test.dart` ;
- `test/text_scaler_test.dart`.

Ont aussi été lus intégralement pour le contrat ou les vérifications croisées :

- `maintenance/decisions/group-projection-oracle.md` ;
- `maintenance/implementation-roadmap.md` ;
- `lib/auto_size_text.dart` et `lib/src/auto_size_group_builder.dart` ;
- `test/text_painter_lifecycle_test.dart`, `test/leak_tracking.dart`,
  `test/leak_tracking_test.dart`, `test/flutter_test_config.dart` et
  `test/utils.dart` ;
- les skills `find-bugs` et `developing-flutter`, avec l'intégralité des cinq
  références Flutter liées.

Aucun `AGENTS.md` additionnel n'est présent dans ce worktree. Les instructions
PostHog fournies au chantier ne s'appliquent pas à cette revue locale.

## Audit pré-conclusion

La surface modifiée ne traite aucun input réseau, requête de base de données,
authentification, autorisation, session, appel externe ou opération
cryptographique. Injection, XSS, CSRF, IDOR, secrets et fuite d'information ne
sont donc pas applicables.

Les éléments applicables de la checklist ont été vérifiés pour chacun des onze
fichiers du lot :

- **courses et état** : coalescence réelle schedule/run/callback, ordre
  retrait/recalcul/notification, pending consommé avant snapshot et limite lue
  au build courant ;
- **cycle de vie** : inscription initiale, même groupe, transfert, `null`,
  retrait, dispose et builder stable ;
- **logique métier** : séparation `L/P/G/R`, publication locale uniquement,
  invalides non transactionnels et remontée du minimum ;
- **disponibilité** : projection logarithmique et aucune nouvelle opération
  non bornée ; le recalcul du minimum reste `O(M)` comme prévu ;
- **ressources** : aucun painter supplémentaire dans la projection, painters
  existants libérés dans `finally`, aucun état démonté rappelé ;
- **qualité des tests** : probes capables de tuer cinq mutants, compteurs de
  phase séparés et frames témoins explicites.

Aucune zone du périmètre demandé n'est restée non vérifiée. La seule limite est
intentionnelle : les hooks privés de phase sont des probes de revue retirés et
ne deviennent pas une API permanente. Le code produit final, les tests
permanents et le worktree ont été revérifiés sans ces hooks.
