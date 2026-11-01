# Chef de produit : veille sur le marché du métier

Séminaires métiers, M2 Marketing Opérationnel & Digital, IAE Clermont Auvergne (2026-2027).
Un site statique qui compte le métier de **chef de produit** (code ROME **M1703**) à partir de données publiques : offres, embauches, salaires, compétences, annonces, entreprises.

**Site en ligne :** https://jasrosejsw-lab.github.io/veille-chef-de-produit/ (GitHub Pages)
**En local :** ouvrir `index.html` dans un navigateur (ou lancer `scripts/serveur_local.ps1`, puis http://localhost:8080).

## Comment le site est fait

Ce document reprend, pour le séminaire, les éléments demandés : les canaux branchés, les scripts, la mise à jour, la règle sur les données personnelles et les limites rencontrées. La page « Méthode » du site en propose une version destinée à tout visiteur.

### Les canaux

| Canal | Ce qu'il apporte | État |
|---|---|---|
| API France Travail « Marché du travail » | Offres, embauches, tension, salaires en poste, par trimestre ou par année | Branché |
| API France Travail « ROME 4.0 » (métiers, fiches métiers) | Appellations et compétences officielles de M1703 | Branché |
| API « Recherche d'entreprises » (Sirene, data.gouv.fr) | Entreprises de 50 salariés et plus du Puy-de-Dôme : siège, secteur, effectif | Branché |
| Études de l'emploi (Apec) | Évolution du métier, impact de l'IA | Source citée |
| API Adzuna (agrégateur d'annonces) | Annonces individuelles : lieu, entreprise, contrat, salaire affiché, extrait de texte | Branché |
| API France Travail « Offres d'emploi » | Annonces détaillées (salaires affichés, compétences) | Absente du compte développeur |
| API France Travail « La Bonne Boite » | Entreprises à fort potentiel d'embauche | Activée mais erreur 403 |

Aucun scraping de LinkedIn, de l'Apec ou d'Indeed : leurs conditions d'utilisation l'interdisent.

### Les scripts et les données

Les scripts sont en PowerShell. Les identifiants des API se placent dans un fichier `.env` (jamais versionné) :

```
FT_CLIENT_ID=...
FT_CLIENT_SECRET=...
ADZUNA_APP_ID=...
ADZUNA_APP_KEY=...
```

| Script | Produit |
|---|---|
| `scripts/test_connexion.ps1` | Teste la connexion à l'API France Travail (n'affiche jamais les identifiants) |
| `scripts/marche_du_travail.ps1` | Offres par trimestre → `data/marche_travail_AAAA-MM-JJ.csv` |
| `scripts/indicateurs_marche.ps1` | Tension, embauches, salaires → `data/indicateurs_AAAA-MM-JJ.csv` |
| `scripts/rome.ps1` | Appellations et compétences → `data/rome_*.csv` |
| `scripts/adzuna.ps1` | Annonces → `data/adzuna_offres_AAAA-MM-JJ.csv` (quota de la clé gratuite : une extraction complète en consomme une trentaine) |
| `scripts/adzuna_compteurs.ps1` | Relevé léger du nombre d'annonces, daté → `data/adzuna_compteurs.csv` (5 requêtes, à répéter à quelques jours d'écart) |
| `scripts/completer_departement.ps1` | Ajoute le département de chaque annonce, sans nouvelle requête |
| `scripts/entreprises63.ps1` | Entreprises du Puy-de-Dôme → `data/entreprises_63_AAAA-MM-JJ.csv` (aucune donnée sur les dirigeants) |
| `scripts/build_site.ps1` | Génère `donnees.js`, `annonces_liste.js`, `entreprises_liste.js` et les numéros de version des pages |

Chaque fichier de données porte la date de son extraction dans son nom : relancer un script crée un nouveau fichier daté, ce qui permet de voir le marché bouger. `data/raw/` contient les réponses brutes des API France Travail, conservées pour vérifier chaque chiffre. Les réponses brutes d'Adzuna contiennent le texte d'annonces de tiers : elles restent en local (`data/local/`, ignoré par git) et ne sont pas publiées.

### Mise à jour

Les mises à jour sont lancées à la main, sans automatisation planifiée : on exécute les scripts, puis `scripts/build_site.ps1`, et le tout est publié sur GitHub.

### Les règles

- Chaque chiffre est présenté avec sa requête, sa date, son canal et ses limites.
- Les identifiants des API sont dans `.env`, exclu du dépôt et du zip.
- **RGPD** : aucune donnée personnelle n'est collectée ni publiée (pas de nom de dirigeant, pas de contact nominatif). Un contact n'est conservé que pour une finalité claire (par exemple une candidature), en lien avec sa fonction, avec possibilité de s'opposer.
- Le texte intégral des annonces Adzuna (contenu de tiers) n'est pas publié ; le site reprend le titre, l'entreprise, le lieu, le contrat, le salaire affiché, la date et un lien, avec la mention « Annonces fournies par Adzuna ».

### Les limites rencontrées

- L'API « Offres d'emploi » n'apparaît pas dans le catalogue du compte développeur : le site passe par Adzuna, qui ne donne qu'un extrait d'environ 500 caractères par annonce. Les outils cités dans les annonces ne peuvent donc pas être comptés sérieusement.
- « La Bonne Boite » répond 403 malgré une activation et un jeton accepté : elle n'est pas utilisée.
- La clé Adzuna est en « activation en attente » : elle est limitée à un quota d'appels d'essai, d'où les relevés légers entre deux extractions complètes.
- Les statistiques sont arrondies et agrégées : elles décrivent le marché, pas des offres individuelles. Dans le Puy-de-Dôme, les volumes sont trop faibles pour être lus finement.
- L'alternance n'est pas isolable dans les sources : elle est estimée à partir de mots dans le titre ou l'extrait des annonces.

## Ce que contient le site

| Page | Contenu |
|---|---|
| Présentation | Le métier, les intitulés, les 5 questions posées au marché et la page qui répond à chacune |
| Ce qu'on retient | Synthèse en quelques points |
| Offres et marché | Offres, embauches, tension de recrutement, salaires et contrats (API France Travail « Marché du travail ») |
| Annonces | Carte des annonces par région et par département, liste filtrable avec liens pour postuler, filtre alternance (API Adzuna) |
| Compétences | Référentiel officiel ROME 4.0 |
| Évolution | Évolution du volume d'offres et effet de l'IA d'après l'Apec |
| Acteurs | Entreprises qui publient, entreprises de 50 salariés et plus du Puy-de-Dôme avec un répertoire filtrable pour les candidatures spontanées (API Recherche d'entreprises) |
| Méthode | Sources, façon de lire les chiffres, limites, données personnelles |

## Organisation du dépôt

- `*.html`, `style.css`, `commun.js`, `carte.js` : le site.
- `donnees.js`, `annonces_liste.js`, `entreprises_liste.js` : données lues par les pages, générées par `scripts/build_site.ps1`.
- `carte_regions.js`, `carte_departements.js` : contours simplifiés (source : france-geojson, données Etalab / IGN).
- `data/` : extractions datées en CSV, et réponses brutes des API France Travail dans `data/raw/`.
- `scripts/` : scripts PowerShell d'extraction et de génération.

## Sources

API France Travail (Marché du travail, ROME 4.0), API Adzuna, API Recherche d'entreprises (Sirene), Apec (article du 03/09/2026, étude de mars 2026), contours des régions et départements (france-geojson).
