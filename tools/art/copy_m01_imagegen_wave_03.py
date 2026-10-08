import shutil
from pathlib import Path
p=Path('assets/art/materials/m01/batch_v1')
files=[{"id":"bathroom_direction","source":"C:\\Users\\gil_n\\.codex\\generated_images\\01a0ee67-7e1b-7d31-a814-1ae1a58f829d\\exec-23f1815b-6aed-4131-841c-e5f1521f3657.png"},{"id":"back_office_direction","source":"C:\\Users\\gil_n\\.codex\\generated_images\\01a0ee67-7e1b-7d31-a814-1ae1a58f829d\\exec-3398e386-4952-4167-ad8c-357c0d840074.png"},{"id":"service_alley_direction","source":"C:\\Users\\gil_n\\.codex\\generated_images\\01a0ee67-7e1b-7d31-a814-1ae1a58f829d\\exec-572badee-6d02-439e-80a9-3f52a8b474a2.png"}]
for a in files: shutil.copy2(a['source'],p/(a['id']+'.png'))
