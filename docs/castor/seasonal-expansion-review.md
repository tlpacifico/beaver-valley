# Seasonal expansion implementation review

Date: 11 November 2026.
Scope: the working-tree implementation of N1, E1, N2 and E2 relative to `f75585c`, including untracked scripts, shader and tests. This is a review, not an implementation pass or milestone acceptance.

The first expansion slice has useful engineering foundations: shared obstacle authoring for visuals/collision/navigation, cached water materials, stable branch identities, save migration and interruption coverage. It does not yet deliver the whole [expansion roadmap](roadmaps/seasonal-gameplay-expansion.md). The main outstanding product goals are a genuinely larger explorable valley, a construction choice and a playable seasonal continuation.

## Findings requiring correction

### R1 — P2: face the tree before starting the gnaw animation

Location: `game/scripts/movement_world.gd`, `_run_tree_fall()`, lines 1133–1137.

The arrival handler calls `actor.play_gnaw_action()` without aiming the actor at the trunk. Movement leaves the actor facing its last travel direction. Starting from a fresh save and requesting the tree interaction produces a horizontal angle of **173.94 degrees** between the actor's forward direction and the tree: the beaver gnaws almost directly away from its target. The branch is still produced, so completion tests pass while the defining visual interaction is wrong.

Reproduction: start the main scene with an isolated empty save, request the tree, wait for `_tree_action_running`, and inspect the actor from the normal play camera. Both headless and graphical probes reproduced the same heading. The forward direction is `-actor.global_basis.z`, consistent with movement and the model's orientation correction.

Proposed correction: aim the actor horizontally at the trunk when it reaches the work point, before the gnaw gesture. Preserve terrain grounding and avoid fighting the movement controller. If turning is animated, start the gesture after the turn is sufficiently complete.

Acceptance: approach from the spawn and at least two other reachable directions; at the start of gnawing the head/body faces the trunk. Verify mouth-to-trunk spacing in the play camera. Add a focused heading assertion to the tree interaction test; a correct fall angle alone does not exercise this defect.

### R2 — P3: reconcile the E2 progress paragraph with the remediated implementation

Location: `docs/castor/roadmaps/seasonal-gameplay-expansion.md`, E2 progress paragraph.

The document header and E2 checklist describe the layer collision, repeated-tap cancellation and fall presentation as fixed, but the E2 progress paragraph still says these majors and their test gaps are open. Current code and the passing focused test contain those fixes. This makes the same roadmap report incompatible states and can send the next implementation pass towards already completed work.

Proposed correction: retain the original failure as review history, explicitly mark its remediation, and list only current open items. Also reconcile the claim that the interactive golden tree is much larger than the decorative golden trees: the implementation notes record the same 0.68 model scale. Distinguish perceived screen size from authored scale.

Acceptance: the header, checklist, progress paragraph and startup notes agree; open items include R1 and the outstanding play/device checks without reinstating fixed defects.

## Roadmap execution and remaining scope

| Stage | Observed result | Assessment |
|---|---|---|
| N1: natural scenery | Stones, mud, vegetation and outer rock formations; cosmetic props do not add walking constraints | Implemented first slice; composition can improve |
| E1: visible current | Animated prepared water surfaces, calmer upstream treatment and placement foam | Implemented visual flow; no physical current or device performance evidence |
| N2: more paths | Five obstacles, alternative routes and a woodland opening inside the existing boundary | Partial against the original opening/widening objective; loop exists, extra walking space does not |
| E2: tree material | One tree supplies an existing branch, with authored fall, persistent state and legacy saves | Implemented with R1 still open; child discovery not observed |
| E3 / E4 | Two dam zones / playable winter continuation | Not implemented |
| N3 / E5 / E6 | Larger valley / controlled swimming / playable spring | Not implemented |
| E7 / D1 | Free swimming / authored branch drift | Optional, not implemented |

N2 is the most important expectation gap. Comparing navigation on the same terrain without the grove against current navigation gives **297 versus 273 walkable cells**, a decrease of 24 cells (about 8.1%). These are navigation samples, not an exact surface-area measurement. The terrain and 13 × 11 m playable rectangle remain unchanged. The existing tests establish connectivity; the new loop creates choices around obstacles rather than opening previously inaccessible ground. The roadmap already leaves its widening/reshaping checkbox open, so this is incomplete scope, not an undisclosed navigation regression.

Proposed response: do not add more blocking scenery to satisfy the request for space. Finish a small N2 widening pass or bring forward the first N3 clearing. Update terrain, collision and navigation together, preserve the short resource routes and compare reachable cells before/after. Keep the castor and tap targets readable rather than zooming out until everything fits. Add one optional discovery to give the new space a purpose.

## Improvements in recommended order

1. **Repair and present the tree interaction.** Fix R1, then capture walking, gnawing, falling and pickup from the actual play camera. The new review capture shows the lower feedback band and text overlapping the tree/beaver area. Move or compact that feedback, or adjust the interaction's framing, so the child can see the action. Debug close-up cameras are useful inspection tools but cannot establish play-camera readability.
2. **Deliver one genuine exploration gain.** Open a small connected land area and give it a recognizable destination. Keep mandatory materials nearby; optional exploration should add discovery rather than commuting. Exercise both loop directions with a branch, home piece and food bundle, including mid-walk retargeting.
3. **Implement E3's two dam zones.** Keep the planned three placements initially, show the selected gap filling and give each placement a local water response. This adds a decision to the main activity without requiring a fluid simulation or repetitive collection.
4. **Implement E4's short winter continuation.** Give the stored food or completed home a visible use in one family activity and end with a small story hook for spring. This addresses the child's reported interest in more story more directly than additional tree models.
5. **Polish the existing scenery before producing more variants.** Break the evenly spaced bank pebbles into irregular pockets with empty stretches; flatten and join some mud shapes so they read as wet ground rather than separate brown discs. Bring the procedural grove trees and golden trees closer in scale/material treatment. Keep decorative clearings visually distinct from interaction rings.
6. **Introduce swimming through E5's controlled crossing.** After land routes and construction are stable, add one clear entry, a short swim and one reliable exit. Free swimming and physical current remain later work; the current shader does not provide either behaviour.

Tree discovery deserves a short child observation: the current objective asks for a branch, while the tree is optional and the dam can be finished using other materials. That fallback is intentional and should remain. If the child misses the tree, try a brief contextual hint such as `Toca na árvore para conseguir um ramo.` or an appropriate existing voice cue before making harvesting mandatory. Do not infer discoverability from the interaction test passing.

## Verification performed for this review

- Ran `./tools/castor.ps1 check`. The log reached the final asset check with all 24 suite success markers and no `ERROR:` or `SCRIPT ERROR`; the deliberate save-failure warnings remain expected. Log: `builds/roadmap-review-check.log`.
- Ran an isolated headless probe and the same probe under the graphical Compatibility renderer. Both exited 0 and reproduced R1 and the 297/273 navigation counts. The graphical run used an NVIDIA GeForce RTX 3060 Laptop GPU, not a target mobile device.
- After cutting the tree, carried its branch to the woodland opening, then changed the destination during the return walk. Both requests arrived with the same branch still carried. This is useful additional evidence, but it does not close the full N2 checklist for all cargo types and both explicit loop routes.
- Inspected the current tree interaction capture and existing N1/N2/E2 source-run captures. The new capture is from the unchanged play camera at 960 × 600.
- Read the implementation and tests for stage gating, layer allocation, tree/branch state, save migration, navigation obstacles, scenery and water presentation. The previously reported tree/home layer collision and repeated-tap cancellation have fixes and regression coverage in this working tree; they are not repeated as current defects here.

Review artifacts are ignored local files under `builds/roadmap-review/`: `probe.gd`, `probe.log`, `graphical-probe.log`, `graphical-probe-errors.log`, and `tree_gnaw.png`. The probe uses only `user://roadmap_review_20261111/` for its save and clears that isolated fixture.

Not verified: a newly exported build, Android/real-device execution, touch ergonomics, frame-time budgets, all aspect ratios or a child session on this expansion. The reported earlier three-minute play session predates this slice and cannot validate its new mechanics. No production code was changed and no commit was made during this review.
