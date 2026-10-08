extends RefCounted
## Authored cut meshes share GPU geometry while each corpse keeps its own skeleton.
const CUTS: Dictionary = {
  "bellhop/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/bellhop_head_0.res"
    ]
  ],
  "bellhop/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/bellhop_arm_0.res"
    ]
  ],
  "bellhop/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/bellhop_leg_0.res"
    ]
  ],
  "bellhop/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/bellhop_legs_0.res"
    ]
  ],
  "biker/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/biker_head_0.res"
    ]
  ],
  "biker/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/biker_arm_0.res"
    ]
  ],
  "biker/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/biker_leg_0.res"
    ]
  ],
  "biker/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/biker_legs_0.res"
    ]
  ],
  "boss/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/boss_head_0.res"
    ]
  ],
  "boss/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/boss_arm_0.res"
    ]
  ],
  "boss/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/boss_leg_0.res"
    ]
  ],
  "boss/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/boss_legs_0.res"
    ]
  ],
  "buck/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/buck_head_0.res"
    ]
  ],
  "buck/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/buck_arm_0.res"
    ]
  ],
  "buck/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/buck_leg_0.res"
    ]
  ],
  "buck/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/buck_legs_0.res"
    ]
  ],
  "burnt/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/burnt_head_0.res"
    ]
  ],
  "burnt/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/burnt_arm_0.res"
    ]
  ],
  "burnt/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/burnt_leg_0.res"
    ]
  ],
  "burnt/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/burnt_legs_0.res"
    ]
  ],
  "cass/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/cass_head_0.res"
    ]
  ],
  "cass/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/cass_arm_0.res"
    ]
  ],
  "cass/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/cass_leg_0.res"
    ]
  ],
  "cass/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/cass_legs_0.res"
    ]
  ],
  "civilian/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/civilian_head_0.res"
    ]
  ],
  "civilian/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/civilian_arm_0.res"
    ]
  ],
  "civilian/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/civilian_leg_0.res"
    ]
  ],
  "civilian/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/civilian_legs_0.res"
    ]
  ],
  "cultist/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/cultist_head_0.res"
    ]
  ],
  "cultist/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/cultist_arm_0.res"
    ]
  ],
  "cultist/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/cultist_leg_0.res"
    ]
  ],
  "cultist/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/cultist_legs_0.res"
    ]
  ],
  "demon/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/demon_head_0.res"
    ]
  ],
  "demon/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/demon_arm_0.res"
    ]
  ],
  "demon/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/demon_leg_0.res"
    ]
  ],
  "demon/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/demon_legs_0.res"
    ]
  ],
  "fireman/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/fireman_head_0.res"
    ]
  ],
  "fireman/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/fireman_arm_0.res"
    ]
  ],
  "fireman/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/fireman_leg_0.res"
    ]
  ],
  "fireman/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/fireman_legs_0.res"
    ]
  ],
  "ghoul/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/ghoul_head_0.res"
    ]
  ],
  "ghoul/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/ghoul_arm_0.res"
    ]
  ],
  "ghoul/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/ghoul_leg_0.res"
    ]
  ],
  "ghoul/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/ghoul_legs_0.res"
    ]
  ],
  "guard/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/guard_head_0.res"
    ]
  ],
  "guard/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/guard_arm_0.res"
    ]
  ],
  "guard/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/guard_leg_0.res"
    ]
  ],
  "guard/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/guard_legs_0.res"
    ]
  ],
  "gunner/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/gunner_head_0.res"
    ]
  ],
  "gunner/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/gunner_arm_0.res"
    ]
  ],
  "gunner/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/gunner_leg_0.res"
    ]
  ],
  "gunner/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/gunner_legs_0.res"
    ]
  ],
  "handler/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/handler_head_0.res"
    ]
  ],
  "handler/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/handler_arm_0.res"
    ]
  ],
  "handler/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/handler_leg_0.res"
    ]
  ],
  "handler/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/handler_legs_0.res"
    ]
  ],
  "heavy/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/heavy_head_0.res"
    ]
  ],
  "heavy/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/heavy_arm_0.res"
    ]
  ],
  "heavy/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/heavy_leg_0.res"
    ]
  ],
  "heavy/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/heavy_legs_0.res"
    ]
  ],
  "hunter/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/hunter_head_0.res"
    ]
  ],
  "hunter/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/hunter_arm_0.res"
    ]
  ],
  "hunter/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/hunter_leg_0.res"
    ]
  ],
  "hunter/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/hunter_legs_0.res"
    ]
  ],
  "riot/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/riot_head_0.res"
    ]
  ],
  "riot/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/riot_arm_0.res"
    ]
  ],
  "riot/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/riot_leg_0.res"
    ]
  ],
  "riot/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/riot_legs_0.res"
    ]
  ],
  "scout/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/scout_head_0.res"
    ]
  ],
  "scout/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/scout_arm_0.res"
    ]
  ],
  "scout/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/scout_leg_0.res"
    ]
  ],
  "scout/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/scout_legs_0.res"
    ]
  ],
  "scrapper/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/scrapper_head_0.res"
    ]
  ],
  "scrapper/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/scrapper_arm_0.res"
    ]
  ],
  "scrapper/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/scrapper_leg_0.res"
    ]
  ],
  "scrapper/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/scrapper_legs_0.res"
    ]
  ],
  "security/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/security_head_0.res"
    ]
  ],
  "security/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/security_arm_0.res"
    ]
  ],
  "security/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/security_leg_0.res"
    ]
  ],
  "security/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/security_legs_0.res"
    ]
  ],
  "sniper/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/sniper_head_0.res"
    ]
  ],
  "sniper/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/sniper_arm_0.res"
    ]
  ],
  "sniper/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/sniper_leg_0.res"
    ]
  ],
  "sniper/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/sniper_legs_0.res"
    ]
  ],
  "stagehand/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/stagehand_head_0.res"
    ]
  ],
  "stagehand/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/stagehand_arm_0.res"
    ]
  ],
  "stagehand/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/stagehand_leg_0.res"
    ]
  ],
  "stagehand/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/stagehand_legs_0.res"
    ]
  ],
  "welder/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/welder_head_0.res"
    ]
  ],
  "welder/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/welder_arm_0.res"
    ]
  ],
  "welder/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/welder_leg_0.res"
    ]
  ],
  "welder/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/welder_legs_0.res"
    ]
  ],
  "zombie/head": [
    [
      "char1",
      "res://assets/art/gore_meshes/zombie_head_0.res"
    ]
  ],
  "zombie/arm": [
    [
      "char1",
      "res://assets/art/gore_meshes/zombie_arm_0.res"
    ]
  ],
  "zombie/leg": [
    [
      "char1",
      "res://assets/art/gore_meshes/zombie_leg_0.res"
    ]
  ],
  "zombie/legs": [
    [
      "char1",
      "res://assets/art/gore_meshes/zombie_legs_0.res"
    ]
  ]
}
static var _warm: Dictionary = {}

static func prefetch(looks: Array) -> void:
 _warm.clear()
 if Gore.level()<2: return
 var bases: Dictionary = {"cass":true}
 for look in looks: bases[SpriteForge.base_name(str(look))]=true
 for key in CUTS:
  if not bases.has(str(key).get_slice("/",0)): continue
  for item in CUTS[key]:
   if not _warm.has(item[1]) and ResourceLoader.exists(item[1]):
    _warm[item[1]]=ResourceLoader.load(item[1])

static func apply(model,part: String) -> int:
 var key: String = model._look_id+"/"+part
 if not CUTS.has(key): return 0
 var prepared: Array = []
 for item in CUTS[key]:
  var source := model._model.find_child(item[0],true,false) as MeshInstance3D
  if source==null or source.skin==null or not ResourceLoader.exists(item[1]): return 0
  var mesh := _warm.get(item[1]) as ArrayMesh
  if mesh==null: mesh=ResourceLoader.load(item[1]) as ArrayMesh
  if mesh==null: return 0
  prepared.append([source,mesh])
 for item in prepared: item[0].mesh=item[1]
 model.set_meta("authored_sever_part",part)
 return 1
