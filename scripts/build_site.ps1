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

$js = "window.DONNEES = " + ($donnees | ConvertTo-Json -Depth 5 -Compress) + ";"
[IO.File]::WriteAllText((Join-Path $racine "donnees.js"), $js, [Text.UTF8Encoding]::new($false))
"donnees.js ecrit : $($donnees.offres.Count) offres, $($donnees.embauches.Count) embauches, $($donnees.tension.Count) tension, $($donnees.salaires.Count) salaires, $($donnees.appellations.Count) appellations, $($donnees.competences.Count) competences"
