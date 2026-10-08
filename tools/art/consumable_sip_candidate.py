"""Review-only reach calibrated against actual can opening in transverse grip."""
from pathlib import Path
source=Path('tools/art/consumable_contact_candidate.py').read_text()
old='0.13769,-0.01947,mouth_z - 0.00712'
assert source.count(old)==1
source=source.replace(old,'0.17369,0.037674,mouth_z - 0.029218')
exec(compile(source,'tools/art/consumable_contact_candidate.py','exec'))
