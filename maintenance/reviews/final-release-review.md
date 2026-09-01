# Revue finale indépendante de la release 4.0.0

Date : 2026-09-02

Branche de revue : `codex/final-review`

Merge-base avec `master` : `f22397751271605ac46e8740d9e48ed631a74cb0`

Candidat exact : `97acb13165c57ab99d74374b3e5272a03d3ce0fe`

## Verdict

**PASS technique — aucun finding P0, P1 ou P2 ouvert.**

Le diff cumulé implémente les contrats approuvés sans nouvelle divergence
fonctionnelle ou de sécurité observée. Les limites dry/wet du remplacement et
des `WidgetSpan`, ainsi que l'absence de garantie d'optimalité pour un prédicat
non monotone, sont les limites publiques déjà décidées ; elles ne sont pas des
findings de cette revue.

La publication réelle reste soumise à une gate humaine distincte : vérifier
qu'un uploader de `auto_size_text` ou un administrateur du publisher possède
encore l'autorité nécessaire. Cette revue n'établit aucun droit Pub et n'a
effectué ni tag, ni push, ni publication.

## Périmètre relu

La comparaison complète contient 165 fichiers : 7 sous `lib/`, 30 sous
`test/`, 40 sous `demo/`, 3 sous `example/`, 6 sous `.github/`, 73 documents de
maintenance et 6 manifests ou documents package. Aucun chemin modifié ne reste
hors de ces catégories.

Ont été contrôlés en particulier :

- l'API publique, les deux constructeurs `const`, le pont déprécié
  `textScaleFactor`, `TextScaler`, les valeurs par défaut et le changement
  documenté de `textKey` ;
- les validations runtime, le domaine virtuel des candidats, ses bornes ULP,
  la dichotomie logarithmique et l'absence de mutation des presets ;
- la configuration effective du paragraphe, les scalers non linéaires, la
  référence zéro, le gras et les overrides de métriques ;
- l'arbre riche, les offsets UTF-16, NBSP/NNBSP, les métadonnées,
  recognizers, interactions et sémantiques ;
- la projection et le cycle de vie des groupes, la coalescence des
  notifications, les transferts, retraits et remontées de minimum ;
- le render object public-only, les six métriques dry/intrinsèques, les
  fallbacks bornés, la libération des painters et la récupération après erreur
  du scaler ;
- l'extraction `WidgetSpan` en préordre, le facteur par run, les alignements et
  baselines wet, le paint transform, le hit test, la sélection, les GlobalKeys,
  le remplacement lazy, la complexité `O(P log C)` et le disposal ;
- les pubspecs et locks, le README, le changelog, l'exemple, la démo Android,
  la provenance du wrapper Gradle et des fontes de test, ainsi que le contenu
  de l'archive Pub ;
- les cinq gates CI, les pins Flutter/actions, les permissions, caches,
  copies isolées minimum/downgrade, `pipefail`, dartdoc et publish dry-run ;
- les suppressions de `FUNDING.yml` et `no-response.yml`, le retrait de
  l'assignee historique et l'URL `repository` identique à `origin`.

Les audits, décisions, feuille de route, rapports d'implémentation, revues et
matrices sous `maintenance/` ont été recoupés avant le code final. Les anciens
findings concernant la projection de groupe, le lifecycle dry, l'état du
remplacement, les GlobalKeys et la propagation des erreurs de pipeline sont
fermés par leurs correctifs et preuves dédiés.

## Preuves et contrôles ciblés

- `git diff --check f223977..97acb13` : propre.
- `git ls-files -ci --exclude-standard` : aucun fichier suivi mais ignoré.
- recherche de clés, tokens, fichiers de credentials, imports privés Flutter,
  artefacts de build et automatisations privilégiées : aucun élément actif
  trouvé dans le produit ou la livraison.
- `.github/workflows/dart.yml` a exactement le même blob Git
  (`bc27061d...`) qu'au SHA `abb7d17` de la re-review CI finale.
- après le merge WidgetSpan revu `8e40312`, `lib/**` ne reçoit que 14 ajouts et
  9 suppressions dartdoc dans trois fichiers ; `test/**` est inchangé.
- sonde binaire64 ciblée autour des puissances de deux et des frontières ULP :
  aucun alias intérieur n'est accepté lorsque la garde de progression du
  domaine régulier laisse passer l'entrée.
- le JAR Gradle final conserve le SHA-256 documenté
  `b3a875ddc1f044746e1b1a55f645584505f4a10438c1afea9f15e92a7c42ec13` ;
  les trois TTF conservent également leurs hashes et licences documentés.
- le candidat et le worktree sont restés propres avant l'ajout de ce rapport.

La matrice release complète n'a pas été rejouée : aucune modification
comportementale, de test ou de workflow n'est intervenue après les validations
indépendantes bi-SDK/CI correspondantes, et aucun soupçon concret
supplémentaire ne le justifiait. La seule sonde nouvelle est celle de
progression numérique ci-dessus.

## Sécurité et gouvernance

Le workflow limite `GITHUB_TOKEN` à `contents: read`, désactive la persistance
des credentials, n'écoute ni `pull_request_target` ni événement de publication
et ne possède aucun secret ou permission d'écriture. Le publish reste
strictement `--dry-run`; le checkout canonique est contrôlé propre après chaque
gate. Les actions et Flutter sont épinglés à des SHA complets.

La suppression du financement historique évite une destination non approuvée.
La suppression de la configuration Probot non vérifiée évite une fermeture
automatique obsolète. Le retrait de l'assignee de l'ancien mainteneur évite une
attribution fantôme. Aucun de ces changements ne retire une gate produit ou CI.

Les chemins absolus présents dans les journaux de preuve restent confinés à
`maintenance/`, exclu de l'archive Pub. Aucun chemin personnel, credential,
lock racine, wrapper Gradle, démo, sortie de build ou fichier local n'entre dans
l'archive validée.

## Risques résiduels acceptés ou externes

- droits uploader/publisher et contrôles serveur Pub non prouvables localement ;
- géométrie dry/intrinsic volontairement différente du wet pour le
  remplacement lazy et les enfants `WidgetSpan` ;
- optimum non garanti pour un scaler ou un child dont le prédicat de fit n'est
  pas monotone ;
- `SECURITY.md` non inventé tant qu'aucun canal réellement surveillé n'est
  fourni ; GitHub déduit l'issue tracker du champ `repository` ;
- le render object s'appuie sur l'API Flutter publique mais `@protected`
  `invokeLayoutCallback`, à revalider lors d'une future hausse du minimum.

Aucun de ces risques ne constitue un défaut P0-P2 du candidat sous le contrat
de release arrêté.
