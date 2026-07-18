$ErrorActionPreference = "Stop"

$chocoCache = "$env:USERPROFILE\.choco-cache"
if (!(Test-Path $chocoCache))
{
    New-Item -ItemType Directory -Path $chocoCache -Force | Out-Null
}

choco install sccache make cmake -y --limit-output --cache-location="$chocoCache"

sccache --version
make --version