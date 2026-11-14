-- playlist-viewer.lua
-- Telescope-style playlist viewer for mpv (companion to keymap-viewer.lua)
-- Default trigger: \  (override in script-opts/playlist-viewer.conf: key=<key>)
--
--   type            filter (space-separated words must all match)
--   ↑↓ PgUp PgDn    navigate        Home / End   first / last
--   Enter           play selected   Del          remove from playlist
--   Shift+↑↓        move entry      Ctrl+u       clear search
--   Esc  (or \ with an empty search)   close

local mp    = require 'mp'
local opts  = require 'mp.options'

local cfg = {
    key           = '\\',
    max_visible   = 20,
    font          = 'monospace',
    font_size     = 13,
    panel_width   = 944,    -- in 720p-space units, shrinks to fit narrow windows
    close_on_play = true,
}
opts.read_options(cfg, 'playlist-viewer')

-- Colours are ASS BGR, kept identical to keymap-viewer for a consistent look
local C = {
    bg        = '0D0D0D',
    accent    = '00CCCC',
    border    = '333333',
    search_bg = '1A1A1A',
    sel_bg    = '1E3A3A',
    sep       = '2A2A2A',
    footer_bg = '111111',
    footer    = '505050',
    header    = '555555',
    count     = '666666',
    index     = 'AAAA00',
    text      = '999999',
    dim       = '444444',
    playing   = '44BB77',
    white     = 'FFFFFF',
}

-- ── state ────────────────────────────────────────────────────────────────────

local ov = mp.create_osd_overlay('ass-events')

local st = {
    active = false,
    query  = '',
    sel    = 1,
    offset = 0,
    all    = {},
    list   = {},   -- filtered
    tokens = {},
}

-- ── text helpers ─────────────────────────────────────────────────────────────

-- Same rules as mpv's `escape-ass` command
local function esc_ass(s)
    return (tostring(s):gsub('\\', '\\\226\129\160'):gsub('{', '\\{'):gsub('\n', ' '))
end

-- Display width of one UTF-8 character (CJK / fullwidth / emoji count as 2)
local function char_width(c)
    local b1 = c:byte(1)
    if b1 < 0x80 then return 1 end
    local b2, b3, b4 = (c:byte(2) or 0x80) % 64, (c:byte(3) or 0x80) % 64, (c:byte(4) or 0x80) % 64
    local cp
    if b1 >= 0xF0 then     cp = (b1 % 8) * 0x40000 + b2 * 0x1000 + b3 * 0x40 + b4
    elseif b1 >= 0xE0 then cp = (b1 % 16) * 0x1000 + b2 * 0x40 + b3
    else                   cp = (b1 % 32) * 0x40 + b2 end
    if (cp >= 0x0300 and cp <= 0x036F) or (cp >= 0x200B and cp <= 0x200F) then return 0 end
    if (cp >= 0x1100 and cp <= 0x115F) or (cp >= 0x2E80 and cp <= 0xA4CF)
        or (cp >= 0xAC00 and cp <= 0xD7A3) or (cp >= 0xF900 and cp <= 0xFAFF)
        or (cp >= 0xFE30 and cp <= 0xFE4F) or (cp >= 0xFF00 and cp <= 0xFF60)
        or (cp >= 0xFFE0 and cp <= 0xFFE6) or (cp >= 0x1F300 and cp <= 0x1FAFF)
        or (cp >= 0x20000 and cp <= 0x3FFFD)
    then return 2 end
    return 1
end

local UTF8_CHAR = '[%z\1-\127\194-\244][\128-\191]*'

-- Cut s to at most `max` display columns, adding … when shortened
local function truncate(s, max)
    if max <= 0 then return '' end
    local w = 0
    for c in s:gmatch(UTF8_CHAR) do w = w + char_width(c) end
    if w <= max then return s end
    local out, used = {}, 0
    for c in s:gmatch(UTF8_CHAR) do
        local cw = char_width(c)
        if used + cw > max - 1 then break end
        out[#out+1] = c
        used = used + cw
    end
    return table.concat(out) .. '…'
end

-- Colour s with `base`, painting every occurrence of a search token in `hl`
local function highlight(s, base, hl)
    if #st.tokens == 0 or s == '' then
        return '{\\c&H' .. base .. '&}' .. esc_ass(s)
    end
    local ls, marks = s:lower(), {}
    for _, t in ipairs(st.tokens) do
        local p = 1
        while true do
            local a, b = ls:find(t, p, true)
            if not a then break end
            for k = a, b do marks[k] = true end
            p = b + 1
        end
    end
    local out, i, n = {}, 1, #s
    while i <= n do
        local on, j = marks[i] or false, i
        while j < n and (marks[j + 1] or false) == on do j = j + 1 end
        local seg = esc_ass(s:sub(i, j))
        if on then
            out[#out+1] = '{\\c&H' .. hl .. '&\\b1}' .. seg .. '{\\b0}'
        else
            out[#out+1] = '{\\c&H' .. base .. '&}' .. seg
        end
        i = j + 1
    end
    return table.concat(out)
end

-- ── data ─────────────────────────────────────────────────────────────────────

local function is_url(s) return s:match('^%a[%w+.-]*://') ~= nil end

-- Backslash is only a path separator on Windows; on Linux it's a legal filename char
local SEP = mp.get_property('platform', '') == 'windows' and '/\\' or '/'

local function basename(p)
    return p:gsub('[' .. SEP .. ']+$', ''):match('([^' .. SEP .. ']+)$') or p
end

local function describe(e)
    local fn = e.filename or ''
    local name, loc
    if is_url(fn) then
        local host = fn:match('^%a[%w+.-]*://([^/?#]+)') or ''
        loc  = host:gsub('^www%.', '')
        name = fn:gsub('^%a[%w+.-]*://', ''):gsub('^www%.', '')
    else
        name = basename(fn)
        loc  = fn:match('([^' .. SEP .. ']+)[' .. SEP .. ']+[^' .. SEP .. ']+[' .. SEP .. ']*$')
               or basename(mp.get_property('working-directory', '') or '')
    end
    if e.title and e.title ~= '' then
        name = e.title
    elseif e.playing then
        -- ytdl and tagged files get a proper title once loaded
        local mt = mp.get_property('media-title', '')
        if mt ~= '' then name = mt end
    end
    return name, loc
end

local function collect()
    local out = {}
    for i, e in ipairs(mp.get_property_native('playlist') or {}) do
        local name, loc = describe(e)
        out[#out+1] = {
            idx     = i,
            id      = e.id or i,
            name    = name,
            loc     = loc,
            playing = e.playing or e.current or false,
            hay     = (name .. '\0' .. loc .. '\0' .. (e.filename or '')):lower(),
        }
    end
    return out
end

local function apply_filter()
    st.tokens = {}
    for t in st.query:lower():gmatch('%S+') do st.tokens[#st.tokens+1] = t end
    if #st.tokens == 0 then st.list = st.all; return end
    local res = {}
    for _, e in ipairs(st.all) do
        local ok = true
        for _, t in ipairs(st.tokens) do
            if not e.hay:find(t, 1, true) then ok = false; break end
        end
        if ok then res[#res+1] = e end
    end
    st.list = res
end

-- Rebuild while keeping the cursor on the same entry (by id) when possible
local function refresh(select_playing)
    local keep = st.list[st.sel] and st.list[st.sel].id
    st.all = collect()
    apply_filter()
    local found = false
    for i, e in ipairs(st.list) do
        if (select_playing and e.playing) or (not select_playing and e.id == keep) then
            st.sel, found = i, true
            break
        end
    end
    if not found then st.sel = math.min(math.max(st.sel, 1), math.max(#st.list, 1)) end
end

-- ── rendering ────────────────────────────────────────────────────────────────

local function make_rect(x1, y1, x2, y2, color)
    return string.format(
        '{\\an7\\pos(0,0)\\p1\\c&H%s&\\1a&H00&\\3a&HFF&\\4a&HFF&\\bord0\\shad0}' ..
        'm %d %d l %d %d l %d %d l %d %d{\\p0}',
        color, x1, y1, x2, y1, x2, y2, x1, y2)
end

local function text(x, y, size, body, align)
    return string.format('{\\an%d\\pos(%d,%d)\\q2\\fn%s\\fs%d\\bord0\\shad0}%s',
        align or 7, x, y, cfg.font, size, body)
end

local function clamp_scroll()
    local n = cfg.max_visible
    if st.sel < st.offset + 1 then st.offset = st.sel - 1 end
    if st.sel > st.offset + n then st.offset = st.sel - n end
    st.offset = math.min(math.max(st.offset, 0), math.max(0, #st.list - n))
end

local function render()
    if not st.active then return end

    -- Keep a 720-unit tall canvas matching the window aspect so nothing stretches
    local d = mp.get_property_native('osd-dimensions') or {}
    local w, h = d.w or 0, d.h or 0
    if w <= 0 or h <= 0 then w, h = 1280, 720 end
    ov.res_y = 720
    ov.res_x = math.floor(720 * w / h + 0.5)

    local L     = {}
    local fs    = cfg.font_size
    local row_h = fs + 4
    local cw    = fs * 0.6                       -- monospace advance
    local x, y  = 32, 20

    local n_shown  = math.min(cfg.max_visible, math.max(1, #st.list))
    local px1, py1 = 16, 10
    local px2      = px1 + math.min(cfg.panel_width, ov.res_x - 2 * px1)
    local py2      = py1 + 80 + n_shown * row_h + 30

    -- columns: marker | index | title | location
    local digits  = math.max(2, #tostring(#st.all))
    local col_mk  = x + 4
    local col_idx = col_mk + math.floor(cw * 2)
    local col_ttl = col_idx + math.floor(cw * (digits + 2))
    local loc_ch  = math.max(8, math.floor((px2 - px1) * 0.22 / cw))
    local col_loc = px2 - 20 - math.floor(loc_ch * cw)
    local ttl_ch  = math.max(8, math.floor((col_loc - col_ttl) / cw) - 2)

    -- ── background ──
    L[#L+1] = make_rect(px1, py1, px2, py2, C.bg)
    L[#L+1] = make_rect(px1, py1, px2, py1 + 3, C.accent)
    L[#L+1] = make_rect(px1, py2 - 1, px2, py2, C.border)
    L[#L+1] = make_rect(px1, py1, px1 + 1, py2, C.border)
    L[#L+1] = make_rect(px2 - 1, py1, px2, py2, C.border)

    -- ── header ──
    L[#L+1] = text(x, y, fs + 4, string.format(
        '{\\c&H%s&\\b1}☰  MPV Playlist{\\b0\\c&H%s&}  %d / %d',
        C.accent, C.count, #st.list, #st.all))

    local pos   = mp.get_property_number('playlist-pos-1', 0)
    local flags = {}
    if pos > 0 then flags[#flags+1] = string.format('▶ %d of %d', pos, #st.all) end
    local lp = mp.get_property('loop-playlist', 'no')
    if lp ~= 'no' then flags[#flags+1] = 'loop ' .. lp end
    if mp.get_property('loop-file', 'no') ~= 'no' then flags[#flags+1] = 'loop file' end
    if #flags > 0 then
        L[#L+1] = text(px2 - 16, y + 3, fs - 1,
            '{\\c&H' .. C.count .. '&}' .. esc_ass(table.concat(flags, '   ')), 9)
    end

    -- ── search bar ──
    y = y + 26
    L[#L+1] = make_rect(px1 + 1, y - 4, px2 - 1, y + fs + 4, C.search_bg)
    local qdisp = st.query ~= '' and ('{\\c&H' .. C.white .. '&}' .. esc_ass(st.query))
                  or ('{\\c&H' .. C.dim .. '&}type to search…')
    L[#L+1] = text(x, y, fs, '{\\c&H' .. C.white .. '&}/ ' .. qdisp ..
                   '{\\c&H' .. C.accent .. '&}▌')

    -- ── column headers ──
    y = y + 24
    local hdr = '{\\c&H' .. C.header .. '&\\b1}'
    L[#L+1] = text(col_idx, y, fs - 2, hdr .. '#')
    L[#L+1] = text(col_ttl, y, fs - 2, hdr .. 'TITLE')
    L[#L+1] = text(col_loc, y, fs - 2, hdr .. 'LOCATION')
    y = y + 12
    L[#L+1] = make_rect(px1 + 1, y, px2 - 1, y + 1, C.sep)

    -- ── entries ──
    y = y + 8
    local entries_y0 = y
    clamp_scroll()

    if #st.list == 0 then
        L[#L+1] = text(x, y, fs, '{\\c&H' .. C.header .. '&}  ' ..
            (#st.all == 0 and '(playlist is empty)' or '(no matches)'))
        y = y + row_h
    else
        for i = st.offset + 1, math.min(st.offset + cfg.max_visible, #st.list) do
            local e   = st.list[i]
            local sel = (i == st.sel)

            if sel then
                L[#L+1] = make_rect(px1 + 1, y - 2, px2 - 1, y + fs + 2, C.sel_bg)
                L[#L+1] = make_rect(px1 + 1, y - 2, px1 + 3, y + fs + 2, C.accent)
            end

            if e.playing then
                L[#L+1] = text(col_mk, y, fs, '{\\c&H' .. C.playing .. '&}▶')
            end

            local idx_s  = string.rep(' ', digits - #tostring(e.idx)) .. e.idx
            local idx_c  = sel and C.accent or (e.playing and C.playing or C.index)
            L[#L+1] = text(col_idx, y, fs,
                (sel and '{\\b1}' or '') .. '{\\c&H' .. idx_c .. '&}' .. idx_s)

            local ttl_c = sel and C.white or (e.playing and C.playing or C.text)
            L[#L+1] = text(col_ttl, y, fs, highlight(truncate(e.name, ttl_ch), ttl_c, C.accent))

            local loc_c = sel and C.playing or C.dim
            L[#L+1] = text(col_loc, y, fs, highlight(truncate(e.loc, loc_ch), loc_c, C.accent))

            y = y + row_h
        end
    end

    -- ── scrollbar ──
    if #st.list > cfg.max_visible then
        local track_h = cfg.max_visible * row_h
        local frac    = st.offset / math.max(1, #st.list - cfg.max_visible)
        local thumb_h = math.max(8, math.floor(track_h * cfg.max_visible / #st.list))
        local thumb_y = entries_y0 + math.floor(frac * (track_h - thumb_h))
        L[#L+1] = make_rect(px2 - 8, entries_y0, px2 - 3, entries_y0 + track_h, '222222')
        L[#L+1] = make_rect(px2 - 8, thumb_y, px2 - 3, thumb_y + thumb_h, C.accent)
    end

    -- ── footer ──
    y = y + 6
    L[#L+1] = make_rect(px1 + 1, y - 4, px2 - 1, py2 - 1, C.footer_bg)
    L[#L+1] = text(x, y, 9, '{\\c&H' .. C.footer .. '&}' ..
        '↑↓ PgUp PgDn  navigate    Enter  play    Del  remove    ' ..
        'Shift+↑↓  move    Ctrl+U  clear    Esc  close')

    ov.data = table.concat(L, '\n')
    ov:update()
end

-- ── actions ──────────────────────────────────────────────────────────────────

local bound_names = {}

local function bind(key, name, fn, flags)
    bound_names[#bound_names+1] = name
    mp.add_forced_key_binding(key, name, fn, flags)
end

local function move_sel(delta)
    if #st.list == 0 then return end
    st.sel = math.min(math.max(st.sel + delta, 1), #st.list)
    render()
end

local function set_query(q)
    st.query  = q
    st.sel    = 1
    st.offset = 0
    apply_filter()
    render()
end

local function on_change() refresh(false); render() end

local function close_viewer()
    if not st.active then return end
    st.active = false
    ov:remove()
    for _, name in ipairs(bound_names) do mp.remove_key_binding(name) end
    bound_names = {}
    mp.unobserve_property(on_change)
    mp.unobserve_property(render)
end

local function play_selected()
    local e = st.list[st.sel]
    if not e then return end
    mp.commandv('playlist-play-index', tostring(e.idx - 1))
    if cfg.close_on_play then close_viewer() end
end

local function remove_selected()
    local e = st.list[st.sel]
    if not e then return end
    mp.commandv('playlist-remove', tostring(e.idx - 1))
    on_change()   -- sync now so fast repeats act on fresh indexes
end

local function move_entry(dir)
    local e = st.list[st.sel]
    if not e then return end
    if st.query ~= '' then
        mp.osd_message('Clear the search to reorder', 1.5)
        return
    end
    local i = e.idx - 1                         -- 0-based
    if dir < 0 and i > 0 then
        mp.commandv('playlist-move', tostring(i), tostring(i - 1))
    elseif dir > 0 and i < #st.all - 1 then
        mp.commandv('playlist-move', tostring(i), tostring(i + 2))
    end
    on_change()   -- sync now; refresh() keeps the cursor on the moved entry via its id
end

local function text_input(t)
    if t.key_text and (t.event == 'press' or t.event == 'down' or t.event == 'repeat') then
        -- the trigger key closes again while the search is empty, otherwise it types
        if t.key_text == cfg.key and st.query == '' and t.event ~= 'repeat' then
            close_viewer()
            return
        end
        set_query(st.query .. t.key_text)
    end
end

local function backspace()
    if st.query == '' then return end
    -- drop one whole UTF-8 character
    set_query(st.query:gsub('[%z\1-\127\194-\244][\128-\191]*$', ''))
end

local function delete_word()
    set_query(st.query:gsub('%s*%S+%s*$', ''))
end

local function open_viewer()
    if st.active then close_viewer(); return end
    st.active   = true
    st.query    = ''
    st.sel      = 1
    st.offset   = 0
    st.list     = {}
    bound_names = {}
    refresh(true)
    st.offset   = st.sel - math.floor(cfg.max_visible / 2)   -- centre the playing entry

    local rep = { repeatable = true }
    bind('UP',          'pv-up',     function() move_sel(-1) end, rep)
    bind('DOWN',        'pv-down',   function() move_sel(1) end, rep)
    bind('WHEEL_UP',    'pv-wup',    function() move_sel(-3) end)
    bind('WHEEL_DOWN',  'pv-wdown',  function() move_sel(3) end)
    bind('PGUP',        'pv-pgup',   function() move_sel(-cfg.max_visible) end, rep)
    bind('PGDWN',       'pv-pgdn',   function() move_sel(cfg.max_visible) end, rep)
    bind('HOME',        'pv-home',   function() move_sel(-math.huge) end)
    bind('END',         'pv-end',    function() move_sel(math.huge) end)
    bind('Shift+UP',    'pv-mvup',   function() move_entry(-1) end, rep)
    bind('Shift+DOWN',  'pv-mvdown', function() move_entry(1) end, rep)
    bind('ENTER',       'pv-enter',  play_selected)
    bind('KP_ENTER',    'pv-kpent',  play_selected)
    bind('MBTN_LEFT_DBL', 'pv-dbl',  play_selected)
    bind('DEL',         'pv-del',    remove_selected, rep)
    bind('ESC',         'pv-esc',    close_viewer)
    bind('BS',          'pv-bs',     backspace, rep)
    bind('Ctrl+h',      'pv-ch',     backspace, rep)
    bind('Ctrl+BS',     'pv-cbs',    delete_word, rep)
    bind('Ctrl+w',      'pv-cw',     delete_word, rep)
    bind('Ctrl+u',      'pv-cu',     function() set_query('') end)
    bind('ANY_UNICODE', 'pv-text',   text_input, { repeatable = true, complex = true })

    -- live updates while open (fires once immediately, which also draws)
    mp.observe_property('playlist', 'none', on_change)
    mp.observe_property('media-title', 'none', on_change)
    mp.observe_property('loop-playlist', 'none', render)
    mp.observe_property('loop-file', 'none', render)
    mp.observe_property('osd-dimensions', 'none', render)
end

mp.add_key_binding(cfg.key, 'playlist-viewer', open_viewer)
mp.register_script_message('playlist-viewer-toggle', open_viewer)
