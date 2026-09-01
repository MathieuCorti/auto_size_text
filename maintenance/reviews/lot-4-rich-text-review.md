# Revue indépendante du lot 4 — RichText fidèle et Unicode

Date : 2026-09-01

Branche revue : `codex/review-rich-text`

Parent exact S4 : `3a1c343e88325b0020452be7c3258a902d87558f`

Candidat exact : `719d6a8df5f699b9ac8963dfb3034e56f71d12ad`

Plage revue : `3a1c343...719d6a8`

Périmètre : arbre de mesure et rendu RichText, scaling par run, référence
racine zéro, overrides de métriques, `wrapWords: false`, UTF-16, bidi,
NBSP/NNBSP, métadonnées, identité et mutation, `textKey`, replacement,
frontière transitoire `WidgetSpan`, compatibilité texte simple/groupes legacy,
cycle de vie et complexité. Aucun correctif produit ou test n'a été écrit par
la revue ; le présent rapport est son seul livrable.

## Verdict

**CHANGEMENTS REQUIS.**

Le comportement fonctionnel principal du lot est solide et les matrices
committées passent sur les deux SDK exacts. Le parent synthétique est fidèle,
le scaler conserve la formule par run `U(S × C / F)`, la branche `F == 0`
n'invente aucun ratio, le clone des `TextSpan` standards recopie tous les
champs des SDK ciblés, et le rendu reçoit l'arbre source pré-override. Les
plages `wrapWords: false` utilisent le texte visuel, des offsets UTF-16 et la
somme de toutes les boxes ; NBSP/NNBSP, bidi, replacement, `textKey` et la
frontière `WidgetSpan` se comportent comme prévu.

Un finding bloquant de disponibilité/complexité reste toutefois ouvert. Le
texte visuel et ses ranges sont recalculés pour chaque candidat de la
dichotomie, alors que l'oracle adversarial corrigé exige leur calcul unique par
configuration. Le probe indépendant compte 30 aplatissements/scans sur une
grille d'environ un milliard de candidats, sous Flutter 3.41.0 comme 3.47.2,
au lieu d'un seul. La suite permanente ne mesure pas cette propriété. Le lot
ne peut donc pas être accepté sur `719d6a8`.

## Finding bloquant

### P1 — La segmentation indépendante du candidat est répétée à chaque évaluation

**Sévérité : moyenne pour la disponibilité ; bloquante pour le gate du lot.**

**Fichiers :**

- `lib/src/auto_size_text.dart:473-492` ;
- `lib/src/auto_size_text.dart:505-526` ;
- `test/wrap_words_test.dart:289-301`.

**Problème.** `_calculateFontSize` appelle `_checkTextFits` depuis le prédicat
de `findLargestThatFits`. Lorsque `wrapWords` vaut faux, `_checkTextFits`
exécute alors `text.toPlainText(includeSemanticsLabels: false)` et recrée
l'itération `_unbreakableTextRanges(plainText)` à chaque candidat. Ni le texte
visuel ni les frontières ne dépendent pourtant de `C` : seuls le scaler et les
boxes du painter dépendent du candidat.

La recherche garde bien `O(log C)` évaluations et le scan individuel reste
linéaire, mais le coût de préparation devient `O(N log C)` et alloue un nouveau
`StringBuffer`/`String` par candidat, au lieu de la borne exigée
`O(N) + O(K log C)` hors coût moteur des boxes. Pour un arbre long ou coûteux à
aplatir, cette répétition se trouve sur le chemin de layout UI et peut produire
du jank ou amplifier un déni de service local par contenu applicatif.

**Preuve indépendante.** Un sous-type temporaire de `TextSpan` a compté les
appels à `computeToPlainText` pour un texte non vide, `wrapWords: false`, une
boîte `0 × 0`, `minFontSize: 0.1`, référence `100000000` et pas `0.1`. La grille
virtuelle contient environ un milliard de candidats et sa dichotomie effectue
30 évaluations. Le test exigeait un seul calcul du texte visuel :

```text
Flutter 3.47.2 : expected 1, actual 30
Flutter 3.41.0 : expected 1, actual 30
```

Le compteur est porté par le span source et n'observe ni un helper de test, ni
le `RenderParagraph` final : avec le replacement actif, ses 30 appels viennent
directement des 30 passages dans `_checkTextFits`. Le probe temporaire a été
supprimé après reproduction.

**Lacune de régression.** Le corpus alterné de 256 code units vérifie seulement
le candidat final et l'égalité du texte rendu. Il ne compte ni aplatissements,
ni ranges, ni painters auxiliaires, ni requêtes de boxes. Il reste donc vert si
le scan est répété 30 fois, comme le démontre la tête candidate.

**Correction exigée.** Calculer
`toPlainText(includeSemanticsLabels: false)` et matérialiser les seuls ranges
`[start, end)` une fois dans la préparation de configuration/mesure, avant
`findLargestThatFits`, puis transmettre ces ranges immuables à chaque appel de
fit. Le painter fidèle et les requêtes de boxes restent naturellement propres
au candidat. Ajouter la régression compteur correspondante sur une grille à
nombre d'évaluations logarithmique ; elle doit exiger un seul aplatissement et
un seul scan de ranges par layout, sans seuil mural.

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
groupe passent dans les 95 tests sur les deux SDK.

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

Le défaut porte donc sur la fréquence du scan préparatoire, pas sur la
classification, les unités, le nombre de painters par candidat ou le calcul de
largeur.

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
| `rich_text_test` + `wrap_words_test` | 20/20 | 20/20 |
| suite racine complète | 95/95 | 95/95 |
| `leak_tracking` + `text_painter_lifecycle` | 9/9 | 9/9 |
| analyse scoped fatale `lib test example/main.dart` | 0 diagnostic | 0 diagnostic |
| exemple : résolution conforme à la politique de lock puis analyse fatale | succès, 10 dépendances naturelles, aucun diagnostic | lock haut forcé, aucun diagnostic |
| downgrade racine puis suite `--no-pub` | 9 dépendances abaissées, 95/95 | 13 dépendances abaissées, 95/95 |
| probe segmentation unique | rouge, attendu 1 / réel 30 | rouge, attendu 1 / réel 30 |

Le format autoritatif Dart 3.13.2 contrôle 25 fichiers de `lib`, `test` et
`example` sans changement. Le contrôle non mutating Dart 3.11.0 signale
uniquement les deux divergences historiques déjà documentées des lots
antérieurs, `test/leak_tracking_test.dart` et
`test/text_painter_lifecycle_test.dart`; aucun des quatre fichiers Dart du lot
4 n'est concerné.

`git diff --check 3a1c343...719d6a8` passe. Les résolutions et probes ont été
isolés ou ignorés conformément à la politique du dépôt ; aucun fichier de
probe ne reste dans le worktree.

## Surface lue intégralement

Les cinq fichiers du diff ont été lus intégralement, ainsi que les versions
parentes des deux fichiers modifiés :

1. `lib/src/auto_size_text.dart` ;
2. `lib/src/auto_size_text_layout.dart` ;
3. `maintenance/implementation/lot-4-rich-text.md` ;
4. `test/rich_text_test.dart` ;
5. `test/wrap_words_test.dart`.

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
| Ressources / disponibilité | Painters correctement disposés et recherche logarithmique, mais scan `O(N)` répété `log C` fois : finding P1 ouvert. |
| Logique numérique | Composition non linéaire, zéro, plateau, validations et exactitude candidat/rendu conformes hors finding. |
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
