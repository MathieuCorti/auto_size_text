# Revue finale de la feuille de route d’implémentation

Date : 2026-09-01

Feuille de route revue : `maintenance/implementation-roadmap.md`, commit
`b845bab2a31c66ff00ae28c5fa7bad3576af250f`.

Base produit et documentaire : `dev`, commit
`d0fe48d60715ec749f9a1761416abc1b6f368dcf`.

Périmètre : couverture des findings, ordre et dépendances des treize lots,
parallélisme, critères d’acceptation, gates, stratégie de revert et aptitude à
préparer une release de production. Aucun code produit, test, manifeste ou
workflow n’a été modifié par cette revue.

## Verdict

**ACCEPTÉ SOUS SEPT CORRECTIONS OBLIGATOIRES.**

Le fond technique est bon. Les onze findings CORE, les quatorze bugs amont
retenus et la maintenance de démo sont tous couverts. Les demandes #80/#81,
#151 et les autres fonctionnalités ou cas non reproduits restent correctement
hors du périmètre. Le découpage en treize lots n’est pas artificiel : chaque
séparation isole soit une cause racine, soit une surface de conflit, soit une
gate de faisabilité qui exige une revue indépendante.

La séquence SDK → cœur → prototype/layout → CI → documentation/release est
également correcte. Le lot 8 est bien une porte d’architecture, pas une
formalité, et les lots 9/10 ne peuvent pas être intégrés si le prototype échoue.

La feuille de route n’est toutefois pas directement exécutable sur trois
points matériels : ses repères Git ne peuvent plus garder la définition donnée
si les lots 6/7 sont mergés tôt, ses gates d’analyse ne distinguent pas la
racine encore polluée par la démo de la piste cœur, et le benchmark demandé par
la Gate Architecture n’a pas de lot propriétaire. Les quatre autres
corrections ci-dessous rendent explicites des conditions de production déjà
présentes de façon partielle.

Cette revue constitue l’annexe normative de la feuille de route. En cas de
divergence sur les sept sujets ci-dessous, les corrections de cette revue
prévalent avant toute implémentation.

## Preuve SDK incorporée

La cible minimale n’est plus une extrapolation fondée seulement sur les sources
ou sur Flutter 3.41.6.

Preuve indépendante : `maintenance/verification/sdk-floor.md`, commit
`d295fe4` (`docs: verify Flutter SDK floor`). Ce rapport a été lu intégralement
depuis sa branche avant finalisation de la présente revue.

- Le manifeste officiel macOS au 2026-09-01 associe Flutter 3.41.0
  (`44a626f4f0027bc38a46dc68aed5964b05a83c18`) à Dart 3.11.0 et Flutter
  3.47.2 (`d3b14c876900e553bc736ca19295fc09e3853e8e`) à Dart 3.13.2.
- Les archives ARM64 ont été téléchargées et leurs SHA-256 vérifiés avant
  exécution :
  `24aa98db60e36b1dad60f4e0859d3299be2a185519392c58ef06e886daa044f6`
  pour 3.41.0 et
  `f456fd6733053d9301828a2e702d6cbec872923126809aa8c48eb0a696d6cc01`
  pour 3.47.2.
- `flutter --no-version-check --suppress-analytics --version` a confirmé les
  deux couples exacts.
- Sur **3.41.0** et **3.47.2**, la baseline actuelle résout 25 dépendances et
  exécute les **23/23 tests historiques avec succès**.
- Sur les deux SDK,
  `flutter analyze lib test example/main.dart` retourne les onze informations
  historiques et un code 1 ; l’analyse globale retourne encore 27 diagnostics,
  dont douze erreurs de démo. Ces résultats sont attendus avant C1/T2/T3 et ne
  sont pas une baseline verte.
- Un micro-probe temporaire passe sur 3.41.0, 3.41.6 et 3.47.2. Il compile et
  exerce une sous-classe de `TextScaler`, `TextScaler.linear`,
  `TextScaler.noScaling`, `Text(textScaler:)`,
  `TextPainter(textScaler:)`, `MediaQuery.textScalerOf`, les trois getters
  `maybeLineHeightScaleFactorOverrideOf`,
  `maybeLetterSpacingOverrideOf`, `maybeWordSpacingOverrideOf` et les trois
  champs correspondants de `MediaQueryData`.

Conclusion : **Flutter `>=3.41.0` et Dart `>=3.11.0 <4.0.0` sont la cible
factuelle à retenir**. Flutter 3.41.6 n’apporte aucun prérequis technique à ce
plan et l’adopter exclurait sans justification 3.41.0 à 3.41.5.

Cette preuve valide le choix de cible, pas la Gate SDK du futur lot 0 : les
manifests, lints, locks et harness modifiés devront encore repasser sur les deux
bundles exacts.

Un comportement de toolchain doit être traité dans ce lot : Flutter 3.47.2 a
ajouté une exclusion `build/**` à `analysis_options.yaml` pendant une commande
de résolution/test de la baseline. L’artefact a été restauré pour garder la
branche de vérification propre. Le lot 0 ne devra pas restaurer silencieusement
une telle mutation : il devra examiner le diff, committer une configuration
intentionnelle et stable si elle est nécessaire, puis prouver l’idempotence des
commandes avec un `git status --short` vide.

## Corrections obligatoires exactes

### C1 — Ajouter une pré-gate humaine de production avant le lot 0

La feuille de route reporte la preuve d’autorité pub.dev et l’identité
canonique au lot 12. Cela protège le tag, mais trop tard pour un chantier dont
le résultat annoncé est une `4.0.0` de production.

Avant de créer `codex/impl-foundation-sdk`, un mainteneur doit attester par
écrit :

- le dépôt canonique et la branche d’intégration/release ;
- qu’un uploader de `auto_size_text` ou un administrateur de `simc.dev` pourra
  publier la version, sans donner ses credentials à un agent ;
- le propriétaire des décisions de version, du contact de sécurité et du
  devenir de la démo ;
- que la cible est bien `4.0.0` du package existant, et non un renommage.

Absence d’attestation : **NO-GO production**. Les travaux techniques peuvent
être requalifiés par une décision séparée en R&D locale, mais ils ne suivent
plus cette feuille de route de release et ne doivent produire ni version
`4.0.0`, ni métadonnées de publication. Cette pré-gate n’ajoute pas un
quatorzième lot et n’autorise aucune mutation distante.

### C2 — Corriger les repères Git des pistes parallèles

La phrase « le lot 6 peut être intégré à tout moment après S1 » est
incompatible avec les définitions `S2…S9` comme chaîne cœur/layout pure. Une
branche Git d’intégration linéaire qui reçoit le lot 6 tôt inclura forcément ce
lot dans le SHA suivant ; `S2 == S1 + lot 1` ne sera alors plus vrai.

Le modèle exécutable est :

- `S1` est l’unique point de fork après le lot 0 ;
- les lots 1→5 puis 8→10 avancent seuls sur la piste critique jusqu’à `S9` ;
- le lot 6 produit une tête parallèle `D6`, basée sur `S1` ;
- le lot 7 produit une tête parallèle `P7`, basée sur `S1` ;
- `D6` et `P7` peuvent être développées et revues tôt, mais **ne sont pas
  mergées dans `codex/impl-integration` avant `S9`** ;
- `S10` est l’union revue de `S9 + D6 + P7` ; le coordinateur journalise les
  trois parents et le SHA d’union réel ;
- tout conflit fait retourner la branche concernée à son auteur, puis à une
  nouvelle revue. Le coordinateur ne combine pas les intentions dans le merge.

Cette correction conserve le parallélisme réel sans créer de dépendance
artificielle de la chaîne cœur vers la démo ou l’archive.

### C3 — Rendre les analyses des gates exécutables par piste

Avant l’union `S10`, une analyse globale depuis la racine est rouge à cause de
`demo/`, que les lots cœur ne modifient pas. Les commandes doivent donc être
nommées sans ambiguïté.

Pour la Gate SDK, avant le lot 3 :

1. analyser la surface racine avec
   `flutter analyze lib test example/main.dart` ;
2. analyser séparément l’application `example/` avec son lock forcé ;
3. comparer les diagnostics d’information à une liste exacte
   `(règle, fichier, ligne)` enregistrée par le lot 0 ; toute erreur, warning ou
   information nouvelle échoue ; le code 1 dû aux seules informations connues
   n’est pas maquillé par un ignore global ;
4. ne pas présenter `flutter analyze` global comme vert tant que les lots 3,
   6 et la fermeture T2 ne sont pas réunis.

Pour les Gates Cœur et Architecture, utiliser sur minimum et haute :

- `flutter analyze --fatal-infos --fatal-warnings lib test example/main.dart` ;
- l’analyse fatale séparée de `example/` ;
- la suite racine complète et les suites ciblées de la gate.

Après `S10`, le checkpoint d’intégration et les Gates CI/Finale exécutent en
plus l’analyse globale et les commandes séparées de `demo/`. Aucun lot ne peut
obtenir un vert en excluant durablement une surface qu’un lot antérieur devait
corriger.

Chaque commande qui peut générer un fichier se termine par un contrôle d’arbre
propre. Si Flutter 3.47.2 propose de modifier `analysis_options.yaml`, le lot 0
rend cette configuration explicite puis rejoue les deux SDK jusqu’à
idempotence.

### C4 — Transformer le GO du lot 8 en autorisation révocable

Le verrou actuel est correct et doit être appliqué littéralement :

- un verdict NO-GO ne crée pas `S7` ; les branches des lots 9 et 10 ne sont ni
  créées, ni commencées, ni mergées ;
- aucune garde `WidgetSpan`, dimension manuelle, estimation d’intrinsic ou
  désactivation de test ne permet de contourner ce verdict ;
- les lots 1 à 7 peuvent être conservés comme travail technique, mais aucune
  `4.0.0` de production n’est préparée et les issues layout/WidgetSpan ne sont
  pas déclarées fermées ;
- un autre design exige une nouvelle note, des preuves sur minimum + haute et
  une nouvelle revue indépendante avant un nouveau GO.

Le GO est **invalidé** si le lot 9 ou le lot 10 révèle qu’il faut une API
publique de placeholders, un type privé Flutter, une copie substantielle de
`RenderParagraph`, une mutation dry, le montage incorrect de la branche
inactive, ou un coût hors de la borne acceptée. Le lot fautif est reverté et le
chantier revient au lot 8 ; les critères ne sont pas affaiblis pour poursuivre.

Le lot 10 ne démarre qu’après merge et revue indépendante du lot 9 sur `S8`,
pas seulement après le GO documentaire du lot 8.

### C5 — Donner un propriétaire au benchmark de la Gate Architecture

La gate demande un benchmark reproductible, mais les surfaces des lots 9/10 ne
l’affectent à aucun livrable. La correction minimale est :

- le lot 9 ajoute un compteur déterministe des évaluations de candidats et
  layouts de paragraphes pour texte simple et RichText sans placeholder ;
- le lot 10 étend le même harness au nombre `P` de placeholders et aux deux
  chemins wet/dry ;
- les tests imposent des bornes dérivées de `ceil(log2(C))`, avec constantes
  explicites pour les layouts supplémentaires, et `O(P log C)` pour les cas
  inline monotones ;
- le lot 10 conserve une commande de benchmark reproductible avant/après sur
  un cas texte et un cas inline. Les temps muraux sont un signal documenté,
  jamais le seul gate ; les compteurs déterministes sont bloquants ;
- le fichier ou script de benchmark, ses entrées et sa commande appartiennent
  explicitement à la surface du lot qui l’introduit. Si le benchmark n’est pas
  committé, la note de revue doit contenir assez d’éléments pour le reproduire
  exactement sur les deux SDK.

Une régression significative ou un compteur linéaire produit un NO-GO/revert ;
elle n’est pas cachée par un cache mutable pendant une passe dry.

### C6 — Ajouter un checkpoint d’union vert avant d’écrire la CI

`S10` réunit pour la première fois le cœur/layout, la démo et l’archive. Le lot
11 ne doit pas servir à découvrir ou masquer une baseline d’intégration rouge.

Avant de créer `codex/impl-ci`, le coordinateur exécute localement les futures
commandes des jobs : format haute, analyse fatale racine minimum + haute,
tests, exemple verrouillé, downgrade, démo verrouillée/analyse/smoke/APK,
dartdoc, dry-run et assertions d’archive. Les commandes dépendantes de la seule
toolchain de démo utilisent cette pin déclarée.

Échec : retourner le défaut au lot propriétaire, rebaser/réviser si nécessaire
et recréer `S10`. Il est interdit de corriger un défaut produit dans le
workflow, d’ajouter `continue-on-error` ou d’exclure une surface pour faire
passer la CI.

### C7 — Figer les critères de sortie de lot et les preuves rouges/vertes

Les critères sont globalement bons, mais le journal du coordinateur doit
enregistrer pour chaque lot : parent exact, tête exacte, fichiers modifiés,
commande rouge sur le parent, cause d’échec attendue, commande verte sur la
tête, deux versions SDK utilisées, reviewer indépendant et verdict.

Pour les lots 6/7 développés tôt, la revue initiale est conservée mais une
validation de compatibilité sur `S9` est obligatoire avant leur union dans
`S10`. Un conflit ou une adaptation fonctionnelle impose une nouvelle revue du
diff actualisé.

Un test déjà rouge pour une cause antérieure, un test de fuite qui ne suit que
le GC Dart, une inspection de widget au lieu des métriques rendues ou un test
dry qui observe un groupe mutable ne constitue pas une preuve d’acceptation.

## Plan final exécutable

Les treize lots restent inchangés dans leur responsabilité. Seuls leurs points
d’intégration et gates sont corrigés ci-dessous.

| Étape | Base / résultat | Travail et preuve de sortie | Revue / décision |
|---|---|---|---|
| Pré-gate production | Attestation humaine | Identité canonique, autorité future de publication, propriétaires, `4.0.0` et démo confirmés | NO-GO production sans attestation |
| Lot 0 — fondation | `S0 → S1` | Pins exactes, manifests/lints/locks/harness, analyse scoped avec allowlist exacte, tests/downgrade, arbre idempotent | Revue outillage puis Gate SDK |
| Lot 1 — painters | `S1 → S2` | `try/finally`, signal natif de fuite, résultats historiques inchangés | Revue ressources indépendante |
| Lot 2 — candidats | `S2 → S3` | Domaine virtuel strict, validations runtime, grille/presets, compteur logarithmique | Revue numérique indépendante |
| Lot 3 — texte simple | `S3 → S4` | `TextScaler`, configuration effective simple, métriques painter/render | Revue texte/accessibilité indépendante |
| Lot 4 — RichText | `S4 → S5` | Runs fidèles, zéro, NBSP/NNBSP, sémantiques, aucune mutation | Revue RichText/Unicode indépendante |
| Lot 5 — groupes | `S5 → S6` | Double borne locale/effective, plateau, convergence, lifecycle | Revue état/layout puis Gate Cœur cumulée |
| Lot 6 — démo | `S1 → D6` en parallèle | Six écrans, dépendances supprimées, cycle de vie, scaffold, smoke/APK sur toolchain déclarée | Revue Dart + Android ; pas de merge précoce |
| Lot 7 — archive | `S1 → P7` en parallèle | `.pubignore`, présence/absence exacte, aucun publish réel | Revue packaging ; pas de merge précoce |
| Lot 8 — prototype | `S6 → S7` seulement si GO | Note reproductible, APIs publiques, inline wet/dry, lifecycle, coût et non-monotonie | Revue render indépendante ; NO-GO arrête 9/10 |
| Lot 9 — intrinsics | `S7 → S8` | Render object sans WidgetSpan, quatre intrinsics, dry/baseline, groupe/replacement/semantics, compteur | Revue architecturale indépendante |
| Lot 10 — WidgetSpan | `S8 → S9` | Enfants inline automatiques, scaling par run, wet/dry, interaction, benchmark | Second reviewer inline puis Gate Architecture cumulée |
| Union | `S9 + D6 + P7 → S10` | Validation des pistes 6/7 sur API finale et commandes de tous les futurs jobs vertes | Checkpoint d’intégration ; retour au lot fautif si rouge |
| Lot 11 — CI | `S10 → S11` | Workflow à SHA complets reproduisant les commandes déjà vertes | Revue CI/supply-chain indépendante |
| Lot 12 — docs/version | `S11 → S12` | Claims factuels, migration, URLs approuvées, `4.0.0`, aucun tag/publish | Revue API/release indépendante puis Gate Finale |

Le chemin critique reste
`0 → 1 → 2 → 3 → 4 → 5 → 8 → 9 → 10 → union → 11 → 12`.
Les lots 6/7 sont parallèles en travail et revue, mais rejoignent une seule fois
la piste critique à l’union. Le graphe corrigé est acyclique.

## Gates GO/NO-GO et règles de revert finales

| Gate | GO | NO-GO / revert |
|---|---|---|
| Production préalable | Gouvernance attestée sans transmettre de credential | Arrêt de la feuille de route production ; aucun `4.0.0` préparé |
| SDK après lot 0 | 3.41.0 et 3.47.2 exacts consomment le diff, diagnostics scoped conformes, tests/downgrade verts, arbre propre | Revert lot 0. Changer de minimum exige une nouvelle décision de support ; 3.41.6 n’est jamais substitué silencieusement |
| Cœur après lot 5 | Analyses scoped fatales, tests rouges/verts, domaines/scalers/groupes/painters corrects sur deux SDK | Revert le lot responsable ; le prototype ne démarre pas |
| Prototype lot 8 | Toutes les preuves reproductibles sans API/type privé/copie de paragraphe | Aucun `S7`, aucun lot 9/10, aucune release production ; nouveau design puis nouvelle revue seulement |
| Architecture après lot 10 | Intrinsics et WidgetSpan verts, dry pur, semantics/lifecycle préservés, compteurs bornés, deux revues séparées | Revert lot 10 seul si la frontière 9 reste valide ; sinon revert 9+10 et retour lot 8 |
| Union `S10` | Toutes les commandes locales destinées à la CI sont déjà vertes | Retour au lot propriétaire ; le workflow ne contourne pas l’échec |
| Finale `S12` | SHA propre, matrice, démo, archive, docs et version concordants, revue finale indépendante | Revert lot 12 pour claim/identité ; sinon revert le dernier lot causant la régression et rejouer toutes les gates aval |

## Couverture et périmètre validés

| Sujet | Lots finaux | Verdict de couverture |
|---|---:|---|
| CORE-01, #61/#106 — `WidgetSpan` | 8 + 10 | Complet seulement après GO et support automatique ; aucune dimension publique |
| CORE-02, #140 — scaling | 3 + 4 + 5 + 10 | Simple, runs, groupes et placeholders couverts |
| CORE-03, #104/#119 — parité de configuration | 3 + 4 | Gras, overrides, strut, wrap, direction/locale et métriques couvertes |
| CORE-04 — RichText | 4 | Héritage, runs et `wrapWords` couverts |
| CORE-05 — groupes | 5 | Domaine individuel, plateau et convergence couverts |
| CORE-06, CORE-11, #145 | 2 | Grille, validations et presets couverts ; #151 reste ouvert |
| CORE-07 — référence zéro | 4 | Contrat explicite sans division couvert |
| CORE-08, CORE-10, #146 | 6 | Démo, Android et lifecycle couverts |
| CORE-09 — SDK/lints/CI | 0 + 11 | Fondation puis automatisation couvertes |
| #150 — painters | 1 + 9 + 10 | Fuite historique puis nouveaux propriétaires couverts |
| #142 — NBSP/NNBSP | 4 | Bug confirmé couvert sans moteur UAX #14 général |
| #28/#30/#37/#77/#129/#147 | 8 + 9 | Prototype puis correction unique des intrinsics/dry |
| Archive, métadonnées, release locale | 7 + 11 + 12 | Contenu, automation et claims couverts sans publication |

Il n’existe pas de lot pour #80/#81, #151, les fonctionnalités exclues, les
issues obsolètes ou les rapports non reproduits. Les comportements ambiants de
`TextWidthBasis`/`TextHeightBehavior` au lot 3 corrigent la parité interne sans
ajouter les paramètres publics demandés par #80/#81. Aucun callback de taille,
thème de groupe, stratégie d’overflow, champ éditable, moteur Unicode général,
CodeCov, OIDC, tag ou publication n’entre dans l’implémentation.

## Revue de qualité, sécurité et limites

Le seul fichier changé par la branche auditée était
`maintenance/implementation-roadmap.md`; il a été lu intégralement et son diff
depuis `d0fe48d` a été contrôlé. Ont aussi été lus intégralement :

- les trois audits de `maintenance/audits/` ;
- les trois plans de `maintenance/plans/` ;
- les six revues antérieures de `maintenance/reviews/` ;
- la vérification `maintenance/verification/sdk-floor.md` au commit `d295fe4` ;
- les instructions `developing-flutter`, Effective Dart, testing et
  `find-bugs`.

Checklist adaptée :

| Classe de risque | Conclusion |
|---|---|
| Injection, XSS, SQL, auth, autorisation, CSRF, session, cryptographie | Hors surface : changement Markdown et widget local sans serveur ni identité |
| Supply chain / secrets | Risque réel projeté dans la CI ; couvert par SHA complets, permissions minimales, absence de secret sur PR et pré-gate d’autorité |
| Race / état | Risques groupe, microtâches, dry/wet et branches inactives explicitement assignés aux lots 5, 8, 9 et 10 |
| Disponibilité / ressources | Crashes intrinsics/WidgetSpan et fuites de painters couverts ; prototype et compteurs empêchent un faux correctif coûteux |
| Logique numérique | Domaine, flottants, scalers à plateau/non monotones et validations runtime couverts par critères testables |
| Compatibilité API | Minimum majeur, ancien facteur déprécié, référence zéro et changement observable de `textKey` documentés pour `4.0.0` |

Restent volontairement non prouvés avant implémentation : faisabilité du render
object complet, coût réel des enfants inline, scaffold Android régénéré,
réglages GitHub, protections de branche et autorité pub.dev. Ils sont traités
comme gates, jamais comme faits acquis.

Après application de C1 à C7, la feuille de route est adaptée à une exécution
production : périmètre fermé, dépendances acycliques, parallélisme réel, preuves
testables, revues indépendantes et reverts bornés. Sans ces corrections, aucun
lot produit ne doit commencer.
