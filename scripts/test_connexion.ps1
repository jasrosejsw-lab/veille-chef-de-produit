# Teste la connexion à l'API France Travail (jeton OAuth2). N'affiche jamais les identifiants ni le jeton.
$racine = Split-Path $PSScriptRoot -Parent
$env_ = @{}
Get-Content (Join-Path $racine ".env") | ForEach-Object {
    $k, $v = $_ -split '=', 2
    if ($k) { $env_[$k.Trim()] = $v.Trim() }
}

$url = "https://entreprise.francetravail.fr/connexion/oauth2/access_token?realm=/partenaire"
$corps = @{
    grant_type    = "client_credentials"
    client_id     = $env_["FT_CLIENT_ID"]
    client_secret = $env_["FT_CLIENT_SECRET"]
}
if ($args.Count -gt 0) { $corps["scope"] = $args[0] }

try {
    $rep = Invoke-RestMethod -Method Post -Uri $url -Body $corps -ContentType "application/x-www-form-urlencoded"
    "OK : jeton obtenu (expire dans $($rep.expires_in) s), scopes accordés : $($rep.scope)"
} catch {
    $statut = $_.Exception.Response.StatusCode.value__
    "ECHEC : HTTP $statut"
    if ($_.ErrorDetails.Message) { $_.ErrorDetails.Message }
}
