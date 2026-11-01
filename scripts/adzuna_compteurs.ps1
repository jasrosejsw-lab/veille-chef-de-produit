# Relevé léger Adzuna : ne récupère que le NOMBRE d'annonces (1 appel par requête, 5 appels au total) et l'ajoute à data/adzuna_compteurs.csv.
# À lancer à quelques jours d'intervalle pour voir le marché bouger sans épuiser le quota de la clé gratuite.
# Les clés sont lues dans .env et ne sont jamais affichées. Un seul relevé par jour (relancer le même jour ne fait rien).
$racine = Split-Path $PSScriptRoot -Parent
$aujourdhui = Get-Date -Format "yyyy-MM-dd"
$sortie = Join-Path $racine "data\adzuna_compteurs.csv"
if ((Test-Path $sortie) -and (Import-Csv $sortie -Delimiter ";" | Where-Object { $_.date_releve -eq $aujourdhui })) {
    "Le releve du $aujourdhui existe deja."
    return
}
$cfg = @{}
Get-Content (Join-Path $racine ".env") | ForEach-Object {
    $k, $v = $_ -split '=', 2
    if ($k) { $cfg[$k.Trim()] = $v.Trim() }
}
$e = { param($s) [uri]::EscapeDataString($s) }
$cp = "what_phrase=" + (& $e "chef de produit")
$requetes = @(
    @{ nom = "France - chef de produit"; params = $cp },
    @{ nom = "Clermont-Ferrand 50 km - chef de produit"; params = "$cp&where=$(& $e 'Clermont-Ferrand')&distance=50" },
    @{ nom = "France - chef de produit avec salaire affiche"; params = "$cp&salary_min=1" },
    @{ nom = "France - chef de produit, categorie marketing"; params = "$cp&category=pr-advertising-marketing-jobs" },
    @{ nom = "France - product manager"; params = "what_phrase=" + (& $e "product manager") }
)
$lignes = foreach ($r in $requetes) {
    $url = "https://api.adzuna.com/v1/api/jobs/fr/search/1?app_id=$($cfg['ADZUNA_APP_ID'])&app_key=$($cfg['ADZUNA_APP_KEY'])&results_per_page=1&content-type=application/json&$($r.params)"
    try {
        $n = (Invoke-RestMethod -Uri $url -Headers @{ Accept = "application/json" }).count
    } catch {
        Write-Warning "$($r.nom) : echec (HTTP $($_.Exception.Response.StatusCode.value__))"
        continue
    }
    [pscustomobject]@{ date_releve = $aujourdhui; canal = "API Adzuna (agregateur)"; requete = $r.nom; nombre_annonces = $n }
    Start-Sleep -Milliseconds 800
}
if (-not $lignes) { "Aucun releve : fichier non modifie."; return }
$lignes | Export-Csv $sortie -NoTypeInformation -Encoding UTF8 -Delimiter ";" -Append
$lignes | ForEach-Object { "{0,-50} {1}" -f $_.requete, $_.nombre_annonces }
