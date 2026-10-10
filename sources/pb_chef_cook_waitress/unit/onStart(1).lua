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

-- fix: in the current game build databank.hasKey() returns true/false, not 1/0, so every `hasKey(k) == 1` test was
-- always false: the chef wrote every ingredient request into needed1 (each one overwriting the last) and the
-- transfer units never saw a request. dbHas() accepts both answers.
function dbHas(k)
    local v = databank.hasKey(k)
    return v == true or v == 1
end

-- fix: a machine used to be offered every requirement whose known:<id> was empty or named its kind, and the kind is
-- the machine name with the tier cut off ("electronics m"). So Basic machines were offered Uncommon-only items, and
-- items no linked machine can make were offered to every machine on every walk; each refusal shows as
-- "Unknown Schematic" in the Lua chat. Now an item goes only to machines whose exact type (item id, tier included)
-- is in the item's recipe producers. If the game gives no producer list for an item, the old known: rule is used.
-- known: is still written, so boards with the old code keep working next to this one.
function getStack(industryname, machineId, f)
    local entryStack = newStack()
    if isATransferUnit(industryname) then
        local added = {}
        for count = 1, 30 do
            local ikey = "needed" .. count
            if dbHas(ikey) then
                local itemid = databank.getStringValue(ikey)
                if added[itemid] ~= true then
                    if not (suppress_debug == 1) then system.print("adding need to stack: " .. itemid) end

                    local item = requirements[mfloor(tonumber(itemid))]
                    if item then
                        -- fix: the chef says how many its machine needs (needqty:<id>). The line's own target for the
                        -- item is only its share of the recipe, so the unit went idle as soon as that was met, still
                        -- short of the recipe. Raising the requirement itself also keeps the overproduce check happy.
                        local nq = databank.getIntValue("needqty:" .. itemid)
                        local want = mceil(nq / maintainMultiplier)
                        if want > item.quantity then item.quantity = want end
                        entryStack.push(item)
                        added[itemid] = true
                    end
                end
            end
            databank.clearValue(ikey)
        end
        if entryStack.size > 0 then return entryStack end
    end

    local lookups = 0
    for id, item in pairs(requirements) do
        local wanted
        if isATransferUnit(industryname) then
            -- fix: not an item this transfer unit type already refused twice (see noteRefused)
            wanted = not refused[item.id .. ":" .. tostring(machineId)]
        else
            -- fix: the first look-up of an item asks the game for its recipes; yield after every 10 of those, so the
            -- first walk after a start does not do ~80 look-ups in one tick (CPU limit)
            if producers[item.id] == nil then
                lookups = lookups + 1
                if f and lookups % 10 == 0 then y(f) end
            end
            local p = getProducers(item.id)
            if p and machineId then
                -- fix: also not an item this exact machine type refused twice although the game lists it as a maker
                -- (see noteRefused)
                wanted = (p[machineId] == true) and not refused[item.id .. ":" .. tostring(machineId)]
            else
                local known = getKnown(item.id) -- old rule: do we already know this item's proper industry?
                -- fix: also skip an item this exact machine type already refused (see noteRefused)
                wanted = (known == "" or known == industryname) and not refused[item.id .. ":" .. tostring(machineId)]
            end
        end
        if wanted then entryStack.push(item) end
    end
    return shuffle(entryStack)
end

-- fix: producers[itemId] = the set of machine item ids that can make the item (from all of its recipes), or false
-- when the game gives no producer list. Looked up once per item and kept (a few numbers each).
producers = {}
function getProducers(id)
    local p = producers[id]
    if p == nil then
        p = false
        local recipes = system.getRecipes(id)
        -- fix: catalysts (and anything like them) have one recipe that makes the item from scratch and several
        -- "hand-back" recipes that take the item IN as an ingredient and return it while making something else (glass,
        -- alloys). A machine that runs a hand-back recipe is not a maker of the item: skip those recipes, unless every
        -- recipe is hand-back (then keep them all, as before).
        local function handBack(recipe)
            for _, ing in pairs(recipe.ingredients or {}) do
                if ing.id == id then return true end
            end
            return false
        end
        -- fix: by-products. Pure Oxygen and Pure Hydrogen only come out of ore recipes as a small side product
        -- (Coal -> 45 Pure Carbon + 7.5 Pure Oxygen + 7.5 Pure Hydrogen), so every refiner was listed as a "maker" of
        -- them, was offered them and refused. A recipe now only counts if the item is its biggest product (by
        -- quantity, not by its place in the list) and not a hand-back. If no recipe counts, the rules below are used.
        local function mainFor(recipe)
            local mine, most = 0, 0
            for _, prod in pairs(recipe.products or {}) do
                if prod.id == id then mine = prod.quantity or 0 end
                most = math.max(most, prod.quantity or 0)
            end
            return mine > 0 and mine >= most and not handBack(recipe)
        end
        local main = false
        for _, recipe in pairs(recipes or {}) do
            if mainFor(recipe) then main = true end
        end
        if main then
            p = {} -- an item with real recipes but no machine listed is offered to nobody (no guessing)
            for _, recipe in pairs(recipes) do
                if mainFor(recipe) then
                    for _, machineId in pairs(recipe.producers or {}) do p[machineId] = true end
                end
            end
            producers[id] = p
            return p
        end
        local keep = false
        for _, recipe in pairs(recipes or {}) do
            if not handBack(recipe) then keep = true end
        end
        for _, recipe in pairs(recipes or {}) do
            if not keep or not handBack(recipe) then
                for _, machineId in pairs(recipe.producers or {}) do
                    if not p then p = {} end
                    p[machineId] = true
                end
            end
        end
        producers[id] = p
    end
    return p
end

-- fix: ITEMS WITHOUT A PRODUCER LIST. When the game gives no producer list for an item (seen with a wrong item id in
-- an order), the old known: rule offered it to every kind of machine on every walk; each machine did not take it and
-- the game printed "Unknown Schematic" in the Lua chat each time.
-- Now (1) such an item is not offered again to a machine type (exact machine item id) that already refused it, until
-- the board restarts; (2) once 3 machine types refused it and no machine ever made it, the board writes it to
-- badids:<board> ("id=Name;...", at most 3), so the screen can say "confirm item id" (the order probably has a wrong
-- item id). The flag is removed as soon as a machine on this board takes the item, and at every board start.
refused = {}
refusedCount = {}
flagged = {}
flaggedKey = "badids:" .. unitName:lower()
function publishFlagged()
    local parts, n = {}, 0
    for id, name in pairs(flagged) do
        n = n + 1
        if n <= 3 then parts[n] = id .. "=" .. (name:gsub("[;=]", " ")) end
    end
    if n == 0 then databank.clearValue(flaggedKey) else databank.setStringValue(flaggedKey, table.concat(parts, ";")) end
end
-- fix: REFUSALS OF ITEMS THAT DO HAVE A PRODUCER LIST. Only items without a producer list were remembered (above),
-- so an item whose list names this machine type but which the machine still does not take (for example a catalyst
-- whose hand-back recipes list a glass furnace) was offered again on every walk, for ever: a steady trickle of
-- "Unknown Schematic". Now such an item gets two tries per machine type, then it is not offered to that machine type
-- again until the board restarts. Same for transfer units. `ret` is what setOutput returned: -1 means the machine was
-- not stopped yet (a stop that waits for the current batch), which is not a refusal, so it does not count.
strikes = {}
function noteRefused(item, machineItem, ret, industryname)
    if ret == -1 then reportRefusal(item, machineItem, industryname, "busy") return end
    local key = item.id .. ":" .. tostring(machineItem)
    if refused[key] then return end
    if producers[item.id] ~= false then
        strikes[key] = (strikes[key] or 0) + 1
        if strikes[key] == 1 then reportRefusal(item, machineItem, industryname) end
        if strikes[key] >= 2 then refused[key] = true end
        return
    end
    reportRefusal(item, machineItem, industryname)
    refused[key] = true
    refusedCount[item.id] = (refusedCount[item.id] or 0) + 1
    if refusedCount[item.id] >= 3 and flagged[item.id] == nil and getKnown(item.id) == "" then
        flagged[item.id] = getName(item.id)
        publishFlagged()
    end
end
-- SAY WHICH ITEM. The game's "Unknown Schematic" line names neither the item nor the machine. When a machine does not
-- take an item, this board now prints ONE line right after it (the first time per item and machine type; "busy" at
-- most 3 times per start) with the item, the exact machine and which kind of problem it is:
--   B = the game lists this machine type as a maker, but it refused -> a TF/game mismatch, not a missing machine
--   I = the game lists no machine at all for this item id            -> most likely a wrong item id in the orders
--   N = the game does not list this machine type                     -> TF offered it to the wrong machine (TF bug)
--   T = a transfer unit refused it
-- A missing machine tier never shows up here: an item no linked machine can make is never offered. The screen lists
-- those as MISSING rows. The last 4 B/N/T cases are kept in refused:<board> for the screen ("I" items already get the
-- screen's "confirm item id" row).
REFUSED_TEXT = {
    B = "game lists this machine as a maker -> TF/game mismatch (bug), not a missing machine",
    I = "game lists NO machine for this id -> wrong item id in the orders?",
    N = "game does not list this machine -> TF offered it to the wrong machine (TF bug)",
    T = "transfer unit refused it",
    busy = "machine was still busy (-1), will try again",
}
refusedKey = "refused:" .. unitName:lower()
reported = {}
busyPrinted = 0
function reportRefusal(item, machineItem, industryname, code)
    if code == "busy" then
        if busyPrinted >= 3 then return end
        busyPrinted = busyPrinted + 1
    else
        local p = producers[item.id]
        if isATransferUnit(industryname) then code = "T"
        elseif p == false then code = "I"
        elseif p and machineItem and p[machineItem] then code = "B"
        else code = "N" end
    end
    local machine = machineItem and getName(machineItem) or industryname
    system.print("TF " .. unitName .. ": refused " .. getName(item.id) .. " (" .. item.id .. ") on " .. machine .. ": "
        .. REFUSED_TEXT[code])
    if code ~= "busy" and code ~= "I" then
        reported[#reported + 1] = item.id .. ">" .. tostring(machineItem or 0) .. ">" .. code
        if #reported > 4 then table.remove(reported, 1) end
        databank.setStringValue(refusedKey, table.concat(reported, ";"))
    end
end

function unflagItem(id)
    if flagged[id] ~= nil then
        flagged[id] = nil
        publishFlagged()
    end
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

        -- fix: `maintain` is rounded up, so compare it with the rounded-up target that doBuild sets (toMaintain), not the raw product
        if itemId and requirements[itemId] and maintain > mceil(maintainMultiplier * requirements[itemId].quantity) then
            slot.stop(false, false)
        elseif itemId == nil or requirements[itemId] == nil then
            slot.stop(false, false)
        end
    end
end

complete = 0
functions = {}

-- fix: one scheduler entry per linked machine, whatever its slot number.
-- Before: exactly 18 hand-written entries (functions.slot1 .. functions.slot18), so a machine linked to slot 19 or
-- higher was never driven: on a board with the databank in slot 1 and 19 machines, the last two never got a job.
-- The entries are now created further down, after the machines are discovered (search for cook_total).

cook_check = 0
cook_total = 0 -- fix: number of linked machines, set after discovery; the start-up wait below waits for all of them
function doIndustry(slot, f)
    if slot and slot.getLocalId and industries[slot.getLocalId()] then
        local industry = industries[slot.getLocalId()]
        local state = checkCooking(slot, industry, f)

        cook_check = cook_check + 1
        -- fix: wait for every linked machine (cook_total) instead of a fixed 10. The old count included the empty
        -- slots among the 18 entries, so 10 was always reached; now only linked machines run this code, and a board
        -- with fewer than 10 machines would wait here forever.
        while cook_check < cook_total do y(f) end -- wait for everyone do be done

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
            if isNotATransferUnit(industryname) then setKnown(industry.name, outputs[1].id) end -- fix: condition was inverted and the arguments swapped

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

    -- fix: one work stack per exact machine type (its item id), so a Basic and an Uncommon machine of the same kind
    -- no longer share one list. Transfer units keep their shared stack.
    local stackKey = industryname
    if isNotATransferUnit(industryname) and industry.itemId then stackKey = industry.itemId end
    local stack
    if stacks[stackKey] == nil or stacks[stackKey].size == 0 then
        stacks[stackKey] = getStack(industryname, industry.itemId, f)
    end
    stack = stacks[stackKey]

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
            if state ~= IndustryStatus.stopped then -- no need to stop idle industry (fix: IndustryStatus.idle does not exist, so this was always true)
                if not (suppress_debug == 1) then
                    system.print("--- stopping " ..
                        industryname .. " with state running:" .. tostring(state == IndustryStatus.running))
                end
                y(f)
                -- fix: right after startMaintain the game reports "pending", and "missing ingredient" (jammed)
                -- only shows a few seconds later, so the check after the start below never saw it. Look once more
                -- just before stopping the machine: if it is missing an ingredient, report what it needs first.
                if unitname == "chef" and slot.getInfo().state == IndustryStatus.jammed then
                    for _, input_item in pairs(slot.getInputs()) do
                        addNeed(input_item)
                    end
                end
                slot.stop(false, false)
            end

            y(f)
            -- fix: setOutput used to follow stop() straight away. A stop that is not forced lets the machine finish its
            -- batch first, so it was often still busy: setOutput returned -1 and the game printed "Unknown Schematic".
            -- Now, if the machine was not already stopped, check it really stopped; if not, put the item back and try
            -- again on the next pass (no extra wait when it did stop).
            if state ~= IndustryStatus.stopped and slot.getInfo().state ~= IndustryStatus.stopped then
                stack.push(item)
                return
            end
            state = IndustryStatus.stopped
            local ret = slot.setOutput(item.id) -- fix: keep the result (-1 = machine still busy)

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
                unflagItem(item.id) -- fix: a machine took it, so drop any "confirm item id" flag
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
            else
                -- fix: the machine did not take the item: remember that (see noteRefused)
                noteRefused(item, industry.itemId, ret, industryname)
            end
        end
    end
end

-- fix: before, an ingredient was asked for once per chef start (needs_added[id] was set to true and never cleared),
-- and always in the first key after the highest one used so far. A transfer unit moves one batch per request, so a
-- recipe that needs more than one batch stayed short for good. Now the request is repeated once the last one is
-- older than NEED_RETRY seconds and has been taken; the first free key is used; and the amount the machine needs
-- is stored as needqty:<id>, so the transfer unit can aim for it (see getStack).
NEED_RETRY = 60
needs_added = {} -- item id -> time of the last request
function addNeed(item)
    local now = system.getArkTime()
    if needs_added[item.id] and (now - needs_added[item.id]) < NEED_RETRY then return end
    local free = nil
    for n = 1, 30 do
        if dbHas("needed" .. n) then
            if tonumber(databank.getStringValue("needed" .. n)) == item.id then
                needs_added[item.id] = now -- still waiting to be picked up
                return
            end
        elseif free == nil then
            free = n
        end
    end
    if free == nil then return end
    databank.setStringValue("needed" .. free, item.id)
    if not (suppress_debug == 1) then system.print(free .. " Need: " .. item.id) end
    needs_added[item.id] = now
    local q = mfloor(tonumber(item.quantity) or 0)
    if q > databank.getIntValue("needqty:" .. item.id) then databank.setIntValue("needqty:" .. item.id, q) end
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
                name = adjustIndustryName(slot.getName()),
                -- fix: the exact machine type as an item id (tier and size included). `name` above drops the tier,
                -- so it cannot tell a Basic machine from an Uncommon one.
                itemId = slot.getItemId()
            }
            industries[slotId] = industry
            -- table.insert(industries, industry)
        end
    end
end

unitname = unit.getName():lower()
unitkey  = unitname:gsub("%d$", "")

-- fix: create one scheduler entry per discovered machine (see the note at `functions = {}`), and count them for
-- the start-up wait in doIndustry.
for id, industry in pairs(industries) do
    local machine = industry.slot
    local fn
    fn = function() doIndustry(machine, fn) end
    functions["machine" .. id] = fn
    cook_total = cook_total + 1
end

for id, industry in pairs(industries) do
    databank.setStringValue("slot" .. industry.id, unitName)
end

databank.setStringValue(unitname .. "_version", chef_linecook_version)
databank.setStringValue("status:" .. unitname, "active")
-- fix: clear this board's "confirm item id" flag at start; otherwise a flag stays after the order was corrected.
-- It is set again within a few minutes if an item is still refused.
databank.clearValue(flaggedKey)
databank.clearValue(refusedKey) -- same for the refusal list: this start begins a fresh one
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
                if (item.quantity % tu_quantity) ~= 0 then -- fix: 0 is true in Lua, so the old test was always true
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
