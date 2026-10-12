"""Recover exact missing reference images by SHA-256; never substitute artwork."""
from pathlib import Path
import hashlib,json,os,re,shutil

root=Path(__file__).resolve().parents[1]
targets={}
for path in (root/'migration/reference-images').iterdir():
    if not path.is_file() or path.stat().st_size>1024:continue
    data=path.read_bytes()
    if not data.startswith(b'version https://git-lfs.github.com/spec/v1'):continue
    oid=re.search(rb'oid sha256:([a-f0-9]+)',data).group(1).decode()
    size=int(re.search(rb'size (\d+)',data).group(1))
    targets[oid]=(path,size)
sizes={size for _,size in targets.values()}
recovered=[]
for base,dirs,files in os.walk(Path.home()):
    dirs[:]=[d for d in dirs if d not in {'.git','.toolchain','node_modules','.godot','Application Data','Local Settings'}]
    for name in files:
        if not targets:break
        path=Path(base)/name
        try:
            if path.stat().st_size not in sizes:continue
            digest=hashlib.sha256(path.read_bytes()).hexdigest()
            if digest not in targets:continue
            dest,size=targets.pop(digest)
            shutil.copyfile(path,dest)
            cache=root/'.git/lfs/objects'/digest[:2]/digest[2:4]/digest
            cache.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(dest,cache)
            recovered.append({'file':str(dest.relative_to(root)),'source':str(path),'sha256':digest})
        except (OSError,PermissionError):continue
report={'recovered':recovered,'unresolved':[str(p.relative_to(root)) for p,_ in targets.values()]}
(root/'.toolchain/reference-recovery.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
