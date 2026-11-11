# Mixed-Material Dam Implementation Plan

> **For agentic workers:** use the executing-plans skill to implement this plan task by task. Follow repository instructions; do not commit without the author's request.

**Goal:** build a new-adventure dam using five branches, five tree-sourced logs and five stones, delivered in any order.

**Architecture:** introduce a small recipe/progress model shared by world interaction and save validation. Reuse the current collect/carry/place presentation and authored tree fall; generalize their data rather than copying five interaction sequences into the world controller.

**Tech stack:** Godot 4.7.2, typed GDScript, Compatibility renderer, PowerShell wrapper.

**Spec:** [mixed-material dam design](mixed-material-dam-design.md). The agreed gameplay is recorded there; architecture and compatibility choices follow its defaults.

**Status (11 November 2026):** tasks 1–4 and the desktop/export part of task 5 are implemented; evidence, commands, build hashes and captures are in [startup progress](startup-progress.md). The ticked boxes record the progress notes and the passing `./tools/castor.ps1 check`; the red-before-green step of task 1 was not independently re-verified. Still open: the child observation (last box), real device/touch on the POCO (the task 5 export box only covers the export), author visual acceptance, and the canopy that partly hides the beaver while it gnaws. Task 3 also added a 3 m east-bank terrain extension (+144 reachable cells); it is a source-placement extension, not the N3 deliverable.

## Global constraints

- English developer artifacts; European Portuguese child-facing text and voice.
- New recipe: exactly five branches, five logs and five stones. Each of five trees yields one log. Free collection/delivery order; one carried object.
- Old saves retain their recipe and progress. No global tool changes or unrequested commits.
- Optional grass/mud finishing, zone choice, swimming and new seasons are not completion prerequisites.
- Keep water within the existing safe bounds and source locations reachable at every prepared level.

## Review focus

- Duplicate taps and action interruption: each physical object contributes at most once (tasks 3–4).
- Partial legacy saves and schema failures: keep a completable chapter and existing backup recovery (task 2).
- Mixed delivery orders: a branch/log placed before stones is grounded and readable (task 4).
- Foreground trees, feedback panels and narrow views: required actions remain visible/selectable (task 5).
- Flooded land and cargo retargeting: all required sources have usable round trips (tasks 3 and 5).

## Task 1 — Define recipe and progress independently of the world

**Create:** `game/scripts/dam_recipe.gd`, `game/scripts/dam_progress.gd`, `game/tests/dam_recipe_test.gd`.
**Modify:** `tools/castor.ps1` to register the focused test.

**Proposed interfaces:** `DamRecipe.for_id(recipe_id: String) -> Dictionary` returns requirements and stable source/slot definitions; `DamProgress.configure(recipe_id: String) -> void`, `can_place(material_id: String) -> bool`, `place(material_id: String) -> int` (slot index, or -1 without mutation), `count_for(material_type: String) -> int`, `is_complete() -> bool`, and `placement_records() -> Array[Dictionary]`.

- [x] Specify both recipes and explicit object-to-type mappings. Give each new recipe five stable IDs per type and deterministic compatible slots; do not infer type by string prefix in save validation.
- [x] Add a focused test for requirements 5/5/5, reversed/interleaved orders, duplicate/unknown ID rejection, per-type capacity and exactly one transition to complete. Prove the test fails before implementing the model.
- [x] Implement the small model, then run the focused test. Expected marker: `CASTOR_DAM_RECIPE_OK`. No live chapter integration yet.

## Task 2 — Preserve old adventures and persist the new recipe

**Modify:** `game/scripts/dam_save.gd`, `game/tests/dam_save_test.gd`, `game/tests/save_fixture_test.gd`, and the save/restore integration in `game/scripts/movement_world.gd`.

**Interface:** schema 4 adds `recipe_id`, `placements` (object ID and stable slot/zone identity), and `cut_tree_ids`; exact keys are finalized together with validator fixtures. Retain chapter/home/food fields; recipe definitions from task 1 validate identity and capacity.

- [x] Add fixtures for schema 1/2/3 partial dams, completed dams and winter, plus mixed-recipe partial state, five distinct cut trees and carried-item restoration. Legacy `tree_cut` maps to the original legacy tree/source relationship.
- [x] Verify failing assertions for invalid duplicates, unknown trees, a placed tree log without its cut source, wrong type/slot pairing and inconsistent completion. Include corrupt/backup recovery and failure to write.
- [x] Implement in-memory migration to `legacy_three`; new adventures select `mixed_fifteen`. Ensure migration alone does not rewrite the old file or reset a chapter. Never reuse the old validator's maximum-three rule for mixed saves.
- [x] Run save and fixture tests with isolated directories. Existing success markers must pass alongside the added recipe assertions before live mixed gameplay is enabled.

## Task 3 — Supply five trees, five logs and five stones

**Modify:** `game/scripts/branch_tree.gd`, `game/scripts/collectible_branch.gd`, `game/scripts/valley_layout.gd`, `game/scripts/movement_world.gd`, `game/tests/tree_branch_test.gd`.
**Create:** `game/tests/mixed_material_sources_test.gd` and register it in `tools/castor.ps1`.

**Interfaces:** add `material_type: String` to the existing collectible independently of `Kind`; author per-tree dictionaries with stable tree/log IDs, work/landing points and fall direction. A tree request identifies a particular tree; the world owns the ID-to-tree and ID-to-object registries. Preserve the legacy branch relationship for legacy recipes.

- [x] First add a heading assertion and fix the confirmed gnaw-facing defect. Check approaches from spawn and two other reachable directions.
- [x] Add tests requiring exactly five trees, one unique log per tree and five ground objects of each other type. Reject collection of hidden logs and repeated harvest. Reproduce tap/retarget/reload interruptions against different tree IDs.
- [x] Generalize the existing lifecycle without duplicating it per tree. Keep one active action and the existing cancellation/save semantics. Represent new stones with distinguishable small models and collection cues, sharing the carrying contract.
- [x] Author safe work and landing points; check terrain, flooded states, collision, path clearance and fall bounds. Relocate scenery or schedule a small ground expansion if the current area is too crowded.
- [x] Run focused source/tree tests. Expected additional marker: `CASTOR_MIXED_MATERIAL_SOURCES_OK`; old tree/home/food interaction tests remain green.

## Task 4 — Deliver and present all 15 placements

**Modify:** `game/scripts/movement_world.gd`, `game/scripts/visual_environment.gd`, `game/scripts/valley_terrain.gd`, `game/tests/construction_feedback_test.gd`, `game/tests/chapter_feedback_test.gd`, `game/tests/river_flow_test.gd`.

**Interfaces:** world commits through `DamProgress.place()`, saves the result and presents its returned slot. Visual placement positions come from stable slots rather than arbitrary delivery order. Water/flow consume clamped normalized presented progress; legacy progress retains the original three-placement behaviour.

- [x] Extend integration tests to complete all-stones-first, all-logs-first and interleaved orders. Assert counts update on delivery, completion fires only at 5/5/5, and final-flight repeated taps cannot consume another object.
- [x] Replace unconditional three-count assumptions in active mixed gameplay, HUD, capture helpers and stage gates with recipe-aware checks. Retain explicitly legacy fixture behaviour.
- [x] Add 15 visible grounded placements and clear material silhouettes. Reuse the flight/signal contract; replaying a save must not re-emit placement effects. Show the three counters without obscuring the work area.
- [x] Map presented progress to the existing prepared water range; keep meshes/materials cached. Test that every delivery responds visually and no level exceeds the existing safe maximum.
- [x] Verify home, food and ending follow completion, with no grass/mud requirement. Run `./tools/castor.ps1 check`; all existing and new suite markers must pass.

## Task 5 — Validate the actual play experience

**Modify as needed:** layout, camera/feedback and tests owning any discovered defects. Record results in `docs/castor/startup-progress.md`; update the expansion roadmap without claiming unrun acceptance.

- [x] Capture standing/gnaw/fall/pickup and mixed partial dams from the normal play camera, including 960 × 600 and the target device aspect ratio. Check panel overlap, occlusion and edge selection.
- [x] Traverse required routes with each material at all relevant water states; retarget on the grove loop and return to construction. Compare reachable area to the prior layout instead of counting decorative ground.
- [x] Run `./tools/castor.ps1 check` after integration fixes; export with the appropriate repository command and record build/device identifiers. Device checks remain pending until actually run on the device.
- [ ] Observe the child playing the new recipe: whether trees/stones are discovered, counters understood, trips remain interesting and the story continues without help. Record observations separately from technical pass/fail. Do not introduce a minimum playtime target.

Focused tests use the Godot console and command pattern documented in [how to run](how-to-run.md), with isolated save directories. Do not delete or overwrite the family's normal save. Optional finishing is a later design/task and is not part of this checklist.
