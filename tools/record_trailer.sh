#!/bin/bash
# Records the cold-open trailer (scripts/ui/intro.gd) to an MP4 with its music.
# Needs: Godot 4.4.1, xvfb-run, ffmpeg. Usage: tools/record_trailer.sh [out.mp4]
# Movie Maker runs at a fixed 60 fps, so software GL (llvmpipe) is fine - just slow.
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT="${1:-releases/HOTSHOT_CALIFORNIA_Trailer.mp4}"
RAW="$(mktemp -d)/raw.avi"
# The logo hands off to the title at ~22.2 s; record a bit past it and trim.
xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 \
	--resolution 1920x1080 --write-movie "$RAW" --fixed-fps 60 --quit-after 1380 \
	res://scenes/ui/intro.tscn
ffmpeg -loglevel error -y -i "$RAW" -t 22.2 \
	-vf "fade=t=out:st=21.6:d=0.6,format=yuv420p" -af "afade=t=out:st=21.4:d=0.8" \
	-c:v libx264 -preset slow -crf 23 -tune grain -r 60 -c:a aac -b:a 192k \
	-movflags +faststart "$OUT"
rm -f "$RAW"
echo "$OUT"
