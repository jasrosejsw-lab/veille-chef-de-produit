# Ajoute la colonne "departement" à un CSV d'extraction Adzuna déjà produit, sans nouvel appel à l'API :
# le département se lit dans la hiérarchie de lieu des réponses brutes (location.area : France > région > département > ville).
# Usage : scripts\completer_departement.ps1 [-Date 2026-11-01]
param([string]$Date = (Get-Date -Format "yyyy-MM-dd"))
$racine = Split-Path $PSScriptRoot -Parent
$csv = Join-Path $racine "data\local\adzuna_offres_$Date.csv"      # copie complète, hors dépôt
$brut = Join-Path $racine "data\local\raw\adzuna_$Date.json"
if (-not (Test-Path $csv) -or -not (Test-Path $brut)) { "Fichiers introuvables pour la date $Date."; return }

$departements = @{}
foreach ($o in (Get-Content $brut -Raw -Encoding UTF8 | ConvertFrom-Json)) {
    $departements["$($o.id)"] = if ($o.location.area.Count -ge 3) { $o.location.area[2] } else { "" }
}
$lignes = @(Import-Csv $csv -Delimiter ";")
if ($lignes.Count -gt 0 -and $lignes[0].PSObject.Properties.Name -contains "departement") { "La colonne departement existe deja."; return }
$resultat = foreach ($l in $lignes) {
    $copie = [ordered]@{}
    foreach ($p in $l.PSObject.Properties) {
        $copie[$p.Name] = $p.Value
        if ($p.Name -eq "region") { $copie["departement"] = $departements["$($l.id)"] }
    }
    [pscustomobject]$copie
}
$resultat | Export-Csv $csv -NoTypeInformation -Encoding UTF8 -Delimiter ";"
"$(@($resultat).Count) lignes, dont $(@($resultat | Where-Object { $_.departement }).Count) avec un departement, ecrites dans $csv"
