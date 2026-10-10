---- (1) ----
unit.hideWidget()
screen_version = "1.2.3b"

-- fix: send EVERY machine to the screen, in pages.
-- Before: each update built one message of all machines (problems first) and cut it at 1024 characters - the most
-- a screen accepts in one setScriptInput (a longer one is dropped entirely) - so on a big factory only the first
-- ~20 machines ever reached the screen. Now one scan builds a short line per machine and packs the lines into
-- pages that each fit the limit; the update timer sends one page per second, and when all pages are sent the next
-- scan starts - but never sooner than SCAN_SECONDS after the last one. The screen (screen.lua) keeps every page
-- and draws all machines. The scan is the expensive part (it asks the game about every element of the construct).
-- Timing: the update timer used to go through NestCo, whose coroutine wrapper only reaches the scan on every 4th
-- tick, so the 1 s timer really scanned about every 4 s. The timer now calls screenTick() directly.
-- Message format (version 2):
--   #TF2|scan|page|pages|machines|manager version|lines|feed x|line x|description
--   id,board,machine,state,current,maintain,item        (one line per machine)
-- board: C = chef, 1-9 = linecook number, W = waitress. state: R running, W missing ingredient, F output full,
-- N no output container, P pending, I stopped, S no schematic, ? anything else.
SCREEN_MAX_INPUT = 1000 -- bytes per page; the game limit is about 1024, keep a margin
SCAN_SECONDS = 12       -- shortest time between two scans of the construct (the screen refreshes this often)

local STATE_CODE = {
    [UNIT_STOPPED] = "I", [UNIT_WORKING] = "R", [UNIT_JAMMED] = "W", [UNIT_FULL_STORAGE] = "F",
    [UNIT_BAD_CFG] = "N", [UNIT_WAITING] = "P", [UNIT_NO_SCHEMAS] = "S",
}

local function boardCode(line)
    if line == "chef" then return "C" end
    if line == "waitress" then return "W" end
    local n = line:match("^||(%d+)$") -- getLine() turns "linecook3" into "||3"
    return n or line:gsub("[,|]", "")
end

scanNo = 0
pages = {}
pageNo = 0
lastScan = -1000000

-- MISSING MACHINES. A cook board only offers an item to machines the game lists as able to make it, so an item that
-- no TF machine can make (wrong tier: e.g. Warp Drive L needs an Uncommon or better Assembly Line L on the chef) is
-- silently never made. The screen checks every item of the chef list (needs a chef machine) and of the linecook list
-- (needs a linecook or waitress machine) against the exact machine types linked to those boards, and adds a MISSING
-- row naming the cheapest machine that could make it. Same producer rules as the cook boards: hand-back recipes and
-- by-products do not count. Recipes are asked once per item, at most 10 new items per scan (CPU), so the full list
-- appears within a couple of minutes after a start.
prodOf = {}    -- item id -> list of machine item ids that can make it, or false
needName = {}  -- item id -> short name of the lowest-tier machine that can make it
function producersOf(id)
    local recipes = system.getRecipes(id) or {}
    local function handBack(recipe)
        for _, ing in pairs(recipe.ingredients or {}) do
            if ing.id == id then return true end
        end
        return false
    end
    local function mainFor(recipe)
        local mine, most = 0, 0
        for _, prod in pairs(recipe.products or {}) do
            if prod.id == id then mine = prod.quantity or 0 end
            most = math.max(most, prod.quantity or 0)
        end
        return mine > 0 and mine >= most and not handBack(recipe)
    end
    local main, keep = false, false
    for _, recipe in pairs(recipes) do
        if mainFor(recipe) then main = true end
        if not handBack(recipe) then keep = true end
    end
    local list, seen = {}, {}
    for _, recipe in pairs(recipes) do
        if (main and mainFor(recipe)) or (not main and (not keep or not handBack(recipe))) then
            for _, mid in pairs(recipe.producers or {}) do
                if not seen[mid] then seen[mid] = true; list[#list + 1] = mid end
            end
        end
    end
    if #list == 0 then return false end
    return list
end
function lowestMachine(id, list)
    if needName[id] == nil then
        local best, bestTier = "?", nil
        for _, mid in ipairs(list) do
            local it = system.getItem(mid)
            local t = tonumber(it.tier) or 99
            if bestTier == nil or t < bestTier then best, bestTier = it.locDisplayNameWithSize or "?", t end
        end
        needName[id] = (best:gsub(" Line", ""):gsub(" Unit", ""):gsub(" Industry", ""):gsub(",", ""))
    end
    return needName[id]
end
function addMissingRows(rows, types)
    local budget, shown = 10, 0
    local function check(list, have, code)
        for _, it in pairs(list or {}) do
            local id = tonumber(it.id)
            if id and prodOf[id] == nil and budget > 0 then
                budget = budget - 1
                prodOf[id] = producersOf(id)
            end
            local p = id and prodOf[id]
            if p then
                local ok = false
                for _, mid in ipairs(p) do
                    if have[mid] then ok = true; break end
                end
                if not ok and shown < 8 then
                    shown = shown + 1
                    rows[#rows + 1] = "m" .. id .. "," .. code .. "," .. lowestMachine(id, p) .. ",M,0,"
                        .. mceil(tonumber(it.quantity) or 0) .. "," .. (getName(id, false):gsub(",", ""))
                end
            end
        end
    end
    check(manager_items, types.chef, "C")
    check(linecook_items, types.line, "L")
end
-- short texts for the cook boards' refusal codes (see reportRefusal on the cook boards)
REFUSED_SHORT = { B = "game says it can: bug?", N = "wrong machine: TF bug", T = "transfer unit refused" }

function scanFactory()
    local rows = {}
    local types = { chef = {}, line = {} } -- exact machine types linked to TF boards
    for _, id in ipairs(core.getElementIdList()) do
        if core.getElementClassById(id):sub(0, 8):lower() == "industry" then
            local info = core.getElementIndustryInfoById(id)
            local outputs = info.currentProducts
            -- note every TF machine's exact type, also when it has no output set yet
            local lineOf = getLine(id)
            if lineOf ~= "" then
                local mid = core.getElementItemIdById(id)
                if lineOf == "chef" then types.chef[mid] = true else types.line[mid] = true end
            end
            if outputs and outputs[1] and outputs[1].id then
                local currentLineID = lineOf
                if currentLineID ~= "" then
                    local current, maintain = 0, 0
                    if info.currentProductAmount > 0 then
                        current = mceil(info.currentProductAmount)
                        if current > 99999 then
                            current = mfloor(current / 16777216)
                        end
                    end
                    if info.maintainProductAmount > 0 then
                        maintain = mceil(info.maintainProductAmount)
                    end
                    -- "Assembly Line L" -> "Assembly L", "Transfer Unit L" -> "Transfer L": shorter lines, more per page
                    local machine = getName(core.getElementItemIdById(id), true):gsub(" Line", ""):gsub(" Unit", ""):gsub(",", "")
                    rows[#rows + 1] = id .. "," .. boardCode(currentLineID) .. "," .. machine .. ","
                        .. (STATE_CODE[info.state] or "?") .. "," .. current .. "," .. maintain .. ","
                        .. getName(outputs[1].id, false)
                end
            end
        end
    end

    databank.setIntValue("machine_count", #rows)

    -- fix: a cook board that found an item no machine will take (the game lists no recipe for it, refused by 3 machine
    -- types) writes it to badids:<board> ("id=Name;..."). Each one becomes an extra row at the top of the screen (red
    -- "NO SCHEM" state, ERROR in the machine column) saying to check that item id in the customer board. Same row
    -- format as a machine, so screen.lua needs no change. Boards that do not write the key change nothing here.
    local askBoards, seenBad = { "chef", "waitress" }, {}
    for n = 1, num_lines do askBoards[#askBoards + 1] = "linecook" .. n end
    for _, bname in ipairs(askBoards) do
        local v = databank.getStringValue("badids:" .. bname)
        if v ~= "" then
            for id, name in v:gmatch("(%d+)=([^;]*)") do
                if not seenBad[id] then
                    seenBad[id] = true
                    rows[#rows + 1] = "e" .. id .. ",!,ERROR,S,0,0,confirm item id: " .. (name:gsub(",", ""))
                        .. " (" .. id .. ")"
                end
            end
        end
        -- the last refusals of this board ("item>machine>code;..."): one REFUSED row each
        for item, mid, code in databank.getStringValue("refused:" .. bname):gmatch("(%d+)>(%d+)>(%a)") do
            local machine = (getName(tonumber(mid), true):gsub(" Line", ""):gsub(" Unit", ""):gsub(",", ""))
            rows[#rows + 1] = "x" .. item .. "_" .. mid .. "," .. boardCode((bname:gsub("linecook", "||"))) .. ","
                .. machine .. ",X,0,0," .. (getName(tonumber(item), false):gsub(",", "")) .. " - "
                .. (REFUSED_SHORT[code] or code)
        end
    end
    addMissingRows(rows, types)

    -- away mode for the header: "-" = normal mode, else "<machines set>/<machines>" over all boards
    local awayText = "-"
    if databank.getIntValue("away") > 0 then
        local done, total = 0, 0
        for _, bname in ipairs(askBoards) do
            local d, t = databank.getStringValue("awaystat:" .. bname):match("^(%d+)/(%d+)$")
            if d then done = done + tonumber(d); total = total + tonumber(t) end
        end
        awayText = done .. "/" .. total
    end

    scanNo = scanNo + 1
    local desc = (factory_desc or ""):gsub("[|\n]", " "):sub(1, 40)
    local function header(page, count)
        return "#TF2|" .. scanNo .. "|" .. page .. "|" .. count .. "|" .. #rows .. "|" .. manager_version .. "|"
            .. num_lines .. "|" .. feed_multiplier .. "|" .. line_multiplier .. "|" .. desc .. "|" .. awayText
    end
    local room = SCREEN_MAX_INPUT - #header(99, 99) - 1 -- header size with the widest page numbers

    -- pack rows into pages
    local chunks, chunk, size = {}, {}, 0
    for _, row in ipairs(rows) do
        if size + #row + 1 > room and #chunk > 0 then
            chunks[#chunks + 1] = chunk
            chunk, size = {}, 0
        end
        chunk[#chunk + 1] = row
        size = size + #row + 1
    end
    chunks[#chunks + 1] = chunk -- the last page (or one empty page when there are no machines)

    pages = {}
    for i, c in ipairs(chunks) do
        pages[i] = header(i, #chunks) .. "\n" .. table.concat(c, "\n")
    end
    pageNo = 0
    screen.activate()
end

-- AWAY BUTTON. screen.lua draws an AWAY button in its header; after a confirm tap it sends "TF_AWAY_ON" or
-- "TF_AWAY_OFF". This board turns that into the databank key `away` (the time it was set), which every cook board
-- watches, and rescans at once so the header shows the new state.
function checkTap()
    local out = screen.getScriptOutput()
    if out == nil or out == "" then return end
    screen.clearScriptOutput()
    if out == "TF_AWAY_ON" then
        databank.setIntValue("away", mfloor(system.getArkTime()))
        system.print("TF screen: AWAY mode on - wait until the header says all machines are set, then leave")
    elseif out == "TF_AWAY_OFF" then
        databank.clearValue("away")
        system.print("TF screen: AWAY mode off - back to normal")
    else
        return
    end
    lastScan = -1000000
    pageNo = #pages
end

function screenTick()
    checkTap()
    if pageNo >= #pages then
        local now = system.getArkTime()
        if now - lastScan < SCAN_SECONDS then return end
        lastScan = now
        scanFactory()
    end
    pageNo = pageNo + 1
    screen.setScriptInput(pages[pageNo])
end

functions = {} -- NestCo (below) is still created as before, but nothing calls NestCo.update() any more

lines = {}
function getLine(id)
    if lines[id] == nil or lines[id] == "" then
        lines[id] = databank.getStringValue("slot" .. id)
        lines[id] = lines[id]:gsub("linecook", "||")
    end
    return lines[id]
end

function ping()
    databank.setIntValue(pingkey, mfloor(system.getArkTime()))
end

pingkey = "ping:" .. unit.getName()
unit.setTimer("ping", 10)

screen.setScriptInput(" ... pending ... ")
screen.activate()

databank.setStringValue("screen_version", screen_version)

manager_items = deserialize(databank.getStringValue("chef"))
linecook_items = deserialize(databank.getStringValue("linecook"))

feed_multiplier = math.max(1.0, databank.getFloatValue("feed_multiplier"))
line_multiplier = math.max(1.0, databank.getFloatValue("line_multiplier"))
num_lines = math.max(1, databank.getIntValue("num_lines"))
manager_version = databank.getStringValue("manager_version")
factory_desc = databank.getStringValue("factory_desc")

-- do not change the below
nestco = {}
function nestco:new(a)
    local b = {}
    setmetatable(b, self)
    self.__index = self; b.functions = a or {}
    b.coroutines = {}
    function b.update() return b:_update() end; function b.init() return b:_init() end; function b.run() return b:_run() end; function b.update() return
        b:_update() end; b.init()
    b.main = coroutine.create(b.run)
    return b
end; function nestco:_init() for c, d in pairs(self.functions) do self.coroutines[c] = coroutine.create(d) end end; function nestco:_run() for c, e in pairs(self.coroutines) do
        local f = coroutine.status(e)
        if f == "dead" then self.coroutines[c] = coroutine.create(self.functions[c]) elseif f == "suspended" then assert(
            coroutine.resume(e)) end
    end end; function nestco:_update()
    local f = coroutine.status(self.main)
    if f == "dead" then self.main = coroutine.create(self.run) elseif f == "suspended" then assert(coroutine.resume(self
        .main)) end
end

NestCo = nestco:new(functions)
-- fix: onTimer(update) now calls screenTick(): one page per second; the scan runs at most every SCAN_SECONDS
unit.setTimer("update", 1)
-- do not chang the above
