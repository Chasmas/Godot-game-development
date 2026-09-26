#!/usr/bin/env python3
"""Generates the data-driven .tres resources (weapons, enemies, characters,
personas, missions). Edit the tables below or edit the .tres files in the
Godot inspector directly - both work."""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def val(v):
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, (int, float)): return repr(v)
    if isinstance(v, tuple): return "Color(%s)" % ", ".join(str(x) for x in (list(v) + [1])[:4])
    if isinstance(v, str) and v.startswith("&"): return '&"%s"' % v[1:]
    s = str(v).replace("\\", "\\\\").replace('"', '\\"')
    return '"%s"' % s

def write(folder, cls, script, rid, props):
    path = os.path.join(ROOT, "data", folder, rid + ".tres")
    lines = [f'[gd_resource type="Resource" script_class="{cls}" load_steps=2 format=3]', "",
             f'[ext_resource type="Script" path="{script}" id="1_s"]', "", "[resource]", 'script = ExtResource("1_s")']
    for k, v in props.items():
        lines.append(f"{k} = {val(v)}")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w").write("\n".join(lines) + "\n")

FIREARM, MELEE, THROWABLE = 0, 1, 2
ONE, TWO, M1, M2 = 0, 1, 2, 3
W = "res://scripts/weapons/weapon_data.gd"
weapons = {
 "pistol": dict(display_name="Service 9mm", kind=FIREARM, hold=ONE, fire_rate=5.0, magazine=12, spare_mags=1, reload_time=0.95,
   spread_deg=2.5, recoil_deg=2.2, bullet_speed=1500.0, noise_radius=460.0, sfx_fire="pistol", sprite_key="pistol",
   flavor="Standard issue. Stolen from somebody who had it issued.", dual_wieldable=True, muzzle_scale=1.0),
 "whisper": dict(display_name="Whisper .22", kind=FIREARM, hold=ONE, fire_rate=4.0, magazine=10, spare_mags=1, reload_time=1.0,
   spread_deg=2.0, recoil_deg=1.2, bullet_speed=1300.0, noise_radius=80.0, suppressed=True, sfx_fire="suppressed",
   sprite_key="whisper", camera_kick=1.2, muzzle_color=(0.6, 0.8, 1.0), flavor="Barely a cough. Enemies more than a room away won't hear it.", dual_wieldable=True, muzzle_scale=0.45),
 "revolver": dict(display_name=".357 Lawman", kind=FIREARM, hold=ONE, fire_rate=2.2, magazine=6, spare_mags=1, reload_time=1.45,
   spread_deg=1.2, recoil_deg=6.0, bullet_speed=1900.0, penetration=1, noise_radius=600.0, sfx_fire="revolver",
   sprite_key="revolver", camera_kick=4.5, knockback=200.0, flavor="Goes through the first guy. Sometimes the second.", muzzle_scale=1.3, ejects_shells=False, fire_hit_stop=0.018),
 "smg": dict(display_name="Surfside SMG", kind=FIREARM, hold=ONE, automatic=True, fire_rate=13.0, magazine=30, spare_mags=1,
   reload_time=1.2, spread_deg=5.5, move_spread_deg=5.0, recoil_deg=1.0, bullet_speed=1300.0, noise_radius=560.0,
   sfx_fire="smg", sprite_key="smg", camera_kick=1.6, flavor="Sprays like a garden hose. Sounds like a sewing machine from hell.", dual_wieldable=True, muzzle_scale=0.85),
 "shotgun": dict(display_name="Hibachi 12ga", kind=FIREARM, hold=TWO, fire_rate=1.5, magazine=6, spare_mags=1, reload_time=1.7,
   pellets=8, spread_deg=20.0, move_spread_deg=4.0, recoil_deg=4.0, bullet_speed=1150.0, max_range=320.0, noise_radius=700.0,
   sfx_fire="shotgun", sprite_key="shotgun", camera_kick=7.0, knockback=300.0, flavor="Closes every conversation.", muzzle_scale=1.7, fire_hit_stop=0.03),
 "rifle": dict(display_name="Canyon AR", kind=FIREARM, hold=TWO, automatic=True, fire_rate=9.0, magazine=30, spare_mags=1,
   reload_time=1.5, spread_deg=2.8, move_spread_deg=6.0, recoil_deg=1.4, bullet_speed=1800.0, penetration=1, noise_radius=640.0,
   sfx_fire="rifle", sprite_key="rifle", camera_kick=2.8, flavor="Desert-surplus. Punches through doors.", muzzle_scale=1.2),
 "hotshot": dict(display_name="THE HOTSHOT", kind=FIREARM, hold=ONE, fire_rate=2.6, magazine=6, spare_mags=3, reload_time=1.1,
   spread_deg=0.8, recoil_deg=4.0, bullet_speed=2100.0, penetration=2, ricochet=2, noise_radius=600.0, sfx_fire="revolver",
   sprite_key="hotshot", camera_kick=4.0, muzzle_color=(1.0, 0.8, 0.2), tracer_color=(1.0, 0.8, 0.3),
   flavor="Gold-plated prop revolver from an unreleased movie. It was never supposed to be loaded. Bullets ricochet.", muzzle_scale=1.3, ejects_shells=False, fire_hit_stop=0.02),
 "knife": dict(display_name="Switchblade", kind=MELEE, hold=M1, melee_range=21.0, melee_arc_deg=100.0, melee_cooldown=0.15, melee_windup=0.0,
   throw_lethal=True, throw_speed=620.0, sfx_hit="hit_blade", sprite_key="knife", score_tag="melee", flavor="Fast. Throw it and it stays thrown."),
 "bat": dict(display_name="Louisville Slugger", kind=MELEE, hold=M2, melee_range=27.0, melee_arc_deg=150.0, melee_cooldown=0.32,
   melee_windup=0.03, durability=14, sfx_hit="hit_blunt", sprite_key="bat", score_tag="melee", flavor="America's pastime."),
 "pipe": dict(display_name="Lead Pipe", kind=MELEE, hold=M2, melee_range=24.0, melee_arc_deg=130.0, melee_cooldown=0.27, melee_windup=0.02,
   sfx_hit="metal_clang", sprite_key="pipe", score_tag="melee", flavor="Never breaks. Neither will they, after this."),
 "machete": dict(display_name="Machete", kind=MELEE, hold=M1, melee_range=25.0, melee_arc_deg=130.0, melee_cooldown=0.21, melee_windup=0.02,
   throw_lethal=True, sfx_hit="hit_blade", sprite_key="machete", score_tag="melee", flavor="Brought back from somewhere nobody talks about."),
 "bottle": dict(display_name="Bottle of Tequila", kind=MELEE, hold=M1, melee_range=19.0, melee_arc_deg=110.0, melee_cooldown=0.19, melee_windup=0.02,
   lethal=False, durability=1, breaks_into="&broken_bottle", sfx_hit="bottle_break", sprite_key="bottle", score_tag="melee",
   flavor="Knocks them down. Then it's a knife."),
 "broken_bottle": dict(display_name="Broken Bottle", kind=MELEE, hold=M1, melee_range=18.0, melee_arc_deg=100.0, melee_cooldown=0.16, melee_windup=0.0,
   durability=3, sfx_hit="hit_blade", sprite_key="broken_bottle", score_tag="melee", flavor="Three more uses. Maybe."),
 "brick": dict(display_name="Brick", kind=THROWABLE, hold=M1, melee_range=18.0, melee_cooldown=0.28, lethal=False,
   sfx_hit="hit_blunt", sprite_key="brick", score_tag="thrown", flavor="Throw it. Through a window, ideally."),
}
for k, p in weapons.items():
    write("weapons", "WeaponData", W, k, {"id": "&" + k, **p})

SHOOTER, RUSHER, SHIELD, ALERTER, BOSS = 0, 1, 2, 3, 4
E = "res://scripts/enemies/enemy_data.gd"
enemies = {
 "guard": dict(display_name="Guard", combat=SHOOTER, weapon_id="&pistol", palette="guard",
   notes="Basic armed muscle. Patrols, investigates noises, shoots after a short reaction delay."),
 "gunner": dict(display_name="Gunner", combat=SHOOTER, weapon_id="&smg", palette="gunner", burst=5, burst_gap=0.08,
   aim_error_deg=8.0, reaction_time=0.45, flank_chance=0.5, notes="Sprays bursts, flanks through side doors."),
 "hunter": dict(display_name="Hunter", combat=RUSHER, weapon_id="&machete", palette="hunter", walk_speed=60.0, run_speed=172.0,
   reaction_time=0.2, melee_windup=0.24, view_distance=230.0, notes="Fast melee charger. Telegraphs his swing: hit him first to COUNTER."),
 "heavy": dict(display_name="Heavy", combat=SHOOTER, weapon_id="&shotgun", palette="heavy", walk_speed=38.0, run_speed=70.0,
   armor=1, can_be_knocked_down=False, immune_to_punch=True, reaction_time=0.55, preferred_range=90.0, burst=1,
   notes="Vest soaks one bullet. Doors and fists do nothing. Shoot twice, heavy-swing, or blow him up."),
 "scout": dict(display_name="Scout", combat=ALERTER, weapon_id="&", palette="scout", walk_speed=70.0, run_speed=178.0,
   reaction_time=0.1, view_distance=300.0, view_angle_deg=140.0, alert_others_radius=260.0, panic_chance=1.0,
   notes="Unarmed lookout. Runs for the nearest alarm panel when he sees you. Stop him."),
 "riot": dict(display_name="Riot", combat=SHIELD, weapon_id="&pipe", palette="riot", walk_speed=42.0, run_speed=88.0,
   shield_arc_deg=120.0, reaction_time=0.3, melee_windup=0.34, can_be_knocked_down=True,
   notes="Frontal shield blocks bullets. Flank him, slam a door into him, or throw something to stagger the shield."),
 "dog": dict(display_name="Guard Dog", combat=RUSHER, weapon_id="&", palette="shepherd", walk_speed=46.0, run_speed=190.0,
   reaction_time=0.15, melee_windup=0.2, view_distance=170.0, view_angle_deg=150.0, hearing_mult=1.6, alert_others_radius=240.0,
   can_be_knocked_down=True, notes="German Shepherd. Smells you if you rush past. Barks for its handlers. Kill it while it sleeps."),
 "dog_rott": dict(display_name="Rottweiler", combat=RUSHER, weapon_id="&", palette="rottweiler", walk_speed=40.0, run_speed=165.0,
   reaction_time=0.2, melee_windup=0.26, view_distance=150.0, view_angle_deg=140.0, hearing_mult=1.4, alert_others_radius=240.0,
   can_be_knocked_down=True, notes="Heavy, slower, relentless once it has your scent."),
 "night_manager": dict(display_name="Lyle Harcourt, Night Manager", combat=BOSS, weapon_id="&revolver", palette="boss",
   walk_speed=70.0, run_speed=150.0, armor=3, can_be_knocked_down=False, immune_to_punch=True, reaction_time=0.5,
   view_distance=420.0, view_angle_deg=160.0, burst=3, burst_gap=0.22, aim_error_deg=4.0, notes="Boss."),
}
for k, p in enemies.items():
    write("enemies", "EnemyData", E, k, {"id": "&" + k, **p})

C = "res://scripts/player/character_data.gd"
cast = {
 "cass": dict(display_name="Cass Moreno", archetype="THE STAR", year_first_seen=1988, persona="&star", palette="cass",
   playable_in_slice=True, ability="&spotlight", equipment="&flare", equipment_count=2,
   bio="Stunt driver. Twenty-six. Walked away from a burning Cadillac on the set of a movie that never came out. Her brother Tommy didn't walk away from anything.",
   strengths="Fast hands, fast car, SPOTLIGHT slow-motion.", weaknesses="Nothing special up close. Reckless."),
 "deacon": dict(display_name="Ray \"Deacon\" Tull", archetype="THE SAINT", year_first_seen=1990, persona="&saint", palette="deacon",
   move_speed=138.0, ability="&laying_on_hands", melee_damage_mult=2.0,
   bio="Defrocked preacher turned nightclub bouncer. Forgives everyone he hits. Hits everyone.",
   strengths="Punches kill. Counters anything.", weaknesses="Slow. Clumsy with guns."),
 "luz": dict(display_name="Luz Ferreira", archetype="THE GHOST", year_first_seen=1990, persona="&ghost", palette="luz",
   move_speed=158.0, ability="&blackout",
   bio="Cat burglar who only robs people who deserve it, by her own accounting. Keeps a ledger.",
   strengths="Invisible in the dark. Silent footsteps.", weaknesses="Can't carry two-handed guns."),
 "marv": dict(display_name="Marv Kessel", archetype="THE KING", year_first_seen=1991, persona="&king", palette="marv",
   move_speed=142.0, ability="&double_or_nothing",
   bio="Host of the late-night true-crime show 'HOTSHOT CALIFORNIA'. His ratings go up every time somebody dies.",
   strengths="Score multiplier that doubles while at risk.", weaknesses="Loses it all if hit."),
 "dana": dict(display_name="Officer Dana Pruitt", archetype="THE SOLDIER", year_first_seen=1991, persona="&soldier", palette="dana",
   ability="&dead_eye", reload_mult=0.6,
   bio="Barstow PD. First on the scene at the Sunset Palms. Hasn't slept right since.",
   strengths="Marks targets, fastest reloads.", weaknesses="Hesitates before melee kills."),
 "wes": dict(display_name="Wes Coyle", archetype="THE COWBOY", year_first_seen=1992, persona="&cowboy", palette="wes",
   ability="&long_shadow",
   bio="Ex-wildfire hotshot crew. Hitchhikes Route 58 with a rifle case and a lighter he never uses. Mostly never.",
   strengths="Sees enemies through walls. Precision rifles.", weaknesses="Hates close quarters."),
 "tilly": dict(display_name="Tilly Park", archetype="THE FOOL", year_first_seen=1990, persona="&fool", palette="tilly",
   move_speed=160.0, ability="&continue",
   bio="Seventeen. Holds the high score on every cabinet in the Galaxy Palace. Talks to the machines.",
   strengths="Hacks cameras and doors. One free CONTINUE per level.", weaknesses="Fragile, weak melee."),
 "bobby": dict(display_name="Bobby Sunshine", archetype="THE DOG", year_first_seen=1992, persona="&dog", palette="bobby",
   move_speed=165.0, ability="&frenzy",
   bio="Surfed Rincon in '79. Hasn't come back up since. Hears a dog barking nobody else hears.",
   strengths="Berserk frenzy, huge melee.", weaknesses="Can't stop once he starts."),
 "nadia": dict(display_name="Nadia Vasquez", archetype="THE ANGEL", year_first_seen=1991, persona="&angel", palette="nadia",
   move_speed=170.0, dash_cooldown=0.25, ability="&shadow_dash",
   bio="ER nurse, night shift, Cedars. Knows exactly how much it takes. Knows exactly who ordered it.",
   strengths="Fastest runner. Dash kills.", weaknesses="Guns jam in her hands (half magazines)."),
 "director": dict(display_name="???", archetype="THE DEVIL", year_first_seen=1987, persona="&devil", palette="director",
   ability="&cut",
   bio="Credited as 'Director' on a film nobody has seen. Please be kind, rewind.",
   strengths="???", weaknesses="???"),
}
for k, p in cast.items():
    write("characters", "CharacterData", C, k, {"id": "&" + k, **p})

P = "res://scripts/systems/persona_data.gd"
personas = {
 "star": dict(display_name="THE STAR", look="A gold five-point star painted over one eye, stage makeup cracking at the edges.",
   description="You're the lead. The camera loves you. Everybody else is an extra.",
   rule_change="Combo window +0.6s. SPOTLIGHT charges 25% faster.", combo_window_bonus=0.6, ability_charge_mult=1.25),
 "saint": dict(display_name="THE SAINT", look="White clerical collar, halo of gaffer tape on a hockey helmet.",
   description="Every blow is a blessing.", rule_change="Unarmed punches are lethal."),
 "ghost": dict(display_name="THE GHOST", look="Bedsheet hood with two burned eyeholes.", description="You were never here.",
   rule_change="Silent footsteps; enemies see 40% less far."),
 "king": dict(display_name="THE KING", look="Plastic Burger-joint crown, rhinestone sunglasses.",
   description="Heavy is the head.", rule_change="Score x2, but the first hit ends the run."),
 "soldier": dict(display_name="THE SOLDIER", look="Olive drab paint, name tape that reads NOBODY.", description="Orders are orders.",
   rule_change="Absorb one bullet per floor.", extra_hit=True),
 "cowboy": dict(display_name="THE COWBOY", look="Sun-bleached Stetson, bandana over the jaw.", description="High noon, all night.",
   rule_change="First shot after a dash is a guaranteed kill."),
 "angel": dict(display_name="THE ANGEL", look="Surgical mask with painted wings on the cheeks.", description="Mercy is quick.",
   rule_change="Executions are instant."),
 "devil": dict(display_name="THE DEVIL", look="A clapperboard, snapped in half, worn like horns.", description="Cut. Again. From the top.",
   rule_change="???"),
 "fool": dict(display_name="THE FOOL", look="Arcade-token eyes glued to a jester's face paint.", description="Insert coin.",
   rule_change="Remix Mode: every weapon is random."),
 "dog": dict(display_name="THE DOG", look="Chewed-up studded collar, teeth drawn in marker on the lips.", description="Good boy.",
   rule_change="Kills extend the combo window twice as much."),
 "king_hidden": dict(display_name="THE ROYALTY CHEQUE", look="A cheque taped over the face.", description="Residuals.",
   rule_change="Secret."),
}
for k, p in personas.items():
    write("personas", "PersonaData", P, k, {"id": "&" + k, **p})

M = "res://scripts/levels/mission_data.gd"
write("missions", "MissionData", M, "m01_checkout", {
    "id": "&m01_checkout", "title": "CHECKOUT TIME", "location": "Sunset Palms Motel - Barstow, CA",
    "date_text": "JULY 4, 1988", "year": 1988, "chapter": 1, "level_file": "res://levels/m01_sunset_palms.json",
    "music_track": "motel", "boss_track": "boss", "default_character": "&cass", "par_score": 42000, "par_time": 330.0,
    "briefing": "Room service. Checkout is at midnight. Don't forget your key.", "objective_type": "clear"})
print("data written")
