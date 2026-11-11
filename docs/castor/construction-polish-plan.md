# Construction and Valley Polish Implementation Plan

> **For agentic workers:** use `superpowers:executing-plans` to implement this plan task by task, following the repository instructions. This document is a plan, not authorization to start game implementation in the documentation task. Commit only when the author asks.

**Goal:** make the existing collect → carry → place loop clear and satisfying, then extend its presentation across the chapter and improve the valley around it.

**Architecture:** retain the current world and stage ownership, terrain navigation and save schema. Centralize contextual interface refresh in the world, and separate committed gameplay state from temporary placement effects. Reuse existing actor, audio and water systems; introduce no general quest framework or water simulation.

**Tech Stack:** Godot 4.7.2, typed GDScript, Compatibility renderer, existing Blender/glTF pipeline and PowerShell tools.

**Spec:** [Construction and valley polish](construction-polish-design.md). Read it with [milestone 4b](roadmaps/04b-visual-valley.md) and [how to run](how-to-run.md).

Status: P1 and P2 implemented and verified on Windows (10 November 2026); P3 has partial reported evidence on 11 November: the child finished without help, enjoyed it and asked for more story. Device/build details and remaining observation criteria are open. Later polish increments are not started. The [gameplay and seasons expansion roadmap](roadmaps/seasonal-gameplay-expansion.md) now sequences the agreed gameplay extensions; E1 shares the water work described in P5. The no-swimming/fixed-material constraints below apply to this polish plan; the expansion explicitly scopes the later changes to those rules.

## Global constraints

- Godot 4.7.2, typed GDScript, Compatibility renderer.
- One valley; dam → home → food → winter; existing counts, stable IDs, material suitability and saved finish choices remain intact.
- Tap/click to collect and place; no mandatory reading, dragging, precise rotation or manual camera control.
- Prepared water states; no physical water simulation or swimming.
- English developer documentation, code and logs; European Portuguese child-facing text and voice.
- Editable art sources in `art/`; exported resources in `game/`; third-party provenance in `3d-production.md`.
- Preserve existing saves and protected restart; presentation timers and animation state are not saved.
- No global tool/settings changes. Commit only when the author asks.

## Current code and ownership

| File | Responsibility and relevant existing entry points |
|---|---|
| `game/scripts/movement_world.gd` | Input, dam placement, UI, saves and chapter transitions; `_build_interface`, `_move_from_screen`, `_physics_process`, `_update_water`, `_on_home_completed`, `_on_food_activated`, `_restore_dam_save`, `_update_finish_choices` |
| `game/scripts/collectible_branch.gd` | Material states and `place(parent, target_position, slot_index, animate)`; full-transform flight and stable placed slot |
| `game/scripts/prototype_actor.gd` | Walking and cosmetic `play_place_action()`; leave collision/root movement with the actor |
| `game/scripts/home_stage.gd`, `home_part.gd` | Home placement, slots, cue rendering and lodge geometry; `_finish_placement`, `_update_cues`, `place_at` |
| `game/scripts/food_stage.gd`, `food_bundle.gd` | Food suitability, placement, cache rendering and cues; `_finish_placement`, `_update_cues`, `restore_placements` |
| `game/scripts/provisional_voice.gd`, `provisional_sfx.gd` | Replaceable voice/effect events; voice currently automatically chains `dam_completed` to `home_invite` |
| `game/scripts/valley_layout.gd`, `valley_navigation.gd`, `valley_terrain.gd` | Shared anchors, dry routes, ground/water geometry and prepared water levels |
| `game/scripts/visual_environment.gd` | Dam structure, spillway, vegetation and backdrop |
| `tools/castor.ps1`, `game/tests/` | Import, regression checks and exports |

Create only two new automated test scripts for the first slice: `game/tests/chapter_feedback_test.gd` and `game/tests/construction_feedback_test.gd`. Extend existing tests for saves, routes, water and later-stage placement. Art-only adjustments use graphical comparisons instead of tests that merely assert chosen colours or tree coordinates.

## Review focus

1. A late timer or voice callback must not restore an old objective after a new action or chapter transition — P1.
2. Touching the completed dam while carrying an item must open its finish panel without dropping the item, triggering placement or walking — P1.
3. Repeated placement taps or closing during material flight must produce one persisted placement and an exact restored result — P2, then P4.
4. Moving the work position or scenery must not introduce routes through water, inaccessible targets or foreground occlusion — P2, P5 and P6.
5. A forced save failure must remain visible through completion effects; silent/headless execution and restored games must not depend on audio finishing — P1, P2 and P4.

## Verification commands and evidence

Use the repository wrapper for the full regression pass:

```powershell
./tools/castor.ps1 check
./tools/castor.ps1 playtest
./tools/castor.ps1 export-windows
```

`playtest` clears only the isolated playtest save. Do not delete or repurpose the normal player save. Run commands sequentially; an interactive playtest ends when the window closes.

For a focused test, use the documented project-local Godot installation:

```powershell
$castorGodot = Join-Path $env:LOCALAPPDATA 'Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
& $castorGodot --headless --path game --import
& $castorGodot --headless --path game --fixed-fps 60 --script res://tests/chapter_feedback_test.gd
```

Substitute the test filename for the task under examination. Every focused run must exit 0 and print its success marker; newly proposed markers are named below. Register the two new scripts in the wrapper with explicit failure handling. Expected warnings from deliberately forced save failures remain distinct from unexpected errors.

Keep comparison captures/recordings under ignored `builds/construction-polish/`. Existing capture flags include `--capture-initial`, `--capture-water`, `--capture-home`, `--capture-food` and `--capture-ending`, using isolated capture saves. These stills do not prove event timing: record actual interactive placement separately. Update `startup-progress.md` after each implemented increment with commands, evidence paths and unresolved human/device checks.

## P1 — Show the current task and contextual choices

**Modify:** `movement_world.gd`, `provisional_voice.gd`, cue functions in `home_stage.gd` and `food_stage.gd`, `tools/castor.ps1`.

**Create/test:** `chapter_feedback_test.gd`; extend `movement_test.gd`, `ending_test.gd` and relevant forced-save-failure checks in `home_stage_test.gd` / `food_stage_test.gd`.

**Proposed interfaces in the world:**

- `_refresh_chapter_interface() -> void`: derive objective, progress and contextual controls from existing committed stage/carry state. It does not advance stages or save.
- `_show_stage_completion(text: String, duration: float = 2.0) -> void` and `_clear_stage_completion() -> void`: own one transient message and invalidate its earlier expiry callback when replaced.
- `_set_finish_panel_open(is_open: bool) -> void`: change only panel visibility. Selection still uses `select_finish_choice(choice_id: String) -> bool`.

**Voice interface:** add `event_finished(event_id: String)` to the existing player; replace its unconditional `dam_completed` → `home_invite` chain with a context-checked world response. `cancel()` invalidates the old event. Audio completion must never activate gameplay or control persistence.

- [x] Add regressions for dam → home → food transitions, restoring each stage, completion expiry after 2.0 seconds, early dismissal by a new action, replacement by a newer completion, and sticky save-failure feedback. Assert that old finish controls/invitations are absent during ordinary food play. Confirm the regressions fail against the current overlapping behaviour.
- [x] Implement the three UI operations above and route transition, restore, pickup, placement, cancellation and movement updates through them. Preserve obstacle-specific status and help. Derive stage by progression order: winter, food, home, dam; earlier stages may remain active internally.
- [x] Use containers/anchors for the compact objective, progress, help and transient region. Keep child-facing text from the design; preserve title hold and restart confirmation. Keep subtitles readable without permanent duplicate invitations.
- [x] Make pickup cues quiet closed rings and destination cues broken outlines or silhouettes. Carrying a suitable item emphasizes compatible destinations; help may strengthen them. Preserve discoverable alternate materials and obstacle guidance.
- [x] Add a completed-dam hit target matching its visible crest. Before completion it uses existing placement behaviour; after completion it opens the optional finish panel without cancelling collection/carry state. Handle this before the existing placement-target path clears other stages' pending actions. UI controls consume their click/touch without forwarding it to the world.
- [x] Offer the finish panel after the dam celebration; close it on choice, “Fechar”, or another world action. Allow reopening during home, food and winter visits, but not through the ending/restart modal. Restore the selected accent with the panel initially closed.
- [x] Add mouse and touch regressions for opening the panel with a carried home part/food bundle, changing a finish, closing without choosing, and restoring an unset finish. Assert item identity and counts remain unchanged. Retain protected restart tests.
- [x] Connect voice completion with a stage/event validity check. Test a late `dam_completed` callback after a food transition and after `cancel()`; neither may play an obsolete invitation. With headless/no audio completion, stage progress and message expiry must still work.
- [ ] Run `chapter_feedback_test.gd` (expected `CASTOR_CHAPTER_FEEDBACK_OK`), the affected existing tests and the full wrapper. Capture the food screen before/after, the completed dam with the optional panel, and the same scene after closing it. Check the layout at 960 × 600 and on the target phone; label desktop resizing separately from device validation.

**Exit:** the screenshot's conflicting permanent messages are resolved, finish selection remains accessible, and the existing chapter and save behaviour pass regression checks.

**Recorded evidence (10 November 2026):** code and the new `chapter_feedback_test.gd` are complete; the red baseline is `builds/construction-polish/p1-red.log` and the green wrapper output is `builds/construction-polish/p1-check.log`. The later P2 capture flows produced the desktop 960 × 600 evidence `finish_panel_open.png`, `finish_panel_closed.png` and `food.png` under `builds/construction-polish/`. The target-phone layout check and a formal before/after comparison remain pending; the desktop captures are not device validation.

## P2 — Coordinate one complete dam placement

**Modify:** `movement_world.gd`, `collectible_branch.gd`, `prototype_actor.gd` only if gesture tuning is needed, `valley_layout.gd`, `tools/castor.ps1`.

**Create/test:** `construction_feedback_test.gd`; extend `branch_flight_test.gd`, `movement_test.gd`, `save_fixture_test.gd`, `valley_navigation_test.gd`, `valley_traversal_test.gd` as needed.

**Proposed interfaces:** retain `CollectibleBranch.place(...)` and its instant restore path. Add `placement_visual_finished(slot_index: int)` emitted exactly once at the end of an animated placement, never during instant restore. In the world, `_on_dam_placement_visual_finished(slot_index: int, sequence_id: int) -> void` consumes that signal with the current presentation generation. A scene-local generation invalidates old callbacks; it is not saved.

- [x] Add regression cases proving one branch/count/save entry after repeated taps, full final transform at flight end, silent instant restore, and no callback side effects after scene disposal. Add a save fixture captured during the 0.45-second flight: restoring it must show one final placement, the correct water state and no transient celebration.
- [x] Preserve the existing commit at arrival of the beaver: assign the slot, clear carried state, increment the count and save once. Separate immediate durable state from delayed sound, growth, water animation and celebration. Save failure still shows its warning; visual completion is not a second save.
- [x] Start the existing gesture and branch flight together. At material arrival play one impact/completion sound, reveal the construction response, then animate the prepared water for 0.7 seconds. Use existing effects initially. Ensure already-visible dam structure does not jump to its new count before arrival through another refresh call.
- [x] Let movement/help remain responsive. During a committed flight, another request may interrupt the actor gesture but must not return the placed branch to its origin. If another placement commits before the earlier response ends, reconcile presentation to the latest committed count and never lower the visible water or replay an older stage invitation. Delay the optional next-stage invitation until the final placement response, without making saved stage completion depend on it.
- [x] Keep levels `[initial, intermediate, full, full]`. Test the last placement's structural/celebration response despite no further water rise. Keep downstream level fixed and cache visibility intact.
- [x] Compare the current `dam_approach` anchor with the closest viable dry bank candidate connected to the collection area and lodge. Keep all coordinates in `ValleyLayout`; check path segments against navigation and the maximum lake footprint. Retain the current anchor if no candidate improves distance safely. Record the chosen position and remaining visual gap.
- [ ] Run the focused tests (`CASTOR_CONSTRUCTION_FEEDBACK_OK` for the new script), existing branch-flight/water/save/navigation tests and the full wrapper. Record first and final branch placement from the play camera, including a movement interruption and reopening a mid-flight save. Listen to effects/voice in a graphical run.

**Exit:** one short sequence visibly connects the beaver, placed material and changing valley without losing control or progress. No broader tree/lodge production is required for this checkpoint.

**Recorded evidence (10 November 2026):** `construction_feedback_test.gd` and the extended branch-flight/save/navigation/traversal tests pass; the red baseline is `builds/construction-polish/p2-red.log` and the green wrapper output is `builds/construction-polish/p2-check.log`. Desktop captures `placement_first_flight.png`, `placement_first_done.png` and `placement_final_done.png` show the commit/presentation split and the completed structure from the play camera. The approach comparison kept `dam_approach` at `(0.0, −0.2)` (5.37 m from the dam centre); the closest safe candidate `(−1.5, −3.2)` shortens that to 4.02 m but raises combined walking from 11.28 m to 15.61 m. A movement interruption and a mid-flight save restore are covered by the test but were not recorded on video; audio listening, real touch and the target phone remain pending.

## P3 — Observe the first slice before expanding it

**Modify:** `startup-progress.md`; revise this plan/design only where observations change the proposal.

- [ ] Export and run the Windows build; on the POCO, export/install/run using `how-to-run.md` when the device is available. Record device, build and whether the evidence is an editor run, exported executable or installed APK.
- [ ] Rehearse collection, thick/rotten branch handling, placement, finish choice and interruption/resume. Record any defect before asking the child to try it.
- [ ] Offer a willing 5–10 minute session with minimal initial explanation. Record mistaken targets, help needed, recognition of the change, waiting/repetition and spontaneous interest. Use the observation guidance in the design; stop on frustration or loss of interest.
- [ ] Record a decision: refine P1/P2, proceed to P4/P5, or investigate an observed gameplay problem. If a child/device session cannot happen, mark it pending and keep later visual work provisional; do not claim acceptance.

**Exit:** a concrete observation and next decision, or an explicit pending gate. Do not convert test success into evidence of enjoyment.

## P4 — Extend placement feedback and clarify the lodge

**Modify:** `home_stage.gd`, `home_part.gd`, `food_stage.gd`, `food_bundle.gd`, `movement_world.gd`; editable sources in `art/` only if replacing procedural visuals with authored models.

**Test:** `home_stage_test.gd`, `food_stage_test.gd`, `ending_test.gd`, `save_fixture_test.gd`, `construction_feedback_test.gd`.

**Interfaces:** use `place_at(parent: Node3D, target_transform: Transform3D, slot_index: int, animate: bool = false) -> void` in both `HomePart` and `FoodBundle`. This extends their current three-argument calls; the food bundle's currently unused `_slot_index` becomes the event's slot index. Both material types expose `placement_visual_finished(slot_index: int)` for live presentation only. Existing `part_placed` / `placed` / `completed` signals continue to describe committed state; separate visual completion from them. Preserve target scale as well as position and orientation: the lodge's slot transforms include non-uniform scale, so do not copy the branch flight's basis orthonormalization unchanged.

- [ ] Add interrupted-placement, duplicate-tap, exact-transform and instant-restore regressions for home and food. Keep unsuitable food refusal and the home slot-choice rules. Verify forced save warnings survive the animation and stage transition.
- [ ] Reuse the actor gesture, 0.45-second transfer and arrival sound pattern. Stage logic commits once and saves through its existing signals; UI/narration waits for the appropriate live presentation response. Restoring any stage applies final visuals immediately without effects.
- [ ] Reshape the procedural lodge into three readable states: foundation/mound, one completed build position, complete rounded shelter. Preserve two slots, three available material choices and their stable IDs; reduce straight plank dominance through meshes/materials, not save-ID renames.
- [ ] Preserve the floor above the sampled bed, submerged entrance, dry approaches, camera-ray selection of both slots, cache visibility and roof-aligned snow. If using Blender sources, keep them under `art/` and document origin/license before exporting.
- [ ] Capture partial and complete lodge states, first/final stored food and winter from the same camera. Run affected tests and `check`; rehearse the complete chapter in the exported build. Confirm late placement callbacks cannot reopen a pre-winter UI.

**Exit:** all three activities share clear placement feedback while retaining their existing rules; the lodge visibly grows into a beaver shelter.

## P5 — Improve river, banks and lighting

**Modify:** `visual_environment.gd`, water presentation in `movement_world.gd`, and `valley_terrain.gd` only where bank/material treatment requires it. If a separate shader is needed, create `game/shaders/valley_water.gdshader` and test it in Compatibility.

**Test:** existing `valley_water_test.gd`, `visual_environment_test.gd`, `valley_terrain_test.gd`, `food_stage_test.gd`; graphical comparison and device rehearsal.

- [ ] Capture initial, one-branch, two-branch and completed water, plus food/winter. Preserve the existing camera as the comparison baseline.
- [ ] Add subtle downstream surface movement and calmer upstream variation using the existing water mesh/material pipeline. Keep shoreline clipping, water levels and the cache alpha/colour window; no new simulation or per-frame mesh rebuilding. Prefer a simple material effect and fall back to static water if device cost/readability worsens.
- [ ] Tune bank colour transitions and sun/ambient balance to reduce distracting shadow masses while preserving depth. Make one change at a time; avoid using dense scenery to hide terrain problems. Only adjust framing if a recorded target occlusion/scale issue remains.
- [ ] Verify the four water states, fixed downstream level, dry routes, submerged food centres and visible cache. Check shader/material rendering in a real Compatibility window; headless tests do not establish rendering correctness.
- [ ] Export and perform the existing 15-minute priority-device rehearsal when available. Record frame-time observations, responsiveness and heating compared with the baseline; keep Android pending if no device is attached. Run the affected tests and full wrapper after the final retained change.

**Exit:** the river's state changes are legible and the playable bank, lodge and cache remain readable in the accepted framing. No device-performance claim without measurements on the device.

## P6 — Compose vegetation and close the pass

**Modify:** `visual_environment.gd`; `valley_layout.gd` if shared placement exclusions are needed; `3d-production.md` for any new third-party asset; `startup-progress.md` and milestone status notes.

- [ ] Group existing trees/bushes/rocks around the collection clearing and background. Use deterministic scale/rotation variations; leave foreground sightlines, touch targets, approaches and the maximum lake footprint clear.
- [ ] Review before/after full-valley captures at the actual play distance. Add another tree model only if this review identifies a specific missing silhouette; document its editable source and provenance. A larger asset catalogue is outside this pass.
- [ ] Rehearse all routes and target selection with the scene populated. Check winter as well as the initial valley; vegetation must not hide required materials or the family.
- [ ] Run affected existing checks and the full wrapper, then export. Gather author visual acceptance and remaining adult/child/device evidence. Record each separately in the existing milestone notes.
- [ ] Carry unresolved findings forward explicitly. Keep milestone 4b/5 gates open where evidence is missing; propose new content only from the observed response to the polished chapter.

**Exit:** a coherent existing chapter, with acceptance evidence and remaining limitations recorded. No automatic commit or milestone closure.
