# Revue architecturale du prototype layout lean — lot 8

## Verdict

**GO ACCEPTÉ.** Aucun finding P0, P1 ou P2 n'est ouvert.

Le contrat lean est suffisamment sûr et simple pour autoriser les lots 9 et 10.
Il ne promet plus une géométrie dry exacte pour une replacement arbitraire non
montée ni pour un `WidgetSpan` arbitraire. Il promet, dans ces deux cas, un
résultat fini, contraint, déterministe et sans consultation du subtree concerné.
Ce compromis est explicite dans la note et dans la feuille de route ; il n'est
pas traité comme une régression de taille.

Ce verdict accepte une décision de prototype. Il ne ferme aucune issue layout
et ne dispense pas les lots produit de leurs propres tests rouges/verts, de la
matrice minimum/haute et des revues render indépendantes prévues.

## Périmètre et provenance

Chaîne auditée :

- base demandée : `dd1d0aded0a9876896eba21c28119214ceea733f` ;
- restauration des preuves antérieures : `69f068e8d923403c25d4fa4d6ca0990d5029eac9` ;
- archive reproductible du contrat lean :
  `f554255d31908a13a29fbaac49ad5bd04ca8f325` ;
- note et roadmap révisés, avec suppression du spike :
  `7a2f6a76dc4f879c0e11611efb969184d1afd2aa`.

Le diff cumulé `dd1d0ad..7a2f6a7` modifie seulement :

- `maintenance/layout-prototype-decision.md` ;
- `maintenance/implementation-roadmap.md`.

Aucun fichier produit ou de spike ne reste au tip. L'extraction indépendante de
`f554255` contient les six artefacts annoncés, avec les tailles et SHA-256
publiés dans la note :

| Fichier | Lignes | SHA-256 |
| --- | ---: | --- |
| `tool/layout_spike/spike.dart` | 1 140 | `b33726d3c8482c632bfb60e41e01a5816edd319856010654f751ab4cfc476f3d` |
| `tool/layout_spike/evidence.dart` | 456 | `13860dbb9f9625b05c8bc5908870dbab826a27b3649d0e15e7fbbb91025f9419` |
| `tool/layout_spike/lean.dart` | 679 | `6487bc49bd3178b9f15bc87cc7e0737e973cc0e95cabae8acb8f0b30b18ff27a` |
| `test/layout_spike_gate_test.dart` | 745 | `da456f7e8c988e8bfb85fec97717d68a21cecc275c603d23a2cd04746624eb0a` |
| `test/layout_spike_evidence_test.dart` | 517 | `ae7ba0990a2378c4ba5e9e9ca1781ed991cf876c9d607d8243a6305289794c79` |
| `test/layout_spike_lean_test.dart` | 460 | `2ccf6c79523b43cce6f76061553c7d6d3d40a6521078b60b7b6cebe58b8f916f` |

## Revalidation ciblée du contrat lean

### Replacement strictement lazy

`SpikeLeanOverflowParagraph` ne demande jamais une métrique au child actif dans
ses chemins normaux dry, baseline ou intrinsic. Ces chemins recréent une mesure
de texte pure avec un `TextPainter` temporaire. La branche replacement est
choisie uniquement par le builder exécuté depuis `runLayoutCallback` pendant le
wet layout.

Le test commence avec le texte monté, effectue dry layout, baseline et quatre
intrinsics, passe ensuite en overflow wet avec une replacement contenant un
`LayoutBuilder` et un descendant wet-only, puis répète les six requêtes sèches.
La replacement n'est ni construite avant le wet ni interrogée après son montage.
Le mutant `lean_reads_active_child` déclenche précisément le descendant interdit
et est tué sur les deux pins.

### Fallback texte minimum stable et contraint

Quand aucun candidat local ne tient, `_selectLeanText` force le candidat minimum,
mesure le paragraphe et applique `BoxConstraints.constrain` à sa taille. Un
`TextPainter` indépendant établit l'attendu du test. Trois appels avant wet,
deux après activation de la replacement, un appel après retour au texte et une
contrainte alternative rendent le même résultat attendu pour chaque contrainte.
La baseline et les quatre intrinsics sont également stables avant/après wet.

Toutes les valeurs observées sont finies et tous les painters temporaires sont
disposés en `finally`. Le mutant `lean_fallback_max_candidate` est tué sur les
deux pins. La différence admise entre ce fallback et la taille wet de la
replacement n'est pas un finding.

### Pureté dry, groupe et référence zéro

Les requêtes dry/intrinsic n'appellent pas `onPublish`, n'incrémentent pas le
compteur de publication wet, ne lisent pas le child actif et ne modifient aucun
cache observable. La limite de groupe est transmise comme valeur et la
publication wet n'arrive qu'après le layout du child final.

Une référence typographique zéro emploie le chemin explicite sans division. Le
dry layout et la baseline restent finis et aucun `FlutterError` n'est produit
sur les deux SDK. Le contrat demandé ici est l'absence de crash et de facteur
non fini, pas la restauration d'une parité géométrique non promise.

### `WidgetSpan` wet-only et six métriques zéro

Le wrapper lean appelle le vrai child uniquement dans `performLayout`. Sous les
contraintes loose utilisées par `RenderParagraph` pour ses enfants inline, il
retourne :

- `Size.zero` pour le dry layout ;
- baseline zéro ;
- zéro pour les largeurs intrinsèques min et max ;
- zéro pour les hauteurs intrinsèques min et max.

Le child témoin lève sur chacune de ces six APIs : aucun appel ne lui parvient.
Les mutants `lean_placeholder_calls_child_dry` et
`lean_placeholder_calls_child_intrinsic` sont tués sur les deux pins.

Le wet layout réel rend `12 × 6` dans le probe. Le wrapper lean est un
`RenderProxyBox` transparent pour paint, hit testing et sémantique ; il ne
remplace que ses métriques non-wet et délègue son wet layout à `super`. Les
preuves héritées vérifient en plus paint effectif, transformation 0,5, hit test,
`PointerDownEvent`, tag `PlaceholderSpanIndexSemanticsTag`, registrar de
sélection et disposal. Aucune nouvelle logique de paint, hit ou sémantique n'est
introduite par le wrapper lean.

### Frontière render et APIs Flutter

Les six fichiers n'importent que les bibliothèques publiques
`package:flutter/{widgets,rendering,material,gestures}.dart`, `flutter_test` et
`dart:ui`. Aucun import `package:flutter/src`, aucun identifiant privé Flutter
et aucune API publique du package `auto_size_text` ne sont ajoutés.

Le même code compile et s'analyse sur les deux pins. La frontière commune reste
un petit parent render, un sous-type borné de `RenderParagraph`, des wrappers
inline internes et les APIs publiques de `TextPainter`/`PlaceholderDimensions`.
`invokeLayoutCallback` est public au sens Dart mais `@protected` ; le code
l'utilise seulement depuis la sous-classe pendant son wet layout, comme le
documentent la note et le roadmap.

### Alignement de la roadmap

Les lots 8, 9, 10 et la Gate Architecture portent le même contrat :

- replacement inactive non montée et jamais consultée hors wet ;
- fallback texte minimum contraint lorsque wet choisit la replacement ;
- `WidgetSpan` sans paramètre public de dimensions ;
- six métriques de placeholder zéro hors wet ;
- wet complet pour layout, baseline, paint, hit et sémantique ;
- exactitude dry/wet exigée seulement hors des deux divergences adoptées ;
- aucun finding fermé par le prototype seul.

La note énumère aussi les limites : baseline alphabétique, hypothèse monotone
pour l'optimum, résultat seulement sûr/déterministe pour un child non monotone,
dépendance `@protected` à revérifier et tests produit encore obligatoires. Les
limites sont proportionnées au GO lean et ne réintroduisent pas une exactitude
universelle abandonnée.

## Matrice indépendante rejouée

`f554255` a été extrait par `git archive` dans un répertoire temporaire. Les
SDK réellement exécutés sont :

- Flutter 3.41.0, framework `44a626f4f0`, Dart 3.11.0 ;
- Flutter 3.47.2, framework `d3b14c8769`, Dart 3.13.2.

Sur chaque pin :

```text
flutter pub get --no-example
dart format --output=none <les six fichiers>
flutter analyze <les six fichiers>
flutter test test/layout_spike_gate_test.dart \
  test/layout_spike_evidence_test.dart \
  test/layout_spike_lean_test.dart --reporter expanded
```

| Contrôle | Flutter 3.41.0 | Flutter 3.47.2 |
| --- | ---: | ---: |
| Format | 6 fichiers, 0 changement | 6 fichiers, 0 changement |
| Analyse | aucune issue | aucune issue |
| Tests | 32/32 | 32/32 |
| Mutants | 15/15 tués | 15/15 tués |

Chaque mutant a été exécuté isolément contre les trois suites complètes. Tous
retournent exit 1 sur chaque pin :

| Mutant | 3.41.0 | 3.47.2 |
| --- | ---: | ---: |
| `linear_search` | tué | tué |
| `wet_uses_dry` | tué | tué |
| `dry_publish` | tué | tué |
| `skip_final_layout` | tué | tué |
| `zero_division` | tué | tué |
| `no_dispose` | tué | tué |
| `intrinsic_uses_dry` | tué | tué |
| `zero_baseline_shortcut` | tué | tué |
| `explicit_dry_uses_cache` | tué | tué |
| `no_inline_transform` | tué | tué |
| `no_wrapper_dispose` | tué | tué |
| `lean_reads_active_child` | tué | tué |
| `lean_fallback_max_candidate` | tué | tué |
| `lean_placeholder_calls_child_dry` | tué | tué |
| `lean_placeholder_calls_child_intrinsic` | tué | tué |

Les traces déterminantes concordent avec la note : replacement `30 × 40`,
fallback `40 × 10`, baseline 7,5, wrapper wet `12 × 6`, dry zéro, `C=1024` en
10 évaluations et groupe local 40/rendu 18 avec un relayout final.

Après le passage final 3.47.2, `example/pubspec.lock` est byte-identique à la
base et au tip, SHA-256
`115848ebae231fd23d59e6f2d5945b59016605d8b14fb4b7f23de2ad8916b1f7`.
`git diff --check dd1d0ad..7a2f6a7` est propre.

## Inventaire et checklist finale

Lus intégralement :

- `maintenance/layout-prototype-decision.md` au tip ;
- `maintenance/implementation-roadmap.md` au tip ;
- les 1 140 lignes de `tool/layout_spike/spike.dart` à `f554255` ;
- les 456 lignes de `tool/layout_spike/evidence.dart` ;
- les 679 lignes de `tool/layout_spike/lean.dart` ;
- les 745 lignes de `test/layout_spike_gate_test.dart` ;
- les 517 lignes de `test/layout_spike_evidence_test.dart` ;
- les 460 lignes de `test/layout_spike_lean_test.dart` ;
- les portions communes pertinentes de `RenderParagraph` sur les deux pins.

Surface d'entrée : spans, widgets, contraintes, scalers, snapshots de groupe,
callbacks locaux et `SPIKE_MUTANT`. Aucun réseau, base, authentification,
autorisation, session, stockage, secret ou cryptographie.

| Risque | Conclusion |
| --- | --- |
| Injection, XSS, SQL, commandes | hors surface |
| Authentification, autorisation/IDOR, CSRF, session | hors surface |
| Cryptographie, secrets, divulgation | hors surface |
| Race/TOCTOU | aucune concurrence ; snapshot dry par valeur ; aucune publication dry |
| Disponibilité/DoS | recherche normale bornée logarithmiquement ; pas de subtree arbitraire interrogé hors wet |
| Ressources | painters en `finally`, wrappers et paragraphe disposés |
| Logique | lazy, minimum, zéro, groupe, non-monotonie et état final couverts |

Tests sur appareil, profile/web et suite produit complète ne sont pas requis
pour accepter cette note de prototype. Ils ne deviennent pas des conditions
exploratoires supplémentaires. Les lots 9 et 10 restent responsables de leurs
gates produit écrites.
