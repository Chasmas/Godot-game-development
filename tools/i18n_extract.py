#!/usr/bin/env python3
"""
Collect every player-facing English string (the translation keys) from
scripts, dialogue, level files and data resources.

  python3 tools/i18n_extract.py            -> writes data/i18n/_keys.txt
  python3 tools/i18n_extract.py --check pt_PT
        -> lists keys missing from data/i18n/pt_PT.json (exit 1 if any)

Heuristics for scripts: string literals that look like prose/UI (contain an
uppercase letter or a space and a letter), excluding resource paths, sound
names, StringNames, colours, format-only strings and identifiers.
"""
import json, os, re, sys, glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

UI_SCRIPTS = [
    "scripts/ui/*.gd", "scripts/narrative/*.gd", "scripts/levels/level.gd", "scripts/levels/door.gd",
    "scripts/levels/interactable.gd", "scripts/levels/power.gd", "scripts/levels/alarm_panel.gd",
    "scripts/player/player_controller.gd", "scripts/player/upgrades.gd", "scripts/player/ability_system.gd",
    "scripts/player/executions.gd", "scripts/systems/score_system.gd", "scripts/systems/input_setup.gd",
    "scripts/systems/difficulty.gd", "scripts/systems/debug_menu.gd", "scripts/enemies/boss_night_manager.gd",
    "scripts/enemies/npc.gd", "scripts/levels/arcade_director.gd", "scripts/levels/nightmare_director.gd",
    "scripts/enemies/boss_fireman.gd", "scripts/enemies/boss_burning_man.gd", "scripts/enemies/handler.gd", "scripts/weapons/weapon_pickup.gd", "scripts/systems/game.gd",
]
# strings that are code, not text
SKIP_RE = [
    re.compile(r"^res://|^user://|\.(gd|tres|tscn|json|png|wav|ogg|gdshader)$"),
    re.compile(r"^[a-z0-9_]+$"),              # identifiers, sfx names, groups
    re.compile(r"^#?[0-9a-fA-F]{6,8}$"),      # colours
    re.compile(r"^[%\d\s.:/,+\-x×|()\[\]]*[sdf]?[%\d\s.:/,+\-x×|()\[\]sdf]*$"),  # format-only
    re.compile(r"^[A-Z_]+$"),                 # enum-ish keys like SPOTTED handled below
]
KEEP_UPPER_SINGLE = True   # single uppercase words are UI labels ("OPTIONS")

LIT = re.compile(r'(?<![&\w])"((?:[^"\\]|\\.)*)"')

# node names, theme types and other code strings that happen to look like text
NOT_TEXT = {"mode%d", "%s@%s", "paint/", "glow/", "Arcade", "Nightmare", "arc_%d_%d", "rise_%d_%d", "%s  ·  %s", "I-C", "I-D", "Visual3DDressing", "title/hotshot_title.webp", "cutscenes/apartment_1988.webp", "cutscenes/news_1988.webp", "Floor", "Effects", "Walls", "Props", "Pickups", "Doors", "Actors", "Lights", "Bullets", "Crowd",
            "Decor", "Glow", "TabContainer", "VScrollBar", "Button", "Label", "PanelContainer", "Panel", "HSlider",
            "CheckButton", "OptionButton", "Underline", "modulate:a", ".remap", "[i]", "[/i]", "[pop]", "[/pop]", "KV", "SS", "XM",
            "NV", "BK", "AD", "QH", "LS", "SI", "A+", "S+", "SSS", "LMB", "RMB", "MMB", "M4", "M5", "LB", "RB",
            "LT", "RT", "RS", "L3", "R3", "HOTSHOT", "California", "GILBERTO LOPES", "INVERTED  INDEX",
            "S   T   U   D   I   O", "VACANCY", "NO", "Barks", "Ambience", "%s#%d", "%s_%s%d", "%s_%d", "HOTSHOT  —  1988", "◀◀ %d:%02d:%02d", "SP", "%d%%", "REC", "00:00:%02d:%02d", "%s  ·  %s  ·  %s", "I", "II", "III", "IV", "I-B", "position:x", "position:y", "1280 x 720", "1600 x 900", "1920 x 1080", "2560 x 1440"}

def looks_like_text(s):
    if s in NOT_TEXT or re.match(r"^(civilian#|reinf_|debug_|step|%s:%d)", s):
        return False
    if len(s) < 2 or not re.search(r"[A-Za-zÀ-ÿ]", s):
        return False
    if re.match(r"^res://|^user://", s) or re.search(r"\.(gd|tres|tscn|json|png|wav|ogg|gdshader)$", s):
        return False
    if re.match(r"^[a-z0-9_]+$", s):
        return False
    if re.match(r"^#?[0-9a-fA-F]{6,8}$", s):
        return False
    if re.match(r"^[a-z_]+(/[a-z_]+)+$", s):   # project setting paths
        return False
    if re.match(r"^[a-z][a-z_]*\.[a-z_.]+$", s):
        return False
    return True

# files full of code strings (paths, registry keys): only tr("...") counts
TR_ONLY = {"scripts/ui/installer.gd"}
TR_LIT = re.compile(r'\btr\("((?:[^"\\]|\\.)*)"\)')

def from_scripts():
    out = {}
    for pat in UI_SCRIPTS:
        for f in sorted(g.replace("\\", "/") for g in glob.glob(pat)):
            if f in TR_ONLY:
                for i, line in enumerate(open(f, encoding="utf-8"), 1):
                    for m in TR_LIT.finditer(line):
                        out.setdefault(m.group(1).replace('\\"', '"'), f"{f}:{i}")
                continue
            for i, line in enumerate(open(f, encoding="utf-8"), 1):
                code = line.split("##")[0]
                if code.strip().startswith("#"):
                    continue
                if re.search(r"\b(push_error|push_warning|print|printerr|get_node|has_method|is_in_group|add_to_group|call|connect|emit_signal|load|preload)\(", code) and "text" not in code:
                    continue
                for m in LIT.finditer(code):
                    s = m.group(1).replace("\\n", "\n").replace('\\"', '"').replace("\\t", "\t")
                    if looks_like_text(s):
                        out.setdefault(s, f"{f}:{i}")
    return out

def walk_json(x, out, src, keys=("text", "name", "title", "hint", "label")):
    if isinstance(x, dict):
        for k, v in x.items():
            if isinstance(v, str) and (k in keys) and looks_like_text(v):
                out.setdefault(v, src)
            else:
                walk_json(v, out, src, keys)
    elif isinstance(x, list):
        for v in x:
            walk_json(v, out, src, keys)

def from_dialogue():
    out = {}
    for f in sorted(glob.glob("data/dialogue/*.json")):
        walk_json(json.load(open(f, encoding="utf-8")), out, f)
    return out

def from_levels():
    out = {}
    for f in sorted(glob.glob("levels/*.json")):
        d = json.load(open(f, encoding="utf-8"))
        for v in d.get("objectives", {}).values():
            if looks_like_text(v):
                out.setdefault(v, f + ":objectives")
        for h in d.get("hints", []):
            out.setdefault(h.get("text", ""), f + ":hints")
        for c in d.get("collectibles", {}).values():
            for k in ("title", "text"):
                if c.get(k):
                    out.setdefault(c[k], f + ":collectibles")
        for e in d.get("enemies", {}).values() if isinstance(d.get("enemies"), dict) else []:
            for line in e.get("lines", []) if isinstance(e, dict) else []:
                out.setdefault(line, f + ":npc")
        for k in ("time_text",):
            if d.get(k):
                out.setdefault(d[k], f)
        walk_json(d.get("npcs", {}), out, f + ":npcs", ("lines", "text"))
        for n in (d.get("npcs") or {}).values() if isinstance(d.get("npcs"), dict) else []:
            for line in n.get("lines", []):
                out.setdefault(line, f + ":npcs")
        for z in d.get("zones", {}).keys():
            out.setdefault(z.replace("_alley", "").replace("_", " ").upper(), f + ":zone")
    out.pop("", None)
    return out

TRES_FIELDS = ("display_name", "flavor", "archetype", "bio", "strengths", "weaknesses", "title", "location",
               "date_text", "briefing", "description", "look", "ability_name", "ability_desc", "notes_player")

def from_tres():
    out = {}
    for f in sorted(glob.glob("data/**/*.tres", recursive=True)):
        for line in open(f, encoding="utf-8"):
            m = re.match(r'^(\w+) = "((?:[^"\\]|\\.)*)"', line)
            if m and m.group(1) in TRES_FIELDS and looks_like_text(m.group(2)):
                out.setdefault(m.group(2).replace('\\"', '"').replace("\\n", "\n"), f)
    return out

def collect():
    keys = {}
    for part in (from_scripts(), from_dialogue(), from_levels(), from_tres()):
        for k, v in part.items():
            keys.setdefault(k, v)
    return keys

if __name__ == "__main__":
    keys = collect()
    if len(sys.argv) > 2 and sys.argv[1] == "--check":
        loc = sys.argv[2]
        tr = json.load(open(f"data/i18n/{loc}.json", encoding="utf-8"))
        missing = [k for k in keys if k not in tr]
        for k in missing:
            print(f"MISSING  {keys[k]}  {k!r}")
        print(f"{len(keys) - len(missing)}/{len(keys)} translated")
        sys.exit(1 if missing else 0)
    with open("data/i18n/_keys.txt", "w", encoding="utf-8") as f:
        for k, src in sorted(keys.items(), key=lambda kv: kv[1]):
            f.write(f"{src}\t{json.dumps(k, ensure_ascii=False)}\n")
    print(len(keys), "keys")
