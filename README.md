# Chef de produit : veille sur le marché du métier

Séminaires métiers, M2 Marketing Opérationnel & Digital, IAE Clermont Auvergne (2026-2027).
Un site statique qui compte le métier de **chef de produit** (code ROME **M1703**) à partir de données publiques : offres, embauches, salaires, compétences, annonces, entreprises.

**Site en ligne :** https://jasrosejsw-lab.github.io/veille-chef-de-produit/ (GitHub Pages)
**En local :** ouvrir `index.html` dans un navigateur (ou lancer `scripts/serveur_local.ps1`, puis http://localhost:8080).

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
| Méthode | Sources, scripts, données, RGPD et limites |

Chaque chiffre du site est présenté avec sa requête, sa date, son canal et ses limites.

## Organisation du dépôt

- `*.html`, `style.css`, `commun.js`, `carte.js` : le site.
- `donnees.js`, `annonces_liste.js` : données lues par les pages, générées par `scripts/build_site.ps1`.
- `carte_regions.js`, `carte_departements.js` : contours simplifiés (source : france-geojson, données Etalab / IGN).
- `data/` : extractions datées en CSV, et réponses brutes des API dans `data/raw/`.
- `scripts/` : scripts PowerShell d'extraction et de génération.

## Relancer les extractions

Les identifiants des API se placent dans un fichier `.env` (jamais versionné) :

```
FT_CLIENT_ID=...
FT_CLIENT_SECRET=...
ADZUNA_APP_ID=...
ADZUNA_APP_KEY=...
```

| Script | Produit |
|---|---|
| `scripts/test_connexion.ps1` | Teste la connexion à l'API France Travail |
| `scripts/marche_du_travail.ps1` | Offres par trimestre |
| `scripts/indicateurs_marche.ps1` | Tension, embauches, salaires |
| `scripts/rome.ps1` | Appellations et compétences ROME 4.0 |
| `scripts/adzuna.ps1` | Annonces (quota de la clé gratuite : ne pas relancer inutilement) |
| `scripts/adzuna_compteurs.ps1` | Relevé léger du nombre d'annonces, à répéter à quelques jours d'écart |
| `scripts/entreprises63.ps1` | Entreprises du Puy-de-Dôme |
| `scripts/build_site.ps1` | Régénère `donnees.js` et `annonces_liste.js` |

## Données personnelles et sources

- Aucune donnée personnelle n'est collectée : pas de nom de dirigeant ni de contact nominatif.
- Le texte intégral des annonces Adzuna (contenu de tiers) n'est pas publié dans le dépôt ; seuls le titre, l'entreprise, le lieu, le contrat, le salaire affiché, la date et le lien sont repris, avec la mention « Annonces fournies par Adzuna ».
- Sources : API France Travail (Marché du travail, ROME 4.0), API Adzuna, API Recherche d'entreprises (Sirene), Apec (article du 03/09/2026).
