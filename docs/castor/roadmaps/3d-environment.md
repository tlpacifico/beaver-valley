# Production of the 3D environment, objects and buildings

[Overall roadmap](../roadmap.md) · [Inventory](../3d-production.md) · Track running across milestones 1–5, including visual composition milestone 4b

**Goal:** build a small explorable valley that makes progress visible. The scenery combines modeling or adapting assets, composition in the engine, lighting and interaction elements.

## Current sequencing

The functional chapter exists, but its presentation is not yet accepted as the intended valley. [Milestone 4b](04b-visual-valley.md) is the current production phase; its R1–R5 automated/desktop evidence is recorded in [startup-progress](../startup-progress.md), and author, child and device validation remain. The checklist below is a production track, not evidence of completion; reconcile it with observed deliverables during 4b. A4 remains finalization after the composition is accepted.

The author's 11 November request for more rocks, mud and movement space is scoped in [nature/exploration stages N1–N3](seasonal-gameplay-expansion.md): compose a natural bank and clearing, open a connected land loop, then extend the playable valley with one new clearing and an appropriate camera. Reuse this production track for assets and evidence. Scenery rocks/mud do not automatically become collectible resources; new physical obstacles must also be represented in navigation. N2's grove and woodland opening are likewise code-authored primitives in `visual_environment.gd`, with the authored obstacle list in `ValleyLayout` shared with navigation exclusion and collision. N2–N3 remain planned or partially delivered work, and these stages do not close earlier acceptance gates. N1's bank, clearing, mud and outer-rock scenery is implemented as code-authored primitive geometry in `game/scripts/visual_environment.gd` (11 November 2026); no new external asset was added, so provenance is unchanged, and the automated/desktop evidence and the remaining open items are in [startup progress](../startup-progress.md). E1's visible current adds a small Compatibility shader (`game/shaders/water_flow.gdshader`) over the existing prepared water meshes, with cached reach materials and authored dam foam; it is not a fluid simulation, and its evidence and open gates are recorded in the same progress section. E2's single gnawable tree (11 November 2026) likewise reuses the existing Meshy golden-tree export at 0.68 scale, so it adds no new environment asset and no provenance entry.

## A1 — Provisional valley, milestones 1–2

- [ ] Represent terrain, banks, river and dam area with simple volumes.
- [ ] Mark the accessible paths and limits, keeping materials and targets in view.
- [ ] Create a simple branch and three visual states of the water, without physical simulation.
- [ ] Set up collisions and walkable areas; confirm that tapping on the other side of an obstacle does not make the beaver pass through it.
- [ ] Test distances and framing with your daughter before adding detail.

**Output:** the first play path works and the layout of the valley can serve as a visual basis.

## A2 — First stretch with the intended look, milestones 3b and 4b

- [ ] Choose own, adapted or existing assets for terrain, trees and stones, recording the origin.
- [ ] Produce only one bank, a small set of vegetation/stones and the initial dam area.
- [ ] Define a common scale and a background palette that lets the beaver, branches and targets stand out.
- [ ] Set up materials, lighting, shadows and simple water in the engine.
- [ ] Import the first animated beaver and check the set in the real camera and on the priority device.
- [ ] Adjust the style and visual cost before replicating that set across the valley.
- [ ] Run the technical performance rehearsal described in [milestone 3b](03b-visual-dam.md), with about 15 minutes by the adult and a log of smoothness stutters and response to taps.

**Output:** a visually coherent, readable and functional stretch. A pretty image outside the engine does not meet this milestone.

## A3 — Dam and valley expansion, milestones 3b–4b

- [ ] Produce normal, thick, gnawed and rotten branches; differentiate the problems by shape as well.
- [ ] Consult the materials decision made before 3a. Produce collectible stones and mud only if included, with their own presentation distinct from the scenery; do not introduce the postponed water leak challenge.
- [ ] Create dam parts and states that match the progress, including the finishing choice.
- [ ] Prepare river, pool and lake; ensure that the visual changes do not leave materials or paths inaccessible.
- [ ] Expand the valley with the same assets, varying position, scale and rotation when appropriate.
- [ ] Produce the home and food store with states compatible with the interactions defined in milestone 4.
- [ ] Prepare the winter ending and the later visit to the valley.
- [ ] Adjust collisions, paths and interaction areas after replacing each provisional volume.

## A4 — Finalization, milestone 5

- [ ] Check that trees, rocks and buildings do not hide important actions.
- [ ] Review shadows, water transparency, effects and number of objects through measurement on the device.
- [ ] Test all scenery states after loading progress and when revisiting the ending.
- [ ] Update the inventory with sources, exports and licenses.

**Done when:** the valley communicates the three stages, keeps usable paths and runs comfortably on the chosen device. It does not need procedural generation, dynamic weather or physically simulated vegetation.
