# Revue architecturale ciblée — lot 9 intrinsics

Date : 2026-09-02

Base S7 auditée : `cc5da0eafcfd17130978041fa1bcc638dfa10d20`

Tête auditée : `33c8bab146f6f29878101b111ccc617b5e96d685`

## Verdict

**ACCEPTÉ.** Aucun finding fonctionnel ou safety P0, P1 ou P2 n'est ouvert.

Le P2 lifecycle identifié après la première passe est fermé par le correctif
`43bb690`. Une exception issue du scaler utilisateur ne franchit plus les six
frontières non-wet et ne peut donc plus laisser les gardes internes de Flutter
armés. La capture reste typée et confinée au scaler ; les erreurs de paragraphe,
assertions et erreurs Flutter hors scaler ne sont pas converties en fallback.

La frontière `LayoutBuilder` a disparu du chemin texte. Le nouveau parent
render sélectionne depuis un snapshot, échange son unique child uniquement
pendant le wet layout, puis délègue le rendu réel à `RenderParagraph`. Les six
requêtes non-wet sont pures et ne consultent ni le child actif ni la
replacement. La divergence de taille admise lorsque la replacement est active
reste exactement le fallback texte au candidat minimum prévu par le contrat
lean ; elle n'est pas un finding.

Le lot peut être intégré comme `S8`. Ce verdict ne porte pas sur le support
automatique de `WidgetSpan`, qui reste gardé et appartient au lot 10.

## Périmètre et provenance

La chaîne relue est linéaire :

```text
cc5da0e  S7, décision lean revue
└─ 1d0225f  reproductions rouges
   └─ dbed398  implémentation et tests verts
      └─ 033a938  journal documentaire
         └─ ea43d98  première revue architecturale
            └─ df29507  reproduction rouge du garde dry empoisonné
               └─ 43bb690  correctif scaler borné
                  └─ 33c8bab  journal du correctif
```

Le diff `cc5da0e..033a938` contient 17 fichiers, 1 676 ajouts et 314
suppressions. Chaque fichier a été lu intégralement :

- `lib/auto_size_text.dart` ;
- `lib/src/auto_size_text.dart` ;
- `lib/src/auto_size_text_layout.dart` ;
- `lib/src/auto_size_text_render_object.dart` ;
- `maintenance/implementation/lot-9-intrinsics.md` ;
- `test/basic_test.dart` ;
- `test/effective_text_configuration_test.dart` ;
- `test/group_builder_test.dart` ;
- `test/group_constraints_test.dart` ;
- `test/group_minimum_maintenance_test.dart` ;
- `test/group_test.dart` ;
- `test/intrinsics_test.dart` ;
- `test/preset_font_sizes_test.dart` ;
- `test/render_object_test.dart` ;
- `test/rich_text_test.dart` ;
- `test/text_painter_lifecycle_test.dart` ;
- `test/utils.dart`.

Ont aussi été lus intégralement ou, pour les sources SDK, sur toute la portion
pertinente : la décision du prototype lean, ses deux revues, la feuille de
route, le journal du lot, `RenderParagraph`, `RenderObject.invokeLayoutCallback`
et l'élément de `LayoutBuilder` dans Flutter 3.41.0 et 3.47.2.

Le worktree était propre avant ce rapport. `git diff --check` est propre et les
locks suivis sont inchangés.

## Revue de l'architecture

### Frontière render et API

`lib/**` ne contient plus aucun `LayoutBuilder` et n'importe aucun
`package:flutter/src`. Le seul ajout à la bibliothèque publique est l'import
public `package:flutter/rendering.dart` nécessaire aux types render internes et
la déclaration d'un nouveau `part` privé. Aucun symbole public, paramètre ou
type de retour du package n'est ajouté.

Le changement observable de `textKey` est celui prévu par la roadmap : la clé
est portée par un petit widget privé dont l'élément résout le vrai
`RenderParagraph`. Elle ne promet plus un widget `Text`. Le paragraphe disparaît
bien lorsque la replacement est active.

### Callback wet et cycle de vie de l'élément

`_AutoSizeTextRenderElement` possède un seul child et ne l'échange que depuis
le callback appelé par `_RenderAutoSizeText.performLayout`. Les deux appels à
`invokeLayoutCallback` sont effectués depuis la sous-classe render, pendant son
wet layout, conformément au contrat `@protected` identique sur les deux pins.
`owner.buildScope` et `updateChild` suivent le protocole public employé par
`LayoutBuilder`, sans appeler cette construction depuis dry ou intrinsic.

La branche inactive n'est pas montée. Les flips texte/replacement créent et
disposent l'état de la replacement une fois par activation ; une replacement
contenant elle-même un `LayoutBuilder` et un descendant wet-only est layoutée
normalement.

### Sélection, métriques et contraintes

Wet, dry et intrinsics appellent le même `_AutoSizeTextLayoutSnapshot.select`.
Le noyau candidat des lots 2 à 5 est réutilisé : aucune seconde grille ni
recherche de fit n'est introduite. La sélection locale est calculée avant la
projection de groupe, et `localFits` seul choisit la replacement.

Les méthodes respectent le contrat du lot :

- les largeurs synthétisent une largeur non bornée et `maxHeight == height`,
  puis retournent les backends min/max distincts du painter choisi ;
- les hauteurs synthétisent `maxWidth == width` et une hauteur non bornée,
  puis reproduisent le layout intrinsèque de `RenderParagraph`, y compris
  `softWrap`, ellipsis et `maxLines` ;
- `computeDryLayout` applique les minima et maxima avec
  `BoxConstraints.constrain` ; les axes infinis ne sont pas convertis en tight ;
- `computeDryBaseline` reprend la baseline alphabétique du même candidat, comme
  `RenderParagraph` pour les deux valeurs publiques de `TextBaseline` sur les
  deux pins.

Les comparaisons directes au témoin couvrent minima non nuls, contraintes
tight/loose, axes infinis, texte simple et riche, presets, scaler, `maxLines`
et le fallback minimum. Les résultats répétés restent finis et stables.

### Pureté, groupe et replacement

Le snapshot contient la limite de groupe par valeur. Les chemins non-wet ne
lisent pas le contrôleur, ne publient rien, ne construisent pas de widget et ne
dépendent pas du child courant. Wet publie la taille locale effective seulement
après le layout final. Un probe de revue supplémentaire a demandé un dry très
étroit après un wet large : aucune microtâche ni frame n'a été planifiée sur le
code livré ; le mutant qui publie depuis `computeDryLayout` échoue sur les deux
pins.

Quand aucun candidat ne tient, `findLargestThatFits` retourne réellement le
minimum. Avec replacement, wet monte celle-ci ; dry, baseline et intrinsics
continuent à mesurer le paragraphe minimum sans consulter la replacement.
Cette valeur est contrainte, finie et indépendante des flips wet.

### Délégation du paragraphe et ressources

Le parent est un `RenderProxyBox` à offset nul. Le `Text`/`Text.rich` final crée
le vrai `RenderParagraph`, qui conserve layout final, paint, clipping,
transform, hit test, recognizers, sémantique et sélection. Le lot ne copie ni
painter privé, ni fragments sélectionnables, ni arbre sémantique.

Chaque `TextPainter` temporaire de recherche, de mot insécable et de hauteur
intrinsèque est possédé localement et disposé dans un `finally`, y compris en
cas d'exception. Le test de fuite natif et son mutant sans `dispose` confirment
que le signal observe bien ces ressources.

### Garde `WidgetSpan` et coût

La garde `WidgetSpan` reste exécutée au build avant toute mesure de paragraphe.
Elle lève `UnsupportedError` sans cloner ni monter l'enfant inline. Sa
suppression est détectée sur les deux SDK. Aucun fallback placeholder du lot 10
n'est introduit prématurément.

Les deux recherches sur le domaine virtuel sont dichotomiques. Un probe de
revue avec 4 096 candidats passe sous une borne de 200 appels de scaler ; un
mutant linéaire dépasse la borne et échoue sur les deux pins. Le coût texte
reste donc `O(log C)` sans allocation proportionnelle au domaine.

## Reproductions et matrice indépendante

Toolchains réellement exécutées :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
```

Les deux fichiers du commit rouge `1d0225f` ont été replacés sur une extraction
exacte de `cc5da0e`. Sur chaque pin, le résultat est `+1 -11`, exit 1. Les six
compositions et les appels directs échouent par la frontière
`_RenderLayoutBuilder`; le cas `Row + Expanded`, volontairement témoin de
non-régression, reste vert.

Sur `033a938` :

| Contrôle | Flutter 3.41.0 | Flutter 3.47.2 |
| --- | ---: | ---: |
| Analyse fatale `lib test example/main.dart` | aucune issue | aucune issue |
| Ciblés intrinsics/render/groupes/config/rich/presets/leak | 84/84 | 84/84 |
| Suite complète naturelle | 140/140 | 140/140 |
| Lifecycle/leak natif | vert dans ciblés et full | vert dans ciblés et full |
| Format final Dart 3.13.2 | sans objet | 31 fichiers, 0 changement |

Les sept mutants suivants ont été appliqués isolément dans une extraction
temporaire et sont tous tués, exit 1, sur les deux pins :

| Mutant | Témoin discriminant |
| --- | --- |
| fallback sur le candidat maximum | métriques du paragraphe minimum |
| largeur intrinsèque dérivée de la taille dry | min intrinsic distinct du max |
| lecture du child actif depuis dry | replacement `LayoutBuilder` wet-only |
| publication du candidat dry au groupe | probe étroit après wet large, aucune frame |
| suppression de la garde `WidgetSpan` | `UnsupportedError` temporaire |
| suppression du `dispose` du painter de candidat | leak tracking natif |
| recherche linéaire | compteur 4 096 candidats sous borne logarithmique |

Les probes temporaires sont absents de la branche auditée.

## Revalidation du correctif scaler

La seconde passe a relu intégralement les quatre fichiers touchés par
`df29507`, `43bb690` et `33c8bab` : les deux sources render/layout, le test
render object et le journal du lot. Le diff `033a938..33c8bab` des deux fichiers
de surface publique, `lib/auto_size_text.dart` et `lib/src/auto_size_text.dart`,
est vide : le wrapper, le helper et les callbacks ajoutés sont tous privés dans
les `part` existants. Aucun import Flutter privé, assertion de constructeur ou
contrat public n'est modifié.

### Portée de la capture

`_scaleUserFontSize` n'est appelé qu'aux deux points qui délèguent réellement
au scaler fourni par l'utilisateur : `source.scale` dans le scaler candidat et
`scaler.scale` dans le calcul de taille effective. Son `try` contient cet appel,
la validation finie/non négative de sa sortie et sa canonicalisation de zéro ;
ces deux dernières opérations sont déterministes, n'appellent ni l'utilisateur
ni Flutter et ne peuvent produire que l'`ArgumentError` déjà prévu pour une
sortie invalide. La validation des entrées, la recherche, la création/layout du
painter et la construction du paragraphe restent hors de cette capture.

Le helper render `_recoverUserScalerFailure` ne capture ensuite que
`_AutoSizeTextUserScalerFailure`, jamais `Object` ou `Error`. Le témoin
`TextSpan.build` fautif traverse encore avec l'objet original ; aucune
`AssertionError`, `FlutterError`, `UnsupportedError` ou erreur interne de
paragraphe hors scaler n'est masquée. Les `finally` qui disposent les painters
restent sur les mêmes chemins.

### Fallbacks et wet layout

Les six retours d'erreur sont adaptés à leur protocole et sans effet de bord :

- dry layout retourne `constraints.constrain(Size.zero)`, donc la plus petite
  taille admise par les contraintes reçues ;
- dry baseline retourne `null`, le signal public d'absence de baseline ;
- les quatre intrinsics retournent `0.0`.

Ils ne lisent ou ne démontent pas le child, ne consultent pas la replacement et
ne publient rien au groupe. L'erreur et la stack originales sont transmises à
`FlutterError.reportError`, puis une configuration valide redonne les six
métriques normales sur la même instance de render object.

En wet, l'extraction de `_reportWetLayoutFailure` conserve la séquence
antérieure : nettoyage du child via le callback de layout, taille
`constraints.smallest`, même contexte de rapport et retour immédiat. Le wrapper
scaler est seulement déballé pour restituer l'objet et la stack utilisateur ;
le catch général historique traite toujours, sans changement, toute autre
erreur de sélection.

### Matrice corrective indépendante

La revalidation a été exécutée sur `33c8bab` avec les mêmes révisions exactes
Flutter/Dart que la matrice initiale. Flutter 3.41.0 a tourné dans une copie
temporaire résolue par son propre SDK ; le worktree de revue et son lock exemple
sont restés inchangés.

| Contrôle | Flutter 3.41.0 | Flutter 3.47.2 |
| --- | ---: | ---: |
| Render/intrinsics/config/lifecycle ciblés | 36/36 | 36/36 |
| Scaler ciblé | 11/11 | 11/11 |
| Suite complète naturelle | 143/143 | 143/143 |
| Leak natif | vert dans la suite complète | vert dans la suite complète |
| Analyse fatale `lib test example/main.dart` | aucun diagnostic | aucun diagnostic |
| Analyse fatale séparée dans `example/` | aucun diagnostic | aucun diagnostic |
| Format Dart canonique | sans objet | 31 fichiers, 0 changement |

`git diff --check` est propre. Aucun probe, mutant ou changement produit n'a
été ajouté par cette revalidation. Le correctif ferme le finding lifecycle sans
réouvrir les garanties d'architecture établies plus haut ; le verdict reste
**ACCEPTÉ**.

## Checklist fonctionnelle et safety

Surface d'entrée : texte simple, arbres `TextSpan`, styles, scalers, domaines de
candidats, contraintes render, limite de groupe, replacement et callbacks
locaux. Il n'existe aucun réseau, base de données, authentification,
autorisation, session, stockage, secret ou opération cryptographique dans le
diff.

| Risque | Conclusion |
| --- | --- |
| Injection, XSS, SQL, commandes | hors surface ; aucune interprétation ou exécution d'entrée |
| Authentification, autorisation/IDOR, CSRF, session | hors surface |
| Cryptographie, secrets, divulgation | hors surface |
| Race / TOCTOU | snapshot de groupe par valeur ; publication wet différée et convergence bornée |
| Disponibilité / DoS | domaine virtuel et recherches `O(log C)` ; aucun subtree arbitraire consulté hors wet |
| Ressources | tous les painters temporaires sont disposés, y compris sur exception |
| Logique render | contraintes, baseline, fallback, lazy lifecycle et délégation au paragraphe vérifiés |

Non vérifiés car hors gate de ce lot : appareil physique, web/profile/AOT et le
wrapper inline complet du lot 10. Ces limites ne diminuent aucune garantie
requise pour le texte simple ou riche sans `WidgetSpan`.
