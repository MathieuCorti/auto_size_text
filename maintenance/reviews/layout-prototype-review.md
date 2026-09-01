# Revue indépendante du prototype layout — lot 8

## Verdict

**CHANGEMENTS REQUIS sur la note.** Le **NO-GO du contrat actuel est confirmé**
et les lots 9 et 10 doivent rester suspendus. En revanche, la note ne satisfait
pas encore entièrement son propre contrat de reproductibilité : le commit
historique permet de rejouer les 17 tests et les mutants, mais pas le probe lazy
chiffré qui porte la preuve décisive, ni plusieurs probes secondaires présentés
comme exécutés sur les deux SDK.

Il n'y a aucun P0. Un P1 documentaire bloque l'acceptation formelle de la note,
sans remettre en cause le NO-GO architectural. Les P2/P3 demandent de borner les
claims à ce que le spike conservé prouve réellement.

Périmètre contrôlé :

- base Gate Cœur `aac54f3eac23aa7c47a5439baf179f9394588aaa` ;
- spike historique `dba563961a66ca09d40f471e3a72e5649752602f` ;
- tip audité `ea5b52df8f15a364dec5fcd243d5931d00ffb959` ;
- Flutter 3.41.0 / framework
  `44a626f4f0027bc38a46dc68aed5964b05a83c18` ;
- Flutter 3.47.2 / framework
  `d3b14c876900e553bc736ca19295fc09e3853e8e`.

## Findings

### P1 — Le probe lazy décisif n'est pas reproductible depuis le commit annoncé

**Fichiers :** `maintenance/layout-prototype-decision.md:20-28,186-209`,
`dba5639:test/layout_spike_gate_test.dart:624-647`,
`dba5639:tool/layout_spike/spike.dart:186-236`.

La note désigne `dba5639` comme « commit temporaire complet du spike », puis
rapporte un probe dans lequel un dry sous `maxWidth: 50` rend `50 × 70`, le wet
rend `30 × 40`, et la trace fit → overflow → fit initialise puis dispose la
replacement. Aucun code conservé à ce SHA ne produit cette trace :

- le seul test lazy monte un `LayoutBuilder` et vérifie uniquement que
  `getDryLayout` lève un `FlutterError` ;
- `SpikeEagerReplacement` est un témoin `Stack`/`Offstage` piloté manuellement,
  sans fitter, sélection par contraintes, appel dry ou comparaison dry/wet ;
- aucun test ne relie le cycle de vie eager/lazy au choix de candidat du render
  object.

Le raisonnement de fond est néanmoins correct. Sur les deux pins,
`_RenderLayoutBuilder.computeDryLayout` appelle
`debugCannotComputeDryLayout`, précisément parce qu'exécuter le callback
spéculativement muterait l'arbre vivant. `RenderBox.getDryLayout` exige une
taille égale au wet à état identique et un calcul sans effet de bord ; une
branche non montée ne fournit aucun `RenderBox` à interroger. Le blocker est
donc réel, mais les valeurs et la trace publiées ne sont pas rejouables à partir
de l'artefact cité.

**Correction requise :** soit conserver le probe lazy et son test dans un
nouveau commit historique jetable, avec exécution sur les deux pins, puis le
retirer au tip ; soit retirer les valeurs `50 × 70`/`30 × 40`, la trace de
lifecycle et le mot « démontrée » pour présenter honnêtement une preuve fondée
sur l'invariant Flutter et le test `LayoutBuilder` conservé. La première option
est préférable pour le prochain lot 8.

### P2 — L'eager mount ne garantit pas un dry exact pour des widgets arbitraires

**Fichiers :** `maintenance/layout-prototype-decision.md:203-218`,
`dba5639:test/layout_spike_gate_test.dart:280-328`.

La première voie de déblocage affirme conserver « un dry exact pour des widgets
arbitraires ». L'eager mount ne résout que la disponibilité du render subtree.
Il ne donne pas un contrat dry à un widget qui n'en possède pas. Le spike le
démontre lui-même : un child monté `SpikeWetOnlyBox` fonctionne en wet et ses
largeurs intrinsèques sont accessibles, mais la première demande de dry lève.
Une replacement contenant un `LayoutBuilder` présente la même limite.

**Correction requise :** remplacer ce claim par « widgets arbitraires dont le
render subtree respecte le contrat dry demandé », puis définir le comportement
pour une replacement wet-only, de la même façon que pour un child inline
wet-only. L'eager mount reste l'unique voie identifiée pour rendre disponible
une branche inactive *dry-capable* ; il ne rend pas tous les widgets dry-capable.

### P2 — La séparation des APIs intrinsèques est prouvée, pas l'exactitude des quatre résultats

**Fichiers :** `maintenance/layout-prototype-decision.md:91-98,148-164`,
`dba5639:tool/layout_spike/spike.dart:603-647,837-991`,
`dba5639:test/layout_spike_gate_test.dart:280-328,587-622`.

La lecture du code et le mutant `intrinsic_uses_dry` confirment la bonne
frontière : les largeurs interrogent `getMinIntrinsicWidth` ou
`getMaxIntrinsicWidth`, tandis que dry, hauteurs et baselines passent par
`getDryLayout`/`getDryBaseline`. Cette séparation correspond aux implémentations
de `RenderParagraph` sur 3.41.0 et 3.47.2.

Les assertions conservées ne prouvent toutefois pas que les valeurs sont
correctes :

- le test wet-only accepte toute largeur non négative et vérifie seulement
  l'absence d'appel dry ;
- le test des quatre intrinsics utilise du texte sans `WidgetSpan` et vérifie
  seulement que les quatre valeurs sont finies et non négatives ;
- aucun témoin `RenderParagraph` ne compare les largeurs min/max, aucun child
  ne donne volontairement un intrinsic différent de son dry, et les contraintes
  synthétiques ne sont pas observées.

**Correction requise :** dans le nouveau spike exigé par la note, ajouter un
child dont min intrinsic, max intrinsic et dry width sont distincts ; comparer
les quatre résultats et le candidat à un `RenderParagraph` témoin sur les deux
pins, avec largeur/hauteur finies puis infinies. À défaut, qualifier la phrase
« noyau render viable » comme une faisabilité de frontière et non une preuve
d'exactitude intrinsèque complète.

### P3 — Plusieurs claims secondaires proviennent de la lecture du code, pas de tests discriminants conservés

**Fichiers :** `maintenance/layout-prototype-decision.md:81-110,169-175`,
`dba5639:test/layout_spike_gate_test.dart:134-220,432-528`.

Le code suit bien les invariants annoncés, mais la suite conservée ne distingue
pas tous les défauts que le texte dit avoir probés :

- `zero_division` tue une division par zéro, sans prouver qu'à facteur zéro la
  baseline du child est interrogée avant multiplication, ni distinguer baseline
  absente, valide à zéro et erreur dry ;
- aucun test ne reproduit le retour d'une taille dry mémoïsée après changement
  d'un facteur externe ;
- le témoin eager vérifie lifecycle et sémantique, pas peinture ni hit testing ;
- le test de recognizer tape le texte, pas l'enfant inline transformé, et aucun
  test n'observe explicitement les tags de placeholder.

Ces propriétés sont plausibles et, pour plusieurs, lisibles directement dans
le spike ou dans le wrapper Flutter équivalent. Elles ne doivent simplement pas
être présentées comme des probes reproductibles sur les deux pins sans artefact.

**Correction requise :** conserver les probes/mutants correspondants ou
étiqueter ces points « inspection structurelle ». Indiquer aussi que
`invokeLayoutCallback` est une API publique **protégée**, réservée aux
sous-classes de `RenderObject`, documentée par Flutter comme généralement
découragée. Son usage actuel depuis `_SpikeRenderFitter.performLayout` respecte
ce contrat et ne constitue pas un recours à une API privée.

## Vérification indépendante

Le spike a été extrait par `git archive` dans un répertoire temporaire ; aucun
fichier n'a été restauré au tip.

Sur chacun des deux SDK exacts :

```text
flutter pub get --no-example                                  succès
dart format --output=none tool/layout_spike/spike.dart \
  test/layout_spike_gate_test.dart                            0 fichier modifié
flutter analyze tool/layout_spike/spike.dart \
  test/layout_spike_gate_test.dart                            aucune issue
flutter test test/layout_spike_gate_test.dart --reporter expanded
                                                               17/17 verts
```

Les compteurs observés sont identiques : `C=1024`, `P=3`, 10 évaluations,
10 layouts paragraphe et 30 layouts children ; groupe local 40, rendu 18 et un
relayout final ; non-monotone candidat 1 en deux évaluations ; painters 4/4
puis 5/5 après exception. Le SHA-256 de `example/pubspec.lock` reste
`115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7`.

Mutants ciblés :

| Mutant | 3.41.0 | 3.47.2 | Conclusion |
|---|---:|---:|---|
| `linear_search` | exit 1 | exit 1 | compteur logarithmique discriminant |
| `wet_uses_dry` | exit 1 | exit 1 | backend wet distinct |
| `dry_publish` | exit 1 | exit 1 | pureté groupe discriminante |
| `skip_final_layout` | exit 1 | exit 1 | état final du paragraphe discriminant |
| `zero_division` | exit 1 | exit 1 | garde de taille de run zéro discriminante |
| `no_dispose` | exit 1 | exit 1 | disposal temporaire discriminant |
| `intrinsic_uses_dry` | non revendiqué | exit 1 | largeur intrinsèque distincte du dry |

## Revue de l'architecture du spike

Les points suivants sont confirmés par exécution et lecture intégrale des deux
fichiers historiques :

- le parent render configure le `RenderParagraph` et les wrappers sous
  `invokeLayoutCallback`, puis laisse tous les descendants dans le dernier état
  réellement rendu ; le relayout de projection groupe est protégé par mutant ;
- le chemin dry ne modifie ni le paragraphe ni les wrappers, ne publie pas au
  groupe, et libère le `TextPainter` temporaire dans un `finally` ;
- le wrapper inline est une duplication bornée de protocole de transformation,
  sans painter, logique de sélection ou sémantique de paragraphe copiés ;
- `WidgetSpan.extractFromInlineSpan` ne peut pas être réutilisé tel quel parce
  que son `_RenderScaledInlineWidget` est privé et reçoit un facteur fixé lors
  du build ; la réimplémentation du petit wrapper depuis des APIs publiques est
  donc justifiée ;
- le wet child sans dry est bien supporté jusqu'à ce qu'un ancêtre demande une
  opération sèche ;
- le snapshot groupe est une valeur immuable, dry ne publie rien et wet publie
  une fois après l'état final ;
- la recherche est logarithmique sur le cas monotone. Le cas non monotone est
  borné, déterministe et rend un candidat effectivement testé dans la fixture,
  sans prétendre trouver le meilleur candidat global ;
- la réutilisation de `RenderParagraph` conserve le registrar de sélection, les
  boxes de texte, un recognizer et la sémantique d'un child inline dans les cas
  exercés.

La surface commune compilée est réelle. La seule différence de constructeur
observée dans le périmètre est `devicePixelRatio`, ajouté à `RenderParagraph`
sur 3.47.2 et volontairement omis par le spike. Les wrappers Flutter internes
restent privés sur les deux pins ; aucun nom privé n'est importé par le spike.

## Confirmation du NO-GO et conformité au roadmap

Le roadmap du lot 9 exige à la fois :

1. la même branche et la même taille en dry/wet à contraintes et snapshot
   identiques ;
2. une replacement inactive non montée ;
3. aucun build, montage ou effet de lifecycle depuis dry/intrinsics.

Quand le texte actuellement monté tient sous les contraintes wet précédentes
mais qu'une nouvelle requête sèche devrait choisir la replacement, ces trois
exigences ne peuvent pas être satisfaites simultanément : la replacement n'a
pas de render subtree mesurable et le seul moment autorisé pour reconstruire
est une passe wet via callback de layout. Un cache de branche active donnerait
une estimation dépendante d'un wet antérieur, pas la taille promise par
`getDryLayout`.

Le NO-GO suit donc littéralement C4 de la revue de roadmap : aucun `S7`, aucune
branche de lot 9/10, aucune fermeture des findings layout, et nouveau design
soumis à une nouvelle note et une nouvelle revue. Accepter l'eager mount sans
décision explicite violerait le lifecycle historique ; accepter un measurer ou
une garantie dry réduite modifierait l'API ou les compositions supportées.

## Inventaire et checklist de revue

Lus intégralement :

- `maintenance/layout-prototype-decision.md` au tip ;
- `tool/layout_spike/spike.dart` au commit `dba5639` (1 064 lignes) ;
- `test/layout_spike_gate_test.dart` au commit `dba5639` (745 lignes).

Ont aussi été contrôlés : les sections lots 8 à 10 et gates de
`maintenance/implementation-roadmap.md`, C4/C5 et les gates de
`maintenance/reviews/implementation-roadmap-review.md`, les contrats pertinents
de `maintenance/reviews/layout-plan-review.md` et
`maintenance/plans/layout-architecture-decision.md`, ainsi que les
implémentations Flutter 3.41.0 et 3.47.2 de `RenderObject`, `RenderBox`,
`RenderParagraph`, `WidgetSpan` et `LayoutBuilder`.

Surface d'entrée : `InlineSpan`, `WidgetSpan`, contraintes, scalers, snapshot de
groupe et callbacks locaux. Aucun réseau, stockage, base de données, commande,
authentification, autorisation, session, secret ou cryptographie.

| Risque | Conclusion |
|---|---|
| Injection, XSS, SQL, commandes | hors surface |
| Authentification, autorisation/IDOR, CSRF, session | hors surface |
| Cryptographie, secrets, divulgation | hors surface |
| Race/état | snapshot et absence de publication dry vérifiés ; lifecycle replacement reste la décision bloquante |
| Disponibilité/DoS | child sans dry échoue au chemin attendu ; coût monotone borné par compteurs |
| Ressources | painters temporaires et paragraphe possédé couverts ; eager tickers/focus non prouvés et correctement renvoyés au nouveau spike |
| Logique métier | monotonie, zéro, groupe et branche replacement examinés ; findings ci-dessus |

Non vérifiés, car hors demande ou absents de l'artefact : appareil physique,
web/profile, suite package complète, focus/tickers eager, et trace numérique du
probe lazy annoncée. Le répertoire d'archive temporaire, les résolutions et les
sorties de test ont été supprimés après revue.

## Décision de sortie

La note peut être acceptée après correction des quatre points ci-dessus sans
changer son verdict principal. Jusqu'à cette correction, le statut reste :

**NO-GO architectural confirmé ; note CHANGEMENTS REQUIS ; lots 9/10 arrêtés.**
