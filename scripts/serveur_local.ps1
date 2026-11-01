# Serveur local minimal pour prévisualiser le site : http://localhost:8080/ (Ctrl+C pour arrêter).
# Facultatif : le site s'ouvre aussi en double-cliquant sur index.html.
param([int]$Port = 8080)
$racine = Split-Path $PSScriptRoot -Parent
$types = @{ ".html" = "text/html; charset=utf-8"; ".css" = "text/css; charset=utf-8"; ".js" = "text/javascript; charset=utf-8"; ".csv" = "text/csv; charset=utf-8"; ".json" = "application/json; charset=utf-8" }
$ecoute = [Net.HttpListener]::new()
$ecoute.Prefixes.Add("http://localhost:$Port/")
$ecoute.Start()
"Site sur http://localhost:$Port/"
while ($ecoute.IsListening) {
    $ctx = $ecoute.GetContext()
    $chemin = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
    if ($chemin -eq "") { $chemin = "index.html" }
    $fichier = [IO.Path]::GetFullPath((Join-Path $racine $chemin))
    # On ne sert que des fichiers du dossier du projet, jamais .env ni .git.
    $interdit = $chemin -match '(^|/)(\.env|\.git)'
    if ($fichier.StartsWith($racine) -and -not $interdit -and (Test-Path $fichier -PathType Leaf)) {
        $octets = [IO.File]::ReadAllBytes($fichier)
        $ctx.Response.ContentType = $types[[IO.Path]::GetExtension($fichier).ToLower()]
        $ctx.Response.OutputStream.Write($octets, 0, $octets.Length)
    } else { $ctx.Response.StatusCode = 404 }
    $ctx.Response.Close()
}
