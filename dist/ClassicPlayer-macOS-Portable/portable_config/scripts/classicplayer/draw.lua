-- Classic Player - ASS drawing primitives and themed widgets.
-- Everything is drawn in real pixels; `s` is the integer UI scale.

local D = {}
D.__index = D

local fmt, floor = string.format, math.floor

local function bgr(c) return c:sub(5, 6) .. c:sub(3, 4) .. c:sub(1, 2) end

local function esc(str)
    str = tostring(str or "")
    str = str:gsub("\\", "\\\239\187\191")
    str = str:gsub("{", "\\{")
    str = str:gsub("}", "\\}")
    str = str:gsub("[\r\n]+", " ")
    str = str:gsub("^ ", "\\h")
    return str
end
D.esc = esc

local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
D.clamp = clamp

local function lerp_color(a, b, t)
    local out = {}
    for i = 1, 5, 2 do
        local ca, cb = tonumber(a:sub(i, i + 1), 16), tonumber(b:sub(i, i + 1), 16)
        out[#out + 1] = fmt("%02X", floor(ca + (cb - ca) * t + 0.5))
    end
    return table.concat(out)
end

-- "&File" -> ASS with underlined accelerator (or plain), plus plain text
function D.accel(label, underline)
    local pre, ch, post = label:match("^(.-)&(.)(.*)$")
    if not pre then return esc(label), label end
    local plain = pre .. ch .. post
    if underline then
        return esc(pre) .. "{\\u1}" .. esc(ch) .. "{\\u0}" .. esc(post), plain
    end
    return esc(plain), plain
end

---------------------------------------------------------------------------
-- Glyphs: vector paths in a 16x16 design box (title glyphs 16x14).
-- Each glyph is a list of {path, "fg"|"bg"} pairs.
---------------------------------------------------------------------------
local function circle(cx, cy, r)
    local k = 0.5523 * r
    return fmt("m %g %g b %g %g %g %g %g %g b %g %g %g %g %g %g b %g %g %g %g %g %g b %g %g %g %g %g %g",
        cx - r, cy,
        cx - r, cy - k, cx - k, cy - r, cx, cy - r,
        cx + k, cy - r, cx + r, cy - k, cx + r, cy,
        cx + r, cy + k, cx + k, cy + r, cx, cy + r,
        cx - k, cy + r, cx - r, cy + k, cx - r, cy)
end

local function grip_paths()
    local sh, li = {}, {}
    for _, k in ipairs({ 11, 7, 3 }) do
        sh[#sh + 1] = fmt("m 12 %g l 12 %g %g 12 %g 12", 12 - k, 12 - k + 1.6, 12 - k + 1.6, 12 - k)
        li[#li + 1] = fmt("m 12 %g l 12 %g %g 12 %g 12", 12 - k - 1, 12 - k, 12 - k, 12 - k - 1)
    end
    return table.concat(sh, " "), table.concat(li, " ")
end
local GRIP_SH, GRIP_LI = grip_paths()

local G = {
    play     = { "m 5 3 l 12 8 5 13", "fg" },
    pause    = { "m 4 3 l 7 3 7 13 4 13 m 9 3 l 12 3 12 13 9 13", "fg" },
    stop     = { "m 4 4 l 12 4 12 12 4 12", "fg" },
    prev     = { "m 3 3 l 5 3 5 13 3 13 m 13 3 l 13 13 6 8", "fg" },
    next     = { "m 11 3 l 13 3 13 13 11 13 m 3 3 l 10 8 3 13", "fg" },
    rew      = { "m 8 3 l 8 13 1 8 m 15 3 l 15 13 8 8", "fg" },
    ff       = { "m 1 3 l 8 8 1 13 m 8 3 l 15 8 8 13", "fg" },
    eject    = { "m 8 3 l 14 9 2 9 m 2 11 l 14 11 14 13 2 13", "fg" },
    camera   = { "m 1 5 l 5 5 6 3 10 3 11 5 15 5 15 13 1 13", "fg",
                 circle(8, 9, 3.2), "bg",
                 circle(8, 9, 1.6), "fg",
                 "m 12 6 l 14 6 14 7 12 7", "bg" },
    subtitle = { "m 1 3 l 15 3 15 13 1 13", "fg",
                 "m 2 4 l 14 4 14 12 2 12", "bg",
                 "m 3 8 l 7 8 7 9 3 9 m 8 8 l 13 8 13 9 8 9 m 3 10 l 10 10 10 11 3 11 m 11 10 l 13 10 13 11 11 11", "fg" },
    contrast = { circle(8, 8, 6.5), "fg",
                 circle(8, 8, 5), "bg",
                 "m 8 3 b 5.24 3 3 5.24 3 8 b 3 10.76 5.24 13 8 13", "fg" },
    fullscreen = { "m 1 1 l 6 1 6 3 3 3 3 6 1 6 m 15 1 l 15 6 13 6 13 3 10 3 10 1 m 1 15 l 1 10 3 10 3 13 6 13 6 15 m 15 15 l 10 15 10 13 13 13 13 10 15 10", "fg" },
    speaker  = { "m 1 6 l 4 6 8 2 8 14 4 10 1 10", "fg",
                 "m 10 6 l 11 6 11 10 10 10 m 12 4 l 13 4 13 12 12 12", "fg" },
    mute     = { "m 1 6 l 4 6 8 2 8 14 4 10 1 10", "fg",
                 "m 10 5 l 11.5 5 15 11 13.5 11 m 13.5 5 l 15 5 11.5 11 10 11", "fg" },
    check    = { "m 3 8 l 5 8 7 10 12 3 14 3 7 13", "fg" },
    bullet   = { circle(8, 8, 2.5), "fg" },
    film     = { "m 1 2 l 15 2 15 14 1 14", "fg",
                 "m 2 3 l 3 3 3 4.5 2 4.5 m 2 6 l 3 6 3 7.5 2 7.5 m 2 9 l 3 9 3 10.5 2 10.5 m 2 12 l 3 12 3 13 2 13", "bg",
                 "m 13 3 l 14 3 14 4.5 13 4.5 m 13 6 l 14 6 14 7.5 13 7.5 m 13 9 l 14 9 14 10.5 13 10.5 m 13 12 l 14 12 14 13 13 13", "bg",
                 "m 4.5 3.5 l 11.5 3.5 11.5 12.5 4.5 12.5", "bg",
                 "m 6.5 5.5 l 10.5 8 6.5 10.5", "fg" },
    grip     = { GRIP_SH, "fg", GRIP_LI, "bg" },
    -- Windows 95/98 caption buttons (16x14 box)
    t_min    = { "m 4 9 l 10 9 10 11 4 11", "fg" },
    t_max    = { "m 3 2 l 12 2 12 11 3 11", "fg", "m 4 4 l 11 4 11 10 4 10", "bg" },
    t_close  = { "m 4 3 l 6 3 8 5 10 3 12 3 9 6.5 12 10 10 10 8 8 6 10 4 10 7 6.5", "fg" },
    -- Windows 3.1 caption arrows
    w_up     = { "m 3 10 l 13 10 8 5", "fg" },
    w_down   = { "m 3 6 l 13 6 8 11", "fg" },
}

---------------------------------------------------------------------------
-- Painter
---------------------------------------------------------------------------
function D.new(measure)
    return setmetatable({ buf = {}, measure = measure, s = 1 }, D)
end

function D:begin(theme, s, font)
    self.buf, self.t, self.c, self.s, self.font = {}, theme, theme.c, s, font
    self.st = theme.style
end

function D:result() return table.concat(self.buf, "\n") end

function D:push(x) self.buf[#self.buf + 1] = x end

function D:rect(x0, y0, x1, y1, col, alpha)
    if x1 <= x0 or y1 <= y0 then return end
    self.buf[#self.buf + 1] = fmt(
        "{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H%s&\\1a&H%s&\\p1}m %d %d l %d %d %d %d %d %d",
        bgr(col), alpha or "00", x0, y0, x1, y0, x1, y1, x0, y1)
end

-- one-unit thick ring; tl = top/left colour, br = bottom/right colour
function D:ring(x0, y0, x1, y1, tl, br)
    local s = self.s
    self:rect(x0, y0, x1 - s, y0 + s, tl)
    self:rect(x0, y0 + s, x0 + s, y1 - s, tl)
    self:rect(x0, y1 - s, x1, y1, br)
    self:rect(x1 - s, y0, x1, y1 - s, br)
end

function D:border(x0, y0, x1, y1, col) self:ring(x0, y0, x1, y1, col, col) end

-- border with cut corners (r in units: 1 = square, 2/3 = rounded)
function D:rborder(x0, y0, x1, y1, col, r)
    local s = self.s
    local R = (r or 1) * s
    self:rect(x0 + R, y0, x1 - R, y0 + s, col)
    self:rect(x0 + R, y1 - s, x1 - R, y1, col)
    self:rect(x0, y0 + R, x0 + s, y1 - R, col)
    self:rect(x1 - s, y0 + R, x1, y1 - R, col)
    for k = 1, (r or 1) - 1 do
        local a, b = x0 + k * s, y0 + (r - k) * s
        self:rect(a, b, a + s, b + s, col)                         -- top-left
        self:rect(x1 - k * s - s, b, x1 - k * s, b + s, col)        -- top-right
        self:rect(a, y1 - (r - k) * s - s, a + s, y1 - (r - k) * s, col)              -- bottom-left
        self:rect(x1 - k * s - s, y1 - (r - k) * s - s, x1 - k * s, y1 - (r - k) * s, col) -- bottom-right
    end
end

-- fill matching rborder's interior
function D:rfill(x0, y0, x1, y1, col, r)
    local s = self.s
    r = r or 1
    for k = 1, r - 1 do
        local inset = (r - k + 1) * s
        self:rect(x0 + inset, y0 + k * s, x1 - inset, y0 + (k + 1) * s, col)
        self:rect(x0 + inset, y1 - (k + 1) * s, x1 - inset, y1 - k * s, col)
    end
    self:rect(x0 + s, y0 + r * s, x1 - s, y1 - r * s, col)
end

function D:text(x, y, an, str, col, size, bold, clip, raw)
    local cl = ""
    if clip then cl = fmt("\\clip(%d,%d,%d,%d)", clip[1], clip[2], clip[3], clip[4]) end
    self.buf[#self.buf + 1] = fmt("{\\an%d\\pos(%d,%d)\\bord0\\shad0\\q2\\fn%s\\fs%d\\b%d\\1c&H%s&%s}%s",
        an, x, y, self.font, floor(size * self.s + 0.5), bold and 1 or 0, bgr(col), cl,
        raw and str or esc(str))
end

function D:glyph(name, x, y, col, bg, k)
    local g = G[name]
    if not g then return end
    local sc = floor((k or 1) * self.s * 100 + 0.5)
    for i = 1, #g, 2 do
        local cc = (g[i + 1] == "bg") and (bg or "000000") or col
        self.buf[#self.buf + 1] = fmt(
            "{\\an7\\pos(%d,%d)\\bord0\\shad0\\fscx%d\\fscy%d\\1c&H%s&\\p1}%s",
            x, y, sc, sc, bgr(cc), g[i])
    end
end

-- glyph embossed (disabled look on Windows themes)
function D:glyph_disabled(name, x, y, bg)
    local c = self.c
    if self.st == "win98" or self.st == "win31" then
        self:glyph(name, x + self.s, y + self.s, c.light, bg)
        self:glyph(name, x, y, c.shadow, bg)
    else
        self:glyph(name, x, y, c.text_dis, bg)
    end
end

---------------------------------------------------------------------------
-- Themed widgets
---------------------------------------------------------------------------

-- push button; returns glyph colour, glyph offset, face colour
function D:button(x0, y0, x1, y1, pressed, on)
    local c, s, st = self.c, self.s, self.st
    local down = pressed or on
    if st == "win98" then
        local face = (on and not pressed) and "E0E0E0" or c.face
        self:rect(x0, y0, x1, y1, face)
        if down then
            self:ring(x0, y0, x1, y1, c.dark, c.light)
            self:ring(x0 + s, y0 + s, x1 - s, y1 - s, c.shadow, c.light2)
        else
            self:ring(x0, y0, x1, y1, c.light, c.dark)
            self:ring(x0 + s, y0 + s, x1 - s, y1 - s, c.light2, c.shadow)
        end
        return c.text, down and s or 0, face
    elseif st == "win31" then
        self:rect(x0 + s, y0 + s, x1 - s, y1 - s, c.face)
        self:rborder(x0, y0, x1, y1, c.dark, 2)
        if down then
            self:rect(x0 + s, y0 + s, x1 - s, y0 + 2 * s, c.shadow)
            self:rect(x0 + s, y0 + 2 * s, x0 + 2 * s, y1 - s, c.shadow)
        else
            self:ring(x0 + s, y0 + s, x1 - s, y1 - s, c.light, c.shadow)
            self:ring(x0 + 2 * s, y0 + 2 * s, x1 - 2 * s, y1 - 2 * s, c.light, c.shadow)
        end
        return c.text, down and s or 0, c.face
    elseif st == "platinum" then
        local face = down and "8C8C8C" or c.face
        self:rfill(x0, y0, x1, y1, face, 2)
        self:rborder(x0, y0, x1, y1, "000000", 2)
        if down then
            self:ring(x0 + s, y0 + s, x1 - s, y1 - s, "666666", "AAAAAA")
        else
            self:ring(x0 + s, y0 + s, x1 - s, y1 - s, c.light, c.shadow)
        end
        return down and "FFFFFF" or c.text, 0, face
    else -- system7
        local face = down and "000000" or "FFFFFF"
        self:rfill(x0, y0, x1, y1, face, 3)
        self:rborder(x0, y0, x1, y1, "000000", 3)
        return down and "FFFFFF" or "000000", 0, face
    end
end

function D:text_button(x0, y0, x1, y1, label, pressed)
    local fg, off = self:button(x0, y0, x1, y1, pressed)
    self:text(floor((x0 + x1) / 2) + off, floor((y0 + y1) / 2) + off, 5, label, fg,
        self.t.font_size, self.t.bold)
end

-- horizontal trackbar. Returns groove start/end x (for hit mapping).
function D:slider(x0, y0, x1, y1, frac, ticks, tw, th, pressed)
    local c, s, st = self.c, self.s, self.st
    tw, th = tw * s, th * s
    local half = floor(tw / 2)
    local gx0, gx1 = x0 + half, x1 - half
    if gx1 <= gx0 then return gx0, gx0 + 1 end
    frac = clamp(frac or 0, 0, 1)
    local cy = ticks and (y0 + floor(th / 2) + 2 * s) or floor((y0 + y1) / 2)
    local cx = gx0 + floor((gx1 - gx0) * frac + 0.5)
    local tx, ty = cx - half, cy - floor(th / 2)

    if st == "win98" then
        local gy = cy - 2 * s
        self:ring(x0, gy, x1, gy + 4 * s, c.shadow, c.light)
        self:ring(x0 + s, gy + s, x1 - s, gy + 3 * s, c.dark, c.light2)
        self:rect(tx, ty, tx + tw, ty + th, c.face)
        self:ring(tx, ty, tx + tw, ty + th, c.light, c.dark)
        self:ring(tx + s, ty + s, tx + tw - s, ty + th - s, c.light2, c.shadow)
    elseif st == "win31" then
        local gy = cy - 3 * s
        self:rect(x0, gy, x1, gy + 6 * s, c.field)
        self:ring(x0, gy, x1, gy + 6 * s, c.shadow, c.light)
        self:border(x0 + s, gy + s, x1 - s, gy + 5 * s, c.dark)
        self:button(tx, ty, tx + tw, ty + th, pressed)
    elseif st == "platinum" then
        local gy = cy - 3 * s
        self:rect(x0, gy, x1, gy + 6 * s, "AAAAAA")
        self:rect(x0 + s, gy + s, cx, gy + 5 * s, c.accent)
        self:ring(x0, gy, x1, gy + 6 * s, "666666", c.light)
        self:button(tx, ty, tx + tw, ty + th, pressed)
        self:rect(cx - s, ty + 3 * s, cx, ty + th - 3 * s, c.shadow)
        self:rect(cx, ty + 3 * s, cx + s, ty + th - 3 * s, c.light)
    else -- system7
        local gy = cy - 3 * s
        self:rect(x0, gy, x1, gy + 6 * s, "FFFFFF")
        self:rect(x0 + s, gy + s, cx, gy + 5 * s, "808080")
        self:border(x0, gy, x1, gy + 6 * s, "000000")
        self:rfill(tx, ty, tx + tw, ty + th, pressed and "000000" or "FFFFFF", 2)
        self:rborder(tx, ty, tx + tw, ty + th, "000000", 2)
    end

    if ticks and (st == "win98" or st == "win31") then
        local yt = ty + th + 2 * s
        for i = 0, 10 do
            local x = gx0 + floor((gx1 - gx0) * i / 10 + 0.5)
            self:rect(x, yt, x + s, yt + ((i % 5 == 0) and 4 or 2) * s, c.dark)
        end
    end
    return gx0, gx1
end

-- outer window frame (rect r, frame thickness f px, title height px)
function D:window_frame(x0, y0, x1, y1, f, title_h)
    local c, s, st = self.c, self.s, self.st
    if f <= 0 then return end
    if st == "win98" then
        self:ring(x0, y0, x1, y1, c.light2, c.dark)
        self:ring(x0 + s, y0 + s, x1 - s, y1 - s, c.light, c.shadow)
    elseif st == "win31" then
        self:rect(x0, y0, x1, y0 + f, c.frame)
        self:rect(x0, y1 - f, x1, y1, c.frame)
        self:rect(x0, y0 + f, x0 + f, y1 - f, c.frame)
        self:rect(x1 - f, y0 + f, x1, y1 - f, c.frame)
        self:border(x0, y0, x1, y1, c.dark)
        self:border(x0 + f - s, y0 + f - s, x1 - f + s, y1 - f + s, c.dark)
        local k = f + title_h
        self:rect(x0, y0 + k, x0 + f, y0 + k + s, c.dark)
        self:rect(x1 - f, y0 + k, x1, y0 + k + s, c.dark)
        self:rect(x0, y1 - k - s, x0 + f, y1 - k, c.dark)
        self:rect(x1 - f, y1 - k - s, x1, y1 - k, c.dark)
        self:rect(x0 + k, y0, x0 + k + s, y0 + f, c.dark)
        self:rect(x1 - k - s, y0, x1 - k, y0 + f, c.dark)
        self:rect(x0 + k, y1 - f, x0 + k + s, y1, c.dark)
        self:rect(x1 - k - s, y1 - f, x1 - k, y1, c.dark)
    elseif st == "platinum" then
        self:border(x0, y0, x1, y1, "000000")
        self:ring(x0 + s, y0 + s, x1 - s, y1 - s, c.light, c.shadow)
        self:ring(x0 + f - s, y0 + f - s, x1 - f + s, y1 - f + s, c.shadow, c.light)
    else
        self:border(x0, y0, x1, y1, "000000")
    end
end

-- small Mac title-bar box (close / zoom / collapse)
function D:mac_box(x, y, b, pressed, kind)
    local c, s, st = self.c, self.s, self.st
    if st == "platinum" then
        self:ring(x, y, x + b, y + b, c.shadow, c.light)
        self:border(x + s, y + s, x + b - s, y + b - s, "000000")
        self:rect(x + 2 * s, y + 2 * s, x + b - 2 * s, y + b - 2 * s, pressed and "777777" or c.face)
        if not pressed then
            self:ring(x + 2 * s, y + 2 * s, x + b - 2 * s, y + b - 2 * s, c.light, c.shadow)
        end
        if kind == "zoom" then
            self:border(x + 2 * s, y + 2 * s, x + b - 4 * s, y + b - 4 * s, "000000")
        elseif kind == "collapse" then
            local my = y + floor(b / 2)
            self:rect(x + 2 * s, my - s, x + b - 2 * s, my, "000000")
            self:rect(x + 2 * s, my + s, x + b - 2 * s, my + 2 * s, "000000")
        end
    else
        self:rect(x - s, y - s, x + b + s, y + b + s, "FFFFFF")
        self:border(x, y, x + b, y + b, "000000")
        if pressed then
            local m = floor(b / 2)
            self:rect(x + m, y + 2 * s, x + m + s, y + b - 2 * s, "000000")
            self:rect(x + 2 * s, y + m, x + b - 2 * s, y + m + s, "000000")
        elseif kind == "zoom" then
            self:border(x, y, x + floor(b * 0.6), y + floor(b * 0.6), "000000")
        elseif kind == "collapse" then
            local my = y + floor(b / 2)
            self:rect(x, my - s, x + b, my, "000000")
            self:rect(x, my + s, x + b, my + 2 * s, "000000")
        end
    end
end

-- caption / title bar. kind = "main" | "dialog". Returns { id = rect }.
function D:title_bar(x0, y0, x1, y1, title, pressed, kind)
    local c, s, st = self.c, self.s, self.st
    local fs = self.t.font_size
    local h = y1 - y0
    local btn = {}

    if st == "win31" then
        self:rect(x0, y0, x1, y1 - s, c.title_bg)
        self:rect(x0, y1 - s, x1, y1, c.dark)
        local bh = h - s
        local bx1 = x0 + bh
        self:rect(x0, y0, bx1, y1 - s, c.face)
        self:rect(bx1, y0, bx1 + s, y1 - s, c.dark)
        local my = y0 + floor(bh / 2) - s
        local p = pressed == "tb:sys"
        self:rect(x0 + 4 * s, my + s, bx1 - 2 * s, my + 4 * s, c.shadow)
        self:rect(x0 + 3 * s, my, bx1 - 3 * s, my + 3 * s, c.dark)
        self:rect(x0 + 4 * s, my + s, bx1 - 4 * s, my + 2 * s, p and c.dark or c.light)
        btn["tb:sys"] = { x0, y0, bx1, y1 - s }
        local rx = x1
        if kind == "main" then
            for _, id in ipairs({ "tb:max", "tb:min" }) do
                local bx0 = rx - bh
                self:rect(bx0 - s, y0, bx0, y1 - s, c.dark)
                local down = pressed == id
                self:rect(bx0, y0, rx, y1 - s, c.face)
                if down then
                    self:rect(bx0, y0, rx, y0 + s, c.shadow)
                    self:rect(bx0, y0, bx0 + s, y1 - s, c.shadow)
                else
                    self:ring(bx0, y0, rx, y1 - s, c.light, c.shadow)
                    self:ring(bx0 + s, y0 + s, rx - s, y1 - 2 * s, c.light, c.shadow)
                end
                local off = down and s or 0
                self:glyph(id == "tb:max" and "w_up" or "w_down",
                    bx0 + floor((bh - 16 * s) / 2) + off, y0 + floor((bh - 16 * s) / 2) + off, c.dark)
                btn[id] = { bx0, y0, rx, y1 - s }
                rx = bx0 - s
            end
        end
        self:text(floor((bx1 + rx) / 2), floor((y0 + y1 - s) / 2), 5, title, c.title_text, fs, true,
            { bx1 + s, y0, rx, y1 })

    elseif st == "win98" then
        local ty1 = y1 - s
        local n, width = 40, x1 - x0
        for i = 0, n - 1 do
            local a = x0 + floor(width * i / n)
            local b = x0 + floor(width * (i + 1) / n)
            self:rect(a, y0, b, ty1, lerp_color(c.title_bg, c.title_bg2, i / (n - 1)))
        end
        self:rect(x0, ty1, x1, y1, c.face)
        local tx = x0 + 3 * s
        if kind == "main" then
            self:glyph("film", x0 + s, y0 + floor((ty1 - y0 - 16 * s) / 2), "FFFFFF", c.title_bg)
            tx = x0 + 20 * s
        end
        local bw, bh = 16 * s, 14 * s
        local by = y0 + floor((ty1 - y0 - bh) / 2)
        local bx = x1 - 2 * s - bw
        btn["tb:close"] = { bx, by, bx + bw, by + bh }
        if kind == "main" then
            local mx = bx - 2 * s - bw
            btn["tb:max"] = { mx, by, mx + bw, by + bh }
            btn["tb:min"] = { mx - bw, by, mx, by + bh }
        end
        local gl = { ["tb:close"] = "t_close", ["tb:max"] = "t_max", ["tb:min"] = "t_min" }
        for id, r in pairs(btn) do
            local fg, off, face = self:button(r[1], r[2], r[3], r[4], pressed == id)
            self:glyph(gl[id], r[1] + off, r[2] + off, fg, face)
        end
        local limit = (btn["tb:min"] or btn["tb:close"])[1] - 2 * s
        self:text(tx, floor((y0 + ty1) / 2), 4, title, c.title_text, fs, true, { x0, y0, limit, ty1 })

    else -- platinum / system7
        local plat = st == "platinum"
        local bg = plat and c.face or "FFFFFF"
        self:rect(x0, y0, x1, y1 - s, bg)
        self:rect(x0, y1 - s, x1, y1, plat and c.shadow or "000000")
        -- pinstripes
        local sx0, sx1 = x0 + (plat and 3 or 1) * s, x1 - (plat and 3 or 1) * s
        local yy = y0 + 4 * s
        while yy + 2 * s <= y1 - 3 * s do
            if plat then
                self:rect(sx0, yy, sx1, yy + s, c.light)
                self:rect(sx0, yy + s, sx1, yy + 2 * s, c.shadow)
            else
                self:rect(sx0, yy, sx1, yy + s, "000000")
            end
            yy = yy + 2 * s
        end
        local b = 11 * s
        local by = y0 + floor((h - s - b) / 2)
        local cx = x0 + 8 * s
        self:rect(cx - 2 * s, y0 + 2 * s, cx + b + 2 * s, y1 - 2 * s, bg)
        self:mac_box(cx, by, b, pressed == "tb:close", "close")
        btn["tb:close"] = { cx - 2 * s, y0, cx + b + 2 * s, y1 }
        local lx, rx = cx + b + 4 * s, x1 - 4 * s
        if kind == "main" then
            local col = x1 - 8 * s - b
            local zm = col - 4 * s - b
            self:rect(zm - 2 * s, y0 + 2 * s, col + b + 2 * s, y1 - 2 * s, bg)
            self:mac_box(zm, by, b, pressed == "tb:max", "zoom")
            self:mac_box(col, by, b, pressed == "tb:min", "collapse")
            btn["tb:max"] = { zm - 2 * s, y0, zm + b + 2 * s, y1 }
            btn["tb:min"] = { col - 2 * s, y0, col + b + 2 * s, y1 }
            rx = zm - 4 * s
        end
        local tw = self.measure(title, fs, true) or 0
        local avail = rx - lx - 12 * s
        if tw > avail then tw = avail end
        if tw > 0 then
            local mid = floor((lx + rx) / 2)
            self:rect(mid - floor(tw / 2) - 6 * s, y0 + 2 * s, mid + floor(tw / 2) + 6 * s, y1 - 2 * s, bg)
            self:text(mid, floor((y0 + y1 - s) / 2), 5, title, c.title_text, fs, true,
                { mid - floor(tw / 2) - 2 * s, y0, mid + floor(tw / 2) + 2 * s, y1 })
        end
    end
    return btn
end

-- in-window menu bar. items = { {ass=, x0=, x1=} }
function D:menubar(x0, y0, x1, y1, items, open_idx)
    local c, s, st = self.c, self.s, self.st
    local fs = self.t.font_size
    if st == "win98" then
        self:rect(x0, y0, x1, y1, c.menu_bg)
    else
        self:rect(x0, y0, x1, y1 - s, c.menu_bg)
        self:rect(x0, y1 - s, x1, y1, (st == "platinum") and c.shadow or c.dark)
    end
    for i, it in ipairs(items) do
        local fg, off = c.menu_text, 0
        if i == open_idx then
            if st == "win98" then
                self:ring(it.x0, y0 + s, it.x1, y1 - s, c.shadow, c.light)
                off = s
            else
                self:rect(it.x0, y0, it.x1, y1 - s, c.menu_hl_bg)
                fg = c.menu_hl_text
            end
        end
        self:text(floor((it.x0 + it.x1) / 2) + off, floor((y0 + y1) / 2) + off, 5, it.ass, fg, fs,
            self.t.bold, nil, true)
    end
end

-- drop-down menu. items: { y0, y1, ass, key, check, radio, disabled, sep }
function D:dropdown(x0, y0, x1, y1, items, hl)
    local c, s, st = self.c, self.s, self.st
    local fs = self.t.font_size
    if st == "win98" then
        self:rect(x0, y0, x1, y1, c.drop_bg)
        self:ring(x0, y0, x1, y1, c.light2, c.dark)
        self:ring(x0 + s, y0 + s, x1 - s, y1 - s, c.light, c.shadow)
    else
        local shc = (st == "platinum") and "777777" or "000000"
        self:rect(x0 + 2 * s, y1, x1 + s, y1 + s, shc)
        self:rect(x1, y0 + 2 * s, x1 + s, y1, shc)
        self:rect(x0, y0, x1, y1, c.drop_bg)
        self:border(x0, y0, x1, y1, "000000")
    end
    local inset = (st == "win98") and 3 * s or s
    for i, it in ipairs(items) do
        if it.sep then
            local my = floor((it.y0 + it.y1) / 2)
            if st == "win98" or st == "platinum" then
                self:rect(x0 + s, my - s, x1 - s, my, c.shadow)
                self:rect(x0 + s, my, x1 - s, my + s, c.light)
            else
                self:rect(x0 + s, my, x1 - s, my + s, (st == "win31") and c.dark or "808080")
            end
        else
            local fg = c.menu_text
            if i == hl and not it.disabled then
                self:rect(x0 + inset, it.y0, x1 - inset, it.y1, c.menu_hl_bg)
                fg = c.menu_hl_text
            end
            local my = floor((it.y0 + it.y1) / 2)
            if it.disabled then
                fg = c.text_dis
                if st == "win98" then
                    self:text(x0 + 21 * s, my + s, 4, it.ass, c.light, fs, self.t.bold, nil, true)
                end
            end
            if it.check then
                self:glyph(it.radio and "bullet" or "check", x0 + 3 * s, my - 8 * s, fg)
            end
            self:text(x0 + 20 * s, my, 4, it.ass, fg, fs, self.t.bold, nil, true)
            if it.key and it.key ~= "" then
                self:text(x1 - 10 * s, my, 6, it.key, fg, fs, self.t.bold)
            end
        end
    end
end

function D:statusbar(x0, y0, x1, y1, left, right, right_w)
    local c, s, st = self.c, self.s, self.st
    local fs = self.t.font_size
    local my = floor((y0 + y1) / 2)
    local grip = 14 * s
    if st == "win98" then
        self:rect(x0, y0, x1, y1, c.status_bg)
        local rx0 = x1 - grip - right_w
        self:ring(x0 + 2 * s, y0 + 2 * s, rx0 - 2 * s, y1, c.shadow, c.light)
        self:ring(rx0, y0 + 2 * s, x1 - grip, y1, c.shadow, c.light)
        self:text(x0 + 6 * s, my + s, 4, left, c.text, fs, false, { x0, y0, rx0 - 4 * s, y1 })
        self:text(rx0 + 4 * s, my + s, 4, right, c.text, fs, false, { rx0, y0, x1 - grip, y1 })
        self:glyph("grip", x1 - 13 * s, y1 - 13 * s, c.shadow, c.light)
    else
        local line = (st == "platinum") and c.shadow or "000000"
        self:rect(x0, y0, x1, y1, c.status_bg)
        self:rect(x0, y0, x1, y0 + s, line)
        if st == "platinum" then self:rect(x0, y0 + s, x1, y0 + 2 * s, c.light) end
        local rx0 = x1 - grip - right_w
        self:text(x0 + 6 * s, my + s, 4, left, c.text, fs - 1, false, { x0, y0, rx0 - 4 * s, y1 })
        self:text(x1 - grip - 4 * s, my + s, 6, right, c.text, fs - 1, false, { rx0, y0, x1 - grip, y1 })
        if st ~= "win31" then
            -- Mac grow box
            local gx, gy = x1 - 12 * s, y1 - 12 * s
            self:border(gx + 3 * s, gy + 3 * s, gx + 11 * s, gy + 11 * s, line)
            self:rect(gx + 2 * s, gy + 2 * s, gx + 8 * s, gy + 8 * s, c.status_bg)
            self:border(gx + 2 * s, gy + 2 * s, gx + 8 * s, gy + 8 * s, line)
        end
    end
end

-- frame drawn around the video area
D.INSET = { win98 = 2, win31 = 1, platinum = 2, system7 = 1 }
function D:video_inset(x0, y0, x1, y1)
    local c, s, st = self.c, self.s, self.st
    if st == "win98" then
        self:ring(x0, y0, x1, y1, c.shadow, c.light)
        self:ring(x0 + s, y0 + s, x1 - s, y1 - s, c.dark, c.light2)
    elseif st == "platinum" then
        self:ring(x0, y0, x1, y1, c.shadow, c.light)
        self:border(x0 + s, y0 + s, x1 - s, y1 - s, "000000")
    else
        self:border(x0, y0, x1, y1, "000000")
    end
end

-- dialog window (frame + title + face). Returns content rect and title buttons.
function D:dialog(x0, y0, x1, y1, title, pressed)
    local t, s = self.t, self.s
    local f = t.m.frame * s
    local th = t.m.title_h * s
    self:rect(x0, y0, x1, y1, t.c.face)
    self:window_frame(x0, y0, x1, y1, f, th)
    local btn = self:title_bar(x0 + f, y0 + f, x1 - f, y0 + f + th, title, pressed, "dialog")
    return { x0 + f, y0 + f + th, x1 - f, y1 - f }, btn
end

return D
