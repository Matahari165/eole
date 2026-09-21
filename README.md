# Eole

Application iPhone native de respiration guidée, développée en SwiftUI pour iOS 26.
Eole accompagne chaque phase d’une séance, mesure les rétentions et conserve
l’historique localement avec SwiftData.

## Ce que le projet démontre

- Architecture native séparant l’interface (`EoleApp`) de la logique métier
  vérifiable (`EoleCore`).
- Gestion d’une séance chronométrée avec reprise après passage en arrière-plan.
- Audio local avec ambiances, guides respiratoires, repères sonores et haptics.
- Interface iPhone compacte avec Dynamic Type, VoiceOver, Reduce Motion et
  orientation portrait pris en compte.
- Statistiques de pratique sur 7 ou 30 jours et export CSV.

## Périmètre

- iPhone uniquement, format de référence `390 × 844`.
- iOS 26 et Swift 6 ; aucune compatibilité iOS antérieure n’est visée.
- Données et préférences conservées sur l’iPhone.
- Pas d’authentification ni de synchronisation cloud dans cette version.

## Architecture

```text
ios/
  Eole.xcodeproj/       Projet Xcode et cible applicative
  EolePhoneApp.swift    Point d’entrée de l’application
  Assets.xcassets/      Icônes
  Resources/Audio/      Audio embarqué et licences

native/Sources/
  EoleApp/              Vues SwiftUI, séance, audio et persistance
  EoleCore/             Modèles, validation, statistiques et export
  EoleCoreVerify/       Vérification autonome de la logique métier
native/Tests/
  EoleCoreTests/        Tests unitaires SwiftPM de la logique métier
```

Le projet Xcode compile les sources natives directement afin que l’application
et la cible SwiftPM partagent la même implémentation.

## Prérequis

- macOS compatible avec Xcode 26
- Xcode 26 avec un SDK iOS 26
- Swift 6
- Un simulateur ou un iPhone sous iOS 26
- Une équipe de signature Apple sélectionnée dans Xcode pour un lancement sur
  appareil réel

## Lancer l’application

1. Ouvrir `ios/Eole.xcodeproj` dans Xcode 26.
2. Sélectionner la cible `Eole` et un simulateur ou iPhone sous iOS 26.
3. Choisir son équipe Apple dans les réglages de signature si nécessaire.
4. Lancer l’application.

Pour une compilation de contrôle sans signature :

```bash
xcodebuild \
  -project ios/Eole.xcodeproj \
  -target Eole \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Vérifier

Depuis `native/`, les deux commandes suivantes couvrent respectivement les
tests XCTest et la vérification autonome de la logique métier :

```bash
swift test
swift run EoleCoreVerify
```

Ces contrôles ne remplacent pas un build Xcode ni une vérification sur iPhone.
Ils ne prouvent notamment pas le rendu SwiftUI, les routes audio, les haptics,
le verrouillage de l’écran ou les interruptions système.

## Données, sécurité et audio

Les séances sont stockées dans SwiftData et les réglages légers dans
`UserDefaults`. La synchronisation distante reste désactivée. Le détail des
sources et licences audio se trouve dans
[`ios/Resources/Audio/SOURCES.md`](ios/Resources/Audio/SOURCES.md).

La respiration rapide suivie d’une apnée peut provoquer vertiges ou malaise.
Une notice demande de pratiquer assis ou allongé, jamais dans l’eau, au volant
ou dans une situation où un malaise serait dangereux. Cette application ne
remplace pas un avis médical.

## Limites connues

- La cible automatisée couvre la logique métier ; l’interface, l’audio et le
  comportement matériel nécessitent encore une vérification Xcode/simulateur/
  iPhone selon le niveau de preuve recherché.
- Les données restent locales : aucune récupération entre appareils n’est
  proposée.
