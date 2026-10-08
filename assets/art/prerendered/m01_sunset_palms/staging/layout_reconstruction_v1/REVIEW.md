# Playable M01 to Blender layout basis

Derived from the current authoritative level JSON, preserving the playable layout. Transform: one 16-pixel Godot cell equals 0.5 metres in Blender; Y is inverted. The layout contract records the input SHA-256, 538 visible wall cells and 122 opening/objective anchors. Zone rectangles and surveillance placements are copied for later validation.

The initial render completed in Blender 5.2.2 and was inspected. It revealed a visual hole in the pool at a pickup glyph. The generator now treats a pickup surrounded by water as basin surface. A second successful render was inspected directly and confirms continuous basin coverage there.

This is a coordinate/layout diagnostic, not final map art. Door/window blocks are placement markers. Floor geometry now uses the actual inherited Godot floor glyphs, with ImageGen carpet, ceramic, deck paving, asphalt and pool tile candidates. No game data, collision or navigation was replaced. The generated blend provides a common basis for detailed architecture, prerender layers, prop anchors and future layout changes.

`tools/m01_floor_parity.tscn` compares the exported Blender floor grid against the actual `LevelBuilder._compute_floors()` implementation. The scene run completed without script errors: 4148 cells, zero mismatches. An earlier standalone `--script` invocation produced autoload dependency compilation errors despite printing parity; that invocation is not accepted as validation. Material seams, native-scale appearance, architectural finishes and runtime occlusion remain pending.

Static architecture and suitable dressing can be pre-rendered. Interactive doors, destructible states, actors and effects need independent render/runtime control. Detailed reconstruction and actor occlusion validation remain pending.

The wall-finish pass adds walnut skirting and cream cutaway caps from the ImageGen trim direction, using reviewed colour sources. Trim stays within each solid wall footprint. The next pass merges 538 wall-cell caps into 97 rectangular sections and the exposed skirting into 193 continuous runs. Assertions verify exact cap cell coverage without overlap or changed footprint. Both renders completed; direct close-up inspection confirms the repeated per-cell seams along straight runs are removed. Junction seams remain, and doors/windows are still diagnostic markers. Reconstruct actual opening frames before judging architectural quality or promoting a runtime layer. No final AAA-quality approval is implied.
