# Référentiel officiel ROME 4.0 pour le métier M1703 (chef de produit) :
#   - appellations (intitulés du métier)  -> data/rome_appellations_AAAA-MM-JJ.csv
#   - compétences mobilisées par enjeu    -> data/rome_competences_AAAA-MM-JJ.csv
# Canal : API France Travail ROME 4.0 (rome-metiers v1, rome-fiches-metiers v1). Réponses brutes dans data/raw/.
# Les identifiants sont lus dans .env, jamais affichés.
$racine = Split-Path $PSScriptRoot -Parent
$aujourdhui = Get-Date -Format "yyyy-MM-dd"
$codeRome = "M1703"

$cfg = @{}
Get-Content (Join-Path $racine ".env") | ForEach-Object {
    $k, $v = $_ -split '=', 2
    if ($k) { $cfg[$k.Trim()] = $v.Trim() }
}
function Lire($url, $scope, $nomBrut) {
    $jeton = Invoke-RestMethod -Method Post -Uri "https://entreprise.francetravail.fr/connexion/oauth2/access_token?realm=/partenaire" `
        -ContentType "application/x-www-form-urlencoded" `
        -Body @{ grant_type = "client_credentials"; client_id = $cfg["FT_CLIENT_ID"]; client_secret = $cfg["FT_CLIENT_SECRET"]; scope = $scope }
    $r = Invoke-WebRequest -UseBasicParsing -Uri $url -Headers @{ Authorization = "Bearer $($jeton.access_token)"; Accept = "application/json" }
    $json = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray())
    New-Item -ItemType Directory -Force (Join-Path $racine "data\raw") | Out-Null
    [IO.File]::WriteAllText((Join-Path $racine "data\raw\$nomBrut`_$aujourdhui.json"), $json, [Text.UTF8Encoding]::new($false))
    $json | ConvertFrom-Json
}

$metier = Lire "https://api.francetravail.io/partenaire/rome-metiers/v1/metiers/metier/$codeRome" "api_rome-metiersv1 nomenclatureRome" "rome-metier_$codeRome"
$appellations = $metier.appellations | ForEach-Object {
    [pscustomobject]@{
        date_extraction = $aujourdhui
        canal           = "API France Travail - ROME 4.0 metiers"
        code_rome       = $codeRome
        code_appellation = $_.code
        appellation     = $_.libelle
        emploi_cadre    = $_.emploiCadre
    }
}
$appellations | Export-Csv (Join-Path $racine "data\rome_appellations_$aujourdhui.csv") -NoTypeInformation -Encoding UTF8 -Delimiter ";"

$fiche = Lire "https://api.francetravail.io/partenaire/rome-fiches-metiers/v1/fiches-rome/fiche-metier/$codeRome" "api_rome-fiches-metiersv1 nomenclatureRome" "rome-fiche_$codeRome"
$competences = foreach ($g in $fiche.groupesCompetencesMobilisees) {
    foreach ($c in $g.competences) {
        [pscustomobject]@{
            date_extraction  = $aujourdhui
            canal            = "API France Travail - ROME 4.0 fiches metiers"
            code_rome        = $codeRome
            enjeu            = $g.enjeu.libelle
            type_competence  = $c.type
            code_competence  = $c.code
            competence       = $c.libelle
        }
    }
}
$competences | Export-Csv (Join-Path $racine "data\rome_competences_$aujourdhui.csv") -NoTypeInformation -Encoding UTF8 -Delimiter ";"

"$(@($appellations).Count) appellations, $(@($competences).Count) competences enregistrees dans data/"
