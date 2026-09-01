# Revue indépendante — lifecycle du prototype layout

Date : 2026-09-01
Branche revue : `codex/review-layout-spike-lifecycle`
Tip revu : `e55f1f90c5e19e202d07348ca02147fb9af37262`
Spike2 temporaire : `58d3b81615c6fb912dde1e01432e2238e57149fb`
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

**Revalidation finale : les deux lacunes de preuve initiales sont fermées.** Le
spike2 archive désormais la trace lazy chiffrée et deux contre-exemples eager
(`LayoutBuilder` et subtree wet-only). La note limite explicitement l'eager aux
subtrees entièrement dry-capable et sépare résultats exécutés, inspection de
source et risques de lifecycle. Elle ne transforme pas le NO-GO en GO.

## Périmètre relu

Fichiers relus intégralement :

- `maintenance/layout-prototype-decision.md` au tip (394 lignes) ;
- `tool/layout_spike/spike.dart` depuis `58d3b81` (1 136 lignes) ;
- `tool/layout_spike/evidence.dart` depuis `58d3b81` (456 lignes) ;
- `test/layout_spike_gate_test.dart` depuis `58d3b81` (745 lignes) ;
- `test/layout_spike_evidence_test.dart` depuis `58d3b81` (517 lignes) ;
- `lib/src/auto_size_text.dart` au tip (694 lignes) ;
- `test/overflow_replacement_test.dart` ;
- les contrats des lots 8, 9 et 10 et les gates dans
  `maintenance/implementation-roadmap.md` ;
- les sections replacement/lifecycle de
  `maintenance/plans/layout-architecture-decision.md` et de sa revue ;
- la surface Flutter pertinente dans `widgets/layout_builder.dart`,
  `widgets/framework.dart`, `rendering/box.dart`, `rendering/object.dart` et
  `rendering/proxy_box.dart` sur les deux SDK épinglés.

Les quatre fichiers temporaires de `58d3b81` sont supprimés par `e55f1f9`,
conformément au lot 8. Leurs blobs sont byte-identiques à l'archive canonique
`06169f7` citée dans la note. Aucun code produit du spike n'est présent au tip.

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

| Pin | Framework | Dart | Spike2 archivé |
|---|---|---|---:|
| Flutter 3.41.0 | `44a626f4f0` | 3.11.0 | 28/28 |
| Flutter 3.47.2 | `d3b14c8769` | 3.13.2 | 28/28 |

Commandes principales :

```sh
/Users/mathieu/fvm/versions/3.41.0/bin/flutter test \
  test/layout_spike_gate_test.dart \
  test/layout_spike_evidence_test.dart --reporter expanded
/Users/mathieu/fvm/versions/3.47.2/bin/flutter test \
  test/layout_spike_gate_test.dart \
  test/layout_spike_evidence_test.dart --reporter expanded
```

Les 28 tests et leurs compteurs sont identiques sur les deux SDK. Le nouveau
fichier de preuve est archivé dans le SHA temporaire puis retiré du tip.

### Lazy : fit → dry overflow → wet overflow → fit

Le probe utilise un `ConstrainedLayoutBuilder` public dont le render object ne
reconstruit sa branche que pendant wet layout. Son `computeDryLayout` délègue
volontairement au seul child actuellement monté. Deux branches stateful keyed,
avec compteurs de layout, sémantique et gesture, rendent le scénario
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

### Eager : lifecycle et capacité dry bornée

Le témoin `SpikeEagerReplacement` utilise `Stack` + deux `Offstage` +
`ExcludeSemantics`. Avec les mêmes branches stateful :

```text
EAGER_PROBE inits={text: 1, replacement: 1}
disposes={}
layouts={text: 1, replacement: 1}
ticks={text: 2, replacement: 2}
taps={text: 1, replacement: 1}
```

Le probe lifecycle indépendant initial avait observé sur les deux SDK :

- les deux `initState` dès le premier montage ;
- un wet layout de chaque branche, y compris l'inactive ;
- les deux tickers actifs avant et après le flip ;
- aucune disposition au flip et une disposition de chaque branche au teardown ;
- une seule branche dans l'arbre sémantique et une seule branche atteinte par
  le hit test à chaque état.

Le contrôle sémantique/hit est correct pour ce témoin parce que `RenderOffstage`
ne peint pas, ne hit-teste pas et ne visite pas l'enfant offstage pour les
sémantiques. Le spike2 archive les deux `initState`, l'absence de dispose aux
flips et la branche sémantique unique. Il classe honnêtement les wet layouts et
tickers comme résultats de cette revue indépendante, pas comme nouveaux
compteurs archivés. Les timers et requêtes réseau restent des conséquences du
montage/`initState`, pas des sorties simulées du spike.

### Limite du témoin eager

Le spike2 monte eager puis active successivement une replacement contenant un
`LayoutBuilder` et une replacement wet-only. `getDryLayout` lève un
`FlutterError` dans les deux cas et sur les deux pins. Les implémentations
3.41.0 et 3.47.2 de `_RenderLayoutBuilder.computeDryLayout` appellent
`debugCannotComputeDryLayout` parce que répondre exigerait une exécution
spéculative du callback.

Donc :

```text
eager mount
  ⇒ un RenderObject existe
  ⇏ ce RenderObject sait répondre au dry layout
```

La note finale ne contient plus d'affirmation d'eager exact pour un widget
arbitraire. Elle limite correctement cette option à une branche dont tout le
render subtree nécessaire est dry-capable.

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
| Eager mount mitigé | possible pour subtrees dry-capable, pas arbitraires | rompu | aucun nouveau paramètre requis | effets cachés, mémoire, focus, tickers, clés, sélection | non retenu comme défaut |
| API explicite de mesure | exacte si le contrat fourni est pur et fidèle | conservé | nouvel opt-in/restriction | dérive mesure/rendu transférée à l'appelant | non retenue selon la préférence finale |
| Garantie dry révisée | volontairement bornée, pas exacte pour la géométrie replacement | conservé | signatures inchangées | divergence à documenter et tester | direction privilégiée pour le prochain design |

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

Dans cette voie seulement, l'absence du delegate devrait produire une erreur
déterministe plutôt qu'une prétendue mesure replacement. Cette voie n'est plus
la recommandation de cette revalidation : la préférence finale exclut une
nouvelle API publique.

### 3. Garantie dry révisée

Le prochain design doit préserver la branche lazy et définir un fallback dry
pur, déterministe et borné sans monter la replacement. La direction privilégiée
est de mesurer uniquement la branche texte en dry/intrinsic et de documenter que
la géométrie du replacement appartient au wet layout. Cette garantie est plus
faible que l'égalité théorique pour tout widget, mais elle évite les effets eager
et toute nouvelle responsabilité publique de mesure.

Ce choix reste un changement de contrat : le roadmap exige encore l'égalité
dry/wet. Il doit être adopté explicitement, puis testé dans un nouveau lot 8 ;
la présente revue ne lui attribue pas un GO anticipé.

## Recommandation formelle pour le second design

**Recommandation finale : préserver le lifecycle lazy et réviser la garantie
dry, sans nouvelle API et sans eager mount implicite.**

Le fallback doit être pur, déterministe, contraint et documenté comme une mesure
de la branche texte ; il ne prétend pas mesurer la géométrie d'une replacement
non montée. Cette priorité accepte une exactitude plus faible pour ce cas afin
de conserver les effets de lifecycle historiques et les call sites existants.

Le mainteneur doit inscrire ce contrat dans le roadmap puis faire valider un
nouveau lot 8. La présente revue n'altère pas le NO-GO du contrat exact actuel.

Le second spike doit obtenir simultanément les preuves suivantes avant GO :

1. branche lazy fraîche, quatre intrinsics, dry layout et dry baseline avant
   tout wet ;
2. fallback texte borné sous contraintes tight/loose, axes infinis, baseline et
   rebuilds, avec divergence replacement explicitement attendue ;
3. absence totale d'`initState`, build, ticker, timer simulé, focus, sémantique,
   sélection et hit de la branche inactive ;
4. aucune taille non finie ou hors contraintes et aucune lecture d'un cache de
   branche historique ;
5. replacement responsive, stateful, avec `WidgetSpan`, puis replacement
   contenant un `LayoutBuilder` comme cas explicitement non mesuré en dry ;
6. snapshot de groupe et zéro publication dry ;
7. Flutter 3.41.0 et 3.47.2, mutants séparant fallback texte, branche dry et
   choix replacement wet.

## Findings finaux

### [P1] Le contrat exact courant reste irréalisable

Le probe lazy donne `50 × 70` en dry et `30 × 40` en wet sous les mêmes
contraintes. Ce finding reste volontairement ouvert et justifie le NO-GO jusqu'à
la révision formelle de la garantie dry.

### Lacunes de preuve résolues

- la trace lazy, son lifecycle, la sémantique et le hit sont archivés ;
- eager + `LayoutBuilder` et eager + wet-only échouent bien en dry sur les deux
  pins ;
- la note ne promet jamais que l'eager mesure un widget arbitraire ;
- elle borne l'eager aux subtrees dry-capable et n'en fait pas la recommandation
  adoptée ;
- `initState` eager est exécuté, tandis que tickers et wet layout de l'inactive
  sont explicitement attribués au probe indépendant ; timers et réseau sont
  correctement classés comme risques de montage/source, pas comme compteurs du
  spike2.

Il ne reste aucun finding lifecycle documentaire supplémentaire contre
`e55f1f9`.

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
  timer et mémoire ; ce risque motive son rejet comme défaut ;
- logique métier : contradiction du contrat exact confirmée, preuves lazy/eager
  désormais archivées et correctement bornées ;
- zones non vérifiées empiriquement : vraie requête réseau et vrai focus clavier
  n'ont pas été déclenchés ; leur activation découle du montage et est explicitée
  par le contrat/documentation Flutter. La sélection eager et les collisions de
  `GlobalKey` restent à démontrer dans le prochain spike.

Conclusion finale : **note et spike2 acceptés pour documenter le NO-GO.** Les
lots 9/10 restent suspendus. La direction privilégiée est un second design lazy
avec fallback dry borné et documenté, sans nouvelle API ni eager mount ; elle
exige encore une décision de contrat et un nouveau lot 8 avant tout code produit.
