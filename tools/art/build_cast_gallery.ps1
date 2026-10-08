param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
)
$ErrorActionPreference = 'Stop'
$assetRoot = Join-Path $ProjectRoot 'assets/art/reference/cast_redesign_v1'
$manifest = Get-Content -LiteralPath (Join-Path $assetRoot 'batch_manifest.json') -Raw | ConvertFrom-Json
$cards = [System.Collections.Generic.List[string]]::new()
$audit = @()
foreach ($entry in $manifest.entries) {
    $reference = $entry.reference_file
    $exists = $reference -and (Test-Path -LiteralPath (Join-Path $assetRoot $reference))
    $audit += [pscustomobject]@{ id=$entry.id; status=$entry.status; reference=$reference; exists=[bool]$exists; identity_source=$entry.identity_source }
    if (-not $exists) { continue }
    $title = [System.Net.WebUtility]::HtmlEncode($entry.id)
    $brief = [System.Net.WebUtility]::HtmlEncode($entry.brief)
    $image = [System.Net.WebUtility]::HtmlEncode($reference)
    $kind = if ($entry.id -like 'zombie*' -or $entry.id -in @('ghoul','demon','shadow','hellhound','dead','burnt')) { 'nightmare' } else { 'living' }
    $cards.Add("<figure data-id='$title' data-kind='$kind'><a href='$image' target='_blank'><img src='$image' loading='lazy' alt='$title'></a><figcaption><strong>$title</strong><p>$brief</p></figcaption></figure>")
}
$pending = @($audit | Where-Object { -not $_.exists }).Count
$body = $cards -join "`n"
$html = @"
<!doctype html><html lang="pt"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Elenco - referencias ImageGen</title>
<style>
body{margin:0;background:#101217;color:#eee;font:15px/1.5 system-ui,sans-serif}header{padding:24px 32px;border-bottom:1px solid #353943}h1{margin:0;font-size:25px}header p{color:#c0c5cf;margin:8px 0 0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:16px;padding:24px}figure{margin:0;background:#1b1f27;border:1px solid #373d49;border-radius:10px;overflow:hidden}figure[hidden]{display:none}img{width:100%;display:block;aspect-ratio:3/2;object-fit:contain;background:#292d34}figcaption{padding:12px 16px}strong{font-size:17px}figcaption p{margin:6px 0;color:#c0c5cf;font-size:13px}a:focus{outline:3px solid #32c8e8}a:hover img{filter:brightness(1.08)}.controls{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin-top:16px}input,select,button{background:#242a34;border:1px solid #586274;border-radius:6px;color:#fff;padding:9px;font:inherit}button:disabled{opacity:.4}
</style><header><h1>Elenco - referencias ImageGen</h1><p>$($cards.Count) referencias disponiveis; $pending entradas ainda sem imagem. Conceitos em revisao, sem substituicoes no jogo. Clique numa imagem para ver a resolucao completa.</p><div class="controls"><input id="search" type="search" placeholder="Procurar personagem" aria-label="Procurar personagem"><select id="group" aria-label="Grupo"><option value="all">Todo o elenco</option><option value="living">Vivos e equipamentos</option><option value="nightmare">Pesadelo</option></select><button id="prev">Anterior</button><span id="count" aria-live="polite"></span><button id="next">Seguinte</button></div></header><main class="grid">$body</main>
<script>
const cards=Array.from(document.querySelectorAll('figure'));const search=document.getElementById('search');const group=document.getElementById('group');const prev=document.getElementById('prev');const next=document.getElementById('next');let page=0;const pageSize=30;
function render(){const filtered=cards.filter(c=>c.dataset.id.toLowerCase().includes(search.value.toLowerCase())&&(group.value==='all'||c.dataset.kind===group.value));const pages=Math.max(1,Math.ceil(filtered.length/pageSize));page=Math.min(page,pages-1);cards.forEach(c=>c.hidden=true);filtered.slice(page*pageSize,(page+1)*pageSize).forEach(c=>c.hidden=false);document.getElementById('count').textContent=(page+1)+' / '+pages+' - '+filtered.length+' imagens';prev.disabled=page===0;next.disabled=page>=pages-1;}
search.addEventListener('input',()=>{page=0;render()});group.addEventListener('change',()=>{page=0;render()});prev.addEventListener('click',()=>{page--;render()});next.addEventListener('click',()=>{page++;render()});render();
</script></html>
"@
[System.IO.File]::WriteAllText((Join-Path $assetRoot 'gallery.html'), $html, [System.Text.UTF8Encoding]::new($false))
$audit | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $assetRoot 'gallery_audit.json') -Encoding UTF8
[pscustomobject]@{ gallery=(Join-Path $assetRoot 'gallery.html'); available=$cards.Count; pending=$pending }
