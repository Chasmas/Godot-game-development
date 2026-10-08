#!/usr/bin/env python3
"""Characters as 3D models through the Meshy API, for top-down sprites that
turn a full 360 degrees (rendered from straight above in Blender).

  python tools/art/meshy3d.py model <id>          text -> 3D preview -> textured refine
  python tools/art/meshy3d.py image <id>          reference painting ("image" in the spec) -> textured 3D
  python tools/art/meshy3d.py rig <id>            humanoid skeleton (+ walk / run)
  python tools/art/meshy3d.py anim <id>           the game's actions on that skeleton
  python tools/art/meshy3d.py balance

Descriptions in tools/art/characters3d.json. Everything downloaded goes to
assets/art/Artwork/3d/<id>/ (excluded from the export); task ids are kept in
tasks.json there so nothing is paid for twice.
"""
import base64, json, os, sys, time, urllib.request, urllib.error

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SPEC = os.path.join(ROOT, "tools", "art", "characters3d.json")
OUT = os.path.join(ROOT, "assets", "art", "Artwork", "3d")
API = "https://api.meshy.ai/openapi"
# the game's actions -> Meshy animation library ids
ACTIONS = {"idle": 0, "walk": 30, "run": 14, "aim": 234, "sneak": 559, "punch": 96, "melee": 219, "kick": 206,
           "death": 184, "death_back": 183, "knocked": 187, "roll": 235, "doze": 268}

def key():
    return open(os.path.join(os.path.expanduser("~"), ".meshy_key"), encoding="utf-8-sig").read().strip()

def call(method, path, body=None):
    req = urllib.request.Request(API + path, data=json.dumps(body).encode() if body else None, method=method,
                                 headers={"Authorization": "Bearer " + key(), "Content-Type": "application/json"})
    try:
        return json.load(urllib.request.urlopen(req, timeout=120))
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code} {path}: {e.read()[:500]}")

def wait(path):
    while True:
        t = call("GET", path)
        st = t.get("status")
        print(f"  {path.split('/')[-2]} {st} {t.get('progress', '')}%", flush=True)
        if st == "SUCCEEDED":
            return t
        if st in ("FAILED", "CANCELED", "EXPIRED"):
            sys.exit(f"task {st}: {t.get('task_error')}")
        time.sleep(8)

def fetch(url, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with urllib.request.urlopen(url, timeout=300) as r, open(dst, "wb") as f:
        f.write(r.read())
    print("  saved", os.path.relpath(dst, ROOT))

def state(cid):
    p = os.path.join(OUT, cid, "tasks.json")
    return json.load(open(p)) if os.path.exists(p) else {}

def save_state(cid, s):
    os.makedirs(os.path.join(OUT, cid), exist_ok=True)
    json.dump(s, open(os.path.join(OUT, cid, "tasks.json"), "w"), indent=1)

def balance():
    return call("GET", "/v1/balance")["balance"]

def model(cid):
    spec = json.load(open(SPEC, encoding="utf-8"))[cid]
    s = state(cid)
    b0 = balance()
    if "preview" not in s:
        t = call("POST", "/v2/text-to-3d", {"mode": "preview", "prompt": spec["prompt"], "ai_model": "latest", "topology": "triangle",
                                            "target_polycount": spec.get("polys", 24000), "should_remesh": True,
                                            # animals stand as they are (rigged in Blender, tools/art/rig_quadruped.py)
                                            "pose_mode": "a-pose" if spec.get("humanoid", True) else ""})
        s["preview"] = t["result"]
        save_state(cid, s)
    wait(f"/v2/text-to-3d/{s['preview']}")
    if "refine" not in s:
        body = {"mode": "refine", "preview_task_id": s["preview"], "texture_prompt": spec["texture"], "enable_pbr": False}
        t = call("POST", "/v2/text-to-3d", body)
        s["refine"] = t["result"]
        save_state(cid, s)
    t = wait(f"/v2/text-to-3d/{s['refine']}")
    fetch(t["model_urls"]["glb"], os.path.join(OUT, cid, "model.glb"))
    if t.get("thumbnail_url"):
        fetch(t["thumbnail_url"], os.path.join(OUT, cid, "thumb.png"))
    print(f"credits {b0} -> {balance()}")

def model_from_image(cid):
    """Like model(), from the spec's reference painting: keeps the drawn identity."""
    spec = json.load(open(SPEC, encoding="utf-8"))[cid]
    s = state(cid)
    b0 = balance()
    if "refine" not in s:
        with open(os.path.join(ROOT, spec["image"]), "rb") as f:
            uri = "data:image/png;base64," + base64.b64encode(f.read()).decode()
        t = call("POST", "/v1/image-to-3d", {"image_url": uri, "ai_model": "latest", "topology": "triangle",
                                             "target_polycount": spec.get("polys", 24000), "should_remesh": True,
                                             "should_texture": True, "enable_pbr": False, "pose_mode": "a-pose",
                                             "texture_prompt": spec["texture"]})
        # rigging and animation take this id as their input task, as for text-to-3d
        s["refine"] = t["result"]
        s["source"] = "image-to-3d"
        save_state(cid, s)
    t = wait(f"/v1/image-to-3d/{s['refine']}")
    fetch(t["model_urls"]["glb"], os.path.join(OUT, cid, "model.glb"))
    if t.get("thumbnail_url"):
        fetch(t["thumbnail_url"], os.path.join(OUT, cid, "thumb.png"))
    print(f"credits {b0} -> {balance()}")

def rig(cid):
    s = state(cid)
    b0 = balance()
    if "rig" not in s:
        t = call("POST", "/v1/rigging", {"input_task_id": s["refine"], "height_meters": json.load(open(SPEC, encoding="utf-8"))[cid].get("height", 1.7)})
        s["rig"] = t["result"]
        save_state(cid, s)
    t = wait(f"/v1/rigging/{s['rig']}")
    res = t.get("result", {})
    for k, v in res.items():
        if isinstance(v, str) and v.startswith("http") and v.split("?")[0].endswith((".glb", ".fbx")):
            fetch(v, os.path.join(OUT, cid, "rig_" + k + os.path.splitext(v.split("?")[0])[1]))
        elif isinstance(v, dict):
            for k2, v2 in v.items():
                if isinstance(v2, str) and v2.startswith("http") and ".glb" in v2:
                    fetch(v2, os.path.join(OUT, cid, f"rig_{k}_{k2}.glb"))
    print(f"credits {b0} -> {balance()}")

def anim(cid, names):
    s = state(cid)
    b0 = balance()
    for n in names:
        key_ = "anim_" + n
        if key_ not in s:
            t = call("POST", "/v1/animations", {"rig_task_id": s["rig"], "action_id": ACTIONS[n], "post_process": {"operation_type": "change_fps", "fps": 24}})
            s[key_] = t["result"]
            save_state(cid, s)
        t = wait(f"/v1/animations/{s[key_]}")
        r = t.get("result", {})
        url = r.get("animation_glb_url")
        if url:
            fetch(url, os.path.join(OUT, cid, f"anim_{n}.glb"))
    print(f"credits {b0} -> {balance()}")

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "balance":
        print(balance())
    elif cmd == "model":
        model(sys.argv[2])
    elif cmd == "image":
        model_from_image(sys.argv[2])
    elif cmd == "rig":
        rig(sys.argv[2])
    elif cmd == "anim":
        anim(sys.argv[2], sys.argv[3:] or list(ACTIONS))
