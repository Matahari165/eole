# Eole — rapport produit et ligne directrice

## 1. Résumé

Eole est une application web de respiration guidée, pensée d’abord pour l’iPhone et utilisable sur Mac. Elle reprend le protocole respiratoire cyclique popularisé par la méthode Wim Hof, sans employer ce nom dans le produit et sans suggérer d’affiliation officielle.

La promesse est simple : permettre de démarrer une séance personnalisée, la suivre les yeux fermés grâce au son, enregistrer automatiquement les rétentions et observer sa progression dans le temps.

## 2. Public et diffusion

- Usage personnel dans un premier temps.
- Espace personnel unique, sans compte ni mot de passe.
- L’application n’est pas référencée publiquement dans la V1 ; les utilisateurs y accèdent grâce au lien transmis.
- Aucun classement, ami ou partage social.

Important : un lien non référencé n’est pas un véritable contrôle d’accès. Toute personne qui possède l’adresse peut consulter, ajouter ou supprimer les données de cet espace unique.

## 3. Expérience d’une séance

### Configuration préalable

L’utilisateur règle :

- Le nombre de rounds : de 1 à 8.
- Le nombre de respirations par round : de 10 à 60, par pas de 5.
- La vitesse : lente, normale ou rapide.

Valeurs par défaut : **3 rounds, 35 respirations, vitesse normale**.

Il n’y a ni programme personnel enregistré. Après validation des réglages, la
séance démarre directement avec un compte à rebours sonore de trois secondes ;
aucune page intermédiaire ne demande de confirmer le départ.

### Déroulement d’un round

1. Inspiration guidée par l’expansion de l’animation et un son respiratoire.
2. Expiration guidée par la contraction de l’animation et un son respiratoire.
3. Répétition jusqu’au nombre configuré, avec affichage du compteur actuel.
4. Après la dernière expiration, rétention poumons vides avec chronomètre visible
   et sans limite automatique.
5. L’utilisateur double-tape n’importe où sur l’écran pour arrêter sa rétention.
6. Grande inspiration de récupération.
7. Maintien fixe de 15 secondes.
8. Expiration, puis passage au round suivant.

L’écran reste allumé durant la séance lorsque le navigateur autorise cette fonction.

### Arrêt

- Une séance ne peut pas être mise en pause.
- L’arrêt demande une confirmation.
- Seuls les rounds entièrement terminés sont enregistrés.
- Une séance arrêtée avec zéro round terminé n’est pas enregistrée.

## 4. Son et mouvement

- Aucun guidage vocal.
- Sons humains d’inspiration par le nez et d’expiration, issus d'une source CC0
  documentée dans `public/audio/SOURCES.md`.
- Trois paysages sonores locaux : Pluie douce, Océan calme et Forêt paisible.
- Volume de la musique et volume respiratoire réglables séparément de 0 à 100 %.
- Mettre un volume à 0 désactive la catégorie correspondante.
- Vibrations disponibles mais désactivées par défaut.
- Animation synchronisée avec la vitesse choisie.
- Les animations non essentielles sont fortement réduites si l’appareil demande moins de mouvement.

Les sons respiratoires et les trois ambiances sont servis comme fichiers audio
locaux et joués avec Web Audio. Les niveaux sont normalisés, les transitions ont
des fondus doux et l’ambiance recule automatiquement sous les sons-guides.

Sur iOS 17 et les navigateurs qui exposent `navigator.audioSession`, Eole demande
le mode `playback` pour éviter que le mode silencieux matériel coupe le son. Les
versions plus anciennes et certains réglages système peuvent encore imposer le
mode silencieux : une application web ne peut pas garantir ce contournement sur
tous les iPhone.

## 5. Données et statistiques

### Données enregistrées

- Identité du propriétaire de la séance.
- Date et heures de début et de fin.
- Statut : terminée ou arrêtée.
- Configuration : rounds prévus, respirations et vitesse.
- Pour chaque round terminé : position, respirations effectuées et durée de rétention.

Aucun ressenti, commentaire personnel ou donnée sociale n’est demandé.

### Indicateurs

- Nombre total de sessions.
- Nombre total et nombre moyen de rounds.
- Meilleure rétention.
- Rétention moyenne de tous les rounds.
- Temps total de pratique.
- Série de jours consécutifs.
- Rétention moyenne par jour sur 7 ou 30 jours.
- Nombre de sessions par jour.
- Historique récent et résultat de chaque round.
- Suppression individuelle d’une séance depuis l’historique, avec confirmation et retrait des statistiques.

Les séries quotidiennes et records servent de repères motivants. Le ton reste calme et ne pénalise jamais une interruption de série.

## 6. Architecture technique

### Interface

- **Next.js 16 et React 19** : application web responsive, rendue côté serveur quand cela apporte de la sécurité ou de la rapidité.
- Conception mobile-first adaptée aux zones sûres de l’iPhone.
- Navigation basse sur mobile et barre latérale sur Mac.
- Manifest web pour l’ajout à l’écran d’accueil depuis Safari.
- Recharts pour les graphiques accessibles et responsifs.
- Web Audio API pour les sons respiratoires et ambiances de la V1.
- Wake Lock API pour éviter la veille de l’écran pendant une séance, si le navigateur l’autorise.

### Serveur

- **Neon Postgres** pour le profil personnel, les réglages, les séances et les rounds.
- Une route serveur Vercel utilise `DATABASE_URL`; le mot de passe Neon n’est jamais envoyé au navigateur.
- Aucun système d’authentification. L’application publique et son API partagent le même espace personnel.

### Modèle de données

| Table | Utilité |
|---|---|
| `profiles` | Prénom et pseudo de l’espace personnel |
| `user_settings` | Ambiance, volumes et vibrations |
| `sessions` | Configuration et état général d’une séance |
| `rounds` | Rétention et respirations de chaque round terminé |

La suppression individuelle d’une séance entraîne la suppression de ses rounds par cascade dans PostgreSQL. L’export CSV n’est pas prioritaire pour la V1.

## 7. Accès

- Aucun compte, mot de passe ou code de confirmation.
- Accès direct à l’application avec son adresse publique.
- La simplicité est volontaire pour cet usage personnel ; l’adresse ne constitue pas une protection.

## 8. Identité visuelle

### Valeurs

- Détente.
- Pureté.
- Clarté.
- Vie.

### Direction V1

- Univers eau et glace, lumineux plutôt que froid.
- Bleu nuit pour le texte et les phases de rétention.
- Cyan et turquoise pour le mouvement et la respiration.
- Surfaces blanches légèrement translucides.
- Typographie expressive et calme pour les grands titres, sobre pour les données.
- Profondeur douce, sans accumulation de cartes ni d’effets décoratifs.

L’écran de séance est volontairement immersif. Les écrans de réglages et de statistiques privilégient la lisibilité.

## 9. Sécurité d’usage

Le choix actuel est de ne pas afficher d’avertissement avant les séances. Ce point constitue un risque produit à conserver explicitement dans les décisions : la respiration rapide suivie d’une apnée peut provoquer des vertiges ou une perte de connaissance.

Avant une diffusion plus large, la recommandation est d’ajouter une notice unique et non intrusive à la première utilisation : pratiquer assis ou allongé, jamais dans l’eau, au volant ou dans une situation où un malaise pourrait être dangereux. Cette notice ne doit pas être répétée avant chaque séance.

Eole ne doit présenter aucun résultat comme un conseil médical ou une preuve d’amélioration de la santé.

## 10. États et erreurs à traiter

- Chargement des données.
- Connexion Internet interrompue.
- Sauvegarde serveur échouée après une séance.
- Aucune séance enregistrée.
- Son bloqué avant le premier geste utilisateur.
- Wake Lock indisponible.

Une sauvegarde échouée ne doit jamais être présentée comme réussie.

## 11. Périmètre de la V1

Inclus :

- Espace personnel unique sans authentification.
- Configuration d’une séance.
- Moteur respiratoire et récupération de 15 secondes.
- Sons, musiques, volumes et vibrations facultatives.
- Enregistrement des rounds terminés.
- Tableau de bord, graphiques semaine/mois, records et séries.
- Mise en page iPhone et Mac.

Hors périmètre initial :

- App Store et application native.
- Fonctionnement hors connexion.
- Programmes personnalisés enregistrés.
- Partage social ou classement.
- Notes de ressenti.
- Export CSV.
- Mode sombre.
- Pause pendant une séance.

## 12. État de mise en service

État historique vérifié le 8 août 2026, avant migration :

- Projet Supabase créé et migration SQL appliquée.
- Confirmation obligatoire des e-mails désactivée.
- Politiques RLS vérifiées avec deux comptes distincts : aucune lecture ni écriture croisée n’est possible.
- Audit Supabase Security Advisor : 0 erreur et 0 avertissement après restriction des fonctions internes.
- Journaux Vercel contrôlés après le parcours public : réponses `200`/`304`, sans erreur applicative observée.
- Protections HTTP ajoutées : politique de contenu, blocage des iframes, limitation des permissions et détection stricte des types de fichiers.
- Projet GitHub relié à Vercel avec déploiement automatique de `main`.
- Fonctions Vercel exécutées à Dublin (`dub1`), dans la même zone européenne que Supabase.
- Application publique : [eole-sandy.vercel.app](https://eole-sandy.vercel.app).
- URL principale et retour `/auth/callback` de production autorisés dans Supabase.
- Inscription immédiate, connexion, séance complète, sauvegarde, reconnexion, statistiques et réglages vérifiés sur le site public.
- Comptes et séances de validation supprimés après les tests.
- Suppression individuelle d’une séance implémentée dans l’interface, le dépôt et Supabase ; la migration `20260808100000_allow_session_deletion.sql` est appliquée et la politique RLS a été vérifiée.

Migration Neon du 12 août 2026 :

- Nouveau projet Neon `Eole` créé à Francfort sur l’offre gratuite.
- La première version avec Neon Auth et Data API a été validée puis simplifiée à la demande du propriétaire.
- Schéma applicatif recréé dans `neon/migrations/20260812130000_initial_eole_schema.sql`.
- La migration additive `neon/migrations/20260812140000_personal_cloud_storage.sql` crée l’espace personnel unique sans supprimer l’ancien schéma lié à Neon Auth.
- Le code utilise `@neondatabase/serverless` uniquement côté serveur ; les dépendances Neon Auth, Neon Data API et Supabase actives ont été retirées.
- L’ancien projet Supabase est inaccessible au compte actuel et déclaré `Unhealthy` ; aucun ancien compte, mot de passe ou historique de séance n’a pu être repris.
- `DATABASE_URL` et `NEXT_PUBLIC_EOLE_CLOUD_ENABLED` sont configurées dans Vercel pour Production et Preview ; les deux anciennes variables Supabase ont été supprimées.
- Le déploiement Vercel `dpl_A6uuMTKvhFPfGSnZ9tLpPT8ba85c` est `READY` et sert `eole-sandy.vercel.app`.
- Une séance publique d’un round et 26 secondes a été enregistrée, relue dans les statistiques puis supprimée ; les tables de séances et rounds sont revenues à zéro donnée de test.
- Aucun groupe d’erreurs Vercel n’a été observé sur `/api/data` après ce parcours.

Passe UX mobile du 8 août 2026 :

- Parcours rejoués en portrait et paysage sur des formats iPhone, puis sur Mac.
- Navigation basse, marges de sécurité de l’iPhone et zones tactiles d’au moins 44 px.
- Geste de retour et fermeture protégés pendant une séance, avec confirmation avant l’arrêt.
- États distincts pour la préparation du son, l’enregistrement, l’échec, l’arrêt et la fin normale.
- Démarrage direct après les réglages avec compte à rebours sonore de 3 secondes.
- Rétention lancée automatiquement après toutes les respirations, sans durée
  maximale ; un double-tap pendant la rétention arrête le chronomètre.
- Visuels de séance enrichis : changement de phase instantané, contraste plus
  sombre à l’expiration/rétention et halos animés réduits avec `prefers-reduced-motion`.
- Sons humains CC0 intégrés et demande de session audio `playback` sur les iPhone
  compatibles.
- Résultats conservés à l’écran si la sauvegarde échoue, avec un bouton pour réessayer.
- Bouton « Lancer » placé immédiatement sous le titre sur iPhone, avec les réglages détaillés accessibles plus bas et une action persistante pendant le défilement.
- Statistiques sans faux zéros les jours sans séance et écran vide centré sur la prochaine action utile.
- Sons respiratoires préparés à l’avance pour éviter les saccades pendant l’animation.
- Contrastes, libellés des graphiques, navigation active et réduction des animations améliorés pour l’accessibilité.

Avant le partage à des amis :

1. Décider si l’accès public sans mot de passe reste acceptable, car toutes les données utilisent le même espace.
2. Tester le son, le verrouillage de l’écran et la veille avec un iPhone physique,
   une fois avec écouteurs et une fois avec le haut-parleur, notamment avec le
   bouton silencieux activé et sur une version iOS antérieure à 17.

## 13. Définition de terminé

Eole V1 est réellement terminée lorsque :

- l’application s’ouvre directement sans compte ;
- une séance complète suit exactement les phases prévues ;
- les sons restent synchronisés avec l’animation pour les trois vitesses ;
- arrêter une séance conserve uniquement les rounds terminés ;
- les résultats persistent après fermeture puis réouverture ;
- les statistiques sont justes sur 7 et 30 jours ;
- l’interface est utilisable à 320, 375, 768, 1024 et 1440 pixels ;
- l’application a été testée dans Safari sur un iPhone réel et sur Mac ;
- les erreurs de réseau et de sauvegarde sont visibles et compréhensibles.
