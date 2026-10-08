import base64,json,sys,os
from pathlib import Path
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
root=Path(__file__).resolve().parent
key=base64.b64decode(Path(sys.argv[1]).read_text().strip())
bundle=json.loads((root/'credentials.enc.json').read_text())
data=json.loads(AESGCM(key).decrypt(base64.b64decode(bundle['nonce']),base64.b64decode(bundle['ciphertext']),b'Hotshot PC migration v1'))
for name,value in data.items():
    if name in {'ELEVENLABS_API_KEY','PIXELLAB_API_KEY','MESHY_API_KEY','OPENAI_API_KEY'}:
        if os.name=='nt':
            import winreg
            with winreg.CreateKey(winreg.HKEY_CURRENT_USER,'Environment') as reg:winreg.SetValueEx(reg,name,0,winreg.REG_SZ,value)
        filename={'ELEVENLABS_API_KEY':'.elevenlabs_key','PIXELLAB_API_KEY':'.pixellab_key','MESHY_API_KEY':'.meshy_key'}.get(name)
        if filename:(Path.home()/filename).write_text(value,encoding='utf-8')
print('Credentials restored locally. Restart Codex so it receives updated environment variables.')
