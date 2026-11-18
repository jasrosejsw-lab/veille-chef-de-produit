# Fiche détaillée de chaque appellation (intitulé) du métier M1703 dans le ROME 4.0 :
# type d'appellation (synonyme, spécialisation…), emploi cadre, transition numérique, compétences clés avec leur fréquence.
# Canal : API France Travail ROME 4.0 (rome-metiers v1, "Lire une appellation"). Les pauses évitent l'erreur 429 (trop de requêtes).
# Entrée : data/rome_appellations_AAAA-MM-JJ.csv (produit par scripts/rome.ps1).
# Sortie : data/rome_appellations_detail_AAAA-MM-JJ.csv + data/raw/rome-appellations_AAAA-MM-JJ.json.
$racine = Split-Path $PSScriptRoot -Parent
$aujourdhui = Get-Date -Format "yyyy-MM-dd"
$cfg = @{}
Get-Content (Join-Path $racine ".env") | ForEach-Object { $k, $v = $_ -split '=', 2; if ($k) { $cfg[$k.Trim()] = $v.Trim() } }
$source = Get-ChildItem (Join-Path $racine "data\rome_appellations_2*.csv") | Sort-Object Name | Select-Object -Last 1
$appellations = @(Import-Csv $source.FullName -Delimiter ";")

function Jeton {
    (Invoke-RestMethod -Method Post -Uri "https://entreprise.francetravail.fr/connexion/oauth2/access_token?realm=/partenaire" `
        -ContentType "application/x-www-form-urlencoded" `
        -Body @{ grant_type = "client_credentials"; client_id = $cfg["FT_CLIENT_ID"]; client_secret = $cfg["FT_CLIENT_SECRET"]; scope = "api_rome-metiersv1 nomenclatureRome" }).access_token
}
$entetes = @{ Authorization = "Bearer $(Jeton)"; Accept = "application/json" }

$lignes = @(); $brut = @()
foreach ($a in $appellations) {
    $json = $null
    foreach ($essai in 1..5) {
        try {
            $r = Invoke-WebRequest -UseBasicParsing -Uri "https://api.francetravail.io/partenaire/rome-metiers/v1/metiers/appellation/$($a.code_appellation)" -Headers $entetes
            $json = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()) | ConvertFrom-Json
            break
        } catch {
            if ($_.Exception.Response.StatusCode.value__ -eq 429) { Start-Sleep -Seconds (3 * $essai) } else { Write-Warning "$($a.appellation) : HTTP $($_.Exception.Response.StatusCode.value__)"; break }
        }
    }
    if (-not $json) { Write-Warning "$($a.appellation) : non recuperee"; continue }
    $brut += $json
    $cles = @($json.competencesCles | ForEach-Object { "$($_.competence.libelle) ($($_.frequence) %)" }) -join " ; "
    $lignes += [pscustomobject]@{
        date_extraction = $aujourdhui
        canal           = "API France Travail - ROME 4.0 metiers (appellation)"
        code_appellation = $json.code
        appellation     = $json.libelle
        type_appellation = $json.classification
        emploi_cadre    = $json.emploiCadre
        transition_numerique = $json.transitionNumerique
        code_rome       = $json.metier.code
        metier          = $json.metier.libelle
        competences_cles = $cles
    }
    Start-Sleep -Milliseconds 1500
}
New-Item -ItemType Directory -Force (Join-Path $racine "data\raw") | Out-Null
[IO.File]::WriteAllText((Join-Path $racine "data\raw\rome-appellations_$aujourdhui.json"), ($brut | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
$sortie = Join-Path $racine "data\rome_appellations_detail_$aujourdhui.csv"
$lignes | Export-Csv $sortie -NoTypeInformation -Encoding UTF8 -Delimiter ";"
"$($lignes.Count) appellations sur $($appellations.Count) enregistrees dans $sortie"
