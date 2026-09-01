# Intégration démo et archive sur S8

Date : 2026-09-02

## Ascendance et contenu

- base exacte : `4794200df27ba042a4c8a8ebbe82719c499340f6` (S8) ;
- démo portée sans conflit depuis `5c5d325243b0c0a0cdc6ea4e4a85807792b1265b` ;
- archive portée sans conflit depuis `b2b9b72b6b5bf5b4b30832494b2bb48eeba43861` ;
- revues initiales consultées : `4bc8a4b7f290969e74d12471114e3a3be64dadec`
  et `0be09ace4954f3bae0a7ad888c4963b8bb0e5046` ;
- aucun fichier `lib/**`, aucune API publique et aucun changement WidgetSpan.

Les deux cherry-picks sont mécaniques. Aucun correctif fonctionnel
supplémentaire n'a été nécessaire sur S8.

## Validation

| Surface | Flutter 3.41.0 | Flutter 3.47.2 |
|---|---|---|
| Package : `pub get` | succès | succès |
| Analyse globale fatale | succès | succès |
| Tests package | 143/143 | 143/143 |
| Démo : lock forcé | non applicable, minimum déclaré 3.47.2 | succès, lock inchangé |
| Démo : analyse fatale | non applicable | succès |
| Démo : smoke tests | non applicable | 4/4 |
| Démo : APK release | non applicable | succès, 44 561 230 octets |

Le lock de la démo conserve le SHA-256
`a33b1dd565ee362192f89e445a471e6110ec619195bc595a2c84c6f3bf1c98fb`.
L'APK release a le SHA-256
`d102624cba3412d04034f4f3758a583f17cf848c691a33dd17968a0a6a5ed9f4`.
Le formatage Dart contrôle 42 fichiers sans changement.

`dart pub publish --dry-run` construit une archive de 61 KB contenant 42
fichiers. Elle inclut les six fichiers `lib/**`, les tests S8 et les cinq
polices/licences sous `test/assets/fonts/**`. Elle exclut `maintenance/**`,
`demo/**`, `.github/**`, les lockfiles, les sorties générées, les fichiers
locaux/secrets et les wrappers Gradle. La validation du dry-run termine avec
un code zéro. Aucun publish réel n'a été tenté.

## État final

La composition de l'archive, les présences requises, les exclusions et la
terminaison avec code zéro du dry-run Pub ont été contrôlées sur cette union.
