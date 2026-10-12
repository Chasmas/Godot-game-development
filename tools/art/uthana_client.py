"""Uthana setup check. Credentials stay in the Windows user's DPAPI store."""
import json, os, subprocess
from pathlib import Path
from uthana import Uthana

def client():
    key = os.environ.get('UTHANA_API_KEY')
    if not key:
        secret = Path.home() / '.codex/secrets/uthana.dpapi'
        if not secret.is_file():
            raise RuntimeError('Uthana credential is not configured')
        command = "$ErrorActionPreference='Stop'; $encrypted=(Get-Content -Raw -LiteralPath '" + str(secret).replace("'", "''") + "').Trim(); $s=ConvertTo-SecureString $encrypted; [System.Net.NetworkCredential]::new('', $s).Password"
        key = subprocess.run(['pwsh','-NoProfile','-Command',command],capture_output=True,text=True,check=True).stdout.strip()
    if not key:
        raise RuntimeError('Uthana credential could not be decrypted')
    return Uthana(key)

if __name__ == '__main__':
    api = client()
    try:
        user = api.org.get_user_sync()
    except Exception as error:
        print('Uthana account authentication failed:', type(error).__name__)
        raise SystemExit(1)
    styles = api.motions.list_locomotion_styles_sync()
    output = Path('build/uthana')
    output.mkdir(parents=True,exist_ok=True)
    (output / 'locomotion_styles.json').write_text(json.dumps(styles,indent=2),encoding='utf-8')
    print('Uthana client/authentication ready; locomotion styles:', styles)

