# Revue indépendante — lot 1 cycle de vie des `TextPainter`

Date : 2026-09-01

Branche revue : `codex/review-painter-dispose`

Parent exact : `e9f75af9c3ef54bee2cbd3fcc0a53b44e7811968`

Tête candidate revue : `ec609c4651116c56232f3a7f4854e7bfb52d108a`

Plage revue : `e9f75af...ec609c4`

Le tree de `ec609c4` est identique à celui du candidat original
`bec29e46d24ec24f936c084b1e96681749f3ea7b` : les deux résolvent vers
`eabfad6c6108e5f1850aefcc9782985ee59e6c78`.

## Verdict

**CHANGEMENTS REQUIS.**

Les deux corrections produit sont correctes : chaque painter de
`_checkTextFits` a un propriétaire local et un `finally`, toutes les lectures
ont lieu avant `dispose`, les retours anticipés et exceptions sont couverts,
et je n'ai trouvé ni double-dispose, ni use-after-dispose, ni changement de
sizing, rendu ou API. Les 25 tests historiques restent verts sur les deux SDK.

Les sept nouvelles régressions ont aussi un signal réel et discriminant : sur
le parent, chacune échoue isolément avec une ou plusieurs ressources
`TextPainter notDisposed` et une stack d'allocation produit ; sur la tête,
elles passent sans fuite. Elles sont groupées et leurs sept noms commencent par
« should ».

Le lot ne satisfait toutefois pas son contrat de nettoyage des helpers de test.
`doesTextFit` conserve un troisième `TextPainter` temporaire sans propriétaire
ni `finally`. Le helper est actuellement inutilisé, ce qui masque la fuite dans
la suite normale, mais un micro-test opt-in qui l'appelle reproduit
immédiatement une fuite instrumentée. Ce finding est bloquant pour
l'acceptation explicite « tout `TextPainter` temporaire » et « aucune fuite du
harness ».

## Finding

### P2 — Le helper `doesTextFit` ne libère pas son `TextPainter`

**Fichier :** `test/utils.dart:23-39`

**Sévérité :** faible pour le produit, bloquante pour l'acceptation du lot.

**Problème :** `doesTextFit` construit un `TextPainter`, appelle `layout`, lit
ses métriques puis retourne sans appeler `dispose`. Le journal du lot écarte ce
helper parce qu'aucun des sept nouveaux tests ne l'appelle. Ce n'est pas le
critère fixé par la feuille de route : le lot doit corriger tout painter des
helpers et tout painter temporaire doit être libéré dans un `finally`.

**Preuve :** `rg 'doesTextFit\(' test` ne trouve que sa déclaration, ce qui
explique pourquoi les suites courantes restent vertes. J'ai ajouté uniquement
dans une extraction temporaire un test qui appelle le helper avec
`experimentalLeakTesting: nativeResourceLeakTesting`. Sur Flutter 3.47.2, le
corps fonctionnel passe, puis `tearDownAll` échoue avec exactement une ressource
`TextPainter notDisposed`; la stack de création pointe sur
`doesTextFit (test/utils.dart:23)`. Le signal vient des événements
`FlutterMemoryAllocations`, pas d'une simple attente de collecte GC.

**Correction attendue :** soit supprimer ce helper mort, soit entourer son
layout, ses lectures et son retour par `try/finally` avec `dispose`, puis ajouter
une régression opt-in qui appelle réellement le helper. La seconde option doit
calculer le booléen avant le `dispose` et ne pas modifier les métriques testées.

Aucun autre finding actionnable n'a été identifié.

## Audit des propriétaires et du cycle de vie

La recherche exhaustive des constructions `TextPainter(` dans les fichiers
Dart du dépôt trouve quatre allocations :

| Allocation | Propriétaire et sortie | Conclusion |
|---|---|---|
| `lib/src/auto_size_text.dart:401`, painter de mots | `_checkTextFits`; `try` couvre `layout`, les deux lectures et le retour anticipé ; `finally` à la ligne 418 et `dispose` à la ligne 419 | Correct |
| `lib/src/auto_size_text.dart:423`, painter principal | `_checkTextFits`; `try` couvre `layout`, les trois lectures et le retour ; `finally` à la ligne 439 et `dispose` à la ligne 440 | Correct |
| `test/leak_tracking_test.dart:9`, probe du harness | Test local ; `dispose` explicite à la ligne 13 après `layout` | Correct pour ce probe sans retour ni exception |
| `test/utils.dart:23`, helper `doesTextFit` | Aucun `dispose`, aucun `finally` | Finding P2 |

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
pollué par le finding du helper.

## Matrice indépendante

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

## Fichiers lus intégralement

Les trois fichiers modifiés ont été lus intégralement, ainsi que leur diff et
la version parent du fichier produit :

1. `lib/src/auto_size_text.dart` ;
2. `test/text_painter_lifecycle_test.dart` ;
3. `maintenance/implementation/lot-1-painter-dispose.md`.

Pour vérifier le harness et les propriétaires, ont aussi été lus intégralement
`test/flutter_test_config.dart`, `test/leak_tracking.dart`,
`test/leak_tracking_test.dart`, `test/utils.dart`, `test/text_fits_test.dart` et
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
| Déni de service / ressources | Les deux fuites produit sont corrigées ; le painter du helper reste non libéré, finding P2 |
| Logique métier / numérique | Aucun calcul produit modifié ; résultats historiques verts sur minimum et haute |

## Limites

Cette revue ne modifie ni le code produit ni le harness et ne valide donc pas
une correction du finding P2. Elle ne couvre pas les futurs painters
persistants des lots render 9 et 10, ni la démo, la CI, le packaging, la
documentation publique ou une publication. Aucun merge, push, tag ou autre
mutation distante n'a été effectué.
