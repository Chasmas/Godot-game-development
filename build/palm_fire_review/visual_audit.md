# M01 palm fire runtime review, 2026-10-07

Actual M01 palm at (40,760), captured by tools/palm_fire_visual_review.tscn.
GPU execution exit 0; original SaveManager snapshot restored. Camera framing
and hidden HUD belong only to the isolated review fixture.

Inspected burning.png and finished.png:

- Finished canopy no longer regrows procedural green fronds. Its leafy
  shadow is removed. Remaining trunk is a plain brown cap: functional state
  confirmation, insufficient final artwork.
- Burning flames are solid triangular wedges with circular particles.
  Reject as final VFX: shape and material do not meet the user's quality bar.
- Flame origin (0,-34)*size sits above the actual crown centre. Needs placement
  based on crown geometry, spreading over the leaves rather than hovering.
- Painted crown stays fully intact until it disappears. Gradual consumption
  of individual fronds is still missing.

Next: authored transparent flame texture/animation, crown-based anchors,
progressive frond damage mirrored in the shadow, textured intact trunk remnant,
and an actual sequence/GIF review. Do not mark this event visually complete.

Subsequent implementation/review:
The generated transparent flame is now loaded by the runtime palm, with
crown-based textured tongues. Painted crown sectors darken and disappear
progressively, and their shadow uses the same sector survival. The trunk is
drawn throughout the burn so faint remaining alpha cannot erase it. Actual
runtime lateburn capture confirms the persistent cap. Lightning terminal
coordinates now hit the crown centre, and the fire light uses that centre.
The existing 4fps GIF predates the final trunk fix. Phase captures manually
advance tree time, while the glow Tween runs at real time; they do not prove
the final light fade timing. Trunk artwork and lightning appearance still
need improvement. These changes do not constitute final VFX approval.

2026-10-07 update: Authored fibrous trunk top promoted to assets/art/vfx/palm_trunk_top_v1.png after actual M01 staged captures. Runtime loads it by default. Fire glow now shares the burn clock and canopy survival, so the earlier Tween timing caveat is resolved. The old GIF remains stale. Lightning artwork and full-rate sequence remain pending.

Lightning update: inspected lightning_000.png and lightning_200.png from actual M01. Fine branched discharge terminates on crown with blue-white local lighting; old opaque impact circles removed. Main pulse, dark gap, return stroke and exponential afterglow replace a flat 100ms flash. Weather/endpoint/light/cleanup review passes 11 checks. Captures prove sampled appearance, not full combined event motion; combined high-rate sequence remains pending.

30fps reference: sequence_30fps contains 391 GPU frames, assembled as combined_event_reference.mp4. No audio; effect clocks manually advanced; weather runs normal render time. This is not a performance benchmark. Frame 180 exposed sector mismatch; fire_anchor now matches painted sector midpoint and crown rotation. Video predates that fix and needs recapture. Embers in textured route and proper crown-based ember origins still pending.

Ember update: production textured-fire route now draws embers, including after the fire. Spawn coordinates follow fire_anchor instead of legacy y=-48..-28 hover positions. Consumed sectors no longer emit. Reviewed current 30fps GPU frames 060 and 180 and assembled combined_event_embers.mp4; silent, manually advanced effect clocks, not a performance benchmark. Flame texture transformation remains limited versus authored animated fire frames; smoke and ash still need work.

Smoke: fine approved wisp reused with neutral tint, bounded six puffs, wind motion and 3s fade. Lifecycle 83 checks pass. 30fps capture initial opacity too subtle, adjusted to 0.4 and lighter neutral tint, reran five-stage GPU review with proper 30Hz simulation steps. Full-rate recapture of final opacity remains pending; no final event approval.

Flame deformation: six connected UV bands preserve anchor while tip turbulence and width oscillate at multiple frequencies. Actual M01 midburn sample inspected, no obvious band seams. Lifecycle passes. Existing MP4 predates deformation; full motion review remains pending. This remains a single authored texture, not a fire spritesheet or fluid simulation.

Latest preview: combined_event_deformed.mp4 and .gif reflect deformation, final smoke tint and no fresh green leaf shedding during fire. GPU sequence exited zero; inspected midburn sample. GIF downsampled to15fps/420px for display; MP4 30fps. No audio; authored clock stepping. Ash and better independent flame shapes still pending.

Charred debris: each sector sheds a small dark fragment once survival falls below0.2. Existing wind/tumbling/ground store controls lifetime and count. Lifecycle88checks pass with30Hz settling simulation; actual GPU finished sample inspected. This is tiny code-native debris, not authored ash texture. Existing GIF does not yet include fragments.
