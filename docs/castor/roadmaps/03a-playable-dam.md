# 3a — Playable dam

[Overall roadmap](../roadmap.md) · Previous: [first play](02-first-play.md) · Next: [visual dam](03b-visual-dam.md)

**Goal:** a short, complete stage that represents the game experience. Depends on validating the interaction and the device in milestone 2. Review this plan with what that test teaches.

Use provisional shapes and voice from the start. The production of the game's models is in milestone 3b, to separate gameplay problems from modeling difficulties. First carry out the simple path with saving, then each obstacle with help and, finally, the personalization; verify each increment before adding the next.

**Sequencing and materials:** The author chose to begin 3a before completing the remaining milestone 2 observations and to use branches only for now. Collectible stones and mud are postponed; scenery stones do not become materials. The missing observation and device choice remain open.

## Learn

Organize the states of a task, save and load local data, connect audio and provisional visual responses to actions, and present help without constantly interrupting. Integrating the character animations belongs to 3b.

## Proposed tasks

- [x] Decide the initial materials: the author chose branches only for now; postpone collectible stones and mud and keep scenery stones distinct.
- [ ] If stones or mud are reconsidered, define distinct roles and test understanding with provisional shapes before visual production. Both are postponed for now.
- [ ] Test how to show progress through visible building and the game's cues. The `3 / 8` counter in the mockups is illustrative, not a quantity or a mandatory interface.

- [x] Define the dam's path: first placement, progress, obstacles, finish and completed lake. Choose a small number of materials after observing her pace.
- [x] Introduce the thick branch after a successful build; allow gnawing it or choosing another.
- [x] Introduce the rotten branch separately. When collected, the branch bends and the beaver comments; do not require an additional inspect verb. Allow dropping and swapping without penalty.
- [x] Ensure there is always a suitable material accessible and that no object blocks the path.
- [x] Add visual and voice help, repeatable. An attempt is a deliberate action of placing an incompatible material; ignore repeated taps during the action. Reset the count when there is progress or a change of situation. After two attempts offer a hint, keeping help on request.
- [x] In the help, repeat the line and highlight the relevant object with a provisional marker; integrate the owl in 3b. Postpone staged demonstrations per obstacle.
- [x] Offer at least one finishing choice that stays visible and can be changed.
- [x] Save after each persistent change: placement, obstacle solved, decorative choice and stage. Use stable identifiers for the materials, without saving paths or intermediate poses.
- [x] On resuming, return each material not yet placed to its point of origin, preserving completed changes such as the gnawed tip; put the beaver in a safe position. Do not arbitrarily restore an object in hand without saving enough information.
- [x] Rebuild each material exactly once, without duplicates or losses. Protect the save with temporary writing, platform-appropriate replacement and a valid previous copy; test interruption and recovery instead of assuming that renaming is enough.
- [ ] Integrate [sounds and provisional voice](../audio.md); show the forming of the lake and the invitation to build the home. Voice cues, sound effects, water change and invitation are implemented; listening checks remain open.
- [ ] Test the stage with your daughter, adjusting repetitive trips and confusing cues.

Implementation checks above describe the current provisional implementation and automated coverage, not a child or device validation. The home invitation, voice cues and sound effects are present; listening checks remain open.

## Completion criterion

The provisional dam can be completed and revisited. She understands the obstacles with the available cues and identifies a choice of her own. Closing while carrying returns the material to its point of origin, preserving completed changes. Reopening after solving an obstacle, changing the finish or finishing the dam recovers progress. Milestone 3b starts with this stable experience.

Write small automated tests for progress and saving rules when they are useful; validate touch, readability and understanding on the real device.

**Postpone until after the MVP:** water leak as a challenge, new obstacles, water simulation and the animals' secondary requests. Avoid a large variety of materials; the decision about stones and mud is explicit before 3a. Do not mechanically repeat trips just to lengthen the stage.
