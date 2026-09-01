# Fixtures permanentes de métriques de texte

Date : 2026-09-01

Base examinée : `cac342c8bdb0fb1e874cb7d18d609c691a46d5a5`

SDK examinés :

| Flutter | Dart | Révision framework |
|---|---|---|
| 3.41.0 | 3.11.0 | `44a626f4f0027bc38a46dc68aed5964b05a83c18` |
| 3.47.2 | 3.13.2 | `d3b14c876900e553bc736ca19295fc09e3853e8e` |

Cette décision ferme uniquement les lacunes de preuve métrique signalées par
les deux revues indépendantes du lot 3. Elle ne propose aucun changement de
code produit et ne change pas l'oracle fonctionnel.

## Décision

Versionner trois petits TTF sous `test/assets/fonts/`, avec deux licences
adjacentes, puis les charger une fois dans le `setUpAll` de
`effective_text_configuration_test.dart` au moyen de `FontLoader`. Le helper
lit chaque `File`, puis convertit précisément ses octets par
`ByteData.sublistView`; `FontLoader.addFont` reçoit ainsi le
`Future<ByteData>` attendu sur les deux SDK. Ils ne doivent pas être déclarés
comme fontes ou assets Flutter dans `pubspec.yaml` : ce sont des données de
test VM, pas des ressources à embarquer dans les applications consommatrices.

Fichiers recommandés :

| Fichier permanent | Taille | SHA-256 du prototype validé | Usage |
|---|---:|---|---|
| `test/assets/fonts/auto_size_metric_roboto_regular.ttf` | 2 660 octets | `893780a2a9c1b15a9ee784b1e34568ff755d3ff9815c9fa755febe303d7bd9c1` | poids `w400`, direction et hauteur |
| `test/assets/fonts/auto_size_metric_roboto_bold.ttf` | 2 632 octets | `bab0b1b36298647122dfaee2e27c0bcb564c43f954be771e90abc94812fafa6d` | poids `w700` |
| `test/assets/fonts/auto_size_metric_naskh_locl.ttf` | 5 212 octets | `d51e94755847f96a7cb9fdd53c91962ec6772a4d6b54c764e05b85e8d987af5a` | substitution localisée arabe/perse |
| `test/assets/fonts/LICENSE-Roboto.txt` | texte | à copier sans modification | Apache-2.0 des deux faces Roboto |
| `test/assets/fonts/LICENSE-NotoNaskhArabic.txt` | texte | à copier sans modification | SIL Open Font License 1.1 |

Les trois binaires totalisent **10 504 octets**. Les tests enregistrent les
deux faces Roboto sous la famille privée `AutoSizeTextMetricRoboto`, et la
face arabe sous `AutoSizeTextMetricNaskh`. Le nom fourni à `FontLoader` est
explicite : aucune résolution d'une police installée sur l'hôte n'intervient.

Les binaires sont des fixtures versionnées et vérifiées par hash. La génération
est une opération de maintenance ponctuelle ; elle ne doit pas être rejouée en
CI et ne doit jamais télécharger une fonte.

## Provenance et génération reproductible

### Roboto regular/bold

Sources présentes dans les deux bundles Flutter exacts :

```text
bin/cache/artifacts/material_fonts/Roboto-Regular.ttf
bin/cache/artifacts/material_fonts/Roboto-Bold.ttf
bin/cache/artifacts/material_fonts/Roboto_LICENSE.txt
```

Les sources ont les mêmes hashes sous 3.41.0 et 3.47.2 :

```text
Roboto-Regular.ttf
79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95

Roboto-Bold.ttf
7d0b991ee3e0be7af01ad7ea8cd2beea6c00a25e679a0226b6737f079aafff86
```

Les prototypes ont été produits avec le `font-subset` de l'engine 3.47.2 en
conservant `(`, `)`, `<`, `>`, `H`, `M` et `g` :

```sh
printf '0x0028 0x0029 0x003C 0x003E 0x0048 0x004D 0x0067\n' |
  font-subset auto_size_metric_roboto_regular.ttf Roboto-Regular.ttf

printf '0x0028 0x0029 0x003C 0x003E 0x0048 0x004D 0x0067\n' |
  font-subset auto_size_metric_roboto_bold.ttf Roboto-Bold.ttf
```

Les tables de poids restent `400` et `700`. Les deux fichiers doivent être
ajoutés ensemble au même `FontLoader` afin que le matching `w400`/`w700` soit
réel. Apache-2.0 autorise cette redistribution et la création de dérivés ; la
copie de la licence et les notices intégrées aux TTF doivent être conservées.

### Noto Naskh Arabic et `locl`

Source officielle déjà utilisée comme ressource de test par l'engine Flutter :

```text
engine/src/flutter/txt/third_party/fonts/NotoNaskhArabic-Regular.ttf
```

Son SHA-256 est identique sous 3.41.0 et 3.47.2 :

```text
6b999662f669b2c9b00c10ce4a110b6f5179c20f3f77e5ccb897e3ab965cf9f5
```

Les enregistrements intégrés déclarent Copyright 2014 Google Inc. et la SIL
Open Font License 1.1, sans Reserved Font Name déclaré. Le fichier est chargé
sous un nom de famille de test différent ; sa notice, le texte complet OFL et
sa provenance doivent rester dans le dépôt et l'archive.

Le prototype validé a été produit avec HarfBuzz 14.2.1 :

```sh
hb-subset \
  --unicodes=066B,066C,06F7 \
  --layout-features=locl \
  --layout-scripts=arab \
  --glyph-names \
  --output-file=auto_size_metric_naskh_locl.ttf \
  NotoNaskhArabic-Regular.ttf
```

La fermeture GSUB par défaut est indispensable : elle conserve notamment
`ThousandsSepFarsi` et `uni06F7.urdu`. Le `font-subset` de l'engine Flutter a
produit un fichier encore plus petit de 4 676 octets, mais a retiré ces
substitutions ; le probe n'observait alors plus aucune différence de locale.
Cette variante est rejetée.

## Préconditions des tests

- Charger les fontes depuis les chemins versionnés, jamais depuis le SDK local,
  le réseau, Google Fonts ou le catalogue système.
- Utiliser des noms de familles privés uniques et appeler `FontLoader.load`
  une seule fois dans `setUpAll`.
- Garder ces tests dans la cible VM actuelle. L'usage de `dart:io` est
  volontairement test-only ; il ne fuit ni dans `lib/` ni dans le manifeste.
- Construire d'abord deux `TextPainter` indépendants et affirmer la divergence
  du témoin. Seulement ensuite comparer le candidat d'`AutoSizeText`,
  `RenderParagraph.textSize`, sa baseline et `didExceedMaxLines`.
- Séparer poids, direction, locale et hauteur en cas distincts. Un cas combiné
  ne permet pas d'attribuer une divergence à la bonne propriété.
- Libérer chaque painter dans un `finally` et conserver les conventions de la
  suite (`group()` et noms commençant par « should »).
- Vérifier les hashes des trois assets lors de leur introduction, puis rejouer
  ces tests sur 3.41.0 et 3.47.2 depuis une archive Git propre.

## Résultats des probes 3.41.0 / 3.47.2

Les métriques suivantes sont identiques bit pour bit sur les deux SDK. Les
valeurs détaillées proviennent des sous-ensembles finaux, pas des fontes
complètes ni du fallback Ahem.

| Témoin à 30 px | Branche A | Branche B | Divergence utile |
|---|---:|---:|---|
| `MMMMMM`, Roboto | `w400`: `Size(157.1, 35.0)` | `w700`: `Size(157.7, 35.0)` | largeur, donc candidat |
| `(`, Roboto | LTR: `10.25390625` | RTL: `10.4296875` | glyph mirroring et largeur |
| `<`, Roboto | LTR: `15.2490234375` | RTL: `15.673828125` | glyph mirroring amplifiable |
| U+066B, Naskh | `ar`: `Size(6.7, 51.0)` | `fa`: `Size(6.0, 51.0)` | substitution `locl` |
| U+066C, Naskh | `ar`: `Size(4.8, 51.0)` | `fa`: `Size(6.7, 51.0)` | substitution `locl`, grand écart |
| U+06F7, Naskh | `ar`: `Size(13.1, 51.0)` | `ur`/`sd`: `Size(12.6, 51.0)` | substitution `locl` |
| `Hg`, Roboto, `height: 3` | comportement par défaut : `Size(38.2, 90.0)`, baseline `71.25` | first ascent et last descent désactivés : `Size(38.2, 35.0)`, baseline `27.83203125` | hauteur, baseline et candidat |

Les quatre blocs ont chacun réussi sur chaque SDK : bold/height, direction,
locale et égalité/hash black-box. Le résultat locale tombe à zéro divergence
avec le sous-ensemble Flutter qui perd `locl`, ce qui valide aussi la
sentinelle du test.

## Tests permanents proposés

### `boldText`

Le témoin métrique doit partir de `w400`, car une famille ne contenant que
regular/bold résout déjà une demande `w900` vers la face disponible la plus
proche. Utiliser `MMMMMM`, taille 30, presets `[30, 29]` et une largeur située
strictement entre les deux largeurs à 30 px. Affirmer avant le widget que
`w400` et `w700` divergent, puis :

1. `boldText: false` conserve le candidat 30 et le poids `w400` ;
2. `boldText: true` porte exactement `FontWeight.bold` (`w700`) et réduit le
   candidat à 29 ;
3. le painter témoin `w700` concorde avec le vrai `RenderParagraph`.

Le cas existant avec une entrée `w900` doit rester comme preuve distincte du
**remplacement exact** par `w700`. Il ne doit plus prétendre être le témoin
métrique. Cette séparation prouve à la fois w400→w700 et la règle
non additive w900→w700 sans ajouter une troisième face w900.

### Direction

Utiliser `<<<<<<`, la face Roboto regular, taille 30, `softWrap: false`,
`maxLines: 1` et les presets `[30, 29]`. Répéter le caractère amplifie le
mirroring `<`→`>` sans introduire de fallback de script. Choisir une largeur
entre les largeurs LTR et RTL à 30 px : LTR conserve 30, RTL descend à 29.

Exercer séparément :

- RTL hérité de `Directionality` avec `textDirection == null` ;
- LTR explicite sous un ancêtre RTL ;
- le cas symétrique explicite RTL sous un ancêtre LTR si la table des quatre
  variantes de l'oracle est conservée.

Le témoin doit comparer les tailles et les line metrics avant de vérifier le
candidat et `RenderParagraph.textDirection`. Une différence de boîtes de
sélection seule est insuffisante : elle ne protège pas le fitter.

### Locale

Utiliser six U+066C, la face Naskh, direction RTL fixée, taille 30, presets
`[30, 26]` et une largeur située entre les témoins `ar` et `fa`. Le glyph
`ThousandsSepFarsi` est sensiblement plus large : `ar` conserve 30 et `fa`
descend à 26.

Exercer séparément :

- locale `fa` héritée de `Localizations`, `AutoSizeText.locale == null` ;
- locale explicite `ar` sous un ancêtre `fa` ;
- locale explicite `fa` sous un ancêtre `ar`.

Pour chaque branche, affirmer d'abord les métriques du painter de locale
opposée, puis le candidat et les métriques du vrai paragraphe. Ne pas mettre la
locale uniquement sur le `TextSpan` témoin : l'oracle concerne ici le locale
effectif du paragraphe.

### `TextHeightBehavior`

Utiliser `Hg`, Roboto regular, `fontSize: 30`, `height: 3`, une hauteur de boîte
60 et les presets `[30, 20]` :

- le comportement par défaut mesure 90 à 30 et doit choisir 20 ;
- `applyHeightToFirstAscent: false` plus
  `applyHeightToLastDescent: false` mesure 35 à 30 et doit conserver 30.

Affirmer taille, baseline alphabétique wet et candidat. Rejouer la même
divergence pour les deux sources de configuration :

1. `DefaultTextStyle.textHeightBehavior` non nul ;
2. `DefaultTextStyle.textHeightBehavior == null`, puis fallback depuis
   `DefaultTextHeightBehavior`.

Ainsi le test protège l'ordre d'héritage et non la seule propriété finale du
render object.

## Égalité/hash du scaler privé sans nouvelle API

Ne pas exposer `_CandidateTextScaler`, ne pas ajouter `@visibleForTesting` et
ne pas importer `lib/src`. Le scaler réellement rendu est déjà observable en
boîte noire par `RenderParagraph.textScaler`.

Ajouter au test une classe source `_PlateauTextScaler(id)` dont
`scale(anything) == 42`, avec égalité/hash fondés sur `id`. Un helper pompe un
`AutoSizeText` vide, force un seul candidat par `presetFontSizes`, puis retourne
le `TextScaler` du `RenderParagraph`.

Capturer les cinq configurations suivantes :

| Cas | source | candidat | référence |
|---|---:|---:|---:|
| base | plateau 1 | 10 | 20 |
| identique | plateau 1 | 10 | 20 |
| source seule différente | plateau 2 | 10 | 20 |
| candidat seul différent | plateau 1 | 15 | 20 |
| référence seule différente | plateau 1 | 10 | 30 |

Affirmer que les cinq scalers rendent 42 pour une même taille d'essai. Malgré
ces sorties identiques, `base == identique` et leurs hashes sont égaux, tandis
que chacune des trois variations isolées est inégale à `base`. Le probe passe
1/1 sur 3.41.0 et 1/1 sur 3.47.2. Une suppression de n'importe lequel des trois
champs de `==` est ainsi détectée sans connaître le type privé.

## Licence et impact d'archive

Les tests sont volontairement conservés dans l'archive pub par la décision du
lot 7. Les fixtures nécessaires à ces tests et leurs licences doivent donc y
rester aussi. Il ne faut ni ignorer seulement les TTF dans `.pubignore`, ce qui
publierait des tests cassés, ni ignorer les licences, ce qui violerait les
conditions de redistribution.

Impact binaire non compressé connu : **10 504 octets**, plus deux petits
fichiers de licence texte. Il est très inférieur aux 342 436 octets des deux
Roboto complets et aux 255 280 octets du Noto complet. Le dry-run final du lot
archive doit ajouter ces cinq entrées à sa liste positive, mesurer la nouvelle
taille compressée et vérifier l'absence de chemins absolus dans les helpers.

Comme les fontes ne figurent pas dans `pubspec.yaml`, elles n'augmentent pas le
bundle d'une application consommatrice. Elles augmentent seulement le dépôt et
l'archive source pub, ce qui est la contrepartie minimale d'une suite publiée
et réellement rejouable.

## Alternatives rejetées

- **Ahem ou `Roboto` nommé sans chargement explicite** : `flutter test` force
  Ahem par défaut ; les poids demandés ont alors les mêmes avances.
- **Comparer w700 à un rendu déjà w700** : preuve circulaire qui ne détecte
  pas un fitter resté en w400 ou w900.
- **Ajouter seulement regular/bold puis utiliser w900 comme témoin métrique** :
  w900 sélectionne déjà la face bold la plus proche. Garder w900 pour la règle
  de remplacement, et w400 pour la divergence métrique.
- **Fontes système, fallbacks thaï/CJK ou locale de la machine** : résultat
  dépendant du système et du contenu installé.
- **Téléchargement Google Fonts ou dépendance dédiée** : réseau, cache et
  résolution externes inutiles pour trois fixtures de 10 Ko.
- **Chemins absolus vers le SDK Flutter** : non rejouables dans l'archive pub
  et incompatibles avec une matrice de SDK indépendante.
- **Versionner les fontes complètes** : 597 716 octets au lieu de 10 504
  octets, sans gain pour les glyphes exercés.
- **Sous-ensemble Noto par `font-subset` Flutter** : retire `locl`; 0
  divergence de locale sur les deux SDK.
- **Boîtes bidi seulement** : elles peuvent prouver une direction de peinture,
  mais pas une décision de fit. Les glyphes miroir Roboto divergent en largeur.
- **Inspection des propriétés de `RenderParagraph` seulement** : prouve le
  rendu final, pas la configuration utilisée pendant la recherche.
- **Un seul scénario direction+locale+height** : une cause peut masquer une
  autre et laisser une branche morte.
- **API de test pour `_CandidateTextScaler`** : surface publique ou interne
  inutile ; `RenderParagraph.textScaler` fournit déjà le point d'observation.

## Verdict borné

Les lacunes de preuve métrique du lot 3 ont une solution permanente,
déterministe et petite. Les témoins proposés divergent réellement et de façon
identique sous Flutter 3.41.0 et 3.47.2. Leur introduction demande uniquement
des assets/helpers/tests et licences test-only ; aucun changement de code
produit ni nouvelle API n'est justifié.
