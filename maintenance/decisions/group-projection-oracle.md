# Oracle de projection des groupes hétérogènes — lot 5

Date : 2026-09-01

Base inspectée : `S5` / `eb6f475b7b3880e3c0a5d0d7750a1ccc0bf0fec9`

Oracles amont lus :

- domaine des candidats : `2346673` ;
- configuration effective : `8d9e2e2`, lu depuis
  `codex/challenge-effective-text` sans merge ;
- RichText : `82df7b6`.

Objet : fixer les unités, l'état, la projection, le cycle de vie et les tests
du lot 5. Ce document ne prescrit aucun correctif produit et n'autorise ni
render object, ni intrinsics, ni dry layout, ni nouvelle API publique.

## Verdict

Un groupe hétérogène ne peut pas imposer directement son minimum comme
`fontSize` logique. Sa valeur commune est une **borne de taille racine
effective**, pas un candidat appartenant nécessairement au domaine d'un
membre.

Pour chaque membre, le flux normatif est strictement le suivant :

1. chercher le résultat local sans lire la limite de groupe ;
2. conserver le candidat logique local et son booléen de fit ;
3. publier `userScaler.scale(localCandidate)` au groupe ;
4. lire la limite effective courante du groupe ;
5. projeter cette limite sur le domaine propre du membre, sans modifier le
   résultat local ni la publication ;
6. rendre le candidat projeté, ou décider le replacement uniquement depuis le
   booléen de fit local.

La projection choisit le plus grand candidat du membre qui satisfait les deux
bounds inclusives :

```text
candidate <= localCandidate
effective(candidate) <= groupLimit
```

La première borne est indispensable avec un scaler à plateau. La seconde est
indispensable avec des scalers ou domaines différents. Si aucun candidat ne
satisfait la limite effective, le membre rend son plus petit candidat : la
divergence est volontaire et vaut mieux qu'une taille sous le minimum ou
étrangère aux presets.

Sous les hypothèses de fit monotone et de scaler monotone non décroissant, la
projection est une dichotomie en `O(log C)`. Comme les publications ne
dépendent jamais des projections, une entrée stable ne peut pas créer de cycle
de réduction ou de remontée.

## Modèle d'unités et d'état

### Unités d'un membre

Pour un membre `m`, les symboles suivants sont normatifs.

- `D_m = [d_0, ..., d_(C-1)]` est le snapshot fini, strictement croissant du
  domaine logique de `_CandidateSet`. Les règles de grille, terminal exact,
  quasi-dédoublonnage et presets sont celles de l'oracle du lot 2.
- `U_m` est le scaler utilisateur résolu par le lot 3 : explicite, sinon ancien
  facteur linéaire, sinon scaler ambiant.
- `E_m(c) = U_m.scale(c)` est la taille **racine effective** du candidat
  logique `c`. Pour une référence positive, elle est aussi
  `candidateScaler(c).scale(reference)`. Pour la référence zéro du lot 4, le
  parent synthétique reçoit `c` et sa racine effective reste `U_m.scale(c)`.
- `(L_m, F_m)` est le résultat de la recherche locale sans groupe. Si au moins
  un candidat tient, `L_m` est le plus grand qui tient et `F_m == true`. Si
  aucun ne tient, `L_m == d_0` et `F_m == false`.
- `P_m = E_m(L_m)` est la seule valeur que le membre publie.
- `G` est la limite effective du groupe : le minimum des `P_m` courants.
- `R_m` est le candidat logique finalement rendu après projection.

`L_m` et `R_m` sont donc des tailles logiques du domaine de `m`. `P_m` et `G`
sont des tailles racines effectives. Comparer `G` directement à un minimum,
maximum ou pas logique, ou donner `G` comme `fontSize`, mélange les unités.

Pour RichText, `P_m` décrit seulement la racine. Les runs conservent la
composition du lot 4 : pour une référence positive `F` et une taille de run
`S`, leur taille effective est `U_m.scale(S * R_m / F)`. Le groupe ne publie
ni le plus grand run, ni un ratio, ni le getter d'estimation
`TextScaler.textScaleFactor`.

### État privé du membre

Le membre conserve au minimum, conceptuellement :

```text
membership       groupe courant ou aucun
candidateSet     snapshot du domaine courant
localResult      (L_m, F_m)
publishedSize    P_m si le résultat local courant a été publié
groupLimit       dernier G observé pour le rendu
renderCandidate  R_m, dérivé et non publié
```

Un changement de contraintes, texte, style effectif, domaine, scaler,
segmentation ou configuration de paragraphe invalide le résultat local. Une
notification qui ne change que `G` invalide uniquement la projection. Elle ne
transforme pas `R_m` en nouveau `L_m`.

La mise en cache exacte est un choix d'implémentation. L'invariant observable
est que toute nouvelle publication provient d'un résultat **local** valide et
jamais du candidat projeté. Recalculer le même résultat local pendant un
rebuild est permis ; écrire `E_m(R_m)` dans le rapport ne l'est pas.

### État privé du groupe

Le groupe contient conceptuellement :

```text
reports             membre inscrit -> P_m ou « non publié »
groupLimit          minimum des rapports publiés, +infinity si aucun
notificationPending booléen de coalescence
```

Le marqueur « non publié » peut être représenté en interne par
`double.infinity`, mais aucune sortie réelle de scaler infinie n'est valide.
Une inscription ne réutilise jamais le rapport d'une ancienne appartenance.

Le groupe compare et stocke des valeurs effectives finies et non négatives.
NaN, les infinis et les valeurs négatives sont rejetés par le wrapper de scaler
avant toute publication. `-0.0` et `0.0` sont égaux ; préserver leur bit de
signe n'est pas un contrat de groupe.

## Projection normative

### Ensemble de décision

Après la publication locale, définir :

```text
S_m = { c dans D_m | c <= L_m et E_m(c) <= G }

R_m = max(S_m), si S_m n'est pas vide
R_m = d_0, sinon
```

Les deux comparaisons sont exactes et inclusives. La tolérance relative du lot
2 sert uniquement à construire un domaine logique strict et à fusionner ses
quasi-doublons. Elle ne s'applique pas aux sorties effectives : une sortie d'un
ULP au-dessus de `G` est au-dessus de la limite et doit être rejetée.

Le cas `S_m` vide n'est pas un overflow local. Il signifie seulement que le
minimum du membre est trop grand, dans son unité effective, pour atteindre la
limite d'un autre membre. `R_m == d_0` est alors rendu et peut rester
strictement supérieur à `G` en taille effective.

### Dichotomie

Le prédicat de projection sur le domaine ascendant est :

```text
allowed(c) = c <= L_m && E_m(c) <= G
```

Il forme un préfixe vrai puis faux parce que :

- `D_m` est strictement croissant ;
- `L_m` est une valeur exacte de `D_m` ;
- `E_m` est supposée monotone non décroissante ;
- un plateau conserve l'ordre, même s'il ne le rend pas strict.

La même dichotomie par indices entiers que celle du lot 2 peut donc retourner
le dernier `allowed`. Elle retourne `d_0` avec un indicateur de projection faux
si le préfixe est vide. Le test `c <= L_m` doit court-circuiter l'appel à
`E_m(c)` pour un candidat déjà au-dessus de la borne locale.

Pour `C` candidats, la projection effectue au plus un nombre logarithmique
d'accès au domaine et d'appels racine au scaler. Elle :

- ne matérialise aucune liste de candidats ;
- n'énumère pas les presets pour trouver le plus proche ;
- ne relance aucun `TextPainter` et aucun prédicat typographique ;
- ne calcule pas l'inverse d'un scaler ;
- ne lit jamais `TextScaler.textScaleFactor` ;
- ne publie rien et ne planifie aucune microtâche.

Le fitter local garde sa propre complexité `O(log C)`. Le coût total de choix
reste donc `O(log C)`, plus le rendu final. Le groupe peut recalculer son
minimum en `O(M)` quand le membre qui détenait le minimum remonte ou disparaît ;
introduire un tas ou une API de priorité pour réduire ce coût n'est pas requis
par le lot.

### Publication et ordre d'exécution

Pour une passe locale valide, l'ordre logique est :

```text
local = candidateSet.findLargestThatFits(localFitPredicate)
published = checkedEffectiveSize(local.value)
group.publish(member, published)
limit = group.currentLimit
projection = candidateSet.findLargestThatFits(
  candidate =>
    candidate <= local.value &&
    checkedEffectiveSize(candidate) <= limit,
)
renderCandidate = projection.value
```

La publication met `G` à jour synchroniquement. Le membre courant projette donc
avec la limite la plus récente, y compris s'il vient lui-même de l'abaisser.
Les autres membres observent cette limite à la notification coalescée.

Si le membre n'appartient à aucun groupe, `R_m == L_m`. Si le groupe ne possède
encore aucun autre rapport, sa propre publication donne `G == P_m`, donc
`R_m == L_m`, y compris sur un plateau grâce à la borne locale.

### Fit local et `overflowReplacement`

`overflowReplacement` dépend exclusivement de `F_m` :

- si `F_m == false` et qu'un replacement existe, monter le replacement ;
- si `F_m == false` sans replacement, rendre `d_0` comme aujourd'hui ;
- si `F_m == true`, rendre `R_m`, même si `S_m` était vide et que
  `E_m(d_0) > G`.

Une projection plus petite ne transforme pas un fit local vrai en échec sous
l'hypothèse de fit monotone. Inversement, atteindre la limite effective ne rend
pas magiquement fit un minimum local qui débordait. Le booléen renvoyé par la
dichotomie de projection ne remplace donc jamais `F_m`.

Un membre qui affiche son replacement conserve son appartenance et publie
`E_m(d_0)`, puisque `d_0` est le résultat fallback de la recherche locale.
Exclure les membres en overflow du minimum de groupe serait une nouvelle
politique incompatible avec le comportement historique.

## Invariants bloquants

1. **Domaine propre.** `R_m` appartient exactement à `D_m`. Il n'est jamais
   une interpolation, un candidat d'un voisin, une limite effective castée en
   taille logique ou une valeur sous le minimum.
2. **Fit local indépendant.** La recherche de `(L_m, F_m)` ne lit pas `G` et ne
   mesure jamais le texte à partir de `R_m` d'une passe précédente.
3. **Double borne.** `R_m <= L_m`. Si l'ensemble n'est pas vide,
   `E_m(R_m) <= G`; s'il est vide, `R_m == d_0` et la divergence est assumée.
4. **Publication locale.** Le rapport vaut toujours `E_m(L_m)`, même lorsque
   le rendu utilise un autre candidat ou un replacement.
5. **Projection pure.** Calculer ou rendre `R_m` ne change ni `L_m`, ni `F_m`,
   ni `P_m`, ni `G`, et ne planifie aucune notification.
6. **Unité effective.** Le minimum de groupe ne contient que des tailles
   racines effectives validées. Aucun candidat logique ou facteur estimé n'y
   entre.
7. **Plateaux distincts.** Deux candidats restent distincts dans l'état et dans
   l'égalité du scaler composé même si `E_m` leur donne momentanément la même
   valeur.
8. **Comparaison exacte.** Aucune tolérance ne permet à une taille effective
   supérieure à `G` de passer. Une égalité exacte passe et ne déclenche pas de
   nouvelle notification.
9. **Replacement local.** Le groupe ne choisit pas le replacement et son
   incapacité à atteindre `G` n'est pas un overflow local.
10. **Retrait immédiat.** Un membre retiré cesse immédiatement de contribuer au
    minimum et ne peut plus être notifié par une microtâche de son ancien
    groupe.
11. **Coalescence.** Plusieurs changements de `G` avant l'exécution de la
    microtâche produisent au plus une vague de notification utilisant la
    dernière valeur.
12. **Absence d'oscillation.** À entrées et appartenance stables, une vague de
    projection ne change aucun rapport ; elle ne peut donc en provoquer une
    autre.

## Cycle de vie et notifications

### Inscription et publication initiale

`initState` inscrit le membre comme « non publié ». La première mesure locale
valide remplace ce marqueur par `P_m`. Un membre non publié n'abaisse pas le
minimum d'un groupe déjà actif.

Une baisse ou une remontée de `G` marque la notification comme pending et
planifie au plus une microtâche. La microtâche :

1. consomme le marqueur pending ;
2. prend les membres **encore présents** au moment de son exécution, pas une
   liste capturée lors de sa planification ;
3. vérifie avant chaque callback que le membre est toujours inscrit dans ce
   groupe et monté ;
4. demande un rebuild/relayout sans transmettre un candidat logique étranger.

Une microtâche en retard observe toujours le minimum courant. Elle ne rejoue
pas une ancienne valeur capturée.

### `didUpdateWidget`

Si `oldGroup == newGroup`, le membre reste inscrit une seule fois. Un
changement de domaine, scaler, texte ou contraintes produira un nouveau
résultat local et une nouvelle publication lors de la mesure correspondante.

Si `oldGroup != newGroup`, l'ordre obligatoire est :

1. retirer le membre et son rapport de l'ancien groupe ;
2. recalculer immédiatement le minimum de l'ancien groupe ;
3. l'inscrire sans rapport dans le nouveau groupe, s'il existe ;
4. calculer puis publier son résultat local courant dans le nouveau groupe ;
5. projeter uniquement avec la limite du nouveau groupe.

Une microtâche déjà pending dans l'ancien groupe ne doit plus voir ce membre.
Une notification de l'ancien groupe ne peut donc pas provoquer une publication
dans le nouveau.

### Retrait et dispose

Retirer un membre de l'arbre appelle la désinscription avant la fin de son
`dispose`. Son rapport disparaît immédiatement. Si c'était le dernier minimum,
le groupe remonte à la prochaine valeur ou à `double.infinity` s'il est vide.

La remontée notifie uniquement les membres restants. Si la désinscription a
elle-même planifié la microtâche, le membre est déjà démonté quand elle
s'exécute : aucun `setState` tardif, aucune exception et aucune référence au
membre ne sont permis. Un groupe vide n'a personne à notifier ; planifier une
microtâche vide est inutile mais ne doit pas être observable.

## Cas d'oracle

Les domaines ci-dessous sont écrits dans leur ordre interne ascendant. Sauf
mention contraire, tous les candidats locaux tiennent et les scalers sont
l'identité.

| Cas | Rapports et limite | Résultat obligatoire |
|---|---|---|
| Groupe homogène : `D_A=D_B={10,20,30,40}`, `L_A=40`, `L_B=30` | `P_A=40`, `P_B=30`, `G=30` | `R_A=R_B=30` ; historique inchangé. |
| Presets disjoints : `D_A={10,20,40}`, `D_B={10,30}`, locaux aux maxima | `40`, `30`, donc `G=30` | `R_A=20`, `R_B=30` ; ne jamais inventer 30 pour A ni republier 20. |
| Minima incompatibles : `D_A={10}`, `D_B={20,30}`, `L_B=30` | `10`, `30`, donc `G=10` | `R_A=10`, `R_B=20`; B diverge au-dessus de `G` sans replacement. |
| Grilles différentes : `D_A={10,14,18,22,26,30}`, `D_B={11,16,21,26,31}` | locaux 30 et 31, `G=30` | `R_A=30`, `R_B=26`. |
| Grille fractionnaire : `D_A={.3,.4,.5}`, `D_B={.35,.45}` | locaux `.5` et `.45`, `G=.45` | `R_A=.4`, `R_B=.45`, valeurs exactes de leurs domaines. |
| Scalers linéaires différents : `D_A={10,20,30}`, `U_A(x)=x`; `D_B={10,15,20}`, `U_B(x)=2x` | locaux 30/20, rapports 30/40, `G=30` | `R_A=30`, `R_B=15`; tailles effectives finales 30/30. |
| Scaler non linéaire : `D_A={10,20,30}`, `U_A(x)=x²/10`; `D_B={50}`, identité | rapports 90/50, `G=50` | `R_A=20` avec effective 40, `R_B=50`; aucune inversion ou linéarisation du scaler. |
| Sorties quasi égales : A a les sorties `{5,10,20.000000000000004}` sur `{10,20,30}` et B publie exactement 20 | `G=20` | A rejette 30 et rend 20. Si sa dernière sortie vaut exactement 20, A rend 30. |
| Scaler nul : `E_A(c)=0` pour tout candidat et `L_A=20` dans `{10,20,30}` | `G=0` | `R_A=20`, jamais 30 : le plateau n'autorise pas de dépasser le fit local. |
| Aucun fit local : A a `D_A={20,30}`, résultat `(20,false)` ; B publie 40 | `P_A=20`, `G=20` | A affiche son replacement ; B se projette vers son plus grand candidat effectif `<=20`. |

### Cas plateau RichText discriminant

Le test central utilise :

```text
référence racine F = 20
domaine D_A = {10, 20, 30}
U_A(x) = min(x, 20)
run enfant explicite S = 10
```

Les valeurs sont :

| Candidat | Racine `U_A(C)` | Run enfant `U_A(S*C/F)` |
|---:|---:|---:|
| 10 | 10 | 5 |
| 20 | 20 | 10 |
| 30 | 20 | 15 |

Une largeur témoin située entre les métriques des runs enfant 10 et 15 force
`L_A=20` : le candidat 20 tient et 30 échoue, alors que leurs racines effectives
sont égales. Avec `G=20`, une projection fondée sur la seule seconde borne
choisirait illégalement 30. La double borne impose `R_A=20`.

Ce cas est préférable à un texte racine monostyle : sur le plateau, ses
métriques pourraient être identiques et ne révéleraient pas le dépassement du
candidat local. Le test compare les boxes/métriques d'un vrai
`RenderParagraph` à des `Text.rich` témoins construits indépendamment selon
l'oracle du lot 4.

### Remontée, transfert et coalescence

| Transition | État initial | État final obligatoire |
|---|---|---|
| Élargissement | rapports A/B `20/40`, rendus `20/20`; A publie ensuite 50 | `G` passe à 40 ; A et B rendent leur projection sous 40 après au plus une vague. |
| Retrait du minimum | A/B `20/40`, puis A est retiré | le rapport de A disparaît, `G=40`, B remonte à 40 après une vague ; aucune taille transitoire ne devient un rapport. |
| Transfert | groupe 1 : A/B `20/40`; groupe 2 : C `50`; A passe au groupe 2 | groupe 1 : `G=40`, B rend 40 ; groupe 2 : `G=20`, A rend 20 et C se projette sous 20. |
| Passage à `group:null` | A contraignait B à 20 | ancien groupe remonte selon ses membres restants ; A rend son résultat local et n'est plus notifié par l'ancien groupe. |
| Deux remontées dans une frame | anciens rapports A/B `10/20`, nouveaux `30/40` | `G` peut valoir transitoirement 20 puis 30, mais une seule vague rend finalement les deux sous 30. |
| Dispose avant microtâche | A, minimum 20, est démonté alors que sa désinscription planifie la remontée de B | la microtâche ne rappelle jamais A ; B remonte, aucune exception `setState() called after dispose()`. |

## Convergence et absence d'oscillation

### Preuve

Pour une époque où contraintes, configuration et appartenance sont stables :

1. chaque `P_m` est une fonction du fit local seulement ;
2. après publication de tous les résultats locaux courants,
   `G = min(P_m)` est fixe ;
3. chaque `R_m` est une fonction pure de `(D_m, L_m, U_m, G)` ;
4. rendre ou recalculer `R_m` ne modifie aucun `P_m` ;
5. une notification de projection ne peut donc changer `G` ni en planifier une
   autre.

Une implémentation qui publie `E_m(R_m)` brise l'étape 1. Dans le cas de
presets disjoints `{10,20,40}` et `{10,30}`, elle ferait passer `G` de 30 à 20,
puis réduirait le second membre à 20 : c'est une convergence vers un mauvais
point fixe, pas une synchronisation valide.

### Borne de frames

Une « époque de publication » commence avec une mutation externe ou un
changement d'appartenance et se termine lorsque tous les membres concernés ont
publié leur résultat local courant.

- Pendant la frame de publication, `G` peut baisser ou remonter plusieurs fois
  selon l'ordre de layout des membres.
- Ces changements produisent au plus une microtâche de notification pending.
- Après cette microtâche, au plus **une frame de synchronisation** est nécessaire
  pour que tous les membres courants rendent la projection du dernier `G`.
- Cette frame ne change aucun rapport à entrées stables et ne planifie donc pas
  une nouvelle vague.

La borne observable est ainsi au plus deux frames wet à partir d'une mutation
traitée dans la première : la frame de publication, puis une frame de
synchronisation. À partir de la dernière publication pertinente, la borne est
une microtâche coalescée plus une frame.

Une mutation externe survenant pendant cette fenêtre ouvre une nouvelle époque
et ne constitue pas une oscillation. Des membres volontairement reconstruits
sur des frames différentes ont chacun leur époque ; aucune borne globale ne
peut les rendre simultanés avant leur dernière publication.

Les tests ne doivent pas employer seulement `pumpAndSettle`, qui masquerait une
boucle ou plusieurs frames inutiles. Ils pompent explicitement :

1. la frame de mutation/publication ;
2. une seule frame de synchronisation ;
3. une frame témoin supplémentaire, où tailles, compteurs de scaler et état de
   scheduling restent inchangés.

## Tests bloquants

Tous les fichiers touchés utilisent `group()` et des noms « should ... ». Les
tests métriques chargent une fonte déterministe. Les scalers de test sont
déterministes, monotones non décroissants et donnent un
`textScaleFactor` trompeur afin qu'une lecture interdite du getter échoue.

Les cas non linéaires et RichText ne lisent pas le helper historique
`effectiveFontSize`. Ils comparent le `RenderParagraph` réel — `textSize`,
line metrics et boxes de sélection pertinentes — à un `Text`/`Text.rich`
témoin utilisant une composition candidate indépendante. Les contraintes sont
choisies entre les métriques témoins de deux candidats, pas à partir d'une
valeur pixel fragile copiée du moteur testé.

### P0 — requis avant merge

1. **Historique homogène.** Conserver les séquences actuelles de réduction et
   de remontée avec deux membres, domaine entier et scaler linéaire. Vérifier
   les résultats, pas le seul nombre de `Text` trouvés.
2. **Min/max/pas.** Couvrir minima 10/20, maxima différents, domaines
   `10+4k` et `11+5k`, puis `.3/.1` face à `.35/.1`. Chaque résultat doit être
   une valeur exacte du domaine du membre et respecter `R_m <= L_m`.
3. **Presets disjoints.** Obtenir 20/30 avec `{10,20,40}` et `{10,30}`. Pomper
   plusieurs fois et provoquer un rebuild sans changement : le résultat ne
   doit jamais s'effondrer à 20/20. Ce test est la preuve black-box qu'une
   projection n'est pas republiée.
4. **Presets et sorties quasi égales.** Avec une sortie effective
   `20.000000000000004` face à `G=20`, rejeter le candidat ; avec une sortie
   exactement égale, le conserver. Aucun epsilon effectif n'est toléré.
5. **Scalers différents.** Tester identité contre facteur 2 et obtenir les
   candidats logiques 30/15 pour une taille effective commune 30. Tester aussi
   `U(x)=x²/10`, avec résultats 20/50 et tailles effectives 40/50.
6. **Plateau et borne locale.** Utiliser la fixture RichText `F=20`, enfant
   explicite 10 et `U(x)=min(x,20)`. Forcer `L=20`, `F_m=true`, `G=20`, puis
   prouver par les boxes du run que `R=20`, jamais 30.
7. **Plateau intégral/zéro.** Avec plusieurs candidats donnant tous zéro,
   prouver que la projection conserve le candidat local au lieu de remonter au
   maximum du domaine. Des pompes supplémentaires ne doivent rien changer.
8. **Minimum inaccessible.** Faire publier 10 par un membre et donner à l'autre
   un domaine de minimum 20 avec fit local vrai. Le second rend 20, ne reçoit
   ni 10 ni replacement, et ne republie pas 20 comme nouveau minimum commun.
9. **Replacement local.** Faire échouer le plus petit candidat d'un membre :
   son `textKey` disparaît, son replacement est seul monté, son minimum
   effectif continue de contraindre les autres. Un voisin localement fit ne
   montre jamais son replacement à cause de la projection seule.
10. **Remontée bornée.** Élargir l'ancien minimum, puis retirer l'ancien
    minimum. Dans chaque scénario, vérifier l'état après la frame de mutation,
    après une seule frame de synchronisation et après une frame témoin sans
    changement.
11. **`didUpdateWidget`.** Avec des clés stables, garder le même groupe en
    changeant domaine/scaler, puis transférer un membre de `g1` à `g2`, puis à
    `null`. Vérifier les deux limites par les rendus des membres restants et
    l'absence de contribution dans l'ancien groupe.
12. **Retrait et dispose avant microtâche.** Démonter le membre minimum dans la
    frame qui appelle sa désinscription. La microtâche de remontée s'exécute
    après son `dispose` : `tester.takeException()` reste nul, le membre n'est
    pas rappelé et les survivants convergent en une frame.
13. **Coalescence et absence d'oscillation.** Faire passer deux rapports de
    `10/20` à `30/40` dans la même frame. La limite finale est 30 après une
    seule vague. Une frame supplémentaire n'appelle plus le scaler, ne change
    aucun résultat et ne laisse aucune frame programmée.
14. **Group builder.** Prouver que `AutoSizeGroupBuilder` conserve la même
    instance de groupe à travers les rebuilds de son `State`, puis répéter un
    cas de remontée. Recréer une nouvelle position/clé peut créer un nouveau
    builder et n'est pas la même garantie.
15. **Entrées invalides du scaler.** Une sortie racine NaN, infinie ou négative
    lève `ArgumentError` avant publication. Une valeur invalide rencontrée
    pendant la projection ne doit jamais empoisonner le minimum du groupe.

### P1 — preuves de complexité et robustesse

- Sur un domaine virtuel d'environ `10^12` candidats, instrumenter séparément
  la projection avec un compteur de `E_m`. Elle reste sous la borne
  logarithmique attendue, sans collection proportionnelle au domaine. Si les
  helpers privés empêchent un test permanent sans exposer d'API, joindre un
  probe temporaire rouge/vert puis le supprimer, comme pour l'oracle du lot 2.
- Instrumenter temporairement les écritures de rapports et les callbacks de
  groupe : une vague de projection n'écrit aucune valeur dérivée de `R_m`, et
  plusieurs changements synchrones de `G` donnent un seul callback par membre
  encore inscrit.
- Répéter les tests P0 sur Flutter 3.41.0/Dart 3.11.0 et Flutter 3.47.2/Dart
  3.13.2 exacts. Les métriques attendues proviennent des témoins de la même pin.
- Vérifier que la liste de presets source n'est ni triée ni mutée et qu'un
  rebuild explicite prend le nouveau snapshot conformément au lot 2.

### Rouge attendu sur le parent

La baseline actuelle stocke une seule valeur `_fontSize`, puis la donne
directement à tous les `Text`. Elle doit échouer au minimum sur :

- minima et presets incompatibles, car elle rend une taille hors domaine ;
- scalers différents/non linéaires, car elle mélange candidat et taille
  effective ;
- le scaler plateau RichText, faute de borne locale explicite ;
- le changement de groupe, insuffisamment asserté par le harness historique ;
- le test de non-publication, si le premier correctif naïf republie la
  projection.

Un test rouge uniquement parce que l'API `textScaler` du lot 3 manque sur une
base trop ancienne ne prouve rien sur le lot 5. Les régressions doivent être
démontrées sur le parent direct intégrant les lots 2 à 4.

## Pièges de mise en œuvre

- Passer `group._fontSize` à `_buildText` comme s'il s'agissait d'un candidat
  logique.
- Clamper `G` entre min et max : un clamp peut produire une taille absente de
  la grille ou des presets.
- Trouver le preset numériquement le plus proche au lieu du plus grand autorisé
  sous les deux bornes.
- Appliquer seulement `E_m(c) <= G` : un plateau peut alors remonter au-dessus
  du candidat qui tenait localement.
- Appliquer seulement `c <= L_m` : des scalers différents ne respectent plus la
  limite effective.
- Inverser `U_m`, lire son getter de facteur ou le remplacer par un scaler
  linéaire. Un scaler non linéaire n'a pas d'inverse public fiable.
- Comparer `G` au candidat logique avant scaling, ou comparer `c` à `P_m` après
  scaling.
- Employer la tolérance du domaine pour accepter une sortie effective un ULP
  trop grande.
- Fusionner ou mettre en cache deux candidats par leur seule sortie effective.
  Leurs runs RichText et leur identité de scaler composé peuvent différer.
- Écraser `L_m` avec `R_m`, puis republier au rebuild : cela crée une réduction
  en cascade et empêche la remontée correcte.
- Faire dépendre le prédicat local de `G` ou mesurer seulement le texte déjà
  projeté : le système devient une boucle de feedback.
- Déduire `overflowReplacement` de l'échec à atteindre `G`, ou le masquer parce
  qu'un autre membre a une taille plus petite.
- Retirer un membre en publiant d'abord l'infini puis conserver sa référence
  dans un snapshot de listeners capturé à la planification.
- Réinitialiser un rapport lors d'un `didUpdateWidget` où le groupe est
  identique, ou au contraire transporter le rapport dans un nouveau groupe.
- Appeler `setState` sur un état démonté, notifier un membre transféré depuis
  son ancien groupe ou conserver une closure de publication après `dispose`.
- Planifier une microtâche par variation intermédiaire au lieu de coalescer la
  dernière limite.
- Utiliser une recherche linéaire ou matérialiser un domaine régulier pour
  simplifier la projection.
- Laisser NaN entrer dans la carte : les comparaisons et le minimum cessent
  alors d'avoir un ordre exploitable.

## Exclusions et frontières fermes

Sont hors du lot 5 et de cet oracle :

- intrinsics, `computeDryLayout`, dry baseline, cache dry/wet et render object,
  réservés au lot 9 ;
- mesure, layout et scaling automatique des `WidgetSpan`, réservés au lot 10 ;
- toute publication depuis une passe dry ou intrinsèque future ; le lot 9
  devra recevoir un snapshot immuable de `G`, sans redéfinir la politique du
  présent oracle ;
- scaler personnalisé décroissant, non déterministe ou à sorties invalides ;
  prouver sa monotonie globale à runtime est hors contrat ;
- prédicat de fit typographique non monotone ;
- égalité effective forcée entre membres dont les domaines ne peuvent pas
  représenter la même valeur ; `G` est une borne, pas une promesse d'égalité ;
- nouvelle API de groupe, callback de taille, facteur individuel, thème de
  groupe, stratégie d'overflow ou accès public à la limite ;
- heap, arbre équilibré ou optimisation spéculative du minimum des membres ;
- changement du domaine numérique, de la référence zéro, de la segmentation
  RichText, des métadonnées ou de la politique de fonte des lots 2 à 4 ;
- `pumpAndSettle` comme seule preuve de convergence ;
- README, changelog, démo, publication ou mutation distante.

## Gate du lot 5

Le lot est acceptable seulement si :

- les quinze familles P0 sont rouges pour leur cause sur le parent direct et
  vertes sur la tête ;
- aucun candidat rendu ne sort du domaine propre du membre ou ne dépasse son
  candidat local ;
- toute taille effective rendue respecte `G`, sauf le cas explicitement testé
  où le minimum du membre ne peut pas l'atteindre ;
- le rapport de chaque membre reste `E_m(L_m)` à travers projections,
  replacements et rebuilds ;
- les scalers non linéaires, plateaux, sorties exactes/quasi égales et runs
  RichText utilisent des témoins métriques indépendants ;
- retrait, transfert et dispose ne laissent ni rapport, ni callback, ni état
  démonté dans l'ancien groupe ;
- la convergence respecte une microtâche coalescée et une frame de
  synchronisation après la dernière publication ;
- l'instrumentation de complexité confirme la dichotomie et est retirée si
  elle n'appartient pas au harness permanent ;
- format, analyse fatale, suite ciblée puis complète passent sur les deux pins
  SDK ;
- le diff produit du futur lot ne contient ni nouvelle API, ni dry/intrinsics,
  ni `WidgetSpan`, ni changement de politique des oracles amont.

Toute publication d'un candidat projeté, toute sortie hors domaine, toute
remontée au-delà du fit local sur un plateau, toute oscillation à entrées
stables ou tout callback après dispose impose le revert entier du lot 5.
