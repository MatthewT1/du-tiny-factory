---
last_updated: 2025-09-08T13:16:29-03:00
---
## Getting Started
Go to the `Customer` Programming Board, Right-Click it, select the `Advanced` option, then `Edit LUA`

Now click the "Unit" option, and select `onStart()`.  You should see some LUA code, including a section that looks like this:

```lua

-- -- some example basic items for testing each assembly line
 items[3923388834] = 4 -- Vertical Light XS
 items[3231255047] = 3 -- Vertical Light S
 items[1603266808] = 2 -- Vertical Light M
 items[2027152926] = 1 -- Vertical Light L

-- -- some example complicated items for testing your new Tiny Factory
-- items[286542481] = 1 -- emergency control unit xs
-- items[1866437084] = 1 -- remote controller xs
 items[3663249627] = 2 -- elevator xs

-- items[2093838343] = 2 -- surrogate vr station m
-- items[3667785070] = 2 -- surrogate pod station m
-- items[819161541] = 1 -- modern screen l
 items[953504975] = 2 -- Modern Transparent Screen m

```

Let's take a look at one of those lines in detail.

### In Detail 

```lua
 items[3923388834] = 4 -- Vertical Light XS
```

The three parts you care about are the number in the brackets ("3923388834"), the number after the equals ("4") and the plain-English after the two dashes ("Vertical Light XS").

The first number is the "Item ID".  You can look that up by going to https://dual.wolfe.science/tools/item-database-explorer/ and just typing in the name of the thing you want.  Part of the info you will get back is the Item ID.

The second number is "how much" of the thing referenced by the Item ID you want Tiny Factory to make.

So, you can see that we are going to make "4" of Item ID "3923388834".

In LUA, a double dash `--` is the start of remark / ignored code.  So in this example, it's just a note telling you that Item ID "3923388834" is "`Vertical Light XS`".

So, as you can guess, any line which starts with a double dash `--` has the entire line ignored.  It won't produce anything from whatever that Item ID is.  If you want it to make that, just remove the `--` so it looks like the other lines.

## Adding New Items

To add something new, just copy an existing line, and blank out the existing information, so it looks like this:

```lua
 items[ ] = 0 -- theItemName
```

Then go look up the `Item Name` at the website gave you, and fill that line in appropriately.  Click the "Apply" button to save your changes and end your editing session. Then restart your Tiny Factory by turning the `Customer Board` off for a count of 3, and then back on.