#!/usr/bin/env python3
"""HOTSHOT CALIFORNIA - the soundtrack through the ElevenLabs Music API.

  python tools/audio/eleven_music.py <track_id> [<track_id> ...]
  python tools/audio/eleven_music.py --list
  python tools/audio/eleven_music.py --credits

Tracks live in tools/audio/soundtrack.json. Each is a composition plan
(music_v2_5 "chunks"); a chunk may be conditioned on a slice of an earlier
track ("ref": {"track": id, "start": s, "end": s}) - that's how the main
theme's motif carries through the rest of the score.

Raw results: music/source/<id>.mp3 (+ song ids in music/source/songs.json).
Nothing is regenerated if the file exists (pass --again). Credits are read
before and after every call and printed, so nothing gets spent silently.
Key: $ELEVENLABS_API_KEY or ~/.elevenlabs_key.
"""
import json, os, sys, urllib.request, urllib.error

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PLAN = os.path.join(ROOT, "tools", "audio", "soundtrack.json")
SRC = os.path.join(ROOT, "music", "source")
SONGS = os.path.join(SRC, "songs.json")
API = "https://api.elevenlabs.io/v1"

def key():
    k = os.environ.get("ELEVENLABS_API_KEY", "")
    if not k:
        p = os.path.join(os.path.expanduser("~"), ".elevenlabs_key")
        if os.path.exists(p):
            k = open(p, encoding="utf-8-sig").read().strip()
    if not k:
        sys.exit("no ElevenLabs key")
    return k

def credits():
    req = urllib.request.Request(API + "/user/subscription", headers={"xi-api-key": key()})
    d = json.load(urllib.request.urlopen(req, timeout=30))
    return int(d["character_count"]), int(d["character_limit"])

def load_songs():
    return json.load(open(SONGS)) if os.path.exists(SONGS) else {}

def compose(tid, t, songs):
    chunks = []
    for c in t["chunks"]:
        ch = {"text": c["text"], "duration_ms": int(c["sec"] * 1000), "positive_styles": c["styles"]}
        avoid = list(c.get("avoid", []))
        if t.get("instrumental", True):
            # force_instrumental only works with a plain prompt: say it per chunk
            if "instrumental" not in ch["positive_styles"]:
                ch["positive_styles"] = ch["positive_styles"] + ["instrumental"]
            avoid += ["vocals", "singing", "lyrics", "spoken word"]
        if avoid:
            ch["negative_styles"] = avoid
        if c.get("adherence"):
            ch["context_adherence"] = c["adherence"]
        if c.get("ref"):
            r = c["ref"]
            if r["track"] not in songs:
                sys.exit(f"{tid}: generate {r['track']} first (it is this track's reference)")
            ch["conditioning_ref"] = {"song_id": songs[r["track"]], "range": {"start_ms": int(r["start"] * 1000), "end_ms": int(r["end"] * 1000)}}
            ch["condition_strength"] = r.get("strength", "medium")
        chunks.append(ch)
    body = {"model_id": t.get("model", "music_v2_5"), "composition_plan": {"chunks": chunks}}
    if t.get("seed") is not None:
        body["seed"] = t["seed"]
    req = urllib.request.Request(API + "/music?output_format=mp3_44100_192", data=json.dumps(body).encode(),
                                 headers={"xi-api-key": key(), "Content-Type": "application/json"})
    try:
        r = urllib.request.urlopen(req, timeout=900)
    except urllib.error.HTTPError as e:
        print(f"  ! {tid}: HTTP {e.code} {e.read()[:600]}")
        return False
    audio = r.read()
    sid = r.headers.get("song-id") or r.headers.get("x-song-id") or ""
    if not sid:
        for h, v in r.headers.items():
            if "song" in h.lower():
                sid = v
    os.makedirs(SRC, exist_ok=True)
    open(os.path.join(SRC, tid + ".mp3"), "wb").write(audio)
    if sid:
        songs[tid] = sid
        json.dump(songs, open(SONGS, "w"), indent=1)
    print(f"  {tid}: {len(audio) // 1024} KB, song id {sid or '(none in headers)'}")
    return True

def main():
    plan = json.load(open(PLAN, encoding="utf-8"))
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--credits" in sys.argv:
        u, lim = credits()
        print(f"credits used {u} of {lim} ({lim - u} left)")
        return
    if "--list" in sys.argv or not args:
        for tid, t in plan["tracks"].items():
            secs = sum(c["sec"] for c in t["chunks"])
            done = os.path.exists(os.path.join(SRC, tid + ".mp3"))
            print(f"  {'x' if done else ' '} {tid:28s} {secs:5.0f}s  ~{secs / 60 * 900:5.0f} cr  {t.get('title', '')}")
        return
    songs = load_songs()
    total = sum(sum(c["sec"] for c in plan["tracks"][a]["chunks"]) for a in args)
    u0, lim = credits()
    print(f"about to compose {len(args)} tracks, {total / 60:.1f} min (~{total / 60 * 900:.0f} credits); {lim - u0} credits left")
    for tid in args:
        if os.path.exists(os.path.join(SRC, tid + ".mp3")) and "--again" not in sys.argv:
            print(f"  {tid}: already there")
            continue
        compose(tid, plan["tracks"][tid], songs)
    u1, _ = credits()
    print(f"spent {u1 - u0} credits; {lim - u1} left")

if __name__ == "__main__":
    main()
