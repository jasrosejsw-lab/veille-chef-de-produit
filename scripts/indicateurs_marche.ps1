# Autres indicateurs "Marché du travail" pour le métier M1703 (chef de produit) :
#   PERSP_2 (tension de recrutement, annuel), EMB_1 (embauches, trimestriel), SAL_3 (salaires en poste de la famille professionnelle, annuel).
# Canal : API France Travail "Offres et demandes d'emploi - Marché du travail" (stats-offres-demandes-emploi v1).
# Sortie : data/indicateurs_AAAA-MM-JJ.csv + data/raw/*.json (réponses brutes). Les identifiants sont lus dans .env, jamais affichés.
$racine = Split-Path $PSScriptRoot -Parent
$aujourdhui = Get-Date -Format "yyyy-MM-dd"
$territoires = @(
    @{ type = "NAT"; code = "FR" },
    @{ type = "REG"; code = "84" },
    @{ type = "DEP"; code = "63" }
)
# SAL_3 n'existe pas par métier : on prend la famille professionnelle (FAP225) du ROME M1703, R4Z90 (référentiel rechercherActivitesRomeFap).
$indicateurs = @(
    @{ code = "PERSP_2"; endpoint = "stat-perspective-employeur"; activite = @("ROME", "M1703"); periode = "ANNEE"; nomenclature = "TYPE_TENSION"; valeurs = @("PERSPECTIVE") },
    @{ code = "EMB_1"; endpoint = "stat-embauches"; activite = @("ROME", "M1703"); periode = "TRIMESTRE"; nomenclature = "CATCANDxDUREEEMP"; valeurs = @("TOUT-TOUTE") },
    @{ code = "SAL_3"; endpoint = "stat-salaires-en-poste"; activite = @("FAP225", "R4Z90"); periode = "ANNEE"; nomenclature = "TYPESALAIRE"; valeurs = @("SAL3") }
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
$base = "https://api.francetravail.io/partenaire/stats-offres-demandes-emploi/v1/indicateur"

New-Item -ItemType Directory -Force (Join-Path $racine "data\raw") | Out-Null
$lignes = @()
foreach ($i in $indicateurs) {
    foreach ($t in $territoires) {
        $requete = @{
            codeTypeTerritoire    = $t.type
            codeTerritoire        = $t.code
            codeTypeActivite      = $i.activite[0]
            codeActivite          = $i.activite[1]
            codeTypePeriode       = $i.periode
            codeTypeNomenclature  = $i.nomenclature
            listeCodeNomenclature = $i.valeurs
        }
        try {
            $reponse = Invoke-WebRequest -UseBasicParsing -Method Post -Uri "$base/$($i.endpoint)" -Headers $entetes -ContentType "application/json" -Body ($requete | ConvertTo-Json)
        } catch {
            Write-Warning "$($i.code) $($t.type)$($t.code) : pas de donnees (HTTP $($_.Exception.Response.StatusCode.value__))"
            continue
        }
        $json = [Text.Encoding]::UTF8.GetString($reponse.RawContentStream.ToArray())
        [IO.File]::WriteAllText((Join-Path $racine "data\raw\$($i.code)_$($t.type)$($t.code)_$aujourdhui.json"), $json, [Text.UTF8Encoding]::new($false))
        foreach ($p in ($json | ConvertFrom-Json).listeValeursParPeriode) {
            $lignes += [pscustomobject]@{
                date_extraction = $aujourdhui
                canal           = "API France Travail - Marche du travail"
                indicateur      = $i.code
                type_activite   = $p.codeTypeActivite
                activite        = "$($p.codeActivite) - $($p.libActivite)"
                type_territoire = $p.codeTypeTerritoire
                territoire      = $p.libTerritoire
                periode         = $p.codePeriode
                nomenclature    = $p.libNomenclature
                valeur_nombre   = $p.valeurPrincipaleNombre
                valeur_decimale = $p.valeurPrincipaleDecimale
                valeur_montant  = $p.valeurPrincipaleMontant
            }
        }
    }
}
$sortie = Join-Path $racine "data\indicateurs_$aujourdhui.csv"
$lignes | Export-Csv -Path $sortie -NoTypeInformation -Encoding UTF8 -Delimiter ";"
"$($lignes.Count) lignes enregistrees dans $sortie"
