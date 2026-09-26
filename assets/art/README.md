# HOTSHOT CALIFORNIA — Cinematic Art Integration

These files are optional high-resolution art layers. The game will continue to
use the existing procedural backdrops whenever a PNG is absent.

Expected files:

- `assets/art/title/hotshot_title.png`
  - 16:9 main-menu key art.
  - Cass Moreno, gold star, Sunset Palms, Harcourt, July 4 1988 visual identity.

- `assets/art/cutscenes/apartment_1988.png`
  - Van Nuys apartment scene: answering machine, room 204 key, gold greasepaint,
    Tommy Polaroid.

- `assets/art/cutscenes/room_204.png`
  - Sunset Palms room 204 evidence scene: CRT/VCR, damaged stunt footage,
    tapes, Polaroid and motel key.

- `assets/art/cutscenes/harcourt_confrontation.png`
  - Cass and Lyle Harcourt confrontation at the Sunset Palms office.

- `assets/art/cutscenes/news_1988.png`
  - KHSC Channel 9 post-mission news frame.

Recommended source size: 1920x1080 or larger, PNG, sRGB.

The runtime uses `CinematicArt` to detect these files. Do not remove the
procedural `TitleBackdrop`; it is intentionally retained as an animated
fallback and can also sit beneath art for subtle motion.

Generated concept sheets and storyboards belong under
`assets/art/reference/` and are not loaded at runtime.
