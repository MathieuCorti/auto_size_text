# Lot 9 — Intrinsics et dry layout lean

Date : 2026-09-02

Branche : `codex/impl-intrinsics`

Parent S7 exact : `cc5da0eafcfd17130978041fa1bcc638dfa10d20`

Tests rouges : `1d0225f` ; implémentation et tests verts : `dbed398` ; le
commit suivant contient uniquement ce journal.

## Périmètre livré

Le `LayoutBuilder` qui formait la frontière de layout a été remplacé, pour le
texte simple et riche sans `WidgetSpan`, par une composition Flutter publique :

```text
AutoSizeText
└─ RenderBox parent (_RenderAutoSizeText)
   └─ branche montée seulement pendant wet layout
      ├─ Text / Text.rich -> RenderParagraph
      └─ overflowReplacement lorsque le minimum ne tient pas
```

Le parent est un `RenderProxyBox` créé par un `RenderObjectWidget`. Son
`RenderObjectElement` minimal ne change son unique child que depuis un callback
ouvert par `invokeLayoutCallback` pendant le wet layout. Les chemins dry ne
construisent et ne consultent aucun widget. Ils mesurent un snapshot immuable
avec des `TextPainter` temporaires tous disposés en `finally`.

Le noyau existant des lots 2 à 5 est réutilisé : domaine candidat virtuel,
dichotomie `findLargestThatFits`, composition du `TextScaler`, oracle de fit,
snapshot des mots insécables et projection de groupe. Il n'existe pas de
seconde recherche ou d'algorithme de fit propre au render object.

Le parent implémente les quatre intrinsics, `computeDryLayout` et
`computeDryBaseline`. Le wet layout sélectionne le même candidat à snapshot et
contraintes égaux, monte le `Text` final puis laisse son vrai `RenderParagraph`
assurer layout, paint, transform, hit test, sémantiques, recognizers et
sélection. Aucune copie de painter de rendu, de sélection ou de sémantique n'a
été introduite. Aucun import `package:flutter/src`, type privé Flutter ou
nouvelle API publique du package n'est utilisé.

`textKey` appartient désormais explicitement au petit widget de frontière dont
le render object résolu est le `RenderParagraph` final. Le widget associé à la
clé reste un détail d'implémentation et n'est plus promis comme un `Text`.

## Dry, groupe et replacement

Le snapshot capture toutes les valeurs effectives de texte, le domaine et la
limite de groupe comme des valeurs immuables. Une requête dry ou intrinsic ne
modifie ni l'état, ni le render object, ni le groupe et ne dépend pas de la
branche wet courante. Le wet publie la taille locale effective `P=U(L)` une
seule fois par transition, après sélection et layout du child final. La
projection `R` utilise la dichotomie du lot 5 et n'est jamais publiée.

`overflowReplacement` reste strictement lazy. Elle n'est pas montée lorsque le
texte tient. Dry layout, dry baseline et les quatre intrinsics ne la montent,
ne la construisent et n'appellent aucune de ses métriques, avant ou après un
wet layout qui l'a rendue active. Le témoin permanent emploie à la fois un
`LayoutBuilder` et un descendant qui lève sur chacune des six requêtes sèches.

Si aucun candidat ne tient, la sélection est déterministe au minimum. Sans
replacement, wet rend le paragraphe minimum. Avec replacement, wet monte et
layoutte la replacement ; dry et intrinsics conservent volontairement la taille
contrainte et la baseline du paragraphe minimum. Un `RenderParagraph` témoin
verrouille directement ces métriques. Les répétitions avant et après wet sont
identiques, finies et sans exception.

Le texte riche contenant un `WidgetSpan` reste explicitement rejeté par le
guard `UnsupportedError` existant, avant toute mesure. Ce lot ne monte, ne
mesure et ne résout aucun enfant inline ; ce périmètre appartient au lot 10.

## Preuves rouges sur S7

Le commit `1d0225f` ajoute d'abord les régressions sans modifier le produit.
Sur `cc5da0e`, Flutter 3.47.2 reproduit `_RenderLayoutBuilder` : les six
compositions demandées (`IntrinsicWidth`, `IntrinsicHeight` dans
liste/card/row, `Chip`, `FilterChip`, `DataTable`, `PaginatedDataTable`) et les
requêtes directes dry/intrinsic échouent. Le témoin indépendant du lot a
reproduit séparément les six compositions et la pureté de groupe sur cette même
base.

Les tests verts couvrent ensuite :

- les quatre intrinsics, dry layout et dry baseline comparés à un
  `RenderParagraph` ;
- minima non nuls, axes infinis, répétitions, simple/riche, scaler, presets,
  `maxLines` et `wrapWords` ;
- fallback exact au minimum et replacement stateful/`LayoutBuilder` wet-only ;
- recognizer touché dans la box exacte du span, label sémantique,
  `SelectionArea` et contrat `textKey` ;
- snapshot de groupe pur, absence de frame après requêtes dry et convergence
  wet ;
- compteurs simples et riches bornés logarithmiquement, sans seuil mural ;
- disposal des painters pendant les six requêtes sèches et les erreurs.

## Matrice verte

Toolchains exactes :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
```

| Contrôle | Flutter 3.41.0 | Flutter 3.47.2 |
| --- | ---: | ---: |
| analyse fatale `lib test example/main.dart` | aucun diagnostic | aucun diagnostic |
| analyse fatale séparée dans `example/` | aucun diagnostic | aucun diagnostic |
| ciblés lot 9 + groupes + texte/config/domaine | 76/76 | 76/76 |
| lifecycle/leak ciblé | 10/10 | 10/10 |
| suite complète naturelle | 140/140 | 140/140 |
| suite complète après downgrade minimum | 140/140 | sans objet |

Le downgrade 3.41.0 a abaissé neuf dépendances. Le formatteur Dart 3.11 a
réécrit mécaniquement la forme de deux appels `testWidgets`; le formatteur
canonique Dart 3.13 les a restaurés ensuite. Après la matrice, la résolution
3.47.2 a restauré les locks byte-identiques à leur état initial :

```text
pubspec.lock         SHA-1 8d64fa6447216488e1ca9ca5e1406dd83c5e9455
example/pubspec.lock SHA-1 6ce414e74d7d5b4d7143e1a3cfaa1528127994d9
```

`dart format` 3.47.2, `git diff --check` et l'analyse fatale finale sont verts.
Le worktree était propre avant la création de ce journal.

## Challenge indépendant

Un agent séparé a audité `dbed398` sans modifier ses fichiers. Son témoin
black-box passe **10/10** sous Flutter 3.41.0 et 3.47.2, et les suites
officielles intrinsics/render/painter passent **23/23** sur chaque pin. Les
trois cas renforcés après sa revue précoce sont discriminants : le tap précis
sur le span appelle le recognizer exactement une fois, `textKey` et le
paragraphe sont absents lorsque la replacement est active, et les requêtes dry
de groupe ne planifient aucune microtâche. Le probe vérifie aussi les six
métriques avant/après wet contre un `LayoutBuilder` wet-only, la référence zéro
simple/riche et un domaine de 4 096 candidats sous borne logarithmique.

Verdict : aucun finding fonctionnel P0, P1 ou P2. Le probe a été supprimé et le
worktree de challenge est propre.

## Correctif après revue lifecycle

Une revue lifecycle plus profonde, consignée dans `4b9bb54` puis précisée par
`8ee34e7`, a ensuite isolé un P2 distinct : lorsqu'un `TextScaler.scale`
utilisateur levait pendant `getDryLayout` ou `getDryBaseline`, l'exception
sortait de la frontière `RenderBox`. Les Flutter 3.41.0 et 3.47.2 ne remettent
leurs gardes dry internes à zéro qu'après un retour normal. Après un rebuild
valide, la seconde requête sur le même render object échouait donc sur une
assertion de garde Flutter restée armée.

Le commit rouge `13cd615` reproduit la séquence exacte sans scaler mutable :
wet valide, rebuild limité à `EnginePhase.build` avec un scaler immuable qui
lève, requête dry, rebuild build-only valide, puis nouvelle requête sur la même
instance de parent. Sur `033a938`, le premier `StateError` sort directement et
le test échoue avant le fallback attendu.

Le correctif `64ecf8a` borne le traitement aux deux appels directs au scaler
utilisateur. `_scaleUserFontSize` appelle le callback et valide sa sortie dans
un `try/catch` étroit ; il conserve l'objet original et sa stack dans
`_AutoSizeTextUserScalerFailure`. Les six entrées dry/intrinsic ne capturent que
ce type privé, rapportent l'erreur originale via `FlutterError.reportError`,
puis retournent sans mutation :

- dry layout : `constraints.constrain(Size.zero)` ;
- dry baseline : `null` ;
- quatre intrinsics : `0.0`.

Wet reconnaît le même wrapper, démonte le child périmé comme auparavant et
rapporte l'objet utilisateur original avec sa stack originale. Son comportement
d'erreur visible ne change donc pas. Le catch général wet historique reste
inchangé pour les autres erreurs de layout.

L'oracle permanent exerce les six fallbacks, l'identité et la stack de chaque
rapport, puis les six résultats normaux après restauration du scaler sur le
même render object. `getDryBaseline` réappelle volontairement
`computeDryBaseline` en assertion debug ; le test exige donc une cardinalité
exacte d'un rapport pour la reproduction `getDryLayout`, mais seulement que
tous les rapports baseline proviennent du même objet et de la même stack. Un
témoin séparé injecte une erreur de `TextSpan.build` hors scaler et vérifie
qu'elle traverse encore : aucune assertion ou erreur interne Flutter n'est
convertie en fallback par un catch global.

### Matrice du correctif lifecycle

| Contrôle | Flutter 3.41.0 | Flutter 3.47.2 |
| --- | ---: | ---: |
| analyse fatale `lib test example/main.dart` | aucun diagnostic | aucun diagnostic |
| analyse fatale séparée dans `example/` | aucun diagnostic | aucun diagnostic |
| ciblé render object | 8/8, inclus dans le ciblé combiné | 8/8 |
| ciblé scaler/render/intrinsics/lifecycle/leak | 38/38 | 38/38 |
| lifecycle/leak dédié | 10/10 | 10/10 |
| suite complète naturelle | 143/143 | 143/143 |
| suite complète après downgrade minimum | 143/143 | sans objet |

Le downgrade 3.41.0 a de nouveau abaissé neuf dépendances. Le format et les
deux locks ont ensuite été restaurés avec Flutter 3.47.2 aux SHA-1 canoniques
déjà consignés plus haut.

## Limites transmises

- `WidgetSpan` reste hors lot et explicitement gardé jusqu'au lot 10 ;
- en overflow avec replacement, la géométrie dry est celle du texte minimum,
  pas celle de la replacement wet ;
- la recherche suppose, comme aux lots précédents, un fit monotone et un
  scaler monotone non décroissant ;
- aucune démo, CI, API publique additionnelle, merge, push, tag ou publication
  ne fait partie de ce lot.

## Commits

- `1d0225f` — `test: reproduce intrinsic layout failures` ;
- `dbed398` — `feat: support intrinsic text layout` ;
- `033a938` — `docs: record lot 9 intrinsics validation` ;
- `13cd615` — `test: reproduce poisoned dry scaler failures` ;
- `64ecf8a` — `fix: recover from dry scaler failures` ;
- commit suivant — journal du correctif lifecycle.
