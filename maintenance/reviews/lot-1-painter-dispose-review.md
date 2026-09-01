# Revue indépendante — lot 1 cycle de vie des `TextPainter`

Date : 2026-09-01

Branche revue : `codex/review-painter-dispose`

Parent exact : `e9f75af9c3ef54bee2cbd3fcc0a53b44e7811968`

Tête candidate initiale : `ec609c4651116c56232f3a7f4854e7bfb52d108a`

Tête candidate corrigée : `21d3664665958914b97e8833033e4ad704a76c9c`

Plage cumulative revue : `e9f75af...21d3664`

Delta correctif re-revu : `e358162..21d3664`

Le tree de `ec609c4` est identique à celui du candidat original
`bec29e46d24ec24f936c084b1e96681749f3ea7b` : les deux résolvent vers
`eabfad6c6108e5f1850aefcc9782985ee59e6c78`.

## Verdict

**ACCEPTÉ.**

Les deux corrections produit restent correctes : chaque painter de
`_checkTextFits` a un propriétaire local et un `finally`, toutes les lectures
ont lieu avant `dispose`, les retours anticipés et exceptions sont couverts,
et je n'ai trouvé ni double-dispose, ni use-after-dispose, ni changement de
sizing, rendu ou API. Les 25 tests historiques restent verts sur les deux SDK.

Les sept nouvelles régressions ont aussi un signal réel et discriminant : sur
le parent, chacune échoue isolément avec une ou plusieurs ressources
`TextPainter notDisposed` et une stack d'allocation produit ; sur la tête,
elles passent sans fuite. Elles sont groupées et leurs sept noms commencent par
« should ».

La revue initiale demandait un changement parce que `doesTextFit` conservait un
troisième `TextPainter` temporaire sans propriétaire ni `finally`. Le correctif
`21d3664` entoure maintenant son layout, ses lectures et son retour par un
`try/finally`, et ajoute une régression permanente qui appelle réellement le
helper. Cette régression est rouge pour la cause attendue sur `e358162`, verte
sur la tête et la suite complète passe sur minimum et haute. Le finding initial
est résolu et aucun finding actionnable ne reste.

## Finding initial résolu

### P2 — Le helper `doesTextFit` ne libère pas son `TextPainter`

**Statut final : résolu par `21d3664`.**

**Fichier :** `test/utils.dart:23-39`

**Sévérité :** faible pour le produit, bloquante pour l'acceptation du lot.

**Problème :** `doesTextFit` construit un `TextPainter`, appelle `layout`, lit
ses métriques puis retourne sans appeler `dispose`. Le journal du lot écarte ce
helper parce qu'aucun des sept nouveaux tests ne l'appelle. Ce n'est pas le
critère fixé par la feuille de route : le lot doit corriger tout painter des
helpers et tout painter temporaire doit être libéré dans un `finally`.

**Preuve initiale :** sur `ec609c4`, `rg 'doesTextFit\(' test` ne trouvait que
sa déclaration, ce qui expliquait pourquoi les suites courantes restaient
vertes. J'ai ajouté uniquement dans une extraction temporaire un test qui
appelle le helper avec
`experimentalLeakTesting: nativeResourceLeakTesting`. Sur Flutter 3.47.2, le
corps fonctionnel passe, puis `tearDownAll` échoue avec exactement une ressource
`TextPainter notDisposed`; la stack de création pointe sur
`doesTextFit (test/utils.dart:23)`. Le signal vient des événements
`FlutterMemoryAllocations`, pas d'une simple attente de collecte GC.

**Correction vérifiée :** le helper conserve sa signature, ses arguments de
painter, son layout et ses comparaisons. Un `try` couvre toutes les opérations
susceptibles de retourner ou lever après l'allocation ; son `finally` appelle
exactement un `dispose`. Le booléen est évalué avant le disposal. Le nouveau
test opt-in appelle `doesTextFit` avec des contraintes qui font réellement
tenir le texte et vérifie aussi le résultat fonctionnel `true`.

Aucun autre finding actionnable n'a été identifié.

## Audit des propriétaires et du cycle de vie

La recherche exhaustive des constructions `TextPainter(` dans les fichiers
Dart du dépôt trouve quatre allocations :

| Allocation | Propriétaire et sortie | Conclusion |
|---|---|---|
| `lib/src/auto_size_text.dart:401`, painter de mots | `_checkTextFits`; `try` couvre `layout`, les deux lectures et le retour anticipé ; `finally` à la ligne 418 et `dispose` à la ligne 419 | Correct |
| `lib/src/auto_size_text.dart:423`, painter principal | `_checkTextFits`; `try` couvre `layout`, les trois lectures et le retour ; `finally` à la ligne 439 et `dispose` à la ligne 440 | Correct |
| `test/leak_tracking_test.dart:9`, probe du harness | Test local ; `dispose` explicite à la ligne 13 après `layout` | Correct pour ce probe sans retour ni exception |
| `test/utils.dart:23`, helper `doesTextFit` | `try` autour de `layout`, des trois lectures et du retour ; `finally` et `dispose` aux lignes 39-40 | Correct par `21d3664` |

Dans les deux sites produit, le constructeur précède le `try`, mais les
constructeurs Flutter 3.41.0 et 3.47.2 ne créent pas encore de paragraphe : la
ressource est créée pendant `layout`, qui est bien dans le `try`. Leur méthode
`dispose` marque le painter disposé, publie l'événement de disposal et libère
`_layoutTemplate` ainsi que le paragraphe de `_layoutCache`. Chaque instance
produit ne traverse qu'un seul `dispose` et n'est plus référencée ensuite.

Le diff produit hors espaces consiste uniquement à ajouter les deux blocs
`try/finally`. Aucun argument de `TextPainter`, calcul binaire, contrainte,
comparaison, taille retournée, widget rendu, signature ou champ public ne
change.

## Challenge indépendant des sept tests

Le réglage `nativeResourceLeakTesting` part d'un harness globalement ignoré,
réactive le suivi complet, demande `allNotDisposed: true` et conserve les
stacks de création. `TextPainter` publie sa création et son disposal via
`FlutterMemoryAllocations`; une instance devenue inatteignable mais jamais
disposée reste donc classée `notDisposed`. Le test ne se contente pas de
constater la collection d'un objet Dart.

Sur une extraction du parent exact, avec le nouveau fichier de test copié sans
le changement produit, chaque test a été lancé seul par son `--plain-name` :

| Test isolé | Code | `notDisposed` | Site(s) d'allocation parent |
|---|---:|---:|---|
| `should dispose the painter when the initial font size fits` | 1 | 1 | painter principal, ligne 419 |
| `should dispose every painter when no font size fits` | 1 | 4 | painter principal, ligne 419 |
| `should dispose the word painter before an early return` | 1 | 4 | painter de mots, ligne 401 |
| `should dispose both painters when wrapWords is false and text fits` | 1 | 2 | lignes 401 et 419 |
| `should dispose the painter when paragraph layout throws` | 1 | 1 | painter principal, ligne 419 |
| `should dispose painters across repeated rebuilds` | 1 | 5 | painter principal, ligne 419 |
| `should dispose painters when a member is removed from its group` | 1 | 3 | painter principal, ligne 419 |

La suite ciblée complète sur le parent exécute ses sept corps puis échoue au
`tearDownAll` avec 20 ressources `TextPainter notDisposed`. Le test
`wrapWords: false` isolé distingue les deux allocations avec deux stacks. Sur
la tête, la suite ciblée passe 7/7 et son `tearDownAll` est vert sur les deux
SDK.

Les sept tests sont dans un `group('AutoSizeText TextPainter lifecycle', ...)`.
Chaque nom commence par « should » et chaque assertion fonctionnelle vérifie
que le chemin visé a réellement été atteint. Aucun des sept n'appelle
`doesTextFit` ou ne crée directement un `TextPainter`; leur vert n'est donc pas
pollué par le finding du helper. Le huitième test permanent appelle au contraire
explicitement `doesTextFit`, vérifie que le texte tient, puis laisse le réglage
de fuite contrôler le disposal du painter du harness.

## Matrice indépendante initiale

Toolchains observées :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
```

| Environnement / commande | Résultat |
|---|---|
| 3.47.2, parent + tests candidats : `flutter test --no-pub --reporter expanded test/text_painter_lifecycle_test.dart` | Code 1 attendu ; 7 corps passent, puis 20 `TextPainter notDisposed` au `tearDownAll` |
| 3.47.2, parent, sept replays `--plain-name` | Sept codes 1 ; comptes et sites détaillés ci-dessus |
| 3.47.2, tête : suite lifecycle ciblée | Code 0 ; 7/7, aucune fuite |
| 3.47.2, tête : `flutter test --no-pub --reporter compact` | Code 0 ; 32/32 |
| 3.47.2, tête : `flutter analyze --no-pub lib test example/main.dart` | Code 1 attendu ; exactement 9 infos `deprecated_member_use`, 0 warning, 0 erreur |
| 3.47.2, exemple : `flutter pub get --enforce-lockfile`, puis analyse fatale `--no-pub` | Codes 0 ; lock consommé et aucun diagnostic |
| 3.47.2 : `dart format --output=none --set-exit-if-changed lib test example` | Code 0 ; 21 fichiers, 0 changement |
| 3.41.0, extraction propre de la tête sans lock exemple : `flutter pub get --no-example` | Code 0 ; 26 dépendances, dont `meta 1.17.0` et `vector_math 2.2.0` |
| 3.41.0, tête : suite lifecycle ciblée | Code 0 ; 7/7, aucune fuite |
| 3.41.0, tête : suite complète | Code 0 ; 32/32 |
| 3.41.0, tête : analyse scoped | Code 1 attendu ; les mêmes 9 infos, 0 warning, 0 erreur |
| 3.41.0, exemple sans lock : résolution puis analyse fatale | Codes 0 ; 10 dépendances et aucun diagnostic |
| Micro-test temporaire du helper sous 3.47.2 | Code 1 attendu ; exactement 1 `TextPainter notDisposed`, stack vers `test/utils.dart:23` |
| `git diff --check e9f75af...ec609c4` | Code 0 |
| `git diff ec609c4 bec29e4` | Aucun delta ; trees identiques |

Les résolutions minimum et le micro-test ont été exécutés dans des répertoires
temporaires. Le lock canonique n'a pas été remplacé et l'arbre de revue était
propre avant la création du présent rapport.

## Re-review du correctif `21d3664`

Le delta `e358162..21d3664` modifie exactement trois fichiers : `test/utils.dart`,
`test/text_painter_lifecycle_test.dart` et le journal du lot. Il n'existe aucun
delta sous `lib/**`; les deux `finally` produit déjà acceptés sont inchangés.

Dans `test/utils.dart`, le diff hors espaces ajoute seulement le
`try/finally` et `dispose`. Il ne change ni le `TextSpan`, ni les paramètres du
painter, ni la largeur de layout, ni les trois comparaisons. Toutes les valeurs
sont lues avant disposal et l'instance ne sort pas du helper. Il n'existe donc
ni double-dispose, ni use-after-dispose, ni changement fonctionnel du helper.

Le nouveau test est permanent, dans le groupe existant et son nom commence par
« should ». Pour prouver son rouge indépendamment, le fichier de test corrigé a
été copié dans une extraction de `e358162`, sans le correctif de `test/utils`.
Sur Flutter 3.47.2, son assertion `isTrue` passe, puis `tearDownAll` échoue avec
exactement une ressource `TextPainter notDisposed`; la stack pointe sur
`doesTextFit (test/utils.dart:23)`. Sur `21d3664`, le même test est inclus dans
les 8/8 verts et ne laisse aucune fuite.

| Contrôle final indépendant | Résultat |
|---|---|
| 3.47.2, nouveau test seul sur `e358162` | Code 1 attendu ; 1 `TextPainter notDisposed`, stack `test/utils.dart:23` |
| 3.47.2, lifecycle ciblé sur `21d3664` | Code 0 ; 8/8, `tearDownAll` vert |
| 3.47.2, suite complète | Code 0 ; 33/33 |
| 3.47.2, analyse scoped `lib test example/main.dart` | Code 1 attendu ; exactement 9 infos historiques, 0 warning, 0 erreur |
| 3.47.2, exemple verrouillé puis analyse fatale | Codes 0 ; lock inchangé et aucun diagnostic |
| 3.47.2, format `lib test example` | Code 0 ; 21 fichiers, 0 changement |
| 3.41.0, extraction propre sans lock exemple | Résolution racine réussie ; 26 dépendances |
| 3.41.0, lifecycle ciblé | Code 0 ; 8/8, `tearDownAll` vert |
| 3.41.0, suite complète | Code 0 ; 33/33 |
| 3.41.0, analyse scoped | Code 1 attendu ; les mêmes 9 infos, 0 warning, 0 erreur |
| 3.41.0, exemple sans lock puis analyse fatale | Codes 0 ; 10 dépendances et aucun diagnostic |
| Diff-check delta et cumul | Codes 0 pour `e358162..21d3664` et `e9f75af...21d3664` |

La recherche cumulative trouve toujours exactement quatre constructions
`TextPainter` dans le dépôt. Les trois painters temporaires de production et du
helper sont maintenant protégés par leurs propriétaires ; le quatrième est le
probe du harness, explicitement disposé. Aucun résultat de sizing, rendu ou API
publique n'a changé. Aucun nouveau finding n'a été identifié lors de la
re-review.

## Fichiers lus intégralement

Les quatre fichiers produit/test/journal modifiés cumulativement ont été lus
intégralement, ainsi que leur diff et
la version parent du fichier produit :

1. `lib/src/auto_size_text.dart` ;
2. `test/text_painter_lifecycle_test.dart` ;
3. `test/utils.dart` ;
4. `maintenance/implementation/lot-1-painter-dispose.md`.

Pour vérifier le harness et les propriétaires, ont aussi été lus intégralement
`test/flutter_test_config.dart`, `test/leak_tracking.dart`,
`test/leak_tracking_test.dart`, `test/text_fits_test.dart` et
`test/wrap_words_test.dart`, ainsi que les portions constructeur/disposal de
`TextPainter` dans les sources Flutter 3.41.0 et 3.47.2.

Les instructions `developing-flutter`, Effective Dart, Testing et `find-bugs`,
la feuille de route, sa revue finale, la revue du lot 0 et le journal du lot 1
ont été lus avant conclusion.

## Cartographie d'attaque et checklist

Les fichiers modifiés n'ajoutent aucune entrée utilisateur nouvelle, requête de
base de données, authentification, autorisation, session, appel externe,
primitive cryptographique, commande ou secret. Le seul état ajouté est local à
des tests ; le code produit ajoute uniquement la libération de ressources.

| Risque | Conclusion |
|---|---|
| Injection SQL/commande/template/header et XSS | Hors surface ; aucun interpréteur, HTML ou donnée externe |
| Authentification, autorisation/IDOR, CSRF et session | Hors surface ; aucune identité, requête ou mutation distante |
| Race / TOCTOU | Aucun nouvel état partagé ; les callbacks de groupe existants ne sont pas modifiés |
| Cryptographie, secrets et divulgation | Hors surface ; seulement des stacks locales de test en cas d'échec |
| Déni de service / ressources | Les deux fuites produit et le painter du helper sont corrigés ; quatre propriétaires vérifiés |
| Logique métier / numérique | Aucun calcul produit modifié ; résultats historiques verts sur minimum et haute |

## Limites

Cette revue ne modifie ni le code produit ni le harness ; elle enregistre la
validation indépendante du correctif déjà fourni. Elle ne couvre pas les futurs
painters persistants des lots render 9 et 10, ni la démo, la CI, le packaging,
la documentation publique ou une publication. Aucun merge, push, tag ou autre
mutation distante n'a été effectué.
