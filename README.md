# Eole

Eole est une application web mobile personnelle de respiration guidée. Elle accompagne les respirations, chronomètre chaque rétention, guide la récupération de 15 secondes et conserve les résultats dans une base Neon permanente.

Application en production : [eole-sandy.vercel.app](https://eole-sandy.vercel.app)

## Backend

- Le projet Neon `Eole` est hébergé à Francfort sur l’offre gratuite.
- Il n’y a ni compte, ni mot de passe, ni écran de connexion.
- Le navigateur appelle uniquement l’API serveur d’Eole ; le mot de passe Neon reste secret dans Vercel.
- Les réglages, les séances et les rounds sont communs à cet espace personnel unique.
- Toute personne possédant l’adresse publique de l’application peut consulter ou modifier ces données.

## Lancer le projet

```bash
npm install
npm run dev
```

Sans configuration Neon, Eole fonctionne en mode aperçu avec des données locales clairement signalées.

Pour activer la sauvegarde permanente, copier `.env.example` vers `.env.local`, puis renseigner :

- `DATABASE_URL` avec la chaîne de connexion Neon groupée ;
- `NEXT_PUBLIC_EOLE_CLOUD_ENABLED=true`.

Pour un nouveau projet Neon, exécuter uniquement `neon/migrations/20260812140000_personal_cloud_storage.sql`. Cette migration autonome crée l’espace personnel sans Neon Auth. Le fichier `20260812130000_initial_eole_schema.sql` conserve seulement l’historique de la première migration avec authentification.

## Vérifier le projet

```bash
npm run verify
```

Cette commande contrôle le code, les types, les calculs statistiques et la compilation de production.

## Ajouter l’application sur iPhone

Ouvrir Eole dans Safari, toucher **Partager**, puis **Sur l’écran d’accueil**. Eole s’ouvre alors comme une application web indépendante, sans App Store.
