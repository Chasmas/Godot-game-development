"""Bake and export the seven measured interruption candidates in one process."""
import runpy
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
surface = '--surface' in sys.argv
for frame in (1, 4, 7, 10, 13, 16, 19):
    sys.argv = ['bake_doberman_walk.py', '--blocked-stop', f'--stop-frame={frame}']
    if surface:
        sys.argv.append('--surface')
    runpy.run_path(str(ROOT / 'tools/blender/bake_doberman_walk.py'), run_name='__main__')
print('Seven stop phases exported', flush=True)
