# Lot 1 — Cycle de vie des `TextPainter`

Date : 2026-09-01

Branche : `codex/impl-painter-dispose`

Parent exact : `e9f75af9c3ef54bee2cbd3fcc0a53b44e7811968`

Tête : commit contenant ce journal ; SHA final communiqué dans le compte rendu

## Périmètre livré

- le `TextPainter` principal de `_checkTextFits` appartient à la méthode et est
  libéré dans un `finally` après succès, échec au minimum ou exception de
  `layout` ;
- le painter secondaire du chemin `wrapWords: false` a son propre `finally`,
  qui s'exécute aussi avant le retour anticipé d'un mot trop large ;
- les valeurs mesurées sont lues avant le `dispose`, sans changer la recherche,
  les candidats, la taille calculée, le rendu ou l'API ;
- sept tests opt-in couvrent le texte qui tient, l'absence de candidat, le
  retour anticipé, les deux painters du chemin sans wrap, l'exception, les
  rebuilds et le retrait d'un membre de groupe.

## Fichiers

- `lib/src/auto_size_text.dart` ;
- `test/text_painter_lifecycle_test.dart` ;
- `maintenance/implementation/lot-1-painter-dispose.md`.

`test/utils.dart` n'est pas modifié : son helper painter n'est appelé par aucun
test de ce lot. Aucun helper de test supplémentaire ne nécessitait donc un
propriétaire pour établir la preuve produit.

## Preuve rouge sur le parent

Le nouveau fichier de test a d'abord été exécuté avec le code produit inchangé
du parent exact. Le mécanisme est `experimentalLeakTesting` avec
`nativeResourceLeakTesting`, réglage opt-in fondé sur les événements
`FlutterMemoryAllocations`. Il suit `notDisposed` et les stacks de création de
`TextPainter` ; il ne se contente pas de vérifier que l'objet Dart devient
collectable.

Commande complète sur Flutter 3.47.2 :

```sh
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --no-version-check --suppress-analytics test --no-pub \
  --reporter expanded test/text_painter_lifecycle_test.dart
```

Résultat rouge attendu : les sept corps fonctionnels passent, puis
`tearDownAll` échoue avec **20 ressources `TextPainter` `notDisposed`**. Les
stacks pointent sur `_checkTextFits`, et non sur un painter de rendu ou un faux
de test.

Le cas `wrapWords: false` a aussi été isolé :

```sh
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --no-version-check --suppress-analytics test --no-pub \
  --reporter expanded test/text_painter_lifecycle_test.dart \
  --plain-name \
  'should dispose both painters when wrapWords is false and text fits'
```

Résultat rouge attendu : **2 ressources `TextPainter` `notDisposed`**, une
créée au site du painter de mots et une au site du painter principal. Cette
preuve du parent distingue les deux propriétaires à corriger.

## Preuves vertes

Toolchains exactes :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
```

### Flutter 3.47.2

| Commande | Résultat |
|---|---|
| test lifecycle ciblé, reporter expanded | Succès, 7/7 et aucune fuite au `tearDownAll`. |
| suite racine complète, reporter compact | Succès, 32/32 : les 25 tests historiques et les 7 nouveaux tests. |
| analyse scoped `lib test example/main.dart` | Code 1 attendu ; exactement 9 informations historiques `deprecated_member_use`, 0 warning, 0 erreur. |
| `example/` : `pub get --enforce-lockfile` | Succès ; lock canonique haut inchangé. |
| `example/` : analyse fatale `--no-pub` | Succès, aucun diagnostic. |
| format haute des fichiers touchés | Succès, aucun changement après formatage. |

### Flutter 3.41.0

Le commit candidat `b4b3091` a été extrait par `git archive` dans
`/private/tmp/auto-size-text-lot1-min.i2TjFi`. Le lock canonique de l'exemple a
été déplacé avant toute résolution minimum, conformément à la décision de
lock.

| Commande | Résultat |
|---|---|
| `flutter pub get --no-example` | Succès, 26 dépendances résolues naturellement. |
| test lifecycle ciblé, reporter expanded | Succès, 7/7 et aucune fuite au `tearDownAll`. |
| suite racine complète, reporter compact | Succès, 32/32 : résultats historiques inchangés. |
| analyse scoped `lib test example/main.dart` | Code 1 attendu ; les mêmes 9 informations historiques, 0 warning, 0 erreur. |
| `example/` sans lock : `flutter pub get` | Succès, 10 dépendances, dont `meta 1.17.0` et `vector_math 2.2.0`. |
| `example/` : analyse fatale `--no-pub` | Succès, aucun diagnostic. |

Les neuf informations scoped restent celles du lot 0. Les deux nouveaux
`finally` décalent seulement les quatre emplacements aval dans
`lib/src/auto_size_text.dart` ; aucune règle ni occurrence n'est ajoutée.

## Limites et revue

- Le lot ne change ni domaine de candidats, ni scaling, ni configuration de
  paragraphe, ni `RichText`, ni groupe, ni surface publique.
- Le test d'exception utilise un `TextSpan` enfant dont `build` lève
  volontairement un `StateError` pendant `TextPainter.layout`; il vérifie donc
  le `finally` après allocation réelle.
- Les painters qui seront persistants dans la future frontière render restent
  la responsabilité des lots 9 et 10.
- Aucun fichier de démo, CI, packaging, lock ou documentation publique n'est
  modifié.
- La revue indépendante Dart/Flutter ressources reste à effectuer avant merge.
  Aucun merge, push ou changement distant n'a été réalisé par ce lot.
