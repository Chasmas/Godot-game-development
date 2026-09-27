#!/usr/bin/env python3
"""
Story pass for 1988: writes the Chapter I-C scenes (Yermo aftermath, Burbank,
Stage Nine, the news that follows) and threads new beats into the existing
scenes (Mom's message, the funeral-home sponsor, the empty extinguisher).
Existing node ids and choice order are kept so saves and tests still line up.

  python tools/write_story.py
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "data", "dialogue")


def load(name):
    return json.load(open(os.path.join(D, name + ".json"), encoding="utf-8"))


def save(name, data):
    with open(os.path.join(D, name + ".json"), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("wrote", name)


def chain(lines, start="a"):
    """[(id, speaker, text, extra), ...] -> nodes, each linked to the next
    unless it has choices/branch/next of its own."""
    nodes = {}
    for i, row in enumerate(lines):
        nid, spk, text = row[0], row[1], row[2]
        extra = row[3] if len(row) > 3 else {}
        n = {"speaker": spk, "text": text}
        n.update(extra)
        if "next" not in n and "choices" not in n and "branch" not in n and i + 1 < len(lines) and not extra.get("end"):
            n["next"] = lines[i + 1][0]
        n.pop("end", None)
        nodes[nid] = n
    return nodes


# ------------------------------------------------------------------ prologue
def prologue():
    d = load("prologue")
    d["nodes"] = chain([
        ("a0", "narration", "Route 58, 1987. The crew calls it the edge of the world, because the catering truck won't drive any further.", {"shot": "desert_road"}),
        ("a", "tommy", "Ever notice nobody says 'cut' out here? Desert doesn't care when the scene ends.", {"shot": "tommy_car"}),
        ("b", "cass", "Tommy. Get out of the car.", {"shot": "cass_close"}),
        ("c", "tommy", "Cassie, it's a stunt. Squibs, fire bars, camera tricks. We do the dangerous part so somebody else gets the close-up.", {"shot": "tommy_car"}),
        ("c1", "cass", "The fire marshal left an hour ago.", {"shot": "cass_close"}),
        ("c2", "tommy", "He left because craft services ran out of donuts. The man has priorities.", {"shot": "tommy_car"}),
        ("c3", "cass", "Harcourt's standing where the extinguishers are supposed to be. He won't look at me.", {"shot": "cass_close"}),
        ("c4", "tommy", "Harcourt doesn't look at anybody. That's why they put him on fire watch.", {"shot": "tommy_car"}),
        ("d", "voice", "Rolling. Speed. HOTSHOT, scene forty, take one.", {"sfx": "vhs_static", "shot": "clapper"}),
        ("e", "tommy", "Hey. If this goes wrong, tell Mom I finally got top billing.", {"shot": "tommy_car"}),
        ("e1", "cass", "Tommy—", {"shot": "cass_close", "auto": 0.9}),
        ("f", "narration", "Action.", {"event": "fire", "sfx": "explosion", "shot": "explosion"}),
        ("g", "voice", "...hold it. Hold it. Nobody move.", {"sfx": "vhs_static", "shot": "wreck"}),
        ("g1", "voice", "Keep the cameras rolling. That's the take.", {"shot": "wreck"}),
        ("g2", "narration", "Somebody drops an extinguisher. It bounces on the asphalt. It's empty. It rings like a bell.", {"shot": "extinguisher"}),
    ])
    d["start"] = "a0"
    save("prologue", d)


# ------------------------------------------------------------------ apartment
def apartment():
    d = load("apartment_1988")
    n = d["nodes"]
    if "k4" in n:
        return   # already threaded in
    n["a"]["text"] = "You have... two... new messages."
    n["a"]["next"] = "m1"
    n["m1"] = {"speaker": "mom", "text": "Cassie, it's Mom. Happy Fourth. The fireworks have the cat under the stove again.", "shot": "mom_kitchen", "next": "m2", "sfx": "blip"}
    n["m2"] = {"speaker": "mom", "text": "I bought a cake. I know. I know it's silly. He'd be twenty-six today... Anyway. Call me back, sweetheart.", "shot": "mom_kitchen", "next": "m3"}
    n["m3"] = {"speaker": "machine", "text": "Next message.", "sfx": "blip", "shot": "machine", "next": "b"}
    n["k3"]["next"] = "k4"
    ev = n["k3"].pop("event", None)
    n["k4"] = {"speaker": "cass", "text": "Top billing, Tommy.", "shot": "mirror"}
    if ev:
        n["k4"]["event"] = ev
    save("apartment_1988", d)


# ------------------------------------------------------------------ news
def news():
    d = load("news_1988")
    n = d["nodes"]
    n["f"]["next"] = "ad1"
    n["ad1"] = {"speaker": "marv", "text": "HOTSHOT CALIFORNIA is brought to you by Desert Rose Funeral Homes. Desert Rose: we're dying to meet you.", "shot": "marv", "next": "g"}
    n["g"]["next"] = "g2"
    n["g2"] = {"speaker": "marv", "text": "Fridays, eleven P.M. Viewers are advised that everything you are about to see is real. Everything.", "shot": "marv", "next": "h"}
    save("news_1988", d)


# ------------------------------------------------------------------ salvage call
def salvage():
    d = load("salvage_1988")
    n = d["nodes"]
    n["c"]["next"] = "c2"
    n["c2"] = {"speaker": "cass", "text": "Arlo. He still owes Tommy forty bucks and a carburetor.", "shot": "polaroid", "next": "d"}
    save("salvage_1988", d)


# ------------------------------------------------------------------ Yermo aftermath
def yermo_after():
    nodes = chain([
        ("a", "narration", "The office smells like wet dog, whiskey and old film stock. Every monitor in the room is showing her.", {"shot": "yermo_office"}),
        ("b", "arlo", "Sit down, kid. You're blocking channel four.", {"shot": "arlo_close"}),
        ("c", "cass", "You watched the whole thing.", {"shot": "arlo_close"}),
        ("d", "arlo", "Watched? I had money on you. Sergeant Biscuits had money on the dogs. Biscuits is gonna be unbearable.", {"shot": "arlo_close"}),
        ("e", "arlo", "The network sends the dog food. Premium. By the pallet. Nobody sends a stunt coordinator steak out of kindness, Cass. They were fattening up the set.", {"shot": "live_monitors"}),
        ("f", "cass", "...", {"shot": "arlo_close", "choices": [
            {"text": "Who rigged the car, Arlo?", "next": "w1"},
            {"text": "You were there. You let it happen.", "next": "l1", "set": {"arlo_confessed": True}},
        ]}),
        ("w1", "arlo", "The gag was clean when I checked it at midnight. Pads, bars, two extinguishers. Full ones. I lifted them myself.", {"shot": "arlo_close", "next": "w2"}),
        ("l1", "arlo", "I was there. Asleep in the truck with the heater on, because the Director swore the shot was scrubbed till dawn.", {"shot": "arlo_close"}),
        ("l2", "arlo", "I woke up to the light. You ever see a fire through a windshield? Looks like a sunrise on the wrong side of the sky.", {"shot": "arlo_close", "next": "w2"}),
        ("w2", "arlo", "Three in the morning, Dutch Kowalski walked back out to that car with a toolbox. Dutch. Our pyro. They call him the Fireman now.", {"shot": "arlo_close"}),
        ("x", "arlo", "Dutch does effects for KHSC these days. Stage Nine, Burbank. That new show. The one your brother's in.", {"shot": "live_monitors"}),
        ("y", "cass", "Tommy isn't in anything.", {"shot": "arlo_close"}),
        ("z", "arlo", "Friday, eleven P.M. They're cutting his last take into the premiere. I've seen the promo. They put a laugh track on the part where he's screaming.", {"shot": "live_monitors"}),
        ("z2", "cass", "...", {"shot": "arlo_close", "auto": 1.4}),
        ("v", "arlo", "And Vance. Aurelio. My kid brother. When we were boys he'd burn ants with a magnifying glass. Said the sun did it. He just held the lens.", {"shot": "arlo_close"}),
        ("v2", "arlo", "That's the whole business, Cass. Somebody else always holds the lens.", {"shot": "arlo_close"}),
        ("r", "narration", "A small red dot drifts across the whiskey bottle. The desk. His chest. He sees it before she does.", {"shot": "red_dot"}),
        ("r2", "arlo", "Ah. Wrap party.", {"shot": "arlo_close", "auto": 1.2}),
        ("r3", "narration", "The window goes white. Out in the yard, every dog stops barking at once.", {"shot": "dogs_silent", "sfx": "sniper", "event": "gunshot", "set": {"arlo_dead": True}}),
        ("r4", "voice", "Episode two is in the can, hotshot. Get some sleep. Friday is the big one.", {"shot": "live_monitors", "sfx": "vhs_static"}),
    ])
    save("yermo_after", {"bg": "apartment", "music": "aftermath", "title": "YERMO SALVAGE — JULY 9, 1988 — 3:02 AM", "shot": "yermo_office", "start": "a", "nodes": nodes})


# ------------------------------------------------------------------ Burbank
def studio():
    nodes = chain([
        ("a", "narration", "Santa Ana winds: hot as a hair dryer, forty miles an hour. The hills behind the studio lot have been burning since Tuesday.", {"shot": "burbank_night"}),
        ("b", "narration", "On the billboard, a gold star the size of a car. HOTSHOT CALIFORNIA. TONIGHT. 11 PM.", {"shot": "burbank_night"}),
        ("c", "voice", "The overnights came in, Miss Moreno. Thirty-one share for the motel. Your mother watched. She didn't know it was you. She liked it.", {"shot": "control_room"}),
        ("d", "cass", "Where's Kowalski?", {"shot": "burbank_night"}),
        ("e", "voice", "Stage Nine. Wardrobe has your jacket. And I see makeup's already done.", {"shot": "control_room"}),
        ("f", "rudy", "THERE you are! Oh thank God. You're late, you're gorgeous, you're on in nineteen minutes. Is that the star? Great star. Very on brand.", {"shot": "stage_door"}),
        ("g", "cass", "Who are you?", {"shot": "stage_door"}),
        ("h", "rudy", "Rudy! Floor manager! Nobody ever— okay. Listen. Security's jumpy, the sprinklers are 'decorative', and Mr. Kowalski says nobody touches his fire bars.", {"shot": "stage_door"}),
        ("h2", "rudy", "Break a leg. Not literally. Legal was very clear about that this week.", {"shot": "stage_door"}),
        ("i", "cass", "What's the show tonight, Rudy?", {"shot": "stage_door"}),
        ("j", "rudy", "Sweetheart. You are.", {"shot": "stage_door", "auto": 1.6}),
        ("k", "narration", "Inside, under the lights, somebody has built room 204. Same bedspread. Same stain on the carpet. The cameras are already rolling.", {"shot": "room_204_set", "sfx": "on_air_buzz"}),
        ("l", "cass", "...", {"shot": "room_204_set", "choices": [
            {"text": "Find the Fireman.", "next": "q1"},
            {"text": "Find the control room.", "next": "q2", "set": {"cass_hunts_booth": True}},
        ]}),
        ("q1", "cass", "Fire watch, Dutch. Your turn.", {"shot": "burbank_night", "end": True}),
        ("q2", "cass", "Somebody's calling the shots in there. I'd like a word.", {"shot": "control_room", "end": True}),
    ])
    save("studio_1988", {"bg": "tv_news", "music": "apartment", "title": "BURBANK — JULY 15, 1988 — 10:41 PM", "shot": "burbank_night", "start": "a", "nodes": nodes})


# ------------------------------------------------------------------ Stage Nine boss
def boss():
    save("m03_boss_intro", {"start": "a", "nodes": chain([
        ("a", "dutch", "Well, look at that jawline. You've got his jawline. Hold still, I'll get your good side."),
        ("b", "cass", "You went back to the car at three in the morning."),
        ("c", "dutch", "Four minutes past. I'm a professional. Fire bars, doubled. Pads, pulled. Extinguishers, emptied into the sand. Tommy even waved at me."),
        ("d", "dutch", "Fire's honest, kid. It doesn't care who the star is."),
        ("e", "pa", "WE ARE LIVE IN FIVE. FOUR. THREE...", {"sfx": "on_air_buzz", "event": "boss_start"}),
    ])})
    save("m03_boss_down", {"start": "a", "nodes": chain([
        ("a", "dutch", "Hah... hah. Look at the tote board, kid. Look at those numbers. They love you."),
        ("b", "cass", "Who paid you?"),
        ("c", "dutch", "Vance paid. Vance always pays. But Vance didn't sign the change order."),
        ("d", "cass", "Then who did?"),
        ("e", "dutch", "Moreno. T. Moreno. Nice handwriting. Loops on the capitals."),
        ("f", "cass", "You're lying."),
        ("g", "dutch", "Maybe. Ask why the sprinklers in here are dry. Same as the extinguishers. Somebody likes a theme."),
        ("h", "pa", "THE LINES ARE OPEN, CALIFORNIA! Dial ONE to FINISH HIM. Dial TWO to SPARE HIM. Operators are standing by!", {"sfx": "tote_ding"}),
        ("i", "narration", "Above the stage the tote board ticks over. FINISH: 2,114,902. SPARE: 11.", {"sfx": "tote_ding"}),
        ("j", "cass", "...", {"choices": [
            {"text": "Give them their ending.", "next": "k1"},
            {"text": "Cut the feed.", "next": "s1", "set": {"dutch_spared": True}},
        ]}),
        ("k1", "cass", "This one's for the viewers at home.", {"event": "boss_execute"}),
        ("k2", "narration", "The studio audience applauds. The applause is canned. It goes on a little too long.", {"sfx": "applause", "end": True}),
        ("s1", "cass", "Show's over.", {"event": "boss_spare"}),
        ("s2", "narration", "She puts a bullet through the nearest camera. Then the next. Then the next. On forty million screens, the picture goes to snow.", {"sfx": "tv_break"}),
        ("s3", "dutch", "They'll just cut to a commercial, kid. They always cut to a commercial.", {"end": True}),
    ])})


# ------------------------------------------------------------------ the next night's news
def news_b():
    nodes = chain([
        ("a", "anchor", "Good evening. A fire at KHSC's Stage Nine in Burbank interrupted last night's premiere of HOTSHOT CALIFORNIA.", {"shot": "news_studio_fire", "branch": [{"if": "dutch_spared", "next": "b1"}, {"next": "b2"}]}),
        ("b1", "anchor", "Special-effects technician Dutch Kowalski was carried from the building by firefighters. He told reporters he would, quote, absolutely do it again.", {"shot": "news_studio_fire", "next": "c"}),
        ("b2", "anchor", "The body of special-effects technician Dutch Kowalski was recovered from the stage. Viewers who phoned in to vote have been assured their calls were billed correctly.", {"shot": "phone_bank", "next": "c"}),
        ("c", "anchor", "The network estimates forty million viewers. The largest audience in the station's history.", {"shot": "phone_bank"}),
        ("d", "marv", "Folks, we lost a soundstage. We found a star. You can't buy that. Well. You can. We did.", {"shot": "marv"}),
        ("e", "anchor", "Next week's episode will air as scheduled.", {"shot": "news_studio_fire"}),
        ("f", "narration", "In a motel off the 5, she tapes the rerun and steps through the end credits one frame at a time.", {"shot": "credits_tv"}),
        ("g", "narration", "EXECUTIVE PRODUCER — T. MORENO.", {"shot": "credits_tv", "sfx": "tape_rewind"}),
        ("h", "cass", "...Tommy?", {"shot": "credits_tv", "auto": 1.6}),
        ("i", "narration", "She rewinds it three times. The name doesn't change.", {"shot": "credits_tv", "sfx": "tape_rewind"}),
        ("j", "voice", "Again. From the top.", {"shot": "control_room", "sfx": "vhs_static"}),
    ])
    save("news_1988b", {"bg": "tv_news", "music": "aftermath", "title": "KHSC CHANNEL 9 — JULY 16, 1988", "shot": "news_studio_fire", "start": "a", "nodes": nodes})


def teaser():
    d = load("teaser")
    n = d["nodes"]
    # a note on Dana's board before the fire
    n["c"]["next"] = "c2"
    n["c2"] = {"speaker": "narration", "text": "RECOVERED NOTE, PINNED TO A CORKBOARD: 'THE STAR KILLER IS NOT ONE PERSON. CHECK THE CREDITS.'", "shot": "corkboard_note", "next": "d"}
    save("teaser", d)


# ------------------------------------------------------------------ the nightmare (Chapter I-D)
def dream():
    nodes = chain([
        ("a", "narration", "She counts them before she sleeps. It used to be sheep.", {"shot": "motel_dream"}),
        ("b", "narration", "Twenty-four at the motel. Nineteen at the yard. Thirty-one on Stage Nine. She always loses count around the bellhop.", {"shot": "motel_dream"}),
        ("c", "cass", "They had guns. They were paid. They'd have done the same to me.", {"shot": "motel_dream"}),
        ("c2", "narration", "In the mirror by the door, her reflection gets up a moment after she does.", {"shot": "mirror_dead"}),
        ("c3", "cass", "...", {"shot": "mirror_dead", "auto": 1.4}),
        ("d", "narration", "The television at the foot of the bed stops showing static. It shows a house on a hill, and a banner over the door. WRAP PARTY.", {"shot": "tv_mansion", "sfx": "vhs_static"}),
        ("e", "dead", "Everybody's here, Cass. Everybody you invited.", {"shot": "wrap_party"}),
        ("f", "tommy", "Cassie. Come up to the house. We saved you a seat.", {"shot": "villa_gate"}),
        ("g", "narration", "She's standing on the lawn. The graves have gold stars on them. The dirt is still moving.", {"shot": "villa_gate"}),
    ])
    save("motel_dream", {"bg": "black", "music": "", "title": "A MOTEL OFF THE 5 — JULY 16, 1988 — 4:12 AM", "shot": "motel_dream", "start": "a", "nodes": nodes})
    save("m04_boss_intro", {"start": "a", "nodes": chain([
        ("a", "tommy_burnt", "Cassie. You came to the party."),
        ("b", "cass", "You're not him."),
        ("c", "tommy_burnt", "I'm the part of him you kept. Somebody had to. You burned the rest of the cast getting here."),
        ("d", "tommy_burnt", "Twenty-four. Nineteen. Thirty-one. You were never this good at math."),
        ("e", "tommy_burnt", "Let's do the take properly this time. You in the car. Me holding the extinguisher.", {"event": "boss_start", "sfx": "flame_ignite"}),
    ])})
    save("m04_boss_down", {"start": "a", "nodes": chain([
        ("a", "tommy_burnt", "...see? You can put a fire out. You just never want to."),
        ("b", "cass", "I'm doing this for you."),
        ("c", "tommy_burnt", "No. You're doing it for them. Look up. The little red lights."),
        ("d", "tommy_burnt", "Top billing, Cassie. It's all yours. It always was."),
        ("e", "cass", "...", {"choices": [
            {"text": "Let him burn out.", "next": "k1"},
            {"text": "Hold him.", "next": "s1", "set": {"held_tommy_dream": True}},
        ]}),
        ("k1", "cass", "Goodbye, Tommy.", {"event": "boss_execute"}),
        ("k2", "narration", "The fire goes out. The dead applaud politely, like a studio audience told when to.", {"sfx": "applause", "end": True}),
        ("s1", "cass", "Come here.", {"event": "boss_spare"}),
        ("s2", "narration", "She holds him while he burns. It doesn't hurt. That's how she knows it's a dream.", {}),
        ("s3", "tommy_burnt", "Check the credits, Cassie. Check who signed.", {"end": True}),
    ])})
    nodes = chain([
        ("a", "narration", "She wakes with the pistol pointed at the television. The test pattern hums.", {"shot": "pov_test_pattern"}),
        ("b", "narration", "The phone is ringing. It has been ringing for a while.", {"shot": "phone_ringing", "sfx": "phone_ring"}),
        ("c", "voice", "Bad dreams, Miss Moreno? Good. It means you're finally method acting.", {"shot": "wake_motel"}),
        ("d", "cass", "Who signed the change order?", {"shot": "wake_motel"}),
        ("e", "voice", "Season two starts in 1990. We've already cast the others. A girl at an arcade. A cop who doesn't sleep. You'll love them. You'll kill some of them.", {"shot": "casting_1990"}),
        ("f", "cass", "And me?", {"shot": "wake_motel"}),
        ("g", "voice", "You're the reason they're watching. Rest. We'll call you when we need the star.", {"shot": "wake_motel", "sfx": "blip"}),
        ("h", "narration", "On the corkboard she builds that week, the first Polaroid is a girl in a harlequin jacket at the Galaxy Palace. Somebody has already written THE FOOL under it.", {"shot": "casting_1990"}),
        ("i", "cass", "Then I get there first.", {"shot": "casting_1990"}),
    ])
    save("wake_1988", {"bg": "black", "music": "apartment", "title": "A MOTEL OFF THE 5 — JULY 16, 1988 — 6:40 AM", "shot": "wake_motel", "start": "a", "nodes": nodes})


# ------------------------------------------------------------------ the call as each mission starts
def calls():
    def t(line):
        return {"auto": round(1.4 + len(line[2]) / 20.0, 1)}
    def call(name, lines):
        rows = [(r[0], r[1], r[2], dict(t(r), **(r[3] if len(r) > 3 else {}))) for r in lines]
        save(name, {"start": rows[0][0], "nodes": chain(rows)})
    call("call_m01", [
        ("a", "voice", "Evening, Miss Moreno. You parked where Harcourt can't see you. Good instincts."),
        ("b", "voice", "Room 204 is upstairs, east side. The night manager keeps the office off the lobby. Twenty-odd guests tonight. None of them are guests."),
        ("c", "cass", "Why me?"),
        ("d", "voice", "Because you already know how this scene ends. Wear the star. Hit your mark."),
    ])
    call("call_m02", [
        ("a", "mom", "Cassie? It's Mom. I know it's late. A man called about Tommy's car. Arlo something. He says he still has it."),
        ("b", "mom", "He said you'd come for it tonight. Out in Yermo? At two in the morning?"),
        ("c", "cass", "Go back to sleep, Mom."),
        ("d", "mom", "Bring me something of his. Anything. ...And be nice to the dogs. You know how you get with dogs."),
    ])
    call("call_m03", [
        ("a", "rudy", "Is this thing on? Miss Moreno? It's Rudy. From the door. I'm in the green room closet. Don't ask."),
        ("b", "rudy", "Security's everywhere, the stagehands have pipes, and Mr. Kowalski is on the Cadillac in the middle of the stage. He's been polishing a flamethrower for an hour."),
        ("c", "rudy", "The control room's up the east side. And the sprinklers really are fake. I checked. I'm a professional."),
        ("d", "cass", "Stay in the closet, Rudy."),
        ("e", "rudy", "Copy. Closet. Great. Love the closet."),
    ])
    call("call_m04", [
        ("a", "tommy", "Cassie? It's me. Don't hang up. I know what this is. I'm calling from the house."),
        ("b", "tommy", "Everybody came. The guards from the motel, Arlo's boys, the stagehands. They've got stars on their faces now. Your stars."),
        ("c", "cass", "Tommy. You're dead."),
        ("d", "tommy", "So are they. Nobody here minds. Come up to the ballroom. There's a gun on every table. Mom would hate it."),
        ("e", "dead", "Checkout was midnight... checkout was midnight..."),
    ])


def speakers():
    s = load("speakers")
    s.update({
        "mom": {"name": "MOM", "color": "f2b8c6", "pitch": 1.05},
        "arlo": {"name": "ARLO VANCE", "color": "c8b070", "pitch": 0.7},
        "dutch": {"name": "DUTCH KOWALSKI", "color": "ff8a3d", "pitch": 0.62},
        "rudy": {"name": "RUDY, FLOOR MANAGER", "color": "9ee6a0", "pitch": 1.3},
        "pa": {"name": "STAGE ANNOUNCER", "color": "ff5a5a", "pitch": 0.9},
        "tommy_burnt": {"name": "TOMMY?", "color": "ff9a4a", "pitch": 0.85},
        "dead": {"name": "THE DEAD", "color": "a8b0a0", "pitch": 0.55},
    })
    with open(os.path.join(D, "speakers.json"), "w", encoding="utf-8") as f:
        json.dump(s, f, ensure_ascii=False, indent=1)
        f.write("\n")


def campaign():
    p = os.path.join(ROOT, "data", "missions", "campaign.json")
    c = [
        {"type": "cutscene", "id": "prologue"},
        {"type": "cutscene", "id": "apartment_1988"},
        {"type": "mission", "id": "m01_checkout"},
        {"type": "cutscene", "id": "news_1988"},
        {"type": "cutscene", "id": "salvage_1988"},
        {"type": "mission", "id": "m02_dog_days"},
        {"type": "cutscene", "id": "yermo_after"},
        {"type": "cutscene", "id": "studio_1988"},
        {"type": "mission", "id": "m03_prime_time"},
        {"type": "cutscene", "id": "news_1988b"},
        {"type": "cutscene", "id": "motel_dream"},
        {"type": "mission", "id": "m04_sweet_dreams"},
        {"type": "cutscene", "id": "wake_1988"},
        {"type": "cutscene", "id": "teaser"},
    ]
    with open(p, "w", encoding="utf-8") as f:
        json.dump(c, f, indent="\t")
        f.write("\n")


if __name__ == "__main__":
    prologue(); apartment(); news(); salvage(); yermo_after(); studio(); boss(); news_b(); dream(); calls(); teaser(); speakers(); campaign()
