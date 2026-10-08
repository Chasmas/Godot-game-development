$ErrorActionPreference='Stop'
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'Install Windows App Installer from Microsoft Store, then run this launcher again.' }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    & winget install --id Git.Git --exact --source winget --accept-package-agreements --accept-source-agreements --silent
    if ($LASTEXITCODE -ne 0) { throw 'Git installation failed.' }
    $env:Path=[Environment]::GetEnvironmentVariable('Path','Machine')+';'+[Environment]::GetEnvironmentVariable('Path','User')
}
$destination=Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'GitHub\Hotshot-California'
if (Test-Path -LiteralPath $destination) {
    if (-not (Test-Path (Join-Path $destination '.git'))) { throw "Destination already exists and is not a Git checkout: $destination" }
    Write-Host "Using existing checkout: $destination"
} else {
    New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
    $env:GIT_LFS_SKIP_SMUDGE='1'
    & git clone --branch migration/beefier-pc-2026-10-08 https://github.com/Chasmas/Godot-game-development.git $destination
    if ($LASTEXITCODE -ne 0) { throw 'GitHub clone failed. Sign into GitHub if the repository is private.' }
    Remove-Item Env:GIT_LFS_SKIP_SMUDGE -ErrorAction SilentlyContinue
}
& (Join-Path $destination 'migration\Setup-New-PC.ps1')
