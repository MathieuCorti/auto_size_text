# Revue indépendante du lot 5 — groupes hétérogènes

Date : 2026-09-01

Branche revue : `codex/review-groups`

Parent produit exact S5 : `c9a1adc006365feb3e1750069ca1e115c3f20237`

Candidat revu : `b32100fc1763266211d90748be61e7ed736c4101`

Plage revue : `c9a1adc..b32100f`

Périmètre : unités logique/effective `L/P/G/R`, projection dans le domaine de
chaque membre, scalers linéaires/non linéaires/plateaux, replacement, erreurs,
publication, `didUpdateWidget`, transfert/retrait/dispose, coalescence de
microtâches, ordre de layout, convergence, complexité, compatibilité des lots
2 à 4 et qualité des preuves rouges/vertes. Aucun correctif produit ou test
permanent n'a été écrit par cette revue ; le présent rapport est son seul
livrable.

## Verdict

**CHANGEMENTS REQUIS.**

Le chemin produit nominal respecte l'oracle : chaque membre publie
`P_i = U_i(L_i)`, le groupe calcule `G = min(P_i)`, puis le rendu projette le
plus grand candidat de son domaine qui respecte `candidate <= L_i` et
`U_i(candidate) <= G`. Les domaines disjoints, minima inaccessibles, scalers
non linéaires, plateaux, remplacement local, valeurs invalides, suppression,
dispose et coalescence passent sur les deux SDK exacts. La recherche reste
logarithmique et ne matérialise pas les grandes grilles.

Deux findings restent toutefois ouverts :

- un P1 de preuve : la régression censée verrouiller la conservation du rapport
  après une exception de projection laisse survivre exactement le mutant de
  rollback interdit par l'oracle ;
- un P2 produit : un transfert entre deux contrôleurs distincts mais égaux au
  sens de `==` n'est pas détecté, ce qui laisse le membre dans l'ancien groupe
  et absent du nouveau.

Il n'y a aucun P0 ni autre P3 actionnable.

## Findings

### P1 — le test d'exception ne prouve pas la conservation non transactionnelle du rapport

**Fichiers :**

- `test/group_constraints_test.dart:577-631` ;
- `maintenance/implementation/lot-5-groups.md:59-64` ;
- contrat : `maintenance/decisions/group-lifecycle-adversarial-oracle.md`,
  contrainte d'acceptation 10.

Le test publie d'abord `P_A=50`, puis garde un membre B dont l'unique candidat
publie `P_B=25`. La projection de A rencontre ensuite `NaN` à 20 et lève bien
`ArgumentError`. Pour la récupération, le test remplace le scaler de A par
l'identité tout en laissant B dans le groupe, puis attend `R_A=20`.

Cette dernière valeur ne dépend pas de la conservation de `P_A`. Si le rapport
50 est correctement retenu, `G=min(50,25)=25` et A rend 20. Si l'exception
annule illégalement le rapport de A vers `+∞`, B impose encore
`G=min(+∞,25)=25` et A rend également 20. L'assertion est donc tautologique
pour la propriété qu'elle prétend établir. Le journal affirme à tort que ce
20 « permet » de prouver la rétention.

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

Un témoin discriminant temporaire a ajouté un troisième membre C avec
`P_C=70` et le domaine `{70,50}`. Après l'exception, il retire B et rétablit le
scaler valide de A. Le produit intact rend C à 50, car le rapport retenu de A
impose `G=50`. Le mutant rend C à 70, car A reste à `+∞`. Avec la même commande
ciblée, le produit a passé 1/1 et le mutant a échoué avec
`Expected: 50, Actual: 70`.

**Impact :** l'exigence bloquante 10 n'est pas protégée. Une future tentative
de rollback, ou une régression qui réinscrit le membre à `⊥`, passerait la suite
et pourrait être déclarée conforme alors qu'elle change l'état partagé après
exception.

**Correction attendue :** conserver une régression permanente à trois membres
ou un observateur équivalent. Après l'exception, retirer le membre qui impose
25 et vérifier indépendamment que le groupe reste borné à 50. Le test doit
échouer si le rapport est supprimé, remis à `⊥` ou remplacé par une valeur
dérivée de `R`. Corriger en même temps la justification du journal. Aucun
changement du code produit actuel n'est nécessaire pour ce finding.

### P2 — `didUpdateWidget` confond égalité et identité des contrôleurs

**Fichiers :**

- `lib/src/auto_size_text.dart:250-258` ;
- effet observable dans `lib/src/auto_size_group.dart:9-20` ;
- absence de cas discriminant dans `test/group_test.dart:120-207`.

`AutoSizeGroup` est une classe publique sous-classable. Pourtant,
`didUpdateWidget` utilise :

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

La comparaison par égalité est historique, mais le cache du lot 5 change le
mode d'échec : auparavant la publication systématique insérait au moins A dans
g2, tout en le laissant incorrectement dans g1 ; désormais une publication
inchangée est sautée et A n'appartient pas du tout au nouveau groupe. Le lot 5
modifie donc matériellement cette interaction.

**Correction attendue :** comparer les contrôleurs par identité :
`if (!identical(oldWidget.group, widget.group))`, puis conserver le retrait,
l'inscription et la remise à `null` du cache dans cette branche. Ajouter une
régression avec deux contrôleurs distincts mais `==`, et vérifier transfert,
variation ultérieure de `P`, absence de callback de l'ancien groupe et absence
d'exception.

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
satisfait ces deux frontières, sous réserve du P1 qui concerne leur preuve
permanente.

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

## Matrice indépendante sur `b32100f`

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
diagnostic ; ciblés 60/60, dont neuf cas lifecycle/leak ; suite 114/114.

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
diagnostic ; ciblés 60/60 ; suite avant downgrade 114/114 ; neuf dépendances
abaissées ; suite après downgrade 114/114. Les cas lifecycle/leak sont inclus
à la fois dans les ciblés et dans les deux suites complètes.

Contrôles complémentaires :

```text
git diff --check c9a1adc..b32100f
git rev-parse HEAD
git branch --show-current
```

Résultat : diff propre ; tête exacte `b32100f...` ; branche
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
nominal est propre, avec le P2 d'identité signalé. La disponibilité a été
contrôlée par le domaine virtuel et la revue des allocations : aucun nouveau
DoS actionnable. La logique métier et la qualité des tests produisent les deux
findings ci-dessus. Aucune zone du diff n'est restée non vérifiée.
