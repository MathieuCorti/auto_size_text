# Revue indépendante du plan de correction du cœur

Date : 2026-09-01

Plan revu : `maintenance/plans/core-implementation-plan.md`, commit
`c2620fde8b1cdd81ab8b5cd95b54b8179ae985ac`.

Base produit : `dev` / `8d459dd95c82265b3ae1a59d3fe3ad28a69751bd`.

Périmètre : validation des causes racines, du périmètre minimal, des
dépendances, de la compatibilité publique et des tests de chaque lot cœur.
Aucun code produit ni test permanent n'a été modifié.

## Verdict

**MODIFIÉ — le plan ne doit pas être implémenté tel quel.**

Les findings retenus, leur mapping et l'ordre général des lots 1 à 5 sont
fiables. Le plan comprend correctement la composition non linéaire du scaler,
la nécessité d'un domaine de candidats explicite, la projection locale des
groupes et la libération des painters.

Sept corrections sont néanmoins obligatoires avant le premier diff produit :

1. transformer la porte SDK en décision de versionnage testée, et non en choix
   dicté par le seul SDK déjà installé ;
2. préciser la compatibilité de `textScaler` et valider aussi l'ancien facteur
   en release ;
3. séparer réellement les responsabilités et les tests des lots texte simple
   et RichText ;
4. borner la projection de groupe par le candidat local qui a effectivement
   tenu, notamment en présence d'un scaler à plateau ;
5. rendre la grille numériquement définie, strictement ordonnée et testable
   sans dépendre des assertions ;
6. remplacer le lot 6 monolithique par un prototype bloquant, puis deux lots
   produits revus séparément ;
7. reconnaître que le remplacement du `Text` interne et la forte hausse du
   plancher sont des ruptures comportementales qui appellent une release
   majeure, même si les signatures historiques compilent encore.

Les lots render-object et `WidgetSpan` restent justifiés si la release promet
réellement de fermer CORE-01 et les six issues d'intrinsics. Ils ne sont en
revanche pas nécessaires pour seulement transformer le crash `WidgetSpan` en
limitation explicite. Cette distinction doit apparaître dans le plan et dans
les critères de fermeture d'issues.

## Décision sur le lot render object et `WidgetSpan`

### Ce qui est indispensable

Un `TextPainter` ne peut pas mesurer correctement un `WidgetSpan` sans
`PlaceholderDimensions`. Ces dimensions dépendent du layout réel du widget
inline, de sa baseline, du scaler hérité du run et de la largeur disponible.
Le build actuel, fondé sur `LayoutBuilder`, ne possède aucune de ces
informations.

Pour supporter automatiquement un `WidgetSpan` arbitraire tout en conservant
le contrat d'auto-size, il faut donc une couche de layout qui possède les
enfants inline. Un render object, ou une architecture de complexité
équivalente, est bien nécessaire. La dérivation ou la composition autour de
`RenderParagraph` est une direction raisonnable : cette classe fournit déjà
le rendu, les intrinsics, le dry layout, les semantics, la sélection, le hit
testing et la libération de ses painters.

### Pourquoi les correctifs ciblés ne ferment pas CORE-01

| Option ciblée | Effet | Verdict |
|---|---|---|
| Détecter le span et lever `UnsupportedError` | Diagnostic stable en release, mais l'application reçoit toujours une exception pour un arbre accepté par `Text.rich`. | Stabilisation seulement ; CORE-01 reste ouvert. |
| Fournir des dimensions nulles, nulles en taille ou estimées | Évite éventuellement l'assertion, mais choisit une taille sans mesurer l'enfant réel. | Incorrect pour le fit, le groupe et le replacement. |
| Rendre directement `Text.rich` au plus petit candidat | Supprime l'exception, mais abandonne l'auto-size et ne sait pas décider `overflowReplacement`. | Hotfix de disponibilité possible, à documenter comme fallback non supporté ; ne ferme pas CORE-01. |
| Ajouter `placeholderDimensions` à l'API | Peut servir aux cas manuels, mais impose au client un détail de layout, ne scale pas automatiquement et laisse l'usage existant sans dimensions en défaut. | Engagement public durable ; ne doit pas être introduit comme rustine. |
| Layout automatique des enfants inline | Mesure les dimensions réelles à chaque candidat et permet le rendu final cohérent. | Seule correction fonctionnelle compatible avec la promesse actuelle. |

Le plan a donc raison de refuser les dimensions manuelles comme résolution
finale. Il a tort, en revanche, de présenter d'emblée une implémentation
complète comme suffisamment spécifiée.

### Pourquoi le lot 6 doit être scindé

Les intrinsics ne sont pas une fonctionnalité opportuniste :
`Chip`, `DataTable`, `PaginatedDataTable`, `IntrinsicWidth` et
`IntrinsicHeight` reproduisent des exceptions sur des compositions valides.
Ils partagent avec `WidgetSpan` le besoin d'un moteur de layout hors build.
Cette cause commune justifie une même branche d'architecture, mais pas un seul
commit ni une seule revue.

Les sources Flutter 3.41 montrent aussi que le plan devra réimplémenter une
partie de comportement aujourd'hui privée : `RichText` extrait les spans via
`WidgetSpan.extractFromInlineSpan`, puis les enveloppe dans des adaptateurs
privés qui portent `TextParentData`, le scale, les intrinsics, les baselines et
les transformations de paint. Le scaler composé dépendant du candidat n'est
pas connu au build ; l'adaptateur public extrait par Flutter ne peut donc pas
simplement être réutilisé tel quel. Ce point rend obligatoire un prototype
avant de figer `_RenderAutoSizeParagraph`.

Le prototype doit démontrer, sans code produit persistant :

- qu'un sous-type ou une composition de `RenderParagraph` peut changer le span
  et le scaler du candidat final sans recopier son painter privé ;
- qu'un enfant inline peut être relayouté avec plusieurs scales pendant un
  même `performLayout` sans mutation interdite ni `markNeedsLayout` récursif ;
- que les baselines dry et wet concordent pour les alignements supportés ;
- que le wrapper d'overflow ne monte pas en permanence le paragraphe et le
  replacement. Aujourd'hui une seule branche est construite ; monter les deux
  déclencherait le cycle de vie d'un widget inactif ;
- que le painter de recherche et les painters possédés par le render object
  sont tous libérés ;
- que l'API publique de Flutter nécessaire est identique sur le minimum exact
  et la stable courante.

Le résultat du prototype doit être une note de décision. S'il échoue, la
release peut livrer les lots 1 à 5 avec une limitation `WidgetSpan` explicite,
mais elle ne doit annoncer ni CORE-01 ni les issues intrinsèques comme
corrigées.

## Corrections obligatoires transversales

### 1. Porte SDK et versionnage

Le plancher 3.41.6 est vérifiable localement, mais ce n'est pas le minimum
technique prouvé. Le dépôt Flutter local montre que le commit introduisant
`lineHeightScaleFactorOverride`, `letterSpacingOverride` et
`wordSpacingOverride` est déjà contenu dans le tag stable **3.41.0**. Le plan
doit donc choisir explicitement entre :

- tester Flutter 3.41.0 et le déclarer comme minimum réellement minimal ; ou
- conserver 3.41.6 comme politique de support, en documentant pourquoi les
  correctifs 3.41.1 à 3.41.5 sont volontairement exclus.

Dans les deux cas, `environment.flutter` et `environment.sdk` doivent
correspondre au SDK exact exécuté. La compilation des sources ne suffit pas :
`pub get`, format, analyse et suite complète doivent passer sur le minimum et
Flutter 3.47.2. Ce dernier n'était installé ni pendant les audits ni pendant
cette revue.

Passer d'une API déclarée Dart 2.12 sans minimum Flutter à Flutter 3.41 est une
rupture de support importante. Conserver `textScaleFactor` évite une rupture
source sur ce paramètre, mais ne rend pas la release rétrocompatible. Le plan
doit cibler une version majeure et fournir un guide de migration. Le changement
documenté de `textKey` renforce cette conclusion.

La porte SDK est un véritable lot 0 avec critères bloquants. La formulation
« livrer ou garantir » est trop faible : aucune correction produit ne doit être
fusionnée avant que le pubspec et les deux SDK de matrice soient disponibles.

### 2. Compatibilité de `textScaler` et `textScaleFactor`

L'addition de `TextScaler? textScaler` aux deux constructeurs et la priorité
`textScaler` explicite, sinon ancien facteur linéaire, sinon scaler ambiant,
sont correctes et cohérentes avec `Text`.

Le plan doit ajouter les exigences suivantes :

- annoter le paramètre des deux constructeurs et le champ historique avec
  `@Deprecated`, sans le supprimer dans cette release ;
- conserver les constructeurs `const` avec une assertion d'exclusion mutuelle,
  puis répéter cette validation dans le chemin runtime avec un
  `ArgumentError`, afin qu'un build release ne choisisse pas silencieusement un
  paramètre ;
- valider `textScaleFactor` comme fini et supérieur ou égal à zéro avant de le
  convertir. Les valeurs NaN, infinies et négatives doivent avoir un test
  public ;
- vérifier que chaque résultat de scaler réellement utilisé par la recherche
  et le groupe est fini et non négatif, ou documenter clairement que la
  violation du contrat d'un scaler personnalisé produit un `ArgumentError` ;
- donner au scaler composé une égalité et un `hashCode` cohérents avec le
  scaler source, le candidat et la référence, afin d'éviter des relayouts
  inutiles dans l'architecture render-object ;
- conserver exactement le comportement linéaire historique pour le test #25,
  les min/max, les presets et les groupes homogènes.

Pour une référence positive, la formule du plan est la bonne :
`userScaler.scale(runSize * candidate / reference)`. Transformer la taille
racine déjà scalée en `TextScaler.linear` recréerait le défaut audité.

Pour une référence nulle, la règle proposée est déterministe : seul le style
parent reçoit le candidat et les tailles explicites des descendants restent
inchangées. Elle constitue néanmoins un nouveau contrat et doit être annoncée,
pas seulement testée.

### 3. Une configuration effective, sans double application

La liste des propriétés effectives du plan couvre correctement CORE-03 : gras,
trois overrides d'espacement/hauteur, strut, wrap, overflow, direction, locale,
`TextWidthBasis` et `TextHeightBehavior` ambiants.

Tant que le lot render-object n'est pas fusionné, le widget final reste un
`Text`. Celui-ci réapplique lui-même les overrides ambiants. Le moteur de
mesure doit donc construire un arbre **équivalent** à celui de `Text.build`,
mais ne pas réinjecter dans `Text` un arbre déjà transformé d'une façon qui
appliquerait deux fois des changements non idempotents futurs. Un test témoin
doit comparer les métriques du painter de mesure à celles du `RenderParagraph`
réel ; inspecter seulement les propriétés du widget `Text` n'est pas suffisant.

Le lot 3 annonce du texte simple, mais exige déjà des tests avec plusieurs runs
et dépend du clonage récursif décrit seulement au lot 4. Ces tests sont rouges
pour une autre cause que celle du lot 3. Il faut :

- limiter le lot 3 au texte simple, à la résolution ambiante et à l'API des
  scalers ;
- déplacer les scalers non linéaires sur plusieurs runs, les sous-types de
  spans et les overrides récursifs au lot 4 ;
- ou fusionner explicitement les lots 3 et 4. La première option est préférable
  pour garder des régressions attribuables.

Les tests `DefaultTextStyle.textWidthBasis` et `textHeightBehavior` doivent
rester des tests d'héritage. Ils ne justifient pas l'ajout des APIs #80/#81.

### 4. Grille et validations

Le domaine virtuel ancré sur le minimum corrige bien CORE-06 et #145. La
recherche par indices entiers, la copie des presets et l'absence de tri
silencieux sont également appropriées.

Le plan doit toutefois définir un invariant numérique précis :

- la suite des candidats est finie, strictement croissante après déduplication
  et entièrement incluse dans `[min, upper]` ;
- `min` est toujours présent ;
- la référence ou la borne haute exacte est autorisée comme candidat terminal
  afin de préserver le comportement historique de `fontSize: 33.5`, mais elle
  ne crée pas deux candidats pratiquement identiques ;
- le calcul du dernier indice ne peut produire ni valeur sous le minimum, ni
  valeur au-dessus de la borne après arrondi ;
- la tolérance employée pour remplacer le dernier pas par la borne exacte est
  définie relativement à la magnitude, et non par une constante absolue
  implicite ;
- un intervalle plus petit qu'un pas et un très grand rapport intervalle/pas
  restent logarithmiques sans matérialiser de liste ;
- la dichotomie retourne un candidat du domaine, y compris lorsque aucun
  candidat ne tient.

Les tests invalides doivent appeler l'API publique et attendre
`ArgumentError`, ce qui les rend indépendants des assertions actives. Les
anciens tests qui attendaient `AssertionError` doivent être migrés dans le même
lot. Une exécution release n'est pas remplacée par un simple commentaire.

Le durcissement couvre partiellement les hypothèses de #151, comme le dit le
plan, mais ne doit jamais fermer cette issue sans sa reproduction.

### 5. Groupes hétérogènes

Publier une taille racine effective préserve le comportement historique des
scalers linéaires et donne une règle compréhensible à des membres ayant des
scalers différents. La projection sur `_CandidateSet`, plutôt qu'un `clamp`,
est indispensable pour les presets.

Il manque cependant une borne essentielle. Le membre doit choisir le plus
grand candidat qui :

1. ne dépasse pas le **candidat local ayant effectivement tenu** ; et
2. possède une taille racine effective inférieure ou égale à la limite du
   groupe.

La seconde condition seule est incorrecte avec un scaler à plateau, cas
explicitement permis par le contrat de `TextScaler`. Exemple : un scaler
`scale(x) = min(x, 20)` donne la même taille racine effective aux candidats 20
et 30. Dans un RichText, un run enfant peut encore être plus grand au candidat
30. Si le candidat local 20 tient et 30 échoue, la projection proposée par le
plan peut remonter à 30 puisque les deux racines valent 20.

Un test avec ce scaler à plateau et un run enfant de taille différente doit
échouer sans cette borne locale. Les tests doivent aussi prouver :

- que `textFits` et `overflowReplacement` restent attachés au candidat local
  minimal, pas à la seule valeur du groupe ;
- qu'une égalité de valeurs effectives ne provoque ni oscillation ni boucle de
  microtâches ;
- que la remontée converge en un nombre borné de frames après retrait ou
  changement de groupe ;
- qu'aucun membre ne sort de son domaine même lorsque deux presets produisent
  la même taille effective.

La monotonicité non décroissante de `TextScaler.scale` doit être une hypothèse
documentée de la projection logarithmique. Un scaler personnalisé qui la viole
sort du contrat pris en charge.

### 6. Cycle de vie des painters

Le lot 1 est accepté avec deux précisions :

- le test doit observer la création et la disposition des `TextPainter` ou
  des paragraphes natifs, et avoir été démontré rouge sans chacun des
  `dispose`; un test qui attend seulement le ramassage de l'objet Dart n'est
  pas une preuve suffisante ;
- tout painter de test ou helper, notamment `doesTextFit` s'il est conservé,
  suit la même règle. Le painter possédé plus tard par `RenderParagraph` est
  libéré par son `dispose`, tandis que tous les painters spéculatifs restent
  sous `try/finally`.

Le SDK 3.41.6 fournit déjà une version bornée de
`leak_tracker_flutter_testing` via `flutter_test`. Si une dépendance directe
est nécessaire, elle doit être fixée à une plage compatible avec le minimum et
ne jamais utiliser `any`.

## Corrections obligatoires du futur render object

### Dry layout et groupe

Le plan promet le même candidat dry et wet « à contraintes identiques », y
compris dans les tests groupés. Cette promesse est impossible au premier
layout d'un groupe : une passe dry ne peut pas publier sa valeur, tandis que la
passe wet modifie le minimum partagé et peut réduire un autre membre.

La règle correcte est :

- dry layout et intrinsics calculent le candidat **local non groupé** et ne
  lisent ni ne modifient un minimum partagé dépendant d'un layout précédent ;
- wet layout calcule le même candidat local, puis applique la projection de
  groupe ;
- la parité dry/wet exacte est exigée sans groupe, ou avec une limite de groupe
  immuable déjà fournie à la mesure ;
- avec un groupe actif, le candidat wet final peut être inférieur au candidat
  dry local. Le test porte sur la pureté, la borne et la convergence après les
  frames de notification, pas sur une égalité impossible.

### Sémantique des intrinsics

Les quatre méthodes doivent avoir une spécification distincte. Pour un
candidat choisi selon la dimension fournie, `computeMinIntrinsicWidth` doit
retourner sa largeur intrinsèque minimale et `computeMaxIntrinsicWidth` sa
largeur maximale ; elles ne peuvent pas être deux alias d'une « largeur qui
tient ». La même distinction et les cas `double.infinity` doivent être testés
pour les hauteurs.

Un contrôle `Row + Expanded` est utile comme non-régression, mais il ne ferme
aucune des six issues intrinsèques et ne doit pas être compté dans leur preuve.

### `overflowReplacement`

Le render object ne peut pas simplement construire le paragraphe, ses enfants
inline et le replacement puis n'en peindre qu'un. Le comportement actuel ne
monte que la branche retournée. Le plan doit tester avec des widgets stateful
que :

- le replacement n'est pas monté lorsque le texte tient ;
- les enfants inline ne restent pas montés lorsque le replacement est actif,
  sauf changement de contrat explicitement annoncé ;
- la branche inactive ne reçoit ni layout, ni paint, ni hit test, ni semantics ;
- le passage d'une branche à l'autre n'introduit pas de frame où les deux sont
  visibles ou sémantiques.

### Compatibilité de `textKey`

Conserver `find.byKey(textKey)` ne suffit pas à préserver le contrat actuel.
La documentation promet « l'instance réelle de `Text` » et des consommateurs
peuvent faire `tester.widget<Text>`. Après le lot render-object, le widget
trouvé aura un autre type.

Cette rupture doit être annoncée dans le guide de migration et testée comme le
nouveau contrat : la clé identifie le paragraphe rendu, sans garantie de type
`Text`. Elle ne peut pas être présentée comme une simple modification interne.

## Lots finaux recommandés

### Lot 0 — Contrat SDK, version majeure et harness

- Choisir et installer le minimum exact, idéalement 3.41.0 si aucune raison de
  politique n'impose 3.41.6.
- Déclarer les contraintes Dart/Flutter correspondantes.
- Installer aussi Flutter 3.47.2 et rendre minimum + stable courante bloquants.
- Fixer la version cible majeure et la migration de `textKey`.
- Configurer un leak tracking borné.

**Bloque tous les lots produits.**

### Lot 1 — Cycle de vie, #150

- Ajouter les `try/finally` autour de chaque painter temporaire.
- Couvrir les deux painters, les retours anticipés, les exceptions, les
  rebuilds et le groupe.
- Prouver chaque test rouge sans son `dispose`.

**Indépendant, aucune modification de taille attendue.**

### Lot 2 — Domaine de candidats et validations, CORE-06, CORE-11, #145

- Introduire `_CandidateSet` virtuel avec invariants numériques explicites.
- Valider min/max/pas/référence/presets et ancien facteur en runtime.
- Préserver la référence exacte, les presets et les résultats historiques
  valides.
- Garder #151 ouvert.

**Indépendant du layout de texte.**

### Lot 3 — Configuration effective du texte simple et `TextScaler`, CORE-02,
CORE-03, #140, #104, #119

- Ajouter l'API compatible et le scaler composé.
- Résoudre les propriétés ambiantes influençant le layout simple.
- Comparer les métriques de mesure au `RenderParagraph` réellement rendu.
- Tester scaler absent, explicite, ancien, linéaire, non linéaire, bascules de
  contexte, gras, overrides, strut, wrap, direction et locale.
- Ne pas revendiquer encore les runs RichText hétérogènes.

**Dépend des lots 1 et 2.**

### Lot 4 — Arbre RichText, zéro et segmentation, CORE-04, CORE-07, #142

- Conserver le span original sous le parent effectif.
- Appliquer les overrides aux seuls `TextSpan` standards comme le fait Flutter,
  sans muter l'arbre ni perdre ses métadonnées.
- Tester le scaler composé sur plusieurs runs, les sous-types inconnus, la
  référence zéro, les recognizers et les semantics.
- Définir les opportunités minimales de coupure, y compris espaces ordinaires,
  tabulations et retours explicites, tout en excluant NBSP et NNBSP. Un UAX #14
  complet reste hors périmètre.

**Dépend du lot 3.**

### Lot 5 — Groupes hétérogènes, CORE-05

- Publier la taille racine effective locale.
- Projeter sous la double borne candidat local + limite effective du groupe.
- Tester plateaux, presets disjoints, scalers différents, retrait, changement,
  dispose, convergence et replacement local.

**Dépend des lots 2 à 4.**

### Lot 6 — Prototype d'architecture, sans code produit

- Valider `RenderParagraph`, enfants inline candidats, baselines, branches
  d'overflow, groupe et durée de vie sur minimum + stable courante.
- Écrire la décision d'architecture et estimer la surface réellement privée à
  reproduire.

**Gate bloquant des lots 7 et 8.**

### Lot 7 — Render object texte seul et intrinsics,
#28/#30/#37/#77/#129/#147

- Remplacer `LayoutBuilder` pour le texte simple et riche sans WidgetSpan.
- Implémenter dry layout et les quatre intrinsics purs selon leur contrat.
- Préserver groupe, replacement, sélection, semantics et recherche
  logarithmique.
- Appliquer le nouveau contrat majeur de `textKey`.

**Revue architecturale indépendante. Ne ferme pas CORE-01.**

### Lot 8 — `WidgetSpan` automatique, CORE-01, #61/#106

- Ajouter les enfants inline et leurs dimensions candidates au render object
  stabilisé.
- Tester dimensions, ordre, scales par run, baselines, paint, hit testing,
  sélection, semantics, groupe, replacement et dispose.
- Ne fermer CORE-01 qu'après un usage sans dimensions manuelles.

**Revue indépendante du lot 7.**

Si les lots 6 à 8 ne sont pas prêts, les lots 1 à 5 peuvent former une release
de correction séparée, à condition de ne pas promettre la résolution de
`WidgetSpan` ou des intrinsics. Aucun fallback silencieusement approximatif ne
doit être présenté comme une correction complète.

## Tests capables d'échouer et critères de sortie

Chaque test de régression doit être exécuté contre le commit de base ou contre
le parent direct du lot et produire l'échec attendu pour **la cause du lot**.
Un test RichText rouge pendant le lot simple, un test leak vert grâce au GC ou
un test groupé qui vérifie seulement le widget final ne satisfont pas ce
critère.

La sortie cœur requiert :

- format, analyse et suite complète sur le minimum exact et Flutter 3.47.2 ;
- résultats historiques linéaires inchangés pour toutes les entrées valides ;
- aucun candidat hors domaine ni projection au-dessus du candidat local ;
- aucune notification de groupe depuis une passe dry ou intrinsèque ;
- aucun painter temporaire ou possédé conservé après dispose ;
- aucune branche inactive de replacement montée ou exposée aux semantics selon
  le contrat retenu ;
- revue séparée des lots 7 et 8 ;
- guide de migration majeur pour plancher, `textScaler`, référence zéro et
  `textKey` ;
- fermeture des issues uniquement par les lots mappés. #151, #80, #81 et #146
  restent hors des fermetures cœur.

## Vérifications effectuées

### Documents lus intégralement

- `maintenance/audits/core-audit.md` ;
- `maintenance/audits/tooling-audit.md` ;
- `maintenance/audits/upstream-issues-audit.md` ;
- `maintenance/reviews/core-audit-review.md` ;
- `maintenance/reviews/tooling-audit-review.md` ;
- `maintenance/reviews/upstream-audit-review.md` ;
- `maintenance/plans/core-implementation-plan.md` ;
- les instructions `developing-flutter`, Effective Dart, testing et
  `find-bugs`.

### Code et tests lus intégralement

- `lib/auto_size_text.dart` et les trois fichiers `lib/src` ;
- les onze fichiers Dart de `test/` ;
- `pubspec.yaml`.

Des extraits ciblés de Flutter 3.41.6, 3.44.0 et 3.35.3 ont été contrôlés pour
`Text`, `RichText`, `RenderParagraph`, `WidgetSpan`, `TextPainter`,
`TextStyle`, `TextScaler` et `MediaQuery`. L'historique local Flutter confirme
que les trois overrides sont contenus dans le tag 3.41.0.

### Surface et checklist de risque

Le seul fichier changé par la branche revue était le plan Markdown. La surface
produit projetée comprend les paramètres publics du widget, les contraintes de
layout, les spans et widgets inline, le scaler utilisateur, les allocations de
paragraphes et l'état partagé du groupe.

| Catégorie | Conclusion |
|---|---|
| Injection, XSS, SQL, auth, autorisation, CSRF, session | Hors surface : widget Flutter local sans réseau, base, template ou identité. |
| Cryptographie, secrets, divulgation | Hors surface du plan cœur. Aucun secret ni primitive n'est ajouté. |
| Appels externes et supply chain | Aucun appel produit. La version du harness de leak et les SDK doivent être épinglés par le lot 0. |
| Race / état | Risques réels autour des microtâches de groupe et des mutations pendant layout ; corrections et tests exigés ci-dessus. |
| Déni de service | Recherche virtuelle logarithmique requise ; attention aux domaines numériques extrêmes et aux layouts répétés des widgets inline. |
| Logique métier / numérique | Corrections obligatoires sur grille, scaler à plateau, dry/group et branche d'overflow. |
| API / compatibilité | Hausse majeure du plancher et changement observable de `textKey`; release majeure requise. |

### Limites

Flutter 3.47.2 et Flutter 3.41.0 n'ont pas été exécutés pendant cette revue.
Aucun prototype render-object complet, build release sans assertions, appareil
physique, web ou benchmark de widgets inline n'a été réalisé. Ces inconnues ne
remettent pas en cause les lots 1 à 5, mais elles interdisent d'accepter les
détails d'implémentation actuels des lots render-object et `WidgetSpan` sans le
prototype demandé.
