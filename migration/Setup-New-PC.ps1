param([switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $projectRoot
$toolchainRoot = Join-Path $projectRoot '.toolchain'
New-Item -ItemType Directory -Path $toolchainRoot -Force | Out-Null
function Run-Native([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed with exit code $LASTEXITCODE" }
}
function Install-Package([string]$Id) {
    Run-Native 'winget' @('install','--id',$Id,'--exact','--source','winget','--accept-package-agreements','--accept-source-agreements','--silent')
}
if (-not $CheckOnly) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'Install Windows App Installer first.' }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Install-Package 'Git.Git' }
    $python313Present = $false
    if (Get-Command py -ErrorAction SilentlyContinue) {
        try { & py -3.13 -c 'import sys; assert sys.version_info[:2] == (3,13)' 2>$null; $python313Present = ($LASTEXITCODE -eq 0) } catch { $python313Present = $false }
    }
    if (-not $python313Present) { Install-Package 'Python.Python.3.13' }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'Install Windows App Installer (winget), then reopen this launcher.' }
    $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine')+';'+[Environment]::GetEnvironmentVariable('Path','User')
    Run-Native 'git' @('lfs','install','--local')
    Run-Native 'git' @('lfs','pull')
    $blenderArchive = Join-Path $PSScriptRoot 'blender-current-windows.zip'
    if (Test-Path -LiteralPath $blenderArchive) {
        Expand-Archive -LiteralPath $blenderArchive -DestinationPath (Join-Path $toolchainRoot 'blender') -Force
    } else {
        $blenderCandidates = @(Get-ChildItem -LiteralPath 'C:\Program Files\Blender Foundation' -Filter blender.exe -Recurse -ErrorAction SilentlyContinue)
        if ($blenderCandidates.Count -eq 0) { Install-Package 'BlenderFoundation.Blender' }
    }
    if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) { Install-Package 'Gyan.FFmpeg' }
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Install-Package 'OpenJS.NodeJS.LTS' }
    $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine')+';'+[Environment]::GetEnvironmentVariable('Path','User')
    $venvPath = Join-Path $toolchainRoot 'python'
    if (-not (Test-Path (Join-Path $venvPath 'Scripts\python.exe'))) { Run-Native 'py' @('-3.13','-m','venv',$venvPath) }
    $pythonPath = Join-Path $venvPath 'Scripts\python.exe'
    Run-Native $pythonPath @('-m','pip','install','-r',(Join-Path $PSScriptRoot 'requirements.lock.txt'))
    Run-Native $pythonPath @((Join-Path $PSScriptRoot 'configure_godot_connector.py'))
    Expand-Archive -LiteralPath (Join-Path $PSScriptRoot 'godot-current-windows.zip') -DestinationPath (Join-Path $toolchainRoot 'godot') -Force
    if (Test-Path (Join-Path $PSScriptRoot 'credentials.enc.json')) {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = 'Select the private migration key copied from your old PC (never upload this key to GitHub)'
        $dialog.Filter = 'Migration key|*.key'
        if ($dialog.ShowDialog() -eq 'OK') { Run-Native $pythonPath @((Join-Path $PSScriptRoot 'restore_credentials.py'),$dialog.FileName) }
        else { Write-Warning 'Credential import skipped. Add the API keys before using generation services.' }
    }
} else { $pythonPath = Join-Path $toolchainRoot 'python\Scripts\python.exe' }
$blenderPath = Join-Path $toolchainRoot 'blender\blender.exe'
if (-not (Test-Path -LiteralPath $blenderPath)) { $blenderPath = Get-ChildItem -LiteralPath 'C:\Program Files\Blender Foundation' -Filter blender.exe -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName }
$godotPath = Get-ChildItem -LiteralPath (Join-Path $toolchainRoot 'godot') -Filter '*console.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
if (-not $blenderPath -or -not $godotPath -or -not (Test-Path $pythonPath)) { throw 'Required toolchain is incomplete. Run setup again and inspect the error.' }
@{project=$projectRoot;python=$pythonPath;blender=$blenderPath;godot=$godotPath;created=(Get-Date).ToString('o')} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $toolchainRoot 'paths.json') -Encoding UTF8
Run-Native $pythonPath @((Join-Path $PSScriptRoot 'verify_migration.py'))
if (-not $CheckOnly) { Run-Native $godotPath @('--headless','--path',$projectRoot,'--editor','--import','--quit') }
Write-Host 'Setup complete. Sign into Codex, open this repository and paste RESUME.txt into a task. Read RESUME_HANDOFF.md before continuing.' -ForegroundColor Green
Start-Process explorer.exe -ArgumentList $projectRoot -WindowStyle Normal
