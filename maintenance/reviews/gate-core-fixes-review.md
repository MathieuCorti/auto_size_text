# Revue indépendante des corrections de la Gate Cœur

Date : 2026-09-01

Branche revue : `codex/review-gate-core-fix`

Base exacte S6 : `b07066ffe321dff059c9d7d8008b2713e30e1aee`

Tip produit, tests et journal revu :
`17d9a35bd232b6678cb3daa11ee571119411f5d8`

Plage relue : `b07066f...17d9a35`

## Verdict

**ACCEPTÉ**

La correction produit de maintenance incrémentale du minimum reste correcte.
Je n'ai trouvé aucun P0, P1, P2 ou P3 à la tête finale, aucune dérive de
`L/P/G/R`, de callback, de transfert ou d'API, et aucun revert produit n'est
justifié.

Le P3 de la première passe sur `wrapWords:false/maxLines:null` est clos par
`9431a03` et `353e994`. Le signal externe sur la fidélité du harness est lui
aussi clos : le helper ne reconstruit plus un `TextPainter` à partir d'un
`Text` source incomplet, mais à partir du `RenderParagraph` monté et résolu par
Flutter. Tous ses appelants ont été migrés. `17d9a35` consigne correctement
ces deux reprises sans toucher au produit ni aux tests de groupe.

## Findings ordonnés

- P0 : aucun.
- P1 : aucun.
- P2 : aucun.
- P3 : aucun.

### P3 précédent — clos

La première passe avait prouvé qu'un mot Ahem trop large, avec
`wrapWords:false` et `maxLines:null`, était refusé par le produit mais accepté
par l'ancien helper. La régression permanente de
`test/text_fit_oracle_test.dart` monte maintenant un vrai `Text`, vérifie que
le `RenderParagraph` résolu conserve `maxLines == null`, puis exige le refus de
la coupure d'urgence.

`renderParagraphFits` mesure chaque plage indivisible sur un painter sans
largeur maximale, indépendamment de la limite publique de lignes. Le mutant
qui supprime cette mesure rend le nouveau test rouge avec
`Expected: false, Actual: true`. Le cas non nul reste couvert séparément par
`test/maxlines_test.dart` : omettre `paragraph.maxLines` du painter de
paragraphe donne le même échec. Le finding et son claim documentaire sont donc
clos sans modification produit.

### Signal externe P2 du harness — clos

L'ancien `doesTextFit(Text, ...)` reconstruisait seulement une partie de la
configuration et pouvait diverger du widget réel sur la direction et le
scaler ambiants, le strut résolu, la locale, `textWidthBasis`,
`textHeightBehavior`, le soft-wrap, l'overflow et les contraintes. Il pouvait
aussi masquer `maxLines:0` en le clampant dans une valeur autorisée.

Le nouveau témoin reçoit un `RenderParagraph` produit par un `Text` réellement
monté. `_resolvedTextPainter` transmet toutes les propriétés de mesure
résolues ; le verdict utilise les contraintes effectives du render object.
`maxLines:0` est désormais rejeté par l'assertion publique de Flutter avant
l'appel du helper. Les sept appels de `renderParagraphFits` couvrent les deux
bornes de lignes, la sélection de preset, le cycle de vie des painters et les
configurations ambiantes. Aucun appel à `doesTextFit` ne subsiste.

## Invariant du minimum de groupe

L'invariant relu et challengé est :

```text
reports[m] = +∞                si m est inscrit mais n'a rien publié
reports[m] = P_m fini >= 0     après publication valide
G = min des rapports finis     s'il en existe
G = +∞                         sinon
```

Les sorties invalides du scaler sont rejetées avant `_updateFontSize`. Le
marqueur `+∞` ne peut donc pas être confondu avec un vrai rapport. Les quatre
classes de transition préservent l'invariant.

### Inscription

`_register` ajoute seulement `m -> +∞`. Ajouter un élément non publié ne peut
ni diminuer ni augmenter le minimum des rapports finis. Le transfert retire
d'abord l'ancien rapport, inscrit ensuite ce marqueur dans le nouveau groupe,
remet le cache de publication à `null`, puis le build courant publie un nouveau
`P` local.

### Publication ou mise à jour

Après mémorisation du nouveau rapport :

1. si `new < G`, `new` est nécessairement le nouveau minimum ; l'affectation
   directe est exacte et ne demande aucun scan ;
2. si l'ancien rapport n'était pas égal à `G` et que `new >= G`, un autre
   membre conserve le minimum ; aucun scan n'est nécessaire ;
3. si l'ancien rapport était égal à `G` et que `new == old`, rien ne change ;
4. si l'ancien rapport était égal à `G` et baisse, le cas 1 s'applique ;
5. s'il était égal à `G` et monte, lui seul peut avoir libéré le minimum : le
   scan de la map mise à jour retrouve soit un ex aequo survivant, soit le
   minimum suivant, soit `+∞`.

Cela couvre première publication, baisse, hausse d'un non-minimum, hausse du
minimum unique et hausse d'un minimum ex aequo. Les comparaisons sont exactes,
comme le contrat des tailles effectives ; aucune tolérance du domaine candidat
n'est introduite.

### Retrait

Retirer un rapport non minimal ne change pas `G`. Retirer `+∞` ne change pas
le minimum des rapports finis et ne doit pas scanner. Retirer un rapport fini
égal à `G` est le seul cas où le minimum peut monter ; le scan après retrait
gère le minimum suivant, un ex aequo et l'absence de rapport fini. Le retrait
du dernier membre fini recalcule ainsi `G` vers `+∞`. Si la map devient vide,
la garde historique évite une notification sans destinataire ; une tâche déjà
pending se consomme toujours sans callback fantôme.

### Notification et coalescence

Le delta ne change ni `_scheduleNotification`, ni `_notifyListeners`. Comme le
nouvel algorithme calcule le même `G` exact avant/après chaque transition,
`oldFontSize != _fontSize` planifie les mêmes vagues que S6. Le pending est
posé avant `scheduleMicrotask`, le snapshot est pris au run, et présence dans
la map puis `mounted` sont revérifiés juste avant chaque callback.

La baisse, les deux remontées synchrones, le retrait, le dispose avant run, le
transfert entre contrôleurs égaux mais distincts et le passage à `null` restent
donc soumis aux mêmes bornes. Les suites lifecycle et les frames témoins n'ont
montré ni second run, ni callback depuis l'ancien groupe, ni frame résiduelle.

## Absence de dérive `L/P/G/R`, API et lots amont

Le seul fichier produit modifié est `lib/src/auto_size_group.dart`. Les appels
et unités restent inchangés :

```text
L = candidat local calculé sans G
P = U.scale(L), valeur finie publiée dans reports
G = minimum exact des P publiés
R = projection dans le domaine du membre sous L et G
```

`_AutoSizeTextState` continue à appeler `_updateFontSize` uniquement avec
`result.effectiveFontSize`, avant de projeter avec `group._fontSize`. Aucun
chemin ne publie `R`, aucun scaler n'est inversé, aucun fitter ou painter n'est
ajouté au groupe, et `overflowReplacement` dépend toujours du fit local. Le
delta ne touche ni la construction de `_CandidateSet`, ni la composition
RichText, ni les validations, ni le rendu.

`AutoSizeGroup` n'expose aucun nouveau membre public. La map, le minimum et la
coalescence restent les trois seules composantes privées de son état. Les
exclusions dry/intrinsics, `WidgetSpan`, démo et nouvelle API restent intactes.

## Audit des tests, du harness et du journal

### Régressions de maintenance du minimum

`test/group_minimum_maintenance_test.dart` utilise des clés stables, des
presets uniques ou descendants et des textes vides qui rendent la publication
locale déterministe. Les cinq tests couvrent :

- premières vagues ascendante et descendante ;
- baisse sous `G` ;
- hausse d'un non-minimum, puis révélation de sa valeur après retraits ;
- hausse du minimum unique ;
- ex aequo, retrait d'un non-minimum puis des minima ;
- retour à `+∞` et nouvelle publication après groupe vide ;
- absence de frame résiduelle aux points discriminants.

Les assertions sont black-box et peuvent réellement échouer. Les mutants de
hausse sans scan et de remplacement direct d'un minimum ex aequo sont rouges
dans ces tests. La preuve de coût reste à juste titre un probe retiré : ajouter
une API ou des compteurs produit permanents pour la seule performance serait
une moins bonne frontière.

### Dettes maxLines, témoin résolu et whitespace

Le test auparavant vide de `maxLines == null` monte maintenant un vrai
paragraphe Ahem multi-ligne, exige une hauteur supérieure à une ligne et
`didExceedMaxLines == false`. Il est substantiel.

Le test du helper avec `maxLines:4` est lui aussi discriminant : omettre
`paragraph.maxLines` du painter donne `true` au lieu de `false`. La régression
`maxLines:null` tue séparément la suppression de la mesure des plages
indivisibles. Les deux branches du bug historique sont donc closes.

Les anciens appels de sélection des presets, de forwarding de `maxLines` et
de cycle de vie ont tous été migrés vers le paragraphe monté. Le nouveau fichier
`text_fit_oracle_test.dart` vérifie aussi le rejet de zéro et les valeurs
résolues de direction, locale, scaler, largeur/hauteur de texte et strut. Les
mutants scaler et strut sont rouges ; les deux painters restent libérés dans
des `finally`.

Les deux espaces finaux de l'oracle candidat sont effectivement les seuls
changements de ce document. `git diff --check b07066f...17d9a35` et le diff
courant sont propres.

## Probes et mutants temporaires

Toute instrumentation a été retirée avant la matrice officielle. Les blobs de
`lib/src/auto_size_group.dart`, `test/utils.dart` et
`test/text_fit_oracle_test.dart` ont ensuite été comparés à la tête :
respectivement `6f108ad35e12615994d95a5c0834914aa8d26186`,
`b937e06138f04b51e7dca044bd02fcb148f8fb96` et
`bb067ffffb665e2227e77ff29e5f9b4778bbad38`.

### Probes verts

Un probe widget temporaire exposait uniquement `G`, le multiset des rapports
et deux compteurs de `_recalculateFontSize`. Il a passé sur Flutter 3.41.0 et
3.47.2 :

- 80 additions, mises à jour et suppressions pseudo-aléatoires, avec à chaque
  étape égalité de `G` avec un oracle linéaire, égalité du multiset de rapports,
  aucune exception et aucune frame restante ;
- hausse d'un non-minimum : `0 appel / 0 visite` ;
- baisse sous `G` : `0 / 0` ;
- hausse du minimum : `1 / 4` ;
- retrait d'un non-minimum : `0 / 0` ;
- retrait du minimum : `1 / 2` ;
- retrait du dernier membre : `1 / 0`, puis `G=+∞` ;
- membre inscrit dont le scaler invalide lève avant publication : rapports
  `{20,+∞}`, `G=20`, puis retrait de `+∞` avec `0 / 0`.

### Mutants rouges

Les cinq mutants de la première passe ont été appliqués séparément sous
Flutter 3.41.0. Les quatre mutants du témoin final ont été rejoués sous
Flutter 3.47.2. Tous ont été retirés :

| Mutant | Rouge observé |
|---|---|
| omettre le scan lorsque le minimum monte | attendu `30/30/30`, obtenu `20/20/20` |
| affecter directement la nouvelle valeur du minimum sans traiter les ties | attendu `20/20/20/20`, obtenu `30/20/30/30` |
| rescanner après chaque publication | attendu `0/0`, obtenu `1/4` lors d'une hausse non minimale |
| rescanner après chaque retrait | attendu `0/0`, obtenu `1/3` au retrait non minimal |
| repasser `text.maxLines` à l'ancien helper | attendu `false`, obtenu `true` avec `maxLines:4` |
| supprimer la mesure des plages indivisibles | attendu `false`, obtenu `true` avec `wrapWords:false/maxLines:null` |
| omettre `paragraph.maxLines` du painter | attendu `false`, obtenu `true` avec `maxLines:4` |
| remplacer le scaler résolu par `TextScaler.noScaling` | attendu `false`, obtenu `true` |
| omettre le strut résolu | attendu `false`, obtenu `true` sous la borne de hauteur serrée |

Le probe initial produit/helper documente l'écart désormais fermé. Sur la tête
finale, les deux régressions permanentes le remplacent avec une frontière de
témoin indépendante et des mutants explicitement rouges.

## Matrice indépendante

Toolchains constatées :

```text
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
```

| Contrôle | 3.47.2 | 3.41.0 naturel | 3.41.0 downgradé |
|---|---:|---:|---:|
| résolution racine | PASS | PASS | PASS, 9 dépendances abaissées |
| résolution exemple | PASS | PASS | PASS, 1 dépendance abaissée |
| format `lib test example/main.dart` | PASS, 28 fichiers inchangés | non autoritatif | non autoritatif |
| analyse fatale `lib test example/main.dart` | PASS | PASS | PASS |
| analyse fatale de l'exemple | PASS | PASS | PASS |
| ciblés harness, groupes et fuites | 50/50 | 50/50 | 50/50 |
| suite complète | 125/125 | 125/125 | 125/125 |
| probes état/complexité/+∞ | 3/3 | 3/3 | non requis |

Les ciblés étaient :

```text
test/group_minimum_maintenance_test.dart
test/group_constraints_test.dart
test/group_test.dart
test/group_builder_test.dart
test/maxlines_test.dart
test/preset_font_sizes_test.dart
test/text_fit_oracle_test.dart
test/text_painter_lifecycle_test.dart
test/leak_tracking_test.dart
```

Les résolutions minimale naturelle et downgradée ont modifié seulement les
locks de travail générés. Le lock canonique de l'exemple a été restauré depuis
la tête puis comparé byte à byte ; son SHA-256 reste
`115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7`.

## Surface lue intégralement

Les neuf fichiers produit, tests et journal de `b07066f...17d9a35` ont été
relus entièrement, ainsi que le rapport de première passe :

1. `lib/src/auto_size_group.dart` ;
2. `maintenance/decisions/candidate-domain-oracle.md` ;
3. `maintenance/implementation/gate-core-fixes.md` ;
4. `test/group_minimum_maintenance_test.dart` ;
5. `test/maxlines_test.dart` ;
6. `test/preset_font_sizes_test.dart` ;
7. `test/text_fit_oracle_test.dart` ;
8. `test/text_painter_lifecycle_test.dart` ;
9. `test/utils.dart`.

Le contexte interactif suivant a aussi été lu intégralement :

- `lib/auto_size_text.dart`, `lib/src/auto_size_group_builder.dart`,
  `lib/src/auto_size_text.dart` et `lib/src/auto_size_text_layout.dart` ;
- `maintenance/decisions/group-projection-oracle.md` et
  `maintenance/decisions/group-lifecycle-adversarial-oracle.md` ;
- `maintenance/implementation/lot-5-groups.md` ;
- les rapports `lot-5-groups-review.md`,
  `lot-5-groups-lifecycle-review.md`,
  `lot-5-groups-projection-review.md` et `lot-5-groups-assembly.md` ;
- `test/group_constraints_test.dart`, `test/group_test.dart`,
  `test/group_builder_test.dart` et `test/wrap_words_test.dart` ;
- les skills `find-bugs` et `developing-flutter`, avec les cinq références de
  ce dernier.

Aucun fichier `AGENTS.md` n'existe dans le worktree. Les instructions
`AGENTS.md` fournies avec la tâche ont été lues ; leur section PostHog n'est
pas applicable à cette revue locale sans opération PostHog.

## Audit de surface et sécurité

La surface produit modifiée reçoit seulement un état Flutter déjà inscrit et
un rapport `double` validé par le wrapper de scaler. Elle modifie une map
locale, son minimum et la décision de planifier la microtâche existante. Le
seul appel externe est le scheduling Flutter déjà présent. Les autres fichiers
sont des tests, un helper local et de la documentation.

Checklist complète :

- **injection et XSS** : hors surface, aucune commande, requête ou sortie HTML ;
- **authentification, autorisation/IDOR, CSRF et session** : hors surface ;
- **cryptographie et secrets** : hors surface, aucune donnée sensible ou log ;
- **divulgation d'information** : aucun nouveau message runtime ni canal ;
- **courses/TOCTOU** : ordre write/recalcul/schedule, pending, snapshot au run,
  revalidation de présence, transfert et dispose vérifiés ; aucun défaut ;
- **disponibilité/DoS** : O(1) pour nouvelle publication, baisse et mutation
  non minimale ; O(M) uniquement lorsqu'un minimum peut monter ; aucune
  structure auxiliaire ou allocation proportionnelle nouvelle ;
- **logique métier** : invariant de `G`, ties, `+∞`, invalides, dernier membre,
  coalescence et `L/P/G/R` vérifiés ; aucun finding résiduel ;
- **ressources** : aucun nouveau painter produit ; les deux painters du helper
  sont libérés dans `finally`, et les suites lifecycle/leak sont vertes.

Le navigateur/web et l'AOT n'ont pas été rejoués : ils ne font pas partie de la
matrice Gate Cœur demandée et le delta produit n'introduit aucune conversion
ou primitive numérique spécifique au runtime. Aucune autre zone demandée
n'est restée non vérifiée.

## Nettoyage

Les compteurs, getters de probe, tests temporaires et neuf mutants ont été
supprimés. Les `.dart_tool`, builds et lock racine généré ont été supprimés.
Avant mise à jour du présent rapport, `git status` était propre,
`git diff --check` passait, les fichiers produit et groupes étaient
byte-identiques à `9ec35e9`, et le lock suivi de l'exemple conservait son hash.
Le commit de revue doit contenir uniquement ce document.
