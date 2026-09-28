#!/usr/bin/env python3
"""
Generate the painted art with the OpenAI Images API (needs OPENAI_API_KEY).

  python tools/art/gen_ai_art.py                 # everything missing
  python tools/art/gen_ai_art.py shots/fireman   # one entry (regenerates)
  python tools/art/gen_ai_art.py --cat sprites   # one category

Entries live in tools/art/ai_manifest.json. Raw results are kept as source in
assets/art/Artwork/ai/<cat>/<id>.webp (excluded from the export); run
tools/art/process_ai_art.py afterwards to build the files the game loads.
Entries with "refs" are made with the edits endpoint so recurring characters
keep their faces (refs are crops of the character sheet, see REFS).
"""
import base64, io, json, os, sys, threading, time, urllib.request, urllib.error, uuid
from concurrent.futures import ThreadPoolExecutor
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
MANIFEST = os.path.join(ROOT, "tools", "art", "ai_manifest.json")
RAW = os.path.join(ROOT, "assets", "art", "Artwork", "ai")
SHEET = os.path.join(ROOT, "assets", "art", "Artwork", "image-1790495612810.webp")
GRID = [["cass", "harcourt", "earl"], ["tommy", "anchor", "guard"], ["marv", "voice", "machine"]]
MODEL = os.environ.get("AI_ART_MODEL", "gpt-image-2")
_lock = threading.Lock()


def log(*a):
    with _lock:
        print(*a, flush=True)


def ref_png(name):
    """A character reference: its cell of the painted character sheet, or a
    generated portrait (assets/art/Artwork/ai/portraits/<name>.webp)."""
    gen = os.path.join(RAW, "portraits", name + ".webp")
    if os.path.exists(gen):
        im = Image.open(gen).convert("RGB")
    else:
        sheet = Image.open(SHEET).convert("RGB")
        cw, ch = sheet.width / 3, sheet.height / 3
        for r, row in enumerate(GRID):
            if name in row:
                c = row.index(name)
                im = sheet.crop((round(c * cw) + 4, round(r * ch) + 4, round((c + 1) * cw) - 4, round((r + 1) * ch) - 4))
                break
        else:
            raise KeyError(name)
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return buf.getvalue()


def _multipart(fields, files):
    b = uuid.uuid4().hex
    out = io.BytesIO()
    for k, v in fields.items():
        out.write(f"--{b}\r\nContent-Disposition: form-data; name=\"{k}\"\r\n\r\n{v}\r\n".encode())
    for k, (fname, data) in files:
        out.write(f"--{b}\r\nContent-Disposition: form-data; name=\"{k}\"; filename=\"{fname}\"\r\nContent-Type: image/png\r\n\r\n".encode())
        out.write(data)
        out.write(b"\r\n")
    out.write(f"--{b}--\r\n".encode())
    return out.getvalue(), "multipart/form-data; boundary=" + b


def call(entry, style):
    key = os.environ["OPENAI_API_KEY"]
    prompt = (style + " " + entry["prompt"]).strip()
    size = entry.get("size", "1536x1024")
    quality = entry.get("quality", "medium")   # medium unless asked otherwise (credits)
    bg = entry.get("background")
    refs = entry.get("refs", [])
    if refs:
        fields = {"model": MODEL, "prompt": prompt + " Keep each referenced person's face, hair and costume exactly as in the reference portraits.", "size": size, "quality": quality, "n": "1"}
        if bg:
            fields["background"] = bg
        body, ctype = _multipart(fields, [("image[]", (r + ".png", ref_png(r))) for r in refs])
        url = "https://api.openai.com/v1/images/edits"
    else:
        payload = {"model": MODEL, "prompt": prompt, "size": size, "quality": quality, "n": 1}
        if bg:
            payload["background"] = bg
        body, ctype = json.dumps(payload).encode(), "application/json"
        url = "https://api.openai.com/v1/images/generations"
    for attempt in range(4):
        req = urllib.request.Request(url, data=body, headers={"Authorization": "Bearer " + key, "Content-Type": ctype})
        try:
            r = json.load(urllib.request.urlopen(req, timeout=600))
            return base64.b64decode(r["data"][0]["b64_json"])
        except urllib.error.HTTPError as e:
            msg = e.read()[:400]
            log(f"  ! {entry['_id']} HTTP {e.code}: {msg}")
            if e.code in (400, 401, 403):
                return None
        except Exception as e:  # network hiccup
            log(f"  ! {entry['_id']} {e}")
        time.sleep(5 + attempt * 10)
    return None


def run(entry, style):
    out = os.path.join(RAW, entry["_id"] + ".webp")
    t = time.time()
    data = call(entry, style)
    if data is None:
        log(f"FAIL {entry['_id']}")
        return False
    im = Image.open(io.BytesIO(data))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    if im.mode == "RGBA" and entry.get("background") == "transparent":
        im.save(out, "WEBP", quality=92, lossless=False, exact=True)
    else:
        im.convert("RGB").save(out, "WEBP", quality=92)
    log(f"ok   {entry['_id']}  ({time.time() - t:.0f}s)")
    return True


def main():
    man = json.load(open(MANIFEST, encoding="utf-8"))
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    cat = sys.argv[sys.argv.index("--cat") + 1] if "--cat" in sys.argv else None
    if cat:
        args = [a for a in args if a != cat]
    jobs = []
    # portraits first: later entries may use them as references
    order = ["portraits"] + [c for c in man["categories"] if c != "portraits"]
    for c in order:
        cdef = man["categories"].get(c)
        if cdef is None or (cat and c != cat):
            continue
        for eid, e in cdef["entries"].items():
            e = dict(cdef.get("defaults", {}), **e)
            e["_id"] = c + "/" + eid
            forced = e["_id"] in args
            if args and not forced:
                continue
            if not forced and os.path.exists(os.path.join(RAW, e["_id"] + ".webp")):
                continue
            jobs.append((c, e, cdef.get("style", "")))
    log(f"{len(jobs)} images to generate with {MODEL}")
    # portraits before anything that references them
    first = [j for j in jobs if j[0] == "portraits"]
    rest = [j for j in jobs if j[0] != "portraits"]
    workers = int(os.environ.get("AI_ART_WORKERS", "5"))
    fails = 0
    for batch in (first, rest):
        with ThreadPoolExecutor(workers) as ex:
            fails += sum(1 for ok in ex.map(lambda j: run(j[1], j[2]), batch) if not ok)
    log(f"done, {fails} failed")
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
