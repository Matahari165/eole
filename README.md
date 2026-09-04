# Eole

Eole est une application iPhone native de respiration guidée, développée en SwiftUI pour iOS 26. Elle guide chaque phase d'une séance, chronomètre les rétentions et conserve l'historique localement avec SwiftData.

## Fonctionnement

- 1 à 8 rounds, 10 à 60 respirations et trois rythmes.
- Sons respiratoires, ambiances et vibrations réglables.
- Rétention libre, récupération guidée de 15 secondes et arrêt protégé.
- Statistiques sur 7 ou 30 jours et export CSV.
- Données et préférences stockées uniquement sur l'iPhone.

## Structure

- `ios/Eole.xcodeproj` : projet et point d'entrée de l'application.
- `ios/Assets.xcassets` : icône et ressources visuelles.
- `ios/Resources/Audio` : fichiers audio embarqués et leurs licences.
- `native/Sources/EoleApp` : vues, moteur de séance, audio et persistance.
- `native/Sources/EoleCore` : modèles, validation, statistiques et export.
- `native/Sources/EoleCoreVerify` : vérifications autonomes de la logique métier.

## Lancer l'application

1. Ouvrir `ios/Eole.xcodeproj` dans Xcode.
2. Choisir un simulateur ou un iPhone sous iOS 26.
3. Lancer le scheme `Eole`.

Le format de référence est l'iPhone `390×844`.

## Vérifier la logique métier

```bash
cd native
swift run EoleCoreVerify
```

Le projet Xcode doit aussi être compilé avant livraison afin de vérifier l'intégration SwiftUI et les ressources embarquées.

## Données et sécurité

Les séances restent dans SwiftData et les réglages légers dans `UserDefaults`. Aucune synchronisation distante ni authentification applicative n'est active.

La respiration rapide suivie d'une apnée peut provoquer vertiges ou malaise. L'application affiche une notice à la première ouverture : pratiquer assis ou allongé, jamais dans l'eau, au volant ou dans une situation dangereuse en cas de malaise.
