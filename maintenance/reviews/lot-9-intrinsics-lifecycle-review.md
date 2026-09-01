# Revue indépendante lot 9 — compatibilité et lifecycle intrinsics

Date : 2026-09-02

Tip audité : `033a938474d432a27bbc29cf30943c69991ee68a`

Base du lot : `cc5da0eafcfd17130978041fa1bcc638dfa10d20`

## Verdict

**NO-GO en l'état : un finding P2 reproductible reste ouvert.** Les chemins
valides du lot passent la matrice Flutter 3.41.0 / 3.47.2 et les probes
lifecycle demandés. En revanche, un `StateError` levé par l'implémentation
utilisateur de `TextScaler.scale` traverse directement la frontière
`RenderBox`. Flutter laisse alors son garde dry interne armé ; un second appel
sur le même render object échoue sur une assertion de framework, même après
installation d'une configuration redevenue valide.

Le finding ne remet pas en cause le choix architectural lean, la branche
replacement lazy, les groupes, `textKey`, les recognizers, la sélection ou les
compositions intrinsèques valides. Il bloque néanmoins l'affirmation du journal
lot 9 selon laquelle les erreurs et requêtes dry répétées sont sans effet. Une
correction bornée aux six entrées dry/intrinsic, puis une revalidation ciblée,
est requise avant acceptation.

## Finding

### [P2] Une erreur dry empoisonne les appels dry suivants du render object

**Fichiers :** `lib/src/auto_size_text_render_object.dart:187-223` et
`lib/src/auto_size_text_layout.dart:159-165,347-377,465-493,537-545`

`computeDryLayout`, `computeDryBaseline` et les quatre intrinsics appellent
directement `_snapshot.select` / `intrinsicHeight`. Dans la reproduction, la
sélection arrive dans `_measure`, puis `TextPainter.layout` appelle
`_CandidateTextScaler.scale`. La ligne 163 délègue à
`source.scale(adjustedFontSize)` : le scaler fourni par l'appelant lève alors
exactement `StateError('review scaler failure')`. Le `finally` de `_measure`
dispose correctement le painter, puis ce même `StateError` remonte sans
transformation à travers `computeDryLayout` ou `computeDryBaseline`.

Il ne s'agit donc ni d'un `ArgumentError` produit par la validation numérique
du package, ni d'une erreur du child rendu. `_checkedEffectiveFontSize` appelle
aussi directement le scaler utilisateur à la ligne 542 et constitue le second
point d'entrée à normaliser. Contrairement à `performLayout`, aucune des six
méthodes non-wet ne traite cette erreur d'entrée utilisateur.

Sur Flutter 3.41.0 et 3.47.2, `RenderBox._computeDryLayout` et
`RenderBox._computeDryBaseline` positionnent respectivement
`_computingThisDryLayout` et `_computingThisDryBaseline` avant d'appeler
l'override, puis les remettent à `false` seulement après son retour normal. Il
n'y a pas de `finally`. Une exception qui sort de l'override laisse donc le
garde armé. Le second appel échoue avant même de revenir dans le package :

```text
'package:flutter/src/rendering/box.dart': Failed assertion:
'!_computingThisDryLayout': is not true
```

L'inspection des deux SDK montre aussi que les quatre intrinsics traversent
`RenderBox._computeWithTimeline`, dont la profondeur de mesure et la timeline ne
sont refermées qu'après un retour normal. Le probe rend directement observable
l'empoisonnement des deux gardes dry ; la même erreur utilisateur ne doit pas
sortir des quatre entrées intrinsèques non plus.

### Reproduction indépendante

Le probe temporaire utilise un `TextScaler` **immuable** qui lève toujours. Il
évite donc de dépendre d'une mutation contraire au contrat `@immutable` :

1. monter et layoutter normalement deux `AutoSizeText` avec
   `TextScaler.noScaling` ;
2. reconstruire seulement jusqu'à `EnginePhase.build` avec le scaler fautif,
   de sorte que le nouveau snapshot soit installé sans wet layout ;
3. appeler `getDryLayout` sur le premier parent et `getDryBaseline` sur le
   second : les deux transmettent exactement
   `StateError('review scaler failure')`, issu de `TextScaler.scale` ;
4. reconstruire seulement jusqu'à `EnginePhase.build` avec
   `TextScaler.noScaling` ;
5. répéter les deux requêtes sur les mêmes render objects : les deux lèvent
   désormais `AssertionError` sur le garde Flutter resté armé.

Le paragraphe wet demeure monté, attaché et non disposé après la première
erreur. L'effet observé est donc bien l'état interne du protocole dry, et non un
remplacement de branche ou une destruction du child. Le cas est identique sous
Flutter 3.41.0 et 3.47.2.

### Ce que ce finding n'est pas

Le finding ne concerne pas un child qui ne sait pas répondre au dry layout.
La branche replacement `LayoutBuilder` contient volontairement un render box
qui lève si l'une de ses six métriques non-wet est appelée. Le parent
`_RenderAutoSizeText` ne consulte jamais ce child pendant dry/intrinsic ; tous
les probes correspondants passent avant, pendant et après wet overflow. Il n'y
a donc aucune raison de capturer ou masquer une erreur `debugCannotComputeDryLayout`
de child, et le correctif ne doit pas interroger la branche active.

Le premier `StateError` appartient à l'entrée utilisateur `TextScaler`. Le
second `AssertionError` appartient au garde de protocole Flutter laissé armé
par la sortie exceptionnelle. Le package doit empêcher la première erreur
utilisateur de franchir cette frontière précise ; il ne doit pas convertir en
fallback toutes les assertions, `FlutterError` ou erreurs internes de
`TextPainter`/Flutter. Aucun défaut séparé de child ou de framework n'est
revendiqué par cette reproduction.

Les tests permanents ne le détectent pas :

- `text_painter_lifecycle_test.dart` vérifie une erreur de paragraphe pendant
  wet layout, que `performLayout` capture correctement ;
- le test dry lifecycle n'utilise que des mesures valides ;
- aucun test n'enchaîne erreur dry, configuration valide et seconde requête sur
  la même instance de `_RenderAutoSizeText`.

### Correction lean recommandée

Le correctif ne devrait pas ajouter un `catch (Object)` autour de
`_snapshot.select`, car il masquerait aussi un invariant cassé dans la recherche
du package ou dans Flutter. La frontière étroite est connue : les appels au
`TextScaler` fourni par l'utilisateur.

1. Faire passer `source.scale` (`_CandidateTextScaler.scale`, ligne 163) et
   `scaler.scale` (`_checkedEffectiveFontSize`, ligne 542) par un helper privé.
   Son `try/catch` doit entourer **uniquement** l'appel au callback utilisateur,
   conserver l'objet erreur et sa stack, puis lever un wrapper privé typé, par
   exemple `_AutoSizeTextUserScalerFailure`. Une sortie non finie ou négative
   doit produire le même wrapper typé après la validation existante.
2. Dans les six overrides dry/intrinsic, capturer uniquement ce wrapper privé.
   Rapporter son erreur originale et sa stack avec `FlutterError.reportError`,
   puis retourner un fallback fini sans mutation : `constraints.smallest` pour
   dry layout, `0.0` pour baseline et intrinsics. Ne pas démonter le child, ne
   pas publier au groupe et ne pas lire la replacement.
3. Laisser remonter les erreurs levées hors du seul appel au callback
   utilisateur, notamment `AssertionError`, `FlutterError`, `UnsupportedError`
   et les erreurs internes de `TextPainter`/Flutter. Le traitement wet existant
   reste inchangé.

Ce ciblage traite l'entrée utilisateur prouvée sans catch-all dangereux et
laisse les `finally` actuels disposer les painters. Les régressions doivent
couvrir dry layout, dry baseline et au moins un intrinsic avec : scaler
immuable fautif, erreur originale rapportée, rebuild valide, puis second appel
valide sur le même render object. Elles doivent conserver le témoin child
wet-only qui lève si le parent le consulte.

## Surfaces relues et résultats

### API publique, valeurs par défaut et constructeurs

Les signatures de `AutoSizeText`, `AutoSizeText.rich`, `AutoSizeGroup` et
`AutoSizeGroupBuilder` sont inchangées. Les valeurs par défaut sont conservées :
minimum 12, maximum infini, pas 1, `wrapWords: true`, paramètres texte et scaler
optionnels. Les nouveaux types sont tous privés. L'import public de
`package:flutter/rendering.dart` ne réexporte aucun symbole.

Le seul changement public intentionnel est la précision de contrat de
`textKey` : la clé trouve désormais un élément dont `findRenderObject()` résout
le `RenderParagraph`, sans garantir que le widget clé soit un `Text`. Le probe
et les tests permanents confirment ce contrat dans les branches texte simple et
riche ; la clé et le paragraphe sont absents lorsque la replacement est active.

### Branche wet, child et délégation Flutter

Le probe `fit -> overflow -> fit` confirme :

- aucune initialisation de la replacement stateful tant que le texte tient ;
- une initialisation lors du premier overflow, puis un `dispose` au retour au
  texte ;
- destruction effective de l'ancien `RenderParagraph`
  (`debugDisposed == true`) et création d'un nouveau paragraphe au retour ;
- destruction du paragraphe final au démontage du parent ;
- une seule branche visible et sémantique à chaque étape ;
- fonctionnement wet d'une replacement `LayoutBuilder` contenant un render box
  qui rejette explicitement dry layout, dry baseline et les quatre intrinsics.

Les requêtes dry répétées avant overflow wet, pendant que la replacement est la
branche wet, puis après retour au texte rendent les mêmes sept valeurs (deux
baselines incluses), ne reconstruisent pas la replacement et ne consultent
aucune de ses métriques.

Le texte final reste un vrai `RenderParagraph`. Paint, transforms, hit test,
recognizers, sémantique et `SelectionArea` sont délégués à Flutter. Le test
permanent touche la box exacte du span reconnaissable et observe un seul tap,
un seul label de sémantique et aucune exception.

### Groupes et microtâches

Un probe retient volontairement les microtâches issues de
`auto_size_group.dart`, puis :

- baisse un membre et le transfère vers un autre groupe avant notification ;
- exécute ensuite les notifications devenues anciennes ;
- baisse à nouveau le membre, le dispose avant notification, puis libère la
  notification retenue.

Les deux groupes convergent vers leurs minima courants, l'ancien groupe ne
conserve aucune contribution, le membre disposé n'est pas notifié, aucun frame
résiduel n'est planifié et aucun render child n'est conservé. Les tests
permanents couvrent en plus égalité de contrôleurs, retrait de minimum,
projection hétérogène et coalescence des diminutions synchrones.

### Rebuild du snapshot et ressources

Sur la même instance de parent et le même `RenderParagraph`, le probe bascule
simple vers riche et change texte, style hérité, domaine preset, scaler,
alignement, wrap, overflow, `maxLines`, locale et label sémantique. Le paragraphe
et les métriques dry reflètent toutes les nouvelles valeurs. Une liste preset
mutée sans rebuild ne modifie pas le snapshot déjà installé ; le rebuild
suivant prend le nouveau domaine copié.

Tous les `TextPainter` créés par `_measure` et `intrinsicHeight`, y compris le
painter supplémentaire de `wrapWords: false`, sont protégés par `finally`. La
suite leak permanente exerce les six requêtes sèches, les chemins fit/no-fit,
les erreurs wet, les rebuilds et le retrait de groupe. Le probe observe aussi
la disposition réelle des render children lors des bascules et du démontage.

Le seul défaut de ressources/protocole observé est le finding dry-error ci-dessus.

## Matrice exécutée

Toolchains exactes :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
```

| Contrôle | Flutter 3.41.0 | Flutter 3.47.2 |
| --- | ---: | ---: |
| probe indépendant lifecycle/error | 5/5 | 5/5 |
| analyse fatale `lib test example/main.dart` | aucun diagnostic | aucun diagnostic |
| suite complète officielle | 140/140 | 140/140 |
| lifecycle/leak inclus dans la suite | vert | vert |
| analyse de `example/` sur résolution compatible | aucun diagnostic | aucun diagnostic |

Le test du finding est vert parce qu'il encode explicitement la séquence
fautive attendue `StateError -> AssertionError`; il ne transforme pas le défaut
en succès produit.

Le lock `example/pubspec.lock` haut ne peut pas être imposé tel quel à Flutter
3.41.0 : `meta 1.19.0` et `vector_math 2.4.2` doivent descendre respectivement à
1.17.0 et 2.2.0. Une résolution temporaire normale sous 3.41.0, suivie de
l'analyse, est verte. Le lock a ensuite été restauré byte-identique. Les hashes
finaux sont :

```text
pubspec.lock         SHA-1 8d64fa6447216488e1ca9ca5e1406dd83c5e9455
example/pubspec.lock SHA-1 6ce414e74d7d5b4d7143e1a3cfaa1528127994d9
```

Le probe temporaire a été supprimé avant les suites officielles. Aucun fichier
de test ou code produit n'est conservé par cette revue.

## Audit de complétude

Fichiers du lot relus intégralement, diff et contexte courant :

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

`lib/src/auto_size_group.dart` et `lib/src/auto_size_group_builder.dart`, non
modifiés par le lot, ont aussi été relus intégralement pour l'audit lifecycle.
Les implémentations Flutter locales de `RenderObjectElement`,
`invokeLayoutCallback`, `RenderProxyBox.child`, `RenderBox` dry/baseline et
`LayoutBuilder` ont été comparées sur 3.41.0 et 3.47.2.

Cartographie sécurité : les entrées sont exclusivement les propriétés widget,
textes/spans, scalers, contraintes et états de groupe. Il n'y a ni requête
réseau/base de données, ni authentification/autorisation, session,
cryptographie, secret ou appel système dans le diff. Injection, XSS, CSRF,
IDOR, fixation de session et cryptographie sont donc sans objet. Les races de
microtâches, la rétention/disposition, les erreurs, la complexité de recherche
et les transitions de machine d'état ont été vérifiées ; le finding P2 est le
seul défaut de logique ou de lifecycle observé.

Conformément au périmètre demandé, cette revue ne réclame ni support de
`WidgetSpan`, ni exactitude géométrique de la replacement pendant dry/intrinsic.

## Conclusion

Les chemins valides et la compatibilité 3.41/3.47 sont solides, et la frontière
render respecte le contrat lazy retenu. Le lot ne doit toutefois pas être
accepté tant que les six méthodes dry/intrinsic laissent une erreur de mesure
sortir et empoisonner le protocole Flutter. Verdict final : **NO-GO, un P2 à
corriger, aucun P0/P1 et aucun autre P2 observé.**
