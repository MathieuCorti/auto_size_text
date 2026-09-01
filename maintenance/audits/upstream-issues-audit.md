# Audit des issues et pull requests de l’amont

Collecte effectuée le **1er septembre 2026 à 03:58:16 UTC** (10:58:16 UTC+7), sur
[`simc/auto_size_text`](https://github.com/simc/auto_size_text), à partir du dernier commit de maintenance présent dans ce fork :
[`f22397751271605ac46e8740d9e48ed631a74cb0`](https://github.com/simc/auto_size_text/commit/f22397751271605ac46e8740d9e48ed631a74cb0), fusionné par la [PR #133](https://github.com/simc/auto_size_text/pull/133) le 30 juin 2023.

## Résumé exécutif

L’amont n’est pas archivé, mais son dernier push date du 7 décembre 2023. Les **95 objets ouverts** retournés par GitHub se répartissent en **84 issues** et **11 pull requests**. Toutes les issues ouvertes sont listées ci-dessous. La classification donne :

- **17 issues à corriger maintenant**, regroupées en 9 sujets techniques ;
- **7 déjà corrigées** dans le code courant, Flutter ou par une utilisation documentée ;
- **19 obsolètes ou inapplicables** sur Flutter moderne ;
- **15 qui demandent une reproduction ou des informations** ;
- **26 demandes hors périmètre ou nouvelles fonctionnalités**.

Les risques principaux sont l’incompatibilité avec le calcul intrinsèque/dry layout, l’API de mise à l’échelle de texte devenue obsolète, deux `TextPainter` jamais libérés, et plusieurs divergences entre la mesure et le rendu (texte en gras d’accessibilité, espaces insécables, `WidgetSpan`). Les PR [#149](https://github.com/simc/auto_size_text/pull/149) et [#139](https://github.com/simc/auto_size_text/pull/139) fournissent des fragments récupérables ; aucune PR ne doit être reprise intégralement sans adaptation.

## Méthode et couverture

La collecte a utilisé l’API REST publique GitHub, l’authentification locale `gh` étant expirée. Ont été lus : les 95 objets ouverts, les 58 objets fermés retournés par la recherche ciblée (42 issues et 16 PR), les métadonnées des PR, leurs diffs pertinents et 415 commentaires de dépôt. Aucune écriture, fermeture, réaction ou publication n’a été faite sur GitHub.

Le triage a ensuite été mappé au code figé au commit de référence, notamment le [`LayoutBuilder` de construction](https://github.com/simc/auto_size_text/blob/f22397751271605ac46e8740d9e48ed631a74cb0/lib/src/auto_size_text.dart#L242-L275), la [validation et la recherche dichotomique](https://github.com/simc/auto_size_text/blob/f22397751271605ac46e8740d9e48ed631a74cb0/lib/src/auto_size_text.dart#L278-L367), les [`TextPainter` de mesure](https://github.com/simc/auto_size_text/blob/f22397751271605ac46e8740d9e48ed631a74cb0/lib/src/auto_size_text.dart#L370-L410), le [rendu final](https://github.com/simc/auto_size_text/blob/f22397751271605ac46e8740d9e48ed631a74cb0/lib/src/auto_size_text.dart#L413-L445) et la [synchronisation de groupe](https://github.com/simc/auto_size_text/blob/f22397751271605ac46e8740d9e48ed631a74cb0/lib/src/auto_size_group.dart#L4-L51). Les dix fichiers de tests existants et leurs utilitaires ont été lus intégralement.

La cible « Flutter moderne » retenue est la série 3.47.x disponible à la date de collecte : voir les [notes officielles de Flutter 3.47.0](https://docs.flutter.dev/release/release-notes/release-notes-3.47.0) et le [suivi officiel de Flutter 3.47.2](https://github.com/flutter/flutter/issues/191758). Les changements de référence sont la [dépréciation de `textScaleFactor`](https://docs.flutter.dev/release/breaking-changes/deprecate-textscalefactor) et la [migration vers la mise à l’échelle non linéaire Android 14](https://docs.flutter.dev/release/breaking-changes/android-14-nonlinear-text-scaling-migration).

Validation locale, sans conserver les tests temporaires :

- `fvm flutter test` avec Flutter 3.35.3 / Dart 3.9.2 : **23 tests existants réussis** ;
- `fvm flutter analyze` : **27 diagnostics**, dont 12 erreurs concentrées dans la démo obsolète et 15 informations/dépréciations, notamment `textScaleFactor` dans la bibliothèque ;
- reproductions widget temporaires : fuite vérifiée par lecture et PR, choix de taille erroné en mode texte gras, assertion sur `minFontSize: 16.3`, mauvais traitement de `U+00A0`, assertion `WidgetSpan dimensions != null`, et crash `Chip` avec `_RenderLayoutBuilder does not support dry layout` (24 exceptions en cascade) ;
- les tests temporaires, `.dart_tool`, `build` et les fichiers lock générés ont été supprimés après validation.

## Décision pour chaque issue ouverte

« Hors périmètre » signifie qu’il s’agit d’une nouvelle API ou d’un nouveau comportement, pas que la demande est sans valeur. « Besoin d’information » signifie que le code actuel ne permet pas d’établir une cause unique sans reproduction minimale moderne.

| Issue | Décision | Motif synthétique |
|---|---|---|
| [#153](https://github.com/simc/auto_size_text/issues/153) | Hors périmètre / fonctionnalité | Équilibrage typographique des lignes ; ne relève pas de l’ajustement de taille existant. |
| [#152](https://github.com/simc/auto_size_text/issues/152) | Hors périmètre / méta | Demande de reprise de maintenance, sans défaut logiciel isolé. |
| [#151](https://github.com/simc/auto_size_text/issues/151) | Besoin d’information | Le plantage à la ligne 332 implique probablement une valeur non finie ou un `stepGranularity` nul ; il faut les valeurs exactes et une reproduction. |
| [#150](https://github.com/simc/auto_size_text/issues/150) | **À corriger maintenant** | Les deux `TextPainter` créés par chaque essai ne sont jamais libérés. |
| [#147](https://github.com/simc/auto_size_text/issues/147) | **À corriger maintenant** | `LayoutBuilder` ne supporte pas le dry layout demandé par `Chip` sur Flutter récent ; reproduction locale exacte. |
| [#146](https://github.com/simc/auto_size_text/issues/146) | **À corriger maintenant** | La démo contient encore l’embedding Android v1 supprimé ; maintenance d’exemple, sans impact sur la bibliothèque Dart consommée. |
| [#145](https://github.com/simc/auto_size_text/issues/145) | **À corriger maintenant** | La grille est ancrée à zéro et interdit arbitrairement des minimums fractionnaires usuels. |
| [#144](https://github.com/simc/auto_size_text/issues/144) | Besoin d’information | Aucun exemple minimal ni détail de police/contraintes expliquant la différence iOS. |
| [#143](https://github.com/simc/auto_size_text/issues/143) | Obsolète / inapplicable | L’auteur confirme dans [son commentaire](https://github.com/simc/auto_size_text/issues/143#issuecomment-2045769206) s’être trompé de dépôt. |
| [#142](https://github.com/simc/auto_size_text/issues/142) | **À corriger maintenant** | `RegExp('\\s+')` traite l’espace insécable comme une coupure autorisée. |
| [#141](https://github.com/simc/auto_size_text/issues/141) | Besoin d’information | Capture seule ; texte, police, contraintes et configuration manquent. |
| [#140](https://github.com/simc/auto_size_text/issues/140) | **À corriger maintenant** | `textScaleFactor` est déprécié et ne représente pas le scaling non linéaire moderne. |
| [#138](https://github.com/simc/auto_size_text/issues/138) | Besoin d’information | Flash HarmonyOS intermittent sans trace, version ni reproduction. |
| [#136](https://github.com/simc/auto_size_text/issues/136) | Hors périmètre / fonctionnalité | Masquer toute erreur de layout par un widget de secours changerait la sémantique et cacherait des erreurs d’intégration. |
| [#131](https://github.com/simc/auto_size_text/issues/131) | Hors périmètre / fonctionnalité | Nouvelle couche de thème héritée. |
| [#130](https://github.com/simc/auto_size_text/issues/130) | Obsolète / inapplicable | Doublon de #86 lié à l’ancien renderer HTML. |
| [#129](https://github.com/simc/auto_size_text/issues/129) | **À corriger maintenant** | `DataTable` sollicite des dimensions intrinsèques incompatibles avec le `LayoutBuilder`. |
| [#128](https://github.com/simc/auto_size_text/issues/128) | Besoin d’information | Le titre, le corps et la plateforme décrite divergent ; aucune reproduction exploitable. |
| [#127](https://github.com/simc/auto_size_text/issues/127) | Hors périmètre / fonctionnalité | Exposer la taille calculée est une nouvelle API/callback. |
| [#126](https://github.com/simc/auto_size_text/issues/126) | Déjà corrigée | L’auteur du diagnostic confirme le correctif moteur dans Flutter 3.7 dans [ce commentaire](https://github.com/simc/auto_size_text/issues/126#issuecomment-1405189145). |
| [#125](https://github.com/simc/auto_size_text/issues/125) | Obsolète / inapplicable | Flutter Driver et la recherche directe du wrapper sont obsolètes ; cibler `textKey`/le `Text` interne dans un test d’intégration moderne. |
| [#123](https://github.com/simc/auto_size_text/issues/123) | Besoin d’information | Le cycle de vie et les contraintes avant/après `setState` ne sont pas fournis. |
| [#121](https://github.com/simc/auto_size_text/issues/121) | Hors périmètre / fonctionnalité | Groupe hérité implicite ; `AutoSizeGroupBuilder` couvre déjà le partage explicite. |
| [#120](https://github.com/simc/auto_size_text/issues/120) | Hors périmètre / fonctionnalité | Nouvelle politique de troncature des derniers mots. |
| [#119](https://github.com/simc/auto_size_text/issues/119) | **À corriger maintenant** | Même divergence de mesure du texte gras d’accessibilité que #104. |
| [#118](https://github.com/simc/auto_size_text/issues/118) | Hors périmètre / fonctionnalité | Indentation et listes à puces relèvent de la composition du contenu. |
| [#115](https://github.com/simc/auto_size_text/issues/115) | Obsolète / inapplicable | Comportement Unicode de coupure de ligne ; aucun défaut de taille isolé ni reproduction moderne. |
| [#114](https://github.com/simc/auto_size_text/issues/114) | Besoin d’information | Rapport générique, sans code minimal ni résultat attendu. |
| [#112](https://github.com/simc/auto_size_text/issues/112) | Obsolète / inapplicable | Un `ListView` peut fournir une contrainte non bornée ; le widget documente l’exigence de contraintes finies. |
| [#111](https://github.com/simc/auto_size_text/issues/111) | Hors périmètre / fonctionnalité | Mise à l’échelle horizontale indépendante, nouvelle transformation. |
| [#109](https://github.com/simc/auto_size_text/issues/109) | Obsolète / inapplicable | Le widget ne grossit pas au-delà de la taille de style initiale ; définir une taille initiale/maximale supérieure. |
| [#107](https://github.com/simc/auto_size_text/issues/107) | Déjà corrigée | `SelectionArea`, disponible depuis Flutter 3.3, rend le texte enfant sélectionnable sans modifier ce widget. |
| [#106](https://github.com/simc/auto_size_text/issues/106) | **À corriger maintenant** | `WidgetSpan` exige des dimensions de placeholder avant le layout du `TextPainter`. |
| [#105](https://github.com/simc/auto_size_text/issues/105) | Déjà corrigée | `wrapWords: false` résout le cas et l’auteur conclut [« Case closed »](https://github.com/simc/auto_size_text/issues/105#issuecomment-1079354493). |
| [#104](https://github.com/simc/auto_size_text/issues/104) | **À corriger maintenant** | Le rendu `Text` applique le gras de `MediaQuery`, mais la mesure ne l’intègre pas. |
| [#103](https://github.com/simc/auto_size_text/issues/103) | Obsolète / inapplicable | Durée de vie du groupe avec les pages paresseuses ; créer/conserver le groupe au-dessus du `PageView`. |
| [#100](https://github.com/simc/auto_size_text/issues/100) | Hors périmètre / fonctionnalité | Changer la valeur par défaut de `wrapWords` serait une rupture de comportement. |
| [#97](https://github.com/simc/auto_size_text/issues/97) | Besoin d’information | « justify-center » n’identifie ni propriété Flutter ni résultat attendu précis. |
| [#95](https://github.com/simc/auto_size_text/issues/95) | Hors périmètre / fonctionnalité | Nouvelle personnalisation de stratégie d’overflow. |
| [#92](https://github.com/simc/auto_size_text/issues/92) | Besoin d’information | Cas d’un caractère sans police/contraintes ; reproduction moderne requise. |
| [#87](https://github.com/simc/auto_size_text/issues/87) | Déjà corrigée | `AutoSizeGroupBuilder` est déjà présent, fusionné par la [PR #88](https://github.com/simc/auto_size_text/pull/88). |
| [#86](https://github.com/simc/auto_size_text/issues/86) | Obsolète / inapplicable | Défaut de l’ancien renderer HTML, relié à [`flutter/flutter#65940`](https://github.com/flutter/flutter/issues/65940), aujourd’hui fermé. |
| [#84](https://github.com/simc/auto_size_text/issues/84) | Hors périmètre / fonctionnalité | Nouvelle API `textBuilder`. |
| [#82](https://github.com/simc/auto_size_text/issues/82) | Besoin d’information | Issue vide, sans question ou reproduction. |
| [#81](https://github.com/simc/auto_size_text/issues/81) | **À corriger maintenant** | Parité manquante avec `Text.textHeightBehavior`; doit affecter mesure et rendu. |
| [#80](https://github.com/simc/auto_size_text/issues/80) | **À corriger maintenant** | Parité manquante avec `Text.textWidthBasis`; doit affecter mesure et rendu. |
| [#79](https://github.com/simc/auto_size_text/issues/79) | Hors périmètre / fonctionnalité | Fond personnalisable, composable avec `DecoratedBox`/`Container`. |
| [#78](https://github.com/simc/auto_size_text/issues/78) | Hors périmètre / fonctionnalité | Intégration à un widget tiers de neumorphisme. |
| [#77](https://github.com/simc/auto_size_text/issues/77) | **À corriger maintenant** | Demande racine de support des dimensions intrinsèques ; toujours valide. |
| [#74](https://github.com/simc/auto_size_text/issues/74) | Obsolète / inapplicable | Un titre d’`AppBar` monoligne doit déclarer `maxLines: 1`. |
| [#73](https://github.com/simc/auto_size_text/issues/73) | Hors périmètre / fonctionnalité | Ajustement dynamique de `letterSpacing`, distinct de la taille. |
| [#71](https://github.com/simc/auto_size_text/issues/71) | Obsolète / inapplicable | Colonne/hauteur non bornée et absence de `maxLines`, donc pas de contrainte déclenchant une réduction. |
| [#70](https://github.com/simc/auto_size_text/issues/70) | Déjà corrigée | Bibliothèque Flutter pure Dart : le support Windows suit celui du framework, sans code plateforme ici. |
| [#68](https://github.com/simc/auto_size_text/issues/68) | Hors périmètre / fonctionnalité | Contour de glyphes, effet de rendu supplémentaire. |
| [#67](https://github.com/simc/auto_size_text/issues/67) | Obsolète / inapplicable | Ancien moteur/renderer web ; aucun cas actuel distinct. |
| [#66](https://github.com/simc/auto_size_text/issues/66) | Hors périmètre / fonctionnalité | Grossissement automatique au-delà du style initial ; contournement documenté par une taille initiale élevée. |
| [#65](https://github.com/simc/auto_size_text/issues/65) | Besoin d’information | Peut relever du scaling, du gras, de la hauteur de ligne ou des contraintes ; reproduction nécessaire. |
| [#64](https://github.com/simc/auto_size_text/issues/64) | Obsolète / inapplicable | Le minimum par défaut est 12 ; le diminuer est requis si la chaîne ne tient pas. |
| [#63](https://github.com/simc/auto_size_text/issues/63) | Obsolète / inapplicable | Rapport ancien lié au web sans reproduction sur le moteur actuel. |
| [#62](https://github.com/simc/auto_size_text/issues/62) | Obsolète / inapplicable | Différences d’implémentation de justification des anciens renderers web. |
| [#61](https://github.com/simc/auto_size_text/issues/61) | **À corriger maintenant** | Même assertion `WidgetSpan` que #106. |
| [#60](https://github.com/simc/auto_size_text/issues/60) | Hors périmètre / fonctionnalité | API publique de taille maximale calculée ; le groupement couvre seulement le partage interne. |
| [#59](https://github.com/simc/auto_size_text/issues/59) | Obsolète / inapplicable | Une contrainte `maxHeight` est déjà apportée par le parent via `BoxConstraints`. |
| [#58](https://github.com/simc/auto_size_text/issues/58) | Besoin d’information | Erreur historique de résolution de package, sans `pubspec`, SDK ou journal complet. |
| [#57](https://github.com/simc/auto_size_text/issues/57) | Hors périmètre / fonctionnalité | Choix sémantique : réduire tout le contenu ou tronquer au nombre de lignes. |
| [#55](https://github.com/simc/auto_size_text/issues/55) | Besoin d’information | Ombre absente sur une ancienne version Flutter, sans reproduction ni capture exploitable. |
| [#54](https://github.com/simc/auto_size_text/issues/54) | Hors périmètre / fonctionnalité | Segmentation spéciale des chemins/mots longs, responsabilité du contenu ou d’une nouvelle politique de coupure. |
| [#53](https://github.com/simc/auto_size_text/issues/53) | Obsolète / inapplicable | `maxFontSize` est une taille logique avant mise à l’échelle d’accessibilité ; le scaling utilisateur s’applique ensuite. |
| [#52](https://github.com/simc/auto_size_text/issues/52) | Obsolète / inapplicable | Stack interne d’un ancien `DropdownButton`, sans reproduction moderne. |
| [#51](https://github.com/simc/auto_size_text/issues/51) | Obsolète / inapplicable | Usage de `Row`/`Column` sans contraintes ; employer `Expanded`/`Flexible` de façon bornée. |
| [#49](https://github.com/simc/auto_size_text/issues/49) | Déjà corrigée | `SelectionArea` du framework fournit la sélection externe. |
| [#48](https://github.com/simc/auto_size_text/issues/48) | Besoin d’information | Ancien cas hébreu sans texte, police et reproduction sur le moteur actuel. |
| [#47](https://github.com/simc/auto_size_text/issues/47) | Hors périmètre / fonctionnalité | Facteur de groupe individuel, nouvelle sémantique de synchronisation. |
| [#46](https://github.com/simc/auto_size_text/issues/46) | Besoin d’information | Un feedback layout/groupe est plausible, mais un cas moderne stable est requis. |
| [#45](https://github.com/simc/auto_size_text/issues/45) | Hors périmètre / fonctionnalité | Stratégies supplémentaires de `TextOverflow`, relevant du framework/API. |
| [#43](https://github.com/simc/auto_size_text/issues/43) | Hors périmètre / fonctionnalité | Exposer publiquement le calcul interne/dry-run est une nouvelle API. |
| [#42](https://github.com/simc/auto_size_text/issues/42) | Déjà corrigée | L’auteur indique que `flutter clean` a résolu le problème de dépendance. |
| [#40](https://github.com/simc/auto_size_text/issues/40) | Hors périmètre / fonctionnalité | Callback de taille calculée, même famille que #127. |
| [#38](https://github.com/simc/auto_size_text/issues/38) | Hors périmètre / fonctionnalité | Champ éditable autosize, widget/package séparé et surface API majeure. |
| [#37](https://github.com/simc/auto_size_text/issues/37) | **À corriger maintenant** | `PaginatedDataTable` demande des intrinsics que `LayoutBuilder` ne sait pas fournir. |
| [#36](https://github.com/simc/auto_size_text/issues/36) | Hors périmètre / fonctionnalité | Bascule de comportement vers `Text`, composable par le code appelant. |
| [#30](https://github.com/simc/auto_size_text/issues/30) | **À corriger maintenant** | `IntrinsicHeight` déclenche la même limite architecturale. |
| [#28](https://github.com/simc/auto_size_text/issues/28) | **À corriger maintenant** | La trace contient `IntrinsicWidth`; un `Expanded` correctement borné seul est déjà supporté. |
| [#26](https://github.com/simc/auto_size_text/issues/26) | Obsolète / inapplicable | Flutter Web est supporté ; les défauts de ses anciens renderers sont traités séparément. |

## Correctifs retenus

### P0 — Calcul intrinsèque et dry layout : #147, #129, #77, #37, #30, #28

**Cause probable.** `AutoSizeText` retourne directement un `LayoutBuilder`. Les parents tels que `Chip`, `DataTable`, `PaginatedDataTable`, `IntrinsicWidth` et `IntrinsicHeight` demandent un dry layout ou une dimension intrinsèque ; `_RenderLayoutBuilder` refuse cette opération. Flutter suit ce problème côté framework pour `Chip` dans [`flutter/flutter#153460`](https://github.com/flutter/flutter/issues/153460), mais le composant reste structurellement incapable de répondre aux intrinsics.

**Portée minimale sûre.** Ce n’est pas un patch ponctuel de `Chip` : remplacer la dépendance au `LayoutBuilder` par un `RenderObjectWidget`/`RenderBox` possédant la logique de mesure, implémentant `computeDryLayout` et les méthodes intrinsèques sans muter le groupe pendant une passe sèche. Préserver les constructeurs public/rich, `overflowReplacement`, la clé du texte et la synchronisation de groupe. La [PR #102](https://github.com/simc/auto_size_text/pull/102) montre une direction `RenderObject`, mais ses 2 768 ajouts, suppressions d’API et usages Flutter anciens en font une référence d’architecture seulement, pas un commit à reprendre.

**Régressions à écrire.** Tests widget nommés `should ...` pour `Chip`/`FilterChip`, `DataTable`, `PaginatedDataTable`, `IntrinsicWidth`, `IntrinsicHeight` et `Row`+`Expanded`; vérifier absence d’exception, taille bornée et résultat identique entre dry et layout réel. Ajouter groupe et `overflowReplacement` pour interdire des effets de bord pendant le dry layout.

### P0 — `TextScaler` et scaling non linéaire : #140

**Cause probable.** La mesure lit un `double` via `MediaQuery.textScaleFactorOf`, le transmet à `TextPainter.textScaleFactor`, puis neutralise le scaling sur le `Text` final. Cette représentation est dépréciée et ne peut pas préserver une courbe non linéaire, surtout dans un arbre `TextSpan` dont les tailles de base diffèrent.

**Portée minimale sûre.** Ajouter `TextScaler? textScaler`, conserver temporairement `double? textScaleFactor` déprécié avec assertion d’exclusivité, prendre `MediaQuery.textScalerOf(context)` par défaut, puis composer le ratio d’auto-ajustement avec le scaler au lieu de l’écraser. Le même scaler effectif doit mesurer et rendre le texte simple, riche et groupé. Mettre à jour les contraintes SDK/lints dans le lot de compatibilité.

La [PR #148](https://github.com/simc/auto_size_text/pull/148) ([commit tête](https://github.com/simc/auto_size_text/commit/4476c9dd1ab1f0ccb0aa51da26617bbb08f7e2a4)) remplace plusieurs API, mais son fallback `TextScaler.noScaling` supprime l’accessibilité ambiante et elle ne corrige pas le dry layout. La [PR #154](https://github.com/simc/auto_size_text/pull/154) ([commit tête](https://github.com/simc/auto_size_text/commit/6bc088971d5c6ba8b488f6c5422186b27e2235e3)) est une référence plus récente, mais linéarise le résultat après scaling, mélange une fonctionnalité de sémantique et casse ses utilitaires de test en retirant `dart:typed_data`. Ne reprendre aucune des deux intégralement.

**Régressions à écrire.** Scaler non linéaire personnalisé donnant des facteurs différents à plusieurs tailles de base ; variantes simple/rich, scaling ambiant/explicite/neutralisé, groupe, maximum/minimum et compatibilité de l’ancien paramètre.

### P0 — Durée de vie des `TextPainter` : #150

**Cause probable.** `_checkTextFits` alloue le painter principal et, avec `wrapWords: false`, un second painter, sans jamais appeler `dispose`; la recherche dichotomique répète ces allocations.

**Portée minimale sûre.** Encadrer chaque painter dans `try/finally` et le libérer, y compris sur le retour anticipé du contrôle de mot. La [PR #149](https://github.com/simc/auto_size_text/pull/149) ([commit tête](https://github.com/simc/auto_size_text/commit/b537868d1cda669f4d05ebf704ba28990290cb8c)) contient les deux appels utiles. Ne pas reprendre sa configuration de tests telle quelle : elle ajoute `leak_tracker_flutter_testing: any` et répète l’activation globale dans chaque test ; centraliser la configuration et borner la dépendance.

**Régressions à écrire.** Leak tracking sur texte simple et `wrapWords: false`, cas qui tient et retour anticipé, plusieurs rebuilds et groupe ; le test doit échouer si l’un des deux painters reste vivant.

### P1 — Grille fractionnaire : #145

**Cause probable.** Les assertions exigent `minFontSize / stepGranularity` et `maxFontSize / stepGranularity` entiers et la recherche utilise `mid * stepGranularity`. La grille est donc ancrée à zéro, bien que seul l’écart entre tailles doive suivre le pas. La reproduction `minFontSize: 16.3, stepGranularity: 1` échoue à l’assertion.

**Portée minimale sûre.** Ancrer les candidats à `minFontSize` (`min + i * step`), inclure exactement les bornes et la taille initiale, gérer les arrondis flottants, puis valider en runtime les valeurs finies, l’ordre des bornes et un pas strictement positif. Cette dernière validation renforcera aussi #151 sans le déclarer corrigé avant reproduction.

**Régressions à écrire.** Minimum 16,3/pas 1, minimum et maximum fractionnaires, plage non multiple du pas, borne exacte, presets, valeurs NaN/infinies/nulles en mode release.

### P1 — Espaces insécables : #142

**Cause probable.** Pour `wrapWords: false`, `toPlainText().split(RegExp('\\s+'))` transforme `U+00A0` en séparateur, sous-estimant le plus long segment non sécable. La reproduction `FAVOURITE\u00A0ENERGY CONTROL` choisit localement la même taille avec `wrapWords` vrai ou faux alors que le segment insécable devrait imposer une réduction.

**Portée minimale sûre.** Employer une segmentation conforme aux opportunités de coupure Unicode ; à défaut, exclure explicitement `U+00A0` et `U+202F` des séparateurs. Éviter `toPlainText` si cela détruit l’information de style des spans.

**Régressions à écrire.** Espace normal, espace insécable, espace fine insécable, chaînes mixtes et `TextSpan` riche ; vérifier la taille choisie et l’absence de coupure interdite.

### P1 — Texte gras d’accessibilité : #104, #119

**Cause probable.** Le `Text` final fusionne le gras demandé par `MediaQuery.boldTextOf`, tandis que les `TextPainter` mesurent le style non renforcé. La reproduction choisit 16,0 dans les deux modes, puis le rendu gras dépasse.

**Portée minimale sûre.** Calculer une seule fois le style effectif incluant le gras d’accessibilité, puis employer exactement ce style pour les painters et le rendu. Préserver les poids explicitement plus forts et le comportement de `DefaultTextStyle`.

**Régressions à écrire.** La taille choisie en gras doit être inférieure au cas régulier lorsque nécessaire ; vérifier aucune exception/overflow de `RenderParagraph`, avec texte simple, riche et police de test chargée.

### P1 — `WidgetSpan` : #61, #106

**Cause probable.** Un `TextPainter` contenant un `WidgetSpan` exige `PlaceholderDimensions`; le code n’en fournit pas, d’où l’assertion locale `dimensions != null`.

**Portée minimale sûre.** La [PR #139](https://github.com/simc/auto_size_text/pull/139) ([commit tête](https://github.com/simc/auto_size_text/commit/ae3b9df6d618166f94d5c131ffc468d73285c6a8)) propose un paramètre `placeholderDimensions` et appelle le setter : c’est un escape hatch récupérable. Il faut documenter et valider le nombre de placeholders, le transmettre à tous les painters et le tester. La solution durable est de mesurer automatiquement les enfants inline dans le futur `RenderObject`, ce qui évite d’imposer des dimensions au client.

**Régressions à écrire.** Un et plusieurs widgets imbriqués, alignements et baselines, scaling, dimension manquante/en trop, rich text groupé et leak tracking.

### P2 — Parité `TextHeightBehavior` et `TextWidthBasis` : #81, #80

**Cause probable.** Ces propriétés de `Text` ne sont pas exposées et ne participent donc ni à la mesure ni au rendu.

**Portée minimale sûre.** Ajouter les deux paramètres et les transmettre à chaque `TextPainter` ainsi qu’à `Text`/`Text.rich`, avec les mêmes valeurs effectives. La [PR #122](https://github.com/simc/auto_size_text/pull/122) ([commit tête](https://github.com/simc/auto_size_text/commit/3ac19abec4e2bc6724b41e2d2d6f89a5ef187780)) ne modifie que le rendu final : son API est récupérable, mais ce diff seul créerait une divergence mesure/rendu.

**Régressions à écrire.** Comportement de hauteur sur la première/dernière ascent/descent, `TextWidthBasis.parent` et `.longestLine`, texte simple et riche, contraintes étroites.

### P2 — Démo Android : #146

**Cause probable.** Le scaffold Java de la démo référence encore l’embedding v1 retiré du moteur Flutter (voir la [suppression côté engine](https://github.com/flutter/engine/pull/52022)). La bibliothèque est pure Dart et n’intègre aucun embedding dans les applications clientes.

**Portée minimale sûre.** Régénérer ou supprimer les scaffolds plateforme de démo obsolètes avec le template Flutter courant, plutôt que copier la registration manuelle de plugins de #148. Vérifier `flutter analyze` et au moins un build Android debug de la démo.

## Pull requests récupérables ou à écarter

| PR | État au 2026-09-01 | Décision |
|---|---|---|
| [#148](https://github.com/simc/auto_size_text/pull/148) | Ouverte | Référence API/démo seulement ; fallback d’accessibilité incorrect, dry layout non corrigé, scaffold à ne pas copier en bloc. |
| [#139](https://github.com/simc/auto_size_text/pull/139) | Ouverte | **Récupérer partiellement** l’escape hatch `placeholderDimensions`, avec validation, documentation et tests supplémentaires. |
| [#135](https://github.com/simc/auto_size_text/pull/135) | Ouverte | Nouvelle fonctionnalité `letterSpacing` et modernisation de démo mêlée ; hors lot correctif. |
| [#124](https://github.com/simc/auto_size_text/pull/124) | Ouverte | Mise à jour d’année de licence, maintenance juridique optionnelle, sans lien avec une issue retenue. |
| [#122](https://github.com/simc/auto_size_text/pull/122) | Ouverte | **Récupérer l’API seulement** ; ajouter impérativement la propriété aux painters. |
| [#116](https://github.com/simc/auto_size_text/pull/116) | Ouverte | Diff de whitespace sans correctif fonctionnel. |
| [#113](https://github.com/simc/auto_size_text/pull/113) | Ouverte | Sélection web obsolète face à `SelectionArea`. |
| [#102](https://github.com/simc/auto_size_text/pull/102) | Ouverte | Référence d’architecture `RenderObject` seulement ; trop vaste, APIs anciennes, suppressions/régressions de surface publique. |
| [#94](https://github.com/simc/auto_size_text/pull/94) | Ouverte | Ancienne implémentation de sélection, obsolète. |
| [#91](https://github.com/simc/auto_size_text/pull/91) | Ouverte | Ancienne implémentation de sélection, obsolète. |
| [#50](https://github.com/simc/auto_size_text/pull/50) | Ouverte | Facteur individuel de groupe, fonctionnalité hors périmètre. |
| [#149](https://github.com/simc/auto_size_text/pull/149) | Fermée non mergée | **Récupérer les deux `dispose`**, refaire proprement la configuration leak tracker. |
| [#154](https://github.com/simc/auto_size_text/pull/154) | Fermée non mergée | Référence `TextScaler` seulement ; ne pas cherry-pick pour les défauts de scaling riche, de tests et le mélange de portée. |

Depuis la maintenance de juin 2023, les autres issues fermées pertinentes sont [#137](https://github.com/simc/auto_size_text/issues/137) (méta-maintenance, aucune modification), [#134](https://github.com/simc/auto_size_text/issues/134) (doublon fonctionnel de #73, fermé comme non planifié) et [#69](https://github.com/simc/auto_size_text/issues/69) (ancien cas `DropDownMenuItem`, fermé en 2024 sans correctif ou reproduction moderne identifiable). Elles ne justifient aucun port. L’issue [#132](https://github.com/simc/auto_size_text/issues/132) est le ticket du commit de référence lui-même.

## Priorité et lots suggérés

1. **Compatibilité et hygiène à faible/moyen risque** : #140, #150, #81, #80, puis #146. Cela restaure une base compilable/testable moderne et élimine la fuite avant les changements structurels.
2. **Exactitude de mesure** : #104/#119, #142 et #145. Petits diffs indépendants, chacun protégé par une reproduction ciblée.
3. **Spans inline** : #61/#106, d’abord avec l’escape hatch #139 si une livraison rapide est nécessaire, puis mesure automatique dans l’architecture suivante.
4. **Branche d’architecture dédiée, priorité d’impact P0** : #147/#129/#77/#37/#30/#28. Son risque de régression et sa taille imposent une revue séparée malgré l’urgence des crashes.

Avant chaque lot, moderniser le harness de tests sans changer simultanément le comportement public. Après chaque lot : `dart format`, `flutter analyze`, suite widget complète, tests de leak si applicables, puis matrice au minimum Flutter stable courant et une version minimale explicitement supportée.

## Surface d’attaque, qualité et limites

Surface revue : texte et propriétés publiques des widgets, `BoxConstraints`, `MediaQuery`, état partagé `AutoSizeGroup`, allocations de `TextPainter` et microtâche de notification. Le package n’a ni réseau, stockage, base de données, authentification, session, chiffrement, désérialisation distante ou commande système ; injection, XSS, CSRF, autorisation, secrets et cryptographie sont donc inapplicables. Le risque de disponibilité local confirmé est la fuite #150. La boucle de recherche reste bornée pour des paramètres valides, mais #151 signale qu’une entrée non finie peut atteindre une conversion entière en release. La microtâche de groupe vérifie `mounted`; aucun défaut de concurrence confirmé, #46 restant à reproduire.

Fichiers relus intégralement : `lib/auto_size_text.dart`, les trois fichiers `lib/src`, `test/basic_test.dart`, `test/group_builder_test.dart`, `test/group_test.dart`, `test/maxlines_test.dart`, `test/min_max_font_size_test.dart`, `test/overflow_replacement_test.dart`, `test/preset_font_sizes_test.dart`, `test/step_granularity_test.dart`, `test/text_fits_test.dart`, `test/utils.dart` et `test/wrap_words_test.dart`.

Limites : aucune installation Flutter 3.47 n’était disponible localement ; les reproductions ont été exécutées sur Flutter 3.35.3 et le mapping 3.47 repose sur les sources officielles. Aucun appareil physique iOS/HarmonyOS ni matrice web n’a été exécuté. Les rapports sans code et les captures historiques ne sont pas reproductibles automatiquement. L’API GitHub publique a remplacé `gh` à cause du jeton expiré, sans réduire la visibilité des objets publics ni produire de mutation distante.
