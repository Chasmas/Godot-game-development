"""Bake every Meshy character that is complete but not yet in the game.

  python tools/art/bake_ready_cast.py [--loop SECONDS] [--force id,id]

A character is ready when assets/art/Artwork/3d/<id>/ has its rig and the last
clip the generator asks for (anim_knocked.glb). It is baked with Blender
(tools/art/render_cast3d.py --bake) into assets/art/cast3d_rt/<id>/<id>.glb,
which CastModel picks up for that look. Cass uses her hair-swapped body
(rig_newhair.glb) when it exists. With --loop it keeps watching, for a running
Meshy batch. Ids ending in _v<N> are drafts and are skipped.
"""
import os, subprocess, sys, time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "art", "Artwork", "3d")
OUT = os.path.join(ROOT, "assets", "art", "cast3d_rt")
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"

def ready():
    for cid in sorted(os.listdir(SRC)):
        d = os.path.join(SRC, cid)
        if "_v" in cid or not os.path.isdir(d):
            continue
        if os.path.exists(os.path.join(d, "anim_knocked.glb")) and os.path.exists(os.path.join(d, "anim_idle.glb")):
            yield cid

def bake(cid):
    out = os.path.join(OUT, cid, cid + ".glb")
    cmd = [BLENDER, "-b", "--python", os.path.join(ROOT, "tools", "art", "render_cast3d.py"), "--",
           os.path.join(SRC, cid), os.path.join(r"C:\tmp_shots\bake_tmp", cid), "--fps", "15", "--bake", out]
    body = os.path.join(SRC, cid, "rig_newhair.glb")
    if os.path.exists(body):
        cmd += ["--mesh", body]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    ok = os.path.exists(out) and "baked" in r.stdout
    print(("BAKED " if ok else "FAILED ") + cid, flush=True)
    if not ok:
        print(r.stdout[-1500:], r.stderr[-1500:], flush=True)

def main():
    force = sys.argv[sys.argv.index("--force") + 1].split(",") if "--force" in sys.argv else []
    loop = float(sys.argv[sys.argv.index("--loop") + 1]) if "--loop" in sys.argv else 0
    while True:
        for cid in ready():
            if cid in force or not os.path.exists(os.path.join(OUT, cid, cid + ".glb")):
                bake(cid)
                if cid in force:
                    force.remove(cid)
        if not loop:
            break
        time.sleep(loop)

if __name__ == "__main__":
    main()
