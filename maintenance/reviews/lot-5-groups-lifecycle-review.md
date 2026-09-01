# Contre-revue indépendante — lot 5, état et cycle de vie des groupes

Date : 2026-09-01

Branche revue : `codex/review-groups-lifecycle`

Tête revue : `85771f62de815fb8712bc766fd5ede3129c63dd7`

Parent produit du lot : `c9a1adc006365feb3e1750069ca1e115c3f20237`

Corrections revalidées : `74501688d4c86131478cf62353a59f41cfdf855d`,
`2c3fc9076e4f1dbab789a1135b7506b65e8d04f0` et
`f52e0b700814497f5b86068160867146e3215923`. Oracle strict final :
`60d1dbfac69367137e90be206002a34ff115f662` et
`85771f62de815fb8712bc766fd5ede3129c63dd7`.

## Verdict

**CHANGEMENTS REQUIS**

Aucun défaut produit n'a été trouvé dans l'état, la coalescence, la convergence
ou le cycle de vie du lot 5. L'oracle strict tue bien le rollback complet sur
les deux SDK. Il reste toutefois un finding test-only : ses pompes explicites
masquent l'absence de la vague de retrait, de sorte que l'assertion finale de
frame ne prouve pas la frame intermédiaire qu'elle consomme.

Le passage de `oldWidget.group != widget.group` à
`!identical(oldWidget.group, widget.group)` ferme bien le défaut :
`AutoSizeGroup` est sous-classable et deux contrôleurs distincts peuvent être
égaux par `==` sans représenter la même appartenance. Le transfert se déclenche
désormais pour ces deux identités, tandis qu'une mise à jour sur la même
instance ne retire pas le membre et conserve son dernier `P` fini.

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

### [P2] L'oracle strict ne verrouille pas la frame de remontée qu'il consomme

- **Fichier :** `test/group_constraints_test.dart:636`.
- **Sévérité :** moyenne, test-only. Le produit intact est correct et le lock
  lifecycle voisin couvre déjà la régression.
- **Problème :** après le retrait du limiteur, le test appelle deux fois
  `tester.pump()` sans vérifier qu'une frame a réellement été programmée entre
  les deux. L'observateur vaut déjà 50 avant le retrait ; si `_remove` ne
  programme aucun callback, le second pump forcé ne le reconstruit pas, mais
  les attentes `observer == 50` et `hasScheduledFrame == false` restent vertes.
- **Preuve :** le mutant temporaire supprimant uniquement
  `_scheduleNotification()` dans `_remove` laisse cet oracle vert sur Flutter
  3.41.0 et 3.47.2. Sur les mêmes pins, le lock
  `should raise the limit once and ignore a member disposed before notify`
  devient rouge avec `Expected: 40, Actual: 20.0`. Le probe de la séquence
  intacte trace `remove, schedule, run, callback, callback`, puis observe
  `hasScheduledFrame == true` avant la frame de synchronisation.
- **Correction attendue :** après le premier pump qui retire B et consomme la
  microtâche, ajouter `expect(tester.binding.hasScheduledFrame, isTrue)` avant
  le pump de synchronisation. Conserver l'attente finale à `false` pour
  interdire une republication ou une frame résiduelle.

## Sanity de l'oracle strict

Le nouvel ordre black-box est discriminant pour la rétention : C, de domaine
`{70,50}`, est construit avant A ; A reste inchangé ; seul B, qui impose
`G=25`, est retiré dans son propre `StatefulBuilder`. La frame de
synchronisation construit donc C avant qu'un A réinitialisé puisse republier.

Un rollback complet temporaire — retrait, réinscription et remise à `null` de
`_publishedEffectiveFontSize` lors de l'erreur — rend C à 70 au lieu de 50 sur
les deux SDK. Le produit intact rend 50 et ne laisse aucune frame résiduelle.
Le placement des enfants tue donc bien le mutant qui échappait au premier
renforcement.

Le probe de phase retiré confirme aussi que l'exécution intacte ne masque pas
le comportement produit : le retrait donne exactement un schedule, un run et
deux callbacks vers les deux membres restants ; cette microtâche laisse une
frame programmée, puis la frame de synchronisation n'écrit aucun rapport et la
frame témoin est stable. Le finding ci-dessus porte uniquement sur la capacité
de la régression black-box permanente à rendre rouge l'absence de cette vague.

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
| Transfert `g1 -> g2` entre contrôleurs égaux mais non identiques | Le membre mobile est retiré de `g1`, inscrit à `+infinity` dans `g2`, y republie `P=20`, ne reçoit aucun callback de `g1` et reçoit exactement celui de `g2`. Les tailles passent à `20/40/20`. |
| Transition de `P` après transfert | Sans nouveau changement d'appartenance, `P=20 -> 30` produit une écriture, un schedule, un run et deux callbacks dans `g2`; les tailles restent `30/40/20` selon les domaines. |
| Passage `g2 -> null` pendant une époque pending | Le retrait et la remontée de `G2` partagent une vague. Le membre mobile n'est pas rappelé ; le survivant l'est une fois et remonte à 40. |
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

La contre-revue initiale avait sept scénarios. La revalidation corrective a
ajouté cinq probes indépendants centrés sur les groupes égaux : transfert puis
`null`, variation de `P` sans changement d'identité, rétention après erreur,
snapshot/revalidation, dispose et compteur microtask/frame. Les deux séries
sont passées sur les deux SDK exacts :

| SDK | Révision Flutter | Dart | Initial | Revalidation corrective |
|---|---|---|---|---|
| Flutter 3.41.0 | `44a626f4f0` | 3.11.0 | 7/7 | 5/5 |
| Flutter 3.47.2 | `d3b14c8769` | 3.13.2 | 7/7 | 5/5 |

Huit mutants indépendants ont ensuite été appliqués un par un, rendus rouges,
puis restaurés immédiatement :

| Mutant temporaire | Échec discriminant observé |
|---|---|
| Restaurer `oldWidget.group != widget.group` | La régression permanente obtient `20/20/40` au lieu de `20/40/20` lors du transfert entre contrôleurs égaux. |
| Supprimer la garde `_notificationPending` | `schedule=2` au lieu de 1 pour une seule frame de publication. |
| Capturer les listeners à la planification | Le membre ajouté avant le run reçoit 0 callback au lieu de 1. |
| Supprimer `_listeners.containsKey(textState)` avant callback | Le membre monté mais retiré après le premier callback est rappelé à tort depuis le snapshot. |
| Republier explicitement `U(R)` | Les presets disjoints convergent vers le mauvais point fixe `10/10`; le second membre vaut 10 au lieu de 30. |
| Retirer/réinscrire lors d'un `didUpdateWidget` dans le même groupe | Une mise à jour invalide fait remonter le survivant de 20 à 40 au lieu de conserver le dernier rapport fini. |
| Retirer/réinscrire lors d'une erreur atteinte après publication, cache conservé | Le premier témoin `{70,50}` rend 70 au lieu de 50 après retrait du limiteur. |
| Rollback complet du rapport et du cache publié | Le nouvel ordre strict rend 70 au lieu de 50 sur les deux pins avant qu'A puisse republier. |

Ces rouges montrent que les probes testent le mécanisme réel, et pas seulement
des frames idempotentes ou le comportement du harness. Tous les hooks, helpers,
mutants et le fichier de probe ont été supprimés avant la matrice officielle.
Aucune API, instrumentation ou modification produit temporaire n'est conservée.

Le neuvième mutant, qui supprime seulement la notification de retrait, est le
contre-exemple du finding : l'oracle strict reste vert, mais le lock lifecycle
permanent devient rouge sur les deux SDK. La suite complète ne masque donc pas
la régression produit ; seule la responsabilité locale du nouvel oracle reste
à verrouiller.

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

Cette frontière repose exclusivement sur l'identité. L'audit de toutes les
occurrences de `group` n'a trouvé aucune autre comparaison
contrôleur-à-contrôleur : `initState` inscrit l'instance reçue, `dispose` retire
de cette même instance, et `AutoSizeGroupBuilder` conserve son champ
`final _group` pendant toute la vie du `State`.

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
| ciblés groupes, presets, scalers, RichText, replacement, lifecycle et leak | 61/61 |
| `flutter test --no-pub --reporter compact` | 115/115 |

### Flutter 3.41.0 / Dart 3.11.0

| Commande | Résultat |
|---|---|
| `flutter pub get --no-example` | succès |
| `flutter analyze --no-pub --fatal-infos --fatal-warnings lib test` | aucun diagnostic |
| mêmes ciblés | 61/61 |
| suite complète sur résolution naturelle | 115/115 |

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
été lus intégralement lors de la contre-revue initiale :

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

Le diff correctif complet, `c6c96da..f52e0b`, et ses quatre fichiers ont été
relus intégralement pour cette revalidation :

- `lib/src/auto_size_text.dart` ;
- `test/group_test.dart` ;
- `test/group_constraints_test.dart` ;
- `maintenance/implementation/lot-5-groups.md`.

Le diff d'oracle strict, `8054bf8..85771f6`, et ses deux fichiers ont ensuite
été relus intégralement :

- `test/group_constraints_test.dart` ;
- `maintenance/implementation/lot-5-groups.md`.

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
fichiers du lot et des quatre fichiers du diff correctif :

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
- **qualité des tests** : rollback complet tué, huit mutants rouges dans leur
  oracle, et un neuvième mutant révélant que la présence de la frame de retrait
  n'est pas assertée localement ; compteurs de phase séparés et frames témoins
  explicites.

Aucune zone du périmètre demandé n'est restée non vérifiée. Les hooks privés de
phase restent des probes de revue retirés et ne deviennent pas une API
permanente. Le code produit final, les tests permanents et le worktree ont été
revérifiés sans ces hooks. La seule action restante est l'assertion de frame
intermédiaire décrite dans le finding P2.
