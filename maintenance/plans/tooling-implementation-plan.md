# Plan d’implémentation outillage et release

Date du plan : **2026-09-01**

Base : `dev` au commit `8d459dd95c82265b3ae1a59d3fe3ad28a69751bd`.

Ce document décide le contrat de compatibilité, les lots d’outillage et les
gates de publication de la prochaine modernisation d’`auto_size_text`. Il ne
contient aucun correctif. Les constats sources sont les trois audits de
`maintenance/audits/` et leurs revues indépendantes dans
`maintenance/reviews/`.

## Décisions fermes

| Sujet | Décision |
|---|---|
| Prochaine version | **`4.0.0`**, seulement après confirmation du droit de publier `auto_size_text`. La hausse du minimum Flutter/Dart justifie une majeure, même si l’ancien paramètre `textScaleFactor` reste temporairement disponible. |
| Minimum du package | **Flutter `>=3.41.0` et Dart `>=3.11.0 <4.0.0`** dans les trois pubspecs. |
| API de scaling | Ajouter `TextScaler? textScaler`, conserver `double? textScaleFactor` comme compatibilité linéaire dépréciée et interdire de fournir les deux. Ne pas introduire de shim dynamique pour les anciens SDK. |
| Fenêtre testée | Minimum exact déclaré + dernier correctif stable Flutter au moment du changement/release. Au 2026-09-01, la candidate courante vérifiée par les audits est Flutter **3.47.2 / Dart 3.13.2**. Chaque mise à jour de cette pin doit venir de l’archive officielle, jamais d’un canal mutable `stable`. |
| Stable précédente | Job supplémentaire recommandé, non bloquant pour le premier retour au vert. Il devient bloquant seulement si les mainteneurs annoncent explicitement une fenêtre « minimum + précédente + courante ». |
| Démonstrateur | Le conserver dans le dépôt, préserver ses six écrans, le moderniser comme application testée sur la stable courante, mais l’exclure de l’archive pub. `example/` reste l’exemple canonique livré. |
| Couverture externe | Ne pas remettre Codecov dans le chemin critique initial. Produire la couverture localement ; un upload épinglé pourra être ajouté plus tard. |
| Publication | Première release manuelle par un uploader vérifié. OIDC n’est ajouté qu’après validation du publisher, du dépôt canonique, du motif de tag et des protections GitHub. |

### Pourquoi le minimum est 3.41 et non 3.16

`TextScaler` est disponible en stable depuis Flutter 3.16/Dart 3.2. Ce seuil ne
suffit toutefois pas à corriger fidèlement les écarts modernes entre mesure et
rendu confirmés par la revue du cœur. Les propriétés publiques
`MediaQueryData.letterSpacingOverride`, `wordSpacingOverride` et
`lineHeightScaleFactorOverride`, que `Text` applique au rendu, sont absentes du
tag Flutter 3.38.5 et présentes dès le tag stable 3.41.0. Flutter 3.41.0 embarque
Dart 3.11.0.

Le cœur doit lire ces valeurs pour donner aux `TextPainter` exactement les
mêmes métriques qu’au rendu. Rester à 3.16 imposerait des accès `dynamic`, des
branches par version ou une copie fragile de logique framework. Le minimum
3.41.0 est donc le plus petit seuil qui couvre **l’ensemble** des corrections
modernes retenues, et non seulement le type `TextScaler`.

Les contraintes à appliquer sont :

```yaml
environment:
  sdk: '>=3.11.0 <4.0.0'
  flutter: '>=3.41.0'
```

Le package ne promet pas de compatibilité avec les Flutter antérieurs à 3.41.
Les consommateurs qui doivent rester sur ces versions conservent la ligne 3.x
déjà publiée. Aucun backport ne doit être promis sans branche, propriétaire et
matrice dédiés.

## Bloqueurs de release et améliorations souhaitables

### Bloqueurs de `4.0.0`

| ID | Condition bloquante | Preuve d’acceptation |
|---|---|---|
| B0 | Gouvernance établie : droit uploader/admin sur `auto_size_text`/`simc.dev`, dépôt canonique, propriétaires et branche de release confirmés. | Contrôle pub.dev effectué par un propriétaire ; URLs approuvées. En l’absence de droit, arrêter la release. Un nouveau nom de package est un projet de migration séparé. |
| B1 | Les lots release-blocking des plans cœur et layout sont terminés sur le minimum 3.41.0 et la stable courante. | Suites de régression scaling, accessibilité, RichText, groupe, recherche numérique, durée de vie des painters et intrinsics/dry layout vertes selon leurs plans. |
| B2 | Les manifests et l’analyse sont cohérents avec le nouveau minimum ; aucune dépendance discontinue ou contrainte trompeuse. | Résolution, format et `flutter analyze --fatal-infos --fatal-warnings` verts. |
| B3 | `example/` et `demo/` sont résolubles ; la démo ne repose plus sur l’ancien embedding Android ni sur ses deux dépendances visuelles obsolètes. | Résolution/analyse des deux applications, smoke test de démo et build APK debug sur la stable courante. |
| B4 | CI PR/push déterministe, à permissions minimales, sans code réseau non épinglé. | Tous les `uses:` sont des SHA complets ; minimum + stable courante + downgrade passent. |
| B5 | L’archive est volontaire et propre. | Dry-run sans `/maintenance/`, `/demo/`, fichier local, chemin machine, secret potentiel ou wrapper historique ; `example/` et les fichiers package requis restent présents. |
| B6 | Version, changelog, README, documentation API, badges et métadonnées décrivent exactement l’artefact. | `4.0.0`, URLs canoniques, migration SDK/TextScaler documentée, `dart doc --dry-run` vert. |
| B7 | Le commit destiné au tag passe la checklist complète sans changement généré non committé. | Gates de la section « Matrice de validation » exécutés sur le SHA exact à taguer. |

### Souhaitable après le premier retour au vert

- stable précédente dans la matrice obligatoire ;
- Codecov via action et CLI épinglés, avec permissions isolées ;
- publication OIDC pub.dev ;
- Dependabot pour les SHA d’actions et dépendances de développement ;
- `pub outdated` et advisories dans un job planifié qui produit un rapport,
  sans échouer seulement parce qu’une version plus récente existe ;
- renommage homogène de tous les anciens tests et objectif de couverture, sans
  confondre pourcentage et qualité des assertions ;
- `CONTRIBUTING.md`, `CODEOWNERS` et benchmark seulement lorsque des
  propriétaires et processus réels peuvent les maintenir.

## Lots d’implémentation

Chaque lot doit être un diff revuable et garder format, analyse et tests verts à
sa frontière. Les corrections mécaniques de lints ne doivent pas être mêlées
aux changements de layout.

### G0 — Gouvernance et périmètre de release

**Dépendance :** aucune. **Bloque :** métadonnées, tag et publication.

1. Confirmer sur pub.dev un uploader de `auto_size_text` ou un administrateur du
   publisher `simc.dev` ; l’accès au fork GitHub ne vaut pas autorité de
   publication.
2. Faire approuver le dépôt canonique (`simc/auto_size_text`,
   `MathieuCorti/auto_size_text` ou autre décision explicite), son issue tracker,
   les propriétaires des contacts de sécurité et la branche protégée.
3. Confirmer `4.0.0` comme version qui regroupe le relèvement de minimum et les
   corrections cœur. Ne jamais tenter de republier l’immuable `3.0.0`.
4. Conserver `demo/` dans le dépôt mais hors de l’archive. Si cette décision est
   renversée, le demo et son wrapper deviennent des artefacts publiés et tous
   leurs contrôles passent de « application dépôt » à « bloqueurs archive ».

**Fichiers :** aucun tant que les personnes autorisées n’ont pas tranché ; les
valeurs approuvées alimentent ensuite `pubspec.yaml`, `README.md`, les templates
GitHub et la configuration de publication.

### T1 — Contrat SDK, dépendances et lockfiles

**Dépendance :** G0 pour les métadonnées, mais la contrainte SDK peut précéder
les corrections cœur. **Bloque :** migration `TextScaler` et nouvelle CI.

Fichiers principaux : `pubspec.yaml`, `example/pubspec.yaml`,
`demo/pubspec.yaml`, `.gitignore`, les lockfiles imbriqués.

1. Aligner les trois environnements sur Dart `>=3.11.0 <4.0.0` et Flutter
   `>=3.41.0`. Le demo reste seulement **testé** sur la stable courante ; il ne
   définit pas la promesse de support du package.
2. Remplacer `pedantic` par `flutter_lints` dans chaque pubspec autonome qui
   consomme la configuration racine, afin que l’include se résolve aussi depuis
   `example/` et `demo/`. Candidat déjà compatible avec ce plancher :
   `flutter_lints: ^6.0.0` (minimum Dart 3.8). Au moment du diff, vérifier la
   fiche officielle et conserver la dernière majeure qui résout à la fois sur
   Dart 3.11 et la stable courante ; ne pas relever le SDK pour une nouvelle
   majeure de lints.
3. Ne pas ajouter de dépendance d’exécution tierce. Pour les tests de fuite,
   utiliser d’abord les capacités fournies par `flutter_test`. Si une dépendance
   directe à `leak_tracker_flutter_testing` est réellement nécessaire, choisir
   avec `flutter pub add --dev` une plage bornée résoluble sur minimum et
   courante ; `any` est interdit et le downgrade doit passer.
4. Ancrer l’ignore racine à `/pubspec.lock`. Versionner
   `example/pubspec.lock` et `demo/pubspec.lock`, car ce sont des applications
   exécutables autonomes. Choisir pour l’exemple une résolution consommable par
   le minimum et la courante ; générer le lock du demo avec sa stable courante.
   Utiliser ensuite `--enforce-lockfile` dans leurs jobs normaux.
5. Exclure les lockfiles d’applications de l’archive via `.pubignore` ; ils
   restent dans Git pour la reproductibilité des applications du dépôt.

**Validation :** résolution normale et minimale sur Flutter 3.41.0, résolution
normale sur la stable courante, puis analyse des trois packages. Un lockfile qui
ne peut pas être consommé par le job prévu doit être régénéré avec la version
de référence documentée, pas contourné par une mise à jour silencieuse en CI.

### C1 — Corrections cœur modernes

**Dépendance :** T1. **Responsabilité :** plans cœur/layout, pas ce lot
d’outillage. **Bloque :** analyse globale, documentation finale et release.

Le minimum 3.41.0 autorise une implémentation directe de `TextScaler` et des
overrides modernes. Le cœur doit :

- conserver temporairement `textScaleFactor` comme alias linéaire déprécié ;
- appliquer le ratio d’auto-size à chaque taille logique avant le scaler
  utilisateur et utiliser la même configuration pour mesure et rendu ;
- couvrir les overrides de spacing/height, bold, strut, direction, locale,
  `softWrap`/overflow, RichText et groupes ;
- libérer tous les `TextPainter` ;
- conserver constructeurs, `textKey`, `overflowReplacement`, sémantiques,
  presets, groupes et valeurs par défaut ;
- livrer l’architecture intrinsics/dry layout sans mutation du groupe pendant
  une passe spéculative.

Ne pas activer une analyse globale bloquante au milieu d’un commit où les
anciennes API sont encore volontairement présentes. En revanche, aucun ignore
de dépréciation global ne doit survivre à C1.

### T2 — Analyzer, lints, format et harness de tests

**Dépendance :** T1 ; finalisation après C1 pour éviter des diffs mêlés.

Fichiers principaux : `analysis_options.yaml`, fichiers Dart signalés par
l’analyse/format, tests touchés par les corrections.

1. Inclure `package:flutter_lints/flutter.yaml`.
2. Supprimer `strong-mode`, l’ignore `include_file_not_found` et la longue liste
   historique copiée. Configurer les équivalents actuels sous
   `analyzer.language` (`strict-casts`, `strict-inference` et
   `strict-raw-types`) si la résolution minimum les reconnaît.
3. Ne conserver au-dessus du socle officiel que des règles qui expriment une
   convention utile au package, par exemple documentation de l’API publique,
   ordre des directives et locaux finaux. Toute règle doit être reconnue par le
   minimum et ne doit pas nécessiter d’ignore global.
4. Formater une seule fois avec la stable courante et committer ce diff
   mécanique séparément. Le format n’est contrôlé qu’avec cette version, car la
   sortie du formatter peut évoluer entre SDK.
5. Remplacer les deux tests vides (`step_granularity_test.dart` et le cas
   `maxLines == null`) par des assertions qui échouent sur une vraie régression ;
   couvrir le changement d’`AutoSizeGroup` et supprimer ou rendre réel le helper
   de police mort.
6. Pour chaque fichier de tests modifié, utiliser `group()` et des noms
   « should … », sans réécrire toute la suite seulement pour le style.

**Validation :** aucune option inconnue, aucun warning d’include depuis la
racine ou les applications, format propre, analyse fatale et tests verts sur le
minimum et la stable courante.

### T3 — Exemple et démonstrateur maintenables

**Dépendance :** T1 ; peut avancer en parallèle de C1, puis doit adopter l’API
finale avant la documentation.

#### `example/`

- garder l’exemple court et canonique ;
- appliquer les constructions `const` et l’API finale sans ajouter de package
  tiers ;
- résoudre et analyser sur le minimum et la stable courante ;
- conserver son lockfile dans Git, mais pas dans l’archive.

#### `demo/`

- remplacer `bottom_navy_bar` par `NavigationBar`/widgets Material et
  `material_design_icons_flutter` par des icônes Flutter ;
- préserver les six démonstrations et le basculement texte normal/riche ;
- déplacer la configuration `SystemChrome` hors de `build` et utiliser l’API
  actuelle ;
- rendre l’`AutoSizeGroup` de `sync_demo.dart` stable et vérifier `mounted`
  avant de relancer l’animation différée ;
- régénérer le scaffold Android avec la stable courante plutôt que migrer à la
  main : embedding v2, Plugin DSL, Maven Central et niveaux Android supportés ;
- supprimer les anciens scripts/JAR/configurations remplacés, puis versionner
  uniquement le wrapper généré cohérent. Si un wrapper reste, ajouter le
  `distributionSha256Sum` officiel ;
- ajouter un smoke widget test qui ouvre les six destinations, bascule RichText
  et démonte l’écran de synchronisation sans exception ;
- construire un APK debug sur la stable courante. Le demo n’est pas inclus dans
  la matrice de compatibilité minimale du package.

**Risque :** le scaffold Android peut changer fortement sans effet sur la
bibliothèque. Garder son commit distinct et ne pas ajouter de plateforme ou de
dépendance native au pubspec racine.

### T4 — Archive pub déterministe

**Dépendance :** décision G0 sur le demo. **Bloque :** toute publication.

Créer `.pubignore` avec des règles explicites. L’archive doit exclure au
minimum :

- `/maintenance/` ;
- `/demo/` ;
- `/.github/` ;
- `/example/pubspec.lock` ;
- tout `local.properties`, sortie de build, fichier de signature ou secret
  potentiel.

Elle doit conserver `lib/`, `test/`, `example/main.dart`,
`example/pubspec.yaml`, `README.md`, `CHANGELOG.md`, `LICENSE`, `pubspec.yaml` et
`analysis_options.yaml`. Les tests sont un contenu normal de package et ne sont
pas exclus pour gagner quelques kilo-octets.

Le gate conserve la liste complète produite par `flutter pub publish --dry-run`
et échoue si un préfixe interdit apparaît. Il recherche aussi des chemins
machine (`/Users/`, home Windows), clés et fichiers locaux. La taille seule
n’est pas un critère de sûreté.

### T5 — CI minimale et sûre

**Dépendance :** baseline T2/T3 verte. Une CI intermédiaire de tests peut être
introduite plus tôt, mais l’analyse globale ne devient obligatoire qu’une fois
le demo et C1 corrigés.

Remplacer `.github/workflows/dart.yml` par un workflow CI clair (le conserver
sous ce nom ou le renommer en `ci.yml`, puis corriger le badge). Règles :

- déclenchement `pull_request`, `push` sur les branches protégées réellement
  choisies et `workflow_dispatch` ;
- `permissions: contents: read` par défaut, aucune permission d’écriture ;
- `concurrency` par PR/branche avec annulation des runs obsolètes et
  `timeout-minutes` par job ;
- `actions/checkout` et l’action d’installation Flutter fixées à un SHA complet
  provenant du dépôt officiel de l’action, avec le tag humain en commentaire ;
- pour le build Android, JDK/distribution choisis selon la matrice officielle
  du template Flutter/AGP et installés par une action elle aussi fixée à un SHA
  complet ; ne pas dépendre du Java mutable de `ubuntu-latest` ;
- Flutter fixé à un numéro de patch exact, jamais `stable`, et cache indexé par
  version + pubspecs/lockfiles ;
- aucun `curl | bash`, aucun secret dans un job déclenchable depuis une PR ;
- Codecov absent du premier workflow. S’il revient, job isolé, SHA complet,
  CLI téléchargé fixé, fichier de couverture explicite et permissions minimales.

Jobs obligatoires :

| Job | SDK | Gates |
|---|---|---|
| `quality` | stable courante exacte | diff-check entre le SHA de base de la PR (ou le `before` du push) et `HEAD`, format, analyse fatale. |
| `test` | matrice Flutter 3.41.0 + stable courante exacte | résolution racine, `flutter test`; résolution/analyse de `example/`. |
| `downgrade` | Flutter 3.41.0 | `flutter pub downgrade`, puis `flutter test --no-pub`. Ce job prouve les bornes de dépendances ; il ne remplace pas le test du SDK minimum. |
| `demo` | stable courante exacte | locks forcés, analyse, smoke tests, `flutter build apk --debug`. |
| `package` | stable courante exacte | `dart doc --dry-run`, dry-run de publication et assertions de contenu T4. |

Le format et le dry-run ne sont pas dupliqués sur chaque entrée de matrice. La
stable précédente et `pub outdated` peuvent d’abord vivre dans un workflow
planifié ; le résultat d’`outdated` est un rapport à examiner, pas un échec
automatique sur toute nouveauté transitive.

### T6 — Métadonnées, README, changelog et release

**Dépendance :** G0 et API C1 stabilisée. **Bloque :** tag.

Fichiers principaux : `pubspec.yaml`, `README.md`, `CHANGELOG.md`, doc comments
de l’API, `.github/ISSUE_TEMPLATE/*.md`, `.github/FUNDING.yml`, éventuellement
`SECURITY.md` et `.github/no-response.yml`.

1. Passer la version racine à `4.0.0` dans le commit de release. Ajouter
   `repository` canonique ; ne fixer `homepage`/`issue_tracker` qu’avec les URLs
   décidées. Ne pas inventer de publisher dans le pubspec.
2. Ajouter en tête du changelog une section `4.0.0` séparant clairement :
   minimum Flutter/Dart cassant, `TextScaler` et compatibilité de
   `textScaleFactor`, corrections de comportement réellement livrées, démo/CI
   et éventuelles dépréciations. Ne revendiquer aucune issue hors du diff final.
3. Mettre le README en cohérence : badges et liens canoniques, minimum supporté,
   exemple `TextScaler`, ancien facteur marqué déprécié, paramètres publics
   complets, limites et comportements de groupe exacts. Corriger les liens et
   exemples invalides, retirer l’affirmation de performance sans benchmark et
   pointer vers `LICENSE` au lieu de dupliquer la licence.
4. Documenter tous les symboles publics ajoutés ou encore non documentés,
   notamment le constructeur `AutoSizeGroup` et le nouveau paramètre.
5. Retirer les assignees, financements et liens d’ancien mainteneur qui n’ont
   pas été approuvés. Garder `no-response` seulement si l’application est
   installée. Ajouter `SECURITY.md` uniquement avec un canal réellement
   surveillé et les versions supportées.
6. Le badge CI référence le vrai fichier/nom de workflow et la branche
   canonique. Ne pas afficher Codecov tant qu’aucun upload fiable n’existe.

## Matrice de validation et gates de publication

Les commandes exactes peuvent être encapsulées dans des scripts courts si cela
évite une divergence local/CI, mais aucun orchestrateur supplémentaire n’est
nécessaire.

| Gate | Quand | Commande/comportement attendu |
|---|---|---|
| Format | chaque PR, stable courante | `dart format --output=none --set-exit-if-changed lib test example demo/lib` ; zéro fichier à modifier. |
| Analyse | chaque PR, stable courante ; cœur aussi au minimum | `flutter analyze --fatal-infos --fatal-warnings` ; même contrôle dans les applications conservées. |
| Tests | chaque PR, minimum + courante | `flutter test`; tests de régression capables d’échouer, sans dépendance à l’ordre. |
| Dépendances minimales | chaque PR ou merge, minimum | `flutter pub downgrade` puis `flutter test --no-pub`. |
| Exemple | chaque PR, minimum + courante | lock cohérent, résolution forcée et analyse verte. |
| Démo | chaque PR/merge, courante | lock cohérent, analyse, smoke test et APK debug. |
| Documentation | chaque PR/merge, courante | `dart doc --dry-run` sans warning ni erreur. |
| Archive | chaque PR/merge, courante | `flutter pub publish --dry-run`, liste conservée, aucun chemin interdit, warning ou hint. |
| Release | SHA exact du tag | tous les gates précédents, diff-check de la plage livrée, status propre, version/changelog/tag concordants. |

Le dry-run doit notamment perdre le hint actuel sur `<3.0.0`; toute suggestion
nouvelle est évaluée, pas ignorée automatiquement. Les advisories vides ne sont
jamais présentés comme preuve d’absence de vulnérabilité.

## Ordre et dépendances avec le cœur

Ordre de fusion recommandé :

1. **G0** : décisions humaines de publication et dépôt ;
2. **T1** : contrat Flutter 3.41.0/Dart 3.11.0, lints disponibles et politique
   de locks ;
3. **C1** : lots cœur/layout indépendants et leurs tests, sans dette de shim ;
4. **T2** et **T3** : fermeture de l’analyse, harness, exemple et demo ;
5. **T4** et **T5** : archive puis CI complète une fois la baseline verte ;
6. **T6** : documentation/métadonnées basées sur l’API réellement fusionnée ;
7. dry-run final sur le SHA de release, tag `v4.0.0`, publication manuelle par
   l’uploader vérifié, puis contrôle de la page et de la documentation pub.dev.

T3 peut avancer en parallèle du cœur après T1. T4 dépend seulement de la
décision demo, mais son assertion finale attend tous les fichiers de release.
T5 ne doit pas être utilisé pour masquer une baseline rouge par des exclusions
ou `continue-on-error`. T6 vient en dernier afin que README et changelog ne
promettent pas des correctifs encore absents.

## Risques et parades

| Risque | Parade minimale |
|---|---|
| Exclusion des utilisateurs Flutter 3.40 et antérieurs | Majeure 4.0.0, minimum visible dans README/changelog/pubspec, maintien de l’artefact 3.x existant ; aucun shim fragile. |
| `flutter_lints` produit un grand diff | Version compatible fixée, commit mécanique séparé, règles additionnelles rares et justifiées. |
| Le formatter courant crée un résultat différent du minimum | Formater uniquement avec la stable courante ; compiler/analyser/tester le résultat sur le minimum. |
| Lockfiles d’application incompatibles avec une entrée de matrice | Définir la toolchain qui les génère et utiliser `--enforce-lockfile`; ne jamais lancer une mise à jour implicite en CI. |
| Régénération Android masque un changement produit | Commit demo séparé, aucune modification de dépendance/platforme du package racine, smoke test des six écrans. |
| Archive trop agressive | Assertion positive sur les fichiers indispensables en plus des exclusions ; conserver tests et exemple canonique. |
| SHA d’action obsolète ou compromis | Source officielle, SHA complet commenté par tag, revue Dependabot ultérieure ; aucun secret sur PR. |
| `pub downgrade` donne une confiance excessive | Le garder en complément du SDK minimum exact, jamais comme substitut. |
| Documentation préparée avant le code | T6 après stabilisation de l’API et vérification du diff final. |
| Publication sans autorité | B0 est un arrêt absolu ; aucun tag de release ni renommage improvisé. |

## Définition de terminé

Le chantier outillage est terminé lorsque les trois pubspecs expriment le même
contrat 3.41.0/3.11.0, les applications sont résolubles selon leur politique,
la CI sûre fait respecter minimum/courante/downgrade, l’archive ne contient que
les fichiers intentionnels, et les métadonnées `4.0.0` décrivent exactement le
code fusionné. La release elle-même n’est terminée qu’après publication par une
personne autorisée et vérification de l’artefact immuable sur pub.dev.
