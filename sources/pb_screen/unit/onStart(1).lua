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

function scanFactory()
    local rows = {}
    for _, id in ipairs(core.getElementIdList()) do
        if core.getElementClassById(id):sub(0, 8):lower() == "industry" then
            local info = core.getElementIndustryInfoById(id)
            local outputs = info.currentProducts
            if outputs and outputs[1] and outputs[1].id then
                local currentLineID = getLine(id)
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

    scanNo = scanNo + 1
    local desc = (factory_desc or ""):gsub("[|\n]", " "):sub(1, 40)
    local function header(page, count)
        return "#TF2|" .. scanNo .. "|" .. page .. "|" .. count .. "|" .. #rows .. "|" .. manager_version .. "|"
            .. num_lines .. "|" .. feed_multiplier .. "|" .. line_multiplier .. "|" .. desc
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

function screenTick()
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
