# Revue indépendante — oracle adversarial du cycle de vie des groupes

Date : 2026-09-01

Branche revue : `codex/review-group-lifecycle-oracle`

Tête revue : `296b6832da44bc246b84991ad889e905ac8d6e0d`

Base produit exécutée : `S5` / `c9a1adc006365feb3e1750069ca1e115c3f20237`

## Verdict

**ACCEPTÉ**

Aucun finding bloquant ou actionnable n'a été trouvé. L'oracle adversarial
résout correctement les deux ambiguïtés de l'oracle principal : seules les
assertions discriminantes du lot 5 doivent être rouges sur S5, et une erreur
rencontrée après la publication d'un rapport fini suit une sémantique non
transactionnelle sans rollback.

La distinction entre tâche planifiée, tâche exécutée, vague avec callbacks et
callback membre est nécessaire. Elle empêche précisément un test de frame ou
de rebuild de masquer plusieurs callbacks `setState` devenus idempotents au
niveau de l'élément Flutter.

## Findings ordonnés

Aucun.

## Vérifications indépendantes

Un fichier de probe widget temporaire, supprimé avant cette revue, a exécuté
huit cas sur les deux bundles exacts :

| SDK | Révision Flutter | Dart | Résultat |
|---|---|---|---|
| Flutter 3.41.0 | `44a626f4f0` | 3.11.0 | 8/8 |
| Flutter 3.47.2 | `d3b14c8769` | 3.13.2 | 8/8 |

Les résultats sont identiques sur les deux pins.

### Coalescence S5

Le probe `ZoneSpecification` a isolé les appels dont la pile contenait
`auto_size_group.dart`. Une mutation synchrone des rapports `10/20 → 30/40`
a produit exactement :

```text
schedule = 2
run      = 2
fin de la frame de publication = 20/30
fin de l'unique frame de synchronisation = 30/30
```

Ce résultat confirme le diagnostic S5 : `_widgetsNotified` évite une seconde
vague de callbacks, mais n'évite ni la seconde planification ni l'exécution de
la seconde microtâche. Le gate lot 5 `1 schedule / 1 run / 1 callback par
membre courant` est donc discriminant. Les compteurs de phase exigés par
l'oracle restent nécessaires ; une seule frame programmée n'aurait pas prouvé
le nombre de tâches ou de callbacks.

### Rouge discriminant et locks historiques

Les probes séparent bien les deux catégories :

- presets disjoints `{10,20,40}` / `{10,30}` : S5 rend `40/30`, puis
  `30/30`; la cible `20/30` est rouge pour la cause lot 5 ;
- identité/quadratique avec rapports `50/90` : S5 rend `50/50`; la cible
  `50/40` est rouge pour la confusion entre limite effective et candidat
  logique ;
- replacement local : seul le replacement du membre localement non fit est
  monté et sa contribution reste active, tandis que S5 rend le voisin à 20
  hors de son domaine `{30,40}`; le lock local est vert et la projection reste
  rouge ;
- groupe homogène, retrait/dispose, transfert, passage à `null`, transfert
  pendant une vague pending et identité du builder restent verts sur S5.

Les autres assertions discriminantes de la table se déduisent directement du
flux S5 qui rend `G` : la grille incompatible rend 30 au lieu de 26, le minimum
inaccessible peut être rendu sous le domaine, et la sortie `G + 1 ULP` n'est
pas projetée. Il n'est donc ni nécessaire ni correct d'inverser une attente
historique pour fabriquer un rouge.

### Retrait, dispose, transfert et `null`

Avec des clés stables et un survivant non reconstruit par le parent, le retrait
du minimum a produit la trace `20 → 40` attendue :

1. le membre retiré disparaît pendant la frame de retrait ;
2. le survivant reste momentanément à 20 et une frame est programmée ;
3. la frame suivante le rend à 40 ;
4. le compteur du scaler du membre démonté ne change plus ;
5. `tester.takeException()` reste nul après la microtâche et après la frame.

Le transfert simple de A depuis g1 `{A:20,B:40}` vers g2 `{C:50}`, puis vers
`null`, donne respectivement `20/40/20` et `20/40/50`, sans exception ni retour
du rapport dans l'ancien groupe.

Le cas pending ordonne D, A et C. D remonte de 10 à 30 avant le transfert de A,
alors que g2 reste borné par C=10. Le compteur du scaler de A ne change pas
pendant la frame déclenchée par l'ancienne vague : un snapshot de listeners ou
un simple test `mounted` aurait rendu ce delta non nul, puisque A reste monté
dans g2.

### Plateau racine zéro

Le probe utilise un vrai `RenderParagraph`, Ahem, `F=20`, `S=100`,
`D={10,20,30}` et `U(x)=max(0,x-30)`. Les boxes témoins indépendantes donnent
exactement :

```text
candidat 20 -> racine 0, run 70
candidat 30 -> racine 0, run 120
```

Une largeur située entre 70 et 120 force le local à 20. S5 passe directement
la limite zéro et produit racine/box `0/0`. Une projection à seule borne
effective choisit 30 et produit 120 ; la double borne choisit 20 et produit 70.
La fixture tue donc séparément le passage direct de `G` et la perte de borne
locale. Elle ne dépend pas d'un golden moteur arbitraire : le seuil vient des
deux témoins de la même pin.

### Invalides non transactionnels

Un probe privé de coordinateur a reproduit l'ordre normatif avec
`D_A={10,20,30,40,50}`, B=15 et C=70. La dichotomie locale visite uniquement
les candidats hauts et produit un rapport A=50 fini. La projection sous G=15
atteint ensuite le candidat bas dont la sortie est NaN et lève
`ArgumentError`. Après l'erreur :

```text
reports[A] = 50
aucune valeur invalide n'est stockée
après retrait de B, G = 50 et non 70
```

La fixture distingue donc réellement la conservation du rapport d'un rollback.
Le fallback prévu vers un probe privé si le montage `ErrorWidget` devient
fragile rend l'exigence testable sans exposer d'API et sans dépendre du rendu
d'erreur de Flutter.

### Détails privés et compteurs de scaler

Les observations absolues `5/5`, `10/10` et `9→9` décrivent S5 mais ne sont pas
transformées en API ou en compte normatif. Le document exige correctement :

- un delta nul sur une frame témoin sans élément dirty ;
- un delta nul pour A pendant l'ancienne vague après transfert ;
- des entrées de scaler discriminantes, tout en acceptant les appels
  supplémentaires de Flutter ;
- un compteur interne séparé pour chaque phase de projection, publication et
  callback.

Le filtrage de pile du `ZoneSpecification` ne sert qu'à constater S5. Le gate
lot 5 demande une instrumentation privée temporaire et ne dépend donc ni du
nom permanent d'un fichier source, ni du nombre global d'appels effectués par
`RenderParagraph`.

## Régressions historiques ciblées

Les suites suivantes ont été exécutées ensemble sur chaque pin avec une
résolution propre au SDK :

```text
test/group_test.dart
test/group_builder_test.dart
test/text_scaler_test.dart
test/text_painter_lifecycle_test.dart
test/preset_font_sizes_test.dart
```

Résultat : 29/29 sur Flutter 3.41.0 et 29/29 sur Flutter 3.47.2. Cela confirme
que les locks historiques ne sont pas des rouges du lot 5.

## Périmètre lu intégralement

Le diff complet contient uniquement
`maintenance/decisions/group-lifecycle-adversarial-oracle.md`, lu ligne par
ligne. Ont aussi été relus intégralement :

- `maintenance/decisions/group-projection-oracle.md` ;
- la décision exécutive, les critères communs, le lot 5 et les gates de
  `maintenance/implementation-roadmap.md` ;
- les oracles candidat, configuration effective, RichText et RichText
  adversarial des lots 2 à 4 ;
- les journaux d'implémentation des lots 2 à 4 ;
- `lib/auto_size_text.dart`, `lib/src/auto_size_group.dart`,
  `lib/src/auto_size_group_builder.dart`, `lib/src/auto_size_text.dart` et
  `lib/src/auto_size_text_layout.dart` ;
- tous les tests qui créent ou observent un groupe, ainsi que leurs helpers :
  `group_test.dart`, `group_builder_test.dart`,
  `text_painter_lifecycle_test.dart`, `text_scaler_test.dart`,
  `preset_font_sizes_test.dart`, `utils.dart` et
  `flutter_test_config.dart`.

Les instructions `AGENTS.md` fournies au chantier n'ajoutent qu'un workflow
PostHog, sans application à cette revue locale.

## Audit pré-conclusion

La modification est documentaire : aucun input réseau, requête de données,
contrôle d'authentification/autorisation, session, appel externe ou opération
cryptographique n'est ajouté. Injection, XSS, CSRF, IDOR, secrets et fuite
d'information sont donc hors surface.

Les points applicables de la checklist ont été vérifiés :

- état et race de microtâches : coalescence, pending, lecture des membres
  courants et limite la plus récente ;
- cycle de vie : inscription, même groupe, transfert, `null`, retrait et
  dispose ;
- logique métier : unités `L/P/G/R`, domaines hétérogènes, replacement et
  invalides ;
- disponibilité : projection logarithmique, domaine virtuel et absence de
  matérialisation proportionnelle à C ;
- qualité des tests : témoins indépendants, assertions par candidat/métrique,
  compteurs de phase et frame témoin.

La seule limite de cette revue est intentionnelle : aucun code produit du lot 5
n'existe dans le diff. Les preuves vertes de la future tête, les compteurs
privés de cette tête et la matrice complète devront donc encore être vérifiés
pendant la revue d'implémentation. Cette limite ne remet pas en cause la
cohérence ni la testabilité de l'oracle.

Les probes temporaires ont été supprimés. Aucun hook public, changement produit
ou lockfile de résolution n'est conservé.
