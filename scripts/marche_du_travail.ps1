# Extraction "Marché du travail" (OFF_1 : offres enregistrées par trimestre) pour le métier M1703.
# Canal : API France Travail "Offres et demandes d'emploi - Marché du travail" (stats-offres-demandes-emploi v1).
# Sortie : data/marche_travail_AAAA-MM-JJ.csv (une ligne par territoire x trimestre x contrat/taille) + data/raw/*.json (réponses brutes).
# Les identifiants sont lus dans .env et ne sont jamais affichés.
$racine = Split-Path $PSScriptRoot -Parent
$aujourdhui = Get-Date -Format "yyyy-MM-dd"
$codeRome = "M1703"
$territoires = @(
    @{ type = "NAT"; code = "FR" },
    @{ type = "REG"; code = "84" },
    @{ type = "DEP"; code = "63" }
)

$cfg = @{}
Get-Content (Join-Path $racine ".env") | ForEach-Object {
    $k, $v = $_ -split '=', 2
    if ($k) { $cfg[$k.Trim()] = $v.Trim() }
}
$jeton = Invoke-RestMethod -Method Post -Uri "https://entreprise.francetravail.fr/connexion/oauth2/access_token?realm=/partenaire" `
    -ContentType "application/x-www-form-urlencoded" `
    -Body @{ grant_type = "client_credentials"; client_id = $cfg["FT_CLIENT_ID"]; client_secret = $cfg["FT_CLIENT_SECRET"]; scope = "api_stats-offres-demandes-emploiv1 offresetdemandesemploi" }
$entetes = @{ Authorization = "Bearer $($jeton.access_token)"; Accept = "application/json" }
$url = "https://api.francetravail.io/partenaire/stats-offres-demandes-emploi/v1/indicateur/stat-offres"

New-Item -ItemType Directory -Force (Join-Path $racine "data\raw") | Out-Null
$lignes = @()
foreach ($t in $territoires) {
    $requete = @{
        codeTypeTerritoire   = $t.type
        codeTerritoire       = $t.code
        codeTypeActivite     = "ROME"
        codeActivite         = $codeRome
        codeTypePeriode      = "TRIMESTRE"
        codeTypeNomenclature = "ORIGINEOFF"
        listeCodeNomenclature = @("TOFF")
    }
    $reponse = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $url -Headers $entetes -ContentType "application/json" -Body ($requete | ConvertTo-Json)
    $json = [Text.Encoding]::UTF8.GetString($reponse.RawContentStream.ToArray())
    [IO.File]::WriteAllText((Join-Path $racine "data\raw\stat-offres_$($t.type)$($t.code)_$aujourdhui.json"), $json, [Text.UTF8Encoding]::new($false))
    foreach ($p in ($json | ConvertFrom-Json).listeValeursParPeriode) {
        $lignes += [pscustomobject]@{
            date_extraction = $aujourdhui
            canal           = "API France Travail - Marche du travail (OFF_1)"
            code_rome       = $p.codeActivite
            metier          = $p.libActivite
            type_territoire = $p.codeTypeTerritoire
            territoire      = $p.libTerritoire
            periode         = $p.codePeriode
            origine_offres  = $p.libNomenclature
            caracteristique = "TOTAL"
            libelle         = "Toutes offres"
            nombre          = $p.valeurPrincipaleNombre
            pourcentage     = ""
        }
        foreach ($c in $p.listeValeurParCaract | Where-Object { $_.codeTypeCaract -in @("TYPECTR", "TAILLEETAB") }) {
            $lignes += [pscustomobject]@{
                date_extraction = $aujourdhui
                canal           = "API France Travail - Marche du travail (OFF_1)"
                code_rome       = $p.codeActivite
                metier          = $p.libActivite
                type_territoire = $p.codeTypeTerritoire
                territoire      = $p.libTerritoire
                periode         = $p.codePeriode
                origine_offres  = $p.libNomenclature
                caracteristique = $c.codeTypeCaract
                libelle         = $c.libCaract
                nombre          = $c.nombre
                pourcentage     = $c.pourcentage
            }
        }
    }
}
$sortie = Join-Path $racine "data\marche_travail_$aujourdhui.csv"
$lignes | Export-Csv -Path $sortie -NoTypeInformation -Encoding UTF8 -Delimiter ";"
"$($lignes.Count) lignes enregistrees dans $sortie"
