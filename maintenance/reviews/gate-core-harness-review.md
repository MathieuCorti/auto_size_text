# Gate Cœur — contre-revue tests, harness et hygiène

Date : 2026-09-01

Base S1 : `e9f75af9c3ef54bee2cbd3fcc0a53b44e7811968`

Base corrective S6 : `b07066ffe321dff059c9d7d8008b2713e30e1aee`

Tête revue : `9ec35e9f1481d346c7df5516de618b151de95097`

Périmètre correctif : `b07066f..9ec35e9`, soit six fichiers. La plage
d'hygiène cumulative contrôlée est `e9f75af..9ec35e9`.

## Verdict

**BLOCKED pour la clôture de la dette de harness ; PASS pour le correctif
produit de maintenance du minimum de groupe.**

Aucun finding P0 ou P1 n'est confirmé. Le finding P2 ci-dessous n'affecte pas
le comportement livré d'`AutoSizeText`, et les preuves cœur antérieures qui
observent directement `RenderParagraph` restent valides. Il bloque toutefois
le commit `4883bb0` en tant que réparation complète du harness :
`doesTextFit(..., wrapWords: false)` continue à produire des verdicts
contraires au produit, et son nouveau test permanent ne compare jamais le
helper au produit.

La correction `AutoSizeGroup` est conforme à l'oracle. Le parent S6 parcourt
64 fois 64 rapports pendant la première vague ; la tête ne rescane aucun
rapport. Les tests permanents tuent les mutants sémantiques de remontée du
minimum et d'ex aequo. Les probes compteurs tuent les rescans inconditionnels
à la publication et au retrait d'un non-minimum.

## Findings

### P2 — `doesTextFit(wrapWords: false)` n'est pas un oracle du produit

**Fichiers :** `test/utils.dart:18-31`, `test/maxlines_test.dart:62-73`.

Le helper remplace `maxLines` par `clamp(1, wordCount)`, puis mesure le texte
normalement dans la largeur disponible. Le produit suit un autre contrat dans
`lib/src/auto_size_text.dart:476-600` : il mesure d'abord chaque plage
indivisible avec un painter non wrappé, conserve ensuite le `maxLines` effectif
inchangé, et utilise une configuration résolue depuis le contexte. Les deux
algorithmes ne sont pas équivalents.

Un témoin temporaire, vert à l'identique sur Flutter 3.41.0 et 3.47.2, établit
quatre divergences indépendantes :

1. Avec `maxLines == null`, un mot Ahem et une largeur située exactement entre
   ses largeurs aux candidats 10 et 5, le helper accepte le candidat 10. Le
   vrai `AutoSizeText(wrapWords: false)` sélectionne 5 ; le
   `RenderParagraph` final confirme cette taille et garde `maxLines == null`.
2. Un `Text(maxLines: 0)` est transformé silencieusement en une ligne par le
   `clamp` et le helper retourne `true`. La surface publique
   `AutoSizeText(maxLines: 0)` est rejetée par l'assertion
   `maxLines == null || maxLines > 0` avant calcul. Le helper ne reflète donc
   pas non plus la précondition publique.
3. Un `Text` sans direction explicite reçoit un `StateError` du helper, alors
   que le même widget sous `Directionality` se rend. Avec une direction
   explicite mais un scaler nul, le helper substitue `noScaling` : il retourne
   `true` dans le témoin, tandis que le `RenderParagraph` sous le scaler
   ambiant 2 signale `didExceedMaxLines == true`.
4. Le helper mesure le `StrutStyle` source sans l'override ambiant de hauteur.
   Il retourne `false` sous la borne du témoin, tandis que le
   `RenderParagraph` avec `lineHeightScaleFactorOverride: 0.5` tient sous la
   même borne et expose bien un strut effectif de hauteur 0,5.

Le nouveau test permanent à `maxLines: 4` est discriminant contre l'ancienne
affectation : rétablir seulement `maxLines: text.maxLines` le rend rouge avec
`Expected: false`, `Actual: true`. Il n'est donc pas tautologique vis-à-vis de
la ligne modifiée. En revanche, il appelle uniquement le helper avec direction,
scaler et fonte explicitement fixés ; aucune instance d'`AutoSizeText` ni aucun
`RenderParagraph` témoin ne participe à son attente. Son résultat `false`
coïncide avec celui du produit pour ce corpus, mais pour deux raisons
algorithmiques différentes.

**Impact.** Aucun test fonctionnel cœur actuel ne prend une décision produit à
partir de `doesTextFit(..., false)` : le seul appel est ce test du helper
lui-même. Il n'y a donc pas de régression runtime ni d'invalidation des tests
RichText/wrapping existants. En revanche, toute réutilisation future du helper
comme oracle de `wrapWords: false` peut accepter un candidat refusé par le
produit, refuser un rendu valide, ou contourner la précondition de `maxLines`.
Le journal ne doit pas présenter cette dette comme close.

**Correction attendue.** Préférer un oracle black-box qui observe la sélection
ou le remplacement d'un vrai `AutoSizeText` et son `RenderParagraph`. Si le
helper est conservé, il doit recevoir une configuration déjà résolue, valider
`maxLines`, mesurer les plages indivisibles sans aplatir les runs, puis passer
le `maxLines` original au painter principal. Les cas `null`, zéro rejeté,
direction/scaler/strut ambiants et une borne finie doivent être permanents.

## Force du test `maxLines == null`

Le test rempli de `test/maxlines_test.dart:39-60` n'est pas entièrement
tautologique. Un mutant temporaire qui force `widget.maxLines ?? 1` sur le
`Text` final devient rouge : hauteur attendue supérieure à 20, hauteur réelle
20. Il protège donc la propagation de la limite illimitée vers le rendu.

Sa portée est néanmoins plus étroite que son nom peut le suggérer. Le preset
singleton `[20]`, l'absence d'`overflowReplacement` et l'absence d'assertion
sur la taille candidate rendent le résultat indépendant du verdict de fit.
Un mutant qui force seulement `configuration.maxLines ?? 1` dans le painter de
mesure laisse les trois tests de `maxlines_test.dart` verts. Le test démontre
donc le rendu multi-ligne final, pas la prise en compte de `null` pendant la
recherche de taille. Cette limite n'ajoute pas un second finding bloquant,
mais elle doit être conservée dans l'interprétation de la preuve.

## Revue des tests de minimum de groupe

`test/group_minimum_maintenance_test.dart` utilise uniquement la surface
publique : `AutoSizeGroup`, `AutoSizeText`, clés stables, presets singleton et
lecture du `Text` rendu. Il n'accède à aucun membre privé et ne dépend d'aucun
chronomètre. Deux `pump` bornés laissent les microtâches et frames converger ;
aucun `pumpAndSettle`, timeout ou attente murale n'est introduit.

Les scénarios permanents couvrent bien :

- premières vagues ascendante et descendante ;
- baisse sous le minimum ;
- stockage de la hausse d'un non-minimum puis sa révélation après retraits ;
- remontée du détenteur du minimum ;
- ex aequo survivant ;
- retrait d'un minimum et d'un non-minimum ;
- retrait du dernier membre fini, retour à l'infini et nouvelle publication.

Les textes vides et presets singleton isolent volontairement le rapport de
groupe des métriques de paragraphe. L'oracle lit la taille effective publique
du `Text` et compare des valeurs attendues indépendantes ; il ne recalcule pas
le minimum avec l'algorithme produit.

Mutants rejoués dans une extraction temporaire 3.47.2 :

| Mutant | Rouge observé |
|---|---|
| ne pas rescanner lorsque l'ancien minimum remonte | attendu `[30,30,30]`, obtenu `[20,20,20]` |
| remplacer directement `G` par la nouvelle valeur | attendu `[30,30,30]`, obtenu `[40,30,40]`; le cas tie obtient `[30,20,30,30]` |
| rescanner au retrait de tout rapport fini | probe retrait : attendu 0 appel, obtenu 1 |
| rescan inconditionnel à chaque publication, parent S6 exact | première vague : 64 appels et 4 096 visites au lieu de 0/0 |

Après restauration, la tête donne 0 appel et 0 visite sur la première vague et
sur le retrait d'un non-minimum. Le probe n'utilise que 64 `AutoSizeText`
publics dans un `Stack`; les compteurs instrumentent temporairement l'appel et
la boucle, sans temps mural. Aucun compteur ou probe ne reste dans la branche
canonique.

## Rouge parent et vert tête

| Preuve | Parent/mutant | Tête |
|---|---:|---:|
| affectation du `maxLines` calculé dans le helper | rouge, `false` attendu / `true` obtenu | `maxlines_test.dart` 3/3 |
| complexité première vague, S6 exact | rouge, 64 appels / 4 096 visites | vert, 0/0 |
| suites groupe et lifecycle ciblées | mutants sémantiques rouges | 36/36 sur les deux pins |
| suite canonique complète | non applicable | 121/121 sur les deux pins et sur le graphe minimum downgradé |

La preuve du helper confirme la correction mécanique de l'affectation, mais
pas son exactitude sémantique ; c'est précisément l'objet du finding P2.

## Matrice indépendante

Toolchains réellement exécutées :

- Flutter 3.47.2, révision `d3b14c8769`, Dart 3.13.2 ;
- Flutter 3.41.0, révision `44a626f4f0`, Dart 3.11.0.

| Contrôle | 3.47.2 | 3.41.0 naturel | 3.41.0 downgradé |
|---|---:|---:|---:|
| résolution hors ligne | PASS | PASS | PASS, 9 dépendances abaissées |
| format haute `lib test example` après résolution | 27 fichiers, 0 changement | non autoritatif | non autoritatif |
| analyse fatale `lib test example/main.dart` | PASS | PASS | PASS |
| ciblés maxLines, groupes et lifecycle | 36/36 | 36/36 | 36/36 |
| suite canonique complète | 121/121 | 121/121 | 121/121 |
| témoin temporaire helper/RenderParagraph | 4/4 | 4/4 | non rejoué après downgrade |
| probe compteur première vague | 0/0 | journal recoupé par les suites | non requis |

Le `pub get` minimum a adapté le lock de l'exemple uniquement dans
l'extraction temporaire (`meta 1.17.0`, `vector_math 2.2.0`). Le downgrade a
ensuite conservé ce graphe exemple naturel. Le lock canonique n'a pas été
touché et garde le SHA-256
`115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7`.

## Hygiène de plage

- `git diff --check e9f75af..9ec35e9` : PASS ;
- `git diff --check e9f75af...9ec35e9` : PASS ;
- 53 fichiers sur la plage S1→tête, aucun sous `demo/` ou `example/`, aucun
  lock ;
- six fichiers seulement sur S6→tête, conformément au journal ;
- format autoritatif exécuté après résolution haute, zéro changement ;
- aucun changement d'API publique, de fixture binaire, de démo ou de lock dans
  la sous-plage corrective ;
- aucun probe, mutant, compteur ou cache créé dans le worktree canonique ;
- avant ce rapport, `git diff -- lib test example`, la liste des fichiers non
  suivis et `git status --short` étaient vides.

## Fichiers lus et audit pré-conclusion

Fichiers de la sous-plage corrective lus intégralement, état final et diff :

1. `lib/src/auto_size_group.dart` ;
2. `maintenance/decisions/candidate-domain-oracle.md` ;
3. `maintenance/implementation/gate-core-fixes.md` ;
4. `test/group_minimum_maintenance_test.dart` ;
5. `test/maxlines_test.dart` ;
6. `test/utils.dart`.

Contexte relu : `lib/src/auto_size_text.dart` intégralement, les primitives de
plages/candidats pertinentes dans `lib/src/auto_size_text_layout.dart`, les
tests `wrap_words`, lifecycle et configuration effective concernés, les trois
rapports Gate Cœur antérieurs et les sections S1/Gate Cœur de la roadmap. Les
instructions `find-bugs`, `developing-flutter` et toutes ses références ont été
lues intégralement. Aucun `AGENTS.md` additionnel n'existe dans le worktree ;
l'instruction PostHog fournie au chantier n'est pas applicable à cette revue
locale.

Checklist `find-bugs` : injection, XSS, authentification, autorisation/IDOR,
CSRF, session, cryptographie, secrets et divulgation sont hors surface ; le
delta ne contient ni réseau, ni base, ni entrée distante, ni template, ni
identité. Les catégories applicables ont été contrôlées : course et cycle de
vie des microtâches, disponibilité, opérations bornées, validations numériques
et logique d'état. Aucun défaut de course, fuite, timeout ou disponibilité ne
subsiste dans le correctif groupe. Le seul défaut confirmé est la logique
d'oracle du helper de test décrite ci-dessus.

Limites : aucun test appareil, web ou release sans assertions n'a été exécuté.
Ces surfaces ne sont pas nécessaires pour confirmer le finding de harness ni
les compteurs déterministes du groupe.

Le commit de cette contre-revue doit contenir uniquement le présent rapport.
