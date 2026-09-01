# Revue indépendante du lot 3 — `TextScaler` et texte effectif

Date : 2026-09-01

Branche revue : `codex/review-effective-text`

Parent exact : `a13534cd12842b2e6847feb4963842175a96ee10`

Commit candidat : `cac342c8bdb0fb1e874cb7d18d609c691a46d5a5`

Périmètre : API `TextScaler`, compatibilité de `textScaleFactor`, composition
du scaler, configuration effective du texte simple, recherche, frontière avec
les groupes et qualité des preuves du lot 3. Aucun correctif produit n'a été
écrit par cette revue.

## Verdict

**CHANGEMENTS REQUIS.**

L'API publique, le scaler composé et la configuration effective du texte
simple sont statiquement conformes à l'oracle, et toutes les commandes de la
matrice produit sont vertes. Aucun défaut produit n'a été trouvé dans l'ordre
de composition non linéaire, la validation des entrées/sorties, la séparation
pré/post-overrides, `minWidth`, l'overflow ou le rebuild de `MediaQuery`.

Le lot n'est cependant pas acceptable en l'état pour trois raisons bloquantes :

1. il change déjà l'unité et le comportement observable des groupes
   hétérogènes, alors que cette sémantique appartient explicitement au lot 5 ;
2. plusieurs tests P0 annoncés comme preuves de parité utilisent des fixtures
   qui ne distinguent pas les branches qu'ils sont censés protéger ;
3. le test permanent d'égalité du scaler candidat n'empêche pas de supprimer
   candidat ou référence de l'égalité/hash, même si le code actuel est correct.

## Findings

### P1 — Défaut produit — le lot 3 change prématurément la sémantique des groupes hétérogènes

**Fichier :** `lib/src/auto_size_text.dart:278-287`

Le parent publiait au groupe la taille racine effective calculée. Le candidat
publie désormais le candidat logique, puis chaque membre applique son propre
scaler à la valeur commune. Ce n'est pas une simple adaptation interne : deux
membres historiques utilisant respectivement `textScaleFactor: 1` avec le
preset `[20]` et `textScaleFactor: 2` avec le preset `[15]` rendaient tous deux
une taille effective de `20` sur le parent. Le même probe rend `15` et `30` sur
`cac342c`.

Le commentaire du code reconnaît que seuls les groupes homogènes sont
préservés, et le test permanent de `test/text_scaler_test.dart:253-297` ne
couvre que ce cas. Or l'oracle exclut la publication, la projection et la
convergence de groupe du lot 3 ; le journal reporte lui-même les groupes
hétérogènes au lot 5. Le lot 3 introduit donc une sémantique de lot 5 sans sa
double borne, sans projection dans le domaine individuel et sans test de
compatibilité historique.

**Correction attendue :** conserver le comportement de groupe antérieur dans
ce lot, ou déplacer atomiquement le changement d'unité et toutes ses
conséquences dans le lot 5 avec son oracle et ses tests. Un smoke homogène ne
peut pas justifier la régression hétérogène.

### P1 — Lacune de preuve — les fixtures bold, locale/direction et hauteur ne peuvent pas protéger la parité métrique

**Fichier :** `test/effective_text_configuration_test.dart:192-219` et
`test/effective_text_configuration_test.dart:513-559`

Le test de gras vérifie `w700`, puis compare le résultat à un témoin déjà gras.
Il n'établit jamais que la branche sans `boldText` possède des métriques ou un
candidat différents. Un probe temporaire reprenant exactement cette fixture a
obtenu le candidat `28` avec et sans `boldText`. Le journal confirme à
`maintenance/implementation/lot-3-effective-text.md:165-167` qu'aucune police
de fixture ne garantit une largeur différente entre poids.

De même, le probe reprenant les fixtures permanentes a obtenu :

- locale/direction fallback et `rtl`/`th` : `Size(120.0, 20.0)` des deux côtés ;
- `TextHeightBehavior` par défaut et `applyHeightToLastDescent: false` :
  `Size(160.0, 20.0)` des deux côtés.

Ces tests vérifient que les propriétés arrivent au `RenderParagraph`, mais ils
ne peuvent pas échouer si le fitter mesure la mauvaise branche. L'oracle exige
explicitement un témoin métriquement distinct avant de vérifier le candidat.

**Correction attendue :** ajouter des fontes regular/bold déterministes avec
licence et un test qui prouve d'abord la différence, puis la réduction du
candidat. Choisir également des fixtures direction/locale et
`TextHeightBehavior` dont les témoins divergent réellement avant de comparer
`AutoSizeText` au paragraphe rendu.

### P1 — Lacune de preuve — l'égalité/hash ne protège pas chacun des trois champs

**Fichier :** `test/text_scaler_test.dart:223-250`

Le test permanent prouve seulement qu'un scaler reconstruit avec les mêmes
valeurs est égal et possède le même hash. Une implémentation qui comparerait
uniquement le scaler source passerait encore ce test. Il manque les trois
inégalités isolées exigées par l'oracle : source différente, candidat différent
et référence différente, y compris quand les sorties sont identiques sous un
scaler à plateau.

Le code de `lib/src/auto_size_text_layout.dart` combine bien les trois champs,
et le probe temporaire plateau/rebuild est vert sur 3.41.0 et 3.47.2. Il s'agit
donc d'une lacune de régression permanente, pas d'un défaut produit observé.

**Correction attendue :** obtenir les scalers rendus de cas qui ne changent
qu'un champ à la fois, vérifier leur inégalité, puis vérifier égalité et hash
pour les trois champs identiques. Le cas plateau doit rester inclus pour éviter
qu'une égalité de sortie masque un changement logique nécessitant un layout.

## Audit de l'API et du scaler

- `TextScaler? textScaler` est présent sur les deux constructeurs, qui restent
  `const`.
- Le paramètre des deux constructeurs et le champ `textScaleFactor` restent
  présents et portent `@Deprecated('Use textScaler instead.')`.
- L'assertion d'exclusion mutuelle est const-compatible. La branche runtime
  commune lève `ArgumentError`; son test par sous-classe contourne l'assertion
  et démontre que la protection ne dépend pas des assertions release.
- La priorité est exacte : scaler explicite, ancien facteur fini et positif ou
  nul converti par `TextScaler.linear`, puis `MediaQuery.textScalerOf`.
- Pour une référence positive, `_CandidateTextScaler.scale(s)` délègue à
  `source.scale(s * candidate / reference)`. Aucun getter de compatibilité ne
  décide d'une taille.
- Taille logique, candidat, référence, produit ajusté et sortie sont contrôlés
  comme finis et supérieurs ou égaux à zéro. Les exceptions du scaler source
  ne sont pas interceptées.
- Le zéro simple conserve sa frontière historique sans division ; la
  généralisation RichText reste au lot 4.
- L'égalité/hash du code inclut bien source, candidat et référence. La
  configuration est reconstruite à chaque build ; les changements hérités
  sont observés.
- Aucun usage produit de `MediaQuery.textScaleFactorOf`, de
  `TextPainter(textScaleFactor:)`, de `Text(textScaleFactor:)`, de `dynamic`,
  `noSuchMethod`, `Function.apply` ou d'un shim d'ancienne API n'a été trouvé.

## Audit de la configuration effective

Le snapshot privé sépare correctement :

- le style et le strut post-overrides destinés aux painters ;
- le style et le strut pré-overrides destinés au `Text` final ;
- le scaler candidat explicite, qui empêche une seconde lecture du scaler
  ambiant.

Les priorités de style, gras `w700`, trois overrides, strut, alignement,
direction, locale, wrap, overflow, maxLines, `TextWidthBasis` et
`TextHeightBehavior` correspondent à l'oracle. Le painter reçoit
`constraints.minWidth`; son maximum vaut la contrainte pour wrap/ellipsis et
l'infini sinon. Le fit compare `constraints.constrain(textSize)` à `textSize`
et conserve `didExceedMaxLines`.

Les probes temporaires suivants passent sur 3.41.0 et 3.47.2 : composition
quadratique racine/strut sans lecture du getter, scaler à plateau et rebuild,
produit extrême devenant infini rejeté avant délégation, les quatre valeurs de
`TextOverflow` héritées sous `softWrap: false`, contrainte tight avec
`minWidth`, et frontière de référence zéro simple. Tous les fichiers de probe
ont été supprimés avant le rapport.

## Preuves rouges et matrice verte

### Parent exact `a13534c`

Une archive temporaire du parent a reçu uniquement les deux suites finales :

- `text_scaler_test.dart` ne compile pas, avec « No named parameter with the
  name `textScaler` » sur les deux constructeurs ;
- `effective_text_configuration_test.dart` produit 4 passages et 3 échecs :
  override isolé attendu `23` mais obtenu `30`, strut/override affichant encore
  le replacement, et `softWrap: false` hérité n'affichant pas le replacement.

Les rouges correspondent donc aux causes du lot.

### Flutter 3.47.2 / Dart 3.13.2

- format autoritatif `lib test example` : 24 fichiers, 0 changement ;
- analyse scoped fatale : aucun diagnostic ;
- suites lot 3 : 16/16 ;
- suite complète : 72/72 ;
- leak/cycle de vie explicite : 9/9 ;
- exemple : `pub get --enforce-lockfile` puis analyse fatale, succès.

### Flutter 3.41.0 / Dart 3.11.0

Depuis une archive propre du commit candidat :

- résolution naturelle : 26 dépendances ;
- analyse scoped fatale : aucun diagnostic ;
- suites lot 3 : 16/16 ;
- suite complète : 72/72 ;
- leak/cycle de vie explicite : 9/9 ;
- exemple résolu sans lock forcé : `meta 1.17.0`,
  `vector_math 2.2.0`, analyse fatale verte ;
- `pub downgrade` : 9 dépendances abaissées, puis 72/72 avec `--no-pub`.

Le formatter 3.41.0 voudrait reformater deux fichiers hérités et non modifiés
par ce lot (`leak_tracking_test.dart` et
`text_painter_lifecycle_test.dart`). Ce n'est pas un gate du lot : la roadmap
impose un format unique produit par 3.47.2, puis compilation/analyse/tests sur
le minimum. L'arbre de revue est resté propre.

## Validité des tests et périmètre

Les trois fichiers de test modifiés ou ajoutés possèdent un `group()` et tous
leurs cas commencent par « should ». Les rouges du parent démontrent la
capacité d'échouer des overrides, du strut, du wrap et de l'API moderne. Les
findings ci-dessus recensent les témoins qui restent tautologiques ou
insuffisamment discriminants.

Les modifications RichText restent limitées au passage par l'API moderne et
ne définissent ni runs fidèles, ni NBSP/NNBSP, ni référence zéro riche. Aucun
`WidgetSpan`, placeholder, intrinsic, dry layout ou nouveau paramètre public
de paragraphe n'est ajouté. En revanche, le changement d'unité de groupe est
une sémantique observable du lot 5 et doit être retiré de ce lot.

## Revue complète selon `find-bugs`

Fichiers du diff lus intégralement :

- `lib/src/auto_size_text.dart` ;
- `lib/src/auto_size_text_layout.dart` ;
- `maintenance/implementation/lot-3-effective-text.md` ;
- `test/basic_test.dart` ;
- `test/effective_text_configuration_test.dart` ;
- `test/text_scaler_test.dart` ;
- `test/utils.dart`.

Entrées et état attaquables : paramètres publics des deux constructeurs,
styles/spans/strut, scalers personnalisés, `MediaQuery`/`DefaultTextStyle`,
contraintes de layout, domaine de candidats et état partagé de groupe. Il n'y
a aucune requête de base, authentification, autorisation, session, primitive
cryptographique ni appel réseau dans le diff.

| Checklist | Conclusion |
|---|---|
| Injection, XSS, SQL, auth, autorisation, CSRF, session | Hors surface : widget local sans serveur, template ou identité. |
| Cryptographie, secrets, divulgation | Hors surface ; aucun secret, log sensible ou primitive ajouté. |
| Race / TOCTOU / état | Rebuilds et égalité du scaler audités ; changement prématuré de l'état de groupe signalé en P1. |
| Disponibilité / ressources | Painters sous `finally`, suites leak 9/9 sur deux SDK ; extrêmes non finis rejetés. |
| Déni de service | Recherche toujours logarithmique ; aucun domaine matérialisé par ce lot. |
| Logique numérique | Ordre non linéaire, plateau, zéro, infinies/NaN/négatives, overflow du produit et égalité/hash audités. |
| Compatibilité API | API historique conservée/dépréciée ; constructeurs const et priorité conformes ; régression de groupe signalée. |

Limites : aucun appareil physique/web ni exécution AOT release n'a été lancé.
La branche runtime d'exclusion mutuelle est néanmoins exercée directement en
contournant l'assertion du constructeur. Les métriques réelles de fontes et de
locale restent précisément la lacune de preuve P1, pas un fait supposé.
