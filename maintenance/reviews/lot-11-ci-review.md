# Revue finale du lot 11 — CI

Date : 2026-09-02

## Périmètre

- base du correctif final : `9e799ce83900610628978e367c530d116c484db0` ;
- tête auditée : `abb7d1787e8672cdd38d6cab3ec6182a5c71d5c7` ;
- branche de revue : `codex/review-ci-final` ;
- fichiers relus intégralement dans ce diff : `.github/workflows/dart.yml` et
  `maintenance/implementation/lot-11-ci.md`.

Cette passe est limitée à la fermeture du finding sur la propagation des
échecs dans les pipelines dartdoc et Pub. Aucun fichier `lib/**` ou `test/**`
ne change.

## Verdict

PASS. Aucun finding P0, P1 ou P2 ne reste dans le périmètre ciblé.

`defaults.run.shell: bash` est déclaré au niveau racine du workflow, au même
niveau que `jobs`. Il s'applique donc aux onze blocs `run`. Selon la syntaxe
officielle GitHub Actions, ce choix exécute les scripts avec
`bash --noprofile --norc -eo pipefail`, contrairement au shell Linux implicite
qui utilise seulement `bash -e`.

Les onze blocs passent `bash -n`. Deux probes négatifs ont ensuite remplacé
séparément les commandes amont dartdoc et publication à blanc par un faux outil
qui imprime le marqueur de succès attendu puis retourne 17. Sous la commande
GitHub explicite, les deux pipelines retournent 17 : `tee` ne masque plus leur
échec.

## Preuves

| Contrôle | Résultat |
|---|---|
| Niveau YAML de `defaults.run.shell` | racine du workflow, valeur `bash` |
| Nombre de blocs `run` | 11 |
| Validation `bash -n` | 11/11 |
| Probe dartdoc amont | code 17 propagé |
| Probe dry-run Pub amont | code 17 propagé |
| `git diff --check 9e799ce..abb7d17` | propre |

Les commandes dartdoc et publication réelles étaient déjà vertes lors de la
re-review précédente et n'ont pas été rejouées, conformément au périmètre
ultra-ciblé demandé.

## Sécurité et limites

Le diff n'ajoute aucune entrée utilisateur, requête, authentification, session,
permission, secret, opération cryptographique ou nouvel appel externe. Les
risques d'injection, XSS, autorisation, CSRF, course, divulgation et épuisement
de ressources restent hors surface. La logique concernée — le statut de sortie
des pipelines — est vérifiée par les deux probes négatifs. Aucune zone du diff
ciblé n'est restée non vérifiée.
