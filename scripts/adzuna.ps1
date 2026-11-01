# Extraction des offres "chef de produit" via l'API Adzuna (agrégateur d'annonces, France).
# Sortie : data/adzuna_offres_AAAA-MM-JJ.csv (une ligne par offre) + data/raw/adzuna_AAAA-MM-JJ.json (réponses brutes).
# Les clés sont lues dans .env (ADZUNA_APP_ID, ADZUNA_APP_KEY) et ne sont jamais affichées.
# Usage : scripts\adzuna.ps1 [-Requete "chef de produit"] [-PagesMax 40]
param([string]$Requete = "chef de produit", [int]$PagesMax = 40, [switch]$Remplacer)
$racine = Split-Path $PSScriptRoot -Parent
$aujourdhui = Get-Date -Format "yyyy-MM-dd"
# La clé gratuite a un quota d'appels limité (une extraction complète en demande une trentaine) :
# on ne relance pas si l'extraction du jour existe déjà, sauf avec -Remplacer.
$sortie = Join-Path $racine "data\adzuna_offres_$aujourdhui.csv"
if ((Test-Path $sortie) -and -not $Remplacer) {
    "L'extraction du $aujourdhui existe deja ($sortie). Relancez avec -Remplacer pour la refaire."
    return
}
$cfg = @{}
Get-Content (Join-Path $racine ".env") | ForEach-Object {
    $k, $v = $_ -split '=', 2
    if ($k) { $cfg[$k.Trim()] = $v.Trim() }
}
function Jour($d) { if ($null -eq $d) { "" } else { ([datetime]$d).ToString("yyyy-MM-dd") } }

$offres = @()
$brut = @()
for ($page = 1; $page -le $PagesMax; $page++) {
    $url = "https://api.adzuna.com/v1/api/jobs/fr/search/${page}?app_id=$($cfg['ADZUNA_APP_ID'])&app_key=$($cfg['ADZUNA_APP_KEY'])" +
        "&what_phrase=$([uri]::EscapeDataString($Requete))&results_per_page=50&sort_by=date&content-type=application/json"
    try {
        $rep = Invoke-WebRequest -UseBasicParsing -Uri $url -Headers @{ Accept = "application/json" }
    } catch {
        Write-Warning "Page $page : arret (HTTP $($_.Exception.Response.StatusCode.value__))"
        break
    }
    $json = [Text.Encoding]::UTF8.GetString($rep.RawContentStream.ToArray())
    $donnees = $json | ConvertFrom-Json
    if (-not $donnees.results -or $donnees.results.Count -eq 0) { break }
    $total = $donnees.count
    $brut += $donnees.results
    foreach ($o in $donnees.results) {
        $offres += [pscustomobject]@{
            date_extraction  = $aujourdhui
            canal            = "API Adzuna (agregateur)"
            requete          = "what_phrase=$Requete ; pays=fr ; tri=date"
            id               = $o.id
            titre            = $o.title
            entreprise       = $o.company.display_name
            lieu             = $o.location.display_name
            region           = if ($o.location.area.Count -ge 2) { $o.location.area[1] } else { "" }
            departement      = if ($o.location.area.Count -ge 3) { $o.location.area[2] } else { "" }
            contrat_type     = $o.contract_type
            contrat_duree    = $o.contract_time
            salaire_min      = $o.salary_min
            salaire_max      = $o.salary_max
            salaire_estime   = $o.salary_is_predicted
            date_publication = Jour $o.created
            categorie        = $o.category.label
            url              = (($o.redirect_url -replace 'utm_source=[^&]*&?', '') -replace '[?&]+$', '')   # retire l'identifiant d'application des liens
            description      = ($o.description -replace '\s+', ' ')
        }
    }
    if ($offres.Count -ge $total) { break }
    Start-Sleep -Milliseconds 1200
}
if ($offres.Count -eq 0) { "Aucune offre recuperee : fichier non ecrit."; return }
# Copie complète (extraits de texte des annonces, réponses brutes) : gardée en local, ignorée par git (data/local/).
$local = Join-Path $racine "data\local"
New-Item -ItemType Directory -Force (Join-Path $local "raw") | Out-Null
[IO.File]::WriteAllText((Join-Path $local "raw\adzuna_$aujourdhui.json"), ($brut | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
$offres | Export-Csv (Join-Path $local "adzuna_offres_$aujourdhui.csv") -NoTypeInformation -Encoding UTF8 -Delimiter ";"
# Version publiée dans le dépôt : sans le texte des annonces (contenu de tiers), avec un indicateur d'alternance.
$publique = foreach ($o in $offres) {
    $alt = [int](($o.titre + " " + $o.description) -match '(?i)alternance|apprenti|contrat de professionnalisation|contrat pro\b')
    $o | Select-Object -Property * -ExcludeProperty description | Add-Member -NotePropertyName alternance -NotePropertyValue $alt -PassThru
}
$publique | Export-Csv $sortie -NoTypeInformation -Encoding UTF8 -Delimiter ";"
"$($offres.Count) offres recuperees sur $total annoncees par l'API, enregistrees dans $sortie (copie complete dans data/local/)"
