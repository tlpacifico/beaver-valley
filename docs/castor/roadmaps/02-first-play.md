# 2 — First play

[Overall roadmap](../roadmap.md) · Previous: [first steps](01-first-steps.md) · Next: [dam](03a-playable-dam.md)

**Goal:** your daughter places three branches and sees a small dam come to life. Depends on an exportable scene from milestone 1. This experiment is an intermediate test, not the complete MVP.

Visual production in this milestone: use the provisional volumes from the [environment](3d-environment.md) and prepare the references and actions for the [characters](3d-characters.md). After this play, validate the provisional dam in 3a. Only in 3b produce and integrate the first animated beaver and the stretch of the valley with the chosen finish.

## Learning needed

Detect the object or point in the world under the touch/click; calculate a walkable path; represent simple states such as "free", "carrying" and "placed"; give a visual and sound response to the action.

## Engine-specific implementation sequence

Start with the existing `game/scenes/movement.tscn` and `game/scripts/movement_world.gd`; preserve the cube and asset test scenes. The exact decomposition can change as the prototype is built.

1. **Area and movement:** adapt the movement scene and `prototype_shapes.gd` to a small bank, water and clear placement area. Reuse `prototype_actor.gd` and the XZ `AStarGrid2D` path while it fits the area. Check free and blocked destinations, reachable paths, retargeting and framing with mouse and touch.
2. **Three branches:** add a branch scene and script under `game/scenes/` and `game/scripts/`, using the existing test branch as a provisional asset. Select a branch by click/tap, approach a reachable point and switch its state from free to carried only on arrival. Show the carried branch; repeated selections must not create copies. Check selecting another branch, inaccessible targets and changing destination.
3. **Placement and water:** add a wide placement target and simple state in the world script or a dedicated script. Approach before placing; update the branch and one of three prepared water states once per placement. Support dropping or swapping and verify that three branches remain accounted for during repeated input.
4. **Feedback and trial:** add destination, visual and provisional voice cues following `audio.md`, an adult restart, and a recognizable placeholder beaver. Extend `game/tests/movement_test.gd` or add focused integration tests for the interaction states. Run `./tools/castor.ps1 check`, export both builds, and try the complete sequence on PC and the real phone before inviting the child. Record observations and device choice here or in linked progress notes.

These are proposed files and checks, not a new interaction system already implemented. Choose final camera behavior and art origin through the milestone's observations.

## Tasks

- [x] Prepare a small area with ground, bank, water and building target, using simple shapes. The water and target are visual placeholders and remain walkable; interaction is not implemented.
- [ ] Try a diorama camera, fixed while the whole usable area fits on the screen. Before expanding the valley, test smooth following of the beaver with a fixed angle and no manual rotation. If the target leaves the frame, try an indicator at the edge; only keep it if it helps orientation. Test object selection with the camera moving.
- [ ] Tap/click a point for the beaver to walk there. Show where it is going and prevent unreachable targets.
- [ ] Tap/click a branch to approach and collect it; clearly show what it is carrying.
- [ ] Tap/click a wide slot to approach and place. Do not require dragging or fine precision.
- [ ] Allow dropping or swapping the branch and handle repeated taps without duplicating materials.
- [ ] Prepare three visible changes in the water, one per placement. Do not physically simulate the river.
- [ ] Prepare the [script per event and the provisional voice](../audio.md) before testing with the child; choose the origin of the voice. Add visual cues and repetition without overlapping lines. Text can support, but must not be necessary.
- [ ] Prepare a restart of the experiment for the adult, without confusing the child's controls.
- [ ] Test the complete path on the PC and on Android beforehand.
- [ ] Invite her to play for a few minutes, trying both devices at comfortable moments.
- [ ] Adjust the main point of confusion and observe again only as much as needed.
- [ ] Record the choice of the priority device and whether camera and interaction serve as a basis for the dam.
- [ ] At the end of this milestone, try a beaver made of simple volumes, flat colors and a recognizable tail in the real camera and on Android, without requiring a skeleton. Record who is responsible for/origin of the art and viable finish before milestone 3b; this test does not automatically set low-poly as the final style.

## Observe, without turning it into an exam

Does she understand where to tap? Can she reach the branch? Does she notice she is carrying it? Does she find out where to place it? Does she see that the water changed? Does she want to place another one?

Start with an invitation such as «vamos ajudar o castor a fazer uma represa» ("let's help the beaver build a dam"). Give time to explore; help when necessary and note the help. Avoid explaining each action before observing the attempt. The second device benefits from what she already learned on the first: do not treat the comparison as a rigorous measurement.

Simple log:

| Device and version | What she tried | Where she needed help | Reaction to the water | Next change |
|---|---|---|---|---|
| To be filled in | | | | |

## Completion criterion

She can repeat the collect → carry → place sequence without continuous explanation and recognizes the consequence in the water. The priority device is chosen by her comfort and by technical viability. If there is no interest, review the interaction and the reward before adding content.

**Adjustment to the brainstorm:** postpone the thick and rotten branches to milestone 3a. That way, the first observation tests only the main action. The original proposal included both in the first prototype; this roadmap splits that prototype into two smaller deliveries. Stones and mud remain as candidates for a decision before 3a; they are not needed in this three-branch test.
