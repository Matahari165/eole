# Eole — conventions du projet

## Produit

- Eole est une application native de respiration pour iPhone `390 × 844` et
  iOS 26 uniquement.
- L’interface utilise les API Liquid Glass natives pour la navigation et les
  contrôles ; les surfaces de contenu restent sobres et lisibles.
- Les séances vivent dans SwiftData et les préférences légères dans
  `UserDefaults`. La synchronisation cloud reste désactivée.
- `pendingSync` fait partie du schéma SwiftData historique et doit être
  conservé pour la compatibilité des données existantes.

## Direction visuelle

- Préserver l’identité calme et aquatique d’Eole : SF Pro, palette teal, fond
  système adaptatif, contours respiratoires réservés à la séance active.
- Respecter Dynamic Type, VoiceOver, Reduce Motion, le contraste et des zones
  tactiles d’au moins 44 points.
- Garder les textes visibles utiles à comprendre, décider, agir, attendre ou
  corriger une erreur.

## Qualité et périmètre

- Préférer les API Apple existantes et les changements simples, locaux et
  réversibles.
- Préserver les données existantes et inspecter `git diff` avant toute
  livraison.
- Vérifier séparément logique métier, build Xcode, simulateur et appareil réel.
  Une compilation ne prouve pas une séance complète, l’audio ou les haptics.
- Tester les parcours normal, vide, erreur, interruption, arrière-plan, reprise
  et migration lorsqu’ils sont concernés.
