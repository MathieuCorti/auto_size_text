# Revue indépendante du lot 3 — texte effectif et accessibilité

Date : 2026-09-01

Base exacte : `a13534cd12842b2e6847feb4963842175a96ee10`

Candidat revu : `cac342c8bdb0fb1e874cb7d18d609c691a46d5a5`

Branche de revue : `codex/review-effective-text-a11y`

Périmètre : `TextScaler`, configuration effective du texte simple positif,
parité entre le fitter et le vrai `RenderParagraph`, sémantique de base et
non-régression historique #25. Aucun correctif produit ou test permanent n'a
été ajouté par la revue ; le présent rapport est son seul livrable.

## Verdict

**CHANGEMENTS REQUIS.**

Je n'ai reproduit **aucun défaut produit** dans le périmètre du lot 3. La
séparation style/strut pré-override pour le `Text` final et post-override pour
les painters est correcte. La composition non linéaire, les règles de largeur,
la contrainte de la taille réelle, `didExceedMaxLines`, le remplacement et la
sémantique ont concordé avec de vrais `RenderParagraph` sur les deux SDK
exacts.

Deux **lacunes de preuve permanente** restent néanmoins bloquantes. Elles
contredisent les cas P0 et la règle explicite de l'oracle selon laquelle une
fixture de gras, direction/locale ou `TextHeightBehavior` doit d'abord prouver
que les deux branches ont des métriques différentes. Les probes temporaires de
revue établissent que le code actuel est correct, mais ne remplacent pas des
régressions permanentes capables de détecter une casse future.

## Findings

### P1 — Le test `boldText` ne possède pas de témoin métrique fiable

**Fichier :** `test/effective_text_configuration_test.dart:192`

**Nature :** lacune de preuve permanente, pas défaut produit reproduit.

Le test rend `XXXXXX` en famille `Roboto`, avec une entrée `w900`, puis affirme
seulement que le paragraphe final porte `w700`. Son oracle de candidat est
ensuite reconstruit depuis le style du `RenderParagraph` déjà rendu. Il
n'établit jamais que les métriques `w700` diffèrent de `w900` pour cette
fixture.

Une implémentation régressive qui mesurerait encore `w900` mais laisserait
`Text.build` rendre `w700` peut donc passer si les deux poids ont les mêmes
avances. Ce n'est pas hypothétique comme faiblesse de test : le journal admet
explicitement aux lignes 165-167 que le dépôt ne fournit aucune police
garantissant une largeur différente. L'oracle exige pourtant une fonte
regular/bold de métriques distinctes et un candidat qui change réellement.

Le probe indépendant a d'abord rencontré des avances identiques entre les
poids Roboto testés. Il a ensuite enregistré sous une même famille de revue des
faces déterministes de métriques distinctes, établi que `w700` et `w900`
produisaient des largeurs et candidats différents, puis vérifié que
`AutoSizeText` choisissait exactement le candidat `w700`. Ce probe passe 1/1
sur Flutter 3.41.0 et 1/1 sur Flutter 3.47.2 : le produit est conforme, la
preuve permanente ne l'est pas.

**Correction attendue :** ajouter des fixtures licenciées regular/bold dont les
métriques diffèrent de façon déterministe, affirmer d'abord la différence du
témoin, placer la contrainte entre les deux seuils, puis affirmer le candidat
et les métriques du vrai `RenderParagraph`. L'entrée `w900` doit rester pour
prouver son remplacement exact par `w700`.

### P1 — Direction, locale et comportements de hauteur sont vérifiés par leurs propriétés, pas par une divergence métrique

**Fichier :** `test/effective_text_configuration_test.dart:513`

**Nature :** lacune de preuve permanente, pas défaut produit reproduit.

Le test affirme `textDirection`, `locale`, `textAlign`, `textWidthBasis` et
`textHeightBehavior` sur le paragraphe final. Le helper recrée ensuite un
`TextPainter` depuis ce même paragraphe. Il ne construit aucun témoin
LTR/locale fallback ni aucun témoin avec l'autre `TextHeightBehavior`, et
n'affirme donc ni une différence de métriques, ni une différence de candidat.

Ce test resterait vert si le fitter mesurait avec LTR, un locale nul ou un
comportement de hauteur différent, tant que la fixture thaïe choisit le même
candidat et que le `Text` final résout correctement les propriétés. L'oracle
interdit expressément ce type de test aux lignes 379-382 et demande aux lignes
373-374 une fixture divergente avant de comparer le choix d'`AutoSizeText`.

Le probe de revue a comparé les boîtes bidi d'un texte latin/hébreu/thaï et a
établi une différence LTR/RTL avant de comparer les boîtes du vrai
`RenderParagraph`; il a aussi vérifié les locales héritée/explicite,
`TextWidthBasis.parent/longestLine`, `DefaultTextStyle.textHeightBehavior`, le
fallback `DefaultTextHeightBehavior`, les contraintes min/max et la baseline
réelle. Les deux SDK sont verts et l'inspection statique confirme que le fitter
utilise ces valeurs. La suite permanente doit cependant posséder ses propres
fixtures sensibles, en particulier pour le locale et les deux comportements
de hauteur.

**Correction attendue :** séparer les causes. Pour direction/locale, établir
d'abord une différence reproductible de boîtes ou de métriques entre le témoin
effectif et le fallback, puis vérifier le candidat et le paragraphe réel. Pour
les comportements de hauteur, utiliser un style dont `height` rend les deux
configurations métriquement distinctes, affirmer cette différence, puis
vérifier taille, baseline et candidat. Ne pas limiter la régression à
l'inspection du widget ou des propriétés du render object.

## Vérification indépendante du code produit

Les sources exactes des tags Flutter `3.41.0` et `3.47.2` ont été inspectées
dans le dépôt Flutter local : `Text.build`, `RichText`, `MediaQuery`,
`RenderParagraph`, `TextPainter` et `TextScaler`. Les différences de 3.47
concernant notamment `devicePixelRatio`, la sélection et le caret ne changent
pas l'oracle métrique du lot 3.

| Surface | Conclusion |
|---|---|
| `DefaultTextStyle` et fallback 14 | Fusion `inherit:true`, isolement `inherit:false` et fallback sont reproduits. Le style final reste pré-override. |
| `boldText` | Le painter fusionne exactement `FontWeight.bold` (`w700`) après le style de base ; le `Text` laisse Flutter faire la même transformation une fois. |
| Overrides de métriques | Hauteur, letter spacing et word spacing remplacent isolément les valeurs source. La configuration est reconstruite entre frames. |
| Strut | Un strut fourni reçoit seulement l'override de hauteur ; un strut nul reste nul. Le scaler candidat scale aussi son `fontSize`. |
| Scaling | Priorité explicite, ancien facteur puis ambiant correcte. La composition appelle `source.scale(size * candidate / reference)` et ne lit pas le getter pour choisir. |
| Double application | Le style racine conserve la référence et le candidat reste dans le scaler ; style, strut et scaler ne sont pas appliqués deux fois. |
| Wrap et overflow | Largeur contrainte si wrap ou ellipsis, infinie sinon. Seule ellipsis configure `…`. |
| Contraintes et fit | `minWidth` et `maxWidth` sont transmis ; le fit compare `textSize` à `constraints.constrain(textSize)` et lit toujours `didExceedMaxLines`. |
| Direction, locale et defaults | Résolution conforme à `Text.build`/`RichText`, y compris `TextWidthBasis` et le fallback `DefaultTextHeightBehavior`. |
| Ressources | Les painters principal, auxiliaire `wrapWords:false` et témoins permanents sont libérés dans des `finally`. |

Le scaler candidat valide les tailles d'entrée, la taille ajustée et chaque
sortie utilisée comme finies et non négatives. Son égalité et son hash portent
sur source, candidat et référence. Aucun usage produit de
`MediaQuery.textScaleFactorOf`, du paramètre déprécié de `TextPainter`, de
`dynamic`, de `Function.apply` ou de `noSuchMethod` n'a été trouvé.

## Probes temporaires

Un fichier widget temporaire a exercé un oracle de candidats indépendant. Pour
chaque paragraphe disponible, il a comparé au vrai `RenderParagraph` :

- taille non contrainte et contrainte, `textSize` et `size` ;
- `didExceedMaxLines` ;
- baseline alphabétique wet ;
- boîtes de sélection bidi ;
- candidat effectif sous scaler linéaire ou quadratique.

Les huit scénarios couvraient :

1. `DefaultTextStyle`, héritage/isolement et fallback 14 ;
2. `boldText` avec témoin métrique `w700`/`w900` réellement divergent ;
3. overrides hauteur/letter/word isolés et bascule de frames ;
4. strut non nul/null et bascule réelle de `overflowReplacement` ;
5. scaler quadratique ambiant, scaler explicite, `noScaling` et absence de
   double application ;
6. `softWrap` hérité/explicite, clip, ellipsis, `maxLines`, remplacement et
   `didExceedMaxLines` réel ;
7. contraintes tight/loose avec minima/maxima, RTL/LTR, locale,
   `TextWidthBasis`, `TextHeightBehavior` et `DefaultTextHeightBehavior` ;
8. sémantique de base avec `semanticsLabel` et régression #25 à taille
   effective 60.

Résultat : **8/8 sur Flutter 3.41.0 et 8/8 sur Flutter 3.47.2**. Le fichier a
été supprimé avant les suites finales ; aucun asset ou artefact de probe ne
reste dans le diff.

La sémantique visible portait exactement `Double dollars`, le scaler historique
de #25 rendait `15 × 4 = 60`, et le painter témoin concordait encore avec le
`RenderParagraph`.

## Matrice finale

SDK exacts :

```text
Flutter 3.41.0 • 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • d3b14c8769 • Dart 3.13.2
```

| Contrôle | Flutter 3.41.0 | Flutter 3.47.2 |
|---|---:|---:|
| Probe indépendant temporaire | 8/8 | 8/8 |
| `text_scaler_test` + `effective_text_configuration_test` | 16/16 | 16/16 |
| Suite racine complète après suppression du probe | 72/72 | 72/72 |
| Analyse fatale `lib test example/main.dart` | aucun diagnostic | aucun diagnostic |

Les résolutions locales ont été remises à la toolchain haute après la matrice.
Le lock canonique de l'exemple est inchangé et le worktree était propre avant
la création du présent rapport.

## Surface lue et checklist `find-bugs`

Les sept fichiers du diff `a13534c..cac342c` ont été lus intégralement :

- `lib/src/auto_size_text.dart` ;
- `lib/src/auto_size_text_layout.dart` ;
- `maintenance/implementation/lot-3-effective-text.md` ;
- `test/basic_test.dart` ;
- `test/effective_text_configuration_test.dart` ;
- `test/text_scaler_test.dart` ;
- `test/utils.dart`.

Ont aussi été lus l'oracle `effective-text`, le lot 3 de la roadmap, les
instructions Developing Flutter, Effective Dart, testing et `find-bugs`, ainsi
que les sources Flutter exactes listées plus haut.

| Classe de risque | Conclusion |
|---|---|
| Logique de layout et accessibilité | Produit conforme dans les probes ; deux preuves P0 permanentes insuffisantes. |
| Ressources / déni de service | Recherche logarithmique héritée du lot 2 ; tous les painters temporaires sont disposés. |
| État / frames / concurrence | Configuration reconstruite ; bascules d'InheritedWidget observées ; aucun nouvel état partagé concurrent. |
| Runtime release | Exclusion mutuelle et valeurs invalides gardées par des branches runtime en plus des assertions. |
| Compatibilité / API | Deux constructeurs `const`, API historique dépréciée mais conservée, aucune API publique hors lot. |
| Injection, XSS, auth, CSRF, secrets, crypto, réseau | Hors surface : aucune entrée distante, commande, identité, persistance ou donnée sensible ajoutée. |

Le lot pourra être accepté après remplacement des deux preuves faibles par des
fixtures métriquement sensibles et relecture de leur rouge sur le parent exact.
Aucun merge, push, tag ou changement distant n'a été effectué par cette revue.
