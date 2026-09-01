# Contre-revue indépendante — lot 5, projection des groupes

Date : 2026-09-01

Tête revue : `b01ceae94ed1a7bfc3bd1b7a458bc3ea9661e397`

Delta initial relu : `69b9ff3..b32100f`

Corrections revalidées :

- `6bd7aeb` — couverture de la conservation du rapport et de l'identité ;
- `20a530a` — comparaison des contrôleurs par identité ;
- `577b83f` — compte rendu des premières corrections ;
- `a2ab5ab` — observation du rapport conservé avant toute republication ;
- `b01ceae` — compte rendu de l'oracle strict.

Worktree exclusif :
`/private/tmp/auto-size-text-review-groups-projection`

## Verdict

**ACCEPTÉ**

Le produit à cette tête respecte le contrat mathématique du lot 5 : seul
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

La correction par `identical` transfère correctement un membre entre deux
contrôleurs distincts mais égaux par `operator ==`. Elle ne modifie aucune
règle `L/P/G/R` et ajoute seulement une comparaison `O(1)` au cycle de vie.

L'oracle permanent de sortie invalide garde désormais A strictement inchangé,
fait observer le groupe par C avant A, et retire seulement le limiteur B. Le
rollback cohérent qui retire/réinscrit A et remet son cache de publication à
`null` devient rouge sur les deux SDK : C rend 70 au lieu de 50. Aucun accès
privé ni republication d'A ne participe à l'observation.

Aucun finding P0, P1, P2 ou P3 ne subsiste.

## Findings ordonnés

- P0 : aucun.
- P1 : aucun.
- P2 : aucun.
- P3 : aucun.

### P1 antérieur — résolu par `a2ab5ab`

L'oracle précédent changeait le scaler d'A après l'`ArgumentError`. Il pouvait
donc republier `P_A = 50` et masquer un rollback qui remettait aussi le cache à
`null`. Le test courant, lignes 577-645 de
`test/group_constraints_test.dart`, construit C, A puis B dans cet ordre. Seul
B est stateful et seul `showLimiter` change après l'erreur.

Preuve par le rollback complet temporaire :

- après l'échec de projection, le mutant exécute `_remove(this)`,
  `_register(this)`, remet `_publishedEffectiveFontSize` à `null`, puis
  relance l'exception ;
- le test permanent devient rouge sur Flutter 3.41.0 et 3.47.2 à son assertion
  métier, avec `Expected: 50, Actual: 70.0` ;
- les contrôles de l'`ArgumentError`, puis des deux pompes sans nouvelle
  exception, sont franchis avant cet échec ; il ne s'agit donc ni d'une erreur
  de harness ni d'une seconde sortie invalide non consommée.

Sur le produit intact, C rend 50 après la pompe de synchronisation et
`hasScheduledFrame` est faux. Le test interdit donc aussi qu'une vague différée
reproduise 50 après avoir momentanément exposé 70. L'oracle est exclusivement
black-box : il observe le `Text` rendu et l'état public du binding, sans
introspection du groupe ou du cache.

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

### L'identité du groupe ne change pas la projection

`didUpdateWidget` compare maintenant les deux contrôleurs avec
`!identical(oldWidget.group, widget.group)`. Cette décision ne s'exécute que
lors de la mise à jour du widget : elle retire le membre de l'ancienne map,
l'inscrit dans la nouvelle et invalide son cache de publication. Elle ne lit
ni ne transforme `L`, `P`, `G`, `R`, le domaine ou le scaler. `identical` est
une opération constante ; les dichotomies et leurs bornes restent donc
inchangées. La recherche dans `lib/` ne trouve aucune autre comparaison
d'identité entre deux contrôleurs de groupe.

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
| Sortie invalide en projection | le produit conserve `P=50` publié avant l'erreur à 20 et refuse NaN ; l'oracle permanent strict tue un rollback complet avant toute republication |
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

La régression permanente d'erreur non transactionnelle utilise trois membres
dans cet ordre de layout : C observateur avec `D_C={50,70}`, A invalide avec
`D_A={10,20,30,40,50}`, puis B limiteur à 25 dans son propre
`StatefulBuilder`. La première frame publie C=70, A=50 et B=25. La pompe
suivante fait rencontrer à A une sortie invalide pour le candidat projeté 20 ;
l'`ArgumentError` est capturé explicitement par `tester.takeException()`.

La suite ne change ni le widget, ni le scaler, ni le domaine, ni les
contraintes d'A. Elle retire seulement B, pompe ce retrait, puis effectue une
unique pompe synchrone. C étant disposé avant A, il observe le minimum avant
qu'un A dont le cache aurait été annulé puisse republier :

- produit intact : le rapport A=50 a survécu, C rend 50 et aucune frame
  supplémentaire n'est planifiée ;
- rollback cohérent : A est réinscrit à `+infinity`, C rend 70, puis seulement
  A republie 50 et demande une nouvelle vague.

Le test permanent passe avec le produit intact et devient rouge, à 70 au lieu
de 50, avec le rollback cohérent sur les deux SDK. Il verrouille donc la
frontière non transactionnelle sans instrumentation privée.

Les trois probes privés initiaux et l'oracle permanent strict passent à
l'identique sur Flutter 3.41.0 et 3.47.2 avec le produit intact.

## Mutants temporaires

Tous les mutants ont été retirés et le diff produit a ensuite été vérifié vide.

| Mutant | Oracle rouge | Signature observée |
|---|---|---|
| Seconde borne effective seule, sans `c <= L` | plateau RichText racine zéro | box `120` au lieu de `70` |
| Republication de `U.scale(R)` | presets disjoints stables | voisin rendu `10` au lieu de `30` |
| Recherche linéaire | probe de 1 024 candidats | `1 524` évaluations pour deux sessions, borne attendue `<=22` |
| Tolérance effective autour de `G` | excès d'un ULP | `20.000000000000004` accepté au lieu du rendu 10 |
| Comparaison de groupes par `!=` | transfert entre deux contrôleurs égaux mais non identiques | `20/20/40` au lieu de `20/40/20` |
| Rollback cohérent du rapport et du cache après erreur | oracle permanent black-box strict | C rend `70` au lieu de `50` sur les deux SDK |

Ces rouges discriminent respectivement la perte de la borne locale, la
confusion `P/R`, la régression de complexité et la réutilisation illégale de la
tolérance du domaine dans la comparaison effective. Les deux derniers valident
la correction d'identité et la conservation non transactionnelle de la
publication. Le rollback complet est désormais rouge dans le test permanent
sur les deux SDK.

## Matrice exécutée

Versions exactes constatées :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
```

| SDK | Analyse fatale `lib test` | Ciblés lot 5 | Suite complète | Probe privé |
|---|---:|---:|---:|---:|
| 3.41.0 | aucun diagnostic | 61/61 | 115/115 | 3/3 |
| 3.47.2 | aucun diagnostic | 61/61 | 115/115 | 3/3 |

La suite ciblée comprend les contraintes de groupe, le cycle de vie, le
builder, les presets, les scalers, RichText, replacement, le cycle de vie des
painters et le leak tracking. Les deux résolutions de dépendances ont été
effectuées proprement avec le SDK exécuté avant ses tests.

Les quatre mutants mathématiques/performance initiaux et le mutant d'identité
ont été exécutés sur Flutter 3.47.2 ; ils échouent dans les assertions métier
attendues, sans erreur de compilation ou de harness. Le rollback cohérent a
été rejoué sur les deux SDK contre `a2ab5ab` : le test permanent strict devient
rouge dans les deux environnements.

## Périmètre lu intégralement

Tous les fichiers du delta initial `69b9ff3..b32100f` ont été lus en entier :

- `lib/src/auto_size_group.dart` ;
- `lib/src/auto_size_text.dart` ;
- `lib/src/auto_size_text_layout.dart` ;
- `maintenance/implementation/lot-5-groups.md` ;
- `test/group_builder_test.dart` ;
- `test/group_constraints_test.dart` ;
- `test/group_test.dart` ;
- `test/preset_font_sizes_test.dart` ;
- `test/text_scaler_test.dart`.

Les quatre fichiers touchés par les corrections `6bd7aeb..577b83f` ont aussi
été relus intégralement :

- `lib/src/auto_size_text.dart` ;
- `test/group_constraints_test.dart` ;
- `test/group_test.dart` ;
- `maintenance/implementation/lot-5-groups.md`.

Les deux fichiers touchés par l'oracle strict `a2ab5ab..b01ceae` ont enfin été
relus intégralement :

- `test/group_constraints_test.dart` ;
- `maintenance/implementation/lot-5-groups.md`.

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
- cycle de vie : inscription, groupe identique, contrôleurs distincts égaux,
  transfert, passage à `null`, retrait et dispose couverts par les régressions
  ciblées et le mutant `!=` ;
- erreurs : validation avant publication et frontière non transactionnelle
  après publication ;
- ressources : aucun painter de projection, tests lifecycle/leak verts ;
- qualité des oracles : mutants discriminants, métrique RichText réelle,
  comparaison exacte, conservation non transactionnelle observée avant toute
  republication et deux SDK exacts.

Aucune zone du périmètre demandé ne reste invérifiée. Les probes, mutants et
fichiers temporaires ont été supprimés. Avant la mise à jour de ce rapport,
`git status`, `git diff --check` et le diff des fichiers produit/tests étaient
vides ; le commit de contre-revue ne contient donc que ce document. Le verdict
`REJETÉ` de la tête `577b83f` est supersédé par le présent verdict : le produit
reste correct et l'oracle strict couvre maintenant le rollback complet qui
motivait le P1.
