# Revue indépendante de l’audit GitHub amont

Revue effectuée le **1er septembre 2026** sur le rapport au commit
[`54a37cd5f649bca44c106c7385e4e21de07e6c95`](https://github.com/simc/auto_size_text/commit/54a37cd5f649bca44c106c7385e4e21de07e6c95),
dont le code de référence est
[`f22397751271605ac46e8740d9e48ed631a74cb0`](https://github.com/simc/auto_size_text/commit/f22397751271605ac46e8740d9e48ed631a74cb0).
Aucune écriture n’a été faite sur GitHub et aucun correctif produit n’a été
modifié.

## Verdict

**Fiable pour l’inventaire et les causes racines, mais à corriger avant de
l’utiliser comme feuille de route.** La couverture est exacte et les 14 issues
qui constituent de vrais défauts de la bibliothèque sont correctement
identifiées. Trois des 17 éléments « à corriger » ne sont toutefois pas des
bugs de la bibliothèque : [#80](https://github.com/simc/auto_size_text/issues/80)
et [#81](https://github.com/simc/auto_size_text/issues/81) sont des demandes
d’extension d’API, et [#146](https://github.com/simc/auto_size_text/issues/146)
est une dette de la seule application de démonstration.

Le triage corrigé des 84 issues est donc :

- **14 bugs à corriger**, regroupés en 7 causes ;
- **1 maintenance de démo** à faire séparément ;
- **28 fonctionnalités ou demandes hors périmètre**, après déplacement de
  #80 et #81 ;
- les **7 déjà corrigées**, **19 obsolètes/inapplicables** et **15 à
  reproduire** restent inchangées.

Les priorités P0 attribuées à `TextScaler` et aux `TextPainter` sont trop
fortes si P0 signifie « bloqueur/crash sur une composition valide ». Le seul
P0 structurel est le lot intrinsics/dry layout. `TextScaler`, la fuite et les
divergences de mesure sont P1 élevés. Cette correction de priorité ne change
pas l’ordre pratique : les petits lots sûrs doivent être livrés avant la
réécriture P0, qui exige une branche et une revue dédiées.

## Contrôle mécanique de couverture

Un nouvel instantané REST public, reçu le **1er septembre 2026 à 04:06:35
UTC**, retourne encore 95 objets ouverts : **84 issues** et **11 PR**.

| Contrôle | Résultat |
|---|---|
| Lignes de décision d’issue | 84 |
| Numéros d’issue uniques | 84 |
| Issues API absentes du tableau | 0 |
| Lignes en trop dans le tableau | 0 |
| PR ouvertes uniques dans l’API | 11 |
| PR ouvertes absentes du tableau | 0 |
| PR ouvertes en trop | 0 |
| PR fermées citées comme candidates | #149 et #154 uniquement |

Le comptage des décisions du rapport est également cohérent : 17 + 7 + 19 +
15 + 26 = 84. Les liens secondaires vers des commentaires ou vers
`flutter/flutter` ont été exclus du contrôle en ne lisant que le premier lien
de chaque ligne. Il n’y a donc ni omission cachée ni double comptage.

## Revue obligatoire des 17 éléments « à corriger »

| Issue | Verdict indépendant | Priorité corrigée et preuve |
|---|---|---|
| [#150](https://github.com/simc/auto_size_text/issues/150) | Bug confirmé | **P1 élevé.** Le painter principal et celui de `wrapWords: false` ne sont jamais libérés dans le [code courant](https://github.com/simc/auto_size_text/blob/f22397751271605ac46e8740d9e48ed631a74cb0/lib/src/auto_size_text.dart#L370-L410). `TextPainter.dispose` existe précisément pour libérer le paragraphe natif ; il a été ajouté par [`flutter/flutter#110627`](https://github.com/flutter/flutter/pull/110627). #149 prouve la fuite, mais pas la sûreté sur exception. |
| [#147](https://github.com/simc/auto_size_text/issues/147) | Bug confirmé, même famille que #77 | **P0.** `AutoSizeText` retourne toujours un [`LayoutBuilder`](https://github.com/simc/auto_size_text/blob/f22397751271605ac46e8740d9e48ed631a74cb0/lib/src/auto_size_text.dart#L242-L275). L’issue Flutter [#153460](https://github.com/flutter/flutter/issues/153460) est fermée comme défaut du package tiers, pas comme correctif framework ; aucun correctif Flutter ne peut donc être présumé. #148 ne touche pas cette architecture. |
| [#146](https://github.com/simc/auto_size_text/issues/146) | **Reclasser : maintenance de démo** | **P2.** Les références v1 se trouvent dans `demo/android` (`io.flutter.app.FlutterActivity`, `FlutterApplication`, ancien manifeste), pas dans la bibliothèque Dart. La suppression moteur est réelle ([`flutter/engine#52022`](https://github.com/flutter/engine/pull/52022)), mais elle ne casse pas les applications clientes du package. |
| [#145](https://github.com/simc/auto_size_text/issues/145) | Bug confirmé | **P1.** Les assertions et les indices de recherche sont ancrés à zéro dans la [validation/recherche](https://github.com/simc/auto_size_text/blob/f22397751271605ac46e8740d9e48ed631a74cb0/lib/src/auto_size_text.dart#L278-L367). Une reproduction indépendante avec `minFontSize: 16.3` et `stepGranularity: 1` déclenche l’assertion sur Flutter 3.35.3. |
| [#142](https://github.com/simc/auto_size_text/issues/142) | Bug confirmé | **P1.** `RegExp('\\s+')` sépare bien `U+00A0` dans Dart moderne ; la reproduction indépendante donne deux « mots ». Cela contredit le rôle insécable du caractère et sous-estime le segment à mesurer pour `wrapWords: false`. |
| [#140](https://github.com/simc/auto_size_text/issues/140) | Bug de compatibilité/accessibilité confirmé | **P1 élevé, pas P0.** `textScaleFactor` est encore accepté mais officiellement [déprécié pour le scaling non linéaire](https://docs.flutter.dev/release/breaking-changes/deprecate-textscalefactor). Le code convertit tout l’arbre riche en un facteur linéaire unique ; mesure et rendu ne peuvent donc pas préserver un scaler non linéaire. |
| [#129](https://github.com/simc/auto_size_text/issues/129) | Bug confirmé, doublon de cause de #77 | **P0.** La trace `DataTable` appelle `computeMaxIntrinsicWidth` sur `_RenderLayoutBuilder`. Il faut une seule correction architecturale, pas un cas spécial `DataTable`. |
| [#119](https://github.com/simc/auto_size_text/issues/119) | Bug confirmé, doublon fonctionnel de #104 | **P1.** Le commentaire de confirmation et le contournement `boldText: false` pointent vers la même divergence mesure/rendu. |
| [#106](https://github.com/simc/auto_size_text/issues/106) | Bug confirmé, doublon de #61 | **P1.** La trace et le commentaire renvoient à #61 ; une reproduction indépendante confirme l’assertion `dimensions != null`. |
| [#104](https://github.com/simc/auto_size_text/issues/104) | Bug confirmé, cause racine du gras | **P1.** Le painter mesure le style avant que le widget Flutter `Text` ne fusionne `FontWeight.bold` lorsque `MediaQuery.boldTextOf` vaut vrai. Le correctif doit reproduire exactement le style effectif de `Text` pour la mesure et le rendu. |
| [#81](https://github.com/simc/auto_size_text/issues/81) | **Reclasser : fonctionnalité/parité d’API** | **Backlog.** L’issue demande « How to replace `Text.textHeightBehavior`? » ; aucun comportement existant ne régresse. L’ajout reste utile, mais doit mesurer et rendre avec la même valeur. |
| [#80](https://github.com/simc/auto_size_text/issues/80) | **Reclasser : fonctionnalité/parité d’API** | **Backlog.** Le corps utilise explicitement le modèle « feature request » et demande « the exact feature that `Text` has ». Ce n’est pas un bug actuel. |
| [#77](https://github.com/simc/auto_size_text/issues/77) | Bug racine confirmé | **P0.** L’issue décrit correctement le contrat intrinsèque et relie #28, #30 et #37. Elle doit être le ticket racine du lot architecture, complété par le dry layout moderne de #147. |
| [#61](https://github.com/simc/auto_size_text/issues/61) | Bug confirmé | **P1.** `AutoSizeText.rich` accepte un `TextSpan` valide contenant un `WidgetSpan`, puis plante faute de `PlaceholderDimensions`. #139 offre seulement une échappatoire manuelle ; la mesure automatique reste le correctif durable. |
| [#37](https://github.com/simc/auto_size_text/issues/37) | Bug confirmé, doublon de cause de #77 | **P0.** `PaginatedDataTable` déclenche le même appel intrinsèque. Pas de patch spécifique. |
| [#30](https://github.com/simc/auto_size_text/issues/30) | Bug confirmé, doublon de cause de #77 | **P0.** La reproduction minimale utilise explicitement `IntrinsicHeight` et la trace s’arrête sur `_RenderLayoutBuilder.computeMaxIntrinsicHeight`. |
| [#28](https://github.com/simc/auto_size_text/issues/28) | Bug confirmé, doublon de cause de #77 | **P0.** Malgré le titre `Expanded`/`Row`, la trace contient `RenderIntrinsicWidth.performLayout`. Le rapport a raison de ne pas attribuer la cause à `Expanded` seul. |

Deux précisions sont nécessaires dans les correctifs proposés par le rapport :

1. pour #104/#119, « préserver les poids explicitement plus forts » ne décrit
   pas strictement le comportement courant de Flutter : `Text` fusionne
   `FontWeight.bold`. La règle sûre est de construire une fois le **même style
   effectif que `Text`**, puis de l’utiliser des deux côtés ; toute amélioration
   de la règle de poids serait un changement volontaire séparé ;
2. pour #140, le scaler de mesure doit appliquer le ratio d’auto-ajustement à
   chaque taille de base **avant** le scaler ambiant, par exemple selon la
   fonction conceptuelle `ambient.scale(baseSize * ratio)`. Transformer le
   résultat de la taille racine en `TextScaler.linear` reproduit l’erreur de
   #154 sur les arbres riches.

## Lots minimaux finaux

Les lots suivants sont atomiques par cause racine. Leur priorité d’impact ne
doit pas être confondue avec leur ordre de fusion.

1. **Cycle de vie — #150 (P1 élevé).** Deux sites de `TextPainter`, tous les
   chemins protégés par `try/finally`, tests de fuite ciblés. Aucun autre
   changement de mesure.
2. **Scaling moderne — #140 (P1 élevé).** `TextScaler`, scaler ambiant,
   compatibilité temporaire du paramètre déprécié, texte simple/riche/groupe,
   et politique explicite de version Flutter minimale.
3. **Style d’accessibilité — #104/#119 (P1).** Un seul style effectif partagé
   par mesure et rendu, avec police de test déterministe.
4. **Segmentation — #142 (P1).** Opportunités de coupure Unicode pour
   `wrapWords: false`, sans modification de l’API publique.
5. **Grille de candidats — #145 (P1).** Grille ancrée au minimum et gestion
   explicite des bornes/arrondis. La validation des entrées non finies peut
   renforcer #151, mais ne doit pas fermer #151 sans reproduction.
6. **Spans inline — #61/#106 (P1).** Décider explicitement entre une petite API
   manuelle de dimensions et une mesure automatique. Recommandation : empiler
   la solution automatique sur l’infrastructure du lot 7 plutôt que figer
   immédiatement l’échappatoire de #139.
7. **Intrinsics et dry layout — #28/#30/#37/#77/#129/#147 (P0).** Branche
   d’architecture dédiée, `computeDryLayout`, intrinsics et baseline purs,
   aucune mutation de groupe pendant les passes spéculatives, parité dry/wet,
   `overflowReplacement`, texte riche et groupe conservés.
8. **Démo Android — #146 (P2 maintenance).** Régénérer la plateforme de démo
   depuis le template courant ; ne pas copier l’enregistrement manuel de #148.
9. **Parité optionnelle — #80/#81 (backlog fonctionnalité).** Un seul lot API
   après les bugs, avec transmission aux painters et au rendu. Il ne doit pas
   être présenté comme condition de correction du package.

Les lots 1 à 5 peuvent être revus et livrés indépendamment. Le lot 7 est le
plus urgent par impact, mais aussi le plus risqué ; le découper par widget
appelant recréerait six patches d’une même cause et doit être évité.

## PR à reprendre ou à éviter

Les 11 PR ouvertes et les deux PR fermées candidates ont été relues. Leurs
diffs totalisent 6 914 lignes ; les discussions publiques et les commentaires
de revue en ligne pertinents ont aussi été contrôlés.

| PR | Décision indépendante |
|---|---|
| [#148](https://github.com/simc/auto_size_text/pull/148/files) | **Éviter.** Ne touche ni `LayoutBuilder` ni le dry layout, malgré son rattachement à #147. Remplace le scaler ambiant absent par `1.0`/`noScaling`, donc supprime l’accessibilité par défaut. La migration Android conserve un enregistrement manuel inutile. Ne récupérer que des indications de fichiers à régénérer. |
| [#139](https://github.com/simc/auto_size_text/pull/139/files) | **Reprise conditionnelle, pas recommandée comme solution finale.** L’appel à `setPlaceholderDimensions` est le fragment utile. La PR n’a ni documentation, ni validation du nombre, ni tests ; sa valeur par défaut vide laisse le crash intact pour l’usage existant et expose au client un détail de layout difficile à scaler. |
| [#135](https://github.com/simc/auto_size_text/pull/135/files) | **Éviter.** Fonctionnalité `letterSpacing` mélangée à la démo et au scaler. Elle supprime le scaler ambiant comme #148, reprend l’enregistrement Android manuel et retire `dart:typed_data` alors que les utilitaires utilisent encore `ByteData`/`Uint8List`. |
| [#124](https://github.com/simc/auto_size_text/pull/124/files) | **Ne pas reprendre dans un lot technique.** Changement juridique facultatif ; décision du titulaire/mainteneur. |
| [#122](https://github.com/simc/auto_size_text/pull/122/files) | **Récupérer seulement la signature et la documentation si #81 est planifiée.** La propriété n’est transmise qu’au `Text` final, pas aux `TextPainter` : le diff complet introduirait une divergence mesure/rendu. |
| [#116](https://github.com/simc/auto_size_text/pull/116/files) | **Ignorer.** Un espace final, aucun comportement. |
| [#113](https://github.com/simc/auto_size_text/pull/113/files) | **Éviter.** Change automatiquement tout rendu web en `SelectableText`, ignore plusieurs propriétés et est dépassée par `SelectionArea`. |
| [#102](https://github.com/simc/auto_size_text/pull/102/files) | **Éviter tout cherry-pick ; idée d’architecture seulement.** Le nouveau `RenderBox` n’implémente pas `computeDryLayout`, ses méthodes intrinsèques mutent un cache, ses `TextPainter` ne sont pas libérés, le défaut de `wrapWords` passe de vrai à faux, et `AutoSizeGroup` est retiré de l’API. Il copie en plus une ancienne implémentation complète de champ texte. Cette PR ne corrige donc pas #147 et réintroduit #150. |
| [#94](https://github.com/simc/auto_size_text/pull/94/files) | **Éviter.** Très large surface `SelectableText`, problèmes de marge/scroll relevés dans sa discussion, API partielle, désormais remplacée par `SelectionArea`. |
| [#91](https://github.com/simc/auto_size_text/pull/91/files) | **Éviter.** Ancienne variante sélectionnable qui ignore `locale`, `softWrap`, `overflow` et `semanticsLabel`, et ajoute une dépendance Material à une bibliothèque jusque-là fondée sur widgets. |
| [#50](https://github.com/simc/auto_size_text/pull/50/files) | **Éviter.** Nouvelle sémantique `groupScaleFactor`, aucune validation de zéro/négatif et aucun test ; hors des bugs retenus. |
| [#149](https://github.com/simc/auto_size_text/pull/149/files) | **Reprendre les deux emplacements, réécrire l’implémentation.** Les appels `dispose` sont corrects sur le chemin nominal, mais doivent être en `try/finally`. Ne pas reprendre `leak_tracker_flutter_testing: any` ni l’activation globale répétée dans chaque fichier. PR fermée non mergée, tête vérifiée : [`b537868`](https://github.com/simc/auto_size_text/commit/b537868d1cda669f4d05ebf704ba28990290cb8c). |
| [#154](https://github.com/simc/auto_size_text/pull/154/files) | **Éviter.** Supprime immédiatement `textScaleFactor` (rupture source), convertit le résultat non linéaire en scaler linéaire global, mélange `semanticsIdentifier` et casse les utilitaires en retirant `dart:typed_data`. PR fermée non mergée, tête vérifiée : [`6bc0889`](https://github.com/simc/auto_size_text/commit/6bc088971d5c6ba8b488f6c5422186b27e2235e3). |

Conclusion de reprise : **aucune PR entière**. #149 fournit deux emplacements de
nettoyage ; #139 et #122 fournissent au plus une esquisse d’API. #102 ne doit
pas servir de base de branche : ses défauts sont directement incompatibles
avec les critères d’acceptation modernes.

## Risques de rupture à rendre explicites

- Introduire `TextScaler` référence une API Flutter moderne ; le package doit
  déclarer une version Flutter minimale. Appeler `TextPainter.dispose` impose
  aussi un Flutter postérieur à [`#110627`](https://github.com/flutter/flutter/pull/110627),
  contrainte de toute façon absorbée par le lot `TextScaler`.
- Conserver `double? textScaleFactor` déprécié pendant une période de migration
  évite une rupture source. Le supprimer, comme #154, exige une version majeure.
- Le changement de style en mode gras réduira volontairement certaines tailles
  calculées et pourra abaisser tout un `AutoSizeGroup`. C’est la correction
  attendue, à figer par tests.
- Une nouvelle architecture doit conserver les deux constructeurs, `textKey`,
  `overflowReplacement`, le groupe, les presets, les sémantiques et les valeurs
  par défaut. Dry layout et intrinsics ne doivent ni construire de widgets, ni
  notifier le groupe, ni dépendre d’un layout précédent.
- Une API publique `placeholderDimensions` serait additive mais difficile à
  retirer. Elle doit être considérée comme un engagement durable, pas comme un
  détail temporaire de PR.
- Autoriser les minimums fractionnaires étend le domaine valide. Pour les
  anciennes entrées valides, la grille doit rester identique ; les nouvelles
  validations runtime ne doivent changer que le comportement des entrées
  invalides/non finies.
- Régénérer `demo/android` peut augmenter les SDK Android minimaux de la démo,
  mais ne doit modifier aucune contrainte de plateforme du package Dart.

## Vérifications locales, qualité et limites

- `fvm flutter test` sur Flutter 3.35.3 / Dart 3.9.2 : **23/23 tests
  existants réussis** ; cela confirme que les défauts retenus ne sont pas déjà
  couverts par la suite.
- Un test temporaire conforme au harness a confirmé séparément les trois claims
  `U+00A0`, minimum 16,3/pas 1 et `WidgetSpan`. Il a ensuite été supprimé, ainsi
  que `.dart_tool`, `build` et les lockfiles générés.
- Le changed file `maintenance/audits/upstream-issues-audit.md` a été lu en
  entier. Ont aussi été relus intégralement : `lib/auto_size_text.dart`, les
  trois fichiers `lib/src`, `test/utils.dart`, `test/step_granularity_test.dart`,
  `pubspec.yaml` et les fichiers Android de démo directement concernés.
- Les 17 corps d’issue et leurs **54 commentaires** ont été contrôlés. Les 13
  diffs de PR, leurs **43 commentaires de discussion** et les éventuels
  commentaires de revue en ligne des sept PR techniquement candidates ont été
  inspectés ; aucun commentaire de revue en ligne supplémentaire n’existait.
- Flutter 3.47 n’est pas installé localement. L’applicabilité moderne repose sur
  l’API officielle, les sources Flutter 3.35.3 disponibles et les références
  3.47 du rapport. Aucun appareil physique iOS/HarmonyOS et aucune matrice web
  n’ont été exécutés.

Surface de la modification auditée : un document Markdown alimenté par des
données publiques et des liens externes. Il ne contient ni entrée exécutable,
base de données, authentification, autorisation, session, chiffrement, secret,
commande, ni écriture distante. Injection, XSS, CSRF, IDOR, cryptographie,
session et fuite d’information sont donc inapplicables. Aucun risque de course
ou de déni de service n’est introduit par le document. Le seul contrôle de
logique métier applicable est l’exactitude du triage ; ses corrections sont
énumérées ci-dessus. Les zones non vérifiables sont limitées aux reproductions
matérielles et à Flutter 3.47, explicitement signalées.
