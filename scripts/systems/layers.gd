class_name Layers
extends RefCounted
## Physics layer bits (see Project Settings > Layer Names).

const WORLD := 1
const PLAYER := 2
const ENEMY := 4
const DOOR := 8
const LOW := 16       ## tables, counters, broken windows: block walking, not bullets, vaultable by dash
const GLASS := 32     ## intact windows: block walking & bullets (they break), see-through
const PIT := 64       ## pool, holes: block walking only, not vaultable
const PROP := 128     ## solid breakables (vending machines, TVs): block bullets & walking
const DOWNED := 256   ## knocked-down enemies: shootable, not solid

const TILE := 16

const BULLET_MASK := WORLD | PLAYER | ENEMY | DOOR | GLASS | PROP | DOWNED
const SIGHT_MASK := WORLD | DOOR | PROP
const WALK_MASK_PLAYER := WORLD | ENEMY | LOW | GLASS | PIT | PROP
const WALK_MASK_ENEMY := WORLD | PLAYER | ENEMY | LOW | GLASS | PIT | PROP
const THROW_MASK := WORLD | ENEMY | DOOR | GLASS | PROP
