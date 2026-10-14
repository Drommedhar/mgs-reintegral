"""Original menu glyph metrics from menu/radio.c, independent of raster packets."""

SPECIALS = tuple(zip(".@:_!?+-/*{}", (2, 2, 2, 4, 2, 6, 6, 6, 6, 6, 3, 3)))


def glyph(x, y, width, height, advance, offset=0):
    return {"rect": [x, y, width, height], "advance": advance, "offset": offset}


def menu_font(large: bool, texture: str, size: tuple[int, int]) -> dict:
    width, height = (8, 6) if large else (6, 5)
    if size != ((216, 12) if large else (256, 10)):
        raise ValueError("Menu font atlas dimensions do not match native glyph metrics")
    normal = 9 if large else 6
    letters_y, numbers_y = (0, 6) if large else (5, 0)
    glyphs = {"32": glyph(0, 0, 0, 0, 4)}
    for index in range(26):
        narrow = index == ord("i") - ord("a")
        advance = (5 if large else 4) if narrow else normal
        entry = glyph(index * width, letters_y, width, height, advance, int(narrow))
        for base in (ord("a"), ord("A")):
            glyphs[str(base + index)] = entry
    for index in range(10):
        glyphs[str(ord("0") + index)] = glyph(
            index * width, numbers_y, width, height, normal
        )
    for index, (character, skip) in enumerate(SPECIALS):
        offset = int(skip < 3)
        advance = skip + offset * 2
        if large and skip == 6:
            advance = 9
        glyphs[str(ord(character))] = glyph(
            (10 + index) * width, numbers_y, width, height, advance, offset
        )
    return {
        "schema": 1,
        "texture": texture,
        "size": list(size),
        "height": height,
        "line_height": 8,
        "glyphs": glyphs,
    }
