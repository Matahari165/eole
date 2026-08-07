# Eole

Eole est une application web mobile de respiration guidée. Elle accompagne les respirations, chronomètre chaque rétention, guide la récupération de 15 secondes et conserve les résultats de chaque utilisateur sur Supabase.

## Lancer l’aperçu

```bash
npm install
npm run dev
```

Ouvrir ensuite `http://localhost:3000`. Sans configuration Supabase, Eole fonctionne en mode aperçu avec des données de démonstration clairement signalées.

## Activer les comptes et la sauvegarde serveur

1. Créer un projet Supabase.
2. Exécuter le fichier `supabase/migrations/20260807220000_initial_eole_schema.sql` dans l’éditeur SQL Supabase.
3. Copier `.env.example` vers `.env.local` et remplacer les deux valeurs Supabase.
4. Dans Supabase, ouvrir **Authentication → Providers → Email** et désactiver **Confirm email** pour respecter le choix d’une inscription immédiate.
5. Dans **Authentication → URL Configuration**, ajouter l’adresse déployée suivie de `/auth/callback` aux URL de redirection autorisées.
6. Configurer un serveur SMTP avant de partager l’application : il est nécessaire pour les e-mails de réinitialisation du mot de passe.

Les politiques RLS de la migration garantissent qu’un utilisateur ne peut lire et écrire que ses propres séances.

## Vérifier le projet

```bash
npm run verify
```

Cette commande contrôle le code, les types, les calculs statistiques et la compilation de production.

## Ajouter l’application sur iPhone

Une fois le site déployé en HTTPS : ouvrir Eole dans Safari, toucher **Partager**, puis **Sur l’écran d’accueil**. Eole s’ouvre alors comme une application web indépendante, sans App Store.

La ligne directrice complète se trouve dans `RAPPORT_EOLE.md`.
