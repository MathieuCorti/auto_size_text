# Contre-revue performance — correction de la Gate Cœur

Date : 2026-09-01

Tête produit revue : `9ec35e9f1481d346c7df5516de618b151de95097`

Tête de sanity test-only : `29f50dd98eed921d23d89b85d18646fbf0817155`

Base comparée : `b07066ffe321dff059c9d7d8008b2713e30e1aee`

Branche de revue : `codex/review-gate-core-performance`

Worktree isolé :
`/private/tmp/auto-size-text-review-gate-core-performance`

Périmètre : complexité et exactitude de la maintenance incrémentale de
`AutoSizeGroup._fontSize`, cohérence du cache membre, suppressions,
notifications, mémoire, API et preuves mutantes. Aucun correctif produit ou
test permanent n'a été écrit par cette contre-revue.

## Verdict

**ACCEPTÉ**

La tête remplace correctement le rescan systématique de la map par une
maintenance incrémentale du minimum. Une première publication, une baisse sous
le minimum et toute mise à jour d'un non-minimum qui reste au-dessus du minimum
ne font aucun scan. Une remontée du détenteur courant du minimum et le retrait
d'un détenteur courant font exactement un scan des membres encore inscrits.

L'invariant observé après chaque mutation est resté :

```text
G = min(reports.values), avec G = +infinity si aucun rapport fini n'existe
```

Il est resté exact pendant 40 époques pseudo-aléatoires déterministes de 64
membres, les réordonnancements par clés, les égalités multiples, les zéros
signés, des doubles adjacents, les suppressions, les marqueurs non publiés et
les erreurs de scaler. Aucun cache périmé ni minimum incohérent n'a été
observé.

Les cinq mutants demandés sont rouges sur Flutter 3.41.0 et 3.47.2. Après
suppression de toute instrumentation, les analyses fatales et les suites
complètes initiales passent à `121/121` sur chaque SDK.

La sanity postérieure de `c4723da`, `40a606e` et `29f50dd` confirme que leur
delta est strictement test/documentation, sans changement de `lib/`. Le probe
M=64 conserve tous ses compteurs, le témoin résolu ne fuit aucun painter et la
matrice étendue passe à `125/125` sur chaque SDK. Le diff final de cette revue
ne contient que le présent rapport.

Aucun finding P0, P1, P2 ou P3 n'est ouvert.

## Findings ordonnés

- P0 : aucun.
- P1 : aucun.
- P2 : aucun.
- P3 : aucun.

### Précision de portée, sans finding

Le `O(1)` démontré concerne la maintenance synchrone de `G` dans
`_updateFontSize` ou `_remove`. Une modification qui change réellement `G`
planifie ensuite une vague coalescée dont le snapshot et les callbacks coûtent
`O(M)`. Ce fan-out existait déjà, est nécessaire pour synchroniser les membres
et n'est exécuté qu'une fois par époque pending.

Le gain de la première vague de `M` publications est donc précisément :

```text
base : M publications × scan M + une notification M = O(M²)
tête : M publications × mise à jour O(1) + une notification M = O(M)
```

Une baisse individuelle de `G` conserve une maintenance de minimum `O(1)`,
mais son coût global avec notification des consommateurs est naturellement
`O(M)`. Une mise à jour ou un retrait non-minimum qui ne change pas `G` est
réellement `O(1)` de bout en bout et ne planifie aucune vague.

## Relecture algorithmique

### Publication

Le code écrit d'abord le nouveau rapport dans la map, puis distingue trois
cas :

1. `new < G` : le nouveau rapport est nécessairement le nouveau minimum ;
   l'affectation directe est exacte en `O(1)` ;
2. `old != G` et `new >= G` : un autre rapport conserve le minimum ; aucun scan
   n'est utile ;
3. `old == G` et `new > old` : ce détenteur ne prouve plus le minimum ; un scan
   retrouve le minimum exact, y compris un ex aequo survivant.

Les cas `new == old`, `new == G` et la remontée d'un non-minimum ne changent
pas la borne. Le cache `_publishedEffectiveFontSize` évite en amont les
publications exactes redondantes et n'est jamais alimenté par le candidat
projeté `R`.

Le scan sur un ex aequo dont un seul détenteur remonte est nécessaire avec
l'état actuel : sans compteur de multiplicité ou structure auxiliaire, il
faut parcourir les rapports pour savoir qu'un autre détenteur exact survit.
Ainsi, `O(M)` est limité aux **pertes potentielles d'un détenteur du minimum** ;
il peut conclure que la valeur globale de `G` ne change pas.

### Retrait

Le rapport est supprimé avant toute décision. Un rapport fini différent de
`G` ne peut pas changer le minimum et ne déclenche aucun scan. Un rapport fini
égal à `G` déclenche un scan des seuls survivants. Le marqueur
`double.infinity` d'un membre inscrit mais non publié ne déclenche pas de
scan ; retirer le dernier rapport fini remet correctement `G` à
`double.infinity`.

### Preuve par cas exhaustive

Pour une map ordonnée de doubles valides, les branches précédentes couvrent
toutes les transitions possibles :

| Ancien rapport | Nouveau rapport | Effet exact |
|---|---|---|
| minimum ou non-minimum | strictement sous `G` | affectation directe de `G` |
| non-minimum | supérieur ou égal à `G` | `G` inchangé |
| minimum | égal ou inférieur à l'ancien | égalité sans effet, ou baisse directe |
| minimum | strictement supérieur | scan des rapports courants |

NaN, les deux infinis comme sorties réelles et les négatifs sont rejetés avant
publication. Le zéro est canonicalisé ; `-0.0 == +0.0` ne crée donc pas de
transition fantôme. Aucune tolérance du domaine de candidats n'est appliquée à
la map : les valeurs adjacentes restent ordonnées par comparaison exacte.

## Instrumentation déterministe temporaire

Le probe retiré ajoutait séparément les compteurs suivants : appels
`update/remove`, appels et visites de `_recalculateFontSize`, planifications,
runs et callbacks de notification. Il exposait aussi, uniquement pendant la
revue, le minimum caché et un snapshot des rapports afin de les comparer à un
oracle linéaire indépendant après chaque mutation.

Le harness construisait de vrais `AutoSizeText` publics à preset unique, avec
clés stables et `TextScaler.noScaling`. Aucun temps mural ou seuil de durée
n'est utilisé.

### Compteurs M=64

Les résultats sont identiques sur les deux SDK exacts.

| Scénario | Base appels/visites | Tête appels/visites |
|---|---:|---:|
| première vague ascendante, `M=64` | `64 / 4096` | `0 / 0` |
| première vague descendante, `M=64` | même chemin `64 / 4096` | `0 / 0` |
| hausse d'un non-minimum, `M=64` | `1 / 64` | `0 / 0` |
| baisse d'un non-minimum sous `G`, `M=64` | `1 / 64` | `0 / 0` |
| remontée du minimum, `M=64` | `1 / 64` | `1 / 64` |
| retrait d'un non-minimum, 63 survivants | `1 / 63` | `0 / 0` |
| retrait du minimum, 62 survivants | `1 / 62` | `1 / 62` |

La base a été reproduite en rétablissant exactement son rescan inconditionnel
sur le chemin instrumenté : la première publication M=64 devient rouge avec
`64` appels et `4096` visites sur Flutter 3.41.0 et 3.47.2. Le chemin de
retrait inconditionnel de la base est aussi discriminé par le mutant de
retrait non-minimum à `1/63` au lieu de `0/0`.

Sur la tête, chaque première vague donne en plus exactement une planification,
un run et 64 callbacks. Une remontée qui révèle une autre valeur planifie une
vague ; la remontée d'un détenteur ex aequo qui laisse `G` inchangé fait son
scan nécessaire mais ne planifie rien.

## Ordres, époques et valeurs adversariales

### Mutations pseudo-aléatoires

Le seed fixe `0x5eedc0de` crée 64 rapports, puis 40 époques de modifications.
Pour chaque époque, un modèle de test simule l'ordre exact des écritures et
calcule indépendamment :

- le nombre de publications réellement différentes ;
- le nombre de pertes potentielles du minimum ;
- le minimum linéaire attendu après chaque séquence.

Le produit donne exactement `visites = scans × 64`, jamais une visite sur une
autre branche, et `G` égale toujours le minimum oracle. Après chaque époque,
les 64 widgets sont mélangés avec leurs clés stables : le réordonnancement
produit zéro publication, zéro retrait, zéro scan et ne change pas `G`.

### Ex aequo, zéro et valeurs adjacentes

- Plusieurs détenteurs exacts du minimum survivent correctement aux remontées
  et suppressions successives.
- La transition `20 -> 20.000000000000004` est distincte et exacte.
- Lorsqu'un détenteur passe ensuite à `20.000000000000007` mais qu'un autre
  reste à `20.000000000000004`, le scan conserve cette dernière valeur et ne
  planifie aucune notification.
- Les presets `-0.0` et `+0.0` publient le même `+0.0` canonique. Remplacer
  `-0.0` par `+0.0` ne produit aucune publication ni aucun scan.

### Marqueurs infinis et scalers invalides

Les sorties `NaN`, `+infinity`, `-infinity` et `-1` ont été essayées une à une
avec un membre valide déjà à 10. Chaque erreur est un `ArgumentError`, le
membre invalide reste seulement inscrit avec son marqueur interne
`+infinity`, `G` reste 10, puis son retrait donne zéro scan et zéro
notification. Aucune sortie invalide n'entre dans le minimum.

L'erreur atteinte après une publication finie pendant la projection reste
couverte par l'oracle permanent non transactionnel de
`group_constraints_test.dart` : le dernier rapport fini est conservé, pas le
marqueur. Cette régression et la suite complète passent sur les deux SDK.

## Mutants

Chaque mutant a été appliqué seul, exécuté sur les deux SDK, observé rouge puis
restauré immédiatement.

| Mutant | Signature rouge observée |
|---|---|
| rescan inconditionnel à chaque publication | première vague : `64/4096` au lieu de `0/0` |
| skip du rescan lorsque l'ancien minimum remonte | `0/0` au lieu de `1/64`, puis minimum exact périmé |
| remplacement direct par la nouvelle valeur sans traiter les ties | aucun scan au lieu de `1/M` ; l'ex aequo survivant peut être dépassé |
| rescan au retrait d'un non-minimum | `1/63` au lieu de `0/0` |
| minimum périmé après retrait du minimum | `0/0` au lieu de `1/62`, minimum retiré conservé |

Tous donnent un exit test non nul sur Flutter 3.41.0 et Flutter 3.47.2. Les
échecs portent sur les compteurs ou l'oracle métier attendus, sans erreur de
compilation ou de harness.

## Notifications, mémoire et API

### Notifications

`oldFontSize != _fontSize` reste l'unique déclencheur. La garde
`_notificationPending` est posée avant `scheduleMicrotask`, puis consommée au
début du run. Le run prend les membres courants et revalide présence et
`mounted` avant chaque callback.

Le probe confirme :

- une première vague de 64 rapports : `1 schedule / 1 run / 64 callbacks` ;
- hausse ou retrait non-minimum : aucune vague ;
- baisse réelle ou remontée révélant une nouvelle limite : une vague ;
- remontée d'un ex aequo avec `G` inchangé : aucune vague ;
- retrait d'un marqueur `+infinity` : aucune vague.

Les tests permanents de coalescence, transfert, retrait, dispose et frame
témoin passent. Aucun callback tardif ni frame résiduelle n'a été observé.

### Mémoire

Le diff produit n'ajoute aucun champ, collection, heap, compteur de
multiplicité ou objet persistant. L'état reste une map de `M` rapports, un
minimum et un booléen pending, donc `O(M)` comme avant. Les deux nouvelles
variables locales sont scalaires et de durée d'appel.

Une vraie notification alloue toujours un snapshot `List` de `M` références,
comportement antérieur inchangé et borné à une seule vague pending. Le chemin
optimisé n'ajoute aucune allocation sur une publication ou suppression.

Les suites lifecycle/leak sont vertes sur les deux SDK. Le groupe ne possède
aucune ressource native, painter ou closure membre persistante nouvelle.

### API et cache

`AutoSizeGroup` conserve les mêmes constructeurs et membres publics. Le diff
ne crée ni hook, ni getter, ni configuration publique. L'instrumentation de
revue et son test ont été supprimés ; une recherche finale de leurs symboles
est vide.

Le cache membre conserve une seule valeur effective finie. Il est remis à
`null` uniquement lors d'un changement d'identité de groupe, pas lors d'une
projection ou d'une mise à jour du même groupe. Les mutations multi-époque et
le test permanent de conservation après erreur n'ont révélé aucune
désynchronisation entre cache, map et minimum.

## Sanity après le témoin de fit résolu

La plage `31186fe..29f50dd` contient uniquement :

- `maintenance/implementation/gate-core-fixes.md` ;
- `test/maxlines_test.dart` ;
- `test/preset_font_sizes_test.dart` ;
- `test/text_fit_oracle_test.dart` ;
- `test/text_painter_lifecycle_test.dart` ;
- `test/utils.dart`.

`git diff --quiet 31186fe..29f50dd -- lib` retourne zéro. Les blobs de
`lib/src/auto_size_group.dart` sont identiques à
`6f108ad35e12615994d95a5c0834914aa8d26186` avant et après ; ceux de
`lib/src/auto_size_text.dart` sont identiques à
`3dde5d2fe6612379f1ac23bee442e7a4afd1269e`. Il n'existe donc aucun changement
de la map, du minimum, du cache publié, de la projection, des notifications ou
de l'API consommateur.

### Compteurs groupe inchangés

Une instrumentation jetable nouvelle, retirée avant la matrice, a recompté
les appels et visites de `_recalculateFontSize` sur la tête de sanity. Les
résultats sont identiques sur Flutter 3.41.0 et 3.47.2 :

| Chemin M=64 | Appels/visites après témoin |
|---|---:|
| première vague ascendante | `0 / 0` |
| première vague descendante | `0 / 0` |
| hausse d'un non-minimum | `0 / 0` |
| baisse sous `G` | `0 / 0` |
| remontée du minimum | `1 / 64` |
| retrait d'un non-minimum | `0 / 0` |
| retrait du minimum, 62 survivants | `1 / 62` |

Le témoin n'est appelé que depuis des tests après montage d'un
`RenderParagraph`. Il ne publie aucun rapport, ne lit aucun groupe et ne
planifie aucune microtâche. Le test de preset groupé l'utilise seulement après
la convergence pour confirmer le fit du paragraphe rendu. Les oracles de
minimum, coalescence, transfert, dispose et projection logarithmique restent
verts dans le ciblé 50/50.

### Coût et durée de vie du témoin

`renderParagraphFits` et son helper `_resolvedTextPainter` vivent exclusivement
dans `test/utils.dart`. Une recherche de tous leurs appels ne trouve que des
fichiers sous `test/`. Ils ne sont ni exportés, ni compilés dans la bibliothèque
consommateur et n'ajoutent donc aucun coût CPU, mémoire ou taille au produit.

Dans le harness :

- le chemin normal crée un painter, le layout puis le libère dans `finally` ;
- `wrapWords:false` crée d'abord le painter non wrappé, qui est libéré avant
  tout retour anticipé ou avant la création du painter de paragraphe ;
- le chemin complet crée donc deux painters **séquentiels**, jamais deux
  painters vivants simultanément ;
- le parcours du texte et des plages indivisibles est proportionnel au contenu
  du témoin et reste confiné aux assertions de test.

Un probe leak jetable avec `experimentalLeakTesting` a exécuté séparément le
retour anticipé et le chemin complet à deux painters. Il passe `2/2` sous les
deux SDK. Le test lifecycle permanent du helper et le ciblé incluant le leak
tracking passent également sur les deux pins. Aucun painter, callback ou état
de groupe supplémentaire n'est conservé.

## Matrice

Versions constatées :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
```

| Contrôle | 3.41.0 | 3.47.2 |
|---|---:|---:|
| probe initial intact, 5 scénarios | `5/5` | `5/5` |
| sanity compteur post-témoin | `2/2` | `2/2` |
| sanity leak jetable du témoin | `2/2` | `2/2` |
| harness + groupes/contraintes/builder/leak ciblés | `50/50` | `50/50` |
| cinq mutants | tous rouges | tous rouges |
| analyse fatale `lib test`, hooks supprimés | aucun diagnostic | aucun diagnostic |
| suite complète étendue, hooks supprimés | `125/125` | `125/125` |

Les résolutions ont été refaites avec le SDK exécuté avant chaque run. Aucun
lock suivi n'a changé.

## Périmètre relu et audit pré-conclusion

Les six fichiers du diff `b07066f...9ec35e9` ont été lus intégralement :

- `lib/src/auto_size_group.dart` ;
- `maintenance/decisions/candidate-domain-oracle.md` ;
- `maintenance/implementation/gate-core-fixes.md` ;
- `test/group_minimum_maintenance_test.dart` ;
- `test/maxlines_test.dart` ;
- `test/utils.dart`.

Le chemin interactif et les preuves croisées ont aussi été relus :

- `lib/auto_size_text.dart`, `lib/src/auto_size_text.dart`,
  `lib/src/auto_size_text_layout.dart` et
  `lib/src/auto_size_group_builder.dart` ;
- les tests de groupes, contraintes, scalers, builder, lifecycle et leak ;
- les oracles de projection et de cycle de vie des groupes ;
- les rapports indépendants projection/lifecycle/lot 5 et le journal du lot 5 ;
- les skills `find-bugs` et `developing-flutter`, avec leurs cinq références.

Les six fichiers du delta de sanity `31186fe..29f50dd`, listés dans la section
précédente, ont également été relus intégralement. Les deux fichiers produit
dont les blobs ont été comparés ont été relus à nouveau autour des chemins
groupe/cache ; leur contenu est byte-identique à la contre-revue initiale.

Aucun `AGENTS.md` additionnel n'est présent dans le worktree. L'instruction
PostHog fournie au chantier ne s'applique pas à cette revue locale.

La surface ne traite aucune entrée réseau, base de données, authentification,
autorisation, session, opération cryptographique ou secret. Injection, XSS,
CSRF, IDOR et divulgation d'information sont hors surface.

Les points applicables de la checklist ont été vérifiés :

- **état et races** : ordre écriture/recalcul/notification, pending,
  coalescence, snapshot courant et cache publié ;
- **logique métier** : minimum exact, ties, ordre des doubles, marqueurs,
  erreurs et suppressions ;
- **disponibilité** : disparition du `O(M²)` initial, scans uniquement sur
  perte potentielle du minimum et fan-out de notification explicité ;
- **ressources** : aucune nouvelle structure persistante, snapshot de vague
  inchangé, lifecycle/leak verts ;
- **API** : aucune modification publique permanente ;
- **qualité des preuves** : compteurs non temporels, oracle linéaire après
  mutation, deux SDK exacts et cinq mutants rouges.

Aucune zone demandée n'est restée non vérifiée. Avant rédaction, le worktree
était propre, `git diff --check` était vide et les hooks/probes étaient absents.
Aucun merge, push ou changement distant n'a été effectué.
