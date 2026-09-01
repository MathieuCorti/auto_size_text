# Revue indépendante du lot 5 — groupes hétérogènes

Date : 2026-09-01

Branche revue : `codex/review-groups`

Parent produit exact S5 : `c9a1adc006365feb3e1750069ca1e115c3f20237`

Candidat initial : `b32100fc1763266211d90748be61e7ed736c4101`

Correctifs contre-revus :

- `b159cc5` — régressions de rétention et d'identité ;
- `cbd3641` — comparaison des contrôleurs par identité ;
- `5d3fb6a5585921dabd134b0c8a5f1ff87d4b897e` — journal corrigé ;
- `581b8506797fed9ac17dd65dd49dbc6ed3463abf` — oracle strict de rétention ;
- `d1a5aae7d2cdd72a9ca465d8e81813c687423ac6` — journal strict ;
- `a2ead5194e46e33c7518b1de9f891351189095a4` — oracle de frame au retrait ;
- `1dc7a63e38da170c2456af5e16acb3a2227a1c86` — journal de frame.

Plages revues : `c9a1adc..b32100f`, `fb306d0..5d3fb6a`, puis
`22d0ce3..d1a5aae` et `fbedb50..1dc7a63`.

Périmètre : unités logique/effective `L/P/G/R`, projection dans le domaine de
chaque membre, scalers linéaires/non linéaires/plateaux, replacement, erreurs,
publication, `didUpdateWidget`, transfert/retrait/dispose, coalescence de
microtâches, ordre de layout, convergence, complexité, compatibilité des lots
2 à 4 et qualité des preuves rouges/vertes. Les revues n'ont écrit aucun
correctif produit ou test ; le présent rapport mis à jour est leur seul
livrable.

## Verdict

**ACCEPTÉ.**

Le chemin produit nominal respecte l'oracle : chaque membre publie
`P_i = U_i(L_i)`, le groupe calcule `G = min(P_i)`, puis le rendu projette le
plus grand candidat de son domaine qui respecte `candidate <= L_i` et
`U_i(candidate) <= G`. Les domaines disjoints, minima inaccessibles, scalers
non linéaires, plateaux, remplacement local, valeurs invalides, suppression,
dispose et coalescence passent sur les deux SDK exacts. La recherche reste
logarithmique et ne matérialise pas les grandes grilles.

Le P1 de preuve est désormais clos : le nouvel oracle garde A strictement
inchangé, retire seulement B et observe C avant toute republication possible
de A. Le rollback complet `_remove/_register` avec cache remis à `null`, vert
sur l'ancien test, devient rouge avec `C=70` au lieu de 50 sur Flutter 3.41.0
et 3.47.2. L'assertion ajoutée par `a2ead51` tue en outre le mutant qui
recalcule `G` au retrait mais ne planifie aucune notification : attendu
`hasScheduledFrame == true`, obtenu `false` sur les deux pins. Le P2 produit
reste clos : `didUpdateWidget` compare les contrôleurs avec `identical`, et sa
régression couvre transfert, transition ultérieure, assertions et frame témoin
sur les deux SDK. Aucun P0, P1 restant, P2 restant ou P3 actionnable n'a été
trouvé.

## Statut des findings

### P1 clos — le nouvel oracle observe le rapport avant republication

**Fichiers :**

- `test/group_constraints_test.dart:577-646` ;
- `maintenance/implementation/lot-5-groups.md:59-69` ;
- contrat : `maintenance/decisions/group-lifecycle-adversarial-oracle.md`,
  contrainte d'acceptation 10.

L'oracle initial publiait `P_A=50`, laissait B imposer `P_B=25`, puis
rencontrait `NaN` pendant la projection de A. Sa récupération changeait le
scaler de A avant de retirer B. Même après un rollback de A vers `+∞`, B
maintenait d'abord `G=25`, puis A republiait 50 : le résultat final ne prouvait
pas la rétention. Le premier renforcement ajoutait C de domaine `{70,50}` et
tuait un rollback partiel qui conservait le cache, mais pas une annulation
cohérente du rapport et du cache.

La contre-revue a donc utilisé exactement ce rollback complet dans le chemin
d'exception :

```dart
group._remove(this);
group._register(this);
_publishedEffectiveFontSize = null;
rethrow;
```

Dans une archive de `5d3fb6a`, l'ancien test reste vert 1/1 avec ce mutant sur
les deux SDK. Le test de `581b850` ne modifie plus A : l'observateur C et A
sont des enfants constants hors du `StatefulBuilder`; son unique `setState`
remplace seulement B par `SizedBox.shrink`. C précède A dans le `Column`. Après
l'erreur, le rollback mutant laisse donc `{P_C=70, P_A=+∞}` quand B est retiré.
À la frame discriminante, C rend 70 avant qu'A puisse republier 50. Le produit
intact conserve `P_A=50`, et C rend 50.

Le test consomme explicitement l'`ArgumentError` attendu après la première
pompe, exige ensuite deux fois l'absence d'exception, puis vérifie C et
`hasScheduledFrame == false`. Avec le mutant, le seul échec est l'attente de C,
`Expected: 50, Actual: 70.0`, sur les deux pins. Il n'y a ni exception
incontrôlée ni frame différée qui masque la preuve.

Commandes exactes, exécutées après `flutter pub get --no-example` dans chaque
archive :

```text
cd /private/tmp/auto-size-groups-old-PROHVi
/Users/mathieu/fvm/versions/3.41.0/bin/flutter test --no-pub \
  test/group_constraints_test.dart \
  --plain-name 'should reject an invalid scaler result reached during projection'

/Users/mathieu/fvm/versions/3.47.2/bin/flutter test --no-pub \
  test/group_constraints_test.dart \
  --plain-name 'should reject an invalid scaler result reached during projection'

cd /private/tmp/auto-size-groups-new-dKILp1
/Users/mathieu/fvm/versions/3.41.0/bin/flutter test --no-pub \
  test/group_constraints_test.dart \
  --plain-name 'should reject an invalid scaler result reached during projection'

/Users/mathieu/fvm/versions/3.47.2/bin/flutter test --no-pub \
  test/group_constraints_test.dart \
  --plain-name 'should reject an invalid scaler result reached during projection'
```

Résultats avec le même mutant : ancien oracle `5d3fb6a`, 1/1 vert sur chaque
SDK ; oracle strict `d1a5aae`, rouge `C=70.0` contre 50 sur chaque SDK. Le
finding est clos sans modification produit.

La sanity lifecycle a vérifié la seconde faiblesse possible du même montage :
sans appel à `_scheduleNotification()` dans `_remove`, le retrait de B
recalcule bien `G=50`, mais C ne reçoit aucun `_notifySync`. Les deux pompes de
l'oracle précédent pouvaient forcer la frame suivante et masquer ce défaut.
`a2ead51` exige désormais `hasScheduledFrame == true` immédiatement après la
pompe qui retire B, avant toute pompe de synchronisation, puis conserve
l'attente finale à `false`.

Le mutant temporaire supprimait seulement la branche de planification de
`_remove`, en conservant suppression et recalcul. Le test devient rouge à la
nouvelle ligne 640 avec `Expected: true, Actual: false` sur les deux SDK, sans
autre échec :

```text
cd /private/tmp/auto-size-groups-noschedule-XToUng
/Users/mathieu/fvm/versions/3.41.0/bin/flutter test --no-pub \
  test/group_constraints_test.dart \
  --plain-name 'should reject an invalid scaler result reached during projection'

/Users/mathieu/fvm/versions/3.47.2/bin/flutter test --no-pub \
  test/group_constraints_test.dart \
  --plain-name 'should reject an invalid scaler result reached during projection'
```

Cette assertion verrouille la notification de retrait sans modifier le produit
ni affaiblir la preuve de rétention ; P1 reste clos.

### P2 clos — transfert fondé sur l'identité des contrôleurs

**Fichiers :**

- `lib/src/auto_size_text.dart:250-258` ;
- effet observable dans `lib/src/auto_size_group.dart:9-20` ;
- régression dans `test/group_test.dart:217-294`.

`AutoSizeGroup` est une classe publique sous-classable. Le candidat initial
utilisait :

```dart
if (oldWidget.group != widget.group) {
```

Deux instances distinctes d'une sous-classe qui redéfinit légalement `==`
peuvent donc comparer égales. Dans ce cas, l'état n'est ni retiré de l'ancien
groupe ni inscrit dans le nouveau, et le cache de publication n'est pas
réinitialisé.

Le probe temporaire utilisait deux `_EqualGroup` distincts dont `operator ==`
retourne vrai pour toute autre `_EqualGroup`. A, de rapport 20, passait de g1
contenant aussi B=40 vers g2 contenant C=40. Après deux pumps, le contrat de
transfert exige `A/B/C = 20/40/20`. Le candidat rendait
`20/20/40` sous Flutter 3.47.2 : A continuait à borner g1, tandis que g2 ne
contenait jamais son rapport. Commande exacte :

```text
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --suppress-analytics --no-version-check test --no-pub \
  --reporter expanded test/review_equal_group_probe_test.dart

Expected: 40
Actual:   20.0
```

À la prochaine variation de `P_A`, le build appelle en outre
`newGroup._updateFontSize(this, ...)` sans inscription préalable : l'assertion
`_listeners.containsKey(text)` peut lever en debug. Sans assertions, l'écriture
insère tardivement A dans g2 mais ne le supprime toujours pas de g1 ; l'ancien
groupe garde donc une contribution et des callbacks fantômes.

La comparaison par égalité était historique, mais le cache du lot 5 changeait le
mode d'échec : auparavant la publication systématique insérait au moins A dans
g2, tout en le laissant incorrectement dans g1 ; désormais une publication
inchangée est sautée et A n'appartient pas du tout au nouveau groupe. Le lot 5
modifiait donc matériellement cette interaction.

Le code corrigé utilise désormais
`if (!identical(oldWidget.group, widget.group))`, puis retire l'ancien rapport,
inscrit le membre dans le nouveau contrôleur et remet le cache à `null`. Le
test permanent crée deux `_EqualAutoSizeGroup` distincts qui comparent égaux.
Il exige après transfert `A/B/C=[20,40,20]`, puis change `P_A` à 30 et exige
`[30,40,20]`, aucune exception et aucune frame restante.

Ce test passe intégralement sous Flutter 3.41.0 et 3.47.2. Le mutant qui remet
`oldWidget.group != widget.group` échoue sur les deux avec
`Actual: [20,20,40]`. Un probe temporaire de contre-revue a accepté ce premier
état erroné pour atteindre la transition suivante : `_updateFontSize` lève
alors exactement l'assertion `_listeners.containsKey(text)`, confirmant que la
seconde moitié du test protège un mode d'échec distinct.

Une recherche exhaustive dans `lib` ne trouve aucune autre comparaison entre
deux contrôleurs. Les autres occurrences sont des gardes de nullité et des
tests de présence d'état dans la map ; elles ne consultent pas une égalité de
contrôleur concurrente. Le delta `fbedb50..1dc7a63` ne touche aucun fichier
produit ; la recherche finale retrouve toujours uniquement
`!identical(oldWidget.group, widget.group)`. Les ciblés 61/61 sur les deux SDK
rejouent le transfert, la transition ultérieure et les assertions sans échec.

Commandes mutantes exactes :

```text
cd /private/tmp/auto-size-groups-identity-gbULQe
/Users/mathieu/fvm/versions/3.41.0/bin/flutter test --no-pub \
  test/group_test.dart \
  --plain-name 'should transfer between equal groups using controller identity'

/Users/mathieu/fvm/versions/3.47.2/bin/flutter test --no-pub \
  test/group_test.dart \
  --plain-name 'should transfer between equal groups using controller identity'
```

## Audit fonctionnel du code produit

### Unités, domaines et replacement

`_calculateFontSize` renvoie le candidat local `L`, sa taille racine effective
`P=U(L)` et le booléen de fit local. La publication précède la projection et
n'est effectuée que lors d'une transition exacte de `P`. La projection
réutilise `_CandidateSet.findLargestThatFits`, court-circuite les candidats
au-dessus de `L`, puis compare exactement et inclusivement `U(candidate)` à
`G`. Elle ne tente ni inversion, ni interpolation, ni clamp étranger au
domaine.

Le minimum/petit preset est rendu lorsqu'aucun candidat ne satisfait la borne
effective. Cette divergence locale autorisée ne republie pas `R`. Le
`overflowReplacement` reste exclusivement fondé sur `result.fits`, donc sur le
fit local ; une projection basse ne masque pas un échec local et une limite de
groupe inaccessible ne crée pas artificiellement un replacement.

Les sorties de scaler utilisées pour `P` et pour chaque prédicat de projection
sont validées finies et non négatives, avec canonicalisation du seul zéro.
Une erreur avant publication conserve l'ancien rapport du même groupe ; une
erreur après publication conserve le nouveau rapport fini. Le code produit
satisfait ces deux frontières. L'oracle permanent strict tue désormais aussi
le rollback cohérent qui réinitialise le cache, conformément au P1 clos.

### État, microtâches et cycle de vie

Le groupe stocke un rapport par état, recalcule le minimum après écriture ou
suppression et ne planifie que si `G` change. `_notificationPending` est posé
avant `scheduleMicrotask`, ce qui coalesce les variations synchrones. Au run,
le code remet le marqueur à faux, capture les membres courants, puis revalide à
la fois leur présence dans la map et `mounted` avant chaque callback. Le
transfert nominal, le passage à `null`, le retrait du minimum et le dispose
avant notification ne laissent pas de callback tardif dans les tests.

La suppression du dernier membre ramène `G` à `+∞` sans tâche vide nouvelle ;
une tâche déjà pending se consomme sur les membres actuels. L'ordre de layout
peut donner des rendus intermédiaires différents pendant la frame de
publication, mais une vague unique synchronise ensuite l'état stable. La frame
témoin ne planifie rien. Le retrait discriminant exige maintenant une frame
pending avant synchronisation et aucune après stabilisation ; le mutant qui
omet la notification est donc rouge. Aucun painter ou ressource native
supplémentaire n'est possédé par le groupe.

### Complexité et interactions lots 2 à 4

Les presets restent des snapshots ascendants dédupliqués sans mutation de la
liste appelante. Les grilles gardent leur représentation virtuelle et leur
index exact ; la projection ajoute une seconde recherche `O(log C)`, y compris
sur environ mille milliards de candidats. Le groupe recalcule son minimum en
`O(M)`, coût explicitement admis par l'oracle sans heap auxiliaire.

Le scaler utilisateur reste composé par run au rendu et à la mesure ; la
projection ne lit pas `textScaleFactor`. Les arbres RichText, les overrides,
la référence zéro et les scalers à plateau continuent à rendre un vrai
candidat logique. Le plateau racine zéro vérifie une box de run indépendante,
pas seulement la taille de la racine. Aucune nouvelle mutation de span,
linéarisation, division par zéro ou prise en charge implicite de `WidgetSpan`
n'a été introduite.

## Preuves rouges sur le parent S5

Les tests finaux ont été superposés à une archive propre du parent exact
`c9a1adc`, sans modifier de commit ni de branche. Le fichier
`group_constraints_test.dart` est rouge sur ses 13 cas avec les deux SDK :

```text
Flutter 3.47.2 : 0 succès, 13 échecs
Flutter 3.41.0 : 0 succès, 13 échecs
```

Les écarts observés sont discriminants : `26 -> 30`, `.4 -> .45`, preset
disjoint `20 -> 30`, minimum inaccessible `20 -> 10`, mauvais domaine sous
scalers linéaires, quadratique `40 -> 50`, excès d'un ULP accepté, scaler
linéarisé sur plateau, plateau zéro `70 -> 0`, voisin replacement `20 -> 10`,
absence d'`ArgumentError`, coalescence `1/1 -> 2/2` et domaine géant
`49.9 -> 50`.

Commandes exactes :

```text
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --suppress-analytics --no-version-check test --no-pub \
  --reporter expanded test/group_constraints_test.dart

/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --suppress-analytics --no-version-check test --no-pub \
  --reporter compact test/group_constraints_test.dart
```

Les locks historiques n'ont pas été inversés artificiellement. Sur le parent,
les cas groupe homogène, transfert/détachement, retrait/dispose et les deux cas
du builder restent verts. Le nouveau cas de changement domaine+scaler est
rouge comme attendu. Sur Flutter 3.41.0, le sous-ensemble final
`group_test + group_builder_test + preset_font_sizes_test` donne 13 succès et
deux rouges exclusivement lot 5 : domaine+scaler et preset disjoint.

```text
/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --suppress-analytics --no-version-check test --no-pub \
  --reporter compact test/group_test.dart test/group_builder_test.dart \
  test/preset_font_sizes_test.dart
```

## Matrice indépendante finale sur `1dc7a63`

Toolchains exactes :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
engine cc8e596aa65130a0678cc59613ed1c5125184db4
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
engine 1cf1c4773fb941c4c74a7f8bb144a8837596c0f4
```

### Flutter 3.47.2

Exécuté dans `/private/tmp/auto-size-text-review-groups` :

```text
/Users/mathieu/fvm/versions/3.47.2/bin/flutter pub get --no-example

cd example
/Users/mathieu/fvm/versions/3.47.2/bin/flutter pub get --enforce-lockfile
/Users/mathieu/fvm/versions/3.47.2/bin/flutter analyze --no-pub \
  --fatal-infos --fatal-warnings

cd ..
/Users/mathieu/fvm/versions/3.47.2/bin/dart \
  format --output=none --set-exit-if-changed lib test example

/Users/mathieu/fvm/versions/3.47.2/bin/flutter analyze --no-pub \
  --fatal-infos --fatal-warnings lib test

/Users/mathieu/fvm/versions/3.47.2/bin/flutter test --no-pub \
  test/group_constraints_test.dart test/group_test.dart \
  test/group_builder_test.dart test/preset_font_sizes_test.dart \
  test/text_scaler_test.dart test/rich_text_test.dart \
  test/overflow_replacement_test.dart \
  test/text_painter_lifecycle_test.dart test/leak_tracking_test.dart

/Users/mathieu/fvm/versions/3.47.2/bin/flutter test --no-pub \
  test/text_painter_lifecycle_test.dart test/leak_tracking_test.dart

/Users/mathieu/fvm/versions/3.47.2/bin/flutter test --no-pub \
  --reporter compact
```

Résultats : résolution racine et exemple réussies ; lock d'exemple inchangé ;
26 fichiers formatés sans changement ; analyses package/tests et exemple sans
diagnostic ; ciblés 61/61 ; lifecycle/leak explicites 9/9 ; suite 115/115.

### Flutter 3.41.0

La tête a été extraite dans un répertoire temporaire sans `.git`. Le lock haut
de l'exemple a été mis de côté avant la résolution naturelle minimale.

```text
/Users/mathieu/fvm/versions/3.41.0/bin/flutter pub get --no-example

cd example
/Users/mathieu/fvm/versions/3.41.0/bin/flutter pub get
/Users/mathieu/fvm/versions/3.41.0/bin/flutter analyze --no-pub \
  --fatal-infos --fatal-warnings

cd ..
/Users/mathieu/fvm/versions/3.41.0/bin/flutter analyze --no-pub \
  --fatal-infos --fatal-warnings lib test

/Users/mathieu/fvm/versions/3.41.0/bin/flutter test --no-pub \
  test/group_constraints_test.dart test/group_test.dart \
  test/group_builder_test.dart test/preset_font_sizes_test.dart \
  test/text_scaler_test.dart test/rich_text_test.dart \
  test/overflow_replacement_test.dart \
  test/text_painter_lifecycle_test.dart test/leak_tracking_test.dart

/Users/mathieu/fvm/versions/3.41.0/bin/flutter test --no-pub \
  test/text_painter_lifecycle_test.dart test/leak_tracking_test.dart

/Users/mathieu/fvm/versions/3.41.0/bin/flutter test --no-pub \
  --reporter compact

/Users/mathieu/fvm/versions/3.41.0/bin/flutter pub downgrade --no-example

/Users/mathieu/fvm/versions/3.41.0/bin/flutter test --no-pub \
  --reporter compact
```

Résultats : 26 dépendances racine et 10 exemple résolues ; analyses sans
diagnostic ; ciblés 61/61 ; lifecycle/leak explicites 9/9 ; suite avant
downgrade 115/115 ; neuf dépendances abaissées ; suite après downgrade
115/115.

Contrôles complémentaires :

```text
git diff --check fbedb50..1dc7a63
git rev-parse HEAD
git branch --show-current
```

Résultat : diff propre ; tête exacte
`1dc7a63e38da170c2456af5e16acb3a2227a1c86` ; branche
`codex/review-groups`. Toutes les extractions parent/minimum, les mutants, les
tests de probe, les `.dart_tool`, builds et locks racine générés ont été
supprimés avant rédaction. Le lock d'exemple suivi n'a pas changé.

## Surface lue intégralement

Les 11 fichiers du diff ont été relus entièrement :

1. `lib/src/auto_size_group.dart` ;
2. `lib/src/auto_size_text.dart` ;
3. `lib/src/auto_size_text_layout.dart` ;
4. `maintenance/decisions/group-lifecycle-adversarial-oracle.md` ;
5. `maintenance/implementation/lot-5-groups.md` ;
6. `maintenance/reviews/group-lifecycle-adversarial-oracle-review.md` ;
7. `test/group_builder_test.dart` ;
8. `test/group_constraints_test.dart` ;
9. `test/group_test.dart` ;
10. `test/preset_font_sizes_test.dart` ;
11. `test/text_scaler_test.dart`.

La contre-revue a relu intégralement chacun des quatre fichiers du delta
`fb306d0..5d3fb6a` :

1. `lib/src/auto_size_text.dart` ;
2. `maintenance/implementation/lot-5-groups.md` ;
3. `test/group_constraints_test.dart` ;
4. `test/group_test.dart`.

La revalidation finale a relu intégralement les deux fichiers du delta strict
`22d0ce3..d1a5aae` :

1. `test/group_constraints_test.dart` ;
2. `maintenance/implementation/lot-5-groups.md`.

La sanity finale a relu intégralement les deux fichiers du delta test-only
`fbedb50..1dc7a63` :

1. `test/group_constraints_test.dart` ;
2. `maintenance/implementation/lot-5-groups.md`.

Le contexte directement interactif a également été lu intégralement :

- `lib/auto_size_text.dart`, `lib/src/auto_size_group_builder.dart` ;
- `maintenance/decisions/group-projection-oracle.md` ;
- `maintenance/implementation-roadmap.md` ;
- `maintenance/audits/core-audit.md`, `tooling-audit.md` et
  `upstream-issues-audit.md` ;
- les journaux des lots 2, 3 et 4 ;
- les oracles candidat, texte effectif, RichText et RichText adversarial.

Les instructions `find-bugs`, `developing-flutter`, `effective-dart`,
`testing`, `flutter-app-architecture` et l'`AGENTS.md` fourni ont été appliqués.

## Audit de surface et sécurité

Les seules entrées sont locales : propriétés de widget, styles, listes de
presets, scalers, contraintes de layout et identité de groupe. Les opérations
d'état sont la map de rapports, le cache de publication et la vague de
microtâche. Les seuls appels externes au package sont les API Flutter de texte,
layout et scheduling. Il n'existe aucune entrée réseau, requête de base de
données, authentification, autorisation, session, opération cryptographique ou
secret dans le diff.

Checklist complète : injection, XSS, authentification, autorisation/IDOR,
CSRF, session, cryptographie et divulgation d'information sont hors surface ;
aucun défaut applicable trouvé. Les races/TOCTOU ont été examinées sur
publication, coalescence, snapshot courant, transfert et dispose : le chemin
nominal est propre et le P2 d'identité est clos. La disponibilité a été
contrôlée par le domaine virtuel et la revue des allocations : aucun nouveau
DoS actionnable. La preuve d'exception stricte tue les rollbacks partiel et
complet, et l'assertion de frame tue l'omission de notification au retrait ; le
P1 est clos. Aucun autre finding n'est apparu. Aucune zone du diff n'est restée
non vérifiée.
