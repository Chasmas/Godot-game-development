#!/usr/bin/env python3
"""Replace the icon images inside a Windows .exe (e.g. a Godot export template)
in place, without rcedit/wine. Each existing icon slot is overwritten with a
PNG-encoded image of the same dimensions (Windows Vista+ reads PNG icons).

usage: pe_icon.py game.exe icon.png
"""
import io, struct, sys
from PIL import Image

def u16(b, o): return struct.unpack_from("<H", b, o)[0]
def u32(b, o): return struct.unpack_from("<I", b, o)[0]

def patch(exe_path, png_path):
    data = bytearray(open(exe_path, "rb").read())
    pe = u32(data, 0x3C)
    assert data[pe:pe + 4] == b"PE\0\0"
    coff = pe + 4
    nsec = u16(data, coff + 2)
    opt_size = u16(data, coff + 16)
    opt = coff + 20
    magic = u16(data, opt)
    dd = opt + (112 if magic == 0x20B else 96)
    rsrc_rva = u32(data, dd + 2 * 8)
    secs = []
    st = opt + opt_size
    for i in range(nsec):
        o = st + i * 40
        secs.append((u32(data, o + 12), u32(data, o + 8), u32(data, o + 20)))  # va, vsize, rawptr
    def rva2off(rva):
        for va, vs, raw in secs:
            if va <= rva < va + vs:
                return raw + rva - va
        raise ValueError("rva %x" % rva)
    base = rva2off(rsrc_rva)

    def entries(dir_off):
        n = u16(data, dir_off + 12) + u16(data, dir_off + 14)
        for i in range(n):
            e = dir_off + 16 + i * 8
            yield u32(data, e), u32(data, e + 4)

    def leaves(type_id):
        out = {}
        for name, off in entries(base):
            if name != type_id or not (off & 0x80000000):
                continue
            for rid, off2 in entries(base + (off & 0x7FFFFFFF)):
                for lang, off3 in entries(base + (off2 & 0x7FFFFFFF)):
                    de = base + off3
                    out[rid] = de   # data entry offset
        return out

    icons = leaves(3)
    groups = leaves(14)
    src = Image.open(png_path).convert("RGBA")
    replaced = 0
    for gid, gde in groups.items():
        goff = rva2off(u32(data, gde))
        count = u16(data, goff + 4)
        for i in range(count):
            e = goff + 6 + i * 14
            w = data[e] or 256
            h = data[e + 1] or 256
            icon_id = u16(data, e + 12)
            if icon_id not in icons:
                continue
            de = icons[icon_id]
            slot = u32(data, de + 4)
            off = rva2off(u32(data, de))
            img = src.resize((w, h), Image.LANCZOS)
            buf = io.BytesIO()
            img.save(buf, "PNG", optimize=True)
            png = buf.getvalue()
            if len(png) > slot:
                buf = io.BytesIO()
                img.quantize(colors=128, method=Image.FASTOCTREE).convert("RGBA").save(buf, "PNG", optimize=True)
                png = buf.getvalue()
            if len(png) > slot:
                print("  skip %dx%d (slot %d < %d)" % (w, h, slot, len(png)))
                continue
            data[off:off + slot] = png + b"\0" * (slot - len(png))
            struct.pack_into("<I", data, de + 4, len(png))
            struct.pack_into("<HHI", data, e + 4, 1, 32, len(png))
            replaced += 1
            print("  icon %dx%d replaced (%d/%d bytes)" % (w, h, len(png), slot))
    open(exe_path, "wb").write(data)
    print("replaced", replaced, "icon images")

if __name__ == "__main__":
    patch(sys.argv[1], sys.argv[2])
