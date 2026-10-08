# Civilian visual identity

Eight distinct civilian designs are required, with two or three civilians per
ordinary level. M04's dream/dead map is exempt: no default living civilians;
only civilians killed in earlier levels may appear there, conditioned on the
existing `killed_civilian_<id>` story flags. The four already authored civilians need individual models and readable, unarmed
behaviour. They must remain recognizable at native gameplay scale in both lit
and unlit zones; portraits or overhead markers alone are insufficient.

Current evidence: Earl and Rudy use `civilian`; Dolores and Bev use `scout`.
NPC assigns a hashed `civilian#0..3` palette, but CharacterVisual passes only
the base name to CastModel.create. These palette suffixes do not create
different runtime 3D models. Scout is also an enemy look, so using it for
civilians undermines identification.

| Character | Role | Silhouette and clothing |
| --- | --- | --- |
| Dolores | Motel housekeeper | Short, sturdy, grey bun; mint work dress, ivory apron, practical shoes, waist keys |
| Earl | Motel guest | Stocky, balding older man; mustard vacation shirt, brown trousers, slippers |
| Bev | Studio makeup artist | Tall, slim, curly hair; dusty rose blouse, flared blue jeans, soft makeup-brush pouch |
| Rudy | Production assistant | Lanky young man, glasses; pale blue striped polo, loose tan trousers, sneakers |
| Marlene | Motel guest | Petite woman; cream cardigan, teal dress, soft shoulder bag, sandals |
| Walter | Maintenance worker | Tall older man, grey moustache; ochre work shirt, blue dungarees, pocket rag |
| Joan | Costume seamstress | Shorter older woman, grey bob, glasses; purple blouse, beige skirt, soft measuring tape |
| Miguel | Delivery driver | Broad middle-aged man; salmon polo, grey trousers, brown loafers |

Current placement count is two in M01 and two in M03. M02 needs two or three;
M04 has no default population requirement. Additional placements must be reviewed against actual
floor geometry, room purpose, enemy patrols and escape routes before authoring.
Do not add population blindly to satisfy the count. Aim for six to nine
ordinary civilian instances across M01/M02/M03, using the eight designs.
Dream appearances preserve each victim's identity and only appear when the
corresponding prior kill flag is true. Never populate the dream with un-killed
civilians merely to fill space.

Each design has relaxed empty hands, no weapon belt, combat vest or aggressive
ready stance. Civilian locomotion must keep hands clear of weapon-grip poses.
Fear uses retreat/protection gestures, distinct from an enemy attack windup.
Their clothing colours support recognition without requiring colour alone.

Pipeline: review generated design reference, create distinct textured models,
rig and animate in Blender, inspect game-camera renders and native Godot clips,
then replace authored palettes only after approval evidence exists. The current
models remain a temporary fallback; no concept image counts as integrated art.

Acceptance evidence must include four directions per character, idle/walk/run
and fear transitions, hands and feet, actual M01/M03 placement, lights on/off,
and comparison against nearby armed and unarmed enemies. Check geometry,
texture detail, animation continuity, collision placement and readable identity.
Do not make civilians invulnerable or suppress intentional damage to conceal
visual ambiguity. Conversation, panic, story flags and penalties must remain.
