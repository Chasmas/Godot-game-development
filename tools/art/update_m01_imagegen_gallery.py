"""Index unmodified ImageGen outputs; no image processing or Blender work."""
from pathlib import Path
import html
import json

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / 'assets/art/materials/m01/batch_v1'
images = sorted(BATCH.glob('*.png'), key=lambda p: (p.stat().st_mtime_ns, p.name))
groups = {'Materiais': [], 'Espaços': [], 'Objetos e personagens': []}
for image in images:
    label = image.stem.replace('_', ' ').title()
    group = 'Materiais' if 'albedo' in image.stem else ('Espaços' if 'direction' in image.stem else 'Objetos e personagens')
    groups[group].append(f'<figure><a href="{image.name}" target="_blank"><img loading="lazy" src="{image.name}" alt="{html.escape(label)}"></a><figcaption>{html.escape(label)}</figcaption></figure>')
page = '''<!doctype html><html lang="pt"><meta charset="utf-8"><title>Mapa 1 — ImageGen</title>
<style>body{background:#11131b;color:#eee;font:16px system-ui;margin:28px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:16px}figure{margin:0;background:#202430;padding:10px;border-radius:10px}img{width:100%;height:190px;object-fit:contain}figcaption{padding:8px;font-size:14px}a{color:inherit}</style>
<h1>Mapa 1 — Lote ImageGen</h1><p>COUNT imagens. Lote em geração. Clique numa imagem para ampliar. Referências e materiais de origem; Blender deste lote ainda não iniciado.</p>CARDS</html>'''
sections = '\n'.join(f'<h2>{name}</h2><main>{"".join(cards)}</main>' for name, cards in groups.items())
page_count = (len(images) + 29) // 30
navigation = '<nav>' + ' | '.join(f'<a href="gallery_{i+1:02}.html">Grupo {i+1}</a>' for i in range(page_count)) + '</nav>'
(BATCH / 'gallery.html').write_text(page.replace('COUNT', str(len(images))).replace('CARDS', navigation + sections), encoding='utf-8')
for i in range(page_count):
    subset = images[i*30:(i+1)*30]
    cards = []
    for image in subset:
        label = image.stem.replace('_', ' ').title()
        cards.append(f'<figure><a href="{image.name}" target="_blank"><img loading="lazy" src="{image.name}" alt="{html.escape(label)}"></a><figcaption>{html.escape(label)}</figcaption></figure>')
    group_page = page.replace('COUNT', str(len(subset))).replace('CARDS', navigation + f'<h2>Grupo {i+1}</h2><main>{"".join(cards)}</main>')
    (BATCH / f'gallery_{i+1:02}.html').write_text(group_page, encoding='utf-8')
manifest_path = BATCH / 'manifest.json'
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
manifest['files'] = [image.name for image in images]
manifest['generated_image_count'] = len(images)
manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding='utf-8')
print(f'Gallery indexed {len(images)} images: {BATCH / "gallery.html"}')
