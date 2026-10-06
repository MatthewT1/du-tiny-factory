-- PB_CHEF_LINECOOK_Waitress.LUA
---- (1) ----
unit.hideWidget()
chef_linecook_version = "1.2.3h"

function adjustIndustryName(text)
    text = text:lower()
    local split = strSplit(text, " ")
    text = split[2]
    for i = 3, 10 do
        if split[i] == nil then split[i] = "" end
        if split[i] == "xs" or split[i] == "s" or split[i] == "m" or split[i] == "l" or split[i] == "xl" then
            return text .. " " .. split[i]
        end
    end
    return text
end

function getStack(industryname)
    local entryStack = newStack()
    if isATransferUnit(industryname) then
        local added = {}
        for count = 1, 30 do
            local ikey = "needed" .. count
            if databank.hasKey(ikey) == 1 then
                local itemid = databank.getStringValue(ikey)
                if added[itemid] ~= true then
                    if not (suppress_debug == 1) then system.print("adding need to stack: " .. itemid) end

                    local item = requirements[mfloor(tonumber(itemid))]
                    if item then
                        entryStack.push(item)
                        added[itemid] = true
                    end
                end
            end
            databank.clearValue(ikey)
        end
        if entryStack.size > 0 then return entryStack end
    end

    for id, item in pairs(requirements) do
        local known = getKnown(item.id) -- do we already know this item's proper industry?

        if isATransferUnit(industryname) or (known == "" or known == industryname) then
            entryStack.push(item)
        end
    end
    return shuffle(entryStack)
end

function checkForOverproducing(slot, info)
    if info.state == IndustryStatus.running
        or info.state == IndustryStatus.jammed then
        local outputs = info.currentProducts
        local itemId = outputs[1].id
        local current = 0
        local maintain = 0

        if info.maintainProductAmount > 0 then
            maintain = mceil(info.maintainProductAmount)
        end

        if itemId and requirements[itemId] and maintain > (maintainMultiplier * requirements[itemId].quantity) then
            slot.stop(false, false)
        elseif itemId == nil or requirements[itemId] == nil then
            slot.stop(false, false)
        end
    end
end

complete = 0
functions = {}

functions.slot1 = function() doIndustry(slot1, functions.slot1) end
functions.slot2 = function() doIndustry(slot2, functions.slot2) end
functions.slot3 = function() doIndustry(slot3, functions.slot3) end
functions.slot4 = function() doIndustry(slot4, functions.slot4) end
functions.slot5 = function() doIndustry(slot5, functions.slot5) end
functions.slot6 = function() doIndustry(slot6, functions.slot6) end
functions.slot7 = function() doIndustry(slot7, functions.slot7) end
functions.slot8 = function() doIndustry(slot8, functions.slot8) end
functions.slot9 = function() doIndustry(slot9, functions.slot9) end
functions.slot10 = function() doIndustry(slot10, functions.slot10) end
functions.slot11 = function() doIndustry(slot11, functions.slot11) end
functions.slot12 = function() doIndustry(slot12, functions.slot12) end
functions.slot13 = function() doIndustry(slot13, functions.slot13) end
functions.slot14 = function() doIndustry(slot14, functions.slot14) end
functions.slot15 = function() doIndustry(slot15, functions.slot15) end
functions.slot16 = function() doIndustry(slot16, functions.slot16) end
functions.slot17 = function() doIndustry(slot17, functions.slot17) end
functions.slot18 = function() doIndustry(slot18, functions.slot18) end

cook_check = 0
function doIndustry(slot, f)
    if slot and slot.getLocalId and industries[slot.getLocalId()] then
        local industry = industries[slot.getLocalId()]
        local state = checkCooking(slot, industry, f)

        cook_check = cook_check + 1
        while cook_check < 10 do y(f) end -- wait for everyone do be done

        if state ~= IndustryStatus.running then doBuild(slot, industry, f) end
    else
        cook_check = cook_check + 1
    end
end

local stacks = {}
local cooking = {}
function checkCooking(slot, industry, f)
    local industryname = industry.name

    local info = slot.getInfo()
    local state = info.state

    if state == IndustryStatus.running then -- cooking something
        outputs = slot.getOutputs()
        if outputs and outputs[1] then
            cooking[outputs[1].id] = true
            if not (suppress_debug == 1) then system.print(industryname .. " cooking " .. getName(outputs[1].id)) end
            if isATransferUnit(industryname) then setKnown(outputs[1].id, industry.name) end

            -- make sure we're not cooking too many, sometimes a bug will put in way too many
        end
    end

    checkForOverproducing(slot, info)
    return state
end

function doBuild(slot, industry, f)
    if industry == nil then return end

    local slotId = slot.getLocalId()
    local industryname = industry.name

    local info = slot.getInfo()
    local state = info.state
    local skip = false

    local stack
    if stacks[industryname] == nil or stacks[industryname].size == 0 then
        stacks[industryname] = getStack(industryname)
    end
    stack = stacks[industryname]

    if not (suppress_debug == 1) then system.print("Checking industry for " ..
        industryname .. " with stack size " .. stack.size .. " state: " .. state) end

    while state ~= IndustryStatus.running and skip == false and stack.size > 0 do
        if state == IndustryStatus.no_schemas
            or state == IndustryStatus.running then
            skip = true
        end
        if state == IndustryStatus.jammed
            and industryname == "refiner m" then
            skip = true
        end
        if state == IndustryStatus.running
            and isATransferUnit(industryname) then
            skip = true
        end -- do not interfere with large transfers industry

        if skip then
            if not (suppress_debug == 1) then system.print(">>> Skipping " .. industryname .. " with state " .. state) end
            return
        end

        local item = stack.pop()
        if item ~= nil then
            if not (suppress_debug == 1) then system.print("+++ checking " .. industryname .. " with state " .. state) end
            if state ~= IndustryStatus.idle then -- no need to stop idle industry
                if not (suppress_debug == 1) then
                    system.print("--- stopping " ..
                        industryname .. " with state running:" .. tostring(state == IndustryStatus.running))
                end
                y(f)
                slot.stop(false, false)
            end

            y(f)
            slot.setOutput(item.id)

            -- ensure the output item is the wanted id
            y(f)
            local outputs = slot.getOutputs()
            if outputs and outputs[1] and outputs[1].id == item.id then
                y(f)
                local toMaintain = mceil(item.quantity * maintainMultiplier) -- NB "even if the transfer unit is drowning do not pass it a float" -- BBDarth
                if not (suppress_debug == 1) then system.print(industryname .. " toMaintain " .. toMaintain) end

                slot.startMaintain(toMaintain)
                if not (suppress_debug == 1) then system.print(industryname ..
                    " maintaining " .. getName(item.id) .. " x" .. toMaintain) end

                setKnown(industryname, item.id)
                -- get the new status, e.g. do we need schematics?
                y(f)
                local info = slot.getInfo()
                state = info.state
                if state == IndustryStatus.running
                    or state == IndustryStatus.pending
                    or state == IndustryStatus.no_schemas then
                    cooking[outputs[1].id] = true
                end

                if isATransferUnit(industryname) then
                    -- some items, e.g. basic pipes, need at least 200 for transfers
                    -- we need to let the other boards know this
                    local inputs = slot.getInputs()
                    if inputs[1].quantity > 1 then
                        databank.setIntValue("transfer:" .. item.id, mfloor(inputs[1].quantity))
                    end
                elseif unitname == "chef" and state == IndustryStatus.jammed then
                    local inputs = slot.getInputs()
                    local count = 0
                    for _, input_item in pairs(inputs) do
                        addNeed(input_item)
                    end
                end
                -- make sure we're not cooking too many, sometimes a bug will put in way too many
                checkForOverproducing(slot, info)
            end
        end
    end
end

needcount = 1
needs_added = {}
function addNeed(item)
    if needs_added[item.id] == true then return end
    while databank.hasKey("needed" .. needcount) == 1 and needcount < 30 do
        needcount = needcount + 1
    end
    if needcount <= 30 then
        databank.setStringValue("needed" .. needcount, item.id)
        if not (suppress_debug == 1) then system.print(needcount .. " Need: " .. item.id) end
        needs_added[item.id] = true
    end
end

known_industry = {}
function getKnown(id)
    local key = "known:" .. id
    if known_industry[key] == nil or known_industry[key] == "" then
        known_industry[key] = databank.getStringValue(key)
    end
    return known_industry[key]
end

slot_status_saved = {}
function setKnown(industryname, id)
    local key = "known:" .. id
    if isNotATransferUnit(industryname) and slot_status_saved[key] == nil then
        databank.setStringValue(key, industryname)
        known_industry[key] = industryname
        slot_status_saved[key] = true
    end
end

names = {}
function getName(id)
    if names[id] == nil then
        names[id] = system.getItem(id).locDisplayNameWithSize
    end
    return names[id]
end

pingkey = "ping:" .. unitName
memkey = "mem:" .. unitName
function ping()
    databank.setIntValue(pingkey, mfloor(system.getArkTime()))
    -- tweak: also publish this board's Lua heap size in KB as mem:<board name>, so memory use can be read from
    -- the databank in game instead of guessed from the overload messages. Only written, never read by TF.
    databank.setIntValue(memkey, mfloor(collectgarbage("count")))
end

-- acutal execution starts here

databank = nil
industries = {}
status = {}
stacks = {}

for slot_name, slot in pairs(unit) do
    if type(slot) == "table" and type(slot.export) == "table" and slot.getClass then
        slotClass = slot.getClass():lower()

        if slotClass == 'databankunit' then
            databank = slot
        elseif slotClass:sub(0, 8) == "industry" then
            slotId = slot.getLocalId()
            industry = {
                id = slotId,
                slot = slot,
                name = adjustIndustryName(slot.getName())
            }
            industries[slotId] = industry
            -- table.insert(industries, industry)
        end
    end
end

unitname = unit.getName():lower()
unitkey  = unitname:gsub("%d$", "")

for id, industry in pairs(industries) do
    databank.setStringValue("slot" .. industry.id, unitName)
end

databank.setStringValue(unitname .. "_version", chef_linecook_version)
databank.setStringValue("status:" .. unitname, "active")
if not (suppress_debug == 1) then out("INFO: ", unitname, " is alive as type [", unitkey, "]") end

suppress_debug = math.max(0, databank.getIntValue("suppress_debug"))
if suppress_debug then
    out("Debug is set OFF.")
else
    out("Debug is set ON.")
end

local raw = databank.getStringValue(unitkey)
if raw == "" then
    out("ERROR: cannot find manager entry for [", unitkey, "]")
    return unit.exit()
end

feed_multiplier = math.max(1.0, databank.getFloatValue("feed_multiplier"))
line_multiplier = math.max(1.0, databank.getFloatValue("line_multiplier"))
num_lines = math.max(1, databank.getIntValue("num_lines"))
machine_count = math.max(1, databank.getIntValue("machine_count"))

if num_lines <= 0 then
    num_lines = 1
elseif num_lines > 1 then
    num_lines = mceil(num_lines / 1.25)
end
-- tweak: parse the requirement text already read into `raw` above, instead of reading it from the databank a
-- second time (two copies of a long string at start-up).
items = deserialize(raw)
requirements = {}
local count = 0
for _, item in pairs(items) do
    if unitkey == "linecook" then
        local tu_quantity = databank.getIntValue("transfer:" .. item.id)
        tu_quantity = mceil(tu_quantity / num_lines)
        if (tu_quantity > 0) then
            if tu_quantity > item.quantity then
                if suppress_debug then
                    system.print("Transfer Unit upgrading " ..
                        getName(item.id) .. " from " .. item.quantity .. " to " .. tu_quantity)
                end
                item.quantity = tu_quantity
            else
                if (item.quantity % tu_quantity) then
                    if not (suppress_debug == 1) then out("tu_quantity fix:", tu_quantity) end
                    local fix_factor = mceil(item.quantity / tu_quantity)
                    if not (suppress_debug == 1) then item.quantity = fix_factor * tu_quantity end
                    out("new item.quantity:", item.quantity)
                end
            end
        end

        -- some items we should never have more than a few of, such as catalysts
        -- hardcode to restrict those item quantities
        if item.id == 3729464848     -- catalyst 3
            or item.id == 3729464849 -- catalyst 4
            or item.id == 3729464850 -- catalyst 5
        then
            item.quantity = math.min(item.quantity, 5)
        end
    end

    requirements[item.id] = item
    count = count + 1
    if not (suppress_debug == 1) then system.print(getName(item.id) .. " x" .. item.quantity) end
end
if count == 0 then
    system.print("0 items to build - exiting")
    unit.exit()
    return
end

-- tweak: from here on only `requirements` is used; drop the requirement text and the parsed list so the collector
-- can free them (they stayed in memory for as long as the board ran).
raw = nil
items = nil

maintainMultiplier = 1
if unitkey == "waitress" then
    maintainMultiplier = math.max(maintainMultiplier, feed_multiplier) * num_lines
end

local tickRatio = mceil((2.37 / 3.0) * 100) / 100
local wide_load = math.max(0, (machine_count - 40) / 2)
local nextTickSeconds = tickRatio * (num_lines + wide_load)
unit.setTimer("next", nextTickSeconds)
unit.setTimer("ping", 5)

-- do not change the following
nestco = {}
function nestco:new(a)
    local b = {}
    setmetatable(b, self)
    self.__index = self; b.functions = a or {}
    b.coroutines = {}
    function b.update() return b:_update() end; function b.init() return b:_init() end; function b.run() return b:_run() end; function b.update()
        return
            b:_update()
    end; b.init()
    b.main = coroutine.create(b.run)
    return b
end; function nestco:_init() for c, d in pairs(self.functions) do self.coroutines[c] = coroutine.create(d) end end; function nestco:_run()
    for c, e in pairs(self.coroutines) do
        local f = coroutine.status(e)
        if f == "dead" then
            self.coroutines[c] = coroutine.create(self.functions[c])
        elseif f == "suspended" then
            assert(
                coroutine.resume(e))
        end
    end
end; function nestco:_update()
    local f = coroutine.status(self.main)
    if f == "dead" then
        self.main = coroutine.create(self.run)
    elseif f == "suspended" then
        assert(coroutine.resume(self
            .main))
    end
end

NestCo = nestco:new(functions)
function y(f) coroutine.yield(f) end

-- tweak: one full clean-up now that start-up is over. Start-up is when a board is biggest (the requirement text
-- is read, copied and compiled); without this that garbage stays until the collector gets round to it.
collectgarbage("collect")
