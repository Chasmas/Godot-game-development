param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)
$ErrorActionPreference = 'Stop'
$assetRoot = Join-Path $ProjectRoot 'assets/art/reference/cast_redesign_v1'
$manifest = Get-Content -LiteralPath (Join-Path $assetRoot 'batch_manifest.json') -Raw | ConvertFrom-Json
$results = @()
foreach ($entry in $manifest.entries) {
    $row = [ordered]@{ id=$entry.id; status=$entry.status; reference=$entry.reference_file; exists=$false; valid_png_header=$false; width=0; height=0; bytes=0; sha256=$null; prompt_exists=$false; visual_review='not_proven_by_file_audit' }
    if ($entry.reference_file) {
        $path = Join-Path $assetRoot $entry.reference_file
        $row.exists = Test-Path -LiteralPath $path
        if ($row.exists) {
            $bytes = [System.IO.File]::ReadAllBytes($path)
            $row.bytes = $bytes.Length
            if ($bytes.Length -ge 24) {
                $signature = [BitConverter]::ToString($bytes, 0, 8)
                $row.valid_png_header = $signature -eq '89-50-4E-47-0D-0A-1A-0A'
                if ($row.valid_png_header) {
                    $row.width = [int64]$bytes[16]*16777216 + [int64]$bytes[17]*65536 + [int64]$bytes[18]*256 + $bytes[19]
                    $row.height = [int64]$bytes[20]*16777216 + [int64]$bytes[21]*65536 + [int64]$bytes[22]*256 + $bytes[23]
                }
            }
            $row.sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
            $promptName = [System.IO.Path]::GetFileNameWithoutExtension($entry.reference_file).Replace('_turnaround','_prompt') + '.txt'
            if ($entry.prompt_file) { $promptName = $entry.prompt_file }
            $row.prompt_exists = Test-Path -LiteralPath (Join-Path $assetRoot $promptName)
        }
    }
    $results += [pscustomobject]$row
}
$report = [ordered]@{
    scope='File existence, PNG signature and dimensions, prompt provenance only. Does not approve identity, anatomy, art quality, textures, Blender models, animation or runtime integration.'
    generated_at=[DateTime]::UtcNow.ToString('o')
    runtime_replacements=$manifest.runtime_replacements
    duplicate_ids=@($manifest.entries | Group-Object id | Where-Object Count -gt 1 | Select-Object -ExpandProperty Name)
    unlisted_images=@(Get-ChildItem -LiteralPath $assetRoot -Filter '*_turnaround.png' | Where-Object { $_.Name -notin $manifest.entries.reference_file } | Select-Object -ExpandProperty Name)
    entries=$results
}
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $assetRoot 'file_audit.json') -Encoding UTF8
[pscustomobject]@{ entries=$results.Count; available=@($results | Where-Object exists).Count; missing=@($results | Where-Object { -not $_.exists }).Count; invalid_png=@($results | Where-Object { $_.exists -and -not $_.valid_png_header }).Count; missing_prompts=@($results | Where-Object { $_.exists -and -not $_.prompt_exists }).Count; duplicate_ids=$report.duplicate_ids.Count; unlisted_images=$report.unlisted_images.Count }
