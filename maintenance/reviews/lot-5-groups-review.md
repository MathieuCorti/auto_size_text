# Revue indépendante du lot 5 — groupes hétérogènes

Date : 2026-09-01

Branche revue : `codex/review-groups`

Parent produit exact S5 : `c9a1adc006365feb3e1750069ca1e115c3f20237`

Candidat initial : `b32100fc1763266211d90748be61e7ed736c4101`

Correctifs contre-revus :

- `b159cc5` — régressions de rétention et d'identité ;
- `cbd3641` — comparaison des contrôleurs par identité ;
- `5d3fb6a5585921dabd134b0c8a5f1ff87d4b897e` — journal corrigé.

Plages revues : `c9a1adc..b32100f`, puis `fb306d0..5d3fb6a`

Périmètre : unités logique/effective `L/P/G/R`, projection dans le domaine de
chaque membre, scalers linéaires/non linéaires/plateaux, replacement, erreurs,
publication, `didUpdateWidget`, transfert/retrait/dispose, coalescence de
microtâches, ordre de layout, convergence, complexité, compatibilité des lots
2 à 4 et qualité des preuves rouges/vertes. La première revue puis la
contre-revue n'ont écrit aucun correctif produit ou test ; le présent rapport
mis à jour est leur seul livrable.

## Verdict

**CHANGEMENTS REQUIS.**

Le chemin produit nominal respecte l'oracle : chaque membre publie
`P_i = U_i(L_i)`, le groupe calcule `G = min(P_i)`, puis le rendu projette le
plus grand candidat de son domaine qui respecte `candidate <= L_i` et
`U_i(candidate) <= G`. Les domaines disjoints, minima inaccessibles, scalers
non linéaires, plateaux, remplacement local, valeurs invalides, suppression,
dispose et coalescence passent sur les deux SDK exacts. La recherche reste
logarithmique et ne matérialise pas les grandes grilles.

Le P2 produit est clos : `didUpdateWidget` compare les contrôleurs avec
`identical`, et sa régression couvre transfert, transition ultérieure,
assertions et frame témoin sur les deux SDK. Le P1 de preuve reste en revanche
ouvert. Le test renforcé tue le rollback partiel qui conserve le cache, mais un
rollback transactionnel qui réinitialise à la fois le rapport et le cache
survit sur Flutter 3.41.0 et 3.47.2. L'exigence bloquante 10 de l'oracle n'est
donc toujours pas entièrement prouvée. Aucun P0, P2 restant ou P3 actionnable
n'a été trouvé.

## Statut des findings

### P1 ouvert — la récupération republie 50 avant l'observation du rollback

**Fichiers :**

- `test/group_constraints_test.dart:577-653` ;
- `maintenance/implementation/lot-5-groups.md:59-64` ;
- contrat : `maintenance/decisions/group-lifecycle-adversarial-oracle.md`,
  contrainte d'acceptation 10.

Le test initial publiait `P_A=50`, puis gardait un membre B dont l'unique
candidat publiait `P_B=25`. La projection de A rencontre ensuite `NaN` à 20 et
lève bien `ArgumentError`. Pour la récupération, le test remplace le scaler de
A par l'identité tout en laissant B dans le groupe, puis attend `R_A=20`.

Cette dernière valeur ne dépend pas de la conservation de `P_A`. Si le rapport
50 est correctement retenu, `G=min(50,25)=25` et A rend 20. Si l'exception
annule illégalement le rapport de A vers `+∞`, B impose encore
`G=min(+∞,25)=25` et A rend également 20. L'assertion est donc tautologique
pour la propriété qu'elle prétend établir. Le journal affirme à tort que ce
20 « permet » de prouver la rétention. C'était le P1 initial.

La revue a vérifié ce point avec une archive temporaire propre de `b32100f`.
Un mutant limité au bloc de projection exécutait, dans le `catch`,
`group._remove(this); group._register(this); rethrow;` sans réinitialiser le
cache `_publishedEffectiveFontSize`. Il remplaçait ainsi le rapport fini par
`+∞`, exactement en violation de l'oracle. Le test permanent inchangé est
resté vert :

```text
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --suppress-analytics --no-version-check test --no-pub \
  --reporter expanded test/group_constraints_test.dart \
  --plain-name 'should reject an invalid scaler result reached during projection'

1/1, All tests passed
```

Le correctif ajoute un troisième membre C de rapport 70 et de domaine
`{70,50}`, puis retire B et exige A=50/C=50. Il tue bien, sur les deux SDK, le
mutant partiel `_remove(this); _register(this); rethrow;` qui remplace le
rapport par `+∞` mais conserve `_publishedEffectiveFontSize=50` : le cache
empêche toute republication et C rend 70.

Cependant, le test rétablit d'abord le scaler de A :

```dart
update(() => scaler = TextScaler.noScaling);
await tester.pump();
// ...
update(() => showLimiter = false);
```

Cette reconstruction rend le témoin non discriminant pour un rollback
transactionnel complet. La contre-revue a utilisé dans le `catch` :

```dart
group._remove(this);
group._register(this);
_publishedEffectiveFontSize = null;
rethrow;
```

Au pump de récupération, A recalcule `P_A=50`, voit le cache nul et republie
50 avant le retrait de B. A et C rendent donc ensuite 50 exactement comme sur
le produit intact. Le test permanent final reste vert 1/1 avec ce mutant sous
Flutter 3.41.0 et 3.47.2. C'est un rollback naturel à tester : remettre le
rapport à `⊥` et invalider son cache sont les deux moitiés cohérentes d'une
annulation transactionnelle.

L'oracle ferme explicitement cette échappatoire : il demande de retirer le
voisin « sans reconstruire A avec une nouvelle configuration », puis
d'observer le rapport fini 50, ou d'utiliser un probe privé si la gestion de
`ErrorWidget` rend la preuve black-box trop fragile. Le journal affirme donc
encore une fermeture plus large que celle réellement obtenue.

**Impact :** une future implémentation de rollback complet passerait tous les
tests et pourrait être déclarée conforme, tout en effaçant illégalement le
rapport partagé au moment de l'exception.

**Correction attendue :** retirer B sans changer préalablement le scaler de A
et observer C avant toute republication possible de A, avec ordre de layout
contrôlé et sous-arbre du limiteur isolé. Une instrumentation privée temporaire
du coordinateur est préférable si ce montage dépend trop du scheduling. Le
gate doit tuer les deux mutants : cache conservé **et** cache réinitialisé.

Commandes exactes du mutant complet survivant :

```text
/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --suppress-analytics --no-version-check test --no-pub \
  --reporter expanded test/group_constraints_test.dart \
  --plain-name 'should reject an invalid scaler result reached during projection'

/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --suppress-analytics --no-version-check test --no-pub \
  --reporter expanded test/group_constraints_test.dart \
  --plain-name 'should reject an invalid scaler result reached during projection'
```

### P2 clos — transfert fondé sur l'identité des contrôleurs

**Fichiers :**

- `lib/src/auto_size_text.dart:250-258` ;
- effet observable dans `lib/src/auto_size_group.dart:9-20` ;
- régression dans `test/group_test.dart:214-292`.

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
contrôleur concurrente.

Commandes mutantes exactes :

```text
/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --suppress-analytics --no-version-check test --no-pub \
  --reporter expanded test/group_test.dart \
  --plain-name 'should transfer between equal groups using controller identity'

/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --suppress-analytics --no-version-check test --no-pub \
  --reporter expanded test/group_test.dart \
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
satisfait ces deux frontières. La preuve permanente ne tue toutefois que le
rollback qui oublie de réinitialiser le cache, conformément au P1 ouvert.

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
témoin ne planifie rien. Aucun painter ou ressource native supplémentaire
n'est possédé par le groupe.

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

## Matrice indépendante finale sur `5d3fb6a`

Toolchains exactes :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
```

### Flutter 3.47.2

Exécuté dans `/private/tmp/auto-size-text-review-groups` :

```text
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --suppress-analytics --no-version-check pub get --no-example

cd example
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --suppress-analytics --no-version-check pub get --enforce-lockfile
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --suppress-analytics --no-version-check analyze --no-pub \
  --fatal-infos --fatal-warnings

cd ..
/private/tmp/flutter-sdk-3.47.2/flutter/bin/cache/dart-sdk/bin/dart \
  format --output=none --set-exit-if-changed lib test example

/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --suppress-analytics --no-version-check analyze --no-pub \
  --fatal-infos --fatal-warnings lib test

/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --suppress-analytics --no-version-check test --no-pub --reporter compact \
  test/group_constraints_test.dart test/group_test.dart \
  test/group_builder_test.dart test/preset_font_sizes_test.dart \
  test/text_scaler_test.dart test/rich_text_test.dart \
  test/overflow_replacement_test.dart \
  test/text_painter_lifecycle_test.dart test/leak_tracking_test.dart

/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --suppress-analytics --no-version-check test --no-pub --reporter compact
```

Résultats : résolution racine et exemple réussies ; lock d'exemple inchangé ;
26 fichiers formatés sans changement ; analyses package/tests et exemple sans
diagnostic ; ciblés 61/61, dont neuf cas lifecycle/leak ; suite 115/115.

### Flutter 3.41.0

La tête a été extraite dans un répertoire temporaire sans `.git`. Le lock haut
de l'exemple a été mis de côté avant la résolution naturelle minimale.

```text
/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --suppress-analytics --no-version-check pub get --no-example

cd example
/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --suppress-analytics --no-version-check pub get
/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --suppress-analytics --no-version-check analyze --no-pub \
  --fatal-infos --fatal-warnings

cd ..
/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --suppress-analytics --no-version-check analyze --no-pub \
  --fatal-infos --fatal-warnings lib test

/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --suppress-analytics --no-version-check test --no-pub --reporter compact \
  test/group_constraints_test.dart test/group_test.dart \
  test/group_builder_test.dart test/preset_font_sizes_test.dart \
  test/text_scaler_test.dart test/rich_text_test.dart \
  test/overflow_replacement_test.dart \
  test/text_painter_lifecycle_test.dart test/leak_tracking_test.dart

/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --suppress-analytics --no-version-check test --no-pub --reporter compact

/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --suppress-analytics --no-version-check pub downgrade --no-example

/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --suppress-analytics --no-version-check test --no-pub --reporter compact
```

Résultats : 26 dépendances racine et 10 exemple résolues ; analyses sans
diagnostic ; ciblés 61/61 ; suite avant downgrade 115/115 ; neuf dépendances
abaissées ; suite après downgrade 115/115. Les cas lifecycle/leak sont inclus
à la fois dans les ciblés et dans les deux suites complètes.

Contrôles complémentaires :

```text
git diff --check fb306d0..5d3fb6a
git rev-parse HEAD
git branch --show-current
```

Résultat : diff propre ; tête exacte `5d3fb6a...` ; branche
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
DoS actionnable. La qualité de la preuve d'exception laisse le P1 ci-dessus
ouvert ; aucun autre finding n'est apparu. Aucune zone du diff n'est restée non
vérifiée.
