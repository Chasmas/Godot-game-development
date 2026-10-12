param(
    [Parameter(Mandatory = $true)]
    [string]$Scene,
    [int]$TimeoutSeconds = 90,
    [string]$SuccessPattern = '',
    [switch]$Windowed,
    [switch]$SkipInstrumentalAudit
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$python = Join-Path $root '.toolchain\python\Scripts\python.exe'
$instrumentalAudit = Join-Path $root 'tools\audio\verify_instrumental_audit.py'
if (-not $SkipInstrumentalAudit) {
    if (-not (Test-Path -LiteralPath $python)) { throw "Python toolchain not found: $python" }
    if (-not (Test-Path -LiteralPath $instrumentalAudit)) { throw "Instrumental audit not found: $instrumentalAudit" }
    & $python $instrumentalAudit
    if ($LASTEXITCODE -ne 0) { throw "Instrumental-only music audit failed; all music tracks must be no-vocals before Godot review." }
}
$godot = Join-Path $root '.toolchain\godot\Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $godot)) { throw "Godot toolchain not found: $godot" }
if (-not (Test-Path -LiteralPath (Join-Path $root $Scene))) { throw "Scene not found: $Scene" }

function Stop-ProcessTree([int]$ProcessId) {
    $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId = $ProcessId" -ErrorAction SilentlyContinue)
    foreach ($child in $children) { Stop-ProcessTree $child.ProcessId }
    Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
}

function Get-ReviewLogText([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        return Get-Content -LiteralPath $Path -Raw
    }
    return ''
}

$logRoot = Join-Path $root '.toolchain'
$stdout = Join-Path $logRoot ("review-$([guid]::NewGuid().ToString('N')).out.log")
$stderr = Join-Path $logRoot ("review-$([guid]::NewGuid().ToString('N')).err.log")
$arguments = @('--path', $root, "res://$($Scene.Replace('\', '/'))")
if (-not $Windowed) { $arguments = @('--headless') + $arguments }
$process = Start-Process -FilePath $godot -ArgumentList $arguments -WorkingDirectory $root -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
try {
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    $matched = $false
    while ([DateTime]::UtcNow -lt $deadline) {
        [string]$outText = Get-ReviewLogText $stdout
        [string]$errText = Get-ReviewLogText $stderr
        # An assertion can return from a helper while its caller still prints
        # the success marker. Script failures must take precedence over it.
        if ($errText -match 'SCRIPT ERROR:|Parse Error:') {
            throw "Godot review emitted a runtime error: $Scene`n$errText"
        }
        if (-not [string]::IsNullOrWhiteSpace($SuccessPattern)) {
            $matched = $outText -like "*$SuccessPattern*" -or $errText -like "*$SuccessPattern*"
            if ($matched) { break }
        }
        # Compatibility/headless renderers can emit nonfatal engine ERROR lines
        # for optional materials.  Abort only on executable-script failures;
        # process exit and the requested success marker still catch real faults.
        if ($errText -match 'SCRIPT ERROR:|Parse Error:') {
            throw "Godot review emitted a runtime error: $Scene`n$errText"
        }
        if ($process.HasExited) { break }
        Start-Sleep -Milliseconds 200
        $process.Refresh()
    }
    if ($matched) {
        Get-ReviewLogText $stdout
        Get-ReviewLogText $stderr
    } elseif (-not $process.HasExited) {
        throw "Godot review timed out after $TimeoutSeconds seconds: $Scene`n$(Get-ReviewLogText $stdout)`n$(Get-ReviewLogText $stderr)"
    }
    elseif ($process.ExitCode -ne 0) { throw "Godot review failed with exit code $($process.ExitCode): $Scene" }
}
finally {
    Stop-ProcessTree $process.Id
}
