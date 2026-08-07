# Eole

Eole est une application web mobile de respiration guidée. Elle accompagne les respirations, chronomètre chaque rétention, guide la récupération de 15 secondes et conserve les résultats de chaque utilisateur sur Supabase.

Application en production : [eole-sandy.vercel.app](https://eole-sandy.vercel.app)

## État de production

- Le dépôt GitHub est relié à Vercel et chaque mise à jour de `main` est redéployée automatiquement.
- Supabase Auth, les profils, les réglages, les séances, les rounds et les politiques d’isolation sont actifs.
- Le domaine Vercel et son retour `/auth/callback` sont autorisés dans Supabase.
- L’inscription, la connexion, une séance complète, les statistiques, les réglages et l’isolation entre deux comptes ont été vérifiés sur le site public.
- Un serveur SMTP personnalisé reste nécessaire avant de dépendre du mot de passe oublié pour des utilisateurs extérieurs à l’équipe Supabase.

## Lancer l’aperçu

```bash
npm install
npm run dev
```

Ouvrir ensuite `http://localhost:3000`. Sans configuration Supabase, Eole fonctionne en mode aperçu avec des données de démonstration clairement signalées.

## Reproduire la configuration serveur

1. Créer un projet Supabase.
2. Exécuter le fichier `supabase/migrations/20260807220000_initial_eole_schema.sql` dans l’éditeur SQL Supabase.
3. Copier `.env.example` vers `.env.local` et remplacer les deux valeurs Supabase.
4. Dans Supabase, ouvrir **Authentication → Providers → Email** et désactiver **Confirm email** pour respecter le choix d’une inscription immédiate.
5. Dans **Authentication → URL Configuration**, ajouter l’adresse déployée suivie de `/auth/callback` aux URL de redirection autorisées.
6. Configurer un serveur SMTP avant de partager l’application : le serveur d’essai Supabase n’envoie pas les e-mails aux personnes extérieures à l’équipe du projet.

Les politiques RLS de la migration garantissent qu’un utilisateur ne peut lire et écrire que ses propres séances.

## Vérifier le projet

```bash
npm run verify
```

Cette commande contrôle le code, les types, les calculs statistiques et la compilation de production.

## Ajouter l’application sur iPhone

Une fois le site déployé en HTTPS : ouvrir Eole dans Safari, toucher **Partager**, puis **Sur l’écran d’accueil**. Eole s’ouvre alors comme une application web indépendante, sans App Store.

La ligne directrice complète se trouve dans `RAPPORT_EOLE.md`.
