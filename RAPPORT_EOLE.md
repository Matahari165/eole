# Eole — rapport produit et ligne directrice

## 1. Résumé

Eole est une application web de respiration guidée, pensée d’abord pour l’iPhone et utilisable sur Mac. Elle reprend le protocole respiratoire cyclique popularisé par la méthode Wim Hof, sans employer ce nom dans le produit et sans suggérer d’affiliation officielle.

La promesse est simple : permettre de démarrer une séance personnalisée, la suivre les yeux fermés grâce au son, enregistrer automatiquement les rétentions et observer sa progression privée dans le temps.

## 2. Public et diffusion

- Usage personnel dans un premier temps.
- Partage ensuite avec un petit cercle de proches.
- Chaque personne possède son propre compte et ses propres données.
- L’application n’est pas référencée publiquement dans la V1 ; les utilisateurs y accèdent grâce au lien transmis.
- Les données et statistiques restent privées. Aucun classement, ami ou partage social.

Important : un lien non référencé n’est pas un véritable contrôle d’accès. Toute personne à qui le lien est transféré pourra créer un compte tant que les inscriptions sont ouvertes. Un système d’invitations pourra être ajouté plus tard si nécessaire.

## 3. Expérience d’une séance

### Configuration préalable

L’utilisateur règle :

- Le nombre de rounds : de 1 à 8.
- Le nombre de respirations par round : de 10 à 60, par pas de 5.
- La vitesse : lente, normale ou rapide.

Valeurs par défaut : **3 rounds, 35 respirations, vitesse normale**.

Il n’y a ni programme personnel enregistré, ni compte à rebours avant le départ.

### Déroulement d’un round

1. Inspiration guidée par l’expansion de l’animation et un son respiratoire.
2. Expiration guidée par la contraction de l’animation et un son respiratoire.
3. Répétition jusqu’au nombre configuré, avec affichage du compteur actuel.
4. Rétention poumons vides avec chronomètre visible.
5. L’utilisateur touche la grande zone centrale pour terminer la rétention.
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
- Sons générés d’inspiration par le nez et d’expiration.
- Trois ambiances musicales initiales : Glacier, Lagon et Aurore.
- Volume de la musique et volume respiratoire réglables séparément de 0 à 100 %.
- Mettre un volume à 0 désactive la catégorie correspondante.
- Vibrations disponibles mais désactivées par défaut.
- Animation synchronisée avec la vitesse choisie.
- Les animations non essentielles sont fortement réduites si l’appareil demande moins de mouvement.

La V1 génère ses textures sonores directement dans le navigateur. Une évolution possible consiste à faire enregistrer de vrais sons de respiration et de vraies compositions ambiantes, puis à les servir sous forme de fichiers audio optimisés.

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

- **Supabase Auth** pour les comptes e-mail et mot de passe.
- **PostgreSQL Supabase** pour les profils, réglages, séances et rounds.
- Sessions de connexion conservées dans des cookies via `@supabase/ssr`.
- Politiques RLS : toutes les lectures et écritures sont limitées au propriétaire connecté. La suppression de séance ajoute la même protection dans la migration dédiée.

### Modèle de données

| Table | Utilité |
|---|---|
| `profiles` | Prénom et pseudo de l’utilisateur |
| `user_settings` | Ambiance, volumes et vibrations |
| `sessions` | Configuration et état général d’une séance |
| `rounds` | Rétention et respirations de chaque round terminé |

La suppression d’un compte entraîne la suppression de ses données par cascade dans PostgreSQL. L’interface de suppression et l’export CSV ne sont toutefois pas prioritaires pour la V1.

## 7. Authentification

- Inscription avec prénom, pseudo, e-mail et mot de passe.
- Connexion par e-mail et mot de passe uniquement.
- Aucun code ni lien de confirmation à chaque inscription, conformément au choix produit.
- Réinitialisation du mot de passe par lien e-mail.

Supabase active normalement la confirmation d’e-mail sur ses projets hébergés. Il faut la désactiver manuellement. Cela rend l’inscription plus directe mais permet aussi de créer un compte avec une adresse qui n’appartient pas réellement à la personne. Pour une diffusion plus large, il faudra réévaluer ce compromis et ajouter au minimum une protection anti-robot.

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
- Compte ou session de connexion absent.
- Connexion Internet interrompue.
- Sauvegarde serveur échouée après une séance.
- Aucune séance enregistrée.
- Son bloqué avant le premier geste utilisateur.
- Wake Lock indisponible.
- Pseudo déjà utilisé.
- E-mail de réinitialisation non envoyé.

Une sauvegarde échouée ne doit jamais être présentée comme réussie.

## 11. Périmètre de la V1

Inclus :

- Authentification complète.
- Profils privés.
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
- Export CSV et suppression autonome du compte.
- Mode sombre.
- Pause pendant une séance.

## 12. État de mise en service

État vérifié le 8 août 2026 :

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
- Suppression individuelle d’une séance implémentée dans l’interface et le dépôt local ; la migration `20260808100000_allow_session_deletion.sql` doit être appliquée à Supabase avant la mise en production de cette fonction.

Passe UX mobile du 8 août 2026 :

- Parcours rejoués en portrait et paysage sur des formats iPhone, puis sur Mac.
- Navigation basse, marges de sécurité de l’iPhone et zones tactiles d’au moins 44 px.
- Geste de retour et fermeture protégés pendant une séance, avec confirmation avant l’arrêt.
- États distincts pour la préparation du son, l’enregistrement, l’échec, l’arrêt et la fin normale.
- Résultats conservés à l’écran si la sauvegarde échoue, avec un bouton pour réessayer.
- Statistiques sans faux zéros les jours sans séance et écran vide centré sur la prochaine action utile.
- Messages de connexion traduits en français sans exposer les erreurs techniques du serveur.
- Sons respiratoires préparés à l’avance pour éviter les saccades pendant l’animation.
- Contrastes, libellés des graphiques, navigation active et réduction des animations améliorés pour l’accessibilité.

Avant le partage à des amis :

1. Configurer un serveur SMTP personnalisé. Le serveur d’essai Supabase refuse les destinataires qui ne font pas partie de l’équipe du projet.
2. Tester le son, le verrouillage de l’écran et la veille avec un iPhone physique, une fois avec écouteurs et une fois avec le haut-parleur.
3. Faire un dernier essai de récupération de mot de passe avec une véritable boîte e-mail.

## 13. Définition de terminé

Eole V1 est réellement terminée lorsque :

- un nouvel utilisateur peut créer son compte sans confirmer son e-mail ;
- il peut se reconnecter et réinitialiser son mot de passe ;
- une séance complète suit exactement les phases prévues ;
- les sons restent synchronisés avec l’animation pour les trois vitesses ;
- arrêter une séance conserve uniquement les rounds terminés ;
- les résultats persistent après fermeture et reconnexion ;
- deux utilisateurs ne peuvent jamais accéder aux données l’un de l’autre ;
- les statistiques sont justes sur 7 et 30 jours ;
- l’interface est utilisable à 320, 375, 768, 1024 et 1440 pixels ;
- l’application a été testée dans Safari sur un iPhone réel et sur Mac ;
- les erreurs de réseau et de sauvegarde sont visibles et compréhensibles.
