# Changes offered from this fork

Thanks for Tiny Factory and the Settlers version of it. These are some fixes and tweaks I made while running a TF factory on Settlers, in case you want any of them. Each change has its own branch and a draft pull request inside this fork (base `dev`), with the problem, the cause, the fix and how it was tested. Pick any subset; nothing here depends on you taking all of it.

**This branch (`integration`)** = your `dev` plus every open change below, one commit each, conflicts already resolved. It is the "pull everything at once" option.

**Merging single PRs:** each `.lua.config` keeps every handler's code on one JSON line, so two PRs that touch the same board always conflict in that file. Take either side, then copy the merged `sources/.../unit/onStart(1).lua` back into that handler. The few real code conflicts are listed in the PRs.

**"Tested in game"** means the same change ran on my Settlers factory (about 76 machines). Every PR also says what was tested offline (the board code run in Lua with stand-ins for the game).

## Fixes

| Change | Branch | PR | Tested in game |
|---|---|---|---|
| Manager: create the industries table before it is used | fix/manager-industries-undefined | #1 | yes |
| Manager buttonsOn: one activate() per tick instead of a while loop | fix/buttons-on-one-try | #2 | yes |
| Cook boards: use IndustryStatus.stopped for "idle" | fix/industry-status-idle | #3 | no (dev-only bug; my boards came from main) |
| checkCooking: learn known:<item> from running machines | fix/set-known-transfer-unit | #4 | yes |
| Linecook start-up: only round the quantity up when not already a multiple | fix/transfer-unit-modulo | #5 | no (dev-only bug) |
| shuffle(): shuffle the stack's entries | fix/shuffle-work-stack | #6 | yes |
| checkForOverproducing: compare with the same rounded target doBuild sets | fix/overproduce-compare-rounded | #7 | yes |
| Screen: show every machine (pages, new screen script) | fix/screen-show-all-machines | #11 | yes |
| Manager watchdog: back off before restarting a board that keeps dying | fix/watchdog-restart-backoff | #13 | yes |
| Cook boards: drive every linked machine, not only slots 1-18 | fix/drive-every-machine | #14 | yes |
| databank.hasKey returns true/false, so ingredient requests never worked | fix/haskey-boolean | #15 | yes (2026-10-10) |
| Chef: report a jammed machine's ingredients just before stopping it | fix/report-jam-before-stop | #16 | yes (2026-10-10) |
| Ask again for a missing ingredient; fetch the full recipe amount (on #15) | fix/repeat-needs | #17 | yes (2026-10-10) |
| Offer an item only to machines the game says can make it | fix/machine-matching | #18 | yes (2026-10-07) |
| Hand-back recipes no longer make a machine a catalyst maker (on #18) | fix/catalyst-producers | #19 | yes (2026-10-08) |
| By-products no longer make a machine a producer (on #19) | fix/byproducts | #20 | yes (2026-10-08) |
| Stop re-offering an item with no recipe; flag it (on #18) | fix/no-producer-list | #21 | yes (2026-10-07) |
| Remember items a machine type refuses, two tries (on #21) | fix/remember-refusals | #22 | yes (2026-10-08) |
| Only set a machine's output once it has really stopped | fix/wait-for-stop | #23 | yes (2026-10-08) |
| Screen: "confirm item id" row for flagged items (on #11) | fix/screen-bad-item-ids | #24 | yes (2026-10-07) |

Together, #15, #16 and #17 are what made chef items that need big ingredient batches (for example the Advanced Atmospheric/Space Engine Overclocks) get made at all.

## Tweaks and features (optional)

| Change | Branch | PR | Tested in game |
|---|---|---|---|
| Manager: higher minimum stock for pure materials, a few intermediates | tweak/manager-line-mins | #8 | yes |
| Memory: lighter garbage collection, smaller start-up, heap size in the databank | tweak/memory-use | #12 | yes |
| Say which item and machine a refusal was; REFUSED and MISSING rows (on #22 + #24) | tweak/schematic-report | #25 | yes (2026-10-08) |
| Refusal notes in a grey strip, not red rows (on #25) | tweak/screen-notes-strip | #26 | yes, screen live; the strip itself not yet seen |
| Away mode: AWAY button gives every free machine one job (on #26) | tweak/away-mode | #27 | dry run only (2026-10-08); not yet overnight |

Closed: #9 and #10 (screen prints, 3 s redraw) are covered by #11.
