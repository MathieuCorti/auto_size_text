# Oracle adversarial — état, convergence et cycle de vie des groupes

Date : 2026-09-01

Base exécutée : `S5` / `c9a1adc006365feb3e1750069ca1e115c3f20237`.

Ce document challenge et précise
`maintenance/decisions/group-projection-oracle.md`. Il ne change pas le
contrat mathématique `L/P/G/R`, ne prescrit aucun correctif produit et
n'autorise ni nouvelle API publique, ni render object, ni dry layout. Les
probes temporaires ont été supprimés ; aucun test ou changement produit de
probe n'est conservé.

## Verdict

La double projection de l'oracle principal est nécessaire et suffisante sous
ses deux hypothèses : fit local monotone et scaler monotone non décroissant.
Les quatre valeurs ne sont jamais interchangeables :

```text
L_m  candidat logique local du domaine D_m
P_m  U_m.scale(L_m), rapport fini publié
G    min des P_m publiés
R_m  candidat logique rendu, projeté dans D_m
```

Deux précisions sont bloquantes pour rendre le gate testable :

1. Le rouge sur le parent `S5` ne concerne que les assertions discriminantes
   d'un défaut du lot 5. Les locks historiques — groupe homogène, replacement
   local, retrait sans callback tardif, identité du builder — sont déjà verts
   sur `S5` et doivent rester verts sur le parent comme sur la tête. Exiger que
   les quinze familles P0 complètes soient rouges sur le parent est
   contradictoire avec leur rôle de non-régression.
2. La gestion d'une sortie invalide rencontrée seulement pendant la projection
   n'est pas transactionnelle. `P_m` est validé avant son écriture. Si une
   autre sortie de `U_m` lève ensuite pendant la projection, aucune valeur
   invalide n'entre dans `reports` ou `G`, mais le `P_m` fini déjà publié reste
   publié. Aucun rollback n'est attendu.

La coalescence doit en outre être mesurée à trois niveaux distincts : tâche
planifiée, tâche exécutée et callback membre. Une seule frame visible ne prouve
aucun de ces trois nombres, car plusieurs `setState` avant la frame sont
idempotents au niveau de l'élément Flutter.

## Sources et probes croisés

Ont été lus intégralement sur la base ci-dessus : les trois audits, les trois
plans, la feuille de route, l'oracle principal, le code de groupe et de layout,
ainsi que tous les tests qui créent ou observent un `AutoSizeGroup`. Les
instructions locales `AGENTS.md` fournies au chantier ne contiennent aucune
instruction supplémentaire applicable hors PostHog.

Les probes ont été exécutés avec les bundles exacts :

| SDK | Révision Flutter | Dart |
|---|---|---|
| Flutter 3.41.0 | `44a626f4f0` | 3.11.0 |
| Flutter 3.47.2 | `d3b14c8769` | 3.13.2 |

Les deux SDK ont produit les mêmes traces. Les sources Flutter pertinentes sont
également identiques sur les points testés : `State.setState` marque l'élément
dirty, les appels suivants avant la frame sont sans effet observable ;
`AutomatedTestWidgetsFlutterBinding.pump` vide les microtâches après la frame ;
`StatefulElement.unmount` appelle `dispose` avant de détacher le `State` de son
élément.

### Résultats observés sur `S5`

Les tailles ci-dessous sont les tailles racines effectives du vrai
`RenderParagraph`, sauf la largeur de box explicitement nommée.

| Probe | Après frame de publication | Après une frame de synchronisation | Frame témoin | Résultat `S5` |
|---|---|---|---|---|
| Presets A `{10,20,40}`, B `{10,30}` | `40/30`, frame programmée | `30/30`, aucune frame programmée | `30/30` | A sort de son domaine ; attendu lot 5 `20/30`. |
| Scalers identité/quadratique, rapports `50/90` | — | `50/50` | stable | La limite effective est rendue directement ; attendu `50/40`. |
| Replacement local P=20, voisin D=`{30,40}` | replacement A seul, voisin texte 20 | identique | stable | Le replacement reste correctement local, mais le voisin passe sous son domaine ; attendu voisin 30. |
| Plateau racine zéro décrit plus bas | racine 0, box du run 0 | racine 0, box 0 | stable | Attendu lot 5 : `R=20`, box Ahem 70 ; le mutant « borne effective seule » donnerait 120. |
| Retrait du minimum `20/40` | survivant encore 20, frame programmée, aucune exception | survivant 40, aucune frame programmée | 40 | Lock historique déjà correct. |
| Rapports `10/20 → 30/40` dans cet ordre | `20/30`, frame programmée | `30/30`, aucune frame programmée | compteurs inchangés | La borne de frames historique est correcte. |
| Transfert A de g1 `20/40` vers g2 `50` | `A/B/C = 20/40/20` | identique | — | Retrait/inscription historiques corrects sur ce cas. |
| Puis A vers `group:null` | `20/40/50` | identique | — | L'ancien groupe remonte correctement. |

Le probe à scalers enregistreurs donne, sur les deux SDK, la trace exacte
suivante pour les presets disjoints :

```text
frame publication : tailles 40/30, appels U 5/5, hasScheduledFrame=true
frame sync        : tailles 30/30, appels U cumulés 10/10,
                    hasScheduledFrame=false
frame témoin      : tailles 30/30, appels U cumulés 10/10
```

Les nombres absolus d'appels à `U` décrivent `S5`; ils ne sont pas une API du
lot 5. Le delta nul de la frame témoin, lui, est un invariant d'absence de
frame et d'oscillation.

### Coalescence réelle de `S5`

Un `ZoneSpecification` temporaire a compté les appels à `scheduleMicrotask`
dont la pile contient `auto_size_group.dart`, puis a enveloppé chaque callback
pour compter son exécution. Deux publications initiales faisant passer `G` de
`+∞` à 40 puis à 30 donnent sur les deux SDK :

```text
microtasks planifiées = 2
microtasks exécutées  = 2
vagues avec callbacks = 1
callbacks membres     = 2
frames programmées    = 1
```

Le second run retourne grâce à `_widgetsNotified`; il n'est pas une preuve de
coalescence de planification. Le lot 5 doit obtenir respectivement
`1 / 1 / 1 / 2 / 1` pour cette époque.

### Transfert pendant une vague déjà pending

Le cas discriminant ordonne les enfants `D, A, C` :

- g1 contient D=10 et A=20, donc `G1=10` ;
- g2 contient C=10, donc `G2=10` ;
- dans une même frame, D publie 30 avant que A soit transféré de g1 vers g2 ;
- la hausse de `G1` planifie donc une vague alors que A appartient encore à
  g1 ; la publication de A dans g2 ne change pas `G2`.

Un scaler recorder de A contient 9 appels après la frame de transfert et
toujours 9 après la frame déclenchée par l'ancienne vague, sans exception, sur
les deux SDK. `S5` consulte donc les membres courants à l'exécution. Ce lock est
déjà vert, mais il tue un futur mutant qui capture les listeners lors de la
planification ou qui se contente de `mounted` : A reste monté dans g2.

## Compteurs normatifs

L'instrumentation temporaire du lot 5 doit séparer les compteurs suivants. Elle
est supprimée avant merge si elle ne peut pas rester privée et maintenable.

| Compteur | Événement exact | Ce qu'il ne faut pas compter à sa place |
|---|---|---|
| `membershipAdd/Remove(g,m)` | ajout ou retrait de m dans la map de g | changement de rapport sans changement d'appartenance |
| `reportWrite(m)` | transition `⊥→P` ou remplacement exact `P→P'` avec `P'!=P` | appel de `publish` avec la même valeur, calcul de `R_m`, rendu |
| `reportDelete(m)` | suppression d'un rapport fini lors d'un retrait/transfert | inscription initiale avec marqueur `⊥` |
| `limitChange` | changement exact de `G`, y compris vers/depuis `+∞` | remplacement d'un rapport qui ne change pas le minimum |
| `waveSchedule` | transition `pending=false → true` causée par un changement de `G` | chaque changement intermédiaire de `G` |
| `waveRun` | consommation d'un marqueur pending | microtâche redondante qui retourne immédiatement |
| `callback(g,m)` | demande de rebuild adressée par g à m encore inscrit et monté | simple reconstruction de m par son parent |
| `projectionEval(m,c)` | évaluation du prédicat de projection pour c | fit local et rendu final |
| `effectiveEval(m,c)` | appel de `U_m.scale(c)` depuis la projection | appels par run du painter ou du `RenderParagraph` |
| `projectedReportWrite` | toute écriture dérivée de `R_m` | republication autorisée du même `P_m=E_m(L_m)` après recalcul local |

Pour une vague stable, `projectedReportWrite` vaut exactement zéro. Un rebuild
de synchronisation peut recalculer le local et republier le même `P_m`; le test
doit vérifier la provenance et la valeur, pas interdire cet appel permis par
l'oracle.

Les appels absolus à un `TextScaler` public ne sont pas un compteur fiable :
Flutter peut l'appeler pour la racine, les runs, le strut et le rendu. Les tests
permanents acceptent des appels supplémentaires, interdisent toute lecture de
`textScaleFactor`, vérifient les entrées discriminantes et exigent un delta nul
sur une frame témoin sans dirty element. Les compteurs de phase ci-dessus sont
réservés au probe interne.

## Traces d'état exactes

Les traces fixent l'ordre des enfants par des clés stables dans un `Column`.
Sans ordre de layout contrôlé, seule la valeur après synchronisation est
normative.

### Publication initiale avec presets disjoints

```text
état initial inscrit       reports={A:⊥, B:⊥}, G=+∞, pending=false
A : L=40, P=40             reports={A:40, B:⊥}, G=40, pending=true
                            R_A=40, waveSchedule=1
B : L=30, P=30             reports={A:40, B:30}, G=30, pending=true
                            R_B=30, waveSchedule reste 1
wave                       waveRun=1, callback(A)=1, callback(B)=1
frame sync                 P inchangés, G=30, R_A=20, R_B=30
                            aucun limitChange, aucun waveSchedule
frame témoin               aucun delta de compteur ou taille
```

État final : `L=40/30`, `P=40/30`, `G=30`, `R=20/30`. Un test qui ne lit que
la frame initiale manquerait précisément la projection de A.

### Deux remontées dans la même frame

Le domaine reste stable ; seules les contraintes changent. Utiliser Ahem avec
`D_A={10,20,30}`, largeur A `10→30`, et
`D_B={10,20,30,40}`, largeur B `20→40`.

```text
avant mutation             reports=10/20, G=10, R=10/10
A publie 30                reports=30/20, G=20, R_A=20
                            limitChange +1, waveSchedule +1
B publie 40                reports=30/40, G=30, R_B=30
                            limitChange +1, waveSchedule +0
fin frame publication      rendu 20/30, pending=true
wave                       waveRun +1, callback(A/B) +1 chacun
fin frame sync             rendu 30/30, pending=false
frame témoin               aucun appel/scaler/report/frame supplémentaire
```

Delta obligatoire de l'époque : deux écritures de rapport, deux changements de
limite, une tâche planifiée, une tâche exécutée, un callback par membre courant
et aucune seconde vague.

### Retrait et dispose du minimum

```text
avant retrait              reports={A:20, B:40}, G=20, rendu=20/20
frame de retrait           B peut encore rendre 20 ; dispose(A) retire A
après désinscription       reports={B:40}, G=40, pending=true
après retour de dispose    A est démonté
wave                       callback(oldGroup,A)=0, callback(oldGroup,B)=1
frame sync                 B rend 40, pending=false
frame témoin               B reste 40, compteurs stables
```

Le compteur du scaler de A, capturé avant le retrait, ne doit plus changer.
`tester.takeException()` reste nul après la microtâche et après la frame de
synchronisation. Un test limité à `mounted` ne prouve pas que la map ou une
closure n'a pas retenu A ; le probe interne vérifie aussi `members={B}` avant
le run et l'absence de snapshot de listeners.

La suppression du dernier membre laisse `reports={}` et `G=+∞`. Elle exige
zéro callback. Planifier zéro ou une tâche vide est une différence interne non
observable et n'est pas un gate du lot 5 ; planifier plusieurs tâches reste
inutile mais ne justifie pas seul un changement d'API.

### Transfert g1 vers g2, puis `null`

À partir de g1 `{A:20,B:40}`, g2 `{C:50}` :

```text
didUpdate A→g2
  g1.remove(A)             g1={B:40}, G1=40, schedule(g1)=1
  g2.register(A)           g2={C:50,A:⊥}, G2=50
  A publie 20              g2={C:50,A:20}, G2=20, schedule(g2)=1
fin frame                  A/B/C rendent 20/40/20
waves                      callback(g1,A)=0, callback(g1,B)=1
                            callback(g2,A)=1, callback(g2,C)=1
frame sync                 mêmes tailles, aucune nouvelle vague

didUpdate A→null
  g2.remove(A)             g2={C:50}, G2=50, schedule(g2)=1
  A local                  aucun rapport, R_A=L_A=20
fin frame et sync          A/B/C rendent 20/40/50
wave                       callback(g2,A)=0, callback(g2,C)=1
```

Le cas pending décrit plus haut est obligatoire en plus de ce transfert simple.
Il prouve qu'un état monté dans le nouveau groupe n'est jamais rappelé par
l'ancien.

### `didUpdateWidget` avec groupe identique

Le membre reste présent une seule fois et garde son rapport courant jusqu'à la
publication locale suivante. Pour g `{A:20,B:40}` :

- une mise à jour valide de A vers `P_A=30` donne directement
  `reports={A:30,B:40}`, `G=30`, une vague et deux callbacks ;
- une configuration invalide qui lève avant le nouveau `P_A` conserve le
  rapport fini 20. B reste projeté sous 20. Réinitialiser A à `⊥` dans
  `didUpdateWidget` ferait illégalement remonter B à 40 ;
- une erreur rencontrée après publication, pendant projection, conserve au
  contraire le nouveau rapport fini selon la règle non transactionnelle.

Cette distinction tue à la fois le reset systématique du même groupe et un
rollback non spécifié.

### `AutoSizeGroupBuilder`

Capturer l'objet reçu par le builder à chaque rebuild du même `State` doit
donner une seule identité. Changer largeur, texte ou scaler ne recrée pas le
groupe. Retirer le builder de l'arbre puis monter une nouvelle position/clé
crée un nouveau `State` et peut donc donner une identité différente. Le champ
`final _group` de `S5` satisfait déjà cette règle ; c'est un lock parent+tête.

## Fixtures de projection discriminantes

Les tests métriques dérivent leur largeur de deux `Text`/`Text.rich` témoins
indépendants sur le SDK exécuté. Aucune largeur moteur copiée ci-dessous ne doit
devenir un golden arbitraire.

| Fixture | `L/P/G/R` obligatoire | Observation et mutant tué |
|---|---|---|
| Homogène `D_A=D_B={10,20,30,40}`, locaux 40/30, identité | `L=40/30`, `P=40/30`, `G=30`, `R=30/30` | Lock historique parent+tête. |
| Presets disjoints A `{10,20,40}`, B `{10,30}` | `40/30`, `40/30`, `30`, `20/30` | Tue `fontSize=G`, clamp et republication de R. Pompes répétées : jamais 20/20. |
| Preset nearest : A `{10,20,40}`, B `{34}` | `40/34`, `40/34`, `34`, `20/34` | Tue « preset le plus proche », qui choisirait illégalement 40 pour A. |
| Grilles A `10+4k` jusqu'à 30, B `11+5k` jusqu'à 31 | `30/31`, `30/31`, `30`, `30/26` | Tue clamp/interpolation à 30 pour B. |
| Fraction A `{.3,.4,.5}`, B `{.35,.45}` | `.5/.45`, `.5/.45`, `.45`, `.4/.45` | Valeurs exactes des domaines ; aucune tolérance de sortie. |
| Minimum inaccessible A `{10}`, B `{20,30}` | `10/30`, `10/30`, `10`, `10/20` | B peut avoir `E(R_B)>G`; aucun replacement et aucune taille sous 20. |
| Identité A `{30}`, facteur 2 B `{10,15,20}` | `30/20`, `30/40`, `30`, `30/15` | Tue la borne locale seule et toute comparaison logique/effective. Taille finale 30/30. |
| Identité A `{50}`, quadratique B `{10,20,30}` | `50/30`, `50/90`, `50`, `50/20` | Racines finales 50/40, pas 50/50. Run enfant vérifie la vraie composition non linéaire. |
| Quasi égal : A sorties `{5,10,20.000000000000004}`, B P=20 | `L_A=30`, `P_A>20`, `G=20`, `R_A=20` | Racine finale A=10. Tue epsilon effectif et `fontSize=G`. |
| Égal exact : même fixture mais dernière sortie 20 | `L_A=30`, `P_A=G=20`, `R_A=30` | L'égalité inclusive conserve 30 ; tue comparaison stricte. |

Le getter `textScaleFactor` de tous les scalers adversariaux retourne une valeur
trompeuse, par exemple 999. Son compteur doit rester exactement zéro.

### Plateau racine classique

Utiliser `F=20`, `D={10,20,30}`, un run Ahem explicite `S=10` et
`U(x)=min(x,20)`. Les racines effectives des candidats 20 et 30 valent toutes
deux 20, mais le run vaut respectivement 10 et 15. Une largeur témoin entre ces
deux avances impose `L=20`.

Avec `G=20`, le résultat est `R=20`. Une projection qui ne teste que
`E(c)<=G` choisit 30 ; la box du run, et non la seule racine, rend le mutant
rouge. Pendant la projection, un candidat `c>L` doit court-circuiter avant
l'appel à `U(c)`.

### Plateau racine zéro réellement discriminant

Le scaler suivant est monotone non décroissant et conserve un getter trompeur :

```text
U_0(x) = max(0, x - 30)
```

Avec `F=20`, `D={10,20,30}` et un run Ahem explicite `S=100` :

| C | racine `U_0(C)` | entrée run `S*C/F` | taille effective du run |
|---:|---:|---:|---:|
| 10 | 0 | 50 | 20 |
| 20 | 0 | 100 | 70 |
| 30 | 0 | 150 | 120 |

Une largeur témoin entre 70 et 120 impose `L=20`, tandis que les trois racines
forment un plateau à zéro et donnent `P=G=0`. Le résultat obligatoire est
`R=20`, box du run égale au témoin 70.

Cette fixture discrimine trois implémentations :

- `S5` passe directement G comme ratio linéaire et produit une box 0 ;
- la projection à seule borne effective choisit 30 et produit une box 120 ;
- la double borne choisit 20 et produit une box 70.

Elle remplace un « scaler toujours zéro » monostyle, qui ne peut pas forcer un
candidat local inférieur au maximum et ne serait donc pas un vrai test de la
borne locale.

### `overflowReplacement` exclusivement local

Construire A avec `D_A={20}`, un texte Ahem qui ne tient pas au minimum,
`F_A=false`, et B localement fit avec `D_B={30,40}`. Alors :

```text
A : L=20, F=false, P=20, replacement seul monté
B : L=40, F=true,  P=40
G=20
R_B=30 faute de candidat <=20 ; texte B monté, replacement B absent
```

Le `textKey` de A est absent, sa contribution 20 reste active et B ne reçoit ni
20 ni son propre replacement. Exclure A des rapports donnerait B=40 ; utiliser
l'échec de projection comme `F_B` monterait le mauvais replacement.

## Invalides : frontière non transactionnelle

Trois moments sont distingués :

1. Si le fit local ou le calcul de `P_m=U_m(L_m)` rencontre NaN, infini ou une
   valeur négative, aucun nouveau rapport n'est écrit.
2. Après validation, `P_m` peut être écrit et changer `G`.
3. Si la projection rencontre ensuite une sortie invalide sur un autre
   candidat, elle lève `ArgumentError`. Le rapport fini de l'étape 2 reste ;
   aucun invalide n'est stocké et aucun rollback n'est effectué.

Une fixture directe utilise `D_A={10,20,30,40,50}`. Le fit local vide visite
les candidats hauts et publie un `P_A=50` fini. Un voisin impose `G=15`; la
projection descend alors vers un candidat bas pour lequel le scaler retourne
une valeur invalide. Le test vérifie l'`ArgumentError`, puis retire le voisin
sans reconstruire A avec une nouvelle configuration : un troisième membre
permet d'observer que le rapport fini 50 est toujours présent. Si ce montage
black-box devient trop dépendant du traitement d'`ErrorWidget`, un probe privé
sur le coordinateur est obligatoire ; il ne faut pas remplacer la preuve par
une attente de rollback.

Les scalers invalides restent hors du contrat général de convergence. Ce test
ne prétend pas rendre leur fit monotone ; il borne seulement la corruption
d'état en cas d'erreur.

## Complexité et absence d'oscillation

Pour `C` candidats, une dichotomie appelle le prédicat de projection au plus
`ceil(log2(C + 1))` fois. Sur environ `10^12` candidats, la borne est 40. Le
test instrumente la phase de projection séparément du fit local et du rendu.
Il interdit :

- une liste de taille `C` ;
- une boucle sur tous les presets ;
- un appel à `U(c)` lorsque `c>L` a déjà rendu le prédicat faux ;
- une inversion de `U`, une lecture de son getter ou une tolérance effective ;
- un painter ou une publication depuis la projection.

Une optimisation qui restreint d'abord la borne d'indice à `L` peut faire moins
d'appels et reste conforme. Le gate porte donc sur la borne supérieure, les
entrées interdites et la pureté, pas sur un nombre absolu minimal.

Après la dernière publication pertinente d'une époque stable :

1. une seule tâche pending s'exécute ;
2. une seule frame synchronise les membres courants ;
3. `P` et `G` ne changent pas dans cette frame ;
4. aucune autre tâche ou frame n'est planifiée ;
5. une pompe témoin ne change ni tailles, ni rapports, ni compteurs de scaler.

`pumpAndSettle` est interdit comme unique preuve. `hasScheduledFrame` complète
les assertions de tailles, mais ne remplace jamais les compteurs
schedule/run/callback.

## Mutants qui doivent devenir rouges

| Mutant | Fixture minimale qui le tue |
|---|---|
| Donner `G` directement comme `fontSize` ou ratio linéaire | presets disjoints, quadratique, plateau zéro |
| Clamper numériquement `G` entre min/max | grilles différentes et presets disjoints |
| Choisir le preset le plus proche | `{10,20,40}` face à `G=34` |
| Tester seulement `c<=L` | facteur 2 face à identité |
| Tester seulement `E(c)<=G` | plateau classique et plateau zéro |
| Accepter `E(c)=G+1 ULP` | paire quasi égale/exacte |
| Écraser `L` par `R` ou publier `E(R)` | presets disjoints, rebuild inchangé : interdit 20/20 |
| Déduire `F` de la projection | minimum inaccessible avec replacement voisin |
| Exclure le membre en replacement des rapports | fixture replacement : B remonterait à 40 |
| Réutiliser l'ancien rapport à l'inscription | transfert g1→g2 avec limites distinctes |
| Réinitialiser le rapport si `oldGroup==newGroup` | mise à jour invalide avant nouveau P : B ne doit pas remonter |
| Transporter le rapport dans le nouveau groupe | transfert, état `A:⊥` avant sa publication locale |
| Capturer les listeners à la planification | transfert pending `D,A,C`, recorder A 9→9 |
| Vérifier seulement `mounted` | même transfert pending : A est monté dans g2 |
| Notifier avant de retirer le membre | dispose du minimum, callback(A) doit rester 0 |
| Planifier une tâche par changement intermédiaire de `G` | compteurs `2 limitChange`, mais `1 schedule/1 run` |
| Capturer une ancienne valeur de `G` dans la tâche | remontées `10/20→30/40`, frame sync finale 30/30 |
| Laisser pending vrai après le run ou faux trop tôt | frame témoin / seconde époque : tâche perdue ou vague supplémentaire |
| Stocker NaN/infini/négatif dans reports | invalides avant P et pendant projection |
| Recherche linéaire ou domaine matérialisé | domaine virtuel `≈10^12`, au plus 40 prédicats |

## Tests parent rouges et locks déjà verts

La preuve rouge/verte se formule par assertion, pas par fichier ou famille
entière.

### Assertions discriminantes rouges sur `S5`

- A rend 20, pas 30, dans les presets disjoints ;
- B rend 26, pas 30, sur les grilles différentes ;
- le membre quadratique rend une racine 40, pas 50 ;
- la sortie `G+1 ULP` est rejetée ;
- le plateau racine zéro produit la box 70, pas 0 ;
- le voisin de minimum inaccessible reste dans son domaine ;
- la coalescence planifie et exécute une seule microtâche, pas deux.

### Locks verts sur `S5` et sur la tête

- séquence homogène historique de réduction/remontée ;
- `overflowReplacement` dépend du fit local et le membre reste inscrit ;
- retrait/dispose : aucune exception, survivant en 20 puis 40 après une frame ;
- transfert simple et passage à `null` retirent l'ancien rapport ;
- transfert pendant vague pending ne rappelle pas A depuis l'ancien groupe ;
- `AutoSizeGroupBuilder` conserve son instance dans le même `State` ;
- une frame témoin n'ajoute aucun appel de scaler.

Un journal de revue doit associer chaque assertion discriminante à son échec
sur `c9a1adc` pour la cause visée. Il ne doit pas fabriquer un rouge en inversant
une attente historique correcte.

## Points dangereux et limites

- `G` est une borne, pas une promesse d'égalité. Si aucun candidat n'est
  autorisé, `E(R_m)>G` est le résultat voulu ; ce n'est ni un overflow local ni
  une oscillation.
- Une frame de publication peut être asymétrique. Les valeurs intermédiaires
  exactes ne sont normatives que si l'ordre de layout est contrôlé ; la frame de
  synchronisation, elle, l'est toujours.
- Le retrait pendant `dispose` se produit avant `super.dispose`, donc `mounted`
  peut encore être vrai dans le corps de désinscription. La sûreté vient du
  retrait de la map et du callback différé, pas d'un test prématuré de
  `mounted`.
- Plusieurs callbacks `setState` du même membre avant une frame ne produisent
  qu'un rebuild. Ni les tailles, ni le nombre de frames, ni le compteur global
  de scaler ne prouvent seuls la coalescence des callbacks.
- Un groupe pending doit lire ses membres et sa limite à l'exécution. Capturer
  la map ou `G` crée des callbacks inter-groupes ou rejoue une valeur périmée.
- Le rapport conservé après une mise à jour invalide dans le même groupe est la
  dernière publication finie, pas `⊥`. Dans un nouveau groupe, le membre reste
  au contraire `⊥` tant qu'aucun nouveau local valide n'a été publié.
- Le snapshot de presets appartient au build courant. La liste source n'est
  jamais triée ou mutée ; un rebuild explicite prend un nouveau snapshot selon
  le lot 2.
- Les métriques de plateau utilisent des boxes de runs et des témoins de la
  même pin. Une racine seule ne distingue pas deux candidats sur un plateau.
- Les contraintes qui changent parce qu'un parent réagit à la taille de ses
  enfants ouvrent une nouvelle époque. La preuve d'absence d'oscillation fixe
  contraintes, configuration et appartenance.
- Dry layout, intrinsics, `WidgetSpan` et publication depuis une passe
  spéculative restent hors lot 5.

## Contraintes d'acceptation du challenger

Le lot 5 peut être accepté seulement si :

1. les tuples `L/P/G/R` de toutes les fixtures sont assertés par candidat ou
   par métrique indépendante, jamais par inspection du seul nombre de `Text` ;
2. les assertions discriminantes listées plus haut sont rouges sur
   `c9a1adc` et vertes sur la tête, tandis que les locks historiques sont verts
   sur les deux ;
3. le plateau classique et le plateau racine zéro tuent séparément la perte de
   borne locale, la linéarisation et le passage direct de `G` ;
4. aucun résultat n'est sous le minimum, hors presets/grille ou au-dessus de
   `L`, et la seule exception à `E(R)<=G` est l'ensemble autorisé vide ;
5. tout rapport stocké est fini, non négatif et égal à `E(L)` ; aucune valeur
   dérivée de `R` ou du replacement n'est publiée ;
6. deux changements synchrones de `G` donnent exactement une planification,
   un run et un callback par membre courant, prouvés par instrumentation de
   phase ;
7. retrait, transfert, `null` et dispose laissent zéro callback de l'ancien
   groupe vers le membre, y compris quand il reste monté dans un nouveau
   groupe ;
8. après la dernière publication, une frame suffit à synchroniser, puis la
   frame témoin ne change aucun compteur et aucune frame ne reste programmée ;
9. la projection respecte la borne logarithmique, ne matérialise aucun domaine
   et ne lit jamais `textScaleFactor` ;
10. l'erreur pendant projection suit la sémantique non transactionnelle
    explicitée ici : `P` fini conservé, aucune valeur invalide stockée ;
11. les probes temporaires de compteurs sont supprimés, le diff ne contient
    aucune API ou hook de test public et aucun fichier produit hors lot 5 ;
12. format, analyse fatale, tests ciblés puis suite complète passent sur
    Flutter 3.41.0 et 3.47.2 exacts.

Toute republication de `R`, sortie étrangère au domaine, remontée au-dessus de
`L` sur un plateau, callback de l'ancien groupe vers un membre transféré,
callback après dispose, seconde vague à entrée stable ou valeur invalide dans
le minimum impose le revert du lot 5.
