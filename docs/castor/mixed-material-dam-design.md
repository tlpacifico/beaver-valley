# Mixed-material dam design

Date: 11 November 2026.
Status: the author agreed to the gameplay direction below. The [implementation plan](mixed-material-dam-plan.md) tasks 1–4 and the desktop part of task 5 are implemented with automated and exported-desktop evidence (see [startup progress](startup-progress.md)); the defaults below describe the implemented behaviour. Not validated: real device/touch, child observation and author visual acceptance. Known open finding: the near golden canopy partly hides the beaver while it gnaws (acceptance item 3). The material counters are text labels, not icons.

## Agreed direction

New adventures build the dam from **15 distinct objects: five ground branches, five logs obtained by gnawing five trees, and five small collectible stones**. Each tree supplies exactly one transportable log. The child may collect and deliver the three materials in any order. One tap starts walking and the relevant action; no repeated tapping, timing challenge or manual inventory is introduced.

Every placement changes the visible construction. Stones occupy prepared base/edge positions, logs form the structure, and branches fill gaps. These are visual roles, not sequential prerequisites: a log or branch must have a grounded, readable placement even when no stone has been delivered. Keep transport distances short and distribute sources in small recognizable groups rather than extending mandatory trips to increase session length.

Show separate icon counters with European Portuguese labels: `Pedras: 0/5`, `Troncos: 0/5`, `Ramos: 0/5`. Collection alone does not increment these counters; delivery does. The dam completes only when all three delivered counts reach five, then the existing home/food/story progression remains available.

Grass and mud are an **optional future finishing activity**, not a fourth required material or an extra five deliveries. A possible small activity places a grass-and-mud bundle over a visible trickle. It must never block the home, food or seasonal story. The first mixed-material release excludes this optional activity.

## Approaches considered

- **Free material order — selected:** supports exploration and lets the child choose between collecting and gnawing. Requires mixed-order construction visuals and clear compatible placement cues.
- **Guided material phases — not selected:** easier to explain one material at a time, but would prevent using an interesting object discovered out of sequence.

Fifteen is the initial playtest recipe, not a proven duration target. Observe interest, independent discovery, repetition and willingness to continue; changing a later new-adventure recipe must not silently change an existing save's requirements.

## Proposed implementation defaults

- Retain the current one-object carrying interaction, cancellation/retargeting behaviour and safe authored fall. A delivered object cannot be collected again. A tree cannot yield twice, including after interruption or reload.
- Distinguish branch shape (`normal`, `thick`, `rotten`) from construction material (`branch`, `log`, `stone`). Keep legacy puzzles available to legacy saves without requiring them for the five new ground branches.
- Use stable IDs for every source, object and destination slot. Five tree records each declare their tree ID, log ID, work point and landing point. Do not replicate one global `tree_cut` flag five times in world logic.
- Keep a single dam destination for the first implementation; automatically choose a free compatible visual slot. This isolates the new material loop from E3's separate two-zone targeting. Slot records reserve a zone field so the later choice does not change object identity. The old E3 three-placement experiment is superseded for new adventures; zone choice remains a separate follow-up.
- Preserve prepared water surfaces and their current maximum level. Derive water/flow presentation from normalized **presented** progress, clamped to the old safe bounds. All 15 deliveries give a local response; not every delivery needs a new water height. No physical current or fluid simulation.
- Recipe IDs distinguish `legacy_three` from `mixed_fifteen`. Existing schema 1–3 saves retain the legacy recipe, source relationships and chapter progress, including partial dams. New adventures use the mixed recipe. Offer the existing protected new-adventure action for trying it; never reset an old save automatically.
- A proposed schema 4 stores recipe ID, stable placements and cut-tree IDs, preserving other chapter fields. Migration is in memory until an ordinary save; transient carried items return to their source on reload. Validate source/placement consistency, per-type capacity and duplicate IDs. Keep the existing atomic-save and recovery behaviour.
- Reuse existing assets and procedural shapes initially. Editable imported art stays under `art/`; document any new third-party source and licence. Small collectible stones need a distinct cue from decorative bank stones.

## Acceptance and limits

1. A new adventure exposes five reachable ground branches, five gnawable trees and five reachable stones; each required tree has a reachable work point and a clear, dry landing at every relevant water level.
2. Any delivery order can finish, including all logs first and interleaved types. The first and fourteenth placements do not complete the dam; the fifteenth completes it exactly once. Same-type extras cannot substitute for a missing type.
3. Tree work faces the trunk, fixing the review's orientation defect before expanding to five instances. The normal play camera and feedback panel keep gnawing, falling and collection visible.
4. Double taps, retargeting, reload during walking/gnawing/falling/placement, and save failure never duplicate or permanently lose a required object. Home and food input layers still work.
5. Old partial and completed saves remain playable without more work being imposed. An old winter save remains in winter.
6. Five trees fit without reducing usable paths or hiding required targets. Adjust source placement or open a small real land area if necessary; do not solve crowding by shrinking all tap targets.
7. Record a new source/exported-build check, target-device traversal and child observation separately. Do not mark device or child acceptance from automated tests.

Swimming, new seasons, free building, reusable tree harvesting and the optional finishing activity are outside this implementation. The open-map request remains a separate deliverable; source placement alone does not fulfil it.

Implementation sequence: [mixed-material dam plan](mixed-material-dam-plan.md). Context: [expansion roadmap](roadmaps/seasonal-gameplay-expansion.md) and [execution review](seasonal-expansion-review.md).
