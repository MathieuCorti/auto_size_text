# Revue indépendante des corrections de la Gate Cœur

Date : 2026-09-01

Branche revue : `codex/review-gate-core-fix`

Base exacte S6 : `b07066ffe321dff059c9d7d8008b2713e30e1aee`

Tip produit, tests et journal revu :
`9ec35e9f1481d346c7df5516de618b151de95097`

Plage relue : `b07066f...9ec35e9`

## Verdict

**CHANGEMENTS REQUIS**

La correction produit de maintenance incrémentale du minimum est correcte.
Je n'ai trouvé aucun P0, P1 ou P2 dans `AutoSizeGroup`, aucune dérive de
`L/P/G/R`, de callback, de transfert ou d'API, et aucun revert produit n'est
justifié.

Un P3 du harness reste toutefois ouvert. Quand `wrapWords` vaut `false` et
que le `Text` témoin a `maxLines == null`, `doesTextFit` laisse désormais le
`TextPainter` accepter les coupures d'urgence à l'intérieur d'un mot. Le
helper peut donc déclarer qu'un texte tient alors que le produit le refuse.
Le nouveau test couvre seulement la branche où `maxLines` est non nul, et le
journal décrit à tort la branche nulle comme correcte. Une correction limitée
au harness, à sa régression et au journal suffit pour rendre cette tête
acceptable ; aucun changement produit n'est demandé par cette revue.

## Findings ordonnés

- P0 : aucun.
- P1 : aucun.
- P2 : aucun.
- P3 : un finding harness/documentation ouvert.

### P3 — `wrapWords:false` devient inexact lorsque `maxLines` est nul

**Fichiers :**

- `test/utils.dart:18-21` ;
- couverture actuelle : `test/maxlines_test.dart:62-73` ;
- claim : `maintenance/implementation/gate-core-fixes.md:92-98`.

**Problème.** Le helper calcule une borne dérivée du nombre de mots seulement
si `text.maxLines` est non nul :

```dart
var maxLines = text.maxLines;
if (!wrapWords && maxLines != null) {
  final wordCount = span.toPlainText().split(RegExp('\\s+')).length;
  maxLines = maxLines.clamp(1, wordCount);
}
```

Pour `wrapWords:false`, cette borne n'est pas la limite publique de lignes du
widget. Elle sert à détecter qu'un mot a subi une coupure d'urgence : un mot
doit occuper au plus une ligne, deux mots au plus deux lignes, etc. Même si le
nombre public de lignes est illimité, laisser le painter envelopper un mot sur
plusieurs lignes donne un faux positif au helper.

**Preuve indépendante.** Un probe temporaire a utilisé `AAAA` en Ahem 10,
une largeur 20, un preset unique 10, `wrapWords:false` et aucun `maxLines`.
Le vrai `AutoSizeText` a monté son `overflowReplacement`, donc son fit local
était faux. Le même témoin passé à
`doesTextFit(text, 20, double.infinity, false)` a renvoyé `true`. Le test
temporaire est devenu rouge sur Flutter 3.41.0 avec
`Expected: false, Actual: true`, après avoir déjà prouvé que le replacement
produit était monté.

Le test permanent ajouté à `maxlines_test.dart` utilise au contraire
`maxLines: 4`. Il tue bien le mutant qui continue à passer
`text.maxLines` au `TextPainter` (`Expected: false, Actual: true`), mais il ne
peut pas exécuter la branche `maxLines == null` de la nouvelle garde. Le test
« unlimited lines » porte sur le widget avec `wrapWords:true` par défaut et ne
ferme pas davantage ce cas.

**Correction suggérée.** Lorsque `wrapWords` est faux, dériver la borne depuis
le nombre de mots même si la limite publique est nulle, par exemple avec
`(maxLines ?? wordCount).clamp(1, wordCount)`. Ajouter une régression permanente
qui compare le helper à un `AutoSizeText` avec replacement pour un mot Ahem
trop large et `maxLines:null`, puis corriger le paragraphe du journal. Cette
modification reste exclusivement dans le harness et la documentation.

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

### Dettes maxLines et whitespace

Le test auparavant vide de `maxLines == null` monte maintenant un vrai
paragraphe Ahem multi-ligne, exige une hauteur supérieure à une ligne et
`didExceedMaxLines == false`. Il est substantiel.

Le test du helper avec `maxLines:4` est lui aussi discriminant : remettre
`maxLines: text.maxLines` dans le painter donne `true` au lieu de `false`.
Il ferme la moitié non nulle du bug historique. Le P3 ci-dessus montre que la
nouvelle garde nulle et son claim documentaire ne sont pas encore corrects.

Les deux espaces finaux de l'oracle candidat sont effectivement les seuls
changements de ce document. `git diff --check b07066f...9ec35e9` et le diff
courant sont propres.

## Probes et mutants temporaires

Toute instrumentation a été retirée avant la matrice officielle. Les blobs de
`lib/src/auto_size_group.dart` et `test/utils.dart` ont ensuite été comparés à
la tête : respectivement `6f108ad35e12615994d95a5c0834914aa8d26186` et
`789e6de8ae51b2604cf884f2169297309b10e859`.

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

Les mutants ont été appliqués séparément sous Flutter 3.41.0 puis retirés :

| Mutant | Rouge observé |
|---|---|
| omettre le scan lorsque le minimum monte | attendu `30/30/30`, obtenu `20/20/20` |
| affecter directement la nouvelle valeur du minimum sans traiter les ties | attendu `20/20/20/20`, obtenu `30/20/30/30` |
| rescanner après chaque publication | attendu `0/0`, obtenu `1/4` lors d'une hausse non minimale |
| rescanner après chaque retrait | attendu `0/0`, obtenu `1/3` au retrait non minimal |
| repasser `text.maxLines` au painter du helper | attendu `false`, obtenu `true` dans le nouveau test permanent |

Le probe supplémentaire du finding P3 n'est pas un mutant : il compare le
produit et le helper intacts et met en évidence leur divergence réelle pour
`wrapWords:false/maxLines:null`.

## Matrice indépendante

Toolchains constatées :

```text
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
```

| Contrôle | 3.47.2 | 3.41.0 naturel | 3.41.0 downgradé |
|---|---:|---:|---:|
| résolution racine | PASS | PASS | PASS, 9 dépendances abaissées |
| format `lib test example` | PASS, 27 fichiers | non autoritatif | non autoritatif |
| analyse fatale `lib test` | PASS | PASS | couvert avant downgrade |
| analyse fatale de l'exemple | PASS, lock forcé | PASS, résolution naturelle isolée | non requis |
| ciblés Gate Cœur | 35/35 | 35/35 | inclus dans la suite complète |
| suite complète | 121/121 | 121/121 | 121/121 |
| probes état/complexité/+∞ | 3/3 | 3/3 | non requis |

Les ciblés étaient :

```text
test/group_minimum_maintenance_test.dart
test/group_constraints_test.dart
test/group_test.dart
test/maxlines_test.dart
test/text_painter_lifecycle_test.dart
test/leak_tracking_test.dart
```

Le lock haut de l'exemple n'est pas consommable tel quel par la pin minimale :
la tentative forcée annonce correctement deux downgrades nécessaires. La
résolution naturelle minimale a donc été exécutée dans une extraction exacte
temporaire de `9ec35e9`, sans recopier son lock. L'analyse y est verte. Le lock
canonique reste byte-identique, SHA-256
`115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7`.

## Surface lue intégralement

Les six fichiers du diff ont été relus entièrement :

1. `lib/src/auto_size_group.dart` ;
2. `maintenance/decisions/candidate-domain-oracle.md` ;
3. `maintenance/implementation/gate-core-fixes.md` ;
4. `test/group_minimum_maintenance_test.dart` ;
5. `test/maxlines_test.dart` ;
6. `test/utils.dart`.

Le contexte interactif suivant a aussi été lu intégralement :

- `lib/auto_size_text.dart`, `lib/src/auto_size_group_builder.dart`,
  `lib/src/auto_size_text.dart` et `lib/src/auto_size_text_layout.dart` ;
- `maintenance/decisions/group-projection-oracle.md` et
  `maintenance/decisions/group-lifecycle-adversarial-oracle.md` ;
- `maintenance/implementation/lot-5-groups.md` ;
- les rapports `lot-5-groups-review.md`,
  `lot-5-groups-lifecycle-review.md`,
  `lot-5-groups-projection-review.md` et `lot-5-groups-assembly.md` ;
- `test/group_constraints_test.dart` et `test/group_test.dart` ;
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
  coalescence et `L/P/G/R` vérifiés ; finding P3 limité au helper de test ;
- **ressources** : aucun nouveau painter produit ; le painter du helper reste
  libéré dans `finally`, et les suites lifecycle/leak sont vertes.

Le navigateur/web et l'AOT n'ont pas été rejoués : ils ne font pas partie de la
matrice Gate Cœur demandée et le delta produit n'introduit aucune conversion
ou primitive numérique spécifique au runtime. Aucune autre zone demandée
n'est restée non vérifiée.

## Nettoyage

Les compteurs, getters de probe, test temporaire et cinq mutants ont été
supprimés. Les `.dart_tool`, builds, lock racine généré et extraction minimale
ont été supprimés. Avant création du présent rapport, `git status` était propre,
`git diff --check` passait et le lock suivi de l'exemple conservait son hash.
Le commit de revue doit contenir uniquement ce document.
