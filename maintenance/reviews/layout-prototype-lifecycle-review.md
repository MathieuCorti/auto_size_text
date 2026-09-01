# Revue indépendante — lifecycle du prototype layout

Date : 2026-09-01
Branche revue : `codex/review-layout-spike-lifecycle`
Tip revu : `ea5b52df8f15a364dec5fcd243d5931d00ffb959`
Spike temporaire : `dba563961a66ca09d40f471e3a72e5649752602f`
Base Gate Cœur : `aac54f3eac23aa7c47a5439baf179f9394588aaa`

## Verdict

**NO-GO confirmé pour le contrat actuel.** Les lots 9 et 10 doivent rester
suspendus. Le roadmap demande à la fois :

- une branche `overflowReplacement` arbitraire inactive non montée ;
- une réponse dry/intrinsic exacte avant tout wet layout ;
- aucune API de mesure fournie par l'appelant.

Ces trois propriétés ne sont pas réalisables simultanément avec le modèle
public Flutter. Un `Widget` non monté est une configuration, pas un objet de
layout. Ses métriques n'existent qu'après inflation en `Element` puis création
d'un `RenderObject`, ou si l'appelant fournit un contrat de mesure distinct.
Monter ou reconstruire la branche pendant `computeDryLayout` muterait l'arbre et
déclencherait un lifecycle depuis une requête qui doit rester pure.

Le NO-GO de `maintenance/layout-prototype-decision.md` est donc correct, tout
comme l'absence de `S7` et la suspension des lots 9/10. Aucun finding layout ne
peut être déclaré fermé sur ce tip.

La note nécessite néanmoins deux précisions de preuve avant de servir de base
au second design :

1. la trace lazy chiffrée annoncée n'est pas présente dans le commit du spike ;
2. l'eager mount est nécessaire pour accéder au render subtree inactif, mais il
   n'est pas suffisant pour garantir le dry exact d'un widget réellement
   arbitraire : un `LayoutBuilder` monté refuse lui-même le dry layout.

Ces précisions renforcent le NO-GO ; elles ne le réfutent pas.

## Périmètre relu

Fichiers relus intégralement :

- `maintenance/layout-prototype-decision.md` au tip ;
- `tool/layout_spike/spike.dart` depuis `dba5639` (1 064 lignes) ;
- `test/layout_spike_gate_test.dart` depuis `dba5639` (745 lignes) ;
- `lib/src/auto_size_text.dart` au tip (694 lignes) ;
- `test/overflow_replacement_test.dart` ;
- les contrats des lots 8, 9 et 10 et les gates dans
  `maintenance/implementation-roadmap.md` ;
- les sections replacement/lifecycle de
  `maintenance/plans/layout-architecture-decision.md` et de sa revue ;
- la surface Flutter pertinente dans `widgets/layout_builder.dart`,
  `widgets/framework.dart`, `rendering/box.dart`, `rendering/object.dart` et
  `rendering/proxy_box.dart` sur les deux SDK épinglés.

Le diff persistant `aac54f3...ea5b52d` contient uniquement la note de décision.
Les 1 809 lignes du spike ont bien été supprimées du tip, conformément au lot
8. Aucun code produit du spike n'est présent.

## Contrat historique réellement observable

L'implémentation actuelle construit un `LayoutBuilder`. Après la mesure du
texte, elle retourne soit le `Text`, soit `widget.overflowReplacement`
(`lib/src/auto_size_text.dart:295-300`). La configuration `Widget` peut déjà
exister dans le champ public, mais seule la branche retournée est inflationnée,
montée, layoutée et exposée.

La distinction est importante : « non montée » ne signifie pas que le
constructeur Dart de la configuration n'a jamais été appelé. Elle signifie
qu'aucun `Element`, `State` ou `RenderObject` n'est créé pour la branche
inactive. En pratique :

- `initState` du replacement n'arrive pas tant que le texte tient ;
- le replacement est disposé au retour vers le texte ;
- les timers, tickers, abonnements et requêtes initiés depuis son `initState`
  n'existent pas lorsqu'il est inactif ;
- seule la branche montée peut participer au focus, à la sélection, aux
  sémantiques et au hit testing.

Le roadmap fige explicitement ce comportement aux lignes 667-668 pour le lot 9
et 731-732 pour le lot 10. Le lot 8 autorise une politique eager uniquement si
elle est acceptée explicitement et prouvée ; il n'autorise pas un changement
implicite.

## Reproduction indépendante

### Matrice exacte

| Pin | Framework | Dart | Spike committé | Probe lifecycle indépendant |
|---|---|---|---:|---:|
| Flutter 3.41.0 | `44a626f4f0` | 3.11.0 | 17/17 | 2/2 |
| Flutter 3.47.2 | `d3b14c8769` | 3.13.2 | 17/17 | 2/2 |

Commandes principales :

```sh
/Users/mathieu/fvm/versions/3.41.0/bin/flutter test \
  test/layout_spike_gate_test.dart --reporter expanded
/Users/mathieu/fvm/versions/3.47.2/bin/flutter test \
  test/layout_spike_gate_test.dart --reporter expanded

/Users/mathieu/fvm/versions/3.41.0/bin/flutter test \
  test/layout_lifecycle_black_box_test.dart --reporter expanded
/Users/mathieu/fvm/versions/3.47.2/bin/flutter test \
  test/layout_lifecycle_black_box_test.dart --reporter expanded
```

Le second fichier était un probe black-box jetable ajouté dans une copie du
spike, puis retiré ; il ne fait partie ni du tip ni de cette revue. Les résultats
et compteurs sont identiques sur les deux SDK.

### Lazy : fit → dry overflow → wet overflow → fit

Le probe utilise un `ConstrainedLayoutBuilder` public dont le render object ne
reconstruit sa branche que pendant wet layout. Son `computeDryLayout` délègue
volontairement au seul child actuellement monté. Deux branches stateful keyed,
avec compteurs de layout/ticker, sémantique et gesture, rendent le scénario
observable sans inspection privée.

| Étape | Contrainte | Branche montée | Taille retournée | Lifecycle cumulé |
|---|---:|---|---:|---|
| premier wet, texte fit | maxWidth 150 | texte | `120 × 70` | `text.init = 1` |
| dry qui devrait overflow | maxWidth 50 | texte encore monté | `50 × 70` | inchangé |
| wet avec la même contrainte | maxWidth 50 | replacement | `30 × 40` | `text.dispose = 1`, `replacement.init = 1` |
| wet fit à nouveau | maxWidth 150 | texte | `120 × 70` | `replacement.dispose = 1`, `text.init = 2` |
| teardown | — | aucune | — | `text.dispose = 2`, `replacement.dispose = 1` |

La sortie commune avant teardown est :

```text
LAZY_PROBE wetFit=120x70 dryOverflow=50x70 wetOverflow=30x40
inits={text: 2, replacement: 1}
disposes={text: 1, replacement: 1}
layouts={text: 2, replacement: 1}
dry={text: 1}
taps={text: 1, replacement: 1}
```

Avant le switch, seule la sémantique `text branch` existe et seul le gesture du
texte reçoit le tap. Après le switch, seule `replacement branch` existe et seul
son gesture reçoit le tap. Le dry intermédiaire ne monte, ne dispose, ne
layoutte wet et n'expose rien de nouveau.

Cette reproduction confirme le désaccord annoncé par la note : la taille dry
est celle de la branche active historique, alors que le wet légalement reconstruit
et choisit une autre branche. `50 × 70 != 30 × 40` sous les mêmes contraintes.

### Eager : lifecycle, layout, ticker, sémantique et hit

Le témoin `SpikeEagerReplacement` utilise `Stack` + deux `Offstage` +
`ExcludeSemantics`. Avec les mêmes branches stateful :

```text
EAGER_PROBE inits={text: 1, replacement: 1}
disposes={}
layouts={text: 1, replacement: 1}
ticks={text: 2, replacement: 2}
taps={text: 1, replacement: 1}
```

Les deux SDK observent :

- les deux `initState` dès le premier montage ;
- un wet layout de chaque branche, y compris l'inactive ;
- les deux tickers actifs avant et après le flip ;
- aucune disposition au flip et une disposition de chaque branche au teardown ;
- une seule branche dans l'arbre sémantique et une seule branche atteinte par
  le hit test à chaque état.

Le contrôle sémantique/hit est correct pour ce témoin parce que `RenderOffstage`
ne peint pas, ne hit-teste pas et ne visite pas l'enfant offstage pour les
sémantiques. Cela ne couvre pas les autres effets d'une branche montée.

### Limite du témoin eager

Le test committé « should prove a lazy LayoutBuilder branch cannot answer dry
layout » monte un `LayoutBuilder`, puis vérifie que `getDryLayout` lève un
`FlutterError`. Il passe sur les deux pins. Les implémentations 3.41.0 et 3.47.2
de `_RenderLayoutBuilder.computeDryLayout` sont identiques sur ce point et
appellent `debugCannotComputeDryLayout` parce que répondre exigerait une
exécution spéculative du callback.

Donc :

```text
eager mount
  ⇒ un RenderObject existe
  ⇏ ce RenderObject sait répondre au dry layout
```

L'affirmation de la note selon laquelle l'eager conserve un dry exact pour des
« widgets arbitraires » est trop large. Elle est vraie seulement pour une
branche dont tout le render subtree nécessaire respecte le protocole dry et les
intrinsics interrogées. `LayoutBuilder`, un render object wet-only ou un widget
qui délègue à l'un d'eux reste un contre-exemple public valide.

## Pourquoi un Widget arbitraire non monté n'est pas mesurable en dry

La conclusion est une impossibilité de contrat, pas seulement une limitation
du spike.

1. `Widget` est une configuration immutable. Il ne porte ni contraintes, ni
   taille, ni baseline, ni méthodes intrinsèques.
2. `getDryLayout`, `getDryBaseline` et les intrinsics appartiennent à
   `RenderBox`. Il faut donc d'abord obtenir le render subtree réel.
3. Obtenir ce subtree exige d'inflater le widget dans un `Element`, de créer son
   éventuel `State`, de résoudre ses inherited dependencies et de construire
   ses descendants. Cela constitue précisément un montage et peut déclencher
   `initState`, `didChangeDependencies`, abonnements, timers, tickers ou réseau.
4. Flutter définit `computeDryLayout` comme un calcul sans changement d'état
   interne. La méthode doit interroger les children via `getDryLayout`, pas les
   construire ou les wet-layoutter.
5. `invokeLayoutCallback` est protégé, déconseillé et utilisable uniquement
   pendant le layout wet du render object courant. Il n'est pas une permission
   de mutation pendant dry/intrinsic.
6. Monter le widget dans un arbre/pipeline « séparé » ne contourne rien : il est
   alors monté, son lifecycle est observable et sa mesure nécessite encore un
   wet layout pour les sous-arbres sans dry.
7. Une table de types connus, une estimation ou un cache de la dernière branche
   n'est pas une mesure d'un widget arbitraire sous de nouvelles contraintes.

Il n'existe donc que deux sources honnêtes de métriques : un render subtree déjà
monté et dry-capable, ou une API/abstraction de mesure explicitement fournie.

## Analyse des trois voies

| Voie | Exactitude dry | Lifecycle actuel | Compatibilité appelant | Risque production | Conclusion |
|---|---|---|---|---|---|
| Eager mount mitigé | possible pour subtrees dry-capable, pas arbitraires | rompu | aucun nouveau paramètre requis | effets cachés, mémoire, focus, tickers, clés, sélection | viable seulement comme politique majeure explicitement acceptée et à support borné |
| API explicite de mesure | exacte si le contrat fourni est pur et fidèle | conservé | nouvel opt-in/restriction | dérive mesure/rendu transférée à l'appelant, mais effets cachés évités | compromis le plus sûr et le plus honnête |
| Garantie dry révisée | cache : inexact ; erreur : honnête mais non fonctionnelle | conservé | signatures inchangées | parents mal dimensionnés ou issues toujours ouvertes | rejetée comme déblocage des lots 9/10 |

### 1. Eager mount mitigé

Avantages :

- ne demande pas à l'appelant de décrire séparément la taille ;
- fournit les render objects des deux branches avant le premier wet switch ;
- permet une parité dry/wet lorsque tous les descendants supportent le dry ;
- simplifie les flips : les states et render objects restent stables.

Risques non théoriques :

- `initState`, `didChangeDependencies` et `build` des deux branches s'exécutent ;
- timers, streams, isolates, requêtes réseau et autres effets applicatifs peuvent
  démarrer alors que le replacement ne sera jamais affiché ;
- `Offstage` wet-layoutte toujours son child, permet encore le focus et laisse
  les animations tourner ;
- deux subtrees augmentent mémoire, coût d'inherited rebuild et pression GC ;
- des `GlobalKey`, Hero tags, focus nodes ou registrars compatibles uniquement
  parce que les branches étaient mutuellement exclusives peuvent entrer en
  conflit ;
- un paragraphe texte monté mais inactif peut rester inscrit auprès de la
  sélection ; le témoin eager ne teste pas ce point ;
- l'eager ne résout pas les descendants qui déclarent ne pas savoir calculer
  leur dry layout.

Mitigations minimales, toutes partielles :

- frontière render multi-slot dédiée : paint, hit, sémantique, baseline et
  sélection exclusivement sur le slot actif ;
- `TickerMode(enabled: active)` sur chaque subtree pour mettre en sourdine les
  tickers conformes ;
- `ExcludeFocus` ou politique de focus équivalente sur l'inactif ;
- ne pas utiliser `Offstage` comme architecture de production si l'objectif est
  d'éviter le wet layout de l'inactif ;
- tests de collisions de `GlobalKey`, registrars de sélection et descendants
  contenant eux-mêmes `LayoutBuilder`.

`TickerMode` ne neutralise ni un `Timer`, ni un abonnement, ni une requête
réseau initiée en `initState`. Aucune enveloppe générique ne peut annuler un
effet arbitraire démarré par du code applicatif.

### 2. API explicite de mesure

Cette voie garde le widget replacement lazy et demande une abstraction pure
capable de répondre, selon le contrat finalement retenu, à :

- dry size par `BoxConstraints` ;
- dry baseline ;
- quatre intrinsics, ou une dérivation explicitement spécifiée et testée.

Le second design ne doit pas figer prématurément la forme de l'API. Un simple
`Size` constant serait insuffisant pour un replacement responsive ; un unique
callback de taille ne couvre pas baseline et intrinsics. Le nouveau spike doit
comparer au moins un delegate complet et une abstraction plus restreinte avant
de choisir la surface publique.

Cette voie ne rend pas une mesure mensongère « garantie » pour n'importe quel
widget : l'appelant peut fournir des métriques qui divergent du rendu. Son
avantage de production est ailleurs : elle rend la responsabilité explicite,
testable et sans effet de lifecycle caché. Le package peut rejeter les résultats
non finis/hors contraintes et tester la parité du delegate avec le replacement
réel dans ses adapters fournis.

Pour l'API historique sans mesure, si le texte overflow pendant une requête
dry/intrinsic, le seul fallback honnête est une erreur déterministe et
documentée. Utiliser silencieusement la branche active ou une estimation ne doit
pas être retenu.

### 3. Garantie dry révisée

Retourner la mesure du child actif rend le probe `50 × 70` alors que le wet rend
`30 × 40`. Ce résultat viole directement le contrat de `RenderBox` selon lequel
`computeDryLayout` doit correspondre à la taille calculée par `performLayout`
sous les mêmes contraintes.

Lever une erreur est plus honnête qu'un cache, mais maintient précisément les
compositions `Chip`, tables et intrinsics que les lots 9/10 doivent débloquer.
Cette voie peut devenir une restriction documentée hors périmètre, pas le GO du
chantier actuel.

## Recommandation formelle pour le second design

**Recommandation : choisir la voie 2, mesure explicite et branche widget lazy.**

C'est le compromis le plus sûr pour la production et le seul qui conserve le
lifecycle demandé tout en autorisant une réponse dry pure. Il ajoute une
responsabilité/API ; cette modification doit donc être décidée par le
mainteneur, inscrite atomiquement dans le roadmap et validée par un nouveau lot
8. La présente revue ne modifie aucun contrat.

L'eager mount ne doit pas devenir le défaut implicite. Si le mainteneur refuse
toute API supplémentaire et donne priorité absolue à des call sites inchangés,
il doit accepter explicitement les conséquences de lifecycle d'une version
majeure et restreindre la promesse aux replacements dry-capable. Il ne peut pas
conserver l'expression « widget arbitraire ».

Le second spike doit obtenir simultanément les preuves suivantes avant GO :

1. branche lazy fraîche, quatre intrinsics, dry layout et dry baseline avant
   tout wet ;
2. parité du mesureur et du replacement réel sous contraintes tight/loose,
   axes infinis, baseline et rebuilds ;
3. absence totale d'`initState`, build, ticker, timer simulé, focus, sémantique,
   sélection et hit de la branche inactive ;
4. erreurs déterministes pour mesure absente, non finie, hors contraintes ou
   divergente dans les witnesses de test ;
5. replacement responsive, stateful, avec `WidgetSpan`, puis replacement
   contenant un `LayoutBuilder` comme cas explicitement non mesurable sans
   delegate ;
6. snapshot de groupe et zéro publication dry ;
7. Flutter 3.41.0 et 3.47.2, mutants séparant mesure replacement, mesure texte,
   branche dry et branche wet.

Si l'eager reste étudié comme alternative, le spike doit en plus compter les
wet layouts des deux slots, les ticks avec/sans `TickerMode`, focus, timers,
sélection, collisions de clés et ressources initiées dans `initState`.

## Findings de revue

### [P1] Le contrat courant est irréalisable sans choix produit

**Preuve.** Le probe lazy donne une divergence dry/wet déterministe sur les deux
SDK ; Flutter interdit la reconstruction spéculative et un widget non monté ne
possède pas de `RenderBox` à interroger.

**Impact.** Toute implémentation des lots 9/10 choisirait silencieusement entre
une mutation de lifecycle, une nouvelle API ou une garantie dry affaiblie.

**Action.** Conserver le NO-GO, décider formellement l'une des voies puis refaire
le lot 8 ciblé.

### [P1] L'eager ne garantit pas le dry exact d'un widget arbitraire

**Preuve.** Un `LayoutBuilder` déjà monté appelle toujours
`debugCannotComputeDryLayout` sur les deux pins. L'eager fournit le render
object ; il ne lui ajoute pas une implémentation dry.

**Impact.** La formulation actuelle pourrait conduire le second design à
promettre plus que Flutter ne permet et à découvrir le blocage seulement avec
un replacement applicatif complexe.

**Action.** Remplacer, lors de la future décision de contrat, « widgets
arbitraires » par un support précisément borné, ou retenir l'API explicite.

### [P2] La preuve lazy chiffrée n'est pas archivée dans `dba5639`

**Preuve.** Le test committé aux lignes 625-646 vérifie seulement que le dry de
`LayoutBuilder` lève. Il ne contient ni wrapper lazy qui délègue au child actif,
ni tailles `50 × 70`/`30 × 40`, ni compteurs init/dispose ou hit test associés.

**Impact.** Les commandes de reproductibilité de la note ne suffisent pas à
rejouer cette preuve précise depuis le SHA documenté. La conclusion reste vraie
et a été reproduite indépendamment, mais son witness n'est pas autoportant.

**Action.** Le prochain spike doit committer temporairement ce test complet
avant de supprimer le code du tip et conserver son SHA dans la décision.

### [P2] Le témoin eager ne couvre pas ses principaux risques de lifecycle

**Preuve.** Le test committé couvre init/dispose et sémantique. Il ne compte pas
le wet layout inactif, les tickers, timers, focus, sélection ou collisions de
clés. Le probe indépendant confirme déjà layout et tick des deux branches.

**Impact.** Une décision eager prise sur le témoin actuel sous-estimerait les
effets de production et les limites de `Offstage`/`TickerMode`.

**Action.** Ajouter la matrice exigée ci-dessus si cette alternative reste en
course.

## Pré-conclusion qualité et sécurité

Surface d'attaque : aucune entrée réseau, base de données, authentification,
session, cryptographie ou écriture externe dans le diff. Les entrées pertinentes
sont les contraintes de layout, le `Widget` replacement fourni par l'appelant,
ses effets de lifecycle et ses ressources.

Checklist :

- injection, XSS, authentification, autorisation, CSRF, session, cryptographie
  et divulgation : non applicables à ce diff local Flutter ;
- race/TOCTOU : aucune nouvelle race dans la note ; risque de callbacks/tickers
  et publication pendant layout correctement bloqué par le NO-GO ;
- DoS/ressources : risque eager réel par double subtree, wet layout, ticker,
  timer et mémoire ; insuffisamment mitigé par le témoin ;
- logique métier : contradiction de contrat confirmée, overclaim eager et gap
  de reproductibilité identifiés ;
- zones non vérifiées empiriquement : vraie requête réseau et vrai focus clavier
  n'ont pas été déclenchés ; leur activation découle du montage et est explicitée
  par le contrat/documentation Flutter. La sélection eager et les collisions de
  `GlobalKey` restent à démontrer dans le prochain spike.

Conclusion finale : **note NO-GO acceptée quant au verdict et à la suspension,
mais second design requis avant tout lot produit.**
