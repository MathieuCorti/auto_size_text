# Revue indépendante du lot 3 — texte effectif et accessibilité

Date : 2026-09-01

Base exacte : `a13534cd12842b2e6847feb4963842175a96ee10`

Candidat initial : `cac342c8bdb0fb1e874cb7d18d609c691a46d5a5`

Première revue : `02dd06d75044ed636fba2717856f52b392adec89`

Correctif re-revu : `a6dea62a564c6bf85734a5def9df457a82d37ca1`

Correctif de provenance de licence :
`2ce954156c69d62c726479b2d200f2cc1db83e22`

Branche de revue : `codex/review-effective-text-a11y`

Périmètre : configuration effective du texte simple positif, composition de
`TextScaler`, parité entre le fitter et le vrai `RenderParagraph`, sémantique
de base, non-régression historique #25 et delta correctif `02dd06d..a6dea62`.
La relecture finale couvre aussi le delta de licence `b38098e..2ce9541`. La
revue n'a modifié ni le produit ni les tests ; ce rapport est son seul livrable.

## Verdict final

**ACCEPTÉ.**

Aucun défaut produit ni aucune lacune de preuve bloquante ne reste dans le
périmètre. Les deux findings P1 de la première revue sont clos par des fixtures
versionnées et métriquement sensibles, des oracles indépendants du widget et
des comparaisons avec de vrais `RenderParagraph`. Les régressions simulées de
gras, direction, locale et hauteur font toutes échouer le candidat réellement
rendu sur Flutter 3.41.0 comme sur Flutter 3.47.2.

Le delta corrige aussi une régression de compatibilité de groupe introduite par
le candidat initial : le groupe republie l'unité effective historique et un
test hétérogène avec les facteurs legacy 1 et 2 vérifie `[20, 20]`. Le code de
mesure du texte non groupé reste inchangé par cette correction.

La relecture finale du correctif `2ce9541` conserve ce verdict. Son delta unique
est la licence Noto Naskh ; code, tests et binaires TTF sont identiques à
`b38098e`. La provenance est désormais celle de la licence ajoutée avec la TTF
source dans l'historique Flutter engine.

## Clôture des findings initiaux

### Gras : clos

Le test ne dépend plus de la police système ni d'une simple inspection de
`fontWeight`. Il enregistre sous une famille de test deux sous-ensembles Roboto
regular `w400` et bold `w700`, puis :

- prouve que les largeurs de `MMMMMM` diffèrent à taille 30 ;
- place la contrainte entre ces deux seuils ;
- établit avec un `TextPainter` témoin que les candidats sont respectivement
  30 et 29 ;
- vérifie que le vrai `RenderParagraph` garde 30 sans accessibilité et choisit
  29 avec `boldText` ;
- compare ses métriques et `didExceedMaxLines` au témoin ;
- conserve un cas d'entrée `w900` qui doit être remplacée exactement par
  `w700`.

Un mutant supprimant l'application de `MediaQuery.boldTextOf` échoue sur
`Expected: 29.0, Actual: 30.0` dans les deux SDK.

### Direction, locale et hauteur : clos

Les causes sont isolées dans trois tests permanents :

- `<<<<<<` avec Roboto possède des avances différentes en LTR et RTL ; les
  candidats témoins sont 30 et 29. Les variantes héritée et explicite vérifient
  ensuite direction, alignement, `TextWidthBasis`, `textSize`, dépassement et
  candidat du vrai paragraphe ;
- six U+066C avec le sous-ensemble Noto Naskh `locl` produisent des métriques
  différentes en `ar` et `fa` ; les candidats sont 30 et 26. Les permutations
  locale héritée/explicite sont contrôlées sur le vrai paragraphe ;
- `Hg`, Roboto et `height: 3` donnent 90 px avec le comportement normal et
  35 px sans hauteur sur la première ascension et la dernière descente. La
  baseline diffère aussi ; sous 60 px de hauteur, les candidats sont 20 et 30.
  Le test distingue `DefaultTextStyle.textHeightBehavior` du fallback
  `DefaultTextHeightBehavior` et lit les métriques réelles.

Les mutants imposant LTR, supprimant le fallback de locale ou supprimant la
résolution du comportement de hauteur échouent respectivement sur `29→30`,
`26→30` et `30→20`, sur les deux SDK exacts.

## Provenance des témoins métriques

Les trois TTF sont des sous-ensembles déterministes, chargés explicitement par
`FontLoader` depuis `test/assets/fonts/`. Aucun n'est une police système et
aucun n'est déclaré dans un manifeste `pubspec`; ils restent donc des fixtures
de test et ne sont pas ajoutés aux assets des clients.

| Fichier | Taille | SHA-256 |
|---|---:|---|
| `auto_size_metric_roboto_regular.ttf` | 2 660 | `893780a2a9c1b15a9ee784b1e34568ff755d3ff9815c9fa755febe303d7bd9c1` |
| `auto_size_metric_roboto_bold.ttf` | 2 632 | `bab0b1b36298647122dfaee2e27c0bcb564c43f954be771e90abc94812fafa6d` |
| `auto_size_metric_naskh_locl.ttf` | 5 212 | `d51e94755847f96a7cb9fdd53c91962ec6772a4d6b54c764e05b85e8d987af5a` |
| `LICENSE-Roboto.txt` | 11 358 | `cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30` |
| `LICENSE-NotoNaskhArabic.txt` | 4 301 | `c3dd4c678171e42146614fd4fd132f474df05f7bd12d1348b4c5af50172c0e8f` |

Les Roboto sources sont identiques dans les artefacts des deux SDK et la
licence Apache-2.0 complète est adjacente. Une inspection des tables confirme
regular/bold pour Roboto et, pour Noto Naskh, les tables de
substitution/localisation nécessaires aux formes `ar`/`fa`.

Pour Noto Naskh, le commit Flutter engine
`e1a8bb2a0a097fd33079e0eba17ba7e73cec9d89` a ajouté ensemble
`NotoNaskhArabic-Regular.ttf` et `NotoNaskhArabic-LICENSE.txt`. Le blob Git de
la TTF de ce commit (`ee6cdaa35bc0ef86c1183726f9867655b0b1aef6`) est
exactement celui des sources installées de Flutter 3.41.0 et 3.47.2 ; leurs
SHA-256 sont également identiques
(`6b999662f669b2c9b00c10ce4a110b6f5179c20f3f77e5ccb897e3ab965cf9f5`).
La fixture est un sous-ensemble de cette source.

La licence corrigée reprend intégralement le blob OFL-1.1 historique associé
`d952d62c065f3f35fb83a173496e90b21525aef3`. Son blob Git
`88cbb72152efe820ec9551583db1185104966fa0` en diffère seulement par le
déplacement d'un LF terminal en tête de fichier : même longueur de 4 301
octets, même texte après normalisation des blancs de bord, aucune attribution
ajoutée ou retranchée. Son SHA-256 a été recalculé ci-dessus. La licence
complète reste adjacente à la fixture.

## Relecture bornée du correctif de licence

Le diff `b38098e..2ce9541` contient exactement un fichier modifié :
`test/assets/fonts/LICENSE-NotoNaskhArabic.txt`, avec 26 lignes ajoutées et 26
retirées par reformatage. L'ancienne ligne `Copyright 2014 Google Inc.` ne
provenait pas de la licence livrée avec cette TTF engine ; elle a été retirée.
Le texte OFL nouvellement versionné correspond à sa provenance vérifiable.

Le diff est vide pour `lib/`, les fichiers Dart de `test/`, les trois TTF, les
manifests et le journal d'implémentation. La parité produit, les témoins
métriques, les mutants et les résultats complets du verdict `b38098e` ne sont
donc pas affectés. Un sanity ciblé a néanmoins rechargé les fontes et exercé
les vrais `RenderParagraph` : 21/21 sous Flutter 3.41.0 et 21/21 sous Flutter
3.47.2. La résolution locale haute a ensuite été restaurée et le lock canonique
est resté inchangé.

## Parité produit cumulée

Les sources exactes de Flutter 3.41.0 et 3.47.2 ont été relues pour
`Text.build`, `RichText`, `MediaQuery`, `RenderParagraph`, `TextPainter` et
`TextScaler`. Pour du texte simple positif, le fitter et le paragraphe final
résolvent la même configuration :

| Surface | Conclusion |
|---|---|
| Style | Fusion de `DefaultTextStyle`, respect de `inherit:false` et fallback 14 conformes. Le style final reste pré-override. |
| Accessibilité | `boldText` remplace le poids par `w700`; hauteur, letter spacing et word spacing remplacent isolément les valeurs source et suivent les bascules de frames. |
| Strut | Un `StrutStyle` fourni reçoit seulement l'override de hauteur ; `null` reste `null`. Le scaler candidat scale aussi son `fontSize`. |
| Scaling | Priorité scaler explicite, facteur legacy puis scaler ambiant correcte. La composition non linéaire est `source.scale(size × candidate / reference)` et n'est appliquée qu'une fois. |
| Wrap/overflow | Largeur bornée si wrap ou ellipsis, infinie sinon ; seule ellipsis configure `…`. `clip`, `ellipsis`, `maxLines` et le remplacement divergent comme attendu. |
| Contraintes | `minWidth` et `maxWidth` sont transmis ; le fit compare `textSize` à `constraints.constrain(textSize)` et lit `didExceedMaxLines`. |
| Contexte | Direction, locale, `TextWidthBasis`, `TextHeightBehavior` et `DefaultTextHeightBehavior` suivent les fallbacks Flutter exacts. |
| Render object | Les tests lisent `textSize`, `size`, baseline et `didExceedMaxLines` de vrais `RenderParagraph`; ils ne se limitent pas à l'arbre de widgets. |
| Sémantique | Le label de base et la régression #25 à taille effective 60 restent couverts sans divergence métrique. |

Les painters principal et auxiliaires sont libérés dans des `finally`. Les
validations finies/non négatives restent des branches runtime. Aucun usage
produit de l'ancien getter de facteur, du paramètre déprécié de `TextPainter`,
de `dynamic`, `Function.apply` ou `noSuchMethod` n'a été introduit.

## Correction du groupe legacy et égalité du scaler

Le candidat logique et sa taille effective sont désormais transportés
séparément par `_AutoSizeTextLayoutResult`. Un groupe publie
`userScaler.scale(candidate)`, conformément à l'unité historique, puis le texte
simple groupé rend cette taille avec `TextScaler.noScaling`. Pour les membres
legacy hétérogènes `20×1` et `15×2`, le vrai rendu reste donc `[20, 20]`.
Remplacer la publication effective par le candidat logique fait rougir le test
avec `[15, 15]`; le test homogène détecte aussi cette unité incorrecte.

Le test d'égalité est pertinent parce que `_CandidateTextScaler` est recréé
entre builds et que source, candidat et référence déterminent sa courbe. Il
construit de vrais scalers rendus dont une source plateau masque toute
différence de sortie (`scale(20) == 42` pour tous), puis exige que chacun des
trois champs participe à `==` et `hashCode`. Omettre le candidat de l'égalité
fait rougir ce test sur les deux SDK ; l'omission dans le hash a aussi été
vérifiée rouge séparément sous 3.47.2.

## Mutants indépendants

Les mutants ont été appliqués dans un worktree détaché temporaire, jamais dans
la branche de revue. Chaque mutant 3.47.2 a été exécuté séparément ; la matrice
combinée a été rejouée sous 3.41.0. Tous ont échoué au témoin attendu :

| Régression simulée | Échec observé |
|---|---|
| Ignorer `boldText` dans la mesure | candidat attendu 29, réel 30 |
| Mesurer toujours en LTR | candidat attendu 29, réel 30 |
| Ignorer la locale héritée | candidat attendu 26, réel 30 |
| Ignorer les defaults de hauteur | candidat attendu 30, réel 20 |
| Publier le candidat logique au groupe | tailles attendues `[20,20]`, réelles `[15,15]` |
| Omettre le candidat de l'égalité | deux scalers distincts deviennent égaux |
| Omettre le candidat du hash | les hashes distincts deviennent égaux |

Le worktree temporaire a été restauré puis supprimé. Aucun probe, mutant ou
artefact généré ne reste dans le diff.

## Matrice finale

SDK exacts :

```text
Flutter 3.41.0 • 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • d3b14c8769 • Dart 3.13.2
```

| Contrôle | Flutter 3.41.0 | Flutter 3.47.2 |
|---|---:|---:|
| Tests ciblés `effective_text_configuration` + `text_scaler` | 21/21 | 21/21 |
| Suite racine complète | 77/77 | 77/77 |
| Analyse fatale `lib test example/main.dart` | aucun diagnostic | aucun diagnostic |
| Mutants gras/direction/locale/hauteur | rouges | rouges |
| Mutants groupe/égalité | rouges | rouges |

La résolution locale a été remise à Flutter 3.47.2 après la matrice ; le lock
canonique est inchangé.

## Surface relue et checklist `find-bugs`

Le delta correctif complet `02dd06d..a6dea62` et le cumul
`a13534c..a6dea62` ont été inspectés, notamment les deux sources produit, les
deux suites ciblées, le journal et les cinq assets/licences. Les instructions
Developing Flutter, Effective Dart, testing, `find-bugs`, l'oracle
`effective-text`, le lot 3 de la roadmap et les sources Flutter exactes ont été
réappliqués.

| Classe de risque | Conclusion |
|---|---|
| Mesure/rendu/accessibilité | Parité établie par métriques de vrais render objects et mutants discriminants ; aucun finding ouvert. |
| Compatibilité | Groupe legacy restauré ; API historique dépréciée mais conservée ; aucune surface publique hors lot. |
| État/frames/ressources | Configuration reconstruite, bascules observées, painters disposés, aucun nouvel état concurrent. |
| Assets/licences | Fixtures minimales, déterministes, versionnées, licenciées et absentes du bundle client. |
| Sécurité | Aucun réseau, secret, identité, persistance, commande, crypto ou entrée distante ajouté. |

Aucun merge, push, tag ou changement distant n'a été effectué par cette revue.
