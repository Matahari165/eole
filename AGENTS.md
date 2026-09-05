# Règles du projet Eole

## Produit et invariants

- Eole est une application personnelle native centrée sur la respiration, conçue uniquement pour iPhone `390 × 844` et iOS 26.
- Utilise les API Liquid Glass natives sans fallback iOS 17–25 ; réserve le verre aux contrôles et à la navigation plutôt qu'aux surfaces de contenu.
- Conserve les séances dans SwiftData et garde la synchronisation cloud désactivée tant qu'un parcours d'authentification natif n'est pas explicitement validé.
- Préserve les données existantes, les migrations prudentes et les changements hors périmètre.

## Autonomie, délégation et coordination

- L'agent principal reste responsable du périmètre, des décisions finales, de la cohérence, de la vérification et de la synthèse.
- Pour chaque tâche non triviale, évalue les sous-tâches qui bénéficient réellement d'une analyse, recherche, implémentation ou vérification séparée. Si une délégation apporte une valeur claire, utilise au moins un sous-agent **GPT-5.6 Luna `high`**.
- Utilise **Luna `xhigh`** pour une difficulté élevée, un diagnostic ambigu, une revue critique ou une vérification indépendante. Utilise deux, trois ou quatre sous-agents lorsque plusieurs lots sont réellement indépendants et que cela accélère le travail ou améliore la preuve.
- Ne délègue pas une tâche triviale, strictement séquentielle ou trop petite pour justifier le coût de coordination. Ne crée pas de doublons.
- Chaque sous-agent reçoit une mission bornée, son périmètre de fichiers, les invariants à respecter et la preuve attendue. Il ne modifie pas silencieusement le travail d'un autre agent.
- Les agents coordonnent eux-mêmes les dépendances, l'ordre des travaux, les fichiers réservés, les conflits et la reprise après blocage. Ils ne demandent pas à l'utilisateur d'organiser leur travail.

## Git et sauvegardes

- Avant toute modification, inspecte la branche, l'état Git et les changements existants. Préserve tout changement hors périmètre.
- Les agents gèrent eux-mêmes les sauvegardes récupérables, les commits locaux cohérents et l'intégration des lots vérifiés. Un commit peut servir de point de reprise avant une opération risquée.
- Utilise une branche ou un worktree séparé lorsque des tâches parallèles peuvent se chevaucher. Ne réinitialise pas, n'écrase pas et ne supprime pas le travail existant.
- Relis le diff final et vérifie que la documentation d'état reflète l'état réel lorsqu'elle est concernée.
- Push, publication, déploiement, dépense, contact d'un tiers et modification d'un service externe exigent une autorisation explicite.

## Interface et microcopy

- Construis une direction visuelle propre à Eole : typographie, palette, densité, formes, icônes et mouvement doivent servir la respiration. Évite l'AI slop : gradients gratuits, cartes identiques, gros titres décoratifs, interfaces copiées ou styles mélangés sans raison.
- Avant une création ou refonte importante, choisis une direction claire et vérifie-la avec des références pertinentes. Ne remplace pas l'identité d'Eole par un thème générique.
- Purge les textes visibles inutiles : sous-titres redondants, phrases évidentes, labels répétés, aide décorative et confirmations bavardes. Garde uniquement ce qui aide à comprendre, décider, agir, attendre, corriger une erreur ou utiliser l'accessibilité.
- Vérifie contraste, Dynamic Type, VoiceOver, libellés, focus et zones tactiles. Utilise le navigateur intégré pour toute modification visuelle ou interactive significative ; une petite correction évidente peut recevoir une vérification proportionnée.

## Développement et définition de terminé

- Utilise la solution la plus simple, les API Apple existantes et les dépendances justifiées.
- Après une modification, vérifie les cas pertinents : normal, chargement, vide, erreur, interruption, arrière-plan, reprise et migration de données.
- Distingue toujours compilation, tests, simulateur, appareil réel et preuve de séance physique. Une compilation réussie ne prouve pas un parcours réel.
- Une tâche n'est terminée qu'après implémentation, inspection du résultat, correction des échecs liés à la tâche, vérifications adaptées, relecture du diff et rapport des limites restantes.
- Une demande d'audit, de conseil ou de lecture seule n'autorise aucune modification.

## Communication

- Réponds en français, simplement et directement. Commence par la conclusion utile.
- Avant une modification, donne un plan court, les hypothèses importantes et les critères de réussite.
- Si une ambiguïté peut changer significativement le résultat, pose une seule question et attends la réponse avant de coder.
- Pour un audit ou un diagnostic, sépare faits vérifiés, hypothèses, causes écartées et inconnues.
