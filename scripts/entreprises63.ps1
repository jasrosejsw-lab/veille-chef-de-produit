# Entreprises de 50 salariés et plus ayant au moins un établissement dans le Puy-de-Dôme (63).
# Canal : API "Recherche d'entreprises" (recherche-entreprises.api.gouv.fr, gratuite, sans clé), source Sirene.
# Sortie : data/entreprises_63_AAAA-MM-JJ.csv. Aucune donnée sur les dirigeants (données personnelles) n'est collectée.
# L'effectif filtré est celui de l'ENTREPRISE (tranche nationale), pas de l'établissement local.
$racine = Split-Path $PSScriptRoot -Parent
$aujourdhui = Get-Date -Format "yyyy-MM-dd"
$sortie = Join-Path $racine "data\entreprises_63_$aujourdhui.csv"
if (Test-Path $sortie) { "L'extraction du $aujourdhui existe deja ($sortie)."; return }

$tranches = "21,22,31,32,41,42,51,52,53"   # 50-99, 100-199, 200-249, 250-499, 500-999, 1000-1999, 2000-4999, 5000-9999, 10000 et plus
$base = "https://recherche-entreprises.api.gouv.fr/search?departement=63&tranche_effectif_salarie=$tranches&etat_administratif=A&per_page=25"
$lignes = @()
$page = 1
$pages = 1
while ($page -le $pages) {
    try {
        $r = Invoke-WebRequest -UseBasicParsing -Uri "$base&page=$page" -Headers @{ Accept = "application/json" }
    } catch {
        Write-Warning "Page $page : arret (HTTP $($_.Exception.Response.StatusCode.value__))"
        break
    }
    $j = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()) | ConvertFrom-Json
    $pages = $j.total_pages
    foreach ($e in $j.results) {
        $communes = @($e.matching_etablissements | ForEach-Object { $_.libelle_commune } | Where-Object { $_ } | Select-Object -Unique)
        $lignes += [pscustomobject]@{
            date_extraction   = $aujourdhui
            canal             = "API Recherche d'entreprises (Sirene)"
            siren             = $e.siren
            nom               = $e.nom_complet
            section_activite  = $e.section_activite_principale
            naf               = $e.activite_principale
            tranche_effectif  = $e.tranche_effectif_salarie
            categorie         = $e.categorie_entreprise
            siege_commune     = $e.siege.libelle_commune
            siege_dans_63     = if ($e.siege.departement -eq "63") { 1 } else { 0 }
            etablissements_63 = @($e.matching_etablissements).Count
            communes_63       = ($communes -join " / ")
        }
    }
    $page++
    Start-Sleep -Milliseconds 250
}
if ($lignes.Count -eq 0) { "Aucune entreprise recuperee : fichier non ecrit."; return }
$lignes | Export-Csv $sortie -NoTypeInformation -Encoding UTF8 -Delimiter ";"
"$($lignes.Count) entreprises ($pages pages) enregistrees dans $sortie ; siege dans le 63 : $(@($lignes | Where-Object { $_.siege_dans_63 -eq 1 }).Count)"
