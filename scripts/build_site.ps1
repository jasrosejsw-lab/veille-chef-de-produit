# Prépare les données du site : lit les derniers CSV de data/ et écrit donnees.js (chargé par les pages, sans serveur).
# À relancer après chaque nouvelle extraction.
$racine = Split-Path $PSScriptRoot -Parent
function Dernier($motif) { Get-ChildItem (Join-Path $racine "data\$motif") | Sort-Object Name | Select-Object -Last 1 }
function Nombre($s) { if ($s -eq "" -or $null -eq $s) { $null } else { [double]::Parse(($s -replace ',', '.'), [Globalization.CultureInfo]::InvariantCulture) } }

$fMarche = Dernier "marche_travail_*.csv"
$fInd = Dernier "indicateurs_*.csv"
$fApp = Dernier "rome_appellations_*.csv"
$fComp = Dernier "rome_competences_*.csv"

$marche = Import-Csv $fMarche.FullName -Delimiter ";"
$ind = Import-Csv $fInd.FullName -Delimiter ";"

$donnees = [ordered]@{
    extraction = ($fMarche.BaseName -replace '.*_', '')
    offres = @($marche | Where-Object { $_.caracteristique -eq "TOTAL" } | ForEach-Object {
            [ordered]@{ territoire = $_.territoire; periode = $_.periode; nombre = (Nombre $_.nombre) } })
    embauches = @($ind | Where-Object { $_.indicateur -eq "EMB_1" } | ForEach-Object {
            [ordered]@{ territoire = $_.territoire; periode = $_.periode; nombre = (Nombre $_.valeur_nombre) } })
    tension = @($ind | Where-Object { $_.indicateur -eq "PERSP_2" } | ForEach-Object {
            [ordered]@{ territoire = $_.territoire; periode = $_.periode; niveau = (Nombre $_.valeur_nombre); score = (Nombre $_.valeur_decimale) } })
    salaires = @($ind | Where-Object { $_.indicateur -eq "SAL_3" } | ForEach-Object {
            [ordered]@{ territoire = $_.territoire; periode = $_.periode; montant = (Nombre $_.valeur_montant); famille = $_.activite } })
    appellations = @(Import-Csv $fApp.FullName -Delimiter ";" | ForEach-Object { $_.appellation })
    competences = @(Import-Csv $fComp.FullName -Delimiter ";" | ForEach-Object {
            [ordered]@{ enjeu = $_.enjeu; type = $_.type_competence; competence = $_.competence } })
}

# Annonces Adzuna : on ne garde que les offres dont le titre contient "chef/cheffe" et "produit" (la recherche remonte aussi d'autres métiers).
# On lit la copie complète (avec le texte des annonces) si elle est présente en local ; sinon la version publiée du dépôt.
$fAdz = Get-ChildItem (Join-Path $racine "data\local\adzuna_offres_*.csv") -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1
if (-not $fAdz) { $fAdz = Dernier "adzuna_offres_*.csv" }
if ($fAdz) {
    $toutes = @(Import-Csv $fAdz.FullName -Delimiter ";")
    $f = @($toutes | Where-Object { $_.titre -match '(?i)chef|cheffe' -and $_.titre -match '(?i)produit' })
    # Alternance : colonne "alternance" de la version publiée si elle existe, sinon repérage par mots dans le titre et l'extrait.
    function EstAlternance($o) {
        if ($o.PSObject.Properties.Name -contains "alternance") { return ($o.alternance -eq "1") }
        return (($o.titre + " " + $o.description) -match '(?i)alternance|apprenti|contrat de professionnalisation|contrat pro\b')
    }
    function Top($liste, $cle, $n) { @($liste | Where-Object { $_.$cle } | Group-Object $cle | Sort-Object Count -Descending | Select-Object -First $n | ForEach-Object { [ordered]@{ nom = $_.Name; nombre = $_.Count } }) }
    function Quantile($tri, $q) { $tri[[math]::Min($tri.Count - 1, [math]::Floor($q * ($tri.Count - 1) + 0.5))] }
    # Salaires : salaire minimum annuel affiché ; on écarte les valeurs hors d'une plage annuelle plausible (10 000 à 250 000).
    $brutSal = @($f | Where-Object { $_.salaire_min } | ForEach-Object { [double]($_.salaire_min -replace ',', '.') })
    $sal = @($brutSal | Where-Object { $_ -ge 10000 -and $_ -le 250000 } | Sort-Object)
    $outils = [ordered]@{ "Excel" = "excel"; "SQL" = "\bsql\b"; "Power BI" = "power ?bi"; "Python" = "python"; "Salesforce" = "salesforce"; "HubSpot" = "hubspot"; "Google Analytics / GA4" = "google analytics|\bga4\b"; "Jira" = "\bjira\b"; "SEO" = "\bseo\b"; "CRM" = "\bcrm\b"; "Agile / Scrum" = "agile|scrum"; "Anglais" = "anglais|english"; "IA" = "\bia\b|intelligence artificielle|chatgpt"; "Data / données" = "\bdata\b|donn(é|e)es"; "E-commerce" = "e-?commerce" }
    $donnees["annonces"] = [ordered]@{
        extraction = ($fAdz.BaseName -replace '.*_', '')
        total_api = $toutes.Count
        retenues = $f.Count
        regions = Top $f "region" 8
        sans_region = @($f | Where-Object { -not $_.region }).Count
        contrats = [ordered]@{
            permanent = @($f | Where-Object { $_.contrat_type -eq "permanent" }).Count
            contract = @($f | Where-Object { $_.contrat_type -eq "contract" }).Count
            non_renseigne = @($f | Where-Object { -not $_.contrat_type }).Count }
        entreprises = Top $f "entreprise" 10
        salaires = [ordered]@{
            avec_salaire = $brutSal.Count; retenus = $sal.Count; exclus = ($brutSal.Count - $sal.Count)
            q1 = (Quantile $sal 0.25); mediane = (Quantile $sal 0.5); q3 = (Quantile $sal 0.75); min = $sal[0]; max = $sal[-1] }
        outils = @($outils.Keys | ForEach-Object { $k = $_; $n = @($f | Where-Object { $_.description -match "(?i)$($outils[$k])" }).Count; [ordered]@{ outil = $k; nombre = $n } })
        annees = @($f | Group-Object { $_.date_publication.Substring(0, 4) } | Sort-Object Name | ForEach-Object { [ordered]@{ annee = $_.Name; nombre = $_.Count } })
        puy_de_dome = @($f | Where-Object { $_.lieu -match 'Puy-de-D|Clermont' }).Count
        alternance = @($f | Where-Object { EstAlternance $_ }).Count
        auvergne_rhone_alpes = @($f | Where-Object { $_.region -match '^Auvergne' }).Count
        carte = @($f | Where-Object { $_.region } | Group-Object region | ForEach-Object {
                [ordered]@{ region = $_.Name; nombre = $_.Count; entreprises = (Top $_.Group "entreprise" 5) } })
        carte_departements = @($f | Where-Object { $_.departement } | Group-Object departement | ForEach-Object {
                [ordered]@{ region = $_.Name; nombre = $_.Count; entreprises = (Top $_.Group "entreprise" 5) } })
        sans_departement = @($f | Where-Object { -not $_.departement }).Count
        puy_de_dome_departement = @($f | Where-Object { $_.departement -match '^Puy-de-D' }).Count
    }
}

# Liste des annonces pour la page "Annonces" (fichier séparé, chargé uniquement par cette page).
# Les liens sont débarrassés de l'identifiant d'application Adzuna (paramètre utm_source).
if ($fAdz) {
    $liste = @($f | Sort-Object date_publication -Descending | ForEach-Object {
            $min = if ($_.salaire_min) { [double]($_.salaire_min -replace ',', '.') } else { $null }
            $max = if ($_.salaire_max) { [double]($_.salaire_max -replace ',', '.') } else { $null }
            $plausible = ($null -ne $min) -and ($min -ge 10000) -and ($min -le 250000) -and ($_.salaire_estime -ne "1")
            [ordered]@{
                titre = $_.titre; entreprise = $_.entreprise; lieu = $_.lieu; region = $_.region; departement = $_.departement; contrat = $_.contrat_type
                alternance = [int](EstAlternance $_)
                salaire_min = $(if ($plausible) { $min } else { $null }); salaire_max = $(if ($plausible -and $max -ge $min) { $max } else { $null })
                date = $_.date_publication
                url = (($_.url -replace 'utm_source=[^&]*&?', '') -replace '[?&]+$', '')
            } })
    $jsListe = "window.LISTE_ANNONCES = " + ($liste | ConvertTo-Json -Depth 4 -Compress) + ";"
    [IO.File]::WriteAllText((Join-Path $racine "annonces_liste.js"), $jsListe, [Text.UTF8Encoding]::new($false))
    "annonces_liste.js ecrit : $($liste.Count) annonces"
}

# Répartition des offres par type de contrat, France entière (les pourcentages sont fiables ; les nombres sont arrondis à la dizaine).
$donnees["contrats_france"] = @($marche | Where-Object { $_.caracteristique -eq "TYPECTR" -and $_.type_territoire -eq "NAT" } | ForEach-Object {
        [ordered]@{ periode = $_.periode; contrat = $_.libelle; pourcentage = (Nombre $_.pourcentage); nombre = (Nombre $_.nombre) } })

# Entreprises du 63 (API Recherche d'entreprises) : on met en avant celles dont le siège est dans le département.
$fEnt = Dernier "entreprises_63_*.csv"
if ($fEnt) {
    $ent = @(Import-Csv $fEnt.FullName -Delimiter ";")
    $siege = @($ent | Where-Object { $_.siege_dans_63 -eq "1" })
    $ordre = @{ "53" = 9; "52" = 8; "51" = 7; "42" = 6; "41" = 5; "32" = 4; "31" = 3; "22" = 2; "21" = 1 }
    $donnees["entreprises63"] = [ordered]@{
        extraction = ($fEnt.BaseName -replace '.*_', '')
        total = $ent.Count
        siege_63 = $siege.Count
        sections = @($siege | Group-Object section_activite | Sort-Object Count -Descending | Select-Object -First 8 | ForEach-Object { [ordered]@{ code = $_.Name; nombre = $_.Count } })
        communes = @($siege | Group-Object siege_commune | Sort-Object Count -Descending | Select-Object -First 8 | ForEach-Object { [ordered]@{ nom = $_.Name; nombre = $_.Count } })
        grandes = @($siege | Where-Object { $ordre[$_.tranche_effectif] -ge 5 -and $_.section_activite -notin @("O", "P", "Q") -and $_.nom -notmatch 'ASSOCIATION|HOSPITAL' } | Sort-Object { -$ordre[$_.tranche_effectif] }, nom | Select-Object -First 15 | ForEach-Object { [ordered]@{ nom = $_.nom; commune = $_.siege_commune; section = $_.section_activite; tranche = $_.tranche_effectif } })
        nb_grandes = @($siege | Where-Object { $ordre[$_.tranche_effectif] -ge 5 -and $_.section_activite -notin @("O", "P", "Q") -and $_.nom -notmatch 'ASSOCIATION|HOSPITAL' }).Count
    }
}

# Liste consultable des entreprises du 63 pour la page "Acteurs" (fichier séparé, chargé uniquement par cette page). Aucune donnée personnelle.
if ($fEnt) {
    $listeEnt = @($ent | ForEach-Object {
            [ordered]@{ siren = $_.siren; nom = $_.nom; siege = $_.siege_commune; s63 = [int]$_.siege_dans_63; section = $_.section_activite; tranche = $_.tranche_effectif; communes = $_.communes_63 } })
    $jsEnt = "window.LISTE_ENTREPRISES = " + ($listeEnt | ConvertTo-Json -Depth 3 -Compress) + ";"
    [IO.File]::WriteAllText((Join-Path $racine "entreprises_liste.js"), $jsEnt, [Text.UTF8Encoding]::new($false))
    "entreprises_liste.js ecrit : $($listeEnt.Count) entreprises"
}

# Numéro de version des fichiers du site dans les pages : évite qu'un navigateur mélange d'anciens fichiers avec les nouveaux
# (GitHub Pages garde les fichiers en cache jusqu'à 10 minutes). À relancer avant chaque mise en ligne.
$version = Get-Date -Format "yyyyMMddHHmm"
$icone = '<link rel="icon" href="data:image/svg+xml,%3Csvg xmlns=''http://www.w3.org/2000/svg'' viewBox=''0 0 32 32''%3E%3Crect width=''32'' height=''32'' rx=''7'' fill=''%230b5fff''/%3E%3C/svg%3E">'
foreach ($page in Get-ChildItem (Join-Path $racine "*.html")) {
    $t = [IO.File]::ReadAllText($page.FullName, [Text.Encoding]::UTF8)
    $t = [regex]::Replace($t, '(src|href)="(style\.css|commun\.js|carte(?:_regions|_departements)?\.js|donnees\.js|annonces_liste\.js|entreprises_liste\.js)(?:\?v=\d+)?"', "`$1=`"`$2?v=$version`"")
    if ($t -notmatch 'rel="icon"') { $t = $t -replace '(<link rel="stylesheet")', "$icone`n`$1" }
    [IO.File]::WriteAllText($page.FullName, $t, [Text.UTF8Encoding]::new($false))
}

$js = "window.DONNEES = " + ($donnees | ConvertTo-Json -Depth 5 -Compress) + ";"
[IO.File]::WriteAllText((Join-Path $racine "donnees.js"), $js, [Text.UTF8Encoding]::new($false))
"donnees.js ecrit : $($donnees.offres.Count) offres, $($donnees.embauches.Count) embauches, $($donnees.tension.Count) tension, $($donnees.salaires.Count) salaires, $($donnees.appellations.Count) appellations, $($donnees.competences.Count) competences"
