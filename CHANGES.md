# Changes in this version (short reasons)

## New in v2 (chef, linecook1-4, waitress)
1. **hasKey returns true/false.** Every request test was written as `hasKey(k) == 1`, which is never true in this game build: the chef overwrote one request key and the transfer units never saw a request. This is what kept Advanced Overclocks from ever being made.
2. **Report a jam just before stopping.** The chef re-reads a machine's state right before it stops it, and asks for the missing ingredients if it is jammed.
3. **Ask again, fetch the full amount.** A missing ingredient is asked for again after 60 s if it still has not arrived, and the transfer unit aims for the amount the recipe needs, not the line's share.

## From v1

1. **Offer an item only to machines the game says can make it.** Before, items were offered to any machine of a line, so machines took items they could never make.
2. **No re-offering items without a producer list; "confirm item id" row.** An item no machine will make is no longer offered again and again; the screen shows a row telling you to check the item id.
3. **Catalyst hand-back recipes no longer count as makers.** Some recipes only hand a catalyst back, which made glass furnaces and smelters look like makers of the catalyst.
4. **Refused items get two tries, then are not offered to that machine again.** Stops the same refusal repeating.
5. **Refusal and MISSING report, with screen rows.** Says which item, which machine and what kind of problem; MISSING names the cheapest machine you would need to link.
6. **Set a machine's output only once it has really stopped.** A stop that is not forced lets the machine finish first, and setting its output meanwhile failed with `Unknown Schematic`.
7. **By-product filter.** Pure Oxygen and Hydrogen come out of ore recipes as a small side product, so every refiner was offered them and refused. Only a recipe's biggest product now counts.
8. **Away mode.** AWAY button on the screen: every free machine gets one fixed job before you leave; the manager clears it when the factory is started again.
9. **Grey notes strip.** Refusal notes used to be red rows that looked like jammed machines; they now sit in a grey strip at the bottom and are not counted as problems.

Screen: shows every machine fitted to the screen (list sent in pages) and refreshes every 3 seconds.

## Earlier fixes (already have pull requests, see README)
Bug fixes to the manager and cook boards (#1-#7), a higher minimum stock for pure materials (#8), a quieter screen that redraws every 3 s and shows every machine (#9-#11), lighter memory use (#12), a watchdog that backs off before restarting a failing board (#13), and cook boards that drive every linked machine, not only slots 1-18 (#14). The title of each PR says what it changes.
