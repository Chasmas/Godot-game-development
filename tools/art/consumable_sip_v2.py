"""Second measured reach iteration; isolated review only."""
from pathlib import Path
source=Path('tools/art/consumable_sip_candidate.py').read_text()
source=source.replace('0.17369,0.037674,mouth_z - 0.029218','0.153843,0.013195,mouth_z - 0.036045')
exec(compile(source,'tools/art/consumable_sip_candidate.py','exec'))
