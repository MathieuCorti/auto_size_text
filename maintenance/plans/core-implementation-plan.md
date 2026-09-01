# Plan minimal de correction du cœur `auto_size_text`

Date : 2026-09-01

Base : `dev` / `8d459dd95c82265b3ae1a59d3fe3ad28a69751bd`

Périmètre : comportement et API du package. Ce document réconcilie les audits
du cœur et des issues amont avec leurs revues indépendantes. Il ne planifie ni
la démo, ni la gouvernance de publication, ni la réfection générale de la CI.

## Résultat attendu

La release cœur ne doit plus :

- planter dans les compositions intrinsèques ou avec un `WidgetSpan` valide ;
- réduire un `TextScaler` non linéaire à un coefficient ;
- mesurer un paragraphe différent de celui qui est rendu ;
- sortir des candidats autorisés par un minimum, une grille ou des presets ;
- laisser un groupe imposer à un membre une taille qui lui est interdite ;
- conserver des paragraphes natifs après la mesure.

Les corrections doivent garder la recherche logarithmique, les deux
constructeurs, les valeurs par défaut et tous les paramètres publics actuels.
La seule addition d'API prévue est `TextScaler? textScaler`; l'ancien
`double? textScaleFactor` reste disponible et devient explicitement déprécié.

## Décisions de cadrage

### Porte SDK et outillage

La décision de plancher est un préalable bloquant, pas un détail du lot CI.

- `TextScaler` impose au minimum Flutter 3.16 / Dart 3.2.
- La parité complète avec le `Text` courant exige aussi
  `MediaQueryData.lineHeightScaleFactorOverride`, `letterSpacingOverride` et
  `wordSpacingOverride`. Ces API sont présentes dans la ligne locale Flutter
  3.41.6 / Dart 3.11.4, mais absentes de Flutter 3.35.3.
- Le plan recommande donc Flutter **3.41.6 / Dart 3.11.4 comme plus ancien
  plancher immédiatement vérifiable**, puis Flutter 3.47.2 / Dart 3.13.2 comme
  stable courante. Si un patch antérieur de la série 3.41 est souhaité, sa
  présence exacte doit être vérifiée avant de l'inscrire au `pubspec`.
- Conserver un plancher 3.16 obligerait soit à différer les overrides confirmés
  de CORE-03, soit à introduire un accès `dynamic` dépendant de version. Cette
  compatibilité fragile est exclue du plan minimal.
- `TextPainter.dispose` est disponible au plancher recommandé. Le test de fuite
  dépend en revanche d'une version bornée de `leak_tracker_flutter_testing` ou
  du support équivalent fourni par ce SDK; cette version doit être choisie par
  le lot outillage, jamais avec `any`.

Avant le premier lot produit, le chantier outillage doit donc livrer ou garantir
au minimum : contraintes `environment` cohérentes, résolution du harness de
test, et exécution exacte sur minimum + stable courante. La migration globale
des lints, la démo et Codecov ne bloquent pas l'écriture des correctifs, mais la
release finale ne peut être déclarée verte sans la baseline outillage décrite
par les deux audits correspondants.

### Contrat de taille conservé

Le moteur manipulera trois notions distinctes :

1. le **candidat logique racine**, choisi dans la grille ou les presets ;
2. le **ratio d'auto-size**, `candidat / tailleDeRéférence`, lorsque la
   référence est strictement positive ;
3. la **taille racine effective**, `scalerUtilisateur.scale(candidat)`, seule
   unité publiée au groupe.

Pour une référence positive, chaque run est transformé conceptuellement par
`scalerUtilisateur.scale(tailleDuRun * ratio)`. L'auto-size intervient donc
avant la courbe utilisateur; il ne reconstruit jamais un `TextScaler.linear` à
partir du résultat racine.

Une référence racine nulle ne peut pas définir un ratio. La règle minimale et
documentable sera : remplacer la taille du parent synthétique par le candidat,
appliquer directement le scaler utilisateur, et conserver inchangées les
tailles explicitement déclarées par les spans descendants. Aucun epsilon et
aucune division par zéro ne seront introduits.

### Configuration effective unique

Une structure privée immuable sera construite une fois par build et consommée
par tous les painters ainsi que par le rendu. Elle contiendra :

- le style parent fusionné avec `DefaultTextStyle`, la taille par défaut et le
  gras de `MediaQuery` exactement comme `Text` ;
- les overrides ambiants de hauteur, d'espacement des lettres et des mots,
  appliqués récursivement sans muter le span de l'appelant ;
- le `StrutStyle` effectif après override de hauteur ;
- `textAlign`, `textDirection`, `locale`, `softWrap`, `overflow` et `maxLines`
  résolus avec les mêmes priorités que `Text` ;
- les valeurs ambiantes de `TextWidthBasis` et `TextHeightBehavior`, sans les
  exposer encore comme nouveaux paramètres publics ;
- le scaler explicite, sinon l'ancien facteur converti en scaler linéaire,
  sinon le scaler ambiant.

La largeur de layout suivra la règle de `RenderParagraph` : largeur contrainte
si le texte wrappe ou si l'overflow est `ellipsis`, largeur infinie sinon, puis
comparaison de la largeur mesurée avec la contrainte réelle.

### Validation en debug et en release

Les préconditions qui protègent l'algorithme ne reposeront plus uniquement sur
`assert`. La validation de build lèvera `ArgumentError` dans tous les modes :

- minimum fini et positif ou nul ;
- maximum strictement positif, fini ou `double.infinity`, et supérieur ou égal
  au minimum ;
- pas fini et au moins égal au contrat historique `0.1` ;
- taille de référence finie et positive ou nulle ;
- presets non vides, finis, positifs ou nuls et monotones non croissants.

Les doublons de presets restent acceptés : ils ne changent pas l'ensemble des
tailles autorisées. La liste de l'appelant n'est ni triée ni mutée. Les autres
assertions de construction (`maxLines`, clés, overflow exclusif) restent en
place sauf si le lot outillage décide séparément d'unifier la politique
d'erreur.

## Réconciliation par cause racine

| Cause racine | Findings / issues couverts | Destination |
|---|---|---|
| Painters non libérés | #150 | Lot 1, must-fix |
| Domaine de candidats ancré à zéro ou invalide | CORE-06, CORE-11, #145; durcissement partiel de #151 | Lot 2, must-fix |
| Scaler et configuration mesure/rendu divergents | CORE-02, CORE-03, #140, #104, #119 | Lot 3, must-fix |
| Arbre riche aplati, référence zéro et segmentation fautive | CORE-04, CORE-07, #142 | Lot 4, must-fix |
| Valeur de groupe appliquée hors domaine du membre | CORE-05 | Lot 5, must-fix |
| `LayoutBuilder` sans dry layout et placeholders sans dimensions | CORE-01, #28, #30, #37, #61, #77, #106, #129, #147 | Lot 6, must-fix |
| Parité publique optionnelle avec d'autres propriétés de `Text` | #80, #81 | Backlog fonctionnalité |
| Démo et plateforme Android | CORE-08, CORE-10, #146 | Plan démo/outillage, hors cœur |

#151 reste « besoin d'information » : les validations prévues empêchent les
valeurs non finies ou le pas nul d'atteindre la recherche, mais l'issue ne doit
pas être fermée sans sa reproduction originale.

## Ordre et dépendances

| Ordre | Lot | Dépendances | Peut être revu isolément |
|---:|---|---|---|
| 0 | Porte SDK/harness | Décision mainteneur | Oui, aucun comportement produit |
| 1 | Cycle de vie des painters | Porte SDK | Oui |
| 2 | Domaine de candidats et validations | Porte SDK | Oui, en parallèle du lot 1 |
| 3 | Configuration effective et scaling moderne | Lots 1 et 2 | Oui |
| 4 | RichText fidèle, zéro et segmentation | Lot 3 | Oui |
| 5 | Groupes hétérogènes | Lots 2 à 4 | Oui |
| 6 | Render object, intrinsics et `WidgetSpan` | Lots 1 à 5 | Branche/revue dédiée |

Le lot 6 a l'impact le plus élevé, mais il vient en dernier pour réutiliser un
moteur de mesure déjà testé. Cela évite de cacher toutes les corrections de
parité dans une réécriture de render object.

## Lot 1 — Cycle de vie des `TextPainter`

**Objectif.** Fermer #150 sans changer la taille choisie.

**Fichiers prévus.**

- `lib/src/auto_size_text.dart` ;
- `test/text_painter_lifecycle_test.dart` ;
- `test/flutter_test_config.dart` et `pubspec.yaml` uniquement si le leak
  tracking centralisé l'exige.

**API.** Aucun changement public.

**Algorithme minimal.** Chaque painter créé pendant un essai est entouré d'un
`try/finally`. Le painter de contrôle `wrapWords: false` est libéré avant tout
retour anticipé, puis le painter principal l'est sur succès comme sur exception.
Lors de l'extraction ultérieure du moteur de mesure, ce même invariant suit la
fonction, sans créer une seconde politique de durée de vie.

**Tests de régression.** Dans un `group('TextPainter lifecycle', ...)`, avec des
noms « should ... » : texte simple qui tient, texte qui échoue au minimum,
`wrapWords: false` qui tient, retour anticipé sur un mot trop large, plusieurs
rebuilds et un groupe. Le test doit échouer si l'un des deux painters reste
vivant; le helper `doesTextFit` doit lui aussi disposer son painter s'il est
conservé.

**Risques.** Configuration de leak tracker incompatible avec le plancher, ou
test vert qui ne suit que les objets Dart et pas le paragraphe natif.

**Critères d'acceptation.** Tous les chemins possèdent un `finally`, le test de
fuite a été démontré rouge en retirant un `dispose`, et les 23 résultats
historiques restent identiques.

## Lot 2 — Domaine de candidats, grille fractionnaire et validations

**Objectif.** Garantir qu'une recherche retourne toujours un candidat autorisé,
en debug comme en release.

**Fichiers prévus.**

- nouveau `lib/src/auto_size_text_layout.dart` pour `_CandidateSet` et les
  validations privées ;
- `lib/auto_size_text.dart` pour la déclaration `part` ;
- `lib/src/auto_size_text.dart` pour utiliser le domaine ;
- `test/step_granularity_test.dart` ;
- `test/min_max_font_size_test.dart` ;
- `test/preset_font_sizes_test.dart` ;
- `test/text_fits_test.dart`.

**API.** Signatures et valeurs par défaut inchangées. Les entrées hors contrat
produisent désormais un `ArgumentError` déterministe au lieu d'une assertion ou
d'un résultat indéfini.

**Algorithme minimal.**

- Le domaine non preset est virtuel : `min + index * step`; aucune liste
  potentiellement énorme n'est matérialisée.
- La borne haute est la taille de référence clampée par min/max, ce qui
  conserve l'absence de grossissement au-delà du style initial.
- Le minimum et la borne haute exacte sont toujours des candidats. Si le
  dernier pas tombe à la borne à l'erreur flottante près, la valeur exacte de
  la borne remplace le résultat calculé; sinon la borne est ajoutée comme
  dernier candidat.
- La dichotomie travaille uniquement sur des indices entiers et renvoie le plus
  grand candidat qui tient. Elle ne fait jamais `floor(min / step)`.
- Les presets sont copiés, validés dans leur ordre descendant, puis consultés
  par indice sans tri silencieux.

**Tests de régression précis.**

- `minFontSize: 0.3`, `stepGranularity: 0.1` ;
- `minFontSize: 16.3`, `stepGranularity: 1` (#145) ;
- minimum 12/pas 5, avec preuve qu'aucune taille 10 n'est produite ;
- plage dont l'écart n'est pas multiple du pas, minimum exact et borne haute
  exacte ;
- référence 33.5 qui tient, puis contrainte voisine qui sélectionne le candidat
  immédiatement inférieur ;
- ancien domaine entier 12..60/pas 1 inchangé ;
- presets descendants, disjoints des futures grilles, doublons acceptés et
  liste de l'appelant inchangée ;
- liste vide, croissante, négative, NaN ou infinie, ainsi que min/max/pas NaN,
  infinis ou désordonnés : `ArgumentError`, pas `AssertionError` ;
- `maxFontSize == double.infinity` reste valide.

**Risques.** Changement volontaire pour les anciennes entrées qui violaient la
divisibilité documentée seulement par assertion; erreurs d'arrondi au dernier
indice; régression de performance si le domaine est matérialisé.

**Critères d'acceptation.** Recherche logarithmique, aucune sortie sous le
minimum ou hors presets, taille initiale exacte conservée, et tests d'entrée
invalide capables de passer avec assertions désactivées.

## Lot 3 — Configuration effective et `TextScaler`

**Objectif.** Faire mesurer et rendre le même paragraphe simple avec la même
courbe d'accessibilité, puis fournir l'infrastructure utilisée par RichText.

**Fichiers prévus.**

- `lib/src/auto_size_text.dart` pour l'API et la résolution depuis le contexte ;
- `lib/src/auto_size_text_layout.dart` pour `_EffectiveTextConfiguration`, le
  scaler composé et le moteur de mesure ;
- `test/basic_test.dart`, `test/text_fits_test.dart`,
  `test/overflow_replacement_test.dart`, `test/utils.dart` ;
- nouveaux `test/text_scaler_test.dart` et
  `test/effective_text_configuration_test.dart` ;
- fontes déterministes regular/bold et leur licence sous `test/assets/` si les
  fontes du harness ne différencient pas leurs métriques ;
- `README.md` et `CHANGELOG.md` pour l'addition d'API et sa migration.

**API conservée ou migrée.** Ajouter `TextScaler? textScaler` aux deux
constructeurs, avec la même priorité que `Text`. Garder `textScaleFactor`, le
marquer `@Deprecated`, le convertir en `TextScaler.linear` et rejeter la
fourniture simultanée des deux paramètres. `textScaler: TextScaler.noScaling`
reste le moyen explicite de neutraliser le scaling ambiant.

**Algorithme minimal.**

- Construire la configuration effective décrite plus haut et un parent
  `TextSpan` synthétique. Le rendu et chaque painter reçoivent ces mêmes valeurs.
- Pour une référence positive, utiliser un scaler privé dont `scale(s)` vaut
  `scalerUtilisateur.scale(s * candidat / référence)`.
- Appliquer le gras et les trois overrides comme le fait `Text`; fusionner
  l'override de hauteur au strut.
- Résoudre direction et locale depuis leurs contextes ambiants au lieu des
  fallbacks LTR/null actuels.
- Pour `softWrap: false`, mesurer avec une largeur infinie sauf ellipsis, puis
  vérifier la largeur réelle contre `constraints.maxWidth`.
- Garder le résultat `textFits` attaché au plus petit candidat local pour que
  `overflowReplacement` reste cohérent.

**Tests de régression précis.**

- scaler linéaire explicite, ancien facteur et scaler ambiant ;
- scaler non linéaire déterministe dont `scale(30) != 30 * textScaleFactor`,
  avec plusieurs tailles de runs, limites min/max et presets ;
- `textScaler` + `textScaleFactor` ensemble rejetés ;
- changement du scaler ambiant entre deux pumps ;
- `boldText` qui oblige une taille inférieure avec les fontes regular/bold ;
- `letterSpacingOverride`, `wordSpacingOverride` et
  `lineHeightScaleFactorOverride` séparément, puis bascule entre deux pumps ;
- `StrutStyle(fontSize: 100, forceStrutHeight: true)` sous hauteur 60, avec et
  sans override de hauteur ;
- `softWrap: false` explicite et hérité, avec overflow clip puis ellipsis, et
  déclenchement correct de `overflowReplacement` ;
- direction RTL et locale héritées puis explicites ;
- `DefaultTextStyle.textWidthBasis`, `textHeightBehavior` et
  `DefaultTextHeightBehavior` ambiant, sans ajouter les paramètres #80/#81.

**Risques.** Hausse du plancher; courbe composée appliquée dans le mauvais ordre;
copie incomplète du comportement de `Text`; tailles attendues volontairement
plus petites en gras, ce qui peut ensuite affecter un groupe.

**Critères d'acceptation.** Le painter témoin construit avec la configuration
effective produit les mêmes métriques que le paragraphe rendu pour chaque cas;
aucun usage produit de `MediaQuery.textScaleFactorOf` ou du paramètre déprécié
de `TextPainter` ne subsiste; les changements ambiants déclenchent un nouveau
calcul.

## Lot 4 — Arbre RichText fidèle, référence zéro et segmentation

**Objectif.** Fermer les divergences propres aux spans sans construire un
moteur rich-text général.

**Fichiers prévus.**

- `lib/src/auto_size_text_layout.dart` ;
- `lib/src/auto_size_text.dart` ;
- `test/wrap_words_test.dart` ;
- nouveau `test/rich_text_test.dart` ;
- `test/text_scaler_test.dart` et `test/overflow_replacement_test.dart`.

**API.** Aucun paramètre supplémentaire. La règle de référence zéro est ajoutée
à la documentation. Les recognizers, labels sémantiques et spans fournis restent
ceux de l'appelant au rendu.

**Algorithme minimal.**

- Placer le `TextSpan` original comme enfant intact du parent synthétique qui
  porte le style effectif; ne plus recopier seulement `text`, `children` et
  `recognizer` ni remplacer le style parent par le style racine du span.
- Pour les overrides d'espacement, cloner seulement les `TextSpan` standards,
  recopier toutes leurs métadonnées et styles, et laisser les sous-types
  inconnus ainsi que les `WidgetSpan` intacts. Ne jamais muter l'arbre reçu.
- Pour `wrapWords: false`, déterminer les plages non sécables à partir du texte
  brut en considérant les espaces ordinaires comme opportunités de coupure mais
  jamais U+00A0 ni U+202F. Mesurer ces plages sur le painter non wrappé avec des
  sélections/boxes afin de conserver les runs, au lieu de reconstruire un span
  monostyle. Une implémentation complète de l'UAX #14 est hors périmètre.
- Pour la référence zéro, reconstruire uniquement le style du parent synthétique
  avec le candidat et laisser les tailles explicites des descendants inchangées.

**Tests de régression précis.**

- span racine partiellement stylé sous un parent à 30 ;
- enfants imbriqués avec tailles, poids, familles, hauteur, letter/word spacing
  différents, sous scaler linéaire puis non linéaire ;
- `wrapWords: false` avec un mot porté par plusieurs spans stylés ;
- espace normal, NBSP U+00A0, NNBSP U+202F et chaîne mixte ;
- recognizer toujours déclenché, semantics du span conservées, arbre fourni
  inchangé après plusieurs pumps ;
- référence zéro simple et riche, minimum zéro puis positif, enfant à taille
  explicite, contrainte minuscule et `overflowReplacement`.

**Risques.** Indices UTF-16/bi-directionnels lors du calcul des boxes; coût par
mot; perte accidentelle de métadonnées en clonant un span; sémantique zéro
surprenante si elle n'est pas documentée.

**Critères d'acceptation.** Les métriques mesure/rendu concordent avec des runs
hétérogènes, aucune coupure n'est autorisée sur NBSP/NNBSP, aucune division par
zéro n'existe, et les interactions/sémantiques restent fonctionnelles.

## Lot 5 — Groupes hétérogènes

**Objectif.** Préserver les domaines individuels tout en conservant la
synchronisation historique en taille racine effective.

**Fichiers prévus.**

- `lib/src/auto_size_group.dart` ;
- `lib/src/auto_size_text.dart` ;
- `lib/src/auto_size_text_layout.dart` ;
- `test/group_test.dart`, `test/group_builder_test.dart`,
  `test/preset_font_sizes_test.dart` ;
- nouveau `test/group_constraints_test.dart`.

**API.** `AutoSizeGroup` et les paramètres `group` restent inchangés. Aucune API
de facteur individuel (#47/#50) et aucun callback de taille calculée ne sont
ajoutés.

**Algorithme minimal.**

- Chaque membre calcule son candidat logique local, puis publie au groupe sa
  taille racine effective `scalerUtilisateur.scale(candidat)`.
- Le groupe garde le minimum de ces valeurs effectives, comme le faisait le
  comportement linéaire historique.
- Au rendu, le membre projette cette limite sur son propre `_CandidateSet` :
  plus grand candidat autorisé dont la taille effective ne dépasse pas la
  limite. La projection reste logarithmique.
- Si aucun candidat du membre n'est assez petit, il rend son minimum ou son plus
  petit preset et diverge du groupe, conformément à la README. Il ne réécrit
  pas pour autant la valeur publiée aux autres membres.
- Le changement/retrait d'un membre recalcule le minimum et permet la remontée.
  Les notifications restent coalescées et ignorent les états démontés.

**Tests de régression précis.**

- minima 10 et 20 dans le même groupe ;
- maxima différents, pas différents et grille fractionnaire ;
- presets disjoints : chaque résultat appartient exactement à sa liste ;
- scaler 1, scaler linéaire différent et deux scalers non linéaires ;
- membre incapable d'atteindre la taille commune, sans abaisser son minimum ;
- membre retiré, changement d'`AutoSizeGroup` dans `didUpdateWidget`, puis
  remontée après élargissement ;
- `overflowReplacement` local et absence de notification après dispose.

**Risques.** Confondre candidat logique et taille effective; oscillation à cause
des arrondis; boucle de microtâches lors de la remontée; projection linéaire qui
créerait une taille hors preset.

**Critères d'acceptation.** Aucun membre sous son minimum ou hors de son domaine,
comportement historique inchangé pour groupes homogènes/scaler linéaire, remontée
en nombre borné de frames, aucune mutation de la valeur de groupe par une simple
projection locale.

## Lot 6 — Render object, intrinsics, dry layout et `WidgetSpan`

**Objectif.** Supprimer la cause architecturale des six issues intrinsèques et
prendre réellement en charge les widgets inline. Une erreur explicite ou une
API manuelle de dimensions ne clôt pas CORE-01.

**Fichiers prévus.**

- nouveau `lib/src/auto_size_text_render_object.dart` ;
- `lib/auto_size_text.dart` pour la déclaration `part` ;
- `lib/src/auto_size_text.dart` pour remplacer `LayoutBuilder` et relier le
  groupe au layout humide uniquement ;
- `lib/src/auto_size_text_layout.dart` pour fournir la mesure pure ;
- `test/utils.dart` pour inspecter les métriques sans dépendre d'un widget
  `Text` interne ;
- nouveaux `test/intrinsics_test.dart` et `test/widget_span_test.dart` ;
- `test/overflow_replacement_test.dart`, `test/group_test.dart`,
  `test/basic_test.dart` et `test/text_painter_lifecycle_test.dart`.

**API conservée ou migrée.** Tous les constructeurs, champs et valeurs par
défaut sont conservés. `textKey` reste appliqué au paragraphe rendu et
`find.byKey(textKey)` reste valide. L'implémentation ne pourra plus garantir que
le widget trouvé est exactement une instance de `Text`; la documentation et
les helpers de test doivent migrer de « resulting Text widget » vers « rendered
text paragraph ». Ce changement d'observation, sans rupture de signature, doit
être annoncé dans la même release que l'architecture.

**Algorithme minimal.**

- Remplacer `LayoutBuilder` par un petit widget render-object inspiré de
  `RichText`, avec un `_RenderAutoSizeParagraph` dérivé de `RenderParagraph` et
  un wrapper privé uniquement chargé de basculer vers `overflowReplacement`.
  Réutiliser le rendu, le hit testing, les semantics et la sélection de
  `RenderParagraph`; ne pas recopier un champ de texte complet ni partir de la
  PR #102.
- `computeDryLayout` et les quatre méthodes intrinsèques appellent le moteur de
  mesure pur. Elles utilisent uniquement les méthodes dry des enfants inline,
  ne modifient ni groupe, ni état, ni cache de layout humide.
- Pour une hauteur donnée, les largeurs intrinsèques choisissent le plus grand
  candidat compatible avec cette hauteur; pour une largeur donnée, les hauteurs
  intrinsèques choisissent le plus grand candidat qui tient. Avec les deux axes
  non bornés, la borne haute est utilisée. À contraintes identiques, dry et wet
  doivent sélectionner le même candidat.
- `performLayout` mesure les candidats, applique le scaler/span final au
  paragraphe, effectue le layout humide des enfants inline et ne publie le
  candidat local au groupe qu'après cette sélection. Une passe sèche ne peut
  donc jamais planifier une microtâche de groupe.
- Extraire les `WidgetSpan` dans l'ordre logique et fournir un adaptateur privé
  limité à leurs parent-data, scale, baseline, layout et paint. Pour chaque
  candidat, calculer les `PlaceholderDimensions` avec le facteur hérité du run,
  les passer à chaque painter, puis utiliser les dimensions humides du candidat
  final pour le rendu. Les passes spéculatives humides peuvent relayout les
  enfants en O(nombre de spans × log candidats); les passes dry restent pures.
- Le wrapper d'overflow consulte le résultat pur : si même le plus petit
  candidat ne tient pas, il mesure/peint/hit-teste uniquement le replacement.
- Les recognizers, semantics, `SelectionArea`, alignements/baselines et le
  scaling automatique des widgets inline suivent le comportement de `RichText`.

**Tests de régression précis.**

- `Chip` et `FilterChip`, `DataTable`, `PaginatedDataTable`, `IntrinsicWidth`,
  `IntrinsicHeight`, plus contrôle négatif `Row` + `Expanded` ;
- absence d'exception, taille bornée et même candidat en dry/wet avec texte
  simple, riche, groupe et `overflowReplacement` ;
- parent de test qui déclenche plusieurs requêtes dry avant le layout humide et
  prouve qu'aucune valeur de groupe ni notification n'a changé ;
- un `WidgetSpan` fixe seul, puis avec texte, sous contraintes de largeur et de
  hauteur ; plusieurs widgets imbriqués, ordre logique, alignements top/middle/
  baseline et baseline réelle ;
- `WidgetSpan` sous scaler linéaire et non linéaire, dans un groupe et dans un
  cas qui affiche le replacement ;
- recognizer, semanticsLabel, sélection sous `SelectionArea`, `textKey`, hit
  testing et paint du child ;
- leak tracking du painter de recherche et du painter possédé par le render
  object après dispose.

**Risques.** Lot de plus forte portée : divergence dry/wet d'un enfant inline,
baseline incorrecte, effet de bord de groupe pendant layout, perte de sélection
ou semantics, dépendance excessive à des détails privés de Flutter, coût des
layouts multiples. Un enfant inline qui ne sait lui-même pas répondre au dry
layout conserve la même limite que dans tout parent intrinsèque Flutter; le
layout humide ordinaire doit néanmoins rester supporté.

**Critères d'acceptation.** Les six reproductions intrinsèques ne lèvent plus
`_RenderLayoutBuilder does not support dry layout`; aucun `LayoutBuilder` ne
reste dans le chemin produit; `WidgetSpan` n'exige aucune donnée manuelle;
dry/intrinsics sont purs; APIs, valeurs par défaut, semantics, interactions,
groupe et replacement sont préservés; complexité de recherche logarithmique.

## Backlog et exclusions explicites

Les éléments suivants ne font pas partie des must-fix de cette release cœur :

- #80 et #81 : ajouter des paramètres publics `textWidthBasis` et
  `textHeightBehavior`. Le comportement ambiant est corrigé au lot 3, mais
  l'extension explicite reste un lot fonctionnalité après release.
- #146, CORE-08 et CORE-10 : démo, Android et animation de démonstration.
- #151 : investigation seulement tant que les valeurs exactes manquent.
- les 28 demandes hors périmètre du triage revu : #36, #38, #40, #43, #45,
  #47, #54, #57, #60, #66, #68, #73, #78, #79, #80, #81, #84, #95, #100,
  #111, #118, #120, #121, #127, #131, #136, #152 et #153.

Sont également exclus pour éviter l'overengineering :

- callback public de taille, thème implicite de groupe, nouvelle stratégie
  d'overflow, équilibrage de lignes, letter-spacing auto ou champ éditable ;
- moteur complet UAX #14 alors que NBSP/NNBSP suffisent au bug confirmé ;
- tri silencieux des presets invalides ;
- API durable `placeholderDimensions` inspirée de la PR #139 ;
- correctifs spéciaux par `Chip`/`DataTable` au lieu de traiter les intrinsics ;
- cherry-pick intégral des PR #102, #139, #148, #149 ou #154 ;
- ajout public anticipé des propriétés #80/#81 dans les lots de parité interne.

## Critères de sortie de la release cœur

Tous les lots 1 à 6 sont **must-fix avant release**. La release est acceptable
quand :

- chaque test ajouté a été vérifié rouge contre la baseline fautive puis vert
  avec son lot ;
- tous les fichiers de test touchés utilisent `group()` et des noms
  « should ... », sans réécriture cosmétique des fichiers non touchés ;
- `dart format`, `flutter analyze` et `flutter test` sont verts sur le minimum
  exact et Flutter 3.47.2, avec les mêmes résultats de layout attendus ;
- les tests historiques non dépendants de l'implémentation interne restent
  verts; les helpers qui inspectaient un `Text` sont migrés vers des métriques
  de paragraphe et `find.byKey` ;
- aucun painter temporaire ne fuit, aucun calcul dry ne notifie un groupe, et
  aucune taille rendue ne sort du domaine individuel ;
- la documentation décrit le plancher, `textScaler`, la compatibilité temporaire
  de `textScaleFactor`, la règle de référence zéro et la portée de `textKey` ;
- les issues ne sont fermées que par les lots explicitement mappés ci-dessus;
  #151, #80, #81 et #146 restent dans leurs catégories revues.

Après chaque lot : format, analyse ciblée, suite widget complète et test du SDK
minimum. Après le lot 6 : matrice minimum + stable courante, leak suite,
intrinsics/WidgetSpan, puis revue séparée du diff architectural avant toute
préparation de release.
