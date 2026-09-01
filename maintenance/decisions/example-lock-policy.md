# Politique de lock de l'application `example/`

Date : 2026-09-01  
Base : `2e8d57b214e03697440ed27ce382abcf1a64ad92`

## Verdict

**Conserver un seul `example/pubspec.lock` versionné, généré et forcé avec
Flutter 3.47.2. Tester Flutter 3.41.0 dans une copie temporaire du même SHA,
après avoir déplacé ce lock hors de son nom reconnu, avec une résolution
naturelle non forcée.**

Le lock suivi est le graphe reproductible de l'application maintenue. La
résolution temporaire prouve que son manifeste reste compatible avec le SDK
minimum. Les deux SDK sont réellement testés, sans prétendre qu'ils peuvent
partager un graphe impossible. La racine reste une bibliothèque et ne suit pas
son `/pubspec.lock`; le lock de `demo/` reste gouverné par le lot 6.

## Preuve indépendante

Les bundles exacts Flutter 3.41.0 / Dart 3.11.0 et Flutter 3.47.2 /
Dart 3.13.2 ont été exécutés dans deux copies temporaires du worktree
d'implémentation, sans jamais modifier ce dernier.

| SDK | Contrainte Flutter `meta` | Contrainte `vector_math` | Résolution naturelle de l'exemple |
|---|---:|---:|---|
| 3.41.0 | `1.17.0` | `2.2.0` | `meta 1.17.0`, `vector_math 2.2.0` |
| 3.47.2 | `^1.18.3` | `^2.4.0` | `meta 1.19.0`, `vector_math 2.4.2` |

Les deux contrôles croisés avec `flutter pub get --enforce-lockfile` échouent
comme attendu : Pub annonce `Would change 2 dependencies`, puis
`Unable to satisfy pubspec.yaml using pubspec.lock`. Il n'existe aucune
version commune pour ces deux dépendances dans les contraintes des SDK.

La politique retenue passe : lock haut forcé et analyse fatale verte sous
3.47.2 ; résolution fraîche sans lock et analyse fatale verte sous 3.41.0.

## Fondement officiel

Dart recommande de versionner le lock d'une application, mais pas celui d'un
package réutilisable ([What not to commit](https://dart.dev/tools/pub/private-files#pubspeclock)).
[`pub get --enforce-lockfile`](https://dart.dev/tools/pub/cmd/pub-get#--enforce-lockfile)
échoue si le lock n'est pas une résolution exacte, notamment après un
changement de SDK. [`pub upgrade`](https://dart.dev/tools/pub/packages#upgrading-a-dependency)
est la commande prévue pour régénérer intentionnellement le lock avec les
versions compatibles les plus récentes.

## Options comparées

| Politique | Verdict | Motif |
|---|---|---|
| Lock canonique haut + résolution minimum en copie | **Retenue** | Un lock d'application versionné, usage courant reproductible et vraie résolution minimum sans mutation du dépôt. |
| Lock minimum + résolution haute en copie | Rejetée | Le lock canonique serait inutilisable avec la toolchain courante qui maintient l'application. |
| Aucun lock | Rejetée | Perd les mises à jour transitives explicites et contredit la politique d'application déjà décidée. |
| Deux locks et copie vers `pubspec.lock` | Rejetée | Pub ne reconnaît qu'un lock ; le second ajoute une convention et un risque de dérive inutiles. |
| `dependency_overrides` | Rejetée | Ne crée aucune intersection, teste un graphe artificiel et peut forcer une version hors des contraintes Flutter. |

## Correction normative du lot 0

Toute exigence demandant que le lock de l'exemple passe
`--enforce-lockfile` sur les deux SDK est remplacée par :

1. Générer et versionner `example/pubspec.lock` avec Flutter 3.47.2 via
   `flutter pub upgrade`.
2. Forcer ce lock et analyser l'exemple sous 3.47.2.
3. Sous 3.41.0, extraire le commit du lot dans `mktemp`, déplacer le lock de
   cette copie, puis résoudre et analyser naturellement l'exemple.
4. Exécuter les tests racine et l'analyse scoped du lot sur les deux SDK. Les
   commandes racine utilisent `--no-example` afin de garder la politique de
   l'exemple explicite.
5. Vérifier que le worktree canonique reste propre. Le lock minimum temporaire
   n'est jamais copié ni committé.

Génération du lock canonique :

```sh
cd example
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --no-version-check --suppress-analytics pub upgrade
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --no-version-check --suppress-analytics pub get --enforce-lockfile
/private/tmp/flutter-sdk-3.47.2/flutter/bin/flutter \
  --no-version-check --suppress-analytics \
  analyze --fatal-infos --fatal-warnings
cd ..
```

Validation du minimum sur la tête déjà committée du lot :

```sh
minimum_tree="$(mktemp -d /private/tmp/auto-size-text-minimum.XXXXXX)"
git archive --format=tar HEAD | tar -xf - -C "$minimum_tree"
mv "$minimum_tree/example/pubspec.lock" \
  "$minimum_tree/example/pubspec.lock.canonical-high"

cd "$minimum_tree"
/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --no-version-check --suppress-analytics pub get --no-example
/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --no-version-check --suppress-analytics test --no-pub --reporter compact

cd "$minimum_tree/example"
/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --no-version-check --suppress-analytics pub get
/private/tmp/flutter-sdk-3.41.0/flutter/bin/flutter \
  --no-version-check --suppress-analytics \
  analyze --fatal-infos --fatal-warnings
```

L'analyse scoped racine avec son allowlist exacte reste celle prescrite par la
revue finale et s'exécute aussi dans `$minimum_tree`. La pin haute exécute les
mêmes contrôles dans le worktree canonique avec `pub get --no-example`, puis
valide séparément le lock de l'exemple. Après le commit et tous les contrôles :

```sh
git status --short
```

La sortie doit être vide.

## Correction normative du lot 11

Le job `compat` conserve sa matrice 3.41.0 + 3.47.2, mais différencie les
étapes de l'exemple :

- 3.47.2 utilise le checkout normal et force le lock suivi ;
- 3.41.0 exécute toute sa résolution dans une extraction temporaire sans le
  lock canonique ;
- aucune entrée minimum ne lance un `pub get` non forcé dans le checkout ;
- `downgrade` reste un job séparé et ne remplace aucune entrée de compatibilité.

Chemin haut, après installation de Flutter 3.47.2 exact :

```sh
flutter pub get --no-example
flutter analyze --fatal-infos --fatal-warnings
flutter test --no-pub

cd example
flutter pub get --enforce-lockfile
flutter analyze --fatal-infos --fatal-warnings
cd ..
git status --short
```

Chemin minimum, après installation de Flutter 3.41.0 exact :

```sh
minimum_tree="$(mktemp -d)"
git archive --format=tar HEAD | tar -xf - -C "$minimum_tree"
mv "$minimum_tree/example/pubspec.lock" \
  "$minimum_tree/example/pubspec.lock.canonical-high"

cd "$minimum_tree"
flutter pub get --no-example
flutter analyze --fatal-infos --fatal-warnings
flutter test --no-pub

cd "$minimum_tree/example"
flutter pub get
flutter analyze --fatal-infos --fatal-warnings
```

Le workflow vérifie ensuite `git status --short` depuis le checkout canonique ;
la sortie doit être vide. `flutter` désigne toujours la version exacte de
l'entrée de matrice, jamais le canal mutable `stable`.

## Critère d'acceptation corrigé

Le gate est vert si le lock haut est forcé sans changement sous 3.47.2, si le
manifeste obtient une résolution et une analyse vertes sous 3.41.0 dans la
copie, si les contrôles racine passent sur les deux SDK, si le checkout reste
propre et si aucune preuve ne prétend qu'un même graphe a servi aux deux SDK.
