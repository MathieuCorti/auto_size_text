# Revue lot 4 — RichText, Unicode et sémantiques

Date : 2026-09-01

Branche revue : `codex/review-rich-text-unicode`

Candidat fonctionnel : `719d6a8df5f699b9ac8963dfb3034e56f71d12ad`

Correctif performance contre-revu :
`413ea87b156c2512f01fe39cc2bad524eca9b333`, cherry-pické dans cette branche
sous `dbe1a18`.

Tête finale revue : `dbe1a18`

Parent exact : `3a1c343e88325b0020452be7c3258a902d87558f`

Périmètre : revue indépendante spécialisée Unicode, interactions et
sémantiques du lot 4. Aucun correctif produit n'a été écrit et aucun merge,
push ou changement distant n'a été effectué.

## Verdict

**ACCEPTÉ** pour le périmètre Unicode et sémantique, y compris après le
correctif de snapshot de segmentation.

Aucun défaut fonctionnel n'a été confirmé dans ce périmètre. Les offsets
restent des code units UTF-16, les plages liées NBSP/NNBSP sont mesurées par la
somme de toutes leurs boxes, les labels sémantiques sont exclus de la
segmentation, et l'arbre riche conserve interactions, métadonnées et identité
des sous-types inconnus à travers les overrides et rebuilds.

Le cas split-surrogate corrigé n'est pas promu en oracle métrique : deux runs
individuellement mal formés signalent chacun un `ArgumentError` dans Flutter
3.41.0 comme dans Flutter 3.47.2. La fixture reste donc exclue, conformément à
l'oracle corrigé.

Le correctif performance lève le risque antérieurement signalé :
`toPlainText(includeSemanticsLabels: false)` et le scan des plages sont
effectués une seule fois par calcul de taille, pas une fois par candidat. La
contre-revue n'a trouvé aucune dérive Unicode, sémantique ou d'état entre
pumps.

## Spécifications et sources relues

Ont été lus intégralement ou, pour les grands plans, dans leur section lot 4 :

- `maintenance/decisions/rich-text-oracle.md` ;
- l'oracle adversarial corrigé à son commit exact `6251a040`, fichier
  `maintenance/decisions/rich-text-adversarial-oracle.md` ; ce commit n'est pas
  ancêtre du candidat, mais son contenu corrigé a été appliqué comme
  spécification de revue ;
- `maintenance/implementation/lot-4-rich-text.md` ;
- les sections lot 4 de `maintenance/implementation-roadmap.md` et
  `maintenance/plans/core-implementation-plan.md` ;
- les guides Developing Flutter, Effective Dart, Testing et `find-bugs`.

Les sources locales exactes suivantes ont été croisées sur Flutter 3.41.0 et
3.47.2 :

- `widgets/text.dart` : parent synthétique de `Text.build` et
  `_OverridingTextStyleTextSpanUtils` ;
- `painting/text_span.dart` : parcours préfixe, construction par run,
  `computeToPlainText`, locale, spell-out et informations sémantiques ;
- `painting/inline_span.dart` : contrat de `toPlainText` et offsets UTF-16 ;
- `painting/text_painter.dart` et `rendering/paragraph.dart` : boxes de
  sélection et délégation à `Paragraph.getBoxesForRange` ;
- `widgets/widget_span.dart` : extraction des enfants et dimensions de
  placeholder obligatoires.

Les implémentations pertinentes de `text_span.dart`, `inline_span.dart` et
`widget_span.dart` ont le même SHA-256 dans les deux SDK. La différence
pertinente en aval est bien le device-pixel ratio ajouté au
`RenderParagraph` 3.47.2 ; le chemin public `Text` utilisé par ce lot le prend
en charge sans code propre au package.

## Diff inspecté

Les cinq fichiers modifiés par `3a1c343..719d6a8` ont été lus complètement :

- `lib/src/auto_size_text.dart` ;
- `lib/src/auto_size_text_layout.dart` ;
- `maintenance/implementation/lot-4-rich-text.md` ;
- `test/rich_text_test.dart` ;
- `test/wrap_words_test.dart`.

Les quatre fichiers modifiés par le correctif `ab532aa..dbe1a18` ont aussi été
lus complètement :

- `lib/src/auto_size_text.dart` ;
- `lib/src/auto_size_text_layout.dart` ;
- `maintenance/implementation/lot-4-rich-text.md` ;
- `test/wrap_words_test.dart`.

La surface d'attaque se limite aux paramètres publics du widget et à l'arbre
`InlineSpan` fourni par l'appelant. Le diff n'ajoute ni entrée réseau, ni accès
fichier, ni base de données, ni authentification, ni session, ni cryptographie,
ni secret. Les validations numériques amont restent actives ; les painters
créés dans les chemins modifiés sont libérés en `finally`.

## Vérification du comportement produit

### Snapshot de segmentation après correctif performance

`_UnbreakableTextSnapshot` est créé localement dans chaque appel à
`_calculateFontSize`, immédiatement après la construction du span de mesure
courant. Il n'est ni stocké dans le `State`, ni partagé entre builds. Une
nouvelle instance est donc calculée après chaque changement de span, de label
sémantique porté par le widget, de configuration ou d'override hérité.

Le snapshot conserve uniquement une liste non modifiable de `TextRange`. Sa
chaîne source provient de
`measurementTextSpan.toPlainText(includeSemanticsLabels: false)` ; les labels
sémantiques restent ainsi exclus et les offsets restent ceux des code units
UTF-16 du même arbre visuel que celui remis au painter. Le chemin texte simple
construit l'équivalent `TextSpan(text: data)`. Pour le texte riche, l'absence
du parent synthétique dans le scan est neutre : ce parent n'ajoute aucun texte
et possède le span source comme unique enfant.

Chaque candidat réutilise les plages, mais mesure toujours le painter riche
reconstruit avec le candidat courant. Aucun recognizer, callback, curseur,
locale, identifiant sémantique, `spellOut` ou objet de span n'est stocké ou
réécrit dans le snapshot. La source, y compris ses listes non modifiables,
reste inchangée.

### Arbre riche et scaling par run

Le span source devient l'enfant unique du parent synthétique de mesure. Il
n'est ni aplati ni muté. Sans override, son identité est conservée. Avec
override, seuls les objets dont `runtimeType == TextSpan` sont clonés, comme
dans Flutter ; leur liste est nouvelle et l'ordre reste inchangé.

Le clone fusionne le `style` et recopie les dix autres surfaces exigées :
`text`, `children`, `recognizer`, `mouseCursor`, `onEnter`, `onExit`,
`semanticsLabel`, `semanticsIdentifier`, `locale` et `spellOut`. Recognizer,
curseur, callbacks, sous-type inconnu et `WidgetSpan` gardent leur identité.

La composition non linéaire est effectuée avant le scaler utilisateur pour
chaque run. Le probe discriminant `F=20`, `C=10`, run explicite 40 et
`U(s)=s+s²/100` donne 24. Le mutant global donnerait 22 et a été explicitement
exclu.

### Segmentation Unicode

`toPlainText(includeSemanticsLabels: false)` fournit la chaîne visuelle. Le
scan conserve les indices de `String.length`, donc les offsets de
`TextSelection` et du paragraphe. U+00A0 et U+202F sont retirés exactement des
séparateurs historiques reconnus par `RegExp(r'\s')`; espace, tabulation, LF et
CRLF restent des frontières.

Les plages sont interrogées sur le painter riche non wrappé. Leur avance est
la somme de `abs(right-left)` de toutes les boxes. Deux contraintes
indépendantes sur une plage RTL `A\u00A0אב` entourée de texte distinguent les
quatre stratégies :

- une largeur entre `max(first,max)` et la somme rejette le candidat haut avec
  le produit, tandis que les mutants première box et maximum l'acceptent ;
- une largeur entre la somme et le bounding extent accepte le candidat haut
  avec le produit, tandis que le mutant bounding le rejette.

Le texte `A😀e\u0301\u00A0אב\u202FZ` occupe dix code units. Les sélections
d'une demi-paire surrogate ne rendent aucune box ; `[1,3)` rend l'emoji entier.
Le combining mark réparti sur un descendant et les changements de direction
n'inventent aucune frontière.

### Interactions et sémantiques

Sous override puis après rebuild, les probes ont déclenché le recognizer
original, `onEnter`, `onExit` et le curseur original sur la box réelle du run.
Le nœud sémantique rendu conserve le label, l'identifiant, l'action tap, un
`LocaleStringAttribute(en-GB)` et un `SpellOutStringAttribute`. Un label porté
par le widget conserve sa priorité historique sur les labels de spans.

Deux arbres dont texte visuel et label sémantique inversent espace et NBSP
choisissent le candidat d'après le texte visuel uniquement. Le label ne pollue
donc ni les offsets ni les plages liées.

### Référence zéro et frontières

Les probes couvrent texte simple et riche, minimum nul et positif, descendant
hérité, descendants explicites 20 et 0, scaler non linéaire, replacement et
`textKey`. Le parent hérité suit le candidat ; les descendants explicites
restent à `U(20)=24` et `U(0)=0`. Une branche texte active expose exactement un
`Text` à `textKey`; la branche replacement ne monte pas cette clé.

Un sous-type inconnu de `TextSpan` reste le même objet avec et sans override,
sa liste non modifiable reste identique et ses valeurs ne changent pas après
rebuild.

La frontière `WidgetSpan` est conforme au lot : le package produit un
`UnsupportedError` déterministe avant mesure et le `WidgetSpan` source reste
identique. Cette preuve ne revendique ni layout, ni baseline, ni hit testing,
ni sémantique enfant avant le lot 10.

## Probes temporaires indépendants

Un fichier de dix widget probes a été créé uniquement pour la revue, exécuté
sur les deux SDK, puis supprimé avant le rapport et le commit.

| Probe | Flutter 3.41.0 | Flutter 3.47.2 |
|---|---:|---:|
| Emoji complet, combining, bidi imbriqué et offsets UTF-16 | vert | vert |
| Somme multi-box contre première box, maximum et bounding | vert | vert |
| Espace, tab, LF, CRLF contre NBSP/NNBSP et chaîne mixte | vert | vert |
| `semanticsLabel` exclu de la segmentation | vert | vert |
| Recognizer, souris, callbacks, curseur et métadonnées réelles après rebuild | vert | vert |
| Sous-type inconnu, identité et source non modifiable | vert | vert |
| Référence zéro simple/riche, descendants, replacement et `textKey` | vert | vert |
| Scaling non linéaire 20/40 : 24, jamais 22 | vert | vert |
| Deux demi-surrogates par runs : deux `ArgumentError`, fixture exclue | vert | vert |
| Frontière `WidgetSpan` et identité source | vert | vert |

Résultat : **10/10** sur chaque SDK exact.

Trois copies isolées du candidat ont ensuite remplacé la somme respectivement
par la première box, le maximum et le bounding extent. Sous Flutter 3.47.2,
les trois replays ont échoué séparément au témoin prévu :

| Mutant | Échec observé |
|---|---|
| première box | candidat 20 obtenu au lieu de 10 |
| maximum d'une box | candidat 20 obtenu au lieu de 10 |
| bounding extent | candidat 10 obtenu au lieu de 20 |

Les copies mutantes et le fichier de probes ont été supprimés.

## Contre-probes indépendants du snapshot

Après le correctif performance, un second fichier temporaire de trois widget
probes a été écrit indépendamment des tests du candidat, exécuté sur les deux
SDK, puis supprimé :

| Contre-probe | Flutter 3.41.0 | Flutter 3.47.2 |
|---|---:|---:|
| Comptage exact : 0 scan avec `wrapWords`, 1 sinon, puis 1 nouveau scan après chaque changement d'override, label ou span | vert | vert |
| NBSP/NNBSP, bidi multi-box, emoji et combining avec offsets UTF-16 ; labels sémantiques inversés exclus | vert | vert |
| Recognizer, souris, curseur, identifiant, locale et spell-out réels après override et rebuild ; source non modifiée | vert | vert |

Résultat : **3/3** sur chaque SDK exact. Le compteur personnalisé confirme que
chaque appel se fait avec `includeSemanticsLabels: false`. Un remplacement du
span contenant U+00A0 par un nouveau span contenant U+202F et deux overrides
successifs déclenchent chacun leur propre snapshot, sans réemploi de l'état
précédent.

## Matrice finale du candidat propre

Toolchains exactes :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
```

| Contrôle | Flutter 3.41.0 | Flutter 3.47.2 |
|---|---:|---:|
| `test/rich_text_test.dart test/wrap_words_test.dart` | 21/21 | 21/21 |
| suite racine complète | 96/96 | 96/96 |
| analyse fatale scoped `lib test example/main.dart` | aucun diagnostic | aucun diagnostic |

La résolution locale a été remise à Flutter 3.47.2 après la matrice. Aucun
fichier suivi autre que le présent rapport n'est modifié par la revue.

## Audit pré-conclusion

- Injection, XSS, authentification, autorisation, CSRF, session et
  cryptographie : surfaces absentes du diff.
- Race/état : aucun cache inter-build ni mutation de source introduit ; les
  changements de span, label, configuration et override entre pumps ont été
  exercés.
- Divulgation : l'erreur `WidgetSpan` ne contient ni donnée sensible ni contenu
  appelant.
- Logique métier : Unicode, bidi, scaling non linéaire, zéro, replacement,
  métadonnées et clé ont été vérifiés par le rendu réel.
- Disponibilité : le texte aplati et les plages sont hoistés une fois par
  configuration de calcul ; les candidats ne refont plus le scan. Les requêtes
  de boxes restent nécessaires par candidat puisqu'elles dépendent du layout
  à la taille testée.

Non vérifié dans cette spécialité : benchmark mural, compteur d'allocations,
intrinsics/dry layout, support réel de `WidgetSpan`, appareils physiques et
plateformes web. Ces surfaces appartiennent respectivement aux gates
performance, lots 9/10 et matrices ultérieures ; elles ne sont pas annoncées
comme fermées par ce rapport.
