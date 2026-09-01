# Revue indépendante du lot 4 — RichText fidèle et Unicode

Date : 2026-09-01

Branche revue : `codex/review-rich-text`

Parent exact S4 : `3a1c343e88325b0020452be7c3258a902d87558f`

Candidat initial : `719d6a8df5f699b9ac8963dfb3034e56f71d12ad`

Correctif source : `413ea87b156c2512f01fe39cc2bad524eca9b333`

Correctif contre-revu dans ce worktree :
`482b56e7431130f0d46f2652652120c5c174548a`

Plages revues : `3a1c343...719d6a8`, puis `719d6a8...482b56e`

Périmètre : arbre de mesure et rendu RichText, scaling par run, référence
racine zéro, overrides de métriques, `wrapWords: false`, UTF-16, bidi,
NBSP/NNBSP, métadonnées, identité et mutation, `textKey`, replacement,
frontière transitoire `WidgetSpan`, compatibilité texte simple/groupes legacy,
cycle de vie et complexité. La contre-revue n'a écrit aucun correctif produit
ou test ; le présent rapport mis à jour est son seul livrable.

## Verdict

**ACCEPTÉ.**

Le correctif ferme le seul finding bloquant de la première revue. Le texte
visuel et ses ranges sont maintenant matérialisés une fois par invocation de
`_calculateFontSize`, avant `findLargestThatFits`, dans un snapshot local dont
la liste est non modifiable. `wrapWords: true` court-circuite la factory et
n'effectue aucun aplatissement. Aucun cache, champ d'état ou objet partagé
entre builds n'a été ajouté.

Le comportement fonctionnel principal reste intact : parent synthétique,
formule par run `U(S × C / F)`, branche `F == 0`, clone exhaustif des
`TextSpan` standards, identité des sous-types, arbre source pré-override,
offsets UTF-16, somme de toutes les boxes bidi, NBSP/NNBSP, replacement,
`textKey`, groupes legacy et frontière bornée `WidgetSpan`. Aucun finding
actionnable ne reste ouvert dans le diff corrigé.

## Finding initial résolu

### P1 clos — segmentation unique hors de la recherche de candidats

**Fichiers :**

- `lib/src/auto_size_text.dart:468-504` ;
- `lib/src/auto_size_text.dart:516-541` ;
- `lib/src/auto_size_text_layout.dart:87-98` ;
- `test/wrap_words_test.dart:6-29` et `325-385`.

`_calculateFontSize` construit un `final unbreakableTextSnapshot` avant la
closure de recherche. Le ternaire est paresseux : avec `wrapWords: true`, sa
valeur est `null` et `_UnbreakableTextSnapshot.from` n'est pas appelée. Avec
`false`, la factory appelle exactement une fois
`toPlainText(includeSemanticsLabels: false)`, scanne la chaîne, puis copie les
seuls couples `[start, end)` dans une `List<TextRange>.unmodifiable`.

Le snapshot reste une variable locale du calcul en cours et est seulement
passé en lecture à `_checkTextFits`. Chaque candidat conserve son propre
painter, son propre layout et ses propres requêtes de boxes ; seules la chaîne
et la segmentation indépendantes de `C` sont sorties de la boucle. Il n'existe
ni champ, ni singleton, ni memoization par span ou candidat. Un nouveau build,
un changement d'override ou un nouveau span reconstruit donc exactement un
snapshot neuf.

L'entrée du snapshot ne dérive pas du paragraphe mesuré. Pour le texte riche,
elle est le span de mesure fidèle après éventuel override ; pour le texte
simple, elle est un unique `TextSpan(text: widget.data)`. Le parent synthétique
de la boucle n'ajoute aucun texte aux cas riches et porte exactement
`widget.data` aux cas simples. Overrides, candidat et scaler ne changent pas
les code units. Les ranges restent ainsi identiques à ceux de l'ancien painter
pour chaque candidat, sans flattening de l'arbre utilisé pour les boxes.

### Régression permanente et preuve rouge/verte

Le test permanent utilise un sous-type privé de `TextSpan` qui surcharge
`computeToPlainText` et incrémente un compteur extérieur. Sa grille
`0.1..100000000` impose 30 évaluations logarithmiques ; une boîte `0 × 0` et
un `overflowReplacement` empêchent un `RenderParagraph` final de polluer le
compteur. Les quatre pumps vérifient successivement :

1. `wrapWords: true` : 0 appel ;
2. première configuration `false` : total 1 ;
3. nouvel override de letter spacing : total 2 ;
4. nouveau span source : total 3.

Pour prouver que ce test détecte réellement le défaut, le fichier final
`test/wrap_words_test.dart` a été superposé à une archive propre de
`719d6a8`, sans le correctif produit, puis le test seul a été exécuté :

```text
Flutter 3.41.0 : Expected <1>, Actual <30>
Flutter 3.47.2 : Expected <1>, Actual <30>
```

Le même test est vert sur `482b56e` dans les deux suites ciblées. Cette preuve
tue directement le mutant initial et ne repose ni sur un seuil mural, ni sur
un helper privé, ni sur le corpus alterné fonctionnel.

## Audit fonctionnel du diff

### Parent synthétique, topologie et mutation

Pour la mesure riche, `sourceTextSpan` devient l'enfant unique d'un
`TextSpan` synthétique qui porte le style effectif. Le texte de la racine
source reste avant ses enfants, l'ordre et la profondeur ne sont pas aplatis,
et le painter reçoit l'arbre riche complet. Sans override de métrique,
`_applyTextStyleOverride` rend exactement le span source ; le même objet et
ses listes restent donc sous propriété de l'appelant.

Sous override, le code ne reconstruit que les objets dont
`runtimeType == TextSpan`. Il produit une nouvelle liste par occurrence et
recopie exactement les champs présents dans Flutter 3.41.0 et 3.47.2 :
`text`, `children`, `style`, `recognizer`, `mouseCursor`, `onEnter`, `onExit`,
`semanticsLabel`, `semanticsIdentifier`, `locale` et `spellOut`. Les callbacks,
recognizers, curseurs, sous-types inconnus et `WidgetSpan` restent identiques.
Un alias standard répété est cloné séparément comme dans Flutter ; l'arbre
source et ses listes non modifiables ne sont jamais écrits.

Un probe temporaire avec le même `TextSpan` standard présent deux fois sous un
override a confirmé deux clones de sortie distincts, deux occurrences dans le
même ordre et les deux références source inchangées. Il a aussi confirmé le
plateau `F == 0` avec presets `[20, 10]` : le plus grand candidat est conservé
et les descendants explicites ne sont pas multipliés.

### Scaler par run, zéro et overrides

Pour `F > 0`, `_CandidateTextScaler.scale(S)` calcule exactement
`U.scale(S × C / F)`, après validations finies/non négatives. Le même type de
scaler composé est fourni au painter et au `Text` final. Un probe riche à deux
candidats, `F=20`, descendant `S=40` et
`U(x)=x+x²/100` choisit `C=10`, rend le parent à 11 et le descendant à 24 ; il
écarte la linéarisation globale qui donnerait 22.

Pour `F == 0`, le parent de mesure et le style de rendu reçoivent directement
`fontSize: C`, tandis que le scaler reste `U`. Les tailles explicites des
descendants, zéro compris, ne changent pas. Aucun `C/F`, epsilon ou
`TextScaler.noScaling` implicite ne se trouve sur le chemin non groupé.

Le snapshot sépare bien le style de mesure post-override du style de rendu
pré-override. Les descendants standards de mesure reçoivent la même fusion que
le helper Flutter ; le `Text.rich` final reçoit le span source et laisse
Flutter appliquer les overrides une seule fois. Le test à deux candidats
discrimine cette application par sa taille choisie et ses boxes.

### `Text`, `textKey`, replacement et compatibilité antérieure

La branche active continue de retourner exactement un widget `Text` ou
`Text.rich` portant `textKey`. Lorsque le minimum ne tient pas et qu'un
`overflowReplacement` existe, le texte construit n'est pas monté et la clé est
absente. Les cas simples et riches à référence zéro exercent les deux branches.

Le chemin simple positif ne change pas de sémantique : le span candidat est
seulement reconstruit dans la closure. La branche simple zéro est corrigée pour
mesurer avec le scaler utilisateur au lieu de prétendre qu'un candidat nul ou
positif est sans scaling. Le transport de la taille effective et le rendu
`noScaling` des groupes legacy restent inchangés ; les suites historiques de
groupe passent dans les 96 tests sur les deux SDK.

### `wrapWords: false`, UTF-16 et bidi

La fonction de ranges fait un scan par matches de `RegExp(r'\s')`, conserve
exactement U+00A0 et U+202F dans la plage, coalesce les séparateurs ordinaires
consécutifs et ne produit aucune plage vide. Les offsets de `String.length`,
`RegExpMatch` et `TextSelection` sont tous des offsets UTF-16. Le texte du
painter n'est jamais aplati : seule la chaîne servant aux offsets l'est, avec
`includeSemanticsLabels: false`.

Par candidat, le code crée un seul painter auxiliaire non wrappé, le dispose
dans un `finally`, puis effectue au plus une requête de boxes par plage avec
retour anticipé. La largeur est la somme de
`abs(box.right - box.left)` sur toutes les boxes, ce qui est correct pour une
sélection bidi disjointe et ne facture pas l'espace physique entre les boxes.
Il n'existe ni painter par plage, ni substring, ni reconstruction monostyle.

Le scan préparatoire est désormais unique par build. La classification, les
unités, le nombre de painters par candidat et le calcul de largeur n'ont pas
changé ; les tests fonctionnels antérieurs et la suite lifecycle restent verts.

### Frontière `WidgetSpan`

`_containsWidgetSpan` parcourt l'arbre avant tout painter et transforme
l'assertion Flutter opaque sur les dimensions absentes en `UnsupportedError`
du package. Le message dit seulement que `AutoSizeText.rich` ne supporte pas
actuellement `WidgetSpan` tant que les dimensions automatiques des enfants
inline n'existent pas ; il ne mentionne ni version, ni calendrier, ni
dimension zéro/estimée. Aucun placeholder n'est créé et aucun support de
layout, scaling, paint, hit test, sémantique, dry ou intrinsics n'est revendiqué.

La transformation de spacing laisse statiquement tout `WidgetSpan` identique,
et le test public confirme que l'objet source n'est ni muté, ni remplacé avant
l'erreur. Cette défense transitoire ne ferme pas CORE-01 ou #61/#106 et ne
débloque aucune release avant le lot 10.

## Reproduction des rouges sur S4

Les deux fichiers de tests finaux du candidat ont été appliqués sans code
produit à une archive propre du parent exact `3a1c343`, puis exécutés sous
Flutter 3.47.2. Résultat : **11 passages et 9 échecs** sur 20.

Les neuf tests rouges couvrent les causes attendues :

1. héritage du parent effectif par une racine partiellement stylée (`30` au
   lieu de `20`) ;
2. overrides de spacing pris en compte par la mesure (`20` au lieu de `10`) ;
3. NBSP/NNBSP liés (`20` au lieu de `10`) ;
4. chaîne mixte liée sans normalisation (`20` au lieu de `10`) ;
5. somme des boxes bidi (`20` au lieu de `10`) ;
6. référence riche zéro avec minimum positif (`ArgumentError` sur `F=0`) ;
7. référence riche zéro avec minimum nul (même `ArgumentError`) ;
8. replacement fondé sur les runs réels (replacement absent) ;
9. frontière `WidgetSpan` (`AssertionError dimensions != null` au lieu de
   `UnsupportedError`).

Le test non linéaire, les métadonnées, la non-mutation et les comportements
déjà vrais sur S4 ne sont pas présentés comme rouges artificiels. Cette
reproduction concorde avec le journal du lot.

## Matrice indépendante

Toolchains vérifiées :

```text
Flutter 3.41.0 • framework 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • framework d3b14c8769 • Dart 3.13.2
```

| Gate | Flutter 3.41.0 | Flutter 3.47.2 |
|---|---:|---:|
| `rich_text_test` + `wrap_words_test` | 21/21 | 21/21 |
| suite racine complète | 96/96 | 96/96 |
| `leak_tracking` + `text_painter_lifecycle` | 9/9 | 9/9 |
| analyse scoped fatale `lib test example/main.dart` | 0 diagnostic | 0 diagnostic |
| exemple : résolution conforme à la politique de lock puis analyse fatale | succès, 10 dépendances naturelles, aucun diagnostic | lock haut forcé, aucun diagnostic |
| downgrade racine puis suite `--no-pub` | 9 dépendances abaissées, 96/96 | lock déjà au minimum, aucun changement, 96/96 |
| test permanent segmentation sur `482b56e` | vert : 0 puis exactement 1 par configuration | vert : 0 puis exactement 1 par configuration |
| même test superposé à `719d6a8` | rouge : attendu 1 / réel 30 | rouge : attendu 1 / réel 30 |

Le format autoritatif Dart 3.13.2 contrôle 25 fichiers de `lib`, `test` et
`example` sans changement. Dart 3.11.0 contrôle séparément les quatre fichiers
Dart du lot sans changement.

`git diff --check 632edad...482b56e` passe. L'archive de preuve rouge et
l'extraction SDK minimum sont isolées sous `/private/tmp` ; aucun fichier de
probe ne reste dans le worktree. Avant mise à jour de ce rapport, l'arbre Git
était propre. Les quatre fichiers du cherry-pick sont byte-for-byte identiques
à ceux du correctif source `413ea87`.

## Surface lue intégralement

Les quatre fichiers du correctif ont été relus intégralement :

1. `lib/src/auto_size_text.dart` ;
2. `lib/src/auto_size_text_layout.dart` ;
3. `maintenance/implementation/lot-4-rich-text.md` ;
4. `test/wrap_words_test.dart`.

La contre-revue a aussi relu le rapport initial en entier. La revue précédente
avait déjà lu intégralement le cinquième fichier original,
`test/rich_text_test.dart`, ainsi que les versions parentes des fichiers
produit.

Ont aussi été lus avant conclusion : les instructions Developing Flutter,
Effective Dart, Testing et `find-bugs` ; le lot 4 et les gates de la roadmap ;
la revue finale de roadmap ; l'oracle RichText ; l'oracle adversarial corrigé
au commit `0a4b60d` de `codex/impl-integration` ; les journaux des lots 0 à 3 ;
les revues finales des lots 0 à 3, y compris accessibilité, fixtures et
assemblage d'intégration ; et les implémentations exactes de `Text.build`, du
clone d'override, `TextSpan` et `WidgetSpan` dans Flutter 3.41.0 et 3.47.2.

## Cartographie d'attaque et checklist `find-bugs`

Les entrées produit du diff sont le texte, l'arbre `TextSpan`, les styles,
scalers, contraintes, options de wrap et configuration Flutter héritée. Les
effets sont limités au layout local, au rendu, aux callbacks de spans et à la
publication locale d'une taille de groupe. Le lot n'ajoute aucune requête de
base de données, authentification, autorisation, session, primitive
cryptographique, secret, commande externe, lecture/écriture de fichier ou
appel réseau.

| Classe de risque | Conclusion |
|---|---|
| Injection SQL/commande/template/header et XSS | Hors surface ; aucun interpréteur, HTML ou appel externe. |
| Authentification, autorisation/IDOR, CSRF et session | Hors surface ; aucune identité ou ressource distante. |
| Race / TOCTOU / état | Aucun nouvel état partagé ; rebuilds, source immuable et groupes legacy exercés. |
| Cryptographie, secrets et divulgation | Hors surface ; aucune donnée sensible ou log runtime ajouté. |
| Ressources / disponibilité | Painters disposés, recherche logarithmique et scan `O(N)` unique par build ; test compteur discriminant vert. |
| Logique numérique | Composition non linéaire, zéro, plateau, validations et exactitude candidat/rendu conformes. |
| Unicode / logique métier | Offsets UTF-16, NBSP/NNBSP, bidi multi-box et labels sémantiques conformes ; split-surrogate invalide par run correctement exclu. |
| Compatibilité API | Aucun nouveau symbole public ; `Text`, `textKey`, ancienne API de scaler et groupes legacy conservés. |

## Limites de la revue

La revue n'exécute ni appareil physique, ni web, ni AOT release, surfaces sans
comportement spécifique introduit par ce lot. Elle ne prétend pas borner la
complexité interne de `Paragraph.getBoxesForRange`; seule la structure visible
du package est auditée. Le nombre exact de requêtes de boxes n'est pas
injectable par l'API Flutter, mais la boucle source montre au plus une requête
par range et candidat avec retour anticipé.

Les intrinsics, dry layout et le support automatique de `WidgetSpan` restent
hors lot et volontairement non testés comme comportements verts. Aucun merge,
push, tag, publication ou mutation distante n'a été effectué.
