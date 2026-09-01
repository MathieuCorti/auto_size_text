# Lot 3 — `TextScaler` et configuration effective du texte simple

Date : 2026-09-01

Branche : `codex/impl-effective-text`

Parent exact : `a13534cd12842b2e6847feb4963842175a96ee10`

Tête : commit contenant ce journal ; SHA final communiqué dans le compte rendu

## Périmètre livré

- paramètre public `TextScaler? textScaler` sur les deux constructeurs `const` ;
- conservation de `double? textScaleFactor`, déprécié, avec assertion de
  construction et `ArgumentError` runtime si les deux API sont fournies ;
- résolution du scaler dans l'ordre explicite, ancien facteur converti par
  `TextScaler.linear`, puis `MediaQuery.textScalerOf` ;
- composition non linéarisée du scaler source avec chaque candidat, avec
  validations finies et positives ou nulles des entrées et sorties ;
- snapshot immuable de la configuration effective du texte simple, reconstruit
  à chaque layout ;
- mesure et rendu alignés sur les règles Flutter 3.41/3.47 de `Text` et
  `RenderParagraph` ;
- passage de la configuration après overrides au `TextPainter`, mais de la
  configuration avant overrides au `Text` final, accompagnée du scaler
  candidat afin que Flutter n'applique chaque override qu'une fois ;
- migration des painters du package vers l'API moderne `textScaler`.

Hors périmètre : runs `RichText`, sémantique complète de référence zéro et
NBSP (lot 4), groupes hétérogènes (lot 5), intrinsics/render personnalisé,
`WidgetSpan`, démo, CI, packaging, documentation publique et version.

## Fichiers

- `lib/src/auto_size_text.dart` ;
- `lib/src/auto_size_text_layout.dart` ;
- `test/basic_test.dart` ;
- `test/utils.dart` ;
- `test/text_scaler_test.dart` ;
- `test/effective_text_configuration_test.dart` ;
- présent journal.

## Contrat du scaler

Le scaler candidat stocke le scaler source, le candidat logique et la taille
logique de référence. Pour une taille logique `s`, il appelle exactement
`source.scale(s * candidate / reference)`. La recherche ne lit pas
`textScaleFactor` et ne remplace donc jamais un scaler non linéaire par une
pente locale. L'égalité et le hash comprennent les trois composantes.

Les tailles logiques, le candidat, la référence positive utilisée par la
composition, la taille ajustée et la sortie du scaler doivent être finies et
supérieures ou égales à zéro. Une sortie invalide d'un scaler tiers devient un
`ArgumentError` avant d'atteindre le rendu. Les exceptions propres au scaler
source restent propagées. Le cas historique de référence zéro du texte simple
reste supporté sans division ; sa généralisation aux runs riches appartient au
lot 4.

## Oracle de configuration effective

La taille de référence vient du style parent effectif lorsque `inherit` vaut
`true`, ou du style isolé lorsqu'il vaut `false`, avec fallback historique à
14. Le gras ambiant remplace le poids par `w700`. Les overrides MediaQuery de
hauteur de ligne, espacement des lettres et espacement des mots remplacent les
trois métriques correspondantes. Le strut n'est fusionné que lorsqu'un strut a
été explicitement fourni.

Le snapshot contient aussi l'alignement, la direction, la locale, `softWrap`,
l'overflow effectif, `maxLines`, `textWidthBasis` et le
`textHeightBehavior` provenant de `DefaultTextStyle` puis, à défaut, de
`DefaultTextHeightBehavior`.

Le painter utilise `constraints.minWidth`. Son `maxWidth` est la largeur
contrainte quand le texte wrappe ou utilise une ellipsis, et l'infini sinon.
L'ellipsis n'est installée que pour `TextOverflow.ellipsis`. Le résultat tient
si `didExceedMaxLines` est faux et si `constraints.constrain(textSize)` ne
réduit aucune dimension. Les tests reconstruisent un painter témoin depuis le
`RenderParagraph` réellement rendu et comparent les métriques, plutôt que
d'inspecter seulement le widget source.

## Preuves rouges sur le parent S3

Les nouvelles suites ont été placées sur une archive du parent exact, sans
aucun code produit du lot 3, puis exécutées avec Flutter 3.47.2.

La suite `test/text_scaler_test.dart` ne compilait pas : `textScaler` n'était
un paramètre nommé ni de `AutoSizeText` ni de `AutoSizeText.rich`. Cette preuve
couvre directement la nouvelle surface publique.

La version finale de la suite de configuration a été exécutée depuis
`/private/tmp/auto-size-text-lot3-red.9Kw42Q/repo` : code 1, 4 passages et
3 échecs. Les témoins distinguaient trois causes produit :

- un override métrique isolé attendait le candidat 23 mais l'ancien painter
  choisissait 30 ;
- l'override de hauteur du strut ne provoquait pas le remplacement attendu ;
- `softWrap: false` hérité ne déclenchait pas le remplacement alors que la
  largeur réelle du paragraphe débordait.

Les tests n'ont donc pas été rendus rouges par une attente artificielle : ils
comparent le candidat attendu par l'oracle et les métriques réelles de
`RenderParagraph`.

## Preuves vertes

Toolchains exactes :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
```

### Flutter 3.47.2

| Commande | Résultat |
|---|---|
| format `lib test example`, contrôle `--output=none --set-exit-if-changed` | 24 fichiers, 0 changement |
| analyse scoped fatale `lib test example/main.dart` | aucun diagnostic ; les 9 informations historiques ont disparu |
| `test/text_scaler_test.dart test/effective_text_configuration_test.dart` | 16/16 |
| suite racine complète | 72/72 |
| suites explicites cycle de vie/leak | 9/9 |
| exemple : `pub get --enforce-lockfile`, analyse fatale | succès, aucun diagnostic |

### Flutter 3.41.0

L'état final a été copié dans
`/private/tmp/auto-size-text-lot3-final-min.e53bES/repo`, sans `.git`, locks ni
répertoires générés avant résolution.

| Commande | Résultat |
|---|---|
| `flutter pub get` racine | succès, 26 dépendances résolues naturellement |
| analyse scoped fatale `lib test example/main.dart` | aucun diagnostic |
| deux suites ciblées du lot | 16/16 |
| suite racine complète | 72/72 |
| exemple sans lock : `flutter pub get`, analyse fatale | succès ; `meta 1.17.0`, `vector_math 2.2.0`, aucun diagnostic |
| `flutter pub downgrade`, puis suite complète | 9 dépendances abaissées ; 72/72 |

Le contrôle statique du code produit ne trouve ni appel à
`MediaQuery.textScaleFactorOf`, ni `textScaleFactor` sur un `TextPainter`, ni
shim `dynamic`, `noSuchMethod` ou `Function.apply`. L'ancien paramètre public
reste exercé explicitement par ses tests de compatibilité et de validation.

## Tests permanents ajoutés

La suite scaler couvre les deux constructeurs constants, l'exclusion mutuelle
en assertion et au runtime, l'absence de scaler explicite, le scaler ambiant,
`noScaling`, les scalers linéaire et non linéaire, l'ancien facteur, la priorité
explicite, les sorties non finies ou négatives, le changement entre pumps,
l'égalité/hash du scaler candidat et un groupe homogène sous facteur 2.

La suite configuration couvre héritage vrai/faux et fallback, gras `w700`,
les trois overrides ensemble, isolément et entre pumps, strut 100/hauteur 60,
`softWrap` hérité et explicite, clip/ellipsis/remplacement, `minWidth` non nul,
RTL, locale, alignement, `textWidthBasis` et `textHeightBehavior`. Les tests de
groupe historiques, dont la couverture permanente du scénario #25, restent
verts dans la suite complète.

## Limites et risques transmis

- la branche riche passe désormais par l'API moderne, mais l'oracle détaillé
  des runs, la référence zéro complète et NBSP restent strictement au lot 4 ;
- les groupes homogènes conservent leur comportement historique ; la projection
  entre scalers ou domaines hétérogènes reste au lot 5 ;
- le test de gras vérifie le `w700` effectif ; le dépôt ne fournit pas de police
  de fixture garantissant sur toutes les plateformes une largeur différente
  entre poids ;
- aucun fichier de démo, CI, exemple, manifeste, lock, documentation publique
  ou version n'est modifié ;
- aucun merge, push, tag ou changement distant n'est effectué.
