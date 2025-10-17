---- (1) ----
-- PB_CUSTOMER.LUA
customer_version    = "1.2.3b"
local items         = {} -- don't modify this line
--- ---
CLASSIC_YPOS          = 488
THREELINE_YPOS        = 511

--- << user configuration section >> ---
local factory_desc = "Classic Build" -- If you have more than one, change this
local feed_multiplier = 1.0 -- how much extra to be produced and kept waiting in the feeder bin
local line_multiplier = 1.0 -- how much extra should be produced waiting to be transferred to feeder bin (will max at 1000)
local num_lines       = 2 -- the number of linecook support lines
local suppress_debug  = true -- don't need it nattering in LUA chan if everything is OK

---
local defaultColHeaderYPos   = CLASSIC_YPOS          -- pick one of above two, or set your own integer value
local colHeaders             = { "Inputs", " ", " ", "Outputs" } --bottom row Hub labels
local fontSize               = 14                    --on-screen font size
local topMargin              = 22                    --don't change at random
local custom_col_header_yPos = -1                    --don't change at random

---
--[[
Instructions:

to add an item, look it up by name on https://du-lua.dev/#/items
and enter the value below as you see in the examples.
Left side is the item id, right side is the item quantity.
Then turn this unit on!  The programming boards will work together to handle the rest

When you change any of the item values, turn this unit off and
then back on for changes to take effect.
--]]

-- -- a whole new Tiny Factory!!
items[521274609]   = 4 -- Basic Container m
items[1689381593]  = 1 -- Basic Container XS
items[3914155468]  = 2 -- Basic Recycler m
items[373359444]   = 5 -- Container Hub xs
items[812400865]   = 1 -- Databank xs
items[4181147843]  = 5 -- Manual Switch XS
items[3415128439]  = 6 -- Programming Board XS
items[184261558]   = 1 -- Screen M
items[184261427]   = 1 -- screen xs
items[2738359963]  = 1 -- Static Core Unit XS
items[2793358078]  = 2 -- Uncommon 3D Printer m
items[648743083]   = 1 -- Uncommon Chemical Industry m
items[2861848558]  = 2 -- Uncommon Electronics Industry m
items[2200747728]  = 2 -- Uncommon Glass Furnace m
items[2808015394]  = 2 -- Uncommon Metalwork Industry m
items[584577125]   = 2 -- Uncommon Refiner m
items[1132446360]  = 2 -- Uncommon Smelter m

items[1762226636]  = 1 -- Uncommon Assembly Line l
items[1762227855]  = 2 -- Uncommon Assembly Line m
items[1762226235]  = 1 -- Uncommon Assembly Line s
items[2480928550]  = 1 -- Uncommon Assembly Line xs

-- -- Good extras for bigger DUFT builds
items[4139262245]  = 2 -- Transfer Unit l
items[166656023]   = 2 -- Sign xs
items[3026799987]  = 2 -- Uncommon Honeycomb Refinery m


--- << END of user configuration section >> ---

databank_clear  = false --global ... no, do NOT clear the databank next time this starts
--->> databank_clear = true  --global ... yes, DO clear the databank next time this starts
-- don't modify the following
if databank_clear == true then databank.clear() end

databank.setFloatValue("feed_multiplier", feed_multiplier)
databank.setFloatValue("line_multiplier", line_multiplier)
databank.setIntValue("num_lines", num_lines)

databank.setStringValue("orders", serialize(items));
databank.setStringValue("factory_desc", factory_desc)
databank.setIntValue("suppress_debug", suppress_debug)

databank.setStringValue("defaultColHeaderYPos", defaultColHeaderYPos)
databank.setStringValue("colHeaders", colHeaders)
databank.setStringValue("fontSize", fontSize)
databank.setStringValue("topMargin", topMargin)
databank.setStringValue("custom_col_header_yPos", custom_col_header_yPos)

manager.deactivate()
unit.setTimer("on", 0.1)

if screen then screen.activate() end

--- eof ---
