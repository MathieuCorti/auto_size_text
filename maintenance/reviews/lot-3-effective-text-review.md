# Revue indépendante du lot 3 — `TextScaler` et texte effectif

Date : 2026-09-01

Branche revue : `codex/review-effective-text`

Parent exact : `a13534cd12842b2e6847feb4963842175a96ee10`

Candidat initial : `cac342c8bdb0fb1e874cb7d18d609c691a46d5a5`

Première revue : `9b948eac2aa3f6c47900e3971218fa8f9c5e9902`

Candidat corrigé : `982117dc37a4c57d306b601319446f5d16a7125f`

Correctif de provenance de licence :
`7ea0de86169c9e8c5a331c6ffc07b4ec50d16557`

Périmètre : relecture cumulative `a13534c...7ea0de8`, relecture corrective
produit `9b948ea..982117d` et relecture licence `6da3e9d..7ea0de8`, selon
`developing-flutter`, `effective-dart/testing` et `find-bugs`. Aucun correctif
produit n'a été écrit par cette revue.

## Verdict final

**ACCEPTÉ.**

Aucun finding ouvert. Les trois P1 de la première revue sont corrigés : la
sémantique effective historique des groupes est restaurée, les quatre preuves
métriques sont maintenant discriminantes et l'égalité/hash du scaler est
protégée champ par champ sous un scaler à plateau.

L'API publique, la composition non linéaire, les validations, les rebuilds,
la configuration pré/post-overrides, la recherche et les limites des lots 4
et 5 restent conformes à l'oracle. Les matrices proportionnées sont vertes sur
Flutter 3.41.0 et 3.47.2. Le contrôle final ne trouve ni modification hors lot,
ni shim de compatibilité, ni fichier temporaire résiduel.

La relecture finale du correctif licence confirme un delta d'un seul fichier,
une provenance cohérente avec la fonte source et l'absence de tout changement
de code, test ou TTF. Le verdict reste donc inchangé.

## Résolution des findings initiaux

### P1 produit — groupe hétérogène : résolu

Le candidat initial publiait le candidat logique. Le probe historique rendait
alors `[15, 30]` au lieu de `[20, 20]`. Le correctif transporte à nouveau la
taille effective dans `_AutoSizeTextLayoutResult`, publie cette valeur au
groupe, choisit le minimum effectif, puis :

- pour le texte simple groupé, pose cette taille sur le style et utilise
  `TextScaler.noScaling` ;
- pour le texte riche groupé à référence positive, utilise le rapport linéaire
  `tailleEffectiveDuGroupe / référence`, comme le parent historique.

Le test permanent hétérogène utilise les presets `[20]` et `[15]` avec les
facteurs historiques 1 et 2, et exige dans l'ordre exact `[20, 20]`. Il est
vert sur les deux SDK. Le code n'ajoute ni projection vers un domaine
individuel, ni double borne, ni convergence, ni nouvelle unité de groupe. Les
groupes hétérogènes modernes restent donc explicitement au lot 5. La branche
riche de référence zéro demeure rejetée pendant la recherche et reste au lot
4 ; la garde de rendu correspondante n'élargit pas le comportement atteignable.

### P1 preuve — gras, direction, locale et hauteur : résolu

Les anciennes fixtures ne prouvaient qu'une propriété transmise au
`RenderParagraph`. Les nouvelles fixtures commencent par mesurer deux témoins
réels et vérifier leur divergence, construisent ensuite une contrainte entre
les deux métriques, puis exigent des candidats différents :

| Branche | Précondition indépendante | Candidats protégés | Mutant rejoué |
|---|---|---:|---|
| `boldText` | Roboto regular et bold ont des largeurs distinctes | `30 / 29` | suppression du gras de mesure : `30` au lieu de `29` |
| direction | `<<<<<<` a des largeurs et lignes distinctes en LTR/RTL | `30 / 29` | direction forcée LTR : `30` au lieu de `29` |
| locale | U+066C a des glyphes `locl` distincts en `ar/fa` | `30 / 26` | locale héritée ignorée : `30` au lieu de `26` |
| hauteur | `Hg`, `height: 3`, mesure `90 / 35` | `20 / 30` | comportement de hauteur ignoré : `20` au lieu de `30` |

Les quatre mutants isolés ont été rejoués par la revue sur 3.47.2. Chacun est
rouge exactement sur l'assertion de candidat indiquée. Les mutations ont été
retirées avant le rapport. Les tests vérifient aussi les métriques du
`RenderParagraph` rendu ; le cas de hauteur compare notamment la baseline
sèche. Le remplacement d'un poids existant `w900` par exactement `w700` reste
couvert séparément.

### P1 preuve — égalité/hash : résolu

Le scaler de fixture retourne toujours `42`, quels que soient l'entrée et son
identité. Le test récupère les scalers du vrai `RenderParagraph` et construit :

- deux valeurs aux trois champs identiques, égales et de même hash ;
- une source seule différente ;
- un candidat seul différent ;
- une référence seule différente.

Les trois variations sont inégales et leurs hashes diffèrent du témoin, bien
que les quatre appels `scale(20)` rendent tous `42`. La revue a retiré à tour
de rôle source, candidat et référence de `operator ==`, puis de `hashCode`.
Les six mutants ont échoué sur leur assertion dédiée. Le code final et l'arbre
ont ensuite été restaurés à l'octet près avant la rédaction du rapport.

## API, scaler et compatibilité source/const

- `TextScaler? textScaler` est présent sur les deux constructeurs, qui restent
  `const` et acceptent une invocation `const` moderne.
- `double? textScaleFactor` est conservé sur les deux constructeurs et porte
  `@Deprecated('Use textScaler instead.')` sur chaque paramètre et sur le
  champ public.
- L'assertion d'exclusion mutuelle reste const-compatible. La résolution
  commune répète la protection avec `ArgumentError`, et le test runtime la
  franchit par sous-classe afin de ne pas dépendre des assertions debug.
- La priorité est exacte : scaler explicite, ancien facteur fini positif ou
  nul converti par `TextScaler.linear`, puis `MediaQuery.textScalerOf`.
- Pour une référence positive, la composition appelle exactement
  `source.scale(fontSize * candidate / reference)`. Elle ne linéarise pas le
  scaler source et ne consulte pas son getter de compatibilité pour décider
  d'une taille.
- Entrée, candidat, référence, produit ajusté et sortie sont validés finis et
  supérieurs ou égaux à zéro. Les sorties négatives, infinies ou `NaN`, y
  compris après overflow du produit, lèvent `ArgumentError`. Les exceptions du
  scaler source restent propagées.
- Le zéro simple conserve sa frontière historique ; les runs riches et leur
  frontière complète restent au lot 4.
- Source, candidat et référence sont tous présents dans l'égalité/hash. Le
  snapshot et le scaler candidat sont reconstruits à chaque build, de sorte
  qu'un changement du `MediaQuery` hérité provoque le nouveau layout attendu.
- Aucun usage produit de `MediaQuery.textScaleFactorOf`, de l'ancien argument
  de `TextPainter`/`Text`, de `dynamic`, `noSuchMethod`, `Function.apply` ou
  d'un shim conditionnel n'a été trouvé. Les occurrences de
  `textScaleFactor` restantes sont l'API publique historique et ses tests.

## Configuration effective et recherche

La configuration privée sépare correctement le style et le strut
post-overrides destinés aux painters du style et du strut pré-overrides remis
au `Text` final. Le scaler candidat explicite évite une seconde application
des overrides par le rendu.

Les priorités de style, le remplacement du gras par `w700`, les trois
overrides métriques, le strut, l'alignement, la direction, la locale, le wrap,
l'overflow, `maxLines`, `TextWidthBasis` et `TextHeightBehavior` correspondent
à l'oracle Flutter 3.41/3.47. Le painter reçoit `constraints.minWidth`. Son
maximum est la contrainte en wrap/ellipsis et l'infini sinon. Le fit combine
`didExceedMaxLines` et la comparaison entre `constraints.constrain(textSize)`
et `textSize`.

Le delta correctif ne change ni le domaine ni l'algorithme de recherche, sauf
le transport de la taille effective déjà calculée vers le groupe. Il n'ajoute
aucun run riche fidèle, NBSP/NNBSP, placeholder, intrinsic, dry layout public,
projection de groupe ou convergence. Il n'anticipe donc ni le lot 4 ni le lot
5.

## Fixtures, licences et minimalité

Les trois TTF sont des sous-ensembles privés de test chargés avec
`FontLoader`; ils ne sont déclarés dans aucun manifeste d'assets et n'entrent
pas dans le bundle client. Le total fontes et licences est de 26 163 octets.

| Fixture | Taille | Unicode / glyphes | SHA-256 |
|---|---:|---:|---|
| Roboto regular | 2 660 | 7 / 8 | `893780a2a9c1b15a9ee784b1e34568ff755d3ff9815c9fa755febe303d7bd9c1` |
| Roboto bold | 2 632 | 7 / 8 | `bab0b1b36298647122dfaee2e27c0bcb564c43f954be771e90abc94812fafa6d` |
| Noto Naskh Arabic `locl` | 5 212 | 3 / 8 | `d51e94755847f96a7cb9fdd53c91962ec6772a4d6b54c764e05b85e8d987af5a` |

Les fontes sources sont identiques entre les SDK 3.41.0 et 3.47.2 : Roboto
regular `79e851...`, Roboto bold `7d0b99...` et Noto Naskh `6b9996...`.
`hb-info`, `fc-query` et `hb-shape` confirment les poids `w400/w700`, les
avances directionnelles distinctes et la substitution `locl` de U+066C
(`329` en arabe, `455` en farsi). Les sous-ensembles ont donc conservé les
seules tables et glyphes requis par les preuves.

`LICENSE-Roboto.txt` est identique octet pour octet à la licence Apache-2.0
des artefacts des deux SDK (`cfc7749...`). La licence Noto adjacente reproduit
le texte OFL-1.1 du fichier `LICENCE` du dépôt historique archivé
`notofonts/NotoNaskhArabic` ; son SHA-256 local est
`c3dd4c678171e42146614fd4fd132f474df05f7bd12d1348b4c5af50172c0e8f`.
La table `name` du TTF sous-ensemble conserve la notice
`Copyright 2014 Google Inc. All Rights Reserved.`, ainsi que le nom, la version
1.07 et le foundry `GOOG`. La licence et la notice requises restent donc
distribuées ensemble. Aucun fichier de licence, hash ou binaire annoncé ne
manque.

### Relecture du correctif licence `7ea0de8`

Le diff `6da3e9d..7ea0de8` contient uniquement
`test/assets/fonts/LICENSE-NotoNaskhArabic.txt` : 26 lignes ajoutées et 26
retirées pour aligner le texte et son reflow sur la provenance historique.
Les comparaisons de blobs et `git diff --quiet` confirment que :

- tous les fichiers sous `lib/` sont inchangés ;
- tous les tests sont inchangés ;
- les trois TTF conservent exactement leurs blobs et leurs SHA-256 ;
- aucun manifeste, lock, journal d'implémentation ou autre fichier n'est
  modifié.

Le sanity ciblé sur Flutter 3.47.2, cas locale `ar/fa` avec substitution
`locl`, est vert 1/1. Il recharge donc le TTF concerné et confirme que la
fixture métrique reste exploitable après le changement purement attributif.

## Preuves rouges et capacité d'échouer

La première revue avait reproduit sur le parent exact :

- l'absence de l'argument `textScaler` sur les deux constructeurs, donc une
  erreur de compilation de la suite scaler ;
- quatre passages et trois échecs de configuration sur les overrides isolés,
  le strut et le wrap ;
- `[20, 20]` sur le parent contre `[15, 30]` sur le candidat initial pour le
  groupe hétérogène.

Le correctif ajoute le rouge permanent exact `[20, 20]`, les quatre témoins
métriques discriminants et les variations plateau. Les dix mutants de la
relecture corrective (quatre métriques, trois égalités, trois hashes) prouvent
que ces assertions échouent si leur cause produit disparaît.

Les fichiers de test modifiés ou ajoutés possèdent un `group()` et chaque cas
`test`/`testWidgets` commence par « should ». Les helpers ne cachent pas les
attentes produit : les préconditions sont calculées par des painters témoins,
et les candidats/rendus sont vérifiés séparément.

## Matrice indépendante rejouée

Toolchains exactes :

```text
Flutter 3.41.0 • revision 44a626f4f0 • Dart 3.11.0
Flutter 3.47.2 • revision d3b14c8769 • Dart 3.13.2
```

| Gate | Flutter 3.41.0 | Flutter 3.47.2 |
|---|---:|---:|
| suites lot 3 | 21/21 | 21/21 |
| suite racine complète | 77/77 | 77/77 |
| leak/cycle de vie explicite | 9/9 | 9/9 |
| analyse scoped `--fatal-infos --fatal-warnings` | 0 diagnostic | 0 diagnostic |

Contrôles supplémentaires :

- format autoritatif Dart 3.13.2, `lib test example` : 24 fichiers, zéro
  changement ;
- exemple 3.47.2 : `pub get --enforce-lockfile`, puis analyse fatale, succès ;
- `pub downgrade` depuis l'état résolu haut a abaissé 13 dépendances, dont les
  quatre contraintes propres au SDK ; la suite avec `--no-pub` reste 77/77 ;
- le contrôle non mutating du formatter 3.11.0 ne diverge que sur les deux
  fichiers hérités déjà documentés des lots antérieurs,
  `leak_tracking_test.dart` et `text_painter_lifecycle_test.dart`. Aucun fichier
  du correctif lot 3 n'est concerné, et la roadmap impose le format unique
  autoritatif 3.47.2.

La résolution haute a ensuite restauré les locks suivis ; l'arbre était propre
avant la seule modification de ce rapport.

## Périmètre et revue `find-bugs`

Delta correctif lu intégralement :

- `lib/src/auto_size_text.dart` ;
- `lib/src/auto_size_text_layout.dart` ;
- `maintenance/implementation/lot-3-effective-text.md` ;
- les deux licences et les trois TTF sous `test/assets/fonts/` ;
- `test/effective_text_configuration_test.dart` ;
- `test/text_scaler_test.dart`.

Le diff cumulatif relit aussi intégralement `test/basic_test.dart` et
`test/utils.dart`. Le delta correctif est limité aux deux fichiers produit, aux
preuves/journal et aux fixtures/licences. Le cumul n'ajoute rien à l'exemple,
au manifeste, aux locks, à la CI, à la documentation publique ou à la version.

| Checklist | Conclusion |
|---|---|
| Injection, XSS, SQL, auth, session, CSRF | Hors surface : widget local sans serveur, template ou identité. |
| Secrets, cryptographie, divulgation | Aucun secret, log sensible, réseau ou primitive ajouté. |
| Race, état, TOCTOU | Rebuild `MediaQuery`, égalité du scaler et état de groupe exercés ; aucun défaut observé. |
| Ressources, disponibilité | Painters libérés sous `finally`, leak 9/9 sur deux SDK, extrêmes rejetés. |
| Déni de service | Recherche toujours logarithmique ; aucun domaine proportionnel à l'amplitude n'est matérialisé. |
| Logique numérique | Non-linéaire, plateau, zéro, négatifs, `NaN`, infinis, overflow et hash audités. |
| Compatibilité API | Ancienne API conservée/dépréciée, nouvelle API const, priorité et runtime conformes. |
| Frontière de lots | Aucun run riche complet, intrinsic, projection ou convergence ajouté. |

Limites : pas d'appareil physique/web ni d'exécution AOT release. La branche
runtime d'exclusion mutuelle est néanmoins exercée sans assertion, les
toolchains minimum et haute couvrent compilation/analyse/layout, et les
métriques sensibles reposent sur des fixtures versionnées plutôt que sur les
fontes de la machine.
