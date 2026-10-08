import json,sys
from pathlib import Path
import tomllib
python_path=Path(sys.executable)
server=python_path.parent/'godot-ai.exe'
if not server.is_file():raise SystemExit('Godot AI package executable missing')
config=Path.home()/'.codex/config.toml'
config.parent.mkdir(parents=True,exist_ok=True)
text=config.read_text(encoding='utf-8') if config.exists() else ''
parsed=tomllib.loads(text)
if 'godot-ai' in parsed.get('mcp_servers',{}):
    print('Existing Godot AI MCP configuration preserved; review host paths in Codex if necessary.')
else:
    command=python_path.parent/'pythonw.exe'
    wrapper='import subprocess,sys; raise SystemExit(subprocess.call(sys.argv[1:], stdin=sys.stdin, stdout=sys.stdout, stderr=sys.stderr, creationflags=0x08000000))'
    args=['-c',wrapper,str(server),'attach','--port','8001','--ws-port','8002']
    addition='\n[mcp_servers.godot-ai]\ncommand = '+json.dumps(str(command))+'\nargs = '+json.dumps(args)+'\n'
    tomllib.loads(text+addition)
    config.write_text(text+addition,encoding='utf-8')
    print('Godot AI MCP configured. Restart Codex and enable the project addon to connect.')
