# Règles du projet Eole

## Communication et cadrage

- Réponds en français, simplement et sans phrases inutiles. Commence par la conclusion utile.
- Avant toute modification, donne un plan court, les hypothèses importantes et les critères de réussite.
- Si une ambiguïté peut changer significativement le résultat, pose une seule question et attends la réponse avant de coder.
- Une demande de conseil, d'explication, d'audit ou de lecture seule n'autorise aucune modification.

## Interface et expérience utilisateur

- Conserve une identité visuelle cohérente, naturelle et centrée sur la respiration. Évite l'apparence générique des applications générées par IA, les cartes répétitives et les espaces vides sans fonction.
- Chaque texte visible doit aider à comprendre, décider ou agir. Le titre de l'onglet reste `Eole`.
- Eole est conçu et vérifié uniquement au format iPhone `390x844`. Ne réalise aucun test ni aucune adaptation spécifique pour Mac ou ordinateur.
- Vérifie contraste, lisibilité, focus visible, zones tactiles et information indépendante de la couleur.
- Utilise le navigateur intégré pour toute modification visuelle ou interactive significative ; une petite correction évidente peut recevoir une vérification proportionnée.

## Développement, qualité et Git

- Inspecte les conventions et l'état Git avant de modifier. Préserve les changements existants et reste strictement dans le périmètre demandé.
- Utilise la solution la plus simple qui répond au besoin, réutilise l'existant et n'ajoute pas de dépendance sans bénéfice clair.
- Utilise une branche par modification cohérente et livrable ; ne mélange pas deux sujets indépendants.
- Après une modification, vérifie selon le risque : cas normal, chargement, absence de données, erreur, accessibilité, types, lint, tests et build pertinents.
- Relis le diff final. Un commit local, un push, un déploiement et une vérification en production sont des preuves distinctes.
- Ne publie, ne déploie, n'envoie de message et ne modifie aucun service externe sans autorisation explicite.
- Ne mets jamais dans le code, Git, les journaux ou les réponses des identifiants, clés, jetons, sessions ou autres données sensibles.

## Sous-agents

- L'agent principal reste responsable du plan, des décisions finales, de l'intégration, des conflits, des vérifications et de la synthèse.
- Utilise au moins un sous-agent dès qu'une étape peut utilement être analysée, recherchée, exécutée ou vérifiée séparément. N'en utilise pas seulement lorsque la tâche est réellement triviale ou que la délégation n'apporterait aucune valeur pratique.
- Lorsque le choix du modèle est disponible, utilise exclusivement GPT-5.6 Luna pour les sous-agents : `high` par défaut et `xhigh` pour les analyses difficiles, diagnostics ambigus, recherches de bugs ou revues critiques. N'utilise pas un autre modèle comme sous-agent.
- Délègue des tâches bornées et utiles. Évite les doublons et coordonne directement les agents lorsque leurs périmètres peuvent se chevaucher ; aucun agent ne doit écraser le travail d'un autre.

## Restitution

- Après une étape technique importante, explique brièvement ce qui fonctionne, comment et pourquoi, avec un exemple concret si utile.
- Pour un audit ou un diagnostic, sépare les faits vérifiés, les hypothèses, les causes écartées et les inconnues.
- Termine toute modification par : ce qui a changé, les vérifications effectuées, puis les limites ou risques restants.
