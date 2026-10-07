-- Classic Player
-- A minimal, classic-styled media player UI built on the mpv engine.
-- All UI is drawn with ASS vector graphics into the mpv window, so the
-- whole app is a single lightweight process with no external toolkit.

local mp = require "mp"
local msg = require "mp.msg"
local options = require "mp.options"

local script_dir = mp.get_script_directory()
if script_dir then package.path = script_dir .. "/?.lua;" .. package.path end
local Themes = require "themes"
local Draw = require "draw"

local VERSION = "1.0.0"
local floor, max, min = math.floor, math.max, math.min
local clamp = Draw.clamp
local unpack = table.unpack or unpack

---------------------------------------------------------------------------
-- Options
---------------------------------------------------------------------------
local opts = {
    theme = "win98",          -- win31 | win98 | platinum | system7
    classic_frame = true,     -- draw a classic title bar / frame (borderless window)
    ui_scale = 0,             -- 0 = auto (follows display DPI), otherwise 1, 2, 3
    seek_step = 10,           -- seconds for rewind / fast-forward
    remember = true,          -- remember theme, frame, scale and volume
    fs_hide_delay = 2.5,      -- seconds before fullscreen controls hide
    font_win31 = "", font_win98 = "", font_platinum = "", font_system7 = "",
}
options.read_options(opts, "classicplayer")

local platform = mp.get_property("platform", "")
if platform == "" then
    platform = (package.config:sub(1, 1) == "\\") and "windows" or "linux"
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
local S = {
    w = 0, h = 0, s = 1, hidpi = 1,
    theme = nil, font = "Arial",
    mx = -1, my = -1, minside = false,
    hits = {}, hover = nil, hover_hit = nil, pressed = nil, drag = nil,
    menu = nil, dialog = nil,
    status = nil, status_until = 0,
    fs_visible_until = 0,
    pause = false, idle = true, stopped = false, duration = 0, time = 0,
    volume = 80, mute = false, fullscreen = false, maximized = false,
    title = "", has_video = false, speed = 1, pl_count = 0, pl_pos = -1,
    meta = {},
}

local request, render, open_menu, close_menu, open_menubar, status
local text_width

---------------------------------------------------------------------------
-- Persistent state (theme etc.)
---------------------------------------------------------------------------
local function state_file()
    if platform == "windows" then
        return mp.command_native({ "expand-path", "~~/classicplayer-state.txt" }), nil
    end
    local home = os.getenv("HOME") or "/tmp"
    local d
    if platform == "darwin" then
        d = home .. "/Library/Application Support/ClassicPlayer"
    else
        d = (os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")) .. "/classicplayer"
    end
    return d .. "/state.txt", d
end

local function load_state()
    local path = state_file()
    local f = path and io.open(path, "r")
    if not f then return {} end
    local st = {}
    for line in f:lines() do
        local k, v = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        if k then st[k] = v end
    end
    f:close()
    return st
end

local dir_ready = false
local function save_state()
    if not opts.remember or not S.theme then return end
    local path, d = state_file()
    if not path then return end
    if d and not dir_ready then
        mp.command_native({ name = "subprocess", args = { "mkdir", "-p", d },
            playback_only = false, capture_stdout = true, capture_stderr = true })
        dir_ready = true
    end
    local f = io.open(path, "w")
    if not f then return end
    f:write("theme=", S.theme.id, "\n")
    f:write("classic_frame=", tostring(opts.classic_frame), "\n")
    f:write("ui_scale=", tostring(opts.ui_scale), "\n")
    local vol = mp.get_property_number("volume")
    if vol then f:write("volume=", tostring(floor(vol + 0.5)), "\n") end
    f:close()
end

---------------------------------------------------------------------------
-- Theme / scale
---------------------------------------------------------------------------
local mcache = {}

local function set_theme(id, persist)
    id = Themes.resolve(id)
    S.theme = Themes.list[id]
    S.font = Themes.font_for(id, platform, {
        win31 = opts.font_win31, win98 = opts.font_win98,
        platinum = opts.font_platinum, system7 = opts.font_system7,
    })
    mcache = {}
    if persist then
        save_state()
        status("Theme: " .. S.theme.name)
    end
    request()
end

local function next_theme()
    local cur = S.theme.id
    for i, id in ipairs(Themes.order) do
        if id == cur then
            set_theme(Themes.order[i % #Themes.order + 1], true)
            return
        end
    end
end

local function update_scale()
    local s = tonumber(opts.ui_scale) or 0
    if s <= 0 then s = floor((S.hidpi or 1) + 0.5) end
    S.s = max(1, floor(s))
    mcache = {}
end

---------------------------------------------------------------------------
-- Text measuring (hidden overlay with compute_bounds)
---------------------------------------------------------------------------
local measure_ov = mp.create_osd_overlay("ass-events")
measure_ov.hidden = true
measure_ov.compute_bounds = true

text_width = function(str, size, bold)
    local px = floor(size * S.s + 0.5)
    local key = S.font .. "|" .. px .. (bold and "b|" or "|") .. str
    local v = mcache[key]
    if v then return v end
    local guess = floor(#str * px * 0.55)
    if S.w <= 0 then return guess end
    measure_ov.res_x, measure_ov.res_y = S.w, S.h
    measure_ov.data = string.format("{\\an7\\pos(0,0)\\bord0\\shad0\\q2\\fn%s\\fs%d\\b%d}%s",
        S.font, px, bold and 1 or 0, Draw.esc(str))
    local res = measure_ov:update()
    if res and res.x0 and res.x1 then v = res.x1 - res.x0 else v = guess end
    mcache[key] = v
    return v
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function basename(p) return (p or ""):match("([^/\\]+)$") or p end

local function fmt_time(t, long)
    t = max(0, floor(t or 0))
    local h, m, sec = floor(t / 3600), floor(t / 60) % 60, t % 60
    if long then return string.format("%d:%02d:%02d", h, m, sec) end
    return string.format("%02d:%02d", floor(t / 60), sec)
end

status = function(text, dur)
    dur = dur or 3
    S.status = text
    S.status_until = mp.get_time() + dur
    mp.add_timeout(dur + 0.05, function() request() end)
    request()
end

local function b64(data)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local out = {}
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1 = floor(n / 262144) % 64
        local c2 = floor(n / 4096) % 64
        local c3 = floor(n / 64) % 64
        local c4 = n % 64
        out[#out + 1] = chars:sub(c1 + 1, c1 + 1) .. chars:sub(c2 + 1, c2 + 1) ..
            (b and chars:sub(c3 + 1, c3 + 1) or "=") .. (c and chars:sub(c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

---------------------------------------------------------------------------
-- File dialogs (native OS dialogs, run asynchronously)
---------------------------------------------------------------------------
local MEDIA_EXT = "*.mp4;*.mkv;*.avi;*.mov;*.wmv;*.webm;*.flv;*.m4v;*.mpg;*.mpeg;*.ts;*.m2ts;*.mts;" ..
    "*.3gp;*.ogv;*.vob;*.divx;*.rm;*.rmvb;*.asf;*.mp3;*.flac;*.wav;*.ogg;*.oga;*.opus;*.m4a;*.aac;" ..
    "*.wma;*.ape;*.mka;*.aiff;*.aif;*.ac3;*.dts;*.m3u;*.m3u8;*.pls"
local SUB_EXT = "*.srt;*.ass;*.ssa;*.vtt;*.sub;*.idx;*.sup;*.smi;*.txt"
local SUB_SET = { srt = true, ass = true, ssa = true, vtt = true, sub = true, idx = true,
    sup = true, smi = true }

local function is_sub(path)
    local ext = path:match("%.([^%.\\/]+)$")
    return ext and SUB_SET[ext:lower()]
end

local dialog_busy = false
local function file_dialog(kind, multi, cb)
    if dialog_busy then return end
    local title = (kind == "sub") and "Load Subtitle" or "Open Media"
    local args
    if platform == "windows" then
        local filter = (kind == "sub")
            and ("Subtitles|" .. SUB_EXT .. "|All files|*.*")
            or ("Media files|" .. MEDIA_EXT .. "|Subtitles|" .. SUB_EXT .. "|All files|*.*")
        local ps = table.concat({
            "Add-Type -AssemblyName System.Windows.Forms",
            "[System.Windows.Forms.Application]::EnableVisualStyles()",
            "$o = New-Object System.Windows.Forms.Form -Property @{TopMost=$true; ShowInTaskbar=$false}",
            "$d = New-Object System.Windows.Forms.OpenFileDialog",
            "$d.Title = '" .. title .. "'",
            "$d.Filter = '" .. filter .. "'",
            "$d.Multiselect = $" .. (multi and "true" or "false"),
            "if ($d.ShowDialog($o) -eq [System.Windows.Forms.DialogResult]::OK) {",
            "  $u = New-Object System.Text.UTF8Encoding $false",
            "  $out = [Console]::OpenStandardOutput()",
            "  foreach ($f in $d.FileNames) { $b = $u.GetBytes($f + \"`n\"); $out.Write($b, 0, $b.Length) }",
            "  $out.Flush()",
            "}",
            "$o.Dispose()",
        }, "\n")
        local utf16 = ps:gsub(".", "%0\0")
        args = { "powershell", "-NoProfile", "-NonInteractive", "-STA", "-ExecutionPolicy", "Bypass",
            "-WindowStyle", "Hidden", "-EncodedCommand", b64(utf16) }
    elseif platform == "darwin" then
        args = { "osascript",
            "-e", "tell me to activate",
            "-e", 'set theFiles to choose file with prompt "' .. title .. '"' ..
                (multi and " with multiple selections allowed" or ""),
            "-e", "if class of theFiles is not list then set theFiles to {theFiles}",
            "-e", 'set out to ""',
            "-e", "repeat with f in theFiles",
            "-e", "set out to out & POSIX path of f & linefeed",
            "-e", "end repeat",
            "-e", "return out" }
    else
        args = { "zenity", "--file-selection", "--title=" .. title, "--separator=\n" }
        if multi then args[#args + 1] = "--multiple" end
    end
    dialog_busy = true
    mp.command_native_async({ name = "subprocess", args = args, capture_stdout = true,
        capture_stderr = true, playback_only = false }, function(ok, res)
        dialog_busy = false
        if not ok or not res or res.status ~= 0 then return end
        local files = {}
        for line in (res.stdout or ""):gmatch("[^\r\n]+") do
            if line ~= "" then files[#files + 1] = line end
        end
        if #files > 0 then cb(files) end
    end)
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
local A = {}

function A.open_files()
    file_dialog("media", true, function(files)
        local first = true
        for _, f in ipairs(files) do
            if is_sub(f) then
                if not S.idle then mp.commandv("sub-add", f, "select") end
            else
                mp.commandv("loadfile", f, first and "replace" or "append")
                first = false
            end
        end
    end)
end

local ok_input, input = pcall(require, "mp.input")
function A.open_url()
    if not ok_input then status("Open URL needs a newer mpv engine (0.38+)"); return end
    input.get({
        prompt = "Open URL:",
        submit = function(text)
            input.terminate()
            if text and text ~= "" then mp.commandv("loadfile", text, "replace") end
        end,
    })
end

function A.load_subtitle()
    if S.idle then status("Open a video first"); return end
    file_dialog("sub", false, function(files)
        mp.commandv("sub-add", files[1], "select")
        status("Subtitle loaded: " .. basename(files[1]), 4)
    end)
end

function A.screenshot(subs)
    if S.idle or not S.has_video then status("Nothing to capture"); return end
    local r = mp.command_native({ "screenshot", subs and "subtitles" or "video" })
    local name = type(r) == "table" and r.filename or nil
    status(name and ("Screenshot saved: " .. basename(name)) or "Screenshot saved", 5)
end

function A.toggle_pause()
    if S.idle then A.open_files() return end
    mp.commandv("cycle", "pause")
end

function A.stop()
    if S.idle then return end
    mp.set_property_bool("pause", true)
    mp.commandv("seek", "0", "absolute", "exact")
    S.stopped = true
    request()
end

function A.seek(sec)
    if S.idle then return end
    mp.commandv("seek", tostring(sec), "relative")
end

function A.prev() mp.commandv("playlist-prev") end
function A.next() mp.commandv("playlist-next") end
function A.fullscreen() mp.commandv("cycle", "fullscreen") end
function A.maximize() mp.commandv("cycle", "window-maximized") end
function A.minimize() mp.set_property_bool("window-minimized", true) end
function A.quit() mp.commandv("quit") end
function A.mute() mp.commandv("cycle", "mute") end
function A.volume(d)
    mp.commandv("add", "volume", tostring(d))
    status(string.format("Volume: %d%%", floor((mp.get_property_number("volume") or 0) + 0.5)), 1.5)
end

local ADJ = {
    { "brightness", "Brightness" }, { "contrast", "Contrast" }, { "saturation", "Saturation" },
    { "gamma", "Gamma" }, { "hue", "Hue" },
}
function A.reset_picture()
    for _, a in ipairs(ADJ) do mp.set_property_number(a[1], 0) end
    status("Picture settings reset")
end

function A.dialog(kind)
    if close_menu then close_menu() end
    if S.dialog and S.dialog.kind == kind then S.dialog = nil
    else S.dialog = { kind = kind, dx = 0, dy = 0 } end
    request()
end
function A.close_dialog() S.dialog = nil; request() end

function A.set_frame(v)
    opts.classic_frame = v
    mp.set_property_bool("border", not v)
    save_state()
    request()
end

function A.set_scale(v)
    opts.ui_scale = v
    update_scale()
    save_state()
    request()
end

function A.escape()
    if S.menu then close_menu()
    elseif S.dialog then A.close_dialog()
    elseif S.fullscreen then mp.set_property_bool("fullscreen", false) end
end

local BUTTONS = {
    ["btn:open"] = A.open_files, ["btn:prev"] = A.prev, ["btn:next"] = A.next,
    ["btn:rew"] = function() A.seek(-opts.seek_step) end,
    ["btn:ff"] = function() A.seek(opts.seek_step) end,
    ["btn:play"] = A.toggle_pause, ["btn:stop"] = A.stop,
    ["btn:shot"] = function() A.screenshot(false) end,
    ["btn:sub"] = A.load_subtitle,
    ["btn:adjust"] = function() A.dialog("adjust") end,
    ["btn:fs"] = A.fullscreen, ["btn:mute"] = A.mute,
    ["tb:close"] = A.quit, ["tb:min"] = A.minimize, ["tb:max"] = A.maximize,
    ["tb:sys"] = function()
        local r = S.L and S.L.title
        if r then open_menu("system", r[1], r[4], nil) end
    end,
    ["dlg_close"] = A.close_dialog, ["dbtn:close"] = A.close_dialog, ["dbtn:ok"] = A.close_dialog,
    ["dbtn:reset"] = A.reset_picture,
}

---------------------------------------------------------------------------
-- Menus
---------------------------------------------------------------------------
local MENUBAR = {
    { name = "file", label = "&File" }, { name = "play", label = "&Play" },
    { name = "video", label = "&Video" }, { name = "audio", label = "&Audio" },
    { name = "subtitle", label = "&Subtitle" }, { name = "view", label = "V&iew" },
    { name = "help", label = "&Help" },
}

local function track_items(kind, add)
    local n = 0
    for _, tr in ipairs(mp.get_property_native("track-list") or {}) do
        if tr.type == kind then
            n = n + 1
            local parts = {}
            if tr.title then parts[#parts + 1] = tr.title end
            if tr.lang then parts[#parts + 1] = "[" .. tr.lang .. "]" end
            if tr.codec then parts[#parts + 1] = "(" .. tr.codec .. ")" end
            if tr.external then parts[#parts + 1] = "external" end
            local label = "Track " .. tr.id .. ": " .. table.concat(parts, " ")
            if #label > 60 then label = label:sub(1, 57) .. "..." end
            local prop = (kind == "audio") and "aid" or "sid"
            add(label, "", function() mp.set_property_number(prop, tr.id) end,
                { check = tr.selected, radio = true, raw = true })
        end
    end
    return n
end

local function build_menu(name)
    local I = {}
    local function add(label, key, action, extra)
        local it = { label = label, key = key, action = action }
        if extra then for k, v in pairs(extra) do it[k] = v end end
        I[#I + 1] = it
    end
    local function sep() I[#I + 1] = { sep = true } end
    local idle = S.idle
    local function prop(p) return mp.get_property(p) end

    if name == "file" then
        add("&Open File...", "Ctrl+O", A.open_files)
        add("Open &URL...", "Ctrl+U", A.open_url)
        add("Load &Subtitle...", "Ctrl+L", A.load_subtitle, { disabled = idle })
        sep()
        add("Take Screens&hot", "S", function() A.screenshot(false) end, { disabled = idle })
        add("Screenshot with Su&btitles", "Shift+S", function() A.screenshot(true) end, { disabled = idle })
        sep()
        add("&Close", "", function() mp.commandv("stop") end, { disabled = idle })
        add("E&xit", "Q", A.quit)
    elseif name == "play" then
        add((S.pause or idle) and "&Play" or "&Pause", "Space", A.toggle_pause)
        add("&Stop", "", A.stop, { disabled = idle })
        sep()
        add("&Rewind " .. opts.seek_step .. "s", "Left", function() A.seek(-opts.seek_step) end, { disabled = idle })
        add("&Forward " .. opts.seek_step .. "s", "Right", function() A.seek(opts.seek_step) end, { disabled = idle })
        add("Pre&vious", "<", A.prev, { disabled = S.pl_pos <= 0 })
        add("&Next", ">", A.next, { disabled = S.pl_pos < 0 or S.pl_pos >= S.pl_count - 1 })
        sep()
        for _, sp in ipairs({ 0.5, 0.75, 1, 1.25, 1.5, 2 }) do
            add(sp == 1 and "Speed: Normal" or string.format("Speed: %gx", sp), "",
                function() mp.set_property_number("speed", sp) end,
                { check = math.abs(S.speed - sp) < 0.001, radio = true })
        end
        sep()
        add("&Loop File", "", function() mp.set_property("loop-file", prop("loop-file") == "no" and "inf" or "no") end,
            { check = prop("loop-file") ~= "no" })
    elseif name == "video" then
        add("&Full Screen", "F", A.fullscreen, { check = S.fullscreen })
        add("Always on &Top", "", function() mp.commandv("cycle", "ontop") end,
            { check = mp.get_property_bool("ontop") })
        sep()
        add("&Picture Adjustments...", "Ctrl+B", function() A.dialog("adjust") end)
        add("&Reset Picture", "", A.reset_picture)
        sep()
        local asp = prop("video-aspect-override") or "-1"
        for _, a in ipairs({ { "-1", "Aspect: Auto" }, { "16:9", "Aspect: 16:9" }, { "4:3", "Aspect: 4:3" },
            { "2.35:1", "Aspect: 2.35:1" } }) do
            local cur = tonumber(asp) or 0
            local want = a[1] == "-1" and -1 or (a[1] == "16:9" and 16 / 9 or (a[1] == "4:3" and 4 / 3 or 2.35))
            add(a[2], "", function() mp.set_property("video-aspect-override", a[1]) end,
                { check = math.abs(cur - want) < 0.01, radio = true })
        end
        sep()
        add("Rotate &90\194\176", "", function()
            mp.set_property_number("video-rotate", ((mp.get_property_number("video-rotate") or 0) + 90) % 360)
        end)
        add("&Deinterlace", "D", function() mp.commandv("cycle", "deinterlace") end,
            { check = mp.get_property_bool("deinterlace") })
        add("&Hardware Decoding", "", function()
            mp.set_property("hwdec", prop("hwdec") == "no" and "auto-safe" or "no")
        end, { check = prop("hwdec") ~= "no" })
    elseif name == "audio" then
        add("&Mute", "M", A.mute, { check = S.mute })
        add("Volume &Up", "Up", function() A.volume(5) end)
        add("Volume &Down", "Down", function() A.volume(-5) end)
        sep()
        if track_items("audio", add) == 0 then add("No audio tracks", "", nil, { disabled = true }) end
    elseif name == "subtitle" then
        add("&Load Subtitle...", "Ctrl+L", A.load_subtitle, { disabled = idle })
        add("&Show Subtitles", "V", function() mp.commandv("cycle", "sub-visibility") end,
            { check = mp.get_property_bool("sub-visibility") })
        sep()
        add("None", "", function() mp.set_property("sid", "no") end,
            { check = prop("sid") == "no" or prop("sid") == nil, radio = true })
        track_items("sub", add)
        sep()
        add("Delay -0.1s", "Z", function() mp.commandv("add", "sub-delay", "-0.1") end, { disabled = idle })
        add("Delay +0.1s", "Shift+Z", function() mp.commandv("add", "sub-delay", "0.1") end, { disabled = idle })
        add("Reset Delay", "", function() mp.set_property_number("sub-delay", 0) end, { disabled = idle })
        add("Larger Text", "Shift+G", function() mp.commandv("add", "sub-scale", "0.1") end)
        add("Smaller Text", "Shift+F", function() mp.commandv("add", "sub-scale", "-0.1") end)
    elseif name == "view" then
        for i, id in ipairs(Themes.order) do
            add(Themes.list[id].name, i == 1 and "Ctrl+T" or "", function() set_theme(id, true) end,
                { check = S.theme.id == id, radio = true, raw = true })
        end
        sep()
        add("Classic &Window Frame", "", function() A.set_frame(not opts.classic_frame) end,
            { check = opts.classic_frame })
        sep()
        for _, sc in ipairs({ 0, 1, 2, 3 }) do
            add(sc == 0 and "UI Size: Auto" or string.format("UI Size: %d%%", sc * 100), "",
                function() A.set_scale(sc) end, { check = (tonumber(opts.ui_scale) or 0) == sc, radio = true })
        end
    elseif name == "help" then
        add("&Keyboard Shortcuts...", "F1", function() A.dialog("keys") end)
        sep()
        add("&About Classic Player...", "", function() A.dialog("about") end)
    elseif name == "system" then
        add("&Restore", "", A.maximize, { disabled = not S.maximized })
        add("Mi&nimize", "", A.minimize)
        add("Ma&ximize", "", A.maximize, { disabled = S.maximized })
        sep()
        add("&Close", "Alt+F4", A.quit)
    elseif name == "context" then
        add((S.pause or idle) and "&Play" or "&Pause", "Space", A.toggle_pause)
        add("&Stop", "", A.stop, { disabled = idle })
        sep()
        add("&Open File...", "Ctrl+O", A.open_files)
        add("Load &Subtitle...", "Ctrl+L", A.load_subtitle, { disabled = idle })
        add("Take Screens&hot", "S", function() A.screenshot(false) end, { disabled = idle })
        add("&Picture Adjustments...", "Ctrl+B", function() A.dialog("adjust") end)
        sep()
        add("&Full Screen", "F", A.fullscreen, { check = S.fullscreen })
        sep()
        for _, id in ipairs(Themes.order) do
            add(Themes.list[id].name, "", function() set_theme(id, true) end,
                { check = S.theme.id == id, radio = true, raw = true })
        end
    end
    return I
end

local menu_key_names = {}
local function menu_keys(enable)
    for _, n in ipairs(menu_key_names) do mp.remove_key_binding(n) end
    menu_key_names = {}
    if not enable then return end
    local function bind(key, fn)
        local n = "cp-menu-" .. key
        mp.add_forced_key_binding(key, n, fn, { repeatable = true })
        menu_key_names[#menu_key_names + 1] = n
    end
    local function move(d)
        local M = S.menu
        if not M then return end
        local n, i = #M.items, M.hl or (d > 0 and 0 or #M.items + 1)
        for _ = 1, n do
            i = i + d
            if i < 1 then i = n elseif i > n then i = 1 end
            local it = M.items[i]
            if not it.sep and not it.disabled then break end
        end
        M.hl = i
        request()
    end
    local function activate()
        local M = S.menu
        if M and M.hl then
            local it = M.items[M.hl]
            if it and not it.sep and not it.disabled then
                close_menu()
                if it.action then it.action() end
            end
        end
    end
    local function side(d)
        local M = S.menu
        if M and M.idx then open_menubar((M.idx - 1 + d) % #MENUBAR + 1, true) end
    end
    bind("UP", function() move(-1) end)
    bind("DOWN", function() move(1) end)
    bind("LEFT", function() side(-1) end)
    bind("RIGHT", function() side(1) end)
    bind("ENTER", activate)
    bind("KP_ENTER", activate)
    bind("ESC", function() close_menu() end)
end

open_menu = function(name, x, y, idx, hl_first)
    local t, s = S.theme, S.s
    local items = build_menu(name)
    local ih, sh = t.m.item_h * s, t.m.sep_h * s
    local lw, kw = 0, 0
    for _, it in ipairs(items) do
        if not it.sep then
            if it.raw then it.ass, it.plain = Draw.esc(it.label), it.label
            else it.ass, it.plain = Draw.accel(it.label, t.style == "win31" or t.style == "win98") end
            lw = max(lw, text_width(it.plain, t.font_size, t.bold))
            if it.key and it.key ~= "" then kw = max(kw, text_width(it.key, t.font_size, t.bold)) end
        end
    end
    local width = 20 * s + lw + (kw > 0 and (kw + 28 * s) or 0) + 16 * s
    local pad = (t.style == "win98") and 3 * s or 2 * s
    local height = pad * 2
    for _, it in ipairs(items) do height = height + (it.sep and sh or ih) end
    if x + width > S.w - 2 * s then x = max(0, S.w - 2 * s - width) end
    if y + height > S.h - 2 * s then y = max(0, S.h - 2 * s - height) end
    local yy = y + pad
    for _, it in ipairs(items) do
        it.y0 = yy
        yy = yy + (it.sep and sh or ih)
        it.y1 = yy
    end
    S.menu = { name = name, idx = idx, items = items, x0 = x, y0 = y, x1 = x + width, y1 = y + height }
    if hl_first then
        for i, it in ipairs(items) do
            if not it.sep and not it.disabled then S.menu.hl = i break end
        end
    end
    menu_keys(true)
    request()
end

close_menu = function()
    if S.menu then
        S.menu = nil
        menu_keys(false)
        request()
    end
end

open_menubar = function(idx, hl_first)
    if not S.mb_items or not S.mb_items[idx] or not S.L or not S.L.menubar then return end
    local it = S.mb_items[idx]
    open_menu(MENUBAR[idx].name, it.x0, S.L.menubar[4], idx, hl_first)
end

local function activate_item(i)
    local M = S.menu
    if not M then return end
    local it = M.items[i]
    if not it or it.sep or it.disabled then return end
    close_menu()
    if it.action then it.action() end
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------
local function compute_layout()
    local t, s, m = S.theme, S.s, S.theme.m
    local w, h = S.w, S.h
    local L = {}
    local fs = S.fullscreen
    if fs then
        L.video = { 0, 0, w, h }
        local ph = (m.seek_h + m.ctrl_h) * s
        local over_panel = S.minside and S.my >= h - ph
        local vis = S.idle or S.pause or S.menu or S.dialog or S.drag or over_panel
            or mp.get_time() < S.fs_visible_until
        if vis then
            L.panel = { 0, h - ph, w, h }
            L.seek = { 0, h - ph, w, h - m.ctrl_h * s }
            L.ctrl = { 0, h - m.ctrl_h * s, w, h }
        end
        return L
    end
    L.show_title = opts.classic_frame
    L.show_frame = L.show_title and not S.maximized
    local f = L.show_frame and m.frame * s or 0
    L.f = f
    local x0, y0, x1, y1 = f, f, w - f, h - f
    if L.show_title then
        L.title = { x0, y0, x1, y0 + m.title_h * s }
        y0 = L.title[4]
    end
    L.menubar = { x0, y0, x1, y0 + m.menu_h * s }
    y0 = L.menubar[4]
    L.status = { x0, y1 - m.status_h * s, x1, y1 }
    y1 = L.status[2]
    L.ctrl = { x0, y1 - m.ctrl_h * s, x1, y1 }
    L.seek = { x0, L.ctrl[2] - m.seek_h * s, x1, L.ctrl[2] }
    L.vbox = { x0, y0, x1, L.seek[2] }
    local inset = (Draw.INSET[t.style] or 1) * s
    L.video = { x0 + inset, y0 + inset, x1 - inset, L.seek[2] - inset }
    return L
end

local last_margins = ""
local function apply_margins(L)
    local l, tp, r, b = 0, 0, 0, 0
    if not S.fullscreen and S.w > 0 and S.h > 0 then
        local v = L.video
        l, tp = v[1] / S.w, v[2] / S.h
        r, b = (S.w - v[3]) / S.w, (S.h - v[4]) / S.h
    end
    local key = string.format("%.5f,%.5f,%.5f,%.5f", l, tp, r, b)
    if key == last_margins then return end
    last_margins = key
    mp.set_property_number("video-margin-ratio-left", l)
    mp.set_property_number("video-margin-ratio-top", tp)
    mp.set_property_number("video-margin-ratio-right", r)
    mp.set_property_number("video-margin-ratio-bottom", b)
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------
local ui = mp.create_osd_overlay("ass-events")
local P = Draw.new(function(str, size, bold) return text_width(str, size, bold) end)
local last_data

local function hit(id, x0, y0, x1, y1, data)
    S.hits[#S.hits + 1] = { id = id, x0 = x0, y0 = y0, x1 = x1, y1 = y1, data = data }
end
local function hit_r(id, r, data) hit(id, r[1], r[2], r[3], r[4], data) end
local function hit_at(x, y)
    for i = #S.hits, 1, -1 do
        local hh = S.hits[i]
        if x >= hh.x0 and x < hh.x1 and y >= hh.y0 and y < hh.y1 then return hh end
    end
end

local CTRL = {
    { id = "open", glyph = "eject", tip = "Open a media file (Ctrl+O)" }, false,
    { id = "prev", glyph = "prev", tip = "Previous item in playlist" },
    { id = "rew", glyph = "rew", tip = "Rewind" },
    { id = "play", tip = "Play / Pause (Space)" },
    { id = "stop", glyph = "stop", tip = "Stop" },
    { id = "ff", glyph = "ff", tip = "Fast forward" },
    { id = "next", glyph = "next", tip = "Next item in playlist" }, false,
    { id = "shot", glyph = "camera", tip = "Take a screenshot (S)" },
    { id = "sub", glyph = "subtitle", tip = "Load a subtitle file (Ctrl+L)" },
    { id = "adjust", glyph = "contrast", tip = "Brightness / contrast (Ctrl+B)" },
    { id = "fs", glyph = "fullscreen", tip = "Full screen (F)" },
}

local function is_disabled(id)
    if id == "open" or id == "play" or id == "fs" or id == "adjust" then return false end
    if id == "prev" then return S.pl_pos <= 0 end
    if id == "next" then return S.pl_pos < 0 or S.pl_pos >= S.pl_count - 1 end
    if id == "shot" then return S.idle or not S.has_video end
    return S.idle
end

local function draw_video_area(L)
    local t, c, s = S.theme, S.theme.c, S.s
    local v = L.video
    local vw, vh = v[3] - v[1], v[4] - v[2]
    if vw < 120 * s or vh < 60 * s then return end
    local cx, cy = floor((v[1] + v[3]) / 2), floor((v[2] + v[4]) / 2)
    if S.idle then
        if vh > 200 * s then P:glyph("film", cx - 24 * s, cy - 84 * s, c.video_dim, "000000", 3) end
        P:text(cx, cy, 5, "Classic Player", c.video_text, 26, true)
        P:text(cx, cy + 30 * s, 5, "File > Open File...  (Ctrl+O)", c.video_dim, t.font_size)
        P:text(cx, cy + 48 * s, 5, "or drop media files onto this window", c.video_dim, t.font_size)
    elseif not S.has_video then
        if vh > 200 * s then P:glyph("speaker", cx - 24 * s, cy - 84 * s, c.video_dim, "000000", 3) end
        P:text(cx, cy, 5, S.title, c.video_text, 20, true, { v[1] + 8 * s, v[2], v[3] - 8 * s, v[4] })
        local line = table.concat({ S.meta.artist or "", S.meta.album or "" },
            (S.meta.artist and S.meta.album) and "  -  " or "")
        if line ~= "" then P:text(cx, cy + 26 * s, 5, line, c.video_dim, t.font_size + 1) end
    end
end

local function draw_seek(r)
    local t, c, s = S.theme, S.theme.c, S.s
    local x0, y0, x1, y1 = r[1], r[2], r[3], r[4]
    local long = S.duration >= 3600
    local tmpl = long and "0:00:00 / 0:00:00" or "00:00 / 00:00"
    local tw = text_width(tmpl, t.font_size, false) + 6 * s
    local tx1 = x1 - 8 * s
    local sx0, sx1 = x0 + 8 * s, tx1 - tw - 10 * s
    local dragging = S.drag and S.drag.kind == "seek"
    local frac = dragging and S.drag.frac or (S.duration > 0 and S.time / S.duration or 0)
    local ticks = (t.style == "win98" or t.style == "win31")
    if sx1 - sx0 > 30 * s then
        local gx0, gx1 = P:slider(sx0, y0 + s, sx1, y1, frac, ticks, 11, 20, dragging)
        hit("seek", sx0, y0, sx1, y1, { gx0 = gx0, gx1 = gx1, tip = "Seek" })
    end
    local shown = dragging and (frac * S.duration) or S.time
    P:text(tx1, floor((y0 + y1) / 2), 6, fmt_time(shown, long) .. " / " .. fmt_time(S.duration, long),
        c.text, t.font_size, false)
end

local function draw_controls(r)
    local t, c, s, m = S.theme, S.theme.c, S.s, S.theme.m
    local x0, y0, x1, y1 = r[1], r[2], r[3], r[4]
    local bw, bh = m.btn_w * s, m.btn_h * s
    local by = y0 + floor((y1 - y0 - bh) / 2)
    local gap = (t.style == "win31") and 0 or ((t.style == "win98") and 2 * s or 4 * s)
    local show_vol = (x1 - x0) > 400 * s
    local vol_x1 = x1 - 10 * s
    local vol_x0 = vol_x1 - 84 * s
    local mute_x0 = vol_x0 - 6 * s - bw
    local limit = show_vol and (mute_x0 - 8 * s) or (x1 - 8 * s)
    local x = x0 + 8 * s
    for _, it in ipairs(CTRL) do
        if not it then
            x = x + 8 * s
        else
            if x + bw > limit then break end
            local id = "btn:" .. it.id
            local fg, off, face = P:button(x, by, x + bw, by + bh, S.pressed == id,
                it.id == "fs" and S.fullscreen)
            local g = it.glyph or ((S.pause or S.idle) and "play" or "pause")
            local gx = x + floor((bw - 16 * s) / 2) + off
            local gy = by + floor((bh - 16 * s) / 2) + off
            if is_disabled(it.id) then P:glyph_disabled(g, gx, gy, face)
            else P:glyph(g, gx, gy, fg, face) end
            hit(id, x, by, x + bw, by + bh, it)
            x = x + bw + gap
        end
    end
    if show_vol then
        local id = "btn:mute"
        local fg, off, face = P:button(mute_x0, by, mute_x0 + bw, by + bh, S.pressed == id, S.mute)
        P:glyph(S.mute and "mute" or "speaker", mute_x0 + floor((bw - 16 * s) / 2) + off,
            by + floor((bh - 16 * s) / 2) + off, fg, face)
        hit(id, mute_x0, by, mute_x0 + bw, by + bh, { tip = "Mute (M)" })
        local vol = S.volume / 100
        local gx0, gx1 = P:slider(vol_x0, y0, vol_x1, y1, vol, false, 9, 16,
            S.drag and S.drag.kind == "vol")
        hit("vol", vol_x0, y0, vol_x1, y1, { gx0 = gx0, gx1 = gx1, tip = "Volume" })
    end
end

local function status_text()
    if S.status and mp.get_time() < S.status_until then return S.status end
    if S.menu and S.menu.hl then
        local it = S.menu.items[S.menu.hl]
        if it and it.plain then return it.plain end
    end
    local hh = S.hover_hit
    if hh and type(hh.data) == "table" and hh.data.tip then return hh.data.tip end
    if S.idle then return "Ready" end
    if S.stopped then return "Stopped" end
    return S.pause and "Paused" or "Playing"
end

local function draw_dialog(L)
    local t, c, s, m = S.theme, S.theme.c, S.s, S.theme.m
    local Dg = S.dialog
    local w, h = S.w, S.h
    local f, th = m.frame * s, m.title_h * s
    local fsz = t.font_size
    local width, body, title
    if Dg.kind == "adjust" then
        title, width, body = "Picture Adjustments", 340 * s, (#ADJ * 30 + 50) * s
    elseif Dg.kind == "about" then
        title, width, body = "About Classic Player", 340 * s, 200 * s
    else
        title, width, body = "Keyboard Shortcuts", 420 * s, 380 * s
    end
    local height = 2 * f + th + body
    local area = L.vbox or L.video
    local x0 = floor((area[1] + area[3] - width) / 2) + Dg.dx
    local y0 = floor((area[2] + area[4] - height) / 2) + Dg.dy
    x0 = clamp(x0, 0, max(0, w - width))
    y0 = clamp(y0, 0, max(0, h - height))
    local x1, y1 = x0 + width, y0 + height
    hit("dlg_block", 0, 0, w, h)
    local pr = S.pressed
    local cr, btn = P:dialog(x0, y0, x1, y1, title, pr == "dlg_close" and (S.pressed_tb or "tb:close") or nil)
    hit("dlg_title", x0 + f, y0 + f, x1 - f, y0 + f + th)
    for tb, r in pairs(btn) do hit("dlg_close", r[1], r[2], r[3], r[4], { tb = tb }) end
    local cx0, cy0, cx1, cy1 = cr[1], cr[2], cr[3], cr[4]
    local bw, bh = 76 * s, 24 * s

    if Dg.kind == "adjust" then
        for i, a in ipairs(ADJ) do
            local ry = cy0 + 10 * s + (i - 1) * 30 * s
            local val = mp.get_property_number(a[1]) or 0
            P:text(cx0 + 12 * s, ry + 12 * s, 4, a[2], c.text, fsz, t.bold)
            local sx0, sx1 = cx0 + 100 * s, cx1 - 52 * s
            local gx0, gx1 = P:slider(sx0, ry, sx1, ry + 24 * s, (val + 100) / 200, false, 9, 18,
                S.drag and S.drag.kind == "adj" and S.drag.h.data.prop == a[1])
            hit("adj", sx0, ry, sx1, ry + 24 * s, { prop = a[1], gx0 = gx0, gx1 = gx1, tip = a[2] })
            P:text(cx1 - 12 * s, ry + 12 * s, 6, string.format("%+d", floor(val + 0.5)), c.text, fsz)
        end
        local by = cy1 - bh - 10 * s
        P:text_button(cx1 - 2 * bw - 22 * s, by, cx1 - bw - 22 * s, by + bh, "Reset", pr == "dbtn:reset")
        hit("dbtn:reset", cx1 - 2 * bw - 22 * s, by, cx1 - bw - 22 * s, by + bh)
        P:text_button(cx1 - bw - 12 * s, by, cx1 - 12 * s, by + bh, "Close", pr == "dbtn:close")
        hit("dbtn:close", cx1 - bw - 12 * s, by, cx1 - 12 * s, by + bh)
    elseif Dg.kind == "about" then
        local mid = floor((cx0 + cx1) / 2)
        P:glyph("film", cx0 + 16 * s, cy0 + 16 * s, c.text, c.face, 2)
        P:text(cx0 + 64 * s, cy0 + 22 * s, 4, "Classic Player " .. VERSION, c.text, fsz + 3, true)
        P:text(cx0 + 64 * s, cy0 + 42 * s, 4, "A minimal media player with classic looks.", c.text, fsz)
        local eng = (mp.get_property("mpv-version") or "mpv"):gsub("^mpv ", "")
        local ff = mp.get_property("ffmpeg-version") or "?"
        P:text(cx0 + 16 * s, cy0 + 80 * s, 4, "Engine: mpv " .. eng, c.text, fsz, false,
            { cx0, cy0, cx1 - 8 * s, cy1 })
        P:text(cx0 + 16 * s, cy0 + 98 * s, 4, "Decoders: FFmpeg " .. ff .. " (built in)", c.text, fsz, false,
            { cx0, cy0, cx1 - 8 * s, cy1 })
        P:text(cx0 + 16 * s, cy0 + 116 * s, 4, "Theme: " .. t.name, c.text, fsz)
        local by = cy1 - bh - 12 * s
        P:text_button(mid - floor(bw / 2), by, mid + floor(bw / 2), by + bh, "OK", pr == "dbtn:ok")
        hit("dbtn:ok", mid - floor(bw / 2), by, mid + floor(bw / 2), by + bh)
    else
        local K = {
            { "Space", "Play / Pause" }, { "Left / Right", "Seek back / forward" },
            { "Up / Down", "Volume up / down" }, { "M", "Mute" },
            { "F, double-click", "Full screen" }, { "Esc", "Leave full screen / close menu" },
            { "Ctrl+O", "Open file" }, { "Ctrl+U", "Open URL" }, { "Ctrl+L", "Load subtitle" },
            { "V", "Show / hide subtitles" }, { "Z / Shift+Z", "Subtitle delay" },
            { "S / Shift+S", "Screenshot (without / with subs)" }, { "Ctrl+B", "Picture adjustments" },
            { "1 / 2", "Contrast - / +" }, { "3 / 4", "Brightness - / +" },
            { "7 / 8", "Saturation - / +" }, { "[ / ]", "Speed - / +" },
            { "Ctrl+T", "Next theme" }, { "Q", "Quit" },
        }
        for i, k in ipairs(K) do
            local yy = cy0 + 12 * s + (i - 1) * 16 * s
            P:text(cx0 + 16 * s, yy, 4, k[1], c.text, fsz, true)
            P:text(cx0 + 150 * s, yy, 4, k[2], c.text, fsz)
        end
        local mid = floor((cx0 + cx1) / 2)
        local by = cy1 - bh - 10 * s
        P:text_button(mid - floor(bw / 2), by, mid + floor(bw / 2), by + bh, "OK", pr == "dbtn:ok")
        hit("dbtn:ok", mid - floor(bw / 2), by, mid + floor(bw / 2), by + bh)
    end
end

render = function()
    if S.w <= 0 or S.h <= 0 or not S.theme then return end
    local t, c, s, m = S.theme, S.theme.c, S.s, S.theme.m
    local w, h = S.w, S.h
    local L = compute_layout()
    S.L = L
    apply_margins(L)
    S.hits = {}
    P:begin(t, s, S.font)

    hit_r("video", L.video)
    draw_video_area(L)

    if not S.fullscreen then
        local vb = L.vbox
        P:rect(0, 0, w, vb[2], c.face)
        P:rect(0, vb[4], w, h, c.face)
        P:rect(0, vb[2], vb[1], vb[4], c.face)
        P:rect(vb[3], vb[2], w, vb[4], c.face)
        P:video_inset(vb[1], vb[2], vb[3], vb[4])
        if L.show_frame then P:window_frame(0, 0, w, h, L.f, m.title_h * s) end
        if L.title then
            local r = L.title
            local name = S.idle and "" or S.title
            local txt
            if t.style == "win31" or t.style == "win98" then
                txt = (name ~= "") and ("Classic Player - " .. name) or "Classic Player"
            else
                txt = (name ~= "") and name or "Classic Player"
            end
            hit_r("title", r)
            local btn = P:title_bar(r[1], r[2], r[3], r[4], txt, S.pressed, "main")
            for id, br in pairs(btn) do hit(id, br[1], br[2], br[3], br[4]) end
        end
        -- menu bar
        local mb = L.menubar
        local items = {}
        local is_win = t.style == "win31" or t.style == "win98"
        local pad = (is_win and 7 or 9) * s
        local x = mb[1] + (is_win and 3 or 6) * s
        for i, md in ipairs(MENUBAR) do
            local ass, plain = Draw.accel(md.label, is_win)
            local tw = text_width(plain, t.font_size, t.bold)
            items[i] = { ass = ass, x0 = x, x1 = x + tw + 2 * pad }
            x = items[i].x1
        end
        S.mb_items = items
        P:menubar(mb[1], mb[2], mb[3], mb[4], items, S.menu and S.menu.idx)
        for i, it in ipairs(items) do hit("mb", it.x0, mb[2], it.x1, mb[4], i) end

        draw_seek(L.seek)
        draw_controls(L.ctrl)

        local st = L.status
        local right = S.mute and "Muted" or string.format("Vol %d%%", floor(S.volume + 0.5))
        if math.abs(S.speed - 1) > 0.001 then right = string.format("%gx  ", S.speed) .. right end
        P:statusbar(st[1], st[2], st[3], st[4], status_text(), right,
            text_width("0.75x  Vol 100%", t.font_size, false) + 12 * s)
        if L.show_frame then
            local f = L.f
            hit("rs:r", w - f, m.title_h * s + f, w, h)
            hit("rs:b", 0, h - f, w, h)
        end
        if not S.maximized then hit("rs:rb", st[3] - 16 * s, st[4] - 16 * s, w, h) end
    elseif L.panel then
        local p = L.panel
        P:rect(p[1], p[2], p[3], p[4], c.face)
        P:rect(p[1], p[2], p[3], p[2] + s, (t.style == "system7") and "000000" or c.light)
        draw_seek(L.seek)
        draw_controls(L.ctrl)
    end

    if S.menu then
        local M = S.menu
        hit("menu_bg", M.x0, M.y0, M.x1, M.y1)
        P:dropdown(M.x0, M.y0, M.x1, M.y1, M.items, M.hl)
        for i, it in ipairs(M.items) do
            if not it.sep then hit("mi", M.x0, it.y0, M.x1, it.y1, i) end
        end
    end
    if S.dialog then draw_dialog(L) end

    local data = P:result()
    if data ~= last_data or ui.res_x ~= w or ui.res_y ~= h then
        last_data = data
        ui.res_x, ui.res_y = w, h
        ui.data = data
        ui:update()
    end
end

local dirty = false
request = function() dirty = true end
mp.register_idle(function()
    if dirty then
        dirty = false
        render()
    end
end)

---------------------------------------------------------------------------
-- Mouse
---------------------------------------------------------------------------
local fs_timer
local function hover_key(hh)
    if not hh then return nil end
    local d = hh.data
    return hh.id .. ":" .. tostring(type(d) == "table" and (d.id or d.prop or d.tb or "") or (d or ""))
end

local function frac_of(hh, x)
    return clamp((x - hh.data.gx0) / max(1, hh.data.gx1 - hh.data.gx0), 0, 1)
end

local function do_drag(x, y)
    local d = S.drag
    if not d then return end
    local now = mp.get_time()
    if d.kind == "seek" then
        d.frac = frac_of(d.h, x)
        if not d.last or now - d.last > 0.06 then
            d.last = now
            mp.commandv("seek", tostring(d.frac * 100), "absolute-percent+keyframes")
        end
    elseif d.kind == "vol" then
        mp.set_property_number("volume", floor(frac_of(d.h, x) * 100 + 0.5))
    elseif d.kind == "adj" then
        mp.set_property_number(d.h.data.prop, floor(-100 + frac_of(d.h, x) * 200 + 0.5))
    elseif d.kind == "dlgmove" then
        S.dialog.dx = d.dx0 + (x - d.sx)
        S.dialog.dy = d.dy0 + (y - d.sy)
    elseif d.kind == "resize" then
        local nw = d.w0 + ((d.mode ~= "b") and (x - d.sx) or 0)
        local nh = d.h0 + ((d.mode ~= "r") and (y - d.sy) or 0)
        nw, nh = max(nw, 360 * S.s), max(nh, 260 * S.s)
        if (not d.last or now - d.last > 0.03) and (nw ~= d.lw or nh ~= d.lh) then
            d.last, d.lw, d.lh = now, nw, nh
            local k = (platform == "darwin") and (S.hidpi or 1) or 1
            mp.set_property("geometry", string.format("%dx%d", floor(nw / k), floor(nh / k)))
        end
    end
    request()
end

local function finish_drag(d, x)
    if d.kind == "seek" and d.frac then
        mp.commandv("seek", tostring(d.frac * 100), "absolute-percent+exact")
        S.time = d.frac * S.duration
    end
end

local function on_mouse_move(x, y, inside)
    S.mx, S.my, S.minside = x, y, inside
    if S.fullscreen then
        local was_visible = S.L and S.L.panel ~= nil
        S.fs_visible_until = mp.get_time() + opts.fs_hide_delay
        if fs_timer then fs_timer:kill() end
        fs_timer = mp.add_timeout(opts.fs_hide_delay + 0.05, function() request() end)
        if not was_visible then request() end
    end
    if S.drag then do_drag(x, y) return end
    local hh = inside and hit_at(x, y) or nil
    if S.menu then
        if hh and hh.id == "mi" then
            if S.menu.hl ~= hh.data then S.menu.hl = hh.data; request() end
        elseif hh and hh.id == "mb" and S.menu.idx and hh.data ~= S.menu.idx then
            open_menubar(hh.data)
        end
    end
    local key = hover_key(hh)
    if key ~= S.hover then
        S.hover, S.hover_hit = key, hh
        request()
    end
end

local last_down = { t = 0, x = -100, y = -100 }

local function mouse_down()
    local mpos = mp.get_property_native("mouse-pos")
    if mpos then S.mx, S.my = mpos.x, mpos.y end
    local x, y = S.mx, S.my
    local hh = hit_at(x, y)
    local id = hh and hh.id
    local now = mp.get_time()
    local tol = 5 * S.s
    local dbl = (now - last_down.t < 0.45) and math.abs(x - last_down.x) < tol and math.abs(y - last_down.y) < tol
    last_down.t, last_down.x, last_down.y = dbl and 0 or now, x, y

    if S.menu then
        if id == "mi" then S.pressed = "mi"
        elseif id == "mb" then
            if hh.data == S.menu.idx then close_menu() else open_menubar(hh.data) end
        elseif id ~= "menu_bg" then close_menu() end
        return
    end
    if not id or id == "dlg_block" then return end

    if id == "title" then
        if dbl then A.maximize()
        elseif not S.maximized then mp.commandv("begin-vo-dragging") end
    elseif id == "tb:sys" and dbl then
        A.quit()
    elseif id:find("^tb:") or id:find("^btn:") or id:find("^dbtn:") or id == "dlg_close" then
        S.pressed = id
        S.pressed_tb = (id == "dlg_close") and hh.data.tb or nil
        request()
    elseif id == "mb" then
        open_menubar(hh.data)
    elseif id == "seek" then
        if S.duration > 0 then S.drag = { kind = "seek", h = hh }; do_drag(x, y) end
    elseif id == "vol" or id == "adj" then
        S.drag = { kind = id, h = hh }
        do_drag(x, y)
    elseif id == "dlg_title" then
        S.drag = { kind = "dlgmove", sx = x, sy = y, dx0 = S.dialog.dx, dy0 = S.dialog.dy }
    elseif id:find("^rs:") then
        S.drag = { kind = "resize", mode = id:sub(4), sx = x, sy = y, w0 = S.w, h0 = S.h }
    elseif id == "video" and dbl then
        A.fullscreen()
    end
end

local function mouse_up()
    local x, y = S.mx, S.my
    local hh = hit_at(x, y)
    if S.drag then
        local d = S.drag
        S.drag = nil
        finish_drag(d, x)
        request()
        return
    end
    if S.menu then
        if hh and hh.id == "mi" then activate_item(hh.data) end
        S.pressed = nil
        return
    end
    local p = S.pressed
    if p then
        S.pressed = nil
        request()
        if hh and hh.id == p and BUTTONS[p] then BUTTONS[p]() end
    end
end

mp.add_forced_key_binding("MBTN_LEFT", "cp-mbtn-left", function(e)
    if e.event == "down" then mouse_down()
    elseif e.event == "up" then mouse_up() end
end, { complex = true })
mp.add_forced_key_binding("MBTN_LEFT_DBL", "cp-mbtn-dbl", function() end)
mp.add_forced_key_binding("MBTN_RIGHT", "cp-mbtn-right", function()
    if S.dialog then return end
    if S.menu then close_menu() return end
    local mpos = mp.get_property_native("mouse-pos")
    if mpos then S.mx, S.my = mpos.x, mpos.y end
    open_menu("context", S.mx, S.my, nil)
end)

mp.observe_property("mouse-pos", "native", function(_, v)
    if v then on_mouse_move(v.x, v.y, v.hover) end
end)

---------------------------------------------------------------------------
-- Keyboard
---------------------------------------------------------------------------
mp.add_key_binding("Ctrl+o", "open", A.open_files)
mp.add_key_binding("Ctrl+u", "open-url", A.open_url)
mp.add_key_binding("Ctrl+l", "load-subtitle", A.load_subtitle)
mp.add_key_binding("s", "screenshot", function() A.screenshot(false) end)
mp.add_key_binding("S", "screenshot-subs", function() A.screenshot(true) end)
mp.add_key_binding("Ctrl+b", "adjustments", function() A.dialog("adjust") end)
mp.add_key_binding("Ctrl+t", "next-theme", next_theme)
mp.add_key_binding("F1", "help", function() A.dialog("keys") end)
mp.add_key_binding("ESC", "escape", A.escape)
mp.add_key_binding("LEFT", "seek-back", function() A.seek(-opts.seek_step) end, { repeatable = true })
mp.add_key_binding("RIGHT", "seek-forward", function() A.seek(opts.seek_step) end, { repeatable = true })
mp.add_key_binding("UP", "volume-up", function() A.volume(5) end, { repeatable = true })
mp.add_key_binding("DOWN", "volume-down", function() A.volume(-5) end, { repeatable = true })
for i, md in ipairs(MENUBAR) do
    local k = md.label:match("&(.)"):lower()
    mp.add_key_binding("Alt+" .. k, "menu-" .. md.name, function()
        if S.fullscreen then return end
        open_menubar(i, true)
    end)
end
mp.register_script_message("set-theme", function(id) set_theme(id, true) end)

---------------------------------------------------------------------------
-- Property observers
---------------------------------------------------------------------------
local tick = mp.add_periodic_timer(0.25, function()
    local tp = mp.get_property_number("time-pos")
    if tp then S.time = tp; request() end
end)
tick:kill()

local function update_tick()
    if not S.pause and not S.idle then tick:resume() else tick:kill() end
    S.time = mp.get_property_number("time-pos") or 0
end

mp.observe_property("osd-dimensions", "native", function(_, v)
    if v and v.w and v.w > 0 then S.w, S.h = v.w, v.h; request() end
end)
mp.observe_property("display-hidpi-scale", "number", function(_, v)
    S.hidpi = v or 1
    update_scale()
    request()
end)
mp.observe_property("pause", "bool", function(_, v)
    S.pause = v
    if not v then S.stopped = false end
    update_tick()
    request()
end)
mp.observe_property("idle-active", "bool", function(_, v)
    S.idle = v
    if v then S.time, S.duration = 0, 0 end
    update_tick()
    request()
end)
mp.observe_property("duration", "number", function(_, v) S.duration = v or 0; request() end)
mp.observe_property("volume", "number", function(_, v) S.volume = v or 0; request() end)
mp.observe_property("mute", "bool", function(_, v) S.mute = v; request() end)
mp.observe_property("speed", "number", function(_, v) S.speed = v or 1; request() end)
mp.observe_property("fullscreen", "bool", function(_, v)
    S.fullscreen = v
    close_menu()
    S.fs_visible_until = mp.get_time() + opts.fs_hide_delay
    request()
end)
mp.observe_property("window-maximized", "bool", function(_, v) S.maximized = v; request() end)
mp.observe_property("media-title", "string", function(_, v) S.title = v or ""; request() end)
mp.observe_property("video-out-params", "native", function(_, v)
    S.has_video = (v ~= nil and next(v) ~= nil)
    request()
end)
mp.observe_property("playlist-count", "number", function(_, v) S.pl_count = v or 0; request() end)
mp.observe_property("playlist-pos", "number", function(_, v) S.pl_pos = v or -1; request() end)
for _, a in ipairs(ADJ) do
    mp.observe_property(a[1], "number", function() if S.dialog then request() end end)
end
mp.register_event("playback-restart", function()
    S.time = mp.get_property_number("time-pos") or S.time
    request()
end)
mp.register_event("file-loaded", function()
    S.stopped = false
    S.meta = {
        artist = mp.get_property("metadata/by-key/Artist"),
        album = mp.get_property("metadata/by-key/Album"),
    }
    request()
end)
mp.register_event("shutdown", save_state)

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------
local st = opts.remember and load_state() or {}
if st.classic_frame then opts.classic_frame = (st.classic_frame == "true") end
if st.ui_scale then opts.ui_scale = tonumber(st.ui_scale) or 0 end
if st.volume and tonumber(st.volume) then mp.set_property_number("volume", tonumber(st.volume)) end
if not opts.classic_frame then mp.set_property_bool("border", true) end
update_scale()
set_theme(st.theme or opts.theme, false)
msg.verbose("Classic Player " .. VERSION .. " started (" .. platform .. ")")
