# Revue indépendante du plan outillage et release

Date de la revue : **2026-09-01**

Plan revu : `maintenance/plans/tooling-implementation-plan.md`, commit
`ee6f891a2d1e403141d2b049c95492a9367016cf`.

Base produit et documentaire : `dev`, commit
`8d459dd95c82265b3ae1a59d3fe3ad28a69751bd`.

Périmètre : contrat Flutter/Dart, lints et manifests, matrice CI, exemple et
démonstrateur, archive, versionnement et gates de publication. Aucun code ni
correctif produit n'est inclus dans cette revue.

## Verdict

Le plan est **accepté sous modifications obligatoires**.

Ses choix structurants sont justes : `4.0.0`, minimum Flutter 3.41.0/Dart
3.11.0 pour la bibliothèque modernisée, migration additive vers `TextScaler`,
maintien temporaire de `textScaleFactor`, démo conservée dans Git mais exclue
de l'archive, exemple canonique livré, CI à SHA complets, publication initiale
manuelle et arrêt absolu sans droit pub.dev.

Quatre corrections matérielles sont toutefois nécessaires avant de traiter le
document comme feuille de route exécutable :

1. Flutter 3.47.2/Dart 3.13.2 est la stable de référence au jour du plan, mais
   elle n'a été exécutée par aucun audit et n'est pas installée dans les SDK
   locaux contrôlés. Le plan ne doit pas la qualifier de candidate « vérifiée ».
2. Le contrat public 3.41.0/3.11.0 doit être celui du package et de l'exemple
   validé sur ce minimum. Le démonstrateur régénéré avec la stable courante ne
   peut annoncer le même minimum que s'il est réellement validé dessus ; sinon
   son propre pubspec doit déclarer le minimum de sa toolchain de régénération.
3. Un `.pubignore` racine remplace le `.gitignore` pour la publication. Il doit
   donc reprendre les exclusions nécessaires, notamment `/pubspec.lock`, et
   pas seulement ajouter `/maintenance/`, `/demo/` et `/.github/`.
4. La CI décrite doit analyser le cœur avec Flutter 3.41.0 en plus de le tester.
   Les sections T2 et « Matrice de validation » l'exigent, mais le tableau des
   jobs T5 ne le fait pas explicitement.

Ces corrections ne justifient ni shim dynamique, ni branche de code par SDK,
ni nouvel orchestrateur.

## Preuves contrôlées

### Flutter 3.41.0 et nécessité des overrides `MediaQuery`

Le minimum proposé est confirmé.

- L'[archive officielle Flutter](https://docs.flutter.dev/install/archive)
  associe le tag stable **3.41.0**, ref `44a626f`, à **Dart 3.11.0**. Le tag
  exact est présent dans le dépôt Flutter local.
- Les sources des tags locaux montrent que
  `MediaQueryData.lineHeightScaleFactorOverride`, `letterSpacingOverride` et
  `wordSpacingOverride` sont absents de 3.38.5 et présents dans 3.41.0. Le
  changement Flutter [`36b1877`](https://chromium.googlesource.com/external/github.com/flutter/flutter/+/36b18770737e52b0b504da38659dceb3964b4934)
  est contenu dans 3.41.0, mais pas dans 3.38.10 ; 3.41.0 est donc le premier
  tag stable qui l'embarque.
- Dans `Text.build` au tag 3.41.0, Flutter lit ces trois valeurs, applique les
  overrides récursivement au `TextSpan` et fusionne l'override de hauteur dans
  le `StrutStyle`. La documentation publique confirme que
  [`letterSpacingOverride`](https://api.flutter.dev/flutter/widgets/MediaQueryData/letterSpacingOverride.html)
  affecte `Text`, et que
  [`lineHeightScaleFactorOverride`](https://api.flutter.dev/flutter/widgets/MediaQueryData/lineHeightScaleFactorOverride.html)
  affecte à la fois `TextStyle.height` et `StrutStyle.height`.
- La revue du cœur a reproduit un overflow causé par
  `letterSpacingOverride` et un faux positif de fit causé par le strut. Ces
  valeurs ne sont donc pas une parité d'API facultative : elles font partie
  des corrections de mesure/rendu déjà retenues.

Une option Flutter 3.16/Dart 3.2 resterait suffisante pour le seul type
`TextScaler`, mais pas pour la parité moderne retenue. Sur 3.16, accéder à ces
valeurs demanderait un appel `dynamic`, une duplication de logique privée ou
l'omission volontaire d'un défaut reproduit. Faire mesurer successivement un
véritable enfant `Text` pourrait théoriquement déléguer les overrides au
framework, mais ne constitue pas une alternative simple pour la recherche de
taille, les intrinsics et le dry layout : le render object ne peut pas rebâtir
un `Text` à chaque candidat pendant une passe spéculative. Cette voie ajoute
plus de risque architectural que le relèvement de minimum.

Conclusion : **conserver Flutter `>=3.41.0` et Dart
`>=3.11.0 <4.0.0` pour la bibliothèque**, sans shim. Les critères
d'acceptation doivent rester formulés en comportement — mesure et rendu
identiques — afin de ne pas imposer inutilement une copie de l'implémentation
privée de `Text`.

### Stable courante et SDK disponibles

La référence **Flutter 3.47.2 / Dart 3.13.2** est cohérente avec le
[tracker de release Flutter 3.47.2](https://github.com/flutter/flutter/issues/191758)
et les informations de la stable publiée. Elle reste une pin externe à
revalider dans l'archive officielle au moment du diff et de la release.

Les SDK contrôlés localement sont 3.38.5, 3.41.4, 3.41.6 et 3.44.0, entre
autres. Flutter 3.41.4 embarque Dart 3.11.1 et 3.41.6 Dart 3.11.4. Les sources
du tag exact 3.41.0 sont disponibles, mais son bundle exécutable ne l'est pas ;
3.47.2 n'est pas installé non plus. Les audits indiquent eux-mêmes que 3.47.2
n'a pas été exécuté.

La preuve de source suffit à choisir le contrat, pas à déclarer la matrice
verte. Avant fusion du lot T1/C1, la CI doit donc exécuter **le bundle exact
3.41.0**, puis la pin courante exacte ; un correctif 3.41.x ne remplace pas le
minimum déclaré.

### `TextScaler` et compatibilité de `textScaleFactor`

Le plan suit la bonne stratégie. Le
[guide de migration officiel](https://docs.flutter.dev/release/breaking-changes/deprecate-textscalefactor)
confirme qu'un `double` ne représente pas un scaling non linéaire et que
`TextScaler.textScaleFactor` n'est qu'une estimation de compatibilité.

La signature actuelle de
[`Text`](https://api.flutter.dev/flutter/widgets/Text/Text.html) conserve les
deux paramètres, déprécie `textScaleFactor` et vérifie leur exclusion mutuelle.
`Text.build` choisit le scaler explicite, sinon convertit l'ancien facteur en
`TextScaler.linear`, sinon utilise `MediaQuery.textScalerOf`.

Le contrat final recommandé est donc :

- ajouter `TextScaler? textScaler` aux deux constructeurs ;
- conserver `double? textScaleFactor`, annoté déprécié ;
- refléter l'exclusion mutuelle de `Text` ;
- priorité : scaler explicite, ancien facteur linéaire, scaler ambiant ;
- appliquer le ratio d'auto-size à chaque taille logique **avant** le scaler
  utilisateur, pour le texte simple comme pour chaque run riche ;
- utiliser la même configuration effective pour mesure, rendu, groupe, strut
  et placeholders.

La compatibilité de source de l'ancien paramètre est ainsi maintenue pour les
consommateurs déjà sur un SDK compatible. Le package ne promet en revanche pas
de compiler sur Flutter antérieur à 3.41.

### Version `4.0.0`

Le choix est accepté. La version publique la plus récente est bien
[`auto_size_text 3.0.0`](https://pub.dev/packages/auto_size_text/versions),
propriété du publisher `simc.dev`. Pub demande de suivre le
[versionnement sémantique](https://dart.dev/tools/pub/versioning), et une
version publiée est immuable.

Le nouveau minimum exclut des consommateurs de la ligne 3.x et les correctifs
de parité peuvent modifier les tailles effectivement rendues. Même si
`textScaleFactor` reste disponible, `4.0.0` est donc le niveau prudent et
correct. Il ne doit être écrit dans le pubspec de release et tagué qu'après
confirmation de l'uploader, du dépôt canonique et du contenu réellement livré.

### Pubspecs, lints et lockfiles

`flutter_lints: ^6.0.0` n'est pas une version inventée :
[l'API pub.dev](https://pub.dev/api/packages/flutter_lints) la donne comme
version courante, publiée par `flutter.dev`, avec un minimum Dart `^3.8.0`.
Elle est donc résoluble sous Dart 3.11 et Dart 3.13. L'include officiel est bien
`package:flutter_lints/flutter.yaml`.

La dépendance doit être directe dans chaque package autonome dont
`analysis_options.yaml` l'inclut. Le plan a raison de ne pas ajouter de
dépendance runtime. Flutter 3.41 expose déjà le paramètre expérimental de leak
tracking via `flutter_test`, qui dépend lui-même de
`leak_tracker_flutter_testing`. Si les tests doivent importer `LeakTesting`
directement, cette dépendance doit être déclarée explicitement ; sa contrainte
doit être choisie par `flutter pub add --dev` sous le SDK minimum et vérifiée
sur la courante, pas recopiée d'une PR ni fixée à `any`.

La politique de lockfiles est correcte sous cette réserve : selon la
[règle officielle](https://dart.dev/tools/pub/private-files), une bibliothèque
ne commite pas son lockfile, tandis qu'une application le commite. Il faut donc
ignorer seulement `/pubspec.lock`, suivre `example/pubspec.lock` tant que
`example/` reste une application autonome et suivre `demo/pubspec.lock` tant
que la démo est maintenue. Le lock de l'exemple doit être généré avec une
résolution consommable par 3.41.0, puis accepté par la courante avec
`--enforce-lockfile`; le lock de la démo est généré avec sa toolchain déclarée.

Correction de cohérence : les trois pubspecs n'ont pas à annoncer
artificiellement le même minimum.

- `pubspec.yaml` et `example/pubspec.yaml` : Dart
  `>=3.11.0 <4.0.0`, Flutter `>=3.41.0`, testés sur minimum et courante.
- `demo/pubspec.yaml` : soit le même contrat, mais alors résolution, analyse,
  smoke test et build doivent être prouvés sur 3.41.0 ; soit, option
  recommandée et plus honnête, le minimum exact de la stable qui régénère le
  scaffold, avec validation uniquement sur cette ligne. La démo n'étend pas la
  promesse de compatibilité de la bibliothèque.

### Exemple, démonstrateur et archive

Le découpage est accepté : `example/` reste court, canonique et publié ;
`demo/` reste une application de dépôt avec six destinations, mais sort de
l'archive. Puisque le projet choisit de continuer à maintenir cette démo, sa
résolution, son analyse, son smoke test et son APK debug peuvent légitimement
bloquer le retour global au vert. Un build debug ne nécessite pas de certificat
de signature de release.

La création d'un `.pubignore` est obligatoire, mais le plan doit intégrer la
règle officielle : selon la
[documentation de publication](https://dart.dev/tools/pub/publishing), un
`.pubignore` remplace le `.gitignore` présent dans le même répertoire.
L'implémentation doit donc exclure explicitement au minimum :

- `/.dart_tool/`, `/build/`, `/doc/api/` et `/pubspec.lock` ;
- `/maintenance/`, `/demo/` et `/.github/` ;
- `/example/pubspec.lock` ;
- fichiers IDE, sorties de couverture, propriétés locales, clés, signatures
  et sorties plateforme/build qui pourraient exister au moment du dry-run.

Le gate doit aussi affirmer la présence de `lib/`, `test/`, `example/main.dart`,
`example/pubspec.yaml`, README, changelog, licence, pubspec et options
d'analyse. Garder les tests dans l'archive est normal. Lister seulement la
taille ou supposer qu'un fichier ignoré par Git le sera encore par Pub n'est pas
suffisant.

### CI, versions et SHA

Les règles de sûreté sont acceptées. GitHub indique qu'un
[SHA complet est la seule référence immuable d'une action](https://docs.github.com/en/actions/reference/security/secure-use),
et permet d'imposer cette politique au niveau du dépôt. Le plan a raison de ne
pas inventer maintenant des SHA d'actions, une version d'AGP, de Gradle ou de
JDK : ces valeurs doivent être prises, au moment du lot, dans les dépôts
officiels et dans le scaffold produit par la pin Flutter retenue, puis
committées et commentées par leur tag lisible.

La matrice finale doit rendre explicites les jobs suivants :

| Job | Toolchain | Gates obligatoires |
|---|---|---|
| `quality` | courante exacte | `git diff --check` sur une plage réellement disponible, format, analyse fatale racine ; checkout avec profondeur suffisante pour la plage. |
| `compat` | 3.41.0 exacte + courante exacte | `flutter pub get`, analyse fatale racine, tests ; résolution et analyse de l'exemple avec lock forcé. |
| `downgrade` | 3.41.0 exacte | `flutter pub downgrade`, puis tests `--no-pub`. |
| `demo` | minimum propre à la démo/courante exacte | lock forcé, analyse, smoke test, APK debug. |
| `package` | courante exacte | dartdoc, dry-run, assertions positives et négatives d'archive. |

La plage du `diff-check` doit être définie par événement et les commits doivent
être disponibles : base de PR à `HEAD`, `before` à `HEAD` pour un push normal,
avec traitement explicite du premier push ou du SHA nul. À défaut, supprimer ce
contrôle de plage plutôt que conserver un gate qui ne voit aucun diff. Le
format porte sur l'arbre complet et ne dépend pas de cette plage.

`flutter analyze --fatal-infos --fatal-warnings` est reconnu par Flutter 3.41.
Le package doit l'exécuter sur le minimum, car tester seul ne garantit ni que
tous les fichiers sont visités, ni que les options analyzer sont comprises par
la borne basse. La démo n'a pas à être dupliquée dans cette entrée si son
pubspec déclare une toolchain plus récente.

Le workflow PR/push n'a besoin d'aucun secret applicatif. Il utilise seulement
le `GITHUB_TOKEN` automatique avec `contents: read`. Codecov et toute action
réseau non indispensable restent hors du chemin critique initial.

## Corrections obligatoires à appliquer au plan d'exécution

### C1 — Corriger le statut des deux pins Flutter

Remplacer toute formulation laissant entendre que 3.47.2 a déjà passé la suite
par : « pin stable courante officielle à exécuter ». Installer et exécuter
3.41.0 et la courante exacte avant de fermer T1/C1. Les correctifs 3.41.4 ou
3.41.6 contrôlés localement sont des preuves complémentaires, pas le minimum.

### C2 — Séparer contrat public et toolchain de démo

Appliquer 3.41.0/3.11.0 à la racine et à l'exemple. Pour la démo, choisir une
des deux politiques testables énoncées plus haut. La recommandation est de
déclarer le minimum de la stable ayant régénéré le scaffold et de ne la tester
que sur cette toolchain, afin d'éviter une promesse Android non vérifiée.

### C3 — Compléter `.pubignore`

Construire le fichier à partir des exclusions nécessaires du `.gitignore`,
puis ajouter les exclusions de release. Vérifier explicitement
`/pubspec.lock`, répertoires générés, maintenance, démo et lock imbriqué de
l'exemple. Le dry-run doit enregistrer la liste complète et faire échouer les
assertions de contenu.

### C4 — Rendre l'analyse minimale explicite en CI

Ajouter l'analyse fatale racine à l'entrée Flutter 3.41.0 du job de
compatibilité. Conserver format et dartdoc une seule fois sur la courante. Le
job downgrade reste complémentaire et ne remplace pas cette analyse.

### C5 — Rendre le diff-check exécutable

Définir les SHA par événement et la profondeur de checkout, ou omettre le
contrôle de plage. Ne jamais utiliser un `git diff --check` sans plage sur un
checkout CI propre, car il ne vérifierait aucun commit livré.

### C6 — Ne fixer les versions externes qu'avec leur preuve

Conserver `flutter_lints ^6.0.0`, déjà vérifié. Résoudre au moment de
l'implémentation les SHA complets des actions, les versions JDK/AGP/Gradle et
le checksum de distribution Gradle depuis leurs sources officielles. Vérifier
la pin stable Flutter dans l'archive le jour du diff et de la release. Aucun
numéro approximatif ne doit être ajouté au plan.

## Plan final recommandé

| Lot | Résultat attendu | Dépendance | Credentials |
|---|---|---|---|
| G0 — Gouvernance | Uploader/admin pub.dev, dépôt canonique, branche, contacts, politique démo et version 4.0.0 confirmés. | Aucune | **Oui** : session pub.dev autorisée et droits d'administration GitHub pour vérifier/configurer les réglages. |
| T1 — Contrats et dépendances | Pubspec racine/exemple à 3.41.0/3.11.0 ; contrat démo propre ; `flutter_lints ^6.0.0` ; locks ciblés ; résolution sur pins exactes. | Décision de périmètre G0, sauf essais locaux | Non pour modifier/tester ; réseau public requis pour résoudre. |
| C1 — Correctifs cœur | TextScaler composé, parité effective Text/MediaQuery/strut, RichText, groupes, painters, recherche et architecture intrinsics/dry layout selon les plans produit. | T1 | Non. |
| T2 — Analyzer et tests | Configuration moderne, format courant, analyse minimum+courante, tests réellement régressifs, leak tracking borné si nécessaire. | T1, fermeture après C1 | Non. |
| T3 — Exemple et démo | Exemple canonique résolu/analysé sur minimum+courante ; démo sans dépendances UI historiques, scaffold régénéré, six destinations, smoke test et APK debug. | T1 ; API finale avant documentation | Non ; aucun keystore pour un APK debug. |
| T4 — Archive | `.pubignore` complet, assertions positives/négatives et dry-run propre. | Politique démo G0, contenu T1-T3 stabilisé | Non ; le dry-run ne publie rien. |
| T5 — CI | Actions à SHA complet, permissions minimales, pins exactes, jobs quality/compat/downgrade/demo/package verts. | Baseline T2/T3 verte | Aucun secret utilisateur ; `GITHUB_TOKEN` automatique en lecture seule. |
| T6 — Métadonnées | README, changelog, API, badges, templates et URLs conformes au diff final. | G0 et API stabilisée | Non pour les fichiers ; droits GitHub requis pour protections, apps ou environments. |
| R1 — Release | Gates rejoués sur le SHA exact, arbre propre, tag `v4.0.0`, publication manuelle puis contrôle de l'artefact immuable. | B0 à B7 | **Oui** : identité OAuth/pub.dev d'un uploader ou admin autorisé. |
| R2 — OIDC optionnel | Workflow tag-only, repository/tag pattern exacts, environnement protégé, `id-token: write` limité au job. | Première release et gouvernance éprouvée | **Oui pour la configuration** pub.dev/GitHub ; aucun secret longue durée ensuite. |

La publication OIDC ultérieure suit la
[documentation officielle](https://dart.dev/tools/pub/automated-publishing) :
elle exige un package existant, un uploader ou admin, un dépôt et un motif de
tag configurés, puis un workflow déclenché par tag. Elle ne doit pas être
simulée par un token permanent. Les commandes de format, analyse, tests,
dartdoc, build debug et dry-run n'exigent pas de credentials de publication.

## Gates de release finales

Une `4.0.0` est autorisée uniquement si :

1. le droit de publier et l'identité canonique sont confirmés ;
2. les bundles exacts 3.41.0 et stable courante ont passé la compatibilité ;
3. le package est analysé/testé et l'exemple résolu/analysé au minimum ;
4. la démo passe sa propre toolchain déclarée ;
5. toutes les actions sont à SHA complet et aucune PR n'accède à un secret ;
6. l'archive exclut maintenance, démo, locks, sorties générées et données
   locales, tout en conservant code, tests, exemple et documents requis ;
7. version, changelog, README, API, tag et dépôt canonique concordent ;
8. les gates sont rejoués sur le SHA exact, sans génération non committée ;
9. la publication est faite par l'uploader vérifié, puis la version et la
   documentation pub.dev sont contrôlées.

## Inventaire, sûreté et limites

Les documents suivants ont été lus intégralement :

- `maintenance/plans/tooling-implementation-plan.md` ;
- les trois audits dans `maintenance/audits/` ;
- les trois revues antérieures dans `maintenance/reviews/` ;
- `pubspec.yaml`, `example/pubspec.yaml`, `demo/pubspec.yaml`, `.gitignore`,
  `analysis_options.yaml`, `.github/workflows/dart.yml` et les manifests
  Android de démo directement concernés.

Les sources Flutter 3.38.5, 3.41.0, 3.41.4, 3.41.6 et 3.44.0 ont été comparées
sur `MediaQuery`, `Text`, `TextPainter`, le test de fuite et la commande
d'analyse. Les contraintes `flutter_lints`, Pub, lockfiles, archive, OIDC et
SHA GitHub ont été vérifiées dans les sources officielles citées.

Checklist sécurité : le seul risque exécutable du plan est la supply chain CI
et publication ; les mesures SHA complet, permissions minimales, absence de
secret sur PR et arrêt sans autorité sont correctes après C1-C6. Injection,
XSS, CSRF, auth applicative, IDOR, sessions, SQL et cryptographie sont hors
surface pour ce widget local et ce document. Aucun secret n'a été trouvé dans
le worktree revu.

Non vérifié par exécution : bundle Flutter 3.41.0 exact, Flutter 3.47.2,
résolution après modifications, scaffold Android régénéré, paramètres GitHub,
installation Probot/Codecov, protections de branche et rôles pub.dev. Ces
éléments sont des gates explicites ; ils ne doivent pas être transformés en
affirmations avant leur exécution par les lots responsables.
