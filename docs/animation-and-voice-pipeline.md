# Animation and character voice pipeline

Cutscene motion is authored in Blender and exported as numbered PNG frames.
Godot's `FrameSequence` plays those frames at the authored rate and keeps the
current still when a sequence is absent. Portrait folders use the same pattern
and animate the face while text types; the existing procedural blink, mouth,
breathing and eye movement remains the safe fallback.

Character speech is separate from the instrumental soundtrack. Authored voice
files suppress letter babble for the entire dialogue line, including after the
recording ends. Lines without recordings still use the existing fallback.
`tools/audio/eleven_dialogue.py` generates per-line ElevenLabs recordings;
coverage and file audits do not replace listening to the result.

## Gameplay validation

Real-time cast locomotion clips, including armed variants, loop. The controllers
feed post-collision displacement to the visuals; the player's displacement is
converted back to its ability time scale. This prevents stepping against a wall
without changing movement physics. Scripted execution poses are cleared when
their target disappears, and a grab pose is used only when that clip exists.

`tools/locomotion_regression.tscn` checks sustained clip playback.
`tools/smoke_test.tscn` checks M01/M02 interactions, including a blocked-player
animation check and interrupted execution recovery. These are logic checks;
visual quality still requires rendered review. Dogs currently use a static
painted body with stride sway and still need authored limb animation.

Cass's combat clips are authored in `tools/art/render_cast3d.py` with a windup,
torso turn, contact and return to the starting pose. The runtime GLB was baked
at 24 samples per second. Driven clips start without the normal locomotion
crossfade, because the manual seek step would leave that blend unfinished.
Delayed melee contact retains the attack's original aim and weapon, cancelling
the hit if the player changes weapon before contact.

`tools/combat_pose_review.tscn` captures six poses for each punch and swing using
the real Godot renderer. `tools/combat_animation_regression.tscn` checks hand
travel, contact phase and endpoint recovery on the imported Cass model.

Rear-hold clips (`grab`, `held`) are now baked for Cass and the common guard.
The standing pair shares the target's facing, with Cass six world pixels behind
it. A held enemy skips crowd separation and collision recovery so the pair stays
aligned. The target pose follows the executor's progress; player death releases
the surviving target. Other enemy looks still need their held clip baked and
visually checked before claiming the entire cast supports the paired animation.
`tools/execution_pose_review.tscn` captures the pair at six points in the clip.

The common guard now has a Blender-authored `doze` clip. The folding chair is
authored by `tools/blender/build_folding_chair.py`, with its editable source in
`assets/art/Artwork/3d/folding_chair/scene.blend` and runtime GLB in `props3d`.
Its model uses the same camera as the cast; no painted legs are drawn over the
seated 3D body. Smoking activity drives the authored clip with its own phase,
attaches the cigarette to the hand socket, and places smoke/snore effects at the
projected head. Dropping an activity restores the previous weapon visibility.
`tools/idle_pose_review.tscn` captures the guard's activities, and
`tools/idle_activity_regression.tscn` verifies the clip selection, hand attachment,
lowered seated hips and weapon restoration. Other looks still need the updated
activity clips baked and reviewed.

Hunter, handler and security now also use the updated activity/hold bake. Their
candidates were produced by `tools/art/stage_cast_activities.py`, checked for lost
and required clips, rendered in `idle_pose_review`, and passed activity tests
before integration. The audit in `build/cast_activity_candidates/audit.json`
records the review artifacts. The locomotion regression covers these three
looks too and rejects stationary fallbacks for requested movement clips.
When a look lacks sneak, it temporarily uses its walking stride; this prevents
sliding but is not a substitute for a dedicated crouch animation.

Audio shutdown now stops pooled playback and releases its stream references.
The rendered idle review exited without its previous `light_switch.wav` warning;
The duplicate player cigarette effect is suppressed for smoking NPCs. Guard,
hunter, handler and security activity regressions now exit without that warning.
The full M01/M02 smoke passed gameplay checks but still reported `blip.wav` and
`st_aftermath.ogg` references at shutdown. Music player release now explicitly
stops playback and clears streams. The subsequent verbose full M01/M02 smoke
in `build/polish_full_verification.log` completed with zero failures and no leaked
instance or resource-in-use diagnostics. This verifies that run, not every audio
path in the campaign.

## Canine animation audit

`tools/blender/audit_canine.py` imports the existing hellhound into Blender and
produces a source render and mesh report in `build/canine_review`. The inspected
mesh has 18,983 vertices and a textured material, but no armature or vertex groups.
Its supernatural silhouette is suitable only for hellhound. No replacement is
approved until rigging, skinning, paw contact and gameplay camera review pass.
Ordinary dogs still need dedicated animated assets: bobbing a static painting
does not satisfy the requested gait quality.

Leash following now uses `move_and_slide()` and measured displacement. The
dog leash regression verifies wall contact, stopped gait cadence, resumed
following and settling beside the handler. This fixes movement, not the missing
authored paw animation.

## Cass gameplay review — 2026-10-06

Integrated the reviewed Blender Cass rig with a dedicated stab clip. The held
switchblade uses a per-weapon scale correction; pickup size and hit range stay
independent. Combat regression confirms the extension peak at 62% of the clip,
matching the existing knife damage timing, and recovery to the ready pose.
All existing clips survived export; sustained locomotion regression passes.

Player footsteps and stealth noise now follow measured displacement after
collision, in player time. Standing against a wall no longer advances the step
clock or counts as walking for detection. Locked execution clears measured
travel. Disabled input cannot activate sprint. Smoke regression includes blocked
footstep cadence and quiet-state checks. This is a partial gameplay pass; remaining
weapon, roll, interaction and execution feel still needs individual visual review.

Integrated gameplay smoke (`build/cass_gameplay_verification.log`) completed
M01/M02 with zero failures after this pass, including the new wall/footstep checks.

## Roll and combat transitions — 2026-10-06

A dodge now cancels an unlanded melee strike and its visual pose. Actions are
suppressed while rolling, avoiding invisible attacks under the roll animation.
Ending a dodge (including wall contact) also ends the visual roll and restores
weapon visibility; the fallback restores its rig transform and legs.
`build/cass_roll_collision_regression.log` passes wall collision, quiet state,
footstep clock, strike cancellation, synchronized roll exit and interrupted
execution. The first expanded full smoke failed because the new wall-dodge test
left its cooldown active for the next test; reset test stamina/cooldown afterward.
The earlier verbose full smoke ended without resource leaks, so the earlier
shutdown warnings are intermittent and not established as fixed.

Corrected full smoke `build/cass_roll_final_verification.log`: M01/M02 zero
failures, including the new dodge assertions and existing combat/mission checks.
Final targeted pass after fallback pose restoration is recorded separately in
`build/cass_roll_collision_final.log`.

## Reload transitions — 2026-10-06

Dodge cancels reload timing, pending reload weapon and visual held magazine.
Visual cancellation hides the auxiliary arm as well. Weapon refresh clears a
cancelled reload's retained weapon reference. Targeted smoke exercises dodge
cancellation, ammunition conservation, restarting and completing reload, and
swapping weapons mid-reload. Test durations use Engine.physics_ticks_per_second
(the project runs at 120 Hz); the initial 60 Hz assumption tested too early.

## Punch contact and direction review — 2026-10-06

Reviewed the integrated Blender right punch, left punch and melee sequence in
Godot. The punch hand reaches maximum extension at 53% of its 0.2-second clip;
player damage now resolves there (previously 62%). Shared constants keep the
rendered punch duration and contact timing together. Combat regression checks
both fists against this contact, plus recovery, stab contact and other arm clips.
`tools/combat_direction_review.tscn` renders full CharacterVisual instances for
right/left punches and bat contact in eight directions, with weapons and normal
render ordering, and rejects a visible duplicate procedural arm. Captured output:
`build/cass_combat_directions.png`. This is a contact-pose review, not approval of
all movement or every weapon's full motion.
Integrated gameplay smoke after punch-contact adjustment:
`build/cass_combat_contact_smoke.log`, M01/M02 zero failures.

## Music immediate-stop and stage audit — 2026-10-06

Music.stop(0) now clears outgoing crossfade players as well as the current track.
The music transport regression creates a long crossfade, stops immediately,
checks every remaining player is stopped/stream-free, and restarts main-menu
music. `build/music_stop_regression.log` passes.
Latest verbose full smoke `build/shutdown_resource_audit.log` has zero gameplay
failures and no exit leak diagnostics. Earlier nonverbose runs did leak, so the
intermittent shutdown issue remains unproven as resolved.
Blender stage audit now merges records by look instead of losing unrelated
candidates, writes atomically and records SHA-256 of each successful new bake.
Every regenerated candidate still starts with reviewed=false.
Actual Hunter bake verified audit preservation: Cass retained, new Hunter hash
matches its GLB, required/previous clips complete, reviewed=false. Runtime Hunter
was not replaced by this pipeline test.

## Shepherd four-beat walk candidate — 2026-10-06

Authored a distinct Blender walk with quarter-cycle staggered limb phases,
0.32 m stride, 0.065 m recovery lift and 75% stance, lasting 1.2 seconds.
Exported review GLB and rendered in Godot at enlarged and native preview sizes:
`build/canine_review/shepherd/godot_walk_review.png`. Exported bone loop seam
passes. Actual skinned sole measurements use each clip's recorded phases and
stance fraction: walk height variation below 0.000004 m, native-speed world
slip below 0.000001 m. Native pace 0.355556 m/s still needs gameplay calibration.
Runtime remains unchanged: shoulder/chest and hind-chain anatomical deformation
are still unapproved, and run/bite/sleep/death remain unfinished. Preview camera
is an approximation; these measurements are not a final gameplay-scale review.

## Shepherd shoulder trial — 2026-10-06

Compared current high-resolution Blender trot frames against rest. Stronger
axial weight attenuation made a shoulder crease worse and was rejected. Restored
its prior weight attenuation and lowered the front upper-joint origin from 0.27
to 0.15 m, closer to the visible upper-leg/chest join. Rebuilt rig/trot, rendered
four Blender phases and exported/reviewed Godot trot with matching loop seam.
The candidate looks less creased than the rejected trial, but shoulder volume
and hip bend remain provisional. Skinned stance height variation <0.000004 m;
world-slip at native pace <0.000002 m. Runtime unchanged. Previous idle/walk
candidates and motion GIF predate this rig adjustment and require regeneration;
recorded explicitly in review_status.json. Before-trial rig/poses retained in
skin_before_chest_adjustment for comparison and recovery.

## Updated canine idle and walk — 2026-10-06

Rebaked idle/walk on the revised shoulder rig, exported and rendered both in
Godot. Idle has four planted paws throughout, subtle root breathing (2 mm),
neck/head/tail motion and a 2-second closed cycle. Godot bone seam checks pass;
24 idle motion frames saved separately in motion_idle. Motion capture now uses
per-clip directories to avoid overwriting another gait review. Idle actual sole
variation/slip below 0.000001 m. Walk with new rig: stance sole variation below
0.000015 m, native-speed slip below 0.000002 m. These measurements only cover
straight motion/native pace. Runtime remains unapproved; shoulder/hip shape,
all-direction live movement and remaining canine clips still need work.

## Cass speaking frame and voice timing — 2026-10-06

OpenAI built-in image_gen edit produced cass_star_talk.png from reviewed Cass
star base, preserving composition/style and changing mouth/jaw only. Actual
Portrait rest/talk render at 124px passed selection and visual review, recorded
in build/cass_talk_style_review.png. The existing mouth cadence now has an
approved speaking frame for job Cass. This is a two-state mouth approximation,
not phoneme alignment, and blink/other expressions/speakers still need assets.
Dialogue mouth activity now follows recorded voice while text types as well as
after text completes. A stopped recording no longer animates lips just because
text is still typing. Closing or starting another line releases the old stream.
`build/dialogue_voice_timing.log` passes voice-before-text-end, voice-after-text-end
and playback release checks. Generation prompt/provenance appended to
build/cass_portrait_generation.txt.

## Additional ElevenLabs calls — 2026-10-06

Generated the existing authored M03 and M04 call text through ElevenLabs using
the project's configured Rudy/Cass and Tommy/Cass/Dead voices, ten new MP3s.
Godot imported/decoded every node; targeted runtime tests pass voice-vs-text
mouth timing, no automatic advance during a playing recording, and cleanup on
close. Dialogue auto-advance now waits for recorded speech; manual skip remains.
Coverage is 105/178 spoken lines (59.0%), with 73 still lacking recordings.
M02 mother's voice has no configured casting and was not substituted arbitrarily.
Technical decoding is verified; these new performances still need an audible
quality review, not proven by file headers. Nonverbose M03 rapid-switch test
emitted resource exit diagnostics; verbose repeat did not. This intermittent
cleanup issue remains open. Logs: build/call_m03_voice_runtime.log,
call_m04_voice_runtime.log, call_m03_voice_cleanup_trace.log.

## Harcourt dialogue voices and silent pauses — 2026-10-06

Queried the account's available ElevenLabs catalog and selected Bill (old,
American male) for Harcourt, preserving Cass casting. Generated 5 intro and 9
post-fight spoken nodes using exact authored text. Post-fight Harcourt uses lower
stability/higher style than his composed introduction. Imported every recording;
runtime decode/timing tests pass. Audible performance review still outstanding.
Punctuation-only dialogue is now excluded from TTS generation/coverage and stays
silent in runtime: no recorded clip, babble or moving mouth for '...'. Tests cover
Harcourt's choice pause, recorded lips, automatic advance and stream release.
Coverage corrected to words-bearing lines: 112/167 (67.1%), 55 missing. 119 MP3
assets exist; older punctuation-only recordings are not used, so asset totals are
not coverage. Rapid-switch intro test again produced exit resource diagnostics;
the silent-pause test did not. Cleanup issue still open.

## Opening and M02 call voice completion — 2026-10-06

Completed full M01/M02 gameplay smoke after Harcourt/voice-timing changes:
`build/voiced_gameplay_flow.log`, zero failures (movement, combat, dialogue,
mission return, death/restart, results). Generated 17 additional ElevenLabs lines:
4 call_m02, 9 apartment_1988, 4 prologue. Mom uses Matilda, an available American
adult female voice, with restrained stability/style settings; existing casts stay.
Imported and decoded all word-bearing nodes in each new scene. Their targeted
voice timing/auto-advance/silent pause tests pass. Coverage now 129/167 (77.2%),
38 missing, 136 MP3 assets including older unused punctuation clips.
Audible performance review remains outstanding. Prologue targeted test emitted
one exit resource diagnostic; M02/apartment did not. Do not call cleanup fixed.

## Graceful audio shutdown — 2026-10-06

Verbose prologue reproduction identified an active AudioStreamPlaybackWAV retaining
`vhs_static.wav` at immediate SceneTree shutdown. Game.request_quit now stops
Dialogue without emitting story completion, releases Music/current crossfades,
clears pooled Audio streams, freezes scene processing and stops remaining scene
players before waiting for the audio mixer and quitting. The title Quit button
and window-close notification share this path. Scene changes and new Audio/Music
requests are suppressed during shutdown; procedural generator stop clears its stream.

`build/voice_graceful_shutdown.log` and `build/audio_shutdown_regression.log`
passed without leaked-resource diagnostics. The latter starts a recorded prologue
voice, WAV/UI/positional effects and crossfading music, checks stream release,
no story-completion event and no restart after a repeated quit request.
`build/gameplay_graceful_shutdown.log`: complete M01/M02 smoke, zero failures,
no exit warnings in this run. This is verified for these paths, not every possible
platform/device or abrupt process termination.

## Complete current spoken-node coverage — 2026-10-06

Generated 38 missing ElevenLabs recordings for both boss dialogue scenes in M02,
M03 and M04. Buck uses Callum (husky American character voice), Dutch uses Roger
(mature/resonant American), PA uses Brian (deep American), and burnt Tommy retains
Tommy's existing voice identity with altered stability/style. Buck/Dutch post-fight
settings differ from their introductions. Exact authored text remains unchanged;
no music assets or music-generation requests were involved.

Coverage: 167/167 word-bearing non-narration nodes in current dialogue JSONs;
174 MP3 assets including unused old punctuation recordings. Imported all new files.
All six `build/voice_m0*_boss_*_validated.log` targeted runtime checks passed with
zero failures and no exit diagnostics: every spoken node loads/decodes, pauses
remain silent, mouths follow recording playback and auto-advance waits for speech.
These checks do not prove acting quality or word accuracy; listening review remains
required. Portrait mouths remain approximate two-state animation, not phoneme sync.

## Narrative shot restoration and sequence activation — 2026-10-06

The two existing 24-frame Blender previews only move a camera over a still.
Their automatic priority also prevented dialogue shot changes. They now carry
unapproved staging manifests and cannot replace the approved narrative shots.
Cutscene retains the establishing shot and subscribes to node shot changes;
apartment machine/close/return cuts work again. FrameSequence has reviewed-manifest
activation with expected frame count, per-shot identity or whole-scene declaration.
Accepted playback explicitly calls play() after entering the tree. Per-shot
sequence routing is implemented but no authored per-shot film is approved yet;
its positive activation/render case still needs a real reviewed sequence.

`build/cutscene_shot_verbose.log`: zero failures, no exit resource warnings after
changing audio shutdown's grace period to actual wall-clock time. Headless timers
alone could advance ahead of the audio mix thread. `build/cutscene_visual_review.log`
checks the same cuts in OpenGL on the RTX 3060. Captures at 1920x1080 use deterministic
settled transition sampling; machine close rendered and visually inspected in
`build/cutscene_review_machine_close.png`. These are shot-restoration proofs,
not new character animation or a completed cinematic performance.

## Gunner and bellhop activity integration — 2026-10-06

Audited runtime clips: both lacked doze/grab/held. Blender rebuilt candidates from
their own source rigs, preserving every previous clip and adding authored seated,
smoking and hold poses. Inspected six smoking/seated samples for each character
in `build/<look>_idle_review.png`, and six Cass/target hold samples in
`build/<look>_execution_pose_review.png`. The seated silhouettes occupy the folding
chair; cigarettes attach to the rendered hand, without a second procedural prop.
These reviews cover one facing, not a complete directional/lighting audit.

Integrated only gunner/bellhop after clip/hash audit and candidate activity tests.
Previous GLBs are preserved in `build/cast_activity_candidates/<look>_before_<hash>.glb`.
`audit.json` records hashes and reviewed artifacts. Reimported actual runtime files;
post-integration activity tests passed (hips lower by ~0.44–0.45 m, weapon restored
on alert, no stale weapon on unarmed wake). Sustained locomotion regression now
includes both looks and passed all eight looks, including armed movement and
collision-limited stride rates. Walk fallback for absent dedicated sneak remains
an open art requirement. Other cast looks still need these authored activities.

## Activity direction review and heavy/biker — 2026-10-06

Extended idle_pose_review with eight facings at fixed smoking/dozing phases.
Its frozen pose fixture now initializes the lower-body facing as well as the
upper body; leaving the CastModel body interpolation at delta=0 had produced
misleading twisted legs. Re-rendered and inspected guard, gunner and bellhop in
all eight facings, then heavy and biker candidates. Chair orientation and planted
seated body read correctly; cigarettes remain attached to the hand.

Blender rebuilt heavy/biker preserving previous clips, adding doze/grab/held and
updated smoking. Reviewed six temporal samples plus eight directions for each;
reviewed paired Cass hold samples in one facing. Integrated after candidate tests,
hash checks and retained original GLBs. New integration helper requires explicit
render inspection acknowledgement, complete review artifacts, passing activity
log and preserved current runtime clip names; replacement is atomic with a hashed
backup. The helper does not infer artistic quality from files existing.

Actual runtime activity tests passed for both; sustained locomotion regression
now covers ten looks and passed. Dedicated sneak/other unupdated cast clips,
map-lighting review and multi-direction paired holds remain open.

### Grounded chair fall and Cass stamina review � 2026-10-06

`tools/blender/animate_folding_chair.py` authors a 0.6-second chair fall with a rebound and settles it against the floor at each Blender sample. Approved runtime GLB preserves the original upright pose. Godot review measured imported vertices at six phases and three headings; contact deviations stay below 0.004 m. Previous GLB is backed up under `build/chair_tip_review`. Alert regression verifies reparent, unchanged placement, authored clip, final pose, static rendering and no duplicate fallback legs. Cass sprint stamina scales with actual travel, avoiding drain when blocked; targeted movement/roll/reload regression passes. Remaining cinematic, canine and other cast work is not marked complete.

### Committed melee facing � 2026-10-06

Rendered attacks now preserve their starting direction rather than rotating with new aim while damage still follows the captured original direction. Player attack entry synchronizes current aim before taking the visual snapshot, including attacks with no nearby target. Fists, knife and bat were checked across 8 headings after deliberately reversing aim mid-attack; the authored body remains aligned to the committed blow, has no duplicate fallback arm, and roll interrupts it. Godot contact capture: `build/cass_combat_committed_directions.png`. This verifies directional consistency, not final cinematic combat quality.

### Melee trail synchronization � 2026-10-06

Cass trails are driven by attack progress: hidden during the first 22% anticipation, reveal toward 62% contact, then fade during recovery. They follow actor displacement and are invalidated on roll or a replacement attack. The Blender melee clip has one authored swing direction, so its trace no longer alternates against that motion. Immediate set_aim preserves the committed cast orientation. Regression covers fists, knife and bat across eight headings, moving trail origin and cancellation. The existing procedural trail artwork remains a pending visual replacement; synchronization alone does not meet the final effects-art requirement.


### Integrated Blender bat trail - 2026-10-06

Cass bat attacks now use the measured Blender render rather than the procedural SlashFX artwork. The 65 normalized poses across 16 headings are packed into a 1024x1024 transparent atlas without resampling. Per-frame offsets preserve the original 256px canvas, and bounded interpolation fits intermediate directions while anchoring the render at the actual held-weapon tip. The atlas and path data are prewarmed during level setup, before combat.

OpenGL all-heading review verified 1040 frame crops/origins, shared atlas memory, cancellation and contact appearance. Measured texture allocation delta was 5,592,404 bytes; warm direction setup max 0.229ms and trail update p95 0.054ms on this machine. These are isolated CPU/allocation measurements, not a global gameplay frame-rate guarantee. Actual M01 controller review covers light/heavy attacks at four intermediate headings, recovery, swap cancellation, roll cancellation and knife exclusion; full M01/M02 smoke passed with zero failures. Runtime capture: `build/melee_trail_review/measured_dense/packed/runtime_level_contact.png`.

Runtime files: `scripts/player/measured_melee_trail.gd`, bounded fit helper, and `assets/art/blender_fx/melee/bat.png`, `bat.json`, `bat_paths.json`. Blender source generator remains `tools/blender/render_measured_melee_trails.py`; atlas assembly is `tools/art/pack_melee_trails.py`. Knife, punches, other weapons and enemy attack effects still need their corresponding authored render work. This integration does not complete the game's visual-effects requirement.


### Revised Cass stab - 2026-10-06

Blender grip targets now pull back further during preparation and extend farther with a short contact hold. This profile is the Cass bake default so future regeneration retains the reviewed change. The imported hand reaches its measured maximum at phase .62, matching existing damage timing; start/end recovery and no duplicate fallback arms pass. Only the stab animation channel data differs from the previous runtime GLB. The previous model is preserved by hash under build/cass_stab_reach.

Reviewed 65 normalized poses while moving in eight headings, plus actual M01 rendered frames, preparation, contact and recovery. The first level fixture incorrectly checked before the first rendered frame; moving the observation after frame_post_draw resolved that fixture failure. Full M01/M02 smoke after integration: zero failures (runtime_gameplay.log). This is an incremental improvement, not a claim of final cinematic combat quality. A new measured blade path was exported separately as extended_knife_paths_16.json; matching Blender trail rendering remains pending. Earlier rejected knife atlases must not be integrated against the revised animation.

### Integrated revised light knife trail

The revised Cass stab now uses its matching Blender render in gameplay. Sixteen headings and 65 phases are packed without resampling into a 1024x256 RGBA atlas (1 MiB raw). The effect follows the current blade tip and is cancelled by attack serial changes, swapping and rolling. Heavy knife attacks retain their separate fallback pending dedicated artwork.

Godot all-heading staging and actual M01 controller review passed; the latter checks four intermediate headings, recovery, heavy exclusion, swapping and roll cancellation. Full M01/M02 smoke passed with zero failures (`build/melee_trail_review/measured_dense/packed/knife_runtime_gameplay.log`). The actual contact capture was inspected. These checks do not establish final visual quality of every attack or complete character gameplay review.

### Cass firing response review

Same-tick direction changes now orient the visual before calculating the muzzle origin. Close-range shot assistance measures its target direction from that origin, preserving target selection and wall obstruction checks. The four-heading regression reproduced four failures before the orientation change, then passed. A subsequent full smoke exposed and verified the close-range origin correction. Full M01/M02 results: zero failures, `build/cass_shoot_aim_gameplay_fixed.log`. This is functional validation of the exercised controls, not a complete visual or game-feel approval.

### Heavy knife trail candidate

A distinct heavy-cut render now follows measured runtime `melee` trajectories, rather than borrowing the `stab` artwork. Blender generated 1040 transparent frames in `build/melee_trail_review/measured_dense/knife_heavy`; exact crops fit a 1024x256 atlas. The eight-heading moving character pose review, packed sixteen-midpoint-heading playback and real M01 contact/cancellation tests pass after asset import. Contact images were inspected. The candidate remains unapproved pending moving-body shape alignment and animated intermediate-heading review; no production heavy effect was replaced. Source tool now records heavy/light and clip provenance in separate measurement output.

### Heavy knife trail integrated

The measured heavy-knife Blender atlas now has its own runtime effect, separate from the light stab. The level prewarms its 1 MiB raw atlas before combat; bounded interpolation preserves the knife curve between sixteen headings and follows the live tip. Static-table moving-path audit measured at most 1.0859 game px error over .30-.78 with no rejected fit matrices. Moving sixteen-heading Godot captures at swing/contact/recovery were reviewed, followed by fitted M01 contact review. Actual controller tests cover four intermediate headings, light/heavy separation, recovery, swap and roll cancellation: zero failures. Full M01/M02 verification is recorded separately in `build/melee_trail_review/heavy_runtime_gameplay.log`. This integration does not approve every melee weapon, fists or execution animation.

### Isolated Blender punch upgrade

Cass now uses the extended `punch`/`punch_left` animation tracks on the existing runtime rig. `tools/art/isolate_punch_clips.py` verifies matching hierarchy, skin joint order and posed world-space equivalence over 65 samples per clip before copying any animation. Joint world-position error was zero; maximum skin-matrix discrepancy was 0.00001956. Runtime nodes, skins, inverse binds, mesh/material/image descriptors and their original binary data are preserved, as are the other 32 animation clips. The backup and hashes are in `build/cass_punch_isolated/audit.json`.

Both-hand moving eight-heading and M01 contact/recovery tests pass, and contact captures were inspected. Authored punches no longer spawn the old white floor wedge that appeared detached from the fist. Full gameplay verification is recorded in `build/cass_punch_isolated/runtime_gameplay.log`; graphical and functional scope must be reported separately.

Regeneration requires an explicit `--punch-extended` Blender candidate followed by pose-space-verified isolation; copying the complete dense candidate into runtime is prohibited because it changes other tracks. This is a punch animation improvement, not approval of all combat, NPC activity, executions or cutscenes.

### Paired execution facing review (2026-10-06)

Grab/held poses commit aim immediately in physics-facing updates and rendered CastModel playback. This prevents the body rotation from lagging behind the paired placement. The M02 regression starts from opposite face angles and verifies Cass alignment, cancellation of a queued punch and momentum, and successful silent completion. Guard alignment is asserted only for models exposing the authored held clip; remaining variants need animation coverage. Movement/collision/action transition regression and supported M02 regression pass with zero failures; the actual OpenGL eight-heading paired review also passes. These checks do not approve the compact Blender grab anatomy. The corrected projected192pose measurement has a3.409game-pixel maximum forearm-to-neck gap; older10.439px measurements came from a frozen fixture that did not rotate bodies correctly and must not guide pose edits.

### Held NPC pose fitting and weapon ownership

The staged sniper held pose exposed a fixed-height error: wrist targets were higher than the Head joint. The optional Blender --held-tucked profile now measures each model’s Head height and places defending hands12cm below it, solving the elbow pole per sample. The fitted sniper candidate preserves24existingclips, with zero pose-space transfer error; it remains outside runtime pending anatomical silhouette approval. Review scripts must resolve actual case-sensitive bone names (Neck/neck), assert valid indices, skip arrival animation and frame the actors before treating captures as evidence.

Standing executions now hide weapon sprites while retaining Enemy.weapon for its existing death-drop logic; cancellation restores weapon presentation. Execution entry clears the player interaction prompt. Actual M02 regression confirms both changes with zero failures, and an OpenGL candidate review additionally verifies cancellation restores the gun.

### Integrated sniper held pose (2026-10-06)

The held-tucked Blender elbow solver must sample pole_angle in[-PI,PI]. A0..2PI scan silently clamps the second half toPI and misses low elbow orientations. The corrected optional profile samples the legal interval every authored frame and fits wrist height to the actual Head joint. The sniper’s elbows are now below its shoulders, rather than flared level with the face. Only this added held clip was integrated; all24existinganimations and originalgeometry/rig/bind data are unchanged. Eight directions,65sampledposes, actual M02 runtime execution and cancellation were checked; both level review and gameplay smoke finish with zero failures. Complete paired Cass choreography and other NPC animation scopes remain open. The review GIF is build/sniper_held_pole_fixed_isolated/motion/held.gif.

### Guard/heavy coverage and car-exit staging

Guard and heavy held poses now use the corrected legal-range elbow search and skeleton-fitted wrist height. Only held was replaced;26/27otherclips remain exact, with originalmodels backed up. Actual first-level execution/cancellation reviews and the fullM01/M02smoke pass. Long locomotion now checks24nonvehicle runtime looks; this verifies animation continuation/rate, not artwork approval.

The staged --car-exit-smooth Cass clip begins in the same fully seated pose as drive, avoiding the previous1.0-to0.55seat jump. First-pose hips,head,feet,hands match drive within8.1micrometres. It adds anticipation and a progressive rise. Only car_exit is replaced in the isolated candidate;33existinganimations and geometry remain intact. It is not integrated until actual car viewport, foot contacts, door clearance and player handoff are reviewed.
