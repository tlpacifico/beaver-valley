# 3a — Playable dam

[Overall roadmap](../roadmap.md) · Previous: [first play](02-first-play.md) · Next: [visual dam](03b-visual-dam.md)

**Goal:** a short, complete stage that represents the game experience. Depends on validating the interaction and the device in milestone 2. Review this plan with what that test teaches.

Use provisional shapes and voice from the start. The production of the game's models is in milestone 3b, to separate gameplay problems from modeling difficulties. First carry out the simple path with saving, then each obstacle with help and, finally, the personalization; verify each increment before adding the next.

## Learn

Organize the states of a task, save and load local data, connect audio and provisional visual responses to actions, and present help without constantly interrupting. Integrating the character animations belongs to 3b.

## Proposed tasks

- [ ] Before starting this milestone, decide whether stones and mud come into the MVP dam and with what role. Update the inventory and the interaction/production tasks; do not confuse scenery stones with collectible materials.
- [ ] For each candidate material, test a distinct role that she understands through the game's cues without additional explanation from the adult. Mud only as a finish is a hypothesis. Validate with provisional shapes in 3a and postpone the material if it does not add an understandable choice, updating the inventory before the visual production.
- [ ] Test how to show progress through visible building and the game's cues. The `3 / 8` counter in the mockups is illustrative, not a quantity or a mandatory interface.

- [ ] Define the dam's path: first placement, progress, obstacles, finish and completed lake. Choose a small number of materials after observing her pace.
- [ ] Introduce the thick branch after a successful build; allow gnawing it or choosing another.
- [ ] Introduce the rotten branch separately. When collected, the branch bends and the beaver comments; do not require an additional inspect verb. Allow dropping and swapping without penalty.
- [ ] Ensure there is always a suitable material accessible and that no object blocks the path.
- [ ] Add visual and voice help, repeatable. An attempt is a deliberate action of placing an incompatible material; ignore repeated taps during the action. Reset the count when there is progress or a change of situation. After two attempts offer a hint, keeping help on request.
- [ ] In the help, repeat the line and highlight the relevant object with a provisional marker; integrate the owl in 3b. Postpone staged demonstrations per obstacle.
- [ ] Offer at least one finishing choice that stays visible and can be changed.
- [ ] Save after each persistent change: placement, obstacle solved, decorative choice and stage. Use stable identifiers for the materials, without saving paths or intermediate poses.
- [ ] On resuming, return each material not yet placed to its point of origin, preserving completed changes such as the gnawed tip; put the beaver in a safe position. Do not arbitrarily restore an object in hand without saving enough information.
- [ ] Rebuild each material exactly once, without duplicates or losses. Protect the save with temporary writing, platform-appropriate replacement and a valid previous copy; test interruption and recovery instead of assuming that renaming is enough.
- [ ] Integrate [sounds and provisional voice](../audio.md); show the forming of the lake and the invitation to build the home.
- [ ] Test the stage with your daughter, adjusting repetitive trips and confusing cues.

## Completion criterion

The provisional dam can be completed and revisited. She understands the obstacles with the available cues and identifies a choice of her own. Closing while carrying returns the material to its point of origin, preserving completed changes. Reopening after solving an obstacle, changing the finish or finishing the dam recovers progress. Milestone 3b starts with this stable experience.

Write small automated tests for progress and saving rules when they are useful; validate touch, readability and understanding on the real device.

**Postpone until after the MVP:** water leak as a challenge, new obstacles, water simulation and the animals' secondary requests. Avoid a large variety of materials; the decision about stones and mud is explicit before 3a. Do not mechanically repeat trips just to lengthen the stage.
