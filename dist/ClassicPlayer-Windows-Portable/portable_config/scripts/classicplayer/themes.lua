-- Classic Player - theme definitions
-- Colors are "RRGGBB". Metrics are in logical pixels (multiplied by UI scale).

local T = {}

-- Font names are chosen per platform because classic system fonts are not
-- installed on modern systems. Drop your own retro TTF/OTF fonts into
-- portable_config/fonts and set font_<theme>=<Family Name> in
-- script-opts/classicplayer.conf to get a more authentic look.
local FONTS = {
    win31     = { windows = "Microsoft Sans Serif", darwin = "Tahoma",  other = "DejaVu Sans" },
    win98     = { windows = "Microsoft Sans Serif", darwin = "Tahoma",  other = "DejaVu Sans" },
    platinum  = { windows = "Arial",                darwin = "Geneva",  other = "DejaVu Sans" },
    system7   = { windows = "Arial",                darwin = "Geneva",  other = "DejaVu Sans" },
}

T.order = { "win31", "win98", "platinum", "system7" }

T.list = {
    win31 = {
        id = "win31", name = "Windows 3.1", style = "win31",
        font_size = 13, bold = true, title_bold = true,
        c = {
            face = "C0C0C0", light = "FFFFFF", light2 = "C0C0C0", shadow = "808080", dark = "000000",
            text = "000000", text_dis = "808080",
            frame = "C0C0C0", frame_line = "000000",
            title_bg = "000080", title_bg2 = "000080", title_text = "FFFFFF",
            menu_bg = "FFFFFF", menu_text = "000000", menu_hl_bg = "000080", menu_hl_text = "FFFFFF",
            drop_bg = "FFFFFF",
            field = "FFFFFF", accent = "000080",
            status_bg = "C0C0C0",
            video_text = "C0C0C0", video_dim = "808080",
        },
        m = { frame = 4, title_h = 20, menu_h = 20, seek_h = 30, ctrl_h = 32, status_h = 20,
              btn_w = 26, btn_h = 24, item_h = 18, sep_h = 8 },
    },

    win98 = {
        id = "win98", name = "Windows 95/98", style = "win98",
        font_size = 13, bold = false, title_bold = true,
        c = {
            face = "C0C0C0", light = "FFFFFF", light2 = "DFDFDF", shadow = "808080", dark = "000000",
            text = "000000", text_dis = "808080",
            frame = "C0C0C0", frame_line = "000000",
            title_bg = "000080", title_bg2 = "1084D0", title_text = "FFFFFF",
            menu_bg = "C0C0C0", menu_text = "000000", menu_hl_bg = "000080", menu_hl_text = "FFFFFF",
            drop_bg = "C0C0C0",
            field = "FFFFFF", accent = "000080",
            status_bg = "C0C0C0",
            video_text = "C0C0C0", video_dim = "808080",
        },
        m = { frame = 4, title_h = 18, menu_h = 20, seek_h = 30, ctrl_h = 32, status_h = 20,
              btn_w = 26, btn_h = 24, item_h = 18, sep_h = 9 },
    },

    platinum = {
        id = "platinum", name = "Mac OS 8/9 (Platinum)", style = "platinum",
        font_size = 13, bold = true, title_bold = true,
        c = {
            face = "DDDDDD", light = "FFFFFF", light2 = "EEEEEE", shadow = "999999", dark = "555555",
            text = "000000", text_dis = "999999",
            frame = "DDDDDD", frame_line = "000000",
            title_bg = "DDDDDD", title_bg2 = "DDDDDD", title_text = "000000",
            menu_bg = "DDDDDD", menu_text = "000000", menu_hl_bg = "333399", menu_hl_text = "FFFFFF",
            drop_bg = "DDDDDD",
            field = "FFFFFF", accent = "6666CC",
            status_bg = "DDDDDD",
            video_text = "BBBBBB", video_dim = "777777",
        },
        m = { frame = 5, title_h = 20, menu_h = 20, seek_h = 30, ctrl_h = 32, status_h = 18,
              btn_w = 26, btn_h = 22, item_h = 18, sep_h = 8 },
    },

    system7 = {
        id = "system7", name = "Mac System 7", style = "system7",
        font_size = 13, bold = true, title_bold = true,
        c = {
            face = "FFFFFF", light = "FFFFFF", light2 = "FFFFFF", shadow = "000000", dark = "000000",
            text = "000000", text_dis = "999999",
            frame = "FFFFFF", frame_line = "000000",
            title_bg = "FFFFFF", title_bg2 = "FFFFFF", title_text = "000000",
            menu_bg = "FFFFFF", menu_text = "000000", menu_hl_bg = "000000", menu_hl_text = "FFFFFF",
            drop_bg = "FFFFFF",
            field = "FFFFFF", accent = "000000",
            status_bg = "FFFFFF",
            video_text = "DDDDDD", video_dim = "888888",
        },
        m = { frame = 1, title_h = 19, menu_h = 20, seek_h = 30, ctrl_h = 32, status_h = 18,
              btn_w = 26, btn_h = 22, item_h = 18, sep_h = 8 },
    },
}

-- aliases accepted in config / state file
T.alias = {
    ["win3.1"] = "win31", win3 = "win31", windows31 = "win31",
    win95 = "win98", win9x = "win98", ["win9.x"] = "win98",
    mac = "platinum", macos9 = "platinum", os9 = "platinum", macos8 = "platinum",
    system6 = "system7", sys7 = "system7", macclassic = "system7",
}

function T.resolve(id)
    id = (id or ""):lower()
    id = T.alias[id] or id
    if T.list[id] then return id end
    return "win98"
end

function T.font_for(id, platform, overrides)
    local o = overrides and overrides[id]
    if o and o ~= "" then return o end
    local f = FONTS[id] or FONTS.win98
    return f[platform] or f.other
end

return T
