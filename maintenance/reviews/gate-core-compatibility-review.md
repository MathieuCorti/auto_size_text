# Gate Cœur — compatibilité, API et comportement

Date : 2026-09-01

Tête auditée : `b07066ffe321dff059c9d7d8008b2713e30e1aee` (`S6`)

Base historique : `f22397751271605ac46e8740d9e48ed631a74cb0` (`master`)

## Verdict

**BLOCKED**

La compatibilité source et la parité fonctionnelle demandées sont établies sur
Flutter 3.41.0 et 3.47.2. Aucun finding P0 ou P1 n'a été trouvé. La gate reste
cependant bloquée par un finding P2 de disponibilité : une première vague de
`M` publications dans un `AutoSizeGroup` parcourt exactement `M²` rapports.
Le même scan `O(M)` est aussi exécuté pour une baisse et pour la hausse d'un
membre qui ne détient pas le minimum. C'est un chemin public normal, une
régression par rapport à `master` et une violation de la borne explicite de
l'oracle, qui n'autorise le recalcul `O(M)` que lorsque le détenteur du minimum
remonte ou disparaît.

## Findings ordonnés

- P0 : aucun.
- P1 : aucun.
- P2 : un finding ouvert, décrit ci-dessous.
- P3 : aucun.

### P2 — Le groupe rescane tous ses membres après chaque publication

Dans `lib/src/auto_size_group.dart:13-17`, `_updateFontSize` écrit le rapport
puis appelle inconditionnellement `_recalculateFontSize`. Cette méthode parcourt
toute la map aux lignes 24-30. Le cache de
`lib/src/auto_size_text.dart:283-286` supprime bien une republication identique,
mais toute nouvelle valeur locale déclenche le scan complet.

L'oracle `maintenance/decisions/group-projection-oracle.md:183-185` autorise un
recalcul `O(M)` « quand le membre qui détenait le minimum remonte ou disparaît »
et précise qu'un tas n'est pas requis. La tête élargit ce coût aux cas où le
minimum se déduit en `O(1)` : première publication, baisse et modification d'un
non-minimum. `master` conservait précisément ces chemins `O(1)` et ne rescannait
que si l'ancien rapport égal au minimum remontait.

#### Preuve déterministe reproductible

Un probe temporaire a instrumenté uniquement le nombre d'appels à
`_recalculateFontSize` et le nombre d'éléments visités dans sa boucle. Le corpus
public construit des `AutoSizeText` à preset unique, avec clés stables, dans un
même `AutoSizeGroup`. Aucun timing ne participe aux assertions.

| Scénario public | Appels S6 | Visites S6 | Borne attendue |
| --- | ---: | ---: | ---: |
| première vague ascendante, `M=64` | 64 | 4 096 | 0 scan, `O(M)` total de publications |
| première vague descendante, `M=64` | 64 | 4 096 | 0 scan, `O(M)` total de publications |
| rebuild sans changement de rapport, `M=4` | 0 | 0 | 0 |
| baisse d'un membre, `M=4` | 1 | 4 | 0 scan, mise à jour `O(1)` |
| hausse d'un non-minimum, `M=4` | 1 | 4 | 0 scan, mise à jour `O(1)` |
| hausse du détenteur du minimum, `M=4` | 1 | 4 | 1 scan `O(M)` |
| retrait du détenteur du minimum | 1 | 3 | 1 scan `O(M)` |

Le test aux attentes de l'oracle est rouge sur S6 avec :

```text
Expected: (0, 0)
Actual:   (64, 4096)
Reason:   ascending first wave
```

Le même comptage S6 est confirmé sous Flutter 3.41.0 et 3.47.2. Un probe de
temps à 6 400 membres a aussi montré le surcoût, mais il n'est pas utilisé comme
preuve, car le compteur donne directement la complexité.

#### Impact

Tous les états sont inscrits avant leurs callbacks de layout. Leur première
publication normale peut donc effectuer `M` scans de `M` entrées, indépendamment
de l'ordre des rapports. Une liste dynamique volumineuse regroupée peut ainsi
consommer un temps CPU quadratique pendant une frame. Aucun accès réseau n'est
nécessaire ; le nombre de widgets suffit à piloter le coût. L'impact est local
et exige un groupe volumineux, d'où P2 plutôt que P1.

#### Correctif minimal attendu et preuve mutante

Sans tas, nouvelle API ni feature : mémoriser l'ancien rapport, traiter une
baisse en mettant directement à jour le minimum, ne rescanner que si l'ancien
rapport était égal au minimum et que la nouvelle valeur remonte. Au retrait,
ne rescanner que si le rapport supprimé était égal au minimum. Les ex aequo
restent corrects, puisque leur rescan retrouve le minimum survivant.

Ce correctif minimal a été appliqué seulement dans l'archive temporaire du
probe. Le même test compteur devient vert, ainsi que les suites groupe
existantes : 20/20 sous Flutter 3.47.2 et 21/21 avec le probe sous Flutter
3.41.0. L'archive et l'instrumentation ont ensuite été supprimées. Aucun fix
produit n'est inclus dans cette revue.

## Surface publique et compatibilité source

La bibliothèque continue d'exporter `AutoSizeText`, `AutoSizeGroup` et
`AutoSizeGroupBuilder`. Aucun nouveau symbole public non prévu n'est introduit.
Le passage de la directive `library auto_size_text;` à `library;` ne retire pas
un symbole importable.

| Surface | Comparaison avec `master` | Verdict |
| --- | --- | --- |
| `AutoSizeText(...)` | mêmes paramètre positionnel, paramètres nommés, defaults et caractère `const`; ajout de `TextScaler? textScaler` | compatible, prévu |
| `AutoSizeText.rich(...)` | même constat | compatible, prévu |
| `textScaleFactor` | paramètre et champ conservés, maintenant dépréciés | compatible avec avertissement prévu |
| `AutoSizeGroup` | constructeur implicite et type public conservés | compatible |
| `AutoSizeGroupBuilder` | constructeur rendu `const`; signature du builder et état conservés | ajout compatible |
| champs et defaults historiques | `minFontSize=12`, `maxFontSize=∞`, `stepGranularity=1`, `wrapWords=true` et tous les autres champs inchangés | compatible |

Les clients de compilation temporaires couvrent les constructions simples et
riches, groupe direct et builder, presets, `overflowReplacement`, `key`,
`textKey`, `semanticsLabel`, ancien facteur et nouveau scaler. Ils compilent et
leurs tests passent sur les deux SDK exacts.

## Assertions, erreurs runtime et valeurs invalides

- Les deux constructeurs portent l'assertion const-compatible qui interdit de
  fournir simultanément `textScaleFactor` et `textScaler`. Le chemin runtime
  répète ce contrôle et lève `ArgumentError`, y compris quand les assertions
  sont absentes.
- Les facteurs legacy, tailles de référence, bornes, pas, ratios de domaine et
  presets non finis, négatifs, vides ou mal ordonnés sont rejetés par des
  `ArgumentError` appartenant au package. Les probes vérifient notamment les
  noms `presetFontSizes` et `minFontSize` dans les messages.
- `maxLines`, l'exclusion `overflow`/`overflowReplacement` et l'égalité
  `key`/`textKey` restent des assertions historiques, conformément au plan ;
  aucune nouvelle rupture runtime n'est ajoutée sur ces surfaces.
- Un `WidgetSpan` reçoit l'`UnsupportedError` déterministe prévu au lot 4. Ce
  rapport ne réclame ni son support ni celui des intrinsics, réservés aux lots
  9 et 10.

## Résultats black-box et immutabilité

Le client indépendant n'inspecte pas l'algorithme pour déterminer les tailles.
Ses témoins linéaires utilisent leurs propres `TextPainter` et comparent les
avances, hauteurs et tailles effectives du `RenderParagraph` rendu.

| Fixture indépendante | 3.41.0 | 3.47.2 |
| --- | ---: | ---: |
| compilation de la surface historique | vert | vert |
| texte simple, facteur linéaire | vert | vert |
| texte riche, scaling par run | vert | vert |
| réduction puis remontée d'un groupe | vert | vert |
| replacement, `textKey` et sémantique | vert | vert |
| recognizer riche, spans et presets non mutés | vert | vert |
| domaines invalides et erreurs package | vert | vert |
| total client | 7/7 | 7/7 |

La fixture passe une liste de presets et une liste d'enfants non modifiables :
aucune écriture n'est tentée. Le code prend un snapshot des presets, trie une
copie et construit des spans de mesure distincts en conservant recognizers,
sémantique et contenu source. Aucun `TextSpan` ou `List` appelant n'est muté.

## Disponibilité et complexité hors finding

- Le domaine régulier est virtuel et la recherche est logarithmique. Les ratios
  non finis ou au-delà de l'index exact IEEE-754 sont rejetés avant conversion.
  Le test permanent couvre environ mille milliards de candidats sans les
  matérialiser.
- Un domaine preset coûte `O(P)` en snapshot/validation, proportionnel à la
  liste explicitement fournie ; il n'y a pas de croissance cachée dépendant de
  l'écart numérique.
- Un texte long est segmenté une fois par configuration pour `wrapWords:false`.
  Chaque candidat paie le layout Flutter et les boîtes des plages, sur un
  nombre logarithmique de candidats. Les painters sont libérés dans des
  `finally`. Aucun contenu réseau, décompression ou récursion de package n'est
  engagé.
- La projection de groupe reste `O(log C)` et ne matérialise pas le domaine.
  Le seul défaut de disponibilité confirmé est le cumul quadratique du minimum.

## Claims upstream des lots 1 à 5

Le mapping est cohérent avec la roadmap et ne dépasse pas le diff :

- lot 1 : #150, libération des painters ;
- lot 2 : CORE-06, CORE-11 et #145 ; durcissement partiel de #151, sans claim de
  fermeture ;
- lot 3 : CORE-02/CORE-03 pour le texte simple, #140, #104 et #119 ;
- lot 4 : CORE-04, CORE-07, #142 et complément RichText de CORE-02/03 ;
- lot 5 : CORE-05 et branche groupe de `didUpdateWidget`.

Ni #151, ni #80/#81, ni les familles intrinsics/dry layout, ni le support réel
de `WidgetSpan` ne sont revendiqués. Leur état ouvert n'est donc pas un finding
de cette gate cœur.

## Chaîne d'approvisionnement des fixtures

Les trois fontes sont des TrueType locales, petites et non exécutables. Elles
ne sont ni téléchargées au runtime ni déclarées comme assets du package livré.
Les licences Noto et Roboto sont présentes. Les SHA-256 correspondent à
`maintenance/decisions/text-metric-fixtures.md` :

```text
d51e94755847f96a7cb9fdd53c91962ec6772a4d6b54c764e05b85e8d987af5a  auto_size_metric_naskh_locl.ttf
bab0b1b36298647122dfaee2e27c0bcb564c43f954be771e90abc94812fafa6d  auto_size_metric_roboto_bold.ttf
893780a2a9c1b15a9ee784b1e34568ff755d3ff9815c9fa755febe303d7bd9c1  auto_size_metric_roboto_regular.ttf
c3dd4c678171e42146614fd4fd132f474df05f7bd12d1348b4c5af50172c0e8f  LICENSE-NotoNaskhArabic.txt
cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30  LICENSE-Roboto.txt
```

Les dépendances de test restent celles du SDK Flutter, `flutter_lints` et
`leak_tracker_flutter_testing`, avec contraintes bornées. Aucune fixture ou
dépendance inconnue supplémentaire n'est apparue.

## Matrice de validation

Versions réellement exécutées :

- Flutter 3.41.0, révision `44a626f4f0`, Dart 3.11.0 ;
- Flutter 3.47.2, révision `d3b14c8769`, Dart 3.13.2.

| Commande/validation | 3.41.0 | 3.47.2 |
| --- | ---: | ---: |
| `flutter analyze --no-pub --fatal-infos --fatal-warnings lib test` | aucun diagnostic | aucun diagnostic |
| `flutter test --no-pub` | 115/115 | 115/115 |
| client historique/black-box | 7/7 | 7/7 |
| compteur S6, observations actuelles | conforme aux comptes ci-dessus | conforme aux comptes ci-dessus |
| correctif minimal temporaire : compteur + suites groupe | 21/21 | 20/20 suites groupe, compteur vert séparément |

`git diff --check master...HEAD` signale quatre espaces finaux déjà présents
dans trois documents de décision/vérification. Ils sont hors du rapport et ne
modifient ni API ni comportement ; aucun fichier produit n'a été corrigé pour
cette revue.

## Périmètre lu et checklist de sécurité

Ont été lus intégralement : les instructions `find-bugs`,
`developing-flutter` et toutes ses références ; les instructions `AGENTS.md`
fournies ; le diff produit public et sa base `master` ; les trois audits, les
trois plans, la roadmap, les huit décisions/oracles et les journaux des lots 0
à 5. Le diff complet a été inventorié, les tests et rapports pertinents à chaque
claim ont été recoupés, et les fontes binaires ont été contrôlées par type,
taille, hash et licence.

La surface est un widget Flutter local : aucune commande, requête, donnée
réseau, authentification, autorisation, session, secret, chiffrement ou rendu
HTML n'est introduit. Injection, XSS, CSRF, IDOR et cryptographie ne sont pas
applicables. Les points applicables sont la validation numérique, les
ressources natives, le cycle de vie asynchrone, l'état partagé, l'immutabilité,
la disponibilité et la supply-chain des fixtures ; ils sont couverts ci-dessus.

Tous les clients, probes, archives, caches et fichiers temporaires créés pour
cette gate ont été supprimés. Le commit de revue contient uniquement ce
rapport.
