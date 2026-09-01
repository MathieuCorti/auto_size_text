# Revue du correctif démo/archive S8

Date : 2026-09-02

## Périmètre

- base auditée : `fdfccea60c1f8f4b76c1605933b6bbcfe5c2c947` ;
- correctif audité : `baa9c89fc03e74309487907589c6eeadfe6f9697` ;
- branche de revue : `codex/review-demo-archive-fix` ;
- diff complet : `demo/android/.gitignore` et
  `maintenance/implementation/demo-archive-s8-integration.md` uniquement.

Les deux fichiers modifiés ont été lus intégralement. Aucun fichier `lib/**`,
aucune déclaration Dart et aucune API publique ne changent dans ce diff.

## Verdict

Aucun finding P0, P1 ou P2. Le correctif est conforme au périmètre annoncé.

Les trois wrappers restent suivis avec leurs modes attendus :

- `demo/android/gradle/wrapper/gradle-wrapper.jar` : `100644` ;
- `demo/android/gradlew` : `100755` ;
- `demo/android/gradlew.bat` : `100644`.

`git check-ignore --no-index` ne trouve plus aucune règle applicable à ces
trois chemins. Le diff retire seulement les trois règles qui les masquaient.
Des sondes couvrant chacune des règles restantes confirment que `.gradle`,
`captures`, `local.properties`, `GeneratedPluginRegistrant.java`, `.cxx`,
`key.properties`, `*.keystore` et `*.jks` restent ignorés.

Le journal d'intégration est honnête : avec Dart fourni par Flutter 3.47.2,
`dart pub publish --dry-run` termine avec le code zéro, construit une archive
de 61 KB et rapporte zéro avertissement. La commande était un dry-run ; aucune
publication réelle n'a été lancée.

## Validation

| Contrôle | Résultat |
|---|---|
| `dart pub publish --dry-run` sous Flutter 3.47.2 | code 0, 0 avertissement |
| Analyse fatale de `demo/` sous Flutter 3.47.2 | aucun problème |
| `demo/test/demo_smoke_test.dart` | 4/4 |
| `git diff --check fdfccea..baa9c89` | propre |
| Diff `lib/**` | vide |

Aucun build APK n'a été exécuté : le diff est limité aux règles d'ignore et à
leur journal, conformément au périmètre de cette revue.

## Checklist de sécurité et de logique

Les deux fichiers audités ne traitent ni entrée utilisateur, ni requête, ni
authentification, ni session, ni appel externe d'exécution. Injection, XSS,
authentification, autorisation/IDOR, CSRF, courses, gestion de session,
cryptographie, divulgation d'information et épuisement de ressources sont donc
hors surface. La logique métier pertinente — contenu de l'archive et portée des
exclusions — a été vérifiée sans défaut. Aucune zone du diff n'est restée non
vérifiée.
