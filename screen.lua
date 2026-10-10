-- ===== TINY FACTORY STATUS SCREEN (render script, paste into the screen in Lua mode) =====
-- fix: shows EVERY TF machine, fitted to the whole screen.
-- Why it changed: the old screen got one message of at most ~1024 characters from the screen board, which on a big
-- factory held only about 20 machines, and drew them in one fixed-size column. Now the board sends the list in pages
-- ("#TF2" header line + one short line per machine), one page per second. This script keeps every machine it has
-- seen (screen globals survive between runs), so the whole factory is on screen once all pages have arrived.
-- Layout: it picks the number of columns (1-3) and the font size that fit all rows on this screen's resolution.
-- Needs the matching screen board (pb_screen, same change).

--- settings (safe to change) ---
local HUB_LABELS  = { "Inputs", " ", " ", "Outputs" } -- labels for the hubs under the screen; {} hides the strip
local SORT_BY     = "status" -- "status": problems first, then running, then the rest; "board": chef, line1-4, waitress
local MAX_COLUMNS = 3        -- most side-by-side columns of machines
local MIN_FONT    = 9        -- smallest text size; if even this does not fit, the last rows are left out (+N more)
local MAX_FONT    = 20       -- largest text size (few machines)
local FONT_NAME   = "RobotoMono"
local REDRAW_FRAMES = 4000   -- extra redraw every N frames, same as the old screen. The screen also redraws when a
                             -- new page arrives. If machines show up slowly or not at all, try 30.
--- end of settings ---

-- Colours (r, g, b, alpha)
local C = {
    bg     = { 0.03, 0.05, 0.07 },
    head   = { 0.35, 0.75, 1.00, 0.10 },
    stripe = { 1, 1, 1, 0.035 },
    text   = { 0.88, 0.92, 0.95, 1 },
    dim    = { 0.50, 0.58, 0.65, 1 },
    accent = { 0.35, 0.75, 1.00, 1 },
    green  = { 0.30, 0.85, 0.45, 1 },
    yellow = { 1.00, 0.78, 0.20, 1 },
    red    = { 1.00, 0.32, 0.30, 1 },
    grey   = { 0.55, 0.60, 0.66, 1 },
    track  = { 1, 1, 1, 0.10 },
    met    = { 0.50, 0.58, 0.65, 0.55 }, -- stock bar at/over target: recedes (green is reserved for 'running')
}

-- State codes sent by the board -> label, colour, sort rank (lower = shown first).
-- W = "missing ingredient" (game state 3): normal for TF (the machine waits for its inputs), except on a refiner,
-- where it means no ore arrived (upstream screen showed that one as "NEED ORE" in red; kept).
local STATES = {
    S = { "NO SCHEM", C.red,    1 },
    X = { "REFUSED",  C.red,    1 }, -- a machine did not take an item (from a cook board's refusal list)
    M = { "MISSING",  C.yellow, 1 }, -- no TF machine of the right type/tier for this item
    O = { "NEED ORE", C.red,    1 },
    F = { "FULL",     C.yellow, 2 },
    N = { "NO CONT.", C.yellow, 2 },
    R = { "Running",  C.green,  3 },
    W = { "Waiting",  C.grey,   4 },
    P = { "Pending",  C.grey,   4 },
    I = { "Idle",     C.dim,    5 },
}
local UNKNOWN = { "?", C.dim, 6 }

-- Board codes sent by the board: C = chef, 1-9 = linecook1-9, W = waitress.
local function boardLabel(code)
    if code == "C" then return "chef", 1 end
    if code == "W" then return "wait", 20 end
    if code == "L" then return "lines", 15 end -- MISSING rows for the linecook list (any line)
    local n = tonumber(code)
    if n then return "L" .. n, 1 + n end
    return code, 30
end

---------------------------------------------------------------------------------------------------------------------
-- 1. Collect pages. Globals (TF) persist between runs of this script; locals do not.
---------------------------------------------------------------------------------------------------------------------
if not TF then
    TF = { rows = {}, meta = nil, scan = -1, lastInput = nil }
end

local function readInput(input)
    local first = true
    local scan, page, pages
    for line in input:gmatch("[^\n]+") do
        if first then
            first = false
            -- #TF2|scan|page|pages|machines|manager version|lines|feed x|line x|description
            local s, p, ps, n, mv, nl, fm, lm, desc =
                line:match("^#TF2|(%d+)|(%d+)|(%d+)|(%d+)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
            if not s then return end -- not our format (e.g. " ... pending ... ")
            scan, page, pages = tonumber(s), tonumber(p), tonumber(ps)
            if scan < TF.scan then TF.rows = {} end -- the board restarted: its scan counter began again
            TF.scan = scan
            TF.meta = { machines = tonumber(n), manager = mv, lines = nl, feed = fm, linex = lm, desc = desc }
        else
            -- id,board,machine,state,current,maintain,item (the item name takes the rest, commas and all)
            local id, b, m, st, cur, max, item = line:match("^([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),(.*)$")
            if id then
                TF.rows[id] = { board = b, machine = m, st = st, cur = tonumber(cur) or 0, max = tonumber(max) or 0,
                    item = item, scan = scan }
            end
        end
    end
    -- After the last page of a scan, forget machines missing from this scan AND the one before (one missed page
    -- must not make a machine flicker off the screen; a removed machine disappears after two scans).
    if scan and page == pages then
        for id, r in pairs(TF.rows) do
            if r.scan < scan - 1 then TF.rows[id] = nil end
        end
    end
end

requestAnimationFrame(REDRAW_FRAMES)
local input = getInput()
if input ~= TF.lastInput then
    TF.lastInput = input
    readInput(input)
end

---------------------------------------------------------------------------------------------------------------------
-- 2. Sort rows and count states.
---------------------------------------------------------------------------------------------------------------------
local list, counts = {}, { good = 0, wait = 0, warn = 0, bad = 0 }
for _, r in pairs(TF.rows) do
    local code = r.st
    if code == "W" and r.machine:find("^Refiner") then code = "O" end
    local s = STATES[code] or UNKNOWN
    r.label, r.color, r.rank = s[1], s[2], s[3]
    r.boardText, r.boardRank = boardLabel(r.board)
    if r.rank == 1 then counts.bad = counts.bad + 1
    elseif r.rank == 2 then counts.warn = counts.warn + 1
    elseif r.rank == 3 then counts.good = counts.good + 1
    else counts.wait = counts.wait + 1 end
    list[#list + 1] = r
end

table.sort(list, function(a, b)
    local k1a, k1b, k2a, k2b = a.rank, b.rank, a.boardRank, b.boardRank
    if SORT_BY == "board" then k1a, k1b, k2a, k2b = k2a, k2b, k1a, k1b end
    if k1a ~= k1b then return k1a < k1b end
    if k2a ~= k2b then return k2a < k2b end
    if a.machine ~= b.machine then return a.machine < b.machine end
    return a.item < b.item
end)

---------------------------------------------------------------------------------------------------------------------
-- 3. Layout: header, footer, then choose columns + font size so all rows fit.
---------------------------------------------------------------------------------------------------------------------
local rx, ry = getResolution()
local unit = ry / 613 -- 1.0 on a standard screen; everything scales with the resolution
setBackgroundColor(C.bg[1], C.bg[2], C.bg[3])
local lBack = createLayer() -- boxes and bars
local lText = createLayer() -- text, on top

local function fill(layer, c) setNextFillColor(layer, c[1], c[2], c[3], c[4] or 1) end
local function text(font, s, x, y, c, alignH)
    fill(lText, c)
    setNextTextAlign(lText, alignH or AlignH_Left, AlignV_Middle)
    addText(lText, font, s, x, y)
end

local pad = math.floor(16 * unit) -- side margin; the screen frame hides a few pixels at the edges
local headH = math.floor(56 * unit)
local footH = (#HUB_LABELS > 0) and math.floor(20 * unit) or 0

-- Header
local fTitle = loadFont(FONT_NAME, math.floor(17 * unit))
local fSmall = loadFont(FONT_NAME, math.floor(12 * unit))
fill(lBack, C.head)
addBox(lBack, 0, 0, rx, headH)
local m = TF.meta
local row1, row2 = headH * 0.32, headH * 0.74
text(fTitle, "TINY FACTORY" .. ((m and m.desc ~= "") and ("  " .. m.desc) or ""), pad, row1, C.accent)
if m then
    text(fSmall, "Manager " .. m.manager .. "   " .. m.lines .. " lines   Feed x" .. m.feed .. "   Line x" .. m.linex,
        rx - pad, row1, C.dim, AlignH_Right)
end

-- State summary: coloured dot + count
local x = pad
local dot = math.max(3, math.floor(4 * unit))
for _, s in ipairs({ { counts.good, "running", C.green }, { counts.wait, "waiting/idle", C.grey },
    { counts.warn, "jammed", C.yellow }, { counts.bad, "need attention", C.red } }) do
    fill(lBack, s[3])
    addCircle(lBack, x + dot, row2, dot)
    local label = s[1] .. " " .. s[2]
    text(fSmall, label, x + dot * 3, row2, (s[1] > 0 or s[3] == C.green) and C.text or C.dim)
    x = x + dot * 3 + getTextBounds(fSmall, label) + pad * 2
end

-- Footer: hub labels, centred on equal-width slots (same places as the old screen)
if footH > 0 then
    local w = rx / #HUB_LABELS
    for i, label in ipairs(HUB_LABELS) do
        text(fSmall, label, w * (i - 0.5), ry - footH / 2, C.dim, AlignH_Center)
    end
end

-- Body
local top, bottom = headH + pad * 0.6, ry - footH - pad * 0.4
local H = bottom - top
local n = #list

if n == 0 then
    text(fTitle, "Waiting for data from the screen board ...", rx / 2, top + H / 2, C.dim, AlignH_Center)
    return
end

-- Width of the fixed columns in characters
local machineChars, qtyChars = 6, 3
for _, r in ipairs(list) do
    machineChars = math.max(machineChars, #r.machine)
    local q = (r.max > 0) and (r.cur .. "/" .. r.max) or tostring(r.cur)
    r.qty = q
    qtyChars = math.max(qtyChars, #q)
end
machineChars = math.min(machineChars, 18)
local ITEM_CHARS = 22 -- room we would like for the product name
local needChars = 4 + machineChars + 8 + qtyChars + ITEM_CHARS + 5 -- + gaps
local CHAR_W, LINE_H = 0.6, 1.35 -- RobotoMono: a character is 0.6 em wide; a row is 1.35 x the font size

local gap = pad * 1.5
local best = { size = -1 }
for cols = 1, MAX_COLUMNS do
    local perCol = math.ceil(n / cols)
    local colW = (rx - pad * 2 - gap * (cols - 1)) / cols
    local size = math.min(H / perCol / LINE_H, colW / needChars / CHAR_W, MAX_FONT * unit)
    if size > best.size + 0.5 then best = { size = size, cols = cols, perCol = perCol, colW = colW } end
end

local size = math.max(math.floor(best.size), MIN_FONT)
local perCol = math.min(best.perCol, math.floor(H / (size * LINE_H)))
local shown = math.min(n, perCol * best.cols)
local rowH = math.min(H / perCol, size * 1.9)
local font = loadFont(FONT_NAME, size)
local cw = getTextBounds(font, "0000000000") / 10 -- real character width of this font

-- Column x offsets inside one panel
local xBoard = 6 * unit
local xMachine = xBoard + cw * 5
local xState = xMachine + cw * (machineChars + 1)
local xQtyRight = xState + cw * (8 + 1) + cw * qtyChars
local xItem = xQtyRight + cw * 1.5
local itemChars = math.max(4, math.floor((best.colW - xItem) / cw))

local function cut(s, maxChars)
    if #s <= maxChars then return s end
    return s:sub(1, maxChars - 2) .. ".."
end

for i = 1, shown do
    local r = list[i]
    local col = math.floor((i - 1) / perCol)
    local rowInCol = (i - 1) % perCol
    local x0 = pad + col * (best.colW + gap)
    local y0 = top + rowInCol * rowH
    local yc = y0 + rowH / 2

    -- Colour lives on marks (state bar, row tint), not on text: text stays in neutral ink so it reads the same
    -- whatever the state, and a problem row is tinted in its status colour so it stands out.
    if r.rank <= 2 then
        fill(lBack, { r.color[1], r.color[2], r.color[3], 0.14 }); addBox(lBack, x0, y0, best.colW, rowH)
    elseif rowInCol % 2 == 1 then
        fill(lBack, C.stripe); addBox(lBack, x0, y0, best.colW, rowH)
    end
    fill(lBack, r.color)
    addBox(lBack, x0, y0 + rowH * 0.15, math.max(3, 4 * unit), rowH * 0.7) -- state bar

    local ink = (r.rank <= 3) and C.text or C.dim -- idle/waiting rows recede
    text(font, r.boardText, x0 + xBoard, yc, C.dim)
    text(font, cut(r.machine, machineChars), x0 + xMachine, yc, ink)
    text(font, r.label, x0 + xState, yc, r.rank <= 2 and C.text or C.dim)
    text(font, r.qty, x0 + xQtyRight, yc, ink, AlignH_Right)
    text(font, cut(r.item, itemChars), x0 + xItem, yc, ink)

    -- stock bar under the quantity: how full the maintain target is
    if r.max > 0 then
        local bw, bh = cw * qtyChars, math.max(1, math.floor(2 * unit))
        local by = yc + size * 0.62
        fill(lBack, C.track); addBox(lBack, x0 + xQtyRight - bw, by, bw, bh)
        fill(lBack, r.cur >= r.max and C.met or C.accent) -- blue = still filling, grey = target reached
        addBox(lBack, x0 + xQtyRight - bw, by, bw * math.min(1, r.cur / r.max), bh)
    end
end

if shown < n then
    text(fSmall, "+" .. (n - shown) .. " more (lower MIN_FONT to fit)", rx - pad, ry - footH - pad * 0.4, C.yellow,
        AlignH_Right)
end
--- eof ---
