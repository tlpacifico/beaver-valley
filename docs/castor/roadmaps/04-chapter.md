# 4 — Complete chapter

[Overall roadmap](../roadmap.md) · Previous: [visual dam](03b-visual-dam.md) · Next: [MVP](05-mvp.md)

**Goal:** connect dam, home and food in a playable tale with an ending. Depends on an understandable dam and reliable saving. This milestone will be detailed after the previous tests.

Associated 3D production: [characters P3](3d-characters.md) and [environment A3](3d-environment.md). Produce the home, food, the animals' remaining appearances and the ending after defining the respective interactions.

## Learn

Reuse interactions across stages, manage chapter progression and coordinate lines, events and scenery changes.

## Proposed tasks

- [x] Write a short description of the home and food play before implementing them. See the [provisional play proposal](../chapter-play-proposal.md); its details still need playtesting.
- [x] Prototype the home keeping the verbs tap, carry and place; vary the decision (which part and where) and the visible consequence. Do not require a new interaction system just to differentiate the stage.
- [ ] Test that stage before producing its final elements.
- [x] Prototype the food store with the same verbs, varying the choice of suitable branches and the visible accumulation in the water. Reuse rules and controls she already masters.
- [ ] Test the stage and adjust repetition and trips.
- [x] Connect the three stages to the preparation for winter, with short, repeatable lines.
- [x] Reuse the owl for help and the otter for the lake celebration already integrated in 3b. Do not require otter demonstrations or new animations of it to complete the chapter.
- [x] Extend saving to the home, food, transitions and ending; also recover a session interrupted between stages.
- [x] Create the ending with snow and the family reunited, without suggesting that the beaver hibernates. Allow continuing to visit the valley.
- [ ] Integrate the models and states of the home and food, adapt the owl's cues to the stages and expand the valley with reusable assets. The simplified otter from 3b remains valid. Record sources and exports in the inventory.
- [x] Allow starting a new adventure through a deliberate action, protecting progress against accidental restarts.
- [ ] Play the complete path and try separate sessions with your daughter.

**Prototype status (9 November 2026):** the home and food stages are implemented. The home has three parts, two positions, swap before placement, an occupied-position refusal and a visible wall/roof change; its lodge sits in the lake on a visible mound while the parts are collected on the bank. The food store starts after the lodge with five bundles (three suitable, two thin), a water target beside the lodge, a visible pile, step progress and a thin-bundle refusal that can be swapped. The save schema 2 restores the dam, the home slots, the food pile and the current stage, and it migrates existing schema 1 saves; a session interrupted during a food placement returns the carried bundle to the bank. The third food bundle ends the chapter with snow and the beaver family around the lodge; the overlay can be dismissed to visit the valley, and a protected `Nova aventura` action clears the save only after confirmation. The winter state is restored from the food-complete save without replaying the overlay. Final art, animation polish and the child/device playtest remain open. See [progress](../startup-progress.md).

## Completion criterion

The three stages have a clear action and leave visible changes in the same valley. The ending can be reached without getting stuck. When coming back in another session, she recognizes what she has already done and what she can do next.

The 5–10 minutes per stage suggested in the review are a hypothesis to observe, not a target that forces adding or cutting content. There is no need to play the whole chapter in one go.

**Postpone:** new playable animals, new maps and exclusive systems that are not needed for these three stages.
