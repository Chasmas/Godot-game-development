"""Procedural mesh kit for the pre-rendered environments (Blender, bpy).

Used by tools/art/build_prerendered_motel.py.  Everything is generated as raw
geometry batched into a few objects per material set, so thousands of small
parts (balusters, leaflets, coping stones...) build in a second instead of the
minutes bpy.ops primitives would take.
"""

import math
import random
import bpy
from mathutils import Vector, Matrix

Z = Vector((0, 0, 1))


def _perp(axis):
    a = Vector((1, 0, 0)) if abs(axis.x) < .9 else Vector((0, 1, 0))
    x = axis.cross(a).normalized()
    return x, axis.cross(x).normalized()


class MB:
    """Mesh builder: accumulates quads/tris with per-face materials."""

    def __init__(self, name):
        self.name = name
        self.v, self.f, self.fm, self.mats = [], [], [], []

    def mi(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def face(self, idx, mat):
        self.f.append(tuple(idx))
        self.fm.append(self.mi(mat))

    def add(self, p):
        self.v.append(Vector(p))
        return len(self.v) - 1

    # -- primitives ---------------------------------------------------------
    def box(self, c, h, mat, rz=0.0, M=None):
        """Box centred at c with half extents h, rotated by rz or basis M."""
        if M is None:
            M = Matrix.Rotation(rz, 3, "Z")
        c = Vector(c)
        base = len(self.v)
        for i in range(8):
            l = Vector(((1 if i & 1 else -1) * h[0], (1 if i & 2 else -1) * h[1], (1 if i & 4 else -1) * h[2]))
            self.v.append(c + M @ l)
        for q in ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)):
            self.face([base + k for k in q], mat)

    def cyl(self, a, b, r, mat, seg=12, r2=None, caps=True):
        a, b = Vector(a), Vector(b)
        axis = (b - a)
        if axis.length < 1e-6:
            return
        axis.normalize()
        x, y = _perp(axis)
        r2 = r if r2 is None else r2
        base = len(self.v)
        for ring, (p, rr) in enumerate(((a, r), (b, r2))):
            for i in range(seg):
                t = i * math.tau / seg
                self.v.append(p + (x * math.cos(t) + y * math.sin(t)) * rr)
        for i in range(seg):
            j = (i + 1) % seg
            self.face((base + i, base + j, base + seg + j, base + seg + i), mat)
        if caps:
            self.face([base + i for i in reversed(range(seg))], mat)
            self.face([base + seg + i for i in range(seg)], mat)

    def tube(self, pts, radii, mat, seg=10, caps=True):
        """Swept tube through pts (list of Vector) with per-point radii."""
        base = len(self.v)
        prev_x = None
        for k, p in enumerate(pts):
            d = (pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]).normalized()
            if prev_x is None:
                x, _ = _perp(d)
            else:
                x = (prev_x - d * prev_x.dot(d)).normalized()
            prev_x = x
            y = d.cross(x)
            for i in range(seg):
                t = i * math.tau / seg
                self.v.append(p + (x * math.cos(t) + y * math.sin(t)) * radii[k])
        for k in range(len(pts) - 1):
            for i in range(seg):
                j = (i + 1) % seg
                a0, a1 = base + k * seg + i, base + k * seg + j
                self.face((a0, a1, a1 + seg, a0 + seg), mat)
        if caps:
            self.face([base + i for i in reversed(range(seg))], mat)
            last = base + (len(pts) - 1) * seg
            self.face([last + i for i in range(seg)], mat)

    def blob(self, c, r, mat, squash=1.0):
        """Octahedron blob (flowers, gravel, leaves at distance)."""
        c = Vector(c)
        b = len(self.v)
        for p in ((r, 0, 0), (-r, 0, 0), (0, r, 0), (0, -r, 0), (0, 0, r * squash), (0, 0, -r * squash)):
            self.v.append(c + Vector(p))
        for q in ((0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (2, 0, 5), (1, 2, 5), (3, 1, 5), (0, 3, 5)):
            self.face([b + k for k in q], mat)

    def strip(self, rows, mat):
        """rows: list of vertex lists of equal length; quads between rows."""
        idx = [[self.add(p) for p in row] for row in rows]
        for k in range(len(idx) - 1):
            for i in range(len(idx[k]) - 1):
                self.face((idx[k][i], idx[k][i + 1], idx[k + 1][i + 1], idx[k + 1][i]), mat)

    def disc(self, c, r, mat, seg=24, normal=Z, r_in=0.0):
        c = Vector(c)
        x, y = _perp(Vector(normal))
        if r_in <= 0:
            b = self.add(c)
            ring = [self.add(c + (x * math.cos(t) + y * math.sin(t)) * r) for t in (i * math.tau / seg for i in range(seg))]
            for i in range(seg):
                self.face((b, ring[i], ring[(i + 1) % seg]), mat)
        else:
            rows = [[c + (x * math.cos(t) + y * math.sin(t)) * rr for t in (i * math.tau / seg for i in range(seg + 1))] for rr in (r_in, r)]
            self.strip(rows, mat)

    # -- output -------------------------------------------------------------
    def build(self, smooth=False, bevel=0.0, collection=None):
        if not self.f:
            return None
        me = bpy.data.meshes.new(self.name)
        me.from_pydata([tuple(v) for v in self.v], [], self.f)
        for m in self.mats:
            me.materials.append(m)
        me.polygons.foreach_set("material_index", self.fm)
        me.polygons.foreach_set("use_smooth", [smooth] * len(self.f))
        me.update()
        ob = bpy.data.objects.new(self.name, me)
        (collection or bpy.context.collection).objects.link(ob)
        if bevel:
            mod = ob.modifiers.new("Bevel", "BEVEL")
            mod.width, mod.segments, mod.limit_method = bevel, 1, "ANGLE"
            mod.harden_normals = False
        return ob


class Frame:
    """Local wall frame: s along the wall, d out of the wall, z up."""

    def __init__(self, origin, u, n):
        self.o, self.u, self.n = Vector(origin), Vector(u).normalized(), Vector(n).normalized()
        self.M = Matrix((self.u, self.n, Z)).transposed()

    def p(self, s, d, z):
        return self.o + self.u * s + self.n * d + Z * z

    def box(self, mb, s, d, z, hs, hd, hz, mat):
        mb.box(self.p(s, d, z), (hs, hd, hz), mat, M=self.M)


# -- vegetation -----------------------------------------------------------------

def palm(mb, base, height, mats, seed=0, lean=(0.0, 0.0), fronds=18, spread=1.0):
    """Ringed tapering trunk with a curved crown of pinnate fronds.

    mats: dict with trunk, ring, frond (list of greens), dead, nut."""
    rnd = random.Random(seed)
    base = Vector(base)
    top = base + Vector((lean[0], lean[1], height))
    bend = Vector((lean[0], lean[1], 0)) * .35
    pts, radii = [], []
    n = int(height / .05)
    for k in range(n + 1):
        t = k / n
        p = base.lerp(top, t) + bend * math.sin(math.pi * t)
        p.z = base.z + height * t
        r = .30 * (1 - t) + .19 * t + .16 * math.exp(-t * 14)
        z = height * t
        ridge = max(0.0, math.cos(math.tau * z / .24)) ** 6
        r *= 1 + .085 * ridge
        pts.append(p)
        radii.append(r)
    mb.tube(pts, radii, mats["trunk"], seg=12)
    # leaf-boot of old frond bases and a coconut cluster below the crown
    for i in range(14):
        a = i * math.tau / 14 + rnd.uniform(-.2, .2)
        d = Vector((math.cos(a), math.sin(a), 0))
        s = top + d * .14 + Vector((0, 0, -.18 - (i % 3) * .1))
        mb.cyl(s, s + d * .45 + Vector((0, 0, .28)), .09, mats["ring"], 6, r2=.035)
    for i in range(7):
        a = i * math.tau / 7 + rnd.uniform(-.3, .3)
        mb.blob(top + Vector((math.cos(a) * .3, math.sin(a) * .3, -.32 + rnd.uniform(-.06, .06))), .14, mats["nut"], 1.1)
    for i in range(fronds):
        a = i * 2.39996 + rnd.uniform(-.15, .15)  # golden angle spiral
        layer = i / fronds
        if i >= fronds - 3:
            e0, droop, L, mat = -.7, 1.3, 1.9 * spread, mats["dead"]
        else:
            e0 = .95 - layer * 1.15 + rnd.uniform(-.1, .1)
            droop = 1.5 + layer * .9 + rnd.uniform(-.2, .2)
            L = (2.2 + layer * 1.1 + rnd.uniform(-.25, .25)) * spread
            mat = mats["frond"][rnd.randrange(len(mats["frond"]))]
        frond(mb, top + Vector((0, 0, .05)), a, e0, droop, L, mat, rnd)


def frond(mb, start, heading, e0, droop, length, mat, rnd, stations=30, leaflet=1.0, width=.1):
    h = Vector((math.cos(heading), math.sin(heading), 0))
    side = Vector((-h.y, h.x, 0))
    p = Vector(start)
    ds = length / stations
    spine = []
    for k in range(stations + 1):
        t = k / stations
        pitch = e0 - droop * t ** 1.4
        fwd = h * math.cos(pitch) + Z * math.sin(pitch)
        spine.append((p.copy(), fwd, t))
        p = p + fwd * ds
    # rachis
    mb.tube([s[0] for s in spine[::3]] + [spine[-1][0]], [.035 * (1 - s[2]) + .008 for s in spine[::3]] + [.006], mat, seg=5, caps=False)
    for (p, fwd, t) in spine[2:]:
        ll = leaflet * length / 3.0 * (math.sin(math.pi * min(1, t * 1.05)) ** .55) * rnd.uniform(.85, 1.1)
        if ll < .05:
            continue
        up = fwd.cross(side).normalized()
        for sg in (-1, 1):
            beta = .35 + .55 * t + rnd.uniform(-.12, .12)
            d1 = (side * sg * math.cos(beta) - up * math.sin(beta) * .6 + fwd * .45).normalized()
            d2 = (side * sg * math.cos(beta + .5) - up * math.sin(beta + .5) + fwd * .5).normalized()
            m = p + d1 * ll * .5
            tip = m + d2 * ll * .5
            w = width * (1.1 - t * .5)
            a0, a1 = p - fwd * w * .5, p + fwd * w * .5
            m0, m1 = m - fwd * w * .45, m + fwd * w * .45
            mb.strip([[a0, a1], [m0, m1], [tip - fwd * .004, tip + fwd * .004]], mat)


def broad_leaf(mb, base, heading, e0, droop, length, width, mat, segs=8, fold=.25):
    """Banana / bird-of-paradise style blade with a raised midrib."""
    h = Vector((math.cos(heading), math.sin(heading), 0))
    side = Vector((-h.y, h.x, 0))
    p = Vector(base)
    ds = length / segs
    rows = []
    for k in range(segs + 1):
        t = k / segs
        pitch = e0 - droop * t * t
        fwd = h * math.cos(pitch) + Z * math.sin(pitch)
        up = fwd.cross(side).normalized()
        w = width * (math.sin(math.pi * min(1, .08 + t * .95)) ** .7) if k else width * .08
        rows.append([p - side * w - up * w * fold, p + up * w * fold * .25, p + side * w - up * w * fold])
        p = p + fwd * ds
    mb.strip(rows, mat)


def tropical_plant(mb, c, size, mats, rnd, leaves=11, flowers=None):
    c = Vector(c)
    for i in range(leaves):
        a = i * 2.39996 + rnd.uniform(-.3, .3)
        L = size * rnd.uniform(.65, 1.05)
        mat = mats[rnd.randrange(len(mats))]
        if rnd.random() < .45:
            frond(mb, c, a, rnd.uniform(.7, 1.2), rnd.uniform(1.4, 2.1), L * 1.1, mat, rnd, stations=12, leaflet=1.2, width=.05)
        else:
            broad_leaf(mb, c + Vector((0, 0, rnd.uniform(0, .1))), a, rnd.uniform(.7, 1.25), rnd.uniform(1.1, 1.9), L, L * rnd.uniform(.13, .2), mat)
    if flowers:
        for i in range(rnd.randint(3, 7)):
            a = rnd.uniform(0, math.tau)
            r = rnd.uniform(.1, size * .5)
            mb.blob(c + Vector((math.cos(a) * r, math.sin(a) * r, size * rnd.uniform(.35, .7))), .07, flowers, 1.0)


def bougainvillea(mb, pts, mats, rnd, density=40, spread=.35):
    """Clusters of magenta bracts + leaves following a path of anchor points."""
    for k in range(len(pts) - 1):
        a, b = Vector(pts[k]), Vector(pts[k + 1])
        for i in range(density):
            p = a.lerp(b, rnd.random()) + Vector((rnd.gauss(0, spread), rnd.gauss(0, spread), rnd.gauss(0, spread * .8)))
            p.z = max(p.z, .12)
            mat = mats["flower"] if rnd.random() < .55 else mats["leaf"]
            mb.blob(p, rnd.uniform(.05, .1), mat, rnd.uniform(.6, 1.2))
