# Lot 11 — CI lean

Date : 2026-09-02

Branche : `codex/impl-ci`

Base exacte : `baa9c89fc03e74309487907589c6eeadfe6f9697`

Workflow : `a8b9756` ; le commit suivant contient uniquement ce journal.

## Périmètre livré

Le workflow historique a été remplacé par un unique job matriciel lisible,
sans script auxiliaire. Il s'exécute sur `push`, `pull_request` et à la demande,
avec permissions globales `contents: read`, annulation des exécutions obsolètes,
échec rapide désactivé entre gates et délai maximal de 45 minutes par gate.

La matrice contient exactement quatre entrées :

| Gate | Flutter | Contrôles |
| --- | --- | --- |
| `compat-minimum` | 3.41.0 | résolution naturelle, analyse fatale, tests package, exemple |
| `compat-high` | 3.47.2 | locks canoniques, format, analyse fatale, tests package, exemple |
| `demo` | 3.47.2 | lock forcé, analyse fatale, quatre smoke tests, APK debug |
| `package` | 3.47.2 | fichiers ignorés suivis, publication locale à blanc |

Les actions tierces sont figées sur leurs SHA complets, vérifiés contre les
tags des dépôts officiels :

- `actions/checkout` v6.1.0 :
  `d23441a48e516b6c34aea4fa41551a30e30af803` ;
- `actions/cache` v5.0.5 :
  `27d5ce7f107fe9357f9df03efb73ab90386fccae` ;
- `actions/setup-java` v5.6.0 :
  `03ad4de0992f5dab5e18fcb136590ce7c4a0ac95`.

Le checkout ne conserve aucun credential. Flutter est cloné depuis son dépôt
officiel au tag exact, puis son `HEAD` est comparé au SHA attendu avant toute
commande :

```text
Flutter 3.41.0 • revision 44a626f4f0027bc38a46dc68aed5964b05a83c18
Flutter 3.47.2 • revision d3b14c876900e553bc736ca19295fc09e3853e8e
```

Le cache officiel couvre uniquement le SDK versionné et le cache Pub. Sa clé
inclut OS, architecture, version, révision Flutter et les manifests/locks. Le
SDK restauré est soumis à la même vérification de révision. Java 17 et son
cache Gradle ne sont activés que pour la construction Android de la démo.

## Locks et isolation du minimum

La gate haute emploie `flutter pub get --enforce-lockfile` dans `example/` et
`demo/`. Le lock de l'exemple est canonique pour Flutter 3.47.2 ; il ne doit pas
être réécrit par la validation du plancher.

La gate 3.41.0 extrait donc `git archive HEAD` dans `$RUNNER_TEMP`, déplace le
lock haut de l'exemple dans cette copie et effectue une résolution naturelle.
Le checkout Git reste intact. Chaque gate termine par un contrôle explicite de
`git status --short` vide.

Le contrôle de whitespace compare la base de pull request, ou le `before`
d'un push normal, à `HEAD`. Il est volontairement omis au premier push et au
déclenchement manuel, événements sans plage de commit fiable.

## Validation locale

Les commandes du workflow ont été rejouées sur les deux SDK exacts :

| Contrôle | Flutter 3.41.0 | Flutter 3.47.2 |
| --- | ---: | ---: |
| résolution package | succès naturel en archive | succès `--no-example` |
| analyse fatale `lib test example/main.dart` | aucun diagnostic | aucun diagnostic |
| tests package complets | 143/143 | 143/143 |
| exemple | résolution naturelle, analyse propre | lock forcé, analyse propre |
| format canonique des 42 fichiers ciblés | non applicable | aucun changement |

Sur Flutter 3.47.2, la démo passe son lock forcé, l'analyse fatale, les quatre
tests de `test/demo_smoke_test.dart` et `flutter build apk --debug --no-pub`.
La publication à blanc du package termine avec zéro avertissement et une
archive annoncée de 61 KB. Aucun publish réel n'a été exécuté.

`git ls-files -ci --exclude-standard`, `git diff --check` et la vérification
YAML locale sont verts. Les locks canoniques sont restés byte-identiques :

```text
example/pubspec.lock SHA-1 6ce414e74d7d5b4d7143e1a3cfaa1528127994d9
demo/pubspec.lock    SHA-1 54cae0e3100845d1095cc8dc9a76afaf8d2f0936
```

## Bornes et limites transmises

- aucun fichier `lib/**` ou `test/**` n'est modifié ;
- aucun secret, permission d'écriture, service, badge, Codecov ou étape de
  publication n'est ajouté ;
- la CI distante GitHub n'a pas été déclenchée, puisqu'aucun push n'appartient
  à ce lot ; la syntaxe YAML et toutes les commandes métier ont été validées
  localement, mais le comportement du runner Ubuntu et des restores de cache
  sera confirmé par la première exécution distante ;
- le lot lean n'ajoute ni gate dartdoc ni second scénario de downgrade : la
  résolution naturelle isolée sous le SDK minimum valide le plancher déclaré ;
- aucun merge, push, tag ou publish n'a été effectué.

## Commits

- `a8b9756` — `ci: add pinned Flutter validation matrix` ;
- commit suivant — journal de validation du lot 11.
