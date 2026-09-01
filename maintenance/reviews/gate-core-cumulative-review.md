# Gate Cœur — revue cumulative indépendante des lots 1 à 5

Date : 2026-09-01

Branche revue : `codex/gate-core-review`

Base exacte : `e9f75af9c3ef54bee2cbd3fcc0a53b44e7811968`

Tête S6 revue : `b07066ffe321dff059c9d7d8008b2713e30e1aee`

Plage : `e9f75af9c3ef54bee2cbd3fcc0a53b44e7811968..b07066f`

Périmètre : revue cumulative du cœur livré par les lots 1 à 5, sans correctif
produit ni test permanent. Le présent rapport est le seul fichier conservé par
la revue. Aucun merge, push, tag, publication ou changement distant n'a été
effectué.

## Verdict

**PASS.**

Aucun finding P0, P1 ou P2 n'est confirmé dans le code produit ou dans les
preuves des lots 1 à 5. Les deux P3 ci-dessous sont des dettes de qualité
documentaire et de helper de test ; ils n'altèrent ni le comportement livré,
ni la capacité des régressions permanentes à détecter les défauts cœur qu'elles
revendiquent. Ils ne bloquent donc pas la Gate Cœur.

Le diff cumulé respecte les invariants attendus : tous les painters temporaires
sont libérés, le domaine de candidats reste virtuel et strict, mesure et rendu
partagent la configuration effective, le RichText conserve ses runs et ses
offsets UTF-16, et les groupes séparent bien `L`, `P`, `G` et `R` sans publier
la projection. Les suites complètes et analyses fatales passent sur Flutter
3.41.0 et 3.47.2.

Cette décision ne permet pas une release. Les intrinsics, le dry layout et le
support automatique de `WidgetSpan` restent explicitement ouverts pour les
lots d'architecture ultérieurs.

## Findings

### P0 — aucun

### P1 — aucun

### P2 — aucun

### P3-01 — le diff cumulé n'est pas propre pour `git diff --check`

**Fichier :** `maintenance/decisions/candidate-domain-oracle.md:3-4`.

Les lignes `Date` et `Base inspectée` se terminent chacune par deux espaces.
Ils servent vraisemblablement de sauts de ligne Markdown, mais
`git diff --check e9f75af..b07066f` les signale comme `trailing whitespace` et
retourne un statut non nul.

Il n'y a aucun impact produit ni ambiguïté normative. La Gate Cœur ne demande
pas ce contrôle, contrairement à la Gate Finale. Si ces blobs sont encore dans
la plage finale livrée, il faudra remplacer ces sauts forcés par une mise en
forme qui ne fasse pas échouer le contrôle Git.

### P3-02 — deux branches historiques du harness restent sans oracle utile

**Fichiers :** `test/utils.dart:18-29` et `test/maxlines_test.dart:35`.

Dans `doesTextFit`, la branche `wrapWords == false` calcule une variable locale
`maxLines`, mais le `TextPainter` reçoit ensuite `text.maxLines`. Aucun appel
actuel du helper ne passe `false`, de sorte que cette branche est à la fois
ineffective et non exercée. Le test nommé
`Unlimited maxLines if parameter null` possède par ailleurs un corps vide.

Cette dette est antérieure au comportement produit revu. Elle ne rend pas les
preuves cœur tautologiques : les tests `wrapWords`, configuration effective,
RichText et groupes observent des `RenderParagraph`, des boxes, des tailles ou
des compteurs indépendants, et les mutants des lots ainsi que le mutant
cumulatif de cette revue deviennent rouges. Elle mérite néanmoins un correctif
test-only avant de réutiliser ce helper comme oracle de wrapping ou de présenter
le cas `maxLines == null` comme couvert par ce test nommé.

## Relecture cumulative du produit

Les quatre fichiers produit du delta ont été lus intégralement, dans leur état
final et contre leur version de base :

1. `lib/auto_size_text.dart` ;
2. `lib/src/auto_size_group.dart` ;
3. `lib/src/auto_size_text.dart` ;
4. `lib/src/auto_size_text_layout.dart`.

`lib/src/auto_size_group_builder.dart`, inchangé mais directement interactif,
a également été relu intégralement.

### Cycle de vie et ressources

Les deux sites d'allocation de `TextPainter` sont protégés par des
`try/finally`. Le painter auxiliaire de `wrapWords: false` est libéré sur fit,
retour anticipé et exception ; le painter principal l'est sur le chemin
nominal et sur exception. Le helper de test libère aussi son painter. Les tests
avec leak tracking couvrent le signal natif et non le seul objet Dart.

Le groupe ne possède aucune ressource native. Un état est retiré avant son
`super.dispose`; une microtâche pending capture les membres courants au moment
de son exécution, puis revalide appartenance et `mounted` avant chaque callback.
Un transfert retire l'ancien rapport, inscrit dans le nouveau groupe et remet
seulement le cache de publication à `null`.

### Domaine de candidats et flottants

`_CandidateSet` ne matérialise pas les grilles régulières. Les valeurs sont
indexées à partir du minimum, la borne supérieure exacte est conservée, la
quasi-égalité reste confinée à la construction du domaine et les projections
effectives utilisent une comparaison exacte. Les quotients non finis ou
supérieurs au plus grand indice exact `2^53-1`, les pas qui n'avancent plus et
les extrémités non strictes sont rejetés avant conversion ou recherche.

Les presets sont copiés, validés dans leur ordre source, canonicalisés pour le
zéro et dédupliqués sans mutation de la liste appelante. La dichotomie rend
toujours une valeur du domaine, y compris le minimum lorsque aucun candidat ne
tient. Aucun scan proportionnel à une plage régulière n'est réintroduit par la
projection de groupe.

Les magnitudes typographiques proches de `double.maxFinite` restent hors du
contrat de paragraphe, comme l'énonce l'oracle ; les résultats arithmétiques
intermédiaires non finis sont rejetés par `ArgumentError` avant Flutter. Aucun
nouvel écart debug/release n'a été trouvé sur les entrées du contrat.

### `TextScaler` et configuration effective

La priorité est `textScaler` explicite, puis ancien facteur converti en scaler
linéaire, puis scaler ambiant. L'exclusion mutuelle existe en assertion dans le
constructeur `const` et en validation runtime au build. Le scaler composé
applique le ratio logique avant le scaler utilisateur, valide entrée,
intermédiaire et sortie, et ne lit pas le getter de compatibilité pendant la
recherche, la mesure, le rendu ou la publication de groupe.

La configuration effective reproduit les propriétés de layout de `Text` :
style hérité et fallback 14, gras w700, overrides de hauteur et d'espacements,
strut, alignement, direction, locale, soft-wrap, overflow et ellipsis,
`maxLines`, `TextWidthBasis` et `TextHeightBehavior`. La mesure utilise une
largeur infinie seulement lorsque le rendu ne wrappe pas et n'utilise pas
l'ellipsis. Le `Text` final reçoit les entrées sources appropriées afin que les
overrides Flutter ne soient pas appliqués deux fois.

L'ajout public de `textScaler` est additif. L'ancien `textScaleFactor` reste
présent et seulement déprécié ; les constructeurs, clés, defaults et
constructeurs `const` sont conservés. Aucune rupture source du cœur historique
n'a été trouvée.

### RichText, Unicode et wrapping

Le span source est placé sous un parent synthétique portant le style effectif.
Sans override, son identité est conservée. Avec override, seuls les
`TextSpan` standards sont clonés ; toutes leurs métadonnées sont recopiées et
les sous-types inconnus restent identiques. Le rendu reçoit toujours l'arbre
source, jamais le clone de mesure.

Pour une référence positive, chaque run suit
`U.scale(S * C / F)`. Pour une référence zéro, le parent reçoit directement le
candidat et les tailles explicites des descendants restent inchangées. Les
cas simple et riche, scaler non linéaire, replacement et clé du texte sont
distingués par les tests.

La segmentation de `wrapWords: false` est construite une seule fois par calcul
de configuration. Elle utilise les offsets UTF-16 du texte visuel sans labels
sémantiques, conserve NBSP/NNBSP dans les plages et interroge le painter riche
non wrappé. La largeur d'une plage bidi est la somme de toutes ses boxes. Par
candidat, il existe un painter auxiliaire et au plus une requête de boxes par
plage, avec retour anticipé.

Le coût visible est `O(N + E*K)` appels de plages au pire, où `N` est le nombre
de code units, `E` le nombre logarithmique de candidats évalués et `K` le
nombre de plages. La complexité interne de `Paragraph.getBoxesForRange` n'est
pas garantie par Flutter ; aucun comportement superlinéaire ou DoS concret n'a
été reproduit dans les corpus et bornes documentés. L'oracle adversarial
n'annonce pas une garantie plus forte.

La détection de `WidgetSpan` produit actuellement un `UnsupportedError`
déterministe avant création de painter. C'est une stabilisation transitoire,
pas la fermeture de CORE-01 ou de #61/#106.

### Groupes, caches et exceptions

Le flux observé est exactement :

```text
L = plus grand candidat local qui tient
P = U(L), seul rapport publié
G = minimum des P courants
R = max { c dans le domaine du membre | c <= L et U(c) <= G }
```

Le cache contient le dernier `P`, jamais `L` ou `R`. Une modification de
contrainte peut donc changer `L` et le run riche rendu tout en gardant le même
`P` sur un plateau, sans publication inutile. Le fallback de projection reste
le minimum exact du domaine et ne déclenche pas `overflowReplacement`, qui
dépend uniquement du fit local.

Les sorties invalides sont rejetées avant d'entrer dans le minimum. Une erreur
avant publication conserve l'ancien rapport du même groupe ; une erreur de
projection après publication conserve le nouveau rapport fini, conformément à
l'oracle non transactionnel. Les contrôleurs sont comparés par identité afin
de transférer correctement un membre entre deux sous-classes distinctes qui se
déclarent égales par `operator ==`.

Le minimum est recalculé en `O(M)`, coût admis, et les changements synchrones
sont coalescés avec un marqueur posé avant `scheduleMicrotask`. Les frames
témoins, retraits, transferts, passage à `null` et dispose convergent sans
republication de `R`, callback tardif ou oscillation stable.

## Probe cumulatif et mutant indépendant

Un test widget temporaire a combiné des surfaces qui n'étaient pas réunies par
un seul test permanent : RichText à run explicite, scaler monotone avec plateau
à la racine, groupe hétérogène, cache `P` inchangé et changement de contrainte.

Le membre riche utilisait `F=20`, un run `S=40`, le domaine `{30,20,10}` et un
scaler donnant `P(30)=P(20)=20` mais des runs rendus de largeur Ahem 60 et 40.
Après réduction de la largeur disponible de 70 à 50 :

- le run est passé de 60 à 40 ;
- la racine publiée est restée 20 ;
- le voisin est resté projeté à 20 ;
- aucune exception ni frame résiduelle n'est apparue.

Le probe est vert 1/1 sur Flutter 3.41.0 et 3.47.2. Un mutant temporaire a
supprimé uniquement la garde `candidate > localCandidate` de la projection :
le même probe est devenu rouge sur 3.47.2 avec largeur réelle 60 au lieu de 40.
Le mutant a été restauré immédiatement ; le probe a ensuite été supprimé.
Aucun fichier produit ou test temporaire ne reste dans le worktree.

## Qualité des preuves permanentes

Les tests du delta produit/test — 23 chemins et 5 fixtures de fontes/licences —
ont été lus intégralement. Les oracles principaux ne se limitent pas à
inspecter le widget `Text` : ils comparent les métriques d'un
`RenderParagraph`, des painters témoins indépendants, des boxes de sélection,
les sorties exactes des scalers, les membres visibles d'un groupe, les frames
et les ressources natives.

Les preuves rouges/vertes des lots sont traçables dans leurs journaux et
rapports : suppression séparée des `dispose`, mutations du domaine virtuel,
ordre de composition du scaler, flattening RichText, segmentation répétée,
première/max/bounding box bidi, confusion `P/R`, perte de borne locale,
recherche linéaire, rollback de rapport, absence de notification et comparaison
de groupe par `==`. Les attentes historiques linéaires restent vertes.

Les deux dettes P3 sont isolées : aucun verdict fonctionnel de ce gate ne
dépend de la branche inutilisée de `doesTextFit` ou du test vide de
`maxLines`.

## Recoupement CORE et amont

| Finding / issue | Conclusion cumulative |
|---|---|
| #150 | Fermé par le lot 1 : tous les painters concernés sont disposés en `finally`. |
| CORE-06, CORE-11, #145 | Fermés par le lot 2 : domaine ancré au minimum, virtuel, validé et presets non mutés. |
| #151 | Durci partiellement seulement ; aucune fermeture amont n'est revendiquée sans reproduction originale. |
| CORE-02, CORE-03, #140, #104, #119 | Fermés pour texte simple/runs/groupes des lots 3 à 5 ; le complément inline attend le lot 10. |
| CORE-04, CORE-07, #142 | Fermés par le lot 4 : arbre fidèle, zéro explicite et NBSP/NNBSP. |
| CORE-05 | Fermé par le lot 5 avec projection dans le domaine propre et double borne. |
| CORE-01, #61, #106 | Non fermés : erreur transitoire déterministe ; support automatique réservé au lot 10. |
| #28, #30, #37, #77, #129, #147 | Non fermés : intrinsics/dry layout réservés aux lots 8 et 9. |
| CORE-08, CORE-10, #146 | Hors chaîne cœur ; lot 6. |
| CORE-09 | Contrat SDK établi au lot 0 ; fermeture CI réservée au lot 11. |
| #80, #81 | Restent backlog d'API ; seuls les comportements ambiants nécessaires à la parité sont respectés. |

Il n'existe donc ni fermeture prématurée des surfaces architecture, ni exigence
de `WidgetSpan`/intrinsics pour ce gate.

## Dette pour le futur dry layout

Le calcul local et la publication de groupe sont déjà séparés dans le build :
`_calculateFontSize` produit le résultat local, puis seulement le chemin wet
publie `P` et projette `R`. Il n'existe pas de cache de paragraphes ou de
configuration traversant les builds.

Le futur render object devra toutefois transformer cette séparation logique en
frontière d'API interne : une passe dry/intrinsèque ne devra ni appeler la
publication de groupe, ni planifier de microtâche, ni écrire le cache
`_publishedEffectiveFontSize`. La configuration aujourd'hui résolue depuis le
`BuildContext` devra être capturée côté widget puis fournie comme snapshot pur
au calcul du render object. C'est une dette planifiée des lots 8/9, pas un
défaut de la tête S6.

## Matrice exécutée

Toolchains exactes :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Engine cc8e596aa65130a0678cc59613ed1c5125184db4

Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
Engine 1cf1c4773fb941c4c74a7f8bb144a8837596c0f4
```

| Contrôle | Flutter 3.41.0 | Flutter 3.47.2 |
|---|---:|---:|
| résolution racine hors ligne, propre au SDK | succès | succès |
| analyse `--fatal-infos --fatal-warnings lib test example/main.dart` | 0 diagnostic | 0 diagnostic |
| suite racine complète sans probe | 115/115 | 115/115 |
| probe cumulatif temporaire | 1/1 | 1/1 |
| format autoritatif `lib test example` | non autoritatif | 26 fichiers, 0 changement |
| mutant sans borne locale | non rejoué | rouge : 60 obtenu au lieu de 40 |

Le premier essai de tests sous sandbox a échoué avant chargement à cause de
l'interdiction des sockets localhost du runner. Il a été rejoué avec cette
capacité normale autorisée ; ce premier échec d'environnement n'est pas un
échec produit. Les résolutions ont utilisé le cache local hors ligne.

## Surface documentaire lue

Ont été lus intégralement avant conclusion :

- les oracles de domaine candidat, configuration effective, métriques,
  RichText, RichText adversarial, projection de groupe et lifecycle groupe ;
- les journaux d'implémentation des lots 1 à 5 ;
- toutes les revues générales, spécialisées et d'assemblage des lots 1 à 5 ;
- `maintenance/audits/core-audit.md` et sa revue ;
- `maintenance/audits/upstream-issues-audit.md` et sa revue ;
- les sections lots 1 à 5, Gate Cœur, couverture et exclusions de la roadmap,
  ainsi que le plan cœur correspondant ;
- les skills `find-bugs` et `developing-flutter`, avec les références Effective
  Dart, Testing et architecture Flutter applicables.

Aucun `AGENTS.md` additionnel n'existe dans le worktree. L'instruction PostHog
fournie au chantier n'est pas applicable à cette revue locale.

## Audit sécurité et disponibilité

La surface est une bibliothèque Flutter locale : propriétés de widget, texte,
spans, scalers, contraintes, identité de groupe, microtâches et API moteur de
paragraphe. Il n'existe aucun réseau, base de données, authentification,
autorisation, session, secret, cryptographie, désérialisation distante ou
commande externe. Injection, XSS, CSRF, IDOR et divulgation sont hors surface.

Les risques applicables ont été contrôlés : validations numériques runtime,
recherche logarithmique, absence d'allocation proportionnelle aux grilles,
coût borné au niveau package pour la segmentation, dispose sur exceptions,
revalidation lifecycle des callbacks et absence de données appelant dans
l'erreur `WidgetSpan`. Aucun DoS concret, fuite, course ou exception inattendue
n'a été confirmé dans le contrat du gate.

## État final avant commit

Après restauration du mutant et suppression du probe, des configurations
temporaires, résolutions, builds et lock racine généré :

```text
git status --short --branch
## codex/gate-core-review

git diff -- lib test
# vide
```

Le commit de cette revue doit contenir uniquement le présent rapport.
