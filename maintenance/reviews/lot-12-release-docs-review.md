# Lot 12 — re-review finale release et documentation

Date : 2026-09-02

Branche de revue : `codex/review-release-docs-final`

Base du correctif : `b820645366a733edefc6cf1b49af8ae215701b6b`

Tête auditée : `d47887cd258a0f42d8f2005d0b0bca7879ac5ece`

## Verdict

**PASS — aucun finding P0, P1 ou P2.**

Le P2 de métadonnée de la première revue est fermé. Le manifeste désigne le
fork de release exact avec un unique champ `repository`; le dry-run Pub strict
du contenu publiable correspondant retourne zéro avec zéro avertissement. Le
correctif ne modifie ni produit, ni test, ni API, ni archive hors métadonnée.

## Diff relu

Le diff complet `b820645..d47887c` contient exactement deux fichiers, lus
intégralement :

- `pubspec.yaml` ajoute uniquement
  `repository: https://github.com/MathieuCorti/auto_size_text` ;
- `maintenance/implementation/lot-12-release-docs.md` remplace la décision
  temporaire et les résultats du dry-run par les faits corrigés.

`git remote -v` donne :

```text
origin   https://github.com/MathieuCorti/auto_size_text.git
upstream https://github.com/simc/auto_size_text.git
```

La valeur du manifeste est donc l'URL exacte d'`origin`, sans suffixe Git,
forme acceptée par Pub. Aucun champ `homepage` ou `issue_tracker` n'est ajouté
ou inventé. Le journal conserve explicitement `upstream` comme origine amont
distincte et laisse les droits Pub hors de la preuve locale.

## Dry-run Pub strict

Le contenu publiable exact a été validé sous Flutter 3.47.2 / Dart 3.13.2 avec
la commande stricte, sans `--ignore-warnings` :

```sh
flutter --no-version-check --suppress-analytics pub publish --dry-run
```

Résultat :

```text
exit code: 0
Total compressed archive size: 69 KB
Package has 0 warnings.
archive entries: 44
```

La preuve a été exécutée dans une extraction de `b820645` portant uniquement
le correctif `repository`. Son `pubspec.yaml` et celui de `d47887c` ont le même
SHA-256 :
`ad1bf1083e2a27f7d23ef4ebde28b496d7339060248955c2e771aa463c014562`.
Le seul autre changement de `d47887c` est le journal ci-dessus, et
`.pubignore` exclut `/maintenance/`. Le flux d'archive validé est donc
byte-identique au contenu publiable de la tête auditée.

Une nouvelle invocation depuis le worktree de revue a été refusée par la
politique d'exécution de l'environnement malgré `--dry-run`; aucun
contournement n'a été tenté. Cette limitation ne laisse pas d'ambiguïté sur le
contenu local validé, dont l'identité est établie ci-dessus. Elle ne couvre pas
les contrôles supplémentaires éventuels du serveur pub.dev.

## Contrôles locaux

| Contrôle | Résultat |
|---|---|
| `git diff --check b820645..d47887c` | propre |
| analyse `--fatal-infos --fatal-warnings` de `lib test example/main.dart` | zéro diagnostic |
| fichiers du diff | `pubspec.yaml` et journal uniquement |
| `homepage` / `issue_tracker` | absents |
| `repository` | unique, identique à `origin` |
| fichiers suivis mais ignorés | aucun |

Le lock racine, `.dart_tool` et `build` produits par la résolution restent
ignorés. Aucun fichier produit ou test n'est modifié par la revue.

## Checklist sécurité et limites

Les deux fichiers ne traitent aucune entrée utilisateur, requête, base de
données, authentification, autorisation, session, opération cryptographique ou
état concurrent. Injection, XSS, CSRF, IDOR, fuite de secret, race et épuisement
de ressource sont hors surface. La seule opération externe est la validation
Pub en mode dry-run ; aucune publication, écriture distante, balise ou push
n'a eu lieu.

Les droits uploader et les contrôles serveur restent à vérifier par le
processus de release. Ils ne sont ni déduits de l'URL Git ni revendiqués par le
journal.
