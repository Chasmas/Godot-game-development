#!/usr/bin/env python3
"""Stage readable industrial control props for PixelLab review.

Output is deliberately outside runtime paths until the whole kit passes a
play-scale review: C:/tmp_shots/utility_kit.
"""
import base64, io, json, os, sys, time, urllib.request, urllib.error
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixellab_upgrade_sprites import b64, clear_backdrop, key

OUT = "C:/tmp_shots/utility_kit"
STYLE = ("flat orthographic top-down pixel art game prop lying flush to the floor or wall plane, no visible side faces, 1980s California salvage yard, "
         "highly detailed shading, clean black outline, vivid but readable cyan status lights and amber warning marks, "
         "transparent background, readable at small gameplay scale")
ASSETS = {
 "utility_control_panel": "rectangular industrial electrical control-panel faceplate made of scratched cream steel, three breaker switches, conduit cable entering from the top edge, red emergency stop button and one green status LED; no cabinet depth",
 "fuse_box_on": "compact rectangular fuse-box faceplate made of weathered steel, closed translucent cover, yellow high-voltage warning triangle, three small green indicator LEDs and a single conduit cable; no cabinet depth",
 "fuse_box_off": "open vandalized electrical fuse-box chassis with NO front door, empty rectangular steel rim surrounding a clearly exposed interior, snapped breaker levers, blackened blown ceramic fuse, severed red and blue copper wires dangling outside, scorch marks and shattered inspection glass fragments; unmistakably broken and powerless, no intact cover, no lit indicators, no cabinet depth",
}
def make(asset_id):
    if asset_id not in ASSETS: return "unknown"
    body={"description":f"{ASSETS[asset_id]}, {STYLE}","negative_description":"isometric, front view, background, unreadable text, watermark, character, duplicate object, blurry",
          "image_size":{"width":128,"height":128},"no_background":True,"detail":"highly detailed","shading":"highly detailed shading","outline":"single color black outline","text_guidance_scale":7.0}
    if asset_id == "fuse_box_off" and "--reference" in sys.argv:
        source_path = os.path.join(OUT, "fuse_box_on.png")
        if os.path.exists(source_path):
            source = Image.open(source_path).convert("RGBA")
            body["init_image"] = b64(source.resize((128, 128), Image.Resampling.NEAREST))
            body["init_image_strength"] = 90
    for attempt in range(6):
        request=urllib.request.Request("https://api.pixellab.ai/v2/create-image-pixflux",data=json.dumps(body).encode(),headers={"Authorization":"Bearer "+key(),"Content-Type":"application/json"})
        try:
            response=json.load(urllib.request.urlopen(request,timeout=300)); raw=response["image"]["base64"].split(",")[-1]
            image=clear_backdrop(Image.open(io.BytesIO(base64.b64decode(raw))).convert("RGBA")); os.makedirs(OUT,exist_ok=True)
            image.save(os.path.join(OUT,asset_id+".png")); return "ok"
        except urllib.error.HTTPError as error:
            if error.code==429: time.sleep(20*(attempt+1)); continue
            return f"HTTP {error.code}"
    return "rate limited"
if __name__=="__main__":
    for item in (sys.argv[1:] or ASSETS.keys()): print(item,make(item),flush=True)
