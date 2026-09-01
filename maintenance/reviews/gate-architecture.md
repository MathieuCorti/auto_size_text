# Gate Architecture — revue cumulative indépendante

Date : 2026-09-02

Branche de revue : `codex/gate-architecture`

Tête technique auditée :
`8ce1f02f4686472540f3a6b42a13d6380f553abd`

Base historique du diff cumulé :
`f22397751271605ac46e8740d9e48ed631a74cb0` (`master` et merge-base)

Périmètre : union des lots 0 à 10, support d'intrinsics et de `WidgetSpan`,
groupes, démonstrateur Android et politique d'archive Pub. Aucun correctif
produit, merge, push, tag ou publication réelle n'est inclus dans cette revue.

## Verdict

**PASS — aucun finding P0, P1 ou P2.**

La tête exacte est compatible avec Flutter 3.41.0 et 3.47.2 : analyses
fatales, 65 tests ciblés et 156 tests package complets passent sur les deux
pins. Sur le pin haut, la démo consomme son lock inchangé, passe son analyse et
ses quatre smoke tests, puis construit son APK debug. Le dry-run Pub retourne
zéro avec zéro avertissement. Aucun fichier suivi n'est ignoré.

Le contrat lean `WidgetSpan` est respecté : layout humide automatique par API
Flutter publique ; métriques sèches de l'enfant à zéro sans consultation de
l'enfant ; divergence dry/wet admise. Cette divergence n'est pas un finding.

## Intégrité de l'assemblage et du diff

Le diff `master...8ce1f02` porte sur 152 fichiers, avec 32 599 insertions et
1 229 suppressions. Les deux contrôles d'identité suivants sont vides :

- `git diff e1e8146..8ce1f02 -- lib test` : le produit et les tests sont
  identiques à la lignée `WidgetSpan` revue ;
- `git diff baa9c89..8ce1f02 -- demo .pubignore` : la démo et la politique
  d'archive sont identiques à leur lignée corrigée.

Les merges d'intégration ne contiennent aucun hunk combiné de résolution dans
ces arbres. La recherche de marqueurs de conflit, de chemins Git dupliqués et
d'import `package:flutter/src/**` est vide. Les 166 fichiers suivis sont
uniques.

`git diff --check HEAD` est propre. Le contrôle cumulé
`git diff --check master...HEAD` retourne toutefois non-zéro pour deux doubles
espaces de fin de ligne dans des documents de maintenance déjà présents :

- `maintenance/decisions/example-lock-policy.md:3` ;
- `maintenance/verification/sdk-floor.md:3`.

Ce sont des sauts de ligne Markdown sans impact exécutable, API, test ou
archive. Conformément au périmètre limité aux P0-P2, ils ne bloquent pas ce
gate et n'ont pas été corrigés par la revue.

## API publique et dépendance au framework

Les déclarations publiques restent `AutoSizeText`, `AutoSizeGroup` et
`AutoSizeGroupBuilder`. L'ajout `textScaler` est additif ; l'ancien
`textScaleFactor` est conservé et déprécié. `AutoSizeGroupBuilder` devient
`const`. La documentation de `textKey` décrit son nouveau paragraphe rendu sans
promettre un widget `Text` concret.

Le render tree emploie uniquement des API Flutter publiques :
`RenderObjectElement`, `RenderProxyBox`, `RenderParagraph`,
`invokeLayoutCallback`, `PlaceholderSpanIndexSemanticsTag` et les visiteurs
publics d'`InlineSpan`. Aucun symbole d'un chemin `flutter/src` n'est importé.
La compilation, l'analyse et l'exécution sur les deux SDK bornes confirment
l'absence de dépendance privée ou d'écart de signature entre 3.41 et 3.47.

## Invariants architecture relus

### Recherche, groupes et ressources

`_CandidateSet` représente les grilles régulières par index et cherche par
dichotomie, sans liste proportionnelle à l'intervalle numérique. Les deux
recherches — fit local puis projection sous limite de groupe — sont en
`O(log C)`. Les tests ciblés couvrent notamment un billion de candidats
virtuels, les domaines preset disjoints, les scalers linéaires/non linéaires et
la borne locale.

Le minimum de groupe est maintenu en `O(1)` quand il baisse et recalculé en
`O(P)` seulement quand l'ancien minimum remonte ou disparaît. Les notifications
sont coalescées avant la microtâche, puis réévaluent appartenance et `mounted`.
Publication, projection, transfert entre groupes, retraits, ex aequo et
disposal convergent sans boucle ni callback tardif.

Chaque `TextPainter` temporaire est protégé par un `try/finally`; les chemins
intrinsic, dry, wet et `wrapWords:false` le libèrent aussi sur exception. Les
tests permanents de lifecycle et de leak tracking passent sur les deux pins.

### `InlineSpan` et `WidgetSpan`

Le span fourni par l'appelant n'est jamais muté. Les overrides de mesure
recréent seulement les `TextSpan` standards, conservent leurs métadonnées et
laissent les autres sous-types identiques. L'extraction des `WidgetSpan` et des
tailles de run utilise le même parcours preorder ; chaque placeholder possède
exactement un host et un wrapper d'échelle.

Le scaling traite les runs multiples, le scaler non linéaire, les runs de
taille zéro et la référence zéro sans division non finie. Les dimensions
humides transmettent taille, alignement, baseline et offset au
`RenderParagraph`. La mise en page des placeholders reste bornée par
`P * (ceil(log2(C)) + constante)` ; le test de 1 024 candidats et trois
placeholders respecte sa borne. Un enfant non monotone termine en moins de 20
layouts par passe dans le probe permanent.

Les métriques non humides du wrapper inline — dry size, dry baseline et quatre
intrinsics — retournent zéro sans appeler l'enfant. Le parent reste fini. C'est
le contrat lean admis et non une prétention d'égalité dry/wet.

Paint, hit test et `applyPaintTransform` partagent la même transformation. Les
tests observent paint réel, hit de l'enfant et tap. Les recognizers, la
sémantique du texte et de l'enfant, `SelectionArea`, les alignements et les
baselines sont également exercés.

### Replacement et invariants internes

`overflowReplacement` reste lazy : le paragraphe inline et le replacement ne
coexistent pas. Le correctif mono-`Element` de `061b561` donne une identité
stable au replacement actif et remplace l'unique enfant sous `buildScope`.
Les tests permanents vérifient :

- conservation de l'état du replacement actif lors d'un rebuild ;
- branches exclusives quand enfant inline et replacement partagent une
  `GlobalKey` ;
- destruction/recréation attendue lors des transitions fit/overflow ;
- suppression de groupe et disposal sans fuite.

Les `StateError` restants protègent uniquement des invariants structurels
internes : paragraphe/wrapper manquant ou nombre de hosts différent du nombre
de `WidgetSpan`. Ils sont dans la passe humide protégée, qui nettoie l'enfant,
rapporte l'erreur Flutter et termine la passe. Les parcours et compteurs sont
construits depuis le même snapshot immuable ; aucun chemin utilisateur valide
ne permet de les désynchroniser. Les régressions replacement/`GlobalKey` passent
en debug sur les deux pins sans exception capturée.

L'assertion d'appartenance de `_updateFontSize` protège elle aussi un invariant
interne : inscription dans `initState`/transfert avant layout, puis retrait au
`dispose`. Le callback de layout consulte le groupe courant de l'état et son
cache est invalidé au transfert ; aucun callback valide ne peut donc atteindre
le `!` de la map après retrait. Les assertions de slot du mono-enfant ne sont
pas utilisées comme validation d'entrée et aucun mouvement de slot n'existe.

## Matrice indépendante

Toolchains exactes :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
```

| Contrôle package | Flutter 3.41.0 | Flutter 3.47.2 |
|---|---:|---:|
| `flutter pub get --no-example` | succès, 1,10 s | succès, 0,96 s |
| analyse `--fatal-infos --fatal-warnings` de `lib test example/main.dart` | 0 diagnostic, 4,09 s | 0 diagnostic, 3,95 s |
| ciblés groupe/layout/performance/WidgetSpan/leak/lifecycle | 65/65, 7,72 s | 65/65, 8,14 s |
| suite package complète | 156/156, 6,59 s | 156/156, 6,46 s |

Les ciblés sont : `group_builder_test.dart`, `group_constraints_test.dart`,
`group_minimum_maintenance_test.dart`, `group_test.dart`,
`render_object_test.dart`, `intrinsics_test.dart`, `widget_span_test.dart`,
`leak_tracking_test.dart` et `text_painter_lifecycle_test.dart`.

### Exemple et démo sur Flutter 3.47.2

| Contrôle | Résultat | Temps réel |
|---|---|---:|
| exemple `pub get --enforce-lockfile` | succès ; lock inchangé | 0,51 s |
| exemple analyse fatale autonome | 0 diagnostic | 3,82 s |
| démo `pub get --enforce-lockfile` | succès ; lock inchangé | 0,56 s |
| démo analyse fatale | 0 diagnostic | 2,50 s |
| `demo_smoke_test.dart` | 4/4 | 6,37 s |
| `flutter build apk --debug --no-pub` | succès | 15,57 s |

Locks versionnés inchangés :

- exemple :
  `115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7` ;
- démo :
  `a33b1dd565ee362192f89e445a471e6110ec619195bc595a2c84c6f3bf1c98fb`.

L'APK `app-debug.apk` mesure 150 383 094 octets et porte le SHA-256
`1fb89f4f4826e8b651c889b1ebe8fce3f54d322d54e5c1283c750b0f147852dc`.

### Archive Pub

`flutter --no-version-check --suppress-analytics pub publish --dry-run`
retourne zéro en 3,24 s, annonce une archive compressée de 69 KB et conclut
`Package has 0 warnings.` Aucune publication réelle n'a été lancée.

La liste annoncée contient les fichiers publics racine, `lib/**`,
`example/main.dart`, `example/pubspec.yaml`, les 25 tests Dart et les cinq
fixtures/licences de fontes. Elle exclut `maintenance/**`, `demo/**`,
`.github/**`, tous les lockfiles, les sorties générées, les fichiers locaux ou
secrets et les wrappers Gradle.

`git ls-files -ci --exclude-standard` retourne zéro ligne après l'ensemble des
commandes. Les seuls artefacts locaux sont ignorés (`.dart_tool/`, `build/`,
lock racine généré et sorties Android de la démo) ; aucun artefact généré ou
ignoré n'est ajouté au commit de revue.

## Sécurité et risques résiduels

Le produit n'ajoute ni réseau, stockage, authentification, session, secret,
cryptographie, shell ou interprétation d'entrée. Les surfaces applicables sont
la disponibilité, les limites numériques, le cycle de vie des éléments et des
ressources natives, et les races de microtâches ; elles sont couvertes par la
relecture et les tests ci-dessus.

Risques non bloquants et limites de preuve :

- le contrat dry/wet `WidgetSpan` est volontairement divergent ;
- l'APK vérifié est un build debug local, sans essai sur appareil physique ;
- le dry-run ne remplace pas les contrôles ultérieurs du serveur pub.dev et la
  version reste volontairement `3.0.0` jusqu'au lot de release ;
- les deux fins de ligne Markdown historiques empêchent seulement le
  `git diff --check` cumulé d'être entièrement vert.

Ces limites ne constituent ni régression d'intégration ni finding P0-P2.
