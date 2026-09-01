# Revue indépendante — lot 0 fondation SDK

Date : 2026-09-01

Branche revue : `codex/review-foundation-sdk`

Parent d'intégration exact :
`85545b7232fb2cc2dedc9a1da528469c1c76f139`

Tête candidate exacte :
`547c1aa77691730b19e08922653033d8606614e8`

Plage revue : `85545b7...547c1aa`

Commit original fonctionnellement équivalent :
`52aacca1daad78cd442d7733235251fff094c78f`. La comparaison à deux arbres
montre que la seule différence entre l'original et le candidat cherry-pické
est l'ajout antérieur de
`maintenance/decisions/example-lock-policy.md` dans la base d'intégration.

## Verdict

**CHANGEMENTS REQUIS.**

La fondation technique est reproductible : les deux SDK exacts résolvent le
package, les 25 tests passent sur minimum et haute, le downgrade minimum passe,
le lock canonique haut et le chemin minimum sans lock respectent la décision,
les neuf diagnostics scoped correspondent exactement à l'allowlist et le
harness de fuite échoue réellement quand un `TextPainter` n'est pas disposé.
Les 182 suppressions sont mécaniques et aucun changement produit involontaire
n'a été trouvé.

Un critère d'acceptation explicite reste cependant non satisfait : les six
fichiers `*_test.dart` historiques touchés par le formatage ne sont ni groupés
par unité testée, ni renommés avec des descriptions « should … ».

## Finding priorisé

### P2 — Les suites historiques touchées ne respectent pas le standard de test du chantier

**Sévérité : faible, bloquante pour l'acceptation du lot.**

**Fichiers et lignes :**

- `test/basic_test.dart:7` ;
- `test/group_builder_test.dart:47` ;
- `test/group_test.dart:63` ;
- `test/min_max_font_size_test.dart:7` ;
- `test/overflow_replacement_test.dart:7` ;
- `test/preset_font_sizes_test.dart:7`.

**Problème :** ces six fichiers font partie du diff du lot, mais leur `main()`
contient directement des `testWidgets` et aucun `group()`. Leurs noms restent
« Only Text », « Group sync », « Respects … », etc., sans la forme obligatoire
« should … ». Cela contredit le critère commun de la feuille de route, T2 du
plan outillage et C7 de la revue finale. Les deux nouveaux tests respectent,
eux, ce standard.

**Preuve :** une recherche ciblée de `main`, `group` et `testWidgets` dans les
six fichiers ne trouve aucun `group()`. Le diff confirme qu'ils ont tous été
modifiés par ce lot, même lorsque le changement est seulement mécanique.

**Correction exacte attendue :** dans chacun de ces six fichiers, envelopper
les cas dans un `group()` nommé d'après l'unité sous test (`AutoSizeText`,
`AutoSizeGroup` ou `AutoSizeGroupBuilder`) et renommer chaque description pour
commencer par « should … ». Ne modifier ni les widgets construits, ni les
attentes, ni les helpers, ni le code produit. Rejouer ensuite format haute,
analyse scoped et tests sur 3.41.0 et 3.47.2.

Aucun autre finding actionnable n'a été identifié.

## Matrice indépendante

| Environnement / commande | Résultat observé |
|---|---|
| Flutter `3.41.0 --version` | Code 0 ; révision `44a626f4f0`, Dart `3.11.0`, moteur `cc8e596aa65130a0678cc59613ed1c5125184db4`. |
| Flutter `3.47.2 --version` | Code 0 ; révision `d3b14c8769`, Dart `3.13.2`, moteur `1cf1c4773fb941c4c74a7f8bb144a8837596c0f4`. |
| 3.47.2 — `flutter pub get --no-example` | Code 0 ; `flutter_lints 6.0.0`, `leak_tracker_flutter_testing 3.0.10`, `leak_tracker 11.0.2`, `lints 6.1.0`. Replay immédiat : code 0, `Got dependencies!`. |
| 3.47.2 — analyse scoped `lib test example/main.dart` | Code 1 attendu ; exactement 9 informations `deprecated_member_use`, 0 erreur, 0 warning, aucune information supplémentaire. |
| 3.47.2 — `example/` `pub get --enforce-lockfile` puis analyse fatale `--no-pub` | Codes 0 ; lock consommé sans mutation, aucun diagnostic. |
| 3.47.2 — `flutter test --no-pub --reporter compact` | Code 0 ; 25/25 tests. |
| 3.47.2 — `dart format --output=none --set-exit-if-changed lib test example` | Code 0 ; 20 fichiers, 0 changement. |
| 3.47.2 — analyse globale témoin `flutter analyze --no-pub` | Code 1 ; 49 diagnostics, dont les erreurs et warnings connus de `demo/**`. Ce résultat n'est pas présenté comme vert. |
| 3.41.0 — copie de `HEAD`, lock exemple déplacé, `flutter pub get --no-example` | Code 0 ; `flutter_lints 6.0.0`, `leak_tracker_flutter_testing 3.0.10`, `leak_tracker 11.0.2`, `lints 6.1.0`. |
| 3.41.0 — analyse scoped `lib test example/main.dart` | Code 1 attendu ; les mêmes 9 informations, aux mêmes règle/fichier/ligne/colonne, et aucun autre diagnostic. |
| 3.41.0 — `flutter test --no-pub --reporter compact` | Code 0 ; 25/25 tests. |
| 3.41.0 — `example/` sans lock canonique, `flutter pub get` puis analyse fatale `--no-pub` | Codes 0 ; résolution naturelle de 10 dépendances avec `meta 1.17.0` et `vector_math 2.2.0`, aucun diagnostic. |
| 3.41.0 — `flutter pub downgrade --no-example` | Code 0 ; 9 dépendances abaissées, notamment `leak_tracker 11.0.1` et `lints 6.0.0`. |
| 3.41.0 — tests `--no-pub` après downgrade | Code 0 ; 25/25 tests. |
| 3.41.0 — lock canonique haut forcé dans la copie | Code 65 attendu ; Pub voudrait abaisser `meta 1.19.0 → 1.17.0` et `vector_math 2.4.2 → 2.2.0`, puis refuse le lock. |
| 3.41.0 — test leak temporaire sans `painter.dispose()` | Code 1 attendu ; une fuite `notDisposed`, classe `TextPainter`, rattachée au test et signalée par les hooks `FlutterMemoryAllocations`. |
| `git diff --check 85545b7...HEAD` | Code 0. |
| Replays / idempotence | `analysis_options.yaml` conserve le SHA-256 `0c9fe2b745a2481769c610ec01461ba15cf583e0bc7b451d74eccb93b90f7dc6`; manifests et lock haut inchangés. |
| Arbre canonique après matrice | `git status --short` vide avant création du présent rapport. |

## Vérification des neuf diagnostics allowlistés

Les deux SDK produisent exactement `deprecated_member_use` aux emplacements
suivants :

| Fichier | Ligne:colonne |
|---|---:|
| `lib/src/auto_size_text.dart` | `185:31` |
| `lib/src/auto_size_text.dart` | `338:46` |
| `lib/src/auto_size_text.dart` | `405:9` |
| `lib/src/auto_size_text.dart` | `423:7` |
| `lib/src/auto_size_text.dart` | `448:9` |
| `lib/src/auto_size_text.dart` | `463:9` |
| `test/utils.dart` | `8:11` |
| `test/utils.dart` | `27:5` |
| `test/utils.dart` | `27:27` |

La commande scoped reste volontairement rouge avec le code 1. Aucun ignore
analyzer global ne masque ces informations.

## Inspection du diff et contrats

- Contraintes racine et exemple exactes : Dart `>=3.11.0 <4.0.0`, Flutter
  `>=3.41.0`.
- `flutter_lints: ^6.0.0` est une dépendance directe de la racine et de
  l'exemple ; la dépendance de test de fuite est bornée à `^3.0.10`.
- `analysis_options.yaml` inclut le socle officiel, emploie les trois options
  strictes reconnues par 3.41.0, ne masque pas un include absent et commite
  explicitement `build/**`. Les replays 3.47.2 sont idempotents.
- `.gitignore` ignore seulement `/pubspec.lock` à la racine. Le lock de
  `example/` est suivi, généré avec la pin haute et appliqué seulement sur cette
  pin conformément à la décision normative. La résolution minimum est isolée
  dans une extraction temporaire ; aucun lock minimum n'est recopié.
- Le harness est opt-in : l'état global ignore les fuites par défaut et le
  réglage ciblé suit les ressources instrumentées non disposées. La mutation
  négative indépendante prouve que le test peut échouer pour la cause visée,
  sans dépendre seulement du GC Dart.
- Le test du plancher exerce réellement les trois getters et les trois valeurs
  de métriques `MediaQuery`.
- Les changements de bibliothèque sont mécaniques : directive `part` par URI,
  super-paramètres, types génériques/retours, `const` permis et formatage. Aucun
  paramètre public, champ public, valeur par défaut, résultat ou attente
  historique n'est retiré ou renommé. L'ajout de `const` à
  `AutoSizeGroupBuilder` est compatible et ne change pas la signature
  appelable existante.
- Le diff ne touche ni `demo/**`, ni `.github/**`, ni README, ni changelog. La
  version reste `3.0.0`, comme prévu avant le lot 12.

## Fichiers lus intégralement

Les 22 fichiers modifiés et toutes leurs lignes supprimées dans le parent ont
été lus intégralement :

1. `.gitignore` ;
2. `analysis_options.yaml` ;
3. `example/main.dart` ;
4. `example/pubspec.lock` ;
5. `example/pubspec.yaml` ;
6. `lib/auto_size_text.dart` ;
7. `lib/src/auto_size_group.dart` ;
8. `lib/src/auto_size_group_builder.dart` ;
9. `lib/src/auto_size_text.dart` ;
10. `maintenance/implementation/lot-0-foundation.md` ;
11. `pubspec.yaml` ;
12. `test/basic_test.dart` ;
13. `test/flutter_test_config.dart` ;
14. `test/group_builder_test.dart` ;
15. `test/group_test.dart` ;
16. `test/leak_tracking.dart` ;
17. `test/leak_tracking_test.dart` ;
18. `test/min_max_font_size_test.dart` ;
19. `test/overflow_replacement_test.dart` ;
20. `test/preset_font_sizes_test.dart` ;
21. `test/sdk_floor_api_test.dart` ;
22. `test/utils.dart`.

Ont également été lus intégralement : la feuille de route, sa revue finale,
la vérification du plancher SDK, la décision de lock de l'exemple et le journal
du lot 0.

## Cartographie d'attaque et checklist sécurité

Les manifests et le lock n'ajoutent que des résolutions d'outillage de test et
de lint. Le code bibliothèque ne reçoit aucune nouvelle entrée : les paramètres
de widgets existants restent inchangés. Les nouveaux fichiers de test allouent
un `TextPainter` local et lisent un `MediaQuery` local. Il n'existe dans aucun
des 22 fichiers modifiés de requête réseau runtime, requête de base de données,
authentification, autorisation, session, opération cryptographique, secret,
écriture externe ou commande construite depuis une entrée.

Checklist appliquée à chaque fichier :

| Risque | Conclusion |
|---|---|
| Injection (SQL/commande/template/header) | Hors surface ; aucune commande runtime ni donnée interpolée vers un interpréteur. |
| XSS | Hors surface ; aucun rendu HTML/web. |
| Authentification / autorisation / IDOR | Hors surface ; aucune identité ni ressource protégée. |
| CSRF | Hors surface ; aucune opération HTTP avec état. |
| Race / TOCTOU | Aucun nouvel état produit ; les microtâches de groupe existantes ne sont pas modifiées. |
| Session | Hors surface. |
| Cryptographie / secrets | Aucune primitive ni donnée secrète ; le lock contient seulement les hashes Pub attendus. |
| Divulgation d'information | Aucun log ou message runtime ajouté ; les stacks de fuite restent dans les tests. |
| Déni de service / ressources | Aucun nouvel algorithme produit ; le harness détecte effectivement un `TextPainter` non disposé. |
| Logique métier / numérique | Aucun calcul produit modifié ; les 23 tests historiques et les 2 nouveaux tests passent sur les deux SDK et après downgrade. |

## Limites de la revue

La revue prouve la compatibilité du lot et du harness, pas la correction des
fuites produit réservée au lot 1. Elle n'exécute pas la démo cassée, la CI, le
packaging, la documentation ou une publication, tous hors périmètre du lot 0.
L'analyse globale témoin suffit à confirmer que cette dette reste visible et
rouge. Aucun merge, push, tag ou changement distant n'a été effectué.
