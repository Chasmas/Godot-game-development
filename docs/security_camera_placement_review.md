# Security camera placement review — 2026-10-07

Current runtime evidence: `build/security_coverage_current.log`,
`build/security_coverage_review.json`, `build/security_counterplay_both_current.log`
and nine fresh GPU captures in `build/security_map_review/` (unsuffixed files).
The contact sheet is `placement_current_contact.png`.

## Observed placement

| Map / authored cell | Actual purpose visible in the capture | Remaining verification |
| --- | --- | --- |
| M01 (18,32) | Corridor outside guest rooms; wall mounted, watches the walking lane. | Full encounter timing with active guards. |
| M01 (40,32) | Second guest corridor near the lobby approach. | Full encounter timing with active guards. |
| M01 (65,27) | Reception corner overlooking the lobby and counter approach. | Approach routes from both entrances. |
| M02 (30,7), moved from (1,1) | Wall above the main warehouse door; sweeps across the entry walking lanes. | Traversal timing with active guards and other warehouse entrance. |
| M02 (30,20) | Exterior boundary looking into the salvage yard. | Patrol interactions and readable warning amid yard lighting. |
| M02 (47,1) | Kennel-side interior corner looking across the room. | Doors, dog patrols and furniture occlusion during play. |
| M03 (21,1) | Narrow stage-side entry corridor. | Moving patrol timing and alternate route. |
| M03 (68,25) | Office corridor with room entrances. | Corridor traversal in both directions. |
| M03 (1,22) | Warehouse corner overlooking stored equipment. | Useful coverage from actual warehouse entrances. |

M04 has no security cameras in its current authored list. Its film cameras are
separate destructible objectives, not surveillance devices; they are outside
this review.

## Verified gameplay scope

All nine security cameras have unobstructed visible samples within their real
range. Actual power-zone shutdown and restoration work for each one.
This establishes functioning coverage, not encounter quality.

For both M01 corridor mounts, normal Cass movement crosses at 20 world units
below the mount, in both directions, without triggering an alarm. Each crossing
travels about 105 units; peak detection is below 0.47. Lingering at a visible
point 60 units from each lens triggers its alarm. Actors are frozen in this
fixture, so these checks exclude combat and patrol interference.

## Warehouse entry adjustment

The old M02 warehouse mount at (1,1) had no door approaches within its range.
Moved it to (30,7), against the east wall just above the main door, authored aim
160 degrees. Runtime fitting gives a centre of 195 degrees and a 55-degree
sweep. Real occlusion probes confirm both walking lanes at (440,136) and
(440,152), three tiles inside the entry, are visible during the sweep. The
adjacent doorstep remains within the deliberate blind zone.

`build/security_warehouse_reposition.log` passes all nine cameras, both new lane
checks and power shutdown/restoration. The fresh GPU capture
`build/security_map_review/m02_dog_days_3_warehouse_entry.png` shows the camera
against the wall above the gate without overlapping the doorway. Nine updated
GPU captures completed with exit 0. Guard timing and the other warehouse entry
remain unverified; this is not approval of the whole encounter.

## Active warehouse AI route check

`tools/security_warehouse_encounter_review.tscn` runs two controlled routes with
normal player movement/collisions and active enemy AI. It preserves save data;
Cass uses god mode so death does not truncate the observations. The camera
starts at the sweep edge facing the entry lane, rather than a random phase.

Entering for 0.45 seconds and retreating for 0.45 seconds avoids the alarm;
peak detection reaches 0.895 and Cass returns to (484.96,136). Eight enemies
move during the sample. Entering and waiting triggers the alarm after 0.875
seconds; twelve enemies move. Both checks pass with exit 0 in
`build/security_warehouse_encounter_review.log` and the matching JSON report.

This supports a short reaction window on that route. It does not establish
combat difficulty, enemy response quality, all sweep phases or the secondary
warehouse entrance. Those remain separate checks.

## Actual guard response

`tools/security_warehouse_response_review.tscn` raises the actual relocated
camera's alarm with Cass at (440,136), then moves only the test player away.
The three selected authored guards remain active for eight seconds. All reach
within 24 units of their initial investigation goal and transition from
INVESTIGATE to SEARCH. Their nearest observed distances are 1.88, 10.43 and
7.52 units. The responder starting at (552,136) crosses from the adjacent room
through the main doorway. None remains blocked on the tested route.

Evidence: `build/security_warehouse_response_review.log` and matching JSON;
exit 0, three responders. Their goals retain the existing uncertain report
position behavior; they are not required to converge on Cass's exact position.
This checks navigation after a directly raised camera alarm, not every possible
natural alarm timing or combat situation.

## Active studio corridor reaction window

The actual stage-side camera at (338,18) was tested with normal Cass movement,
real collisions and active enemy AI in `tools/security_studio_encounter_review.tscn`.
From (354,40), moving right for 0.25 seconds and immediately returning left for
0.25 seconds reaches the under-lens blind zone at (357.04,40). Detection peaks
at 0.567 and no alarm occurs; six enemies move during the observation. Entering
without retreat triggers an alarm after 0.8 seconds, with nine moving enemies.
Both checks pass, including actual exposure before retreat and a final distance
within the lens blind radius. Evidence: `build/security_studio_encounter_review.log`
and its JSON report. No production placement or detection timing was changed.

A shorter retreat ending at (361,40) remains outside the blind radius and raises
an alarm; stopping nearby does not count as hiding. These checks cover this
fixed initial sweep and two controlled routes, with god mode preventing death
from truncating the observation. They do not approve all corridor approaches,
combat balance or alternate routes.
## Main warehouse entrance across sweep phases

The actual M02 main entrance was checked at four initial sweep phases (0, .25, .5, .75) with active enemies, normal player collision and god mode. All four 0.45-second entries followed by 0.45-second retreats avoid camera alarms; peak detection ranges from 0 to .895. Remaining inside triggers the alarm in all four samples, at 4.408, 2.783, 1.100 and .875 seconds respectively. Between 14 and 16 enemies move during each nine-second observation.

Evidence: tools/security_warehouse_sweep_review.tscn, build/security_warehouse_sweep_review.log and matching JSON; eight checks, zero failures, exit 0. Player positions vary due to live enemy interactions; this is one sample per phase, not deterministic combat balance approval. Secondary entrance and other encounters remain pending. No production placement or detection settings changed.

## South warehouse door alternative

Actual Cass movement through both south doorway lanes (216 and 232, starting y344) reaches y199.337 after 150 physics frames, with active enemies and normal door pushing. Door swing is observed (.851 and 1.833 radians), not bypassed or forced open. No surveillance meter or camera alarm is triggered in either sample. This entrance is outside the relocated east-wall camera's range and provides a mechanically traversable alternative, with warehouse occupants still present.

Evidence: tools/security_warehouse_south_review.tscn and build/security_warehouse_south_review.log/json; two checks, zero failures, exit 0. God mode prevents death from truncating observation. This does not prove enemy stealth, combat difficulty or routes beyond the sampled entry. No production placement changed.


## Studio entry across sweep phases
Eight actual entry scenarios (retreat/linger at phases 0, .25, .5, .75) pass with active enemies and real collision. Retreat peaks .409-.678 without alarm and reaches the under-lens blind radius; lingering alarms in .725-.900 seconds. Evidence: build/security_studio_sweep_review.log and build/security_studio_encounter_review.json. God mode is used; this does not approve full combat balance or other approaches. Security fixtures now have individual development save paths; the existing SaveManager already isolates tools/headless runs from player progress.
