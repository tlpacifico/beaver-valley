# Chapter play — first prototype proposal

These are provisional interaction choices for milestone 4, to be checked in play before producing final assets. The existing dam and its save remain the starting point.

## Home

After completing the dam, the beaver is invited to build a lodge nearby. The child taps a loose part, carries it, and taps one of two highlighted positions on the lodge. Each position visibly changes when filled. Offer a small choice of differently shaped parts so the child can influence the lodge's appearance; keep both positions reachable and allow a part to be swapped before placement. Finishing the lodge leads to the food-store invitation.

Implemented choice (9 November 2026): three differently shaped parts, two positions (front wall and roof), and all parts fit either position. The decision is which part goes where, not whether a part is suitable; the part left over loses its cue after completion. The lodge sits in the lake on a visible mound of branches and moss; the parts are collected on the bank and carried into the water.

## Food store

The child taps a suitable branch bundle, carries it to a highlighted spot by the water, and taps to place it. A visibly unsuitable bundle can be swapped for a suitable one without a penalty. Each placed bundle visibly accumulates in the water. Start with a small number of trips and adjust after observing play rather than targeting a duration.

Implemented choice (9 November 2026): five bundles on the bank, three suitable and two thin. Three suitable bundles fill the store at a highlighted spot in the water beside the lodge; the thin bundles are refused and can be swapped. The pile stays visible, the progress line shows three steps and the third bundle completes the stage. The food stage starts immediately after the lodge; home and food progress are saved in schema 2.

## Ending

After the third food bundle, the valley turns to winter: snow falls, snow patches cover the grass and the lodge roof, and the beaver family waits by the lodge. A short overlay says `O inverno chegou!` and the family is together; there is no hibernation. `Continuar a visitar` keeps the winter valley, and a protected `Nova aventura` action asks for confirmation before clearing the save. The winter state is restored from a completed save without replaying the overlay. Implemented 9 November 2026 with procedural visuals; final art remains open.

## Continuity and validation

Use the existing movement, carrying, placement and owl-help conventions. Save each durable placement and the current stage; reopening during an action returns the carried item to a safe available position. Preserve earlier dam saves. Observe the home prototype before final home production, then test the food prototype and adjust trips. The number of parts and exact placement positions are prototype decisions, not validated requirements.

Implemented persistence (9 November 2026): save schema 2 stores the two home slots and the placed food bundles, derives the current stage from them, migrates schema 1 saves and returns carried or reserved items to safe origins. The ending is not saved yet because it has not been implemented.
