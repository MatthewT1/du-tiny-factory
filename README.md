# Tiny Factory - Matt's dev version

Built on [MichelV69's Tiny Factory](https://github.com/MichelV69/du-tiny-factory). Huge thanks to him: it is his foundation, I only added things on top, in my own hacky way. If this does not work for you, go back to his original: https://github.com/MichelV69/du-tiny-factory

## New in v2
- **OVERCLOCKS PATCHED.** Advanced Atmospheric and Space Engine Overclocks (and other chef items that need a big batch of one ingredient, like Uncommon Power System) now get made. In the current game build `databank.hasKey` returns true/false instead of 1/0, so the chef's ingredient requests to the transfer units never worked. The chef also missed jams it found just before stopping a machine, and asked for each ingredient only once.
- The chef asks again for an ingredient that has not fully arrived, and the transfer units fetch the full recipe amount, not just the line's share.
- Every change from v1 now has its own pull request (links below), and the `integration` branch has all of them on top of MichelV69's `dev`.

Update from v1: paste the six cook boards again (chef, linecook1-4, waitress). Manager, screen, the screen script and the customer board are the same as in v1.

## What is different
- Machines are only offered items the game says they can make (right machine type and tier).
- Items a machine refuses are remembered; after two tries it is not offered that item again.
- A machine only gets its next item once it has really stopped (no more `Unknown Schematic` spam).
- By-products (for example Pure Oxygen from refiner ore recipes) no longer count as "what this machine makes".
- Catalyst hand-back recipes no longer make furnaces and smelters "makers" of a catalyst.
- Screen: every machine fitted to the screen, 3 s refresh, yellow MISSING rows (no machine of the right type linked), a "confirm item id" row for items nobody can make, and a grey NOTES strip for refusals.
- Away mode: an AWAY button on the screen gives every free machine one fixed job before you leave. The manager clears it on a factory start.

## Files
- `paste/` one JSON per board: manager, screen, chef, linecook1-4, waitress. Paste each into the matching Programming Board (back up your boards first).
- `screen_render/tf_screen.lua` goes INTO the screen (right-click the screen, edit content, Lua mode). It pairs with `paste/screen.json`.
- `customer/` is MichelV69's stock customer board, unchanged. Put your own items in it as in his HOWTOUSE.
- `CHANGES.md` has the reason for each change.

## A note on testing and the PRs
I tested these boards in game on the Settlers server, on a factory with 4 lines and 76 machines, plus offline simulations. All of it was done against the upstream **main** branch, not `dev`, so the boards here are based on main (v1.2.x), not on his `dev` work.

Every change now has a small pull request of its own, on top of his `dev` (draft PRs inside my fork, listed below and in `CONTRIBUTIONS.md` on the `integration` branch). The files in this release already have them, so you do not need the PRs to try them.

## How the new parts work

**Away mode** (set it and leave)
1. Wait until the factory is running normally.
2. Tap the **AWAY MODE** button in the screen header. It turns yellow and says TAP AGAIN: GO AWAY.
3. Tap again within 5 seconds to confirm.
4. Every free machine is given one fixed job. The header counts up: `AWAY ON 12/79 SET`.
5. Leave once it reads all set (for example `79/79`).
6. When you are back, tap the button twice (it says TAP TO RESUME) and normal mode returns.

If you restart the factory from the customer board, the manager clears away mode on its own.

Limits: each transfer unit moves one item while you are away. The chef's assemblers only get the inputs the waitress's transfer units cover, plus what is already in the chef hub. Items with no free machine run on stock only. Refiners only use ore already in the hubs.

**Reading the screen**
- Rows are sorted problems first, then running, then waiting, then idle.
- Red `NO SCHEM`: nobody can make this item. Check the item id in the customer board.
- Yellow `MISSING`: no machine of the right type or tier is linked for this item. The row names the cheapest machine that would make it.
- Grey **NOTES** strip at the bottom: the game refused an item for a machine. Nothing is jammed. If the same note stays for a long time, the item or machine is probably wrong in your setup.
- `Pending`, `Waiting` and `Idle` are normal for Tiny Factory: the machine is waiting for inputs or has nothing to do.

**Smaller changes you will notice**
- Refused items are remembered, so the same refusal is not retried over and over.
- The screen refreshes every 3 seconds instead of every second, which saves script memory.

## More details on each change
Each change has its own pull request in my fork, with the symptom, cause, fix, tests and risks. A short reason for each is in `CHANGES.md`.

**Earlier fixes** (open as drafts in my fork, based on his `dev`):

| PR | Change |
|---|---|
| [#1](https://github.com/MatthewT1/du-tiny-factory/pull/1) | Manager: create the industries table before it is used |
| [#2](https://github.com/MatthewT1/du-tiny-factory/pull/2) | Manager buttonsOn: one activate() per tick instead of a while loop |
| [#3](https://github.com/MatthewT1/du-tiny-factory/pull/3) | Chef/linecook/waitress: use IndustryStatus.stopped for "idle" |
| [#4](https://github.com/MatthewT1/du-tiny-factory/pull/4) | checkCooking: learn `known:<item>` from running machines (inverted test, swapped args) |
| [#5](https://github.com/MatthewT1/du-tiny-factory/pull/5) | Linecook start-up: only round the quantity up when it is not already a multiple |
| [#6](https://github.com/MatthewT1/du-tiny-factory/pull/6) | shuffle(): shuffle the stack's entries; drop the duplicate definition |
| [#7](https://github.com/MatthewT1/du-tiny-factory/pull/7) | checkForOverproducing: compare with the same rounded target doBuild sets |
| [#8](https://github.com/MatthewT1/du-tiny-factory/pull/8) | Manager: higher minimum stock for pure materials, minimums for a few intermediates |
| [#9](https://github.com/MatthewT1/du-tiny-factory/pull/9) | Screen: stop printing a chat line per machine on every redraw |
| [#10](https://github.com/MatthewT1/du-tiny-factory/pull/10) | Screen: redraw every 3 seconds instead of every second |
| [#11](https://github.com/MatthewT1/du-tiny-factory/pull/11) | Screen: show every machine (send the list in pages, new screen script) |
| [#12](https://github.com/MatthewT1/du-tiny-factory/pull/12) | Memory: lighter garbage collection, smaller start-up, heap size in the databank |
| [#13](https://github.com/MatthewT1/du-tiny-factory/pull/13) | Manager watchdog: back off before restarting a board that keeps dying |
| [#14](https://github.com/MatthewT1/du-tiny-factory/pull/14) | Cook boards: drive every linked machine, not only slots 1-18 |

**Newer changes** (draft PRs in my fork, based on his `dev`):

| PR | Change |
|---|---|
| [#15](https://github.com/MatthewT1/du-tiny-factory/pull/15) | databank.hasKey returns true/false, so ingredient requests never worked |
| [#16](https://github.com/MatthewT1/du-tiny-factory/pull/16) | Chef: report a jammed machine's ingredients just before stopping it |
| [#17](https://github.com/MatthewT1/du-tiny-factory/pull/17) | Ask again for a missing ingredient, and fetch the full recipe amount |
| [#18](https://github.com/MatthewT1/du-tiny-factory/pull/18) | Offer an item only to machines the game says can make it |
| [#19](https://github.com/MatthewT1/du-tiny-factory/pull/19) | Catalyst hand-back recipes no longer count as makers |
| [#20](https://github.com/MatthewT1/du-tiny-factory/pull/20) | By-product filter (Pure Oxygen / Hydrogen) |
| [#21](https://github.com/MatthewT1/du-tiny-factory/pull/21) | No re-offering items without a producer list; flag for the screen |
| [#22](https://github.com/MatthewT1/du-tiny-factory/pull/22) | Refused items get two tries, then are not offered to that machine again |
| [#23](https://github.com/MatthewT1/du-tiny-factory/pull/23) | Set a machine's output only once it has really stopped |
| [#24](https://github.com/MatthewT1/du-tiny-factory/pull/24) | Screen: "confirm item id" row |
| [#25](https://github.com/MatthewT1/du-tiny-factory/pull/25) | Refusal and MISSING report, with screen rows |
| [#26](https://github.com/MatthewT1/du-tiny-factory/pull/26) | Grey notes strip on the screen |
| [#27](https://github.com/MatthewT1/du-tiny-factory/pull/27) | Away mode |

#9 and #10 are closed: #11 covers them.
