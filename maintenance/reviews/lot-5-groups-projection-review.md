# Contre-revue indépendante — lot 5, projection des groupes

Date : 2026-09-01

Tête revue : `b32100fc1763266211d90748be61e7ed736c4101`

Delta produit et régressions relu : `69b9ff3..b32100f`

Worktree exclusif :
`/private/tmp/auto-size-text-review-groups-projection`

## Verdict

**ACCEPTÉ**

La projection de groupe respecte le contrat mathématique du lot 5 : seul
`P = U.scale(L)` est publié, `G` est le minimum des rapports publiés, et le
candidat rendu est

```text
R = max { c dans D | c <= L et U.scale(c) <= G }
```

avec retour au minimum exact du domaine si cet ensemble est vide. Aucun chemin
de produit ne republie `R`.

La dichotomie reste en `O(log C)` sur un domaine régulier virtuel d'environ
`10^12` candidats. La projection ne construit aucune collection
proportionnelle à ce domaine, ne scanne pas les candidats et ne crée ni ne
relance aucun `TextPainter`.

Aucun finding P0, P1, P2 ou P3 n'a été trouvé.

## Findings ordonnés

- P0 : aucun.
- P1 : aucun.
- P2 : aucun.
- P3 : aucun.

## Preuve formelle du flux `L/P/G/R`

### `L` et `P` restent locaux

`_calculateFontSize` appelle la dichotomie du domaine avec le seul prédicat de
fit typographique. Ce chemin ne lit jamais `AutoSizeGroup._fontSize`. Son
résultat contient séparément le candidat logique local `L`, la sortie racine
effective validée `P = U.scale(L)` et le booléen de fit local.

Dans le build groupé, l'unique appel produit à
`AutoSizeGroup._updateFontSize` reçoit `result.effectiveFontSize`. La recherche
de projection n'est appelée qu'après cette publication. La recherche globale
confirme qu'il n'existe aucun autre appel à `_updateFontSize` dans `lib/`.

Le cache `_publishedEffectiveFontSize` compare exactement le nouveau `P` au
dernier `P` publié. Une notification de groupe peut recalculer le local, mais
un `P` inchangé n'écrit rien. Si `L` change sur un plateau sans changer `P`, le
nouveau `L` borne tout de même la projection du build courant.

### `G` est exactement le minimum des `P`

Le groupe conserve une map `membre -> rapport`. Une inscription reçoit le
marqueur interne `+infinity`, puis la première publication finie le remplace.
`_recalculateFontSize` repart de `+infinity` et applique uniquement la
comparaison exacte `size < _fontSize` sur les rapports courants.

Les sorties de scaler NaN, infinies ou négatives sont rejetées par
`_checkedEffectiveFontSize` avant l'appel au groupe. Le zéro est seulement
canonicalisé ; aucune tolérance n'intervient dans la map ou dans son minimum.

### `R` est une projection pure à double borne

`_projectGroupFontSize` réutilise le même `_CandidateSet` ascendant que le fit
local. Son prédicat est exactement :

```text
candidate > localCandidate        => false, sans appel à U
U.scale(candidate) <= groupLimit  => true
```

Les deux comparaisons sont inclusives et exactes. La tolérance ULP du lot 2
n'est appelée que pendant la construction du domaine logique et la fusion de
ses quasi-doublons ; elle n'est pas appelée sur une sortie effective ou sur
`G`.

Sous les hypothèses contractuelles `D` strictement croissant et `U` monotone
non décroissant, ce prédicat est un préfixe vrai puis faux. La dichotomie rend
donc son plus grand élément. Si le préfixe est vide,
`findLargestThatFits` garde l'index zéro et rend le minimum du domaine avec son
indicateur faux ; cet indicateur n'écrase jamais le fit local qui décide seul
de `overflowReplacement`.

Le résultat de `_projectGroupFontSize` est transmis uniquement à `_buildText`.
Il n'entre ni dans le cache de publication, ni dans la map, ni dans le calcul
de `G`. Cette séparation exclut par construction une réduction en cascade
causée par la republication de `R`.

## Domaines, scalers et métriques vérifiés

| Cas | Preuve observée |
|---|---|
| Grilles régulières distinctes | domaines `10+4k` et `11+5k`, rendus `30/26`, sans interpolation |
| Domaine virtuel géant | environ `10^12` candidats, terminal logique exact `100000000000.1`, rendu projeté `49.900000000000006` |
| Grilles fractionnaires | domaines `.3/.1` et `.35/.1`, rendus exacts `.4/.45` |
| Presets disjoints | `{10,20,40}` et `{10,30}`, rendus stables `20/30` après rebuilds |
| Presets dupliqués | snapshot immuable, quasi-dédoublonnage logique sans mutation de la liste source |
| Minimum inaccessible | limite 10 face au domaine `{20,30}` : rendu 20, sans taille étrangère ni replacement |
| Scalers linéaires distincts | identité contre facteur 2 : candidats `30/15`, racines `30/30` |
| Scaler non linéaire | `U(x)=x²/10` : candidat 20, racine 40, face au rapport voisin 50 |
| Plateau classique | `U(x)=min(x,20)` conserve `L=R=20` malgré la même racine pour 20 et 30 |
| Comparaison exacte | `G+1 ULP` est rejeté ; l'égalité exacte est acceptée |
| Référence racine zéro | fixture RichText `F=20`, run enfant 100, racine/box mutantes `0/120`, résultat exigé `0/70` |
| Sortie invalide en projection | `P=50` est publié avant l'erreur à 20, NaN n'entre jamais dans les rapports, puis le voisin reste borné à 50 après retrait de la limite 15 |
| Replacement | dépend uniquement du fit local ; l'échec à atteindre `G` n'est pas traité comme un overflow |

Le run enfant RichText suit la composition du lot 4 : pour une référence
positive `F` et un run de taille `S`, le rendu applique
`U.scale(S * R / F)`. Pour la fixture plateau zéro, le candidat 20 donne donc
une racine 0 et une box Ahem 70 ; le candidat 30, interdit par `R <= L`, aurait
donné 120.

## Probe privé temporaire

Une instrumentation locale, supprimée avant ce rapport, séparait :

- les écritures de rapport ;
- les entrées, évaluations, appels de scaler et sorties de chaque projection ;
- les appels du fitter qui construisent un `TextPainter`.

Sur les presets disjoints, la trace contient exactement deux écritures de
rapport, `40` et `30`. Elle contient un résultat projeté `20`, mais aucune
écriture `20`. Les pompes de synchronisation et témoin n'ajoutent aucune
écriture. Cela prouve directement que seules les valeurs `P` locales sont
publiées et que `R` reste dérivé.

Sur le domaine régulier virtuel d'environ `10^12` candidats, chaque recherche
de projection respecte la borne
`ceil(log2(C + 1)) = 40`. Aucun événement de painter ne se trouve entre
`projectionStart` et `projectionEnd`. La lecture du code confirme en plus que
ce chemin ne contient qu'une dichotomie par indices et un accès virtuel
`_CandidateSet[index]` ; les seules listes de `_CandidateSet` concernent le
snapshot fini des presets fournis par l'appelant.

Le probe d'erreur non transactionnelle utilisait A avec
`D={10,20,30,40,50}`, `P_A=50`, B imposant 15 et C avec `{50,70}`. La
projection de A rencontre NaN à 20 après la publication finie. Après retrait
de B, sans changer la configuration de A, C rend 50 et non 70. Le rapport fini
de A a donc été conservé, aucune sortie invalide n'a été stockée et aucun
rollback spéculatif n'a été effectué.

Les trois probes passent à l'identique sur Flutter 3.41.0 et 3.47.2.

## Mutants temporaires

Tous les mutants ont été retirés et le diff produit a ensuite été vérifié vide.

| Mutant | Oracle rouge | Signature observée |
|---|---|---|
| Seconde borne effective seule, sans `c <= L` | plateau RichText racine zéro | box `120` au lieu de `70` |
| Republication de `U.scale(R)` | presets disjoints stables | voisin rendu `10` au lieu de `30` |
| Recherche linéaire | probe de 1 024 candidats | `1 524` évaluations pour deux sessions, borne attendue `<=22` |
| Tolérance effective autour de `G` | excès d'un ULP | `20.000000000000004` accepté au lieu du rendu 10 |

Ces rouges discriminent respectivement la perte de la borne locale, la
confusion `P/R`, la régression de complexité et la réutilisation illégale de la
tolérance du domaine dans la comparaison effective.

## Matrice exécutée

Versions exactes constatées :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
```

| SDK | Analyse fatale `lib test` | Ciblés lot 5 | Suite complète | Probe privé |
|---|---:|---:|---:|---:|
| 3.41.0 | aucun diagnostic | 60/60 | 114/114 | 3/3 |
| 3.47.2 | aucun diagnostic | 60/60 | 114/114 | 3/3 |

La suite ciblée comprend les contraintes de groupe, le cycle de vie, le
builder, les presets, les scalers, RichText, replacement, le cycle de vie des
painters et le leak tracking. Les deux résolutions de dépendances ont été
effectuées proprement avec le SDK exécuté avant ses tests.

Les quatre mutants ont été exécutés sur Flutter 3.47.2 ; ils échouent dans les
assertions métier attendues, sans erreur de compilation ou de harness.

## Périmètre lu intégralement

Tous les fichiers du delta `69b9ff3..b32100f` ont été lus en entier :

- `lib/src/auto_size_group.dart` ;
- `lib/src/auto_size_text.dart` ;
- `lib/src/auto_size_text_layout.dart` ;
- `maintenance/implementation/lot-5-groups.md` ;
- `test/group_builder_test.dart` ;
- `test/group_constraints_test.dart` ;
- `test/group_test.dart` ;
- `test/preset_font_sizes_test.dart` ;
- `test/text_scaler_test.dart`.

Les oracles `maintenance/decisions/group-projection-oracle.md` et
`maintenance/decisions/group-lifecycle-adversarial-oracle.md`, ainsi que la
contre-revue de ce dernier, ont également été lus intégralement. Les
instructions `find-bugs`, `developing-flutter` et leurs cinq références ont
été appliquées. Aucun `AGENTS.md` additionnel n'existe dans ce worktree ;
l'instruction PostHog fournie au chantier n'est pas applicable à cette revue
locale.

## Audit pré-conclusion

La surface modifiée est une bibliothèque Flutter locale : aucun input réseau,
requête de données, contrôle d'authentification ou d'autorisation, session,
appel externe ou opération cryptographique n'est ajouté. Injection, XSS, CSRF,
IDOR, secrets et fuite d'information sont hors surface.

Les points applicables de la checklist ont été vérifiés :

- logique métier et arithmétique : unités `L/P/G/R`, ordre exact, minima,
  terminal, ULP, plateau et fallback de domaine ;
- disponibilité : dichotomie virtuelle, absence de scan/liste/painter dans la
  projection et compteur logarithmique ;
- état et race : rapport local mémorisé, minimum synchrone, notification
  coalescée, absence de republication pendant la vague ;
- cycle de vie : inscription, groupe identique, transfert, passage à `null`,
  retrait et dispose couverts par les régressions ciblées ;
- erreurs : validation avant publication et frontière non transactionnelle
  après publication ;
- ressources : aucun painter de projection, tests lifecycle/leak verts ;
- qualité des oracles : mutants discriminants, métrique RichText réelle,
  comparaison exacte et deux SDK exacts.

Aucune zone du périmètre demandé ne reste invérifiée. Les probes, mutants et
fichiers temporaires ont été supprimés. Avant l'ajout de ce rapport,
`git status`, `git diff --check` et le diff des fichiers produit/tests étaient
vides ; le commit de revue ne contient donc que ce document.
