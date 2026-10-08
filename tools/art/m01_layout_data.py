"""Blender-side equivalent of LevelBuilder floor inheritance (original glyphs)."""
FLOORS = '.,_:="~;+-'


def floor_grid(rows):
    width = max(map(len, rows))
    height = len(rows)
    def char(x, y):
        return rows[y][x] if 0 <= y < height and 0 <= x < len(rows[y]) else '#'
    result = []
    for y in range(height):
        row = []
        for x in range(width):
            glyph = char(x, y)
            if glyph in FLOORS:
                row.append(glyph)
                continue
            if glyph in '# ':
                row.append('')
                continue
            if glyph == '*' and (char(x-1,y)=='~' or char(x+1,y)=='~') and (char(x,y-1)=='~' or char(x,y+1)=='~'):
                row.append('~')
                continue
            inherited = ','
            found = False
            for distance in range(1,4):
                for dx,dy in ((-distance,0),(distance,0),(0,-distance),(0,distance)):
                    nx,ny = x+dx,y+dy
                    if 0 <= nx < width and 0 <= ny < height:
                        candidate = char(nx,ny)
                        if candidate in FLOORS and candidate != '~':
                            inherited = candidate
                            found = True
                            break
                if found:
                    break
            row.append(inherited)
        result.append(row)
    return result
