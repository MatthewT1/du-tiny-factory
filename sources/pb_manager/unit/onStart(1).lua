-- PB_MANAGER.LUA
unit.hideWidget()
manager_version       = "1.2.3f"

items                 = {}
line_mins             = {}
line_mins[2240749601] = 300   -- pure aluminum
line_mins[159858782]  = 300   -- pure carbon
line_mins[198782496]  = 300   -- pure iron
line_mins[2589986891] = 300   -- pure silicon

line_mins[2112763718] = 200   -- pure calcium
line_mins[2147954574] = 200   -- pure chromium
line_mins[1466453887] = 200   -- pure copper
line_mins[3603734543] = 200   -- pure sodium

line_mins[3810111622] = 100   -- pure lithium
line_mins[3012303017] = 100   -- pure nickel
line_mins[1807690770] = 100   -- pure silver
line_mins[3822811562] = 100   -- pure sulfur

dont_assign           = {     -- list of raw minerals, these can't be produced, so they need to be ignored
    299255727,                -- coal
    4234772167,               -- hematite
    262147665,                -- bauxite
    3724036288,               -- quartz

    2029139010,               -- chromite
    3086347393,               -- limestone
    2289641763,               -- malachite
    343766315,                -- natron

    1050500112,               -- acanthite
    1065079614,               -- garnierette
    3837858336,               -- petalite
    4041459743,               -- pyrite

    3546085401,               -- cobaltite
    1467310917,               -- cryolite
    1866812055,               -- gold nuggets
    271971371,                -- kolbeckite

    789110817,                -- columbite
    629636034,                -- ilmenite
    3934774987,               -- rhodonite
    2162350405,               -- vanadinite
}

ignore_list           = {} -- will be populated by the dont_assign list

-- fix: RESTART BACKOFF for the watchdog below.
-- Before: a board whose ping went stale was switched off by next(), and buttonsOn switched it straight back on
-- within seconds, every time. A board that dies during its own start-up (for example from a script memory
-- overload) then restarts over and over, and every restart is another burst of memory that can push the next board
-- over the limit. Now the 1st failure in a row keeps the board off for 30 s, the 2nd for 60 s, the 3rd and later for
-- 120 s. A board counts as healthy again (failures forgotten) once its ping is fresh 120 s after its last hold ended.
--   restart_fails[name] = failures in a row;  hold_until[name] = buttonsOn leaves the board off until this time.
restart_fails = {}
hold_until = {}

function next()
    currentTime = math.floor(system.getArkTime())

    out("status checking at timestamp: [", currentTime, "]")

    for name, slot in pairs(buttons) do
        lastPing = databank.getIntValue("ping:" .. name)
        out(">>> lastPing: [", lastPing, "]")
        if isStillActive(currentTime, lastPing) then
            out(name, " is still running")
            -- fix: fresh ping and well past its last hold: the board is healthy again, forget its failures
            if hold_until[name] and (currentTime - hold_until[name]) > 120 then
                restart_fails[name] = nil
                hold_until[name] = nil
            end
        elseif not slot.isActive() then
            -- fix: already switched off (e.g. waiting out its hold): nothing to reset and no new failure to count
        else
            out(name, " is overdue for ping.  Trying to reset.")
            slot.deactivate()
            local resetAttempts = 1
            while resetAttempts < 10 do
                if slot.isActive() then slot.deactivate() end
                resetAttempts = resetAttempts + 1
            end
            databank.clearValue("status:" .. name)
            -- fix: count the failure and hold the board off for 30, 60, then 120 s (see restart_fails above)
            restart_fails[name] = (restart_fails[name] or 0) + 1
            hold_until[name] = currentTime + math.min(30 * 2 ^ (restart_fails[name] - 1), 120)
        end
    end
end --- function next()

function isStillActive(currentTime, lastPing)
    local stillActiveMaxPing = 30
    return (stillActiveMaxPing > (currentTime - lastPing))
end --- function isStillActive

function getIngredients(items, base, recurse)
    local new = false

    if base == nil then base = {} end
    local ingredients = base
    if recurse then ingredients = items end

    repeat
        new = false
        for _, item in pairs(items) do
            local item_id = item.id

            -- determine what we will need to build the item
            local inputs = getPrimaryIngredients(item_id)
            local time_multiplier = 1

            if inputs and inputs[1] then
                items = bruteFixWrongQuantity(recurse, item_id, ingredients, inputs, line_multiplier, num_lines)
            end
        end
    until (recurse == false or new == false)

    return items
end

function addBuild(id, quantity, is_input)
    if id == nil or quantity == nil then
        out("id or quantity can not be nil", id, quantity)
        return
    end
    local new = false
    local key = "" .. id

    if builds[key] == nil then
        builds[key] = { id = id }
        new = true
    end
    builds[key].quantity = math.ceil(quantity)

    return new
end

function saveTable(name, table)
    databank.clearValue(name)
    local raw = serialize(table)
    databank.setStringValue(name, raw)
    if databank.getStringValue(name) ~= raw then
        out("Unable to save to databank")
        unit.exit()
    end
end

databank = nil
buttons = {}
names = {}
builds = {}
activated = {}
screen = nil
button_names = {}

for slot_name, slot in pairs(unit) do
    if type(slot) == "table" and type(slot.export) == "table" and slot.getClass then
        slotClass = slot.getClass():lower()
        if slotClass == 'databankunit' then
            databank = slot
        elseif slotClass:sub(0, 8) == "industry" then
            slotId = slot.getLocalId()
            industry = {
                id = slotId,
                slot = slot
            }
            table.insert(industries, industry)
        elseif slotClass == "manualswitchunit" then
            buttons[slot.getName()] = slot
            table.insert(button_names, slot.getName())
        end
    end
end

feed_multiplier = math.max(1.0, databank.getFloatValue("feed_multiplier"))
line_multiplier = math.max(1.0, databank.getFloatValue("line_multiplier"))
num_lines = math.max(1, databank.getIntValue("num_lines"))

databank.setStringValue("manager_version", manager_version)

orders = deserialize(databank.getStringValue("orders"))
if orders == "" then orders = {} end
for id, quantity in pairs(orders) do
    items[tonumber(id)] = quantity
end
orders = nil

for name, slot in pairs(buttons) do
    slot.deactivate()
    if databank then databank.clearValue("status:" .. name) end
end

for _, id in pairs(dont_assign) do
    databank.setStringValue("industry:" .. id, "-")
    databank.setStringValue("known:" .. id, "-")
    ignore_list[id] = true
end

for id, qty in pairs(items) do
    addBuild(id, qty, "false")
end

-- save the main builds
saveTable("chef", builds)

-- all items added, now determine immediate ingredients to build each item
ingredients = getIngredients(builds, {}, false)
saveTable("waitress", ingredients)

-- immediate ingredients added, now determine all ingredients needed to build ingredients and required items
ingredients = getIngredients(ingredients, ingredients, true)
saveTable("linecook", ingredients)

unit.setTimer("buttonsOn", 11)
unit.setTimer("next", 22)
