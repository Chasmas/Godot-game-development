"""Authored seating geometry following the M01 ImageGen room direction."""
import math
import bpy


def armchair(x, y, rot, upholstery, wood, seam_material=None):
    root = bpy.data.objects.new('M01 upholstered armchair', None)
    bpy.context.collection.objects.link(root)
    root.location = (x, y, 0)
    root.rotation_euler.z = rot
    parts = []

    def cushion(name, location, dimensions, radius, tilt=0):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
        obj = bpy.context.object
        obj.name = name
        obj.parent = root
        obj.location = location
        obj.dimensions = dimensions
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        obj.rotation_euler.x = tilt
        obj.data.materials.append(upholstery)
        bevel = obj.modifiers.new('Soft upholstered edges', 'BEVEL')
        bevel.width = radius
        bevel.segments = 5
        bevel.affect = 'EDGES'
        obj.modifiers.new('Weighted upholstery normals', 'WEIGHTED_NORMAL')
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
        parts.append(obj)
        return obj

    cushion('Armchair lower upholstered shell', (0, .015, .31), (.68, .65, .18), .07)
    cushion('Armchair separate seat cushion', (0, -.045, .43), (.54, .53, .13), .055)
    cushion('Armchair inclined back shell', (0, .255, .66), (.65, .16, .52), .075, math.radians(-8))
    cushion('Armchair padded back insert', (0, .15, .68), (.50, .10, .35), .045, math.radians(-8))
    for side in (-1, 1):
        cushion('Armchair padded arm', (side * .30, -.015, .54), (.13, .61, .19), .055)
        for end in (-1, 1):
            bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=.026,
                radius2=.036, depth=.23)
            leg = bpy.context.object
            leg.name = 'Armchair tapered walnut leg'
            leg.parent = root
            leg.location = (side * .265, end * .24, .16)
            leg.rotation_euler = (end * .055, -side * .055, 0)
            leg.data.materials.append(wood)
            parts.append(leg)
    # Upholstery piping remains geometry so it survives changes of camera/light.
    curve = bpy.data.curves.new('Armchair seat piping', 'CURVE')
    curve.dimensions = '3D'
    curve.bevel_depth = .003
    curve.bevel_resolution = 2
    spline = curve.splines.new('POLY')
    points = []
    for cx, cy, start in ((.22, .17, 0), (-.22, .17, 90),
                          (-.22, -.26, 180), (.22, -.26, 270)):
        for step in range(7):
            angle = math.radians(start + step * 15)
            points.append((cx + .045 * math.cos(angle), cy + .045 * math.sin(angle), .465, 1))
    spline.points.add(len(points) - 1)
    for point, position in zip(spline.points, points):
        point.co = position
    spline.use_cyclic_u = True
    piping = bpy.data.objects.new('Armchair stitched seat piping', curve)
    bpy.context.collection.objects.link(piping)
    piping.parent = root
    curve.materials.append(seam_material or wood)
    root['imagegen_reference'] = 'assets/art/materials/m01/batch_v1/guest_room_direction.png'
    root['runtime_approved'] = False
    return root
