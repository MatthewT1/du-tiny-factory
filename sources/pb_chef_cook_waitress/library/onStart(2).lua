---- (2) ----
function strSplit(a, b)
    result = {}
    for c in (a .. b):gmatch("(.-)" .. b) do table.insert(result, c) end; return result
end

function strSplit(a,b)result={}for c in(a..b):gmatch("(.-)"..b)do table.insert(result,c)end;return result end

mfloor = math.floor
mceil = math.ceil
mmin = math.min
mmax = math.max
mrandom = math.random
unitName = unit.getName()

function clean(param)
    if param == nil then return " " end
    return param
end

function out(a, b, c, d)
    system.print(clean(a) .. " " .. clean(b) .. " " .. clean(c) .. " " .. clean(d))
end

function newStack()
    local o = {} o.entries = {} o.size = 0
    o.push = function(object)
        if object ~= nil then 
            o.size = o.size + 1
            o.entries[o.size] = object
        end
    end
    o.pop = function()
        if o.size > 0 then
            o.size = o.size - 1
            return o.entries[o.size + 1]
        end
    end
    return o
end

mfloor   = math.floor
mceil    = math.ceil
mmin     = math.min
mmax     = math.max
mrandom  = math.random
unitName = unit.getName()

function newStack()
    local o = {}
    o.entries = {}
    o.size = 0
    o.push = function(object)
        if object ~= nil then
            o.size = o.size + 1
            o.entries[o.size] = object
        end
    end
    o.pop = function()
        if o.size > 0 then
            o.size = o.size - 1
            return o.entries[o.size + 1]
        end
    end
    return o
end

-- fix: getStack() passes a stack object (entries + size), for which #tbl is 0, so nothing was ever shuffled.
-- Shuffle the entries of the stack (or a plain array if one is passed).
function shuffle(t)
    local arr = t.entries or t
    for i = #arr, 2, -1 do
        local j = mrandom(i)
        arr[i], arr[j] = arr[j], arr[i]
    end
    return t
end
