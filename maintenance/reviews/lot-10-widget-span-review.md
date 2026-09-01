# Revue indépendante ciblée — lot 10 `WidgetSpan`

Date : 2026-09-02

Base S8 auditée : `4794200df27ba042a4c8a8ebbe82719c499340f6`

Tête auditée : `e1e814661925ee1dc2a2ee046256b0b51f98c116`

Branche de revue : `codex/review-widget-span`

## Verdict

**ACCEPTÉ.** Aucun finding fonctionnel, render-tree ou safety P0, P1 ou P2
n'est ouvert.

Le lot respecte le contrat lean admis : la taille, la baseline dry et les
quatre intrinsics des wrappers inline restent nulles sans consulter le child.
La divergence dry/wet documentée n'est donc pas un finding. La sélection wet
layoutte les vrais widgets, conserve le `WidgetSpan` exact et délègue au vrai
`RenderParagraph` la géométrie finale, le paint, le hit test, la sémantique et
la sélection.

Le correctif final `061b561` ferme bien le risque de double branche :
`_AutoSizeTextRenderElement` ne conserve qu'un seul `Element`. Une replacement
active est désactivée le temps de monter le paragraphe de mesure, puis reprise
par la `GlobalKey` interne stable si l'overflow persiste. Le paragraphe et la
replacement ne sont jamais actifs simultanément.

## Périmètre lu intégralement

Le diff complet S8..tête contient 8 fichiers, 1 881 ajouts et 38 suppressions.
Chaque fichier modifié a été lu intégralement :

- `lib/auto_size_text.dart` ;
- `lib/src/auto_size_text.dart` ;
- `lib/src/auto_size_text_inline.dart` ;
- `lib/src/auto_size_text_layout.dart` ;
- `lib/src/auto_size_text_render_object.dart` ;
- `maintenance/implementation/lot-10-widget-span.md` ;
- `test/rich_text_test.dart` ;
- `test/widget_span_test.dart`.

Les portions pertinentes de `WidgetSpan`, `RenderParagraph`,
`RenderInlineChildrenContainerDefaults`, `TextParentData`,
`Element.updateChild`, `Element.inflateWidget` et la reprise des `GlobalKey`
ont aussi été comparées dans les sources exactes de Flutter 3.41.0 et 3.47.2.
Le diff n'importe aucun `package:flutter/src` et n'appelle aucune API Flutter
privée.

## Revue render-tree et `InlineSpan`

### Extraction et composition

Les deux parcours internes utilisent `visitDirectChildren` dans le même ordre
preorder. Le premier extrait exactement un widget par `WidgetSpan`; le second
recalcule exactement un font size logique par child. Les enfants du paragraphe
reçoivent le `WidgetSpan` original dans `TextParentData.span`. Les overrides de
style ne clonent que les `TextSpan` standards et conservent l'identité du
`WidgetSpan`; l'arbre source n'est jamais modifié.

Le tag public `PlaceholderSpanIndexSemanticsTag` est incrémenté une fois par
placeholder extrait. Le child original ne possède qu'un emplacement actif et
les tests vérifient cardinalité, ordre, `ParentData`, absence de duplication et
immutabilité de la source.

### Scaling, contraintes et baselines

Le facteur wet est calculé par run logique :

```text
candidateScaler.scale(runFontSize) / runFontSize
```

Le run zéro évite division et appel au scaler. Les facteurs non linéaires et
les références zéro restent finis. Le wrapper inverse seulement la contrainte
de largeur, comme le wrapper Flutter témoin, laisse la hauteur libre, puis
applique le même facteur à la taille, à la baseline, au paint transform et au
hit test. Le facteur zéro expose une géométrie nulle et ne peint ni ne hit-teste
le child.

Top, middle, bottom, baseline alphabétique et idéographique sont couverts dans
la suite livrée. Un probe indépendant a aussi comparé above/below-baseline et
les deux baselines avec un `RichText` scalé : géométrie identique sur les deux
pins.

### Wet, dry et coût

Chaque candidat wet configure le scaler et les wrappers, layoutte le vrai
paragraphe, puis laisse l'arbre sur le candidat rendu. Les painters auxiliaires
reçoivent des dimensions nulles en preorder et sont tous disposés dans un
`finally`.

Le wrapper inline répond directement `Size.zero`/`0.0` aux six métriques
non-wet. Le test trap confirme que le child n'est jamais appelé. Cette
approximation peut sélectionner un candidat différent du wet, conformément au
contrat lean explicite.

Pour `P` placeholders, chaque candidat effectue un parcours et un layout
bornés par `P`; les deux recherches de candidats restent dichotomiques. Le
témoin `P=3`, `C=1024` respecte la borne `P log C`. Un child non monotone finit
de manière déterministe et bornée, sans promesse d'optimum global.

### Paint, interaction et accessibilité

`applyPaintTransform`, `pushTransform` et `addWithPaintTransform` appliquent la
même matrice. Les tests observent la taille transformée, le paint, le hit test
et le tap du `GestureDetector`. Le vrai `RenderParagraph` conserve les
recognizers texte, la sémantique du child et l'inscription à `SelectionArea`.
Un probe supplémentaire avec référence typographique zéro et plusieurs
candidats reste sélectionnable sans exception sur les deux pins.

## Revue ciblée de `061b561`

Le protocole mono-`Element` suit cette séquence :

1. le layout callback remplace l'éventuelle replacement par le paragraphe au
   candidat minimum ;
2. la recherche wet configure et layoutte ce même paragraphe ;
3. le callback final conserve le paragraphe s'il tient, ou reprend le
   `KeyedSubtree` de replacement par sa `GlobalKey` interne stable ;
4. le seul render child actif est retiré puis inséré au slot `null`.

Les branches ne nécessitent aucun `moveRenderObjectChild` : le slot reste
toujours `null`. L'`assert(false)` de cette méthode n'a pas été atteint, y
compris pendant les reprises de `GlobalKey` et les flips répétés fit/overflow.
En release, la même séquence appelle retrait puis insertion et ne dépend donc
pas de cette assertion.

Les `StateError` de configuration protègent trois invariants internes :
paragraphe monté, wrapper de scale présent et cardinalité children/spans
identique. Les widgets construits par les API publiques établissent ces
invariants avant la configuration. Les tests de changements de source,
replacement active, groupe, retrait, disposal et clé partagée ne les rendent
pas atteignables. Si une erreur interne ou user-layout survient néanmoins, le
catch wet nettoie l'unique child, fixe une taille contrainte et la transmet à
`FlutterError.reportError`; il ne laisse pas deux branches actives.

La replacement reste lazy hors sélection overflow. Quand elle est déjà active,
sa `State` survit à un rebuild toujours-overflow. Une `GlobalKey` utilisateur
partagée entre son subtree et le child inline reste exclusive et ne déclenche
ni duplication, ni crash. Un probe indépendant a enchaîné cinq flips de
contraintes fit/overflow avec cette clé partagée, sans exception sur les deux
pins.

## Matrice indépendante

Toolchains réellement exécutées :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
```

| Contrôle | Flutter 3.41.0 | Flutter 3.47.2 |
| --- | ---: | ---: |
| Analyse fatale `lib test example/main.dart` | aucun diagnostic | aucun diagnostic |
| WidgetSpan + rich/render/intrinsics/group/replacement/wrap/scaler | 69/69 | 69/69 |
| Suite complète | 156/156 | 156/156 |
| Probes adversariaux temporaires | 3/3 | 3/3 |

Les probes temporaires couvrent la sélection avec référence zéro, les
alignements baseline non explicitement comparés dans la suite, et les flips
répétés avec `GlobalKey` partagée. Ils sont restés hors de la branche.

Après la matrice, la résolution haute a été restaurée. Les locks ont les mêmes
SHA-1 que la tête auditée :

```text
pubspec.lock         8d64fa6447216488e1ca9ca5e1406dd83c5e9455
example/pubspec.lock 6ce414e74d7d5b4d7143e1a3cfaa1528127994d9
```

`git diff --check` est propre.

## Checklist fonctionnelle et safety

Surface d'entrée : arbres `TextSpan`, `WidgetSpan.child`, styles, scalers,
domaines candidats, contraintes render, groupe, selection registrar et
replacement. Il n'existe aucun accès réseau, base de données, authentification,
autorisation, session, stockage, secret ou opération cryptographique dans le
diff.

| Risque | Conclusion |
| --- | --- |
| Injection | hors surface ; aucune entrée n'est interprétée comme code, commande ou requête |
| XSS | hors surface ; aucun rendu HTML |
| Authentification | hors surface |
| Autorisation / IDOR | hors surface |
| CSRF | hors surface |
| Race / TOCTOU | snapshot immutable par build ; échanges de child confinés au callback wet synchrone |
| Session | hors surface |
| Cryptographie | hors surface |
| Divulgation | les erreurs wet suivent `FlutterError.reportError`, sans donnée sensible ajoutée |
| Disponibilité / DoS | recherche bornée `O(P log C)` ; non-monotonie terminante ; pas de child arbitraire hors wet |
| Logique métier/render | ordre 1:1, facteurs, baselines, contraintes, groupes, replacement et lifecycle vérifiés |
| Ressources | painters disposés en `finally`; teardown/disposal et leak tracking verts dans la suite complète |

Non vérifiés directement : appareil physique et compilation AOT/profile. Les
deux toolchains exactes compilent, analysent et exécutent cependant toutes les
branches demandées. Les sous-classes personnalisées de `PlaceholderSpan`
autres que `WidgetSpan` restent hors contrat, comme dans le helper public de
Flutter.
