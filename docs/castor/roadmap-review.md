# Handling of the external roadmap review

Review received from the user and checked against the documents on November 8, 2026. This note records planning changes; it does not declare technical tests or tests with children as already carried out.

## Assessment

The main diagnosis holds: the former milestone 3 piled up rules, saving, art production and animation. The startup only validated a static asset and left the animation risk until too late. The MVP keeps dam, home and food.

| Suggestion | Handling |
|---|---|
| Test animations early | Included in milestone 1: licensed test model with idle/walk. It does not have to be a quadruped. |
| Split milestone 3 | Created 3a, gameplay with placeholder shapes, and 3b, visual integration and performance. |
| Define an achievable finish | Decision scheduled by the end of milestone 2; a beaver made of simple volumes to assess the silhouette. Low-poly was not adopted as a user decision. |
| Follow camera and edge indicator | Test if the area no longer fits on screen. There is no evidence that the map always requires following or an indicator. No manual rotation in the first path. |
| Simplify help and inspection | Automatic reaction to the rotten branch, repeatable voice line and object highlight. Per-obstacle demonstrations deferred. Deliberate attempt defined in 3a. These are reversible prototype choices, to be validated with the child. |
| Script and voice early | Audio plan and inventory created. A family member's voice is an option, not an assumed obligation. |
| Godot/C# risk on Android | Confirmed in the official documentation; incorporated into the comparison of combinations and the rule to re-evaluate export. |
| Reuse verbs across the three stages | Made explicit in milestone 4; vary choices and consequences, without requiring new systems. |
| Simplify saving | Return unplaced material to its origin, preserving completed changes. Do not save animations/paths. Test write recovery on the platform. |
| Measure performance earlier | Technical run-through by the adult in 3b, repeated in 5, accompanied by measurements when available. It is not an obligation for the child to play for 15 minutes. |

## Technical caveats

The [Godot stable documentation on C#](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/index.html), consulted on November 8, 2026, classifies Android support as experimental. The page consulted did not confirm the "Godot 4.7" identification made in the review. Record the version actually chosen and check its requirements again when starting. Web is not a requirement of this MVP and should not weigh as if it were.

The import test of an animated model does not validate the ability to produce or animate the final beaver. The decision on the origin, effort and finish of the art is still needed by the end of milestone 2. Test character skeletons do not guarantee compatibility with the beaver.

Saving to a temporary file and replacing is a strategy to verify on the platform, not an automatic guarantee against corruption. Keep a valid previous copy and test interruptions. Restoring a branch held in the beaver's mouth would require saving enough identity and state; we chose the simpler rule of returning it to its origin.

Blender, glTF, an engine, a model supplier or voice synthesis were not chosen just because they appeared in the review. The choice should follow the requirements and the import test. Simple transform-based animations are an option for supporting characters.

## Relation to the concept documents

### Optional adjustments incorporated

- **Otter in 3b:** a recognizable static celebration pose or simple code-driven movement satisfies the completion criterion. A dedicated rig and animations are no longer a possible dependency for moving on to home and food.
- **Choice of materials:** propose a distinct role before 3a and validate in that milestone that the child understands it through the game's clues without additional explanation from the adult. If it does not add an understandable choice, defer the material. Mud only as finishing is an example to test, not a decision made.
- **Otter's role:** celebrates the formation of the lake in the MVP; the owl gives help. Otter demonstrations remain a future possibility. Summary, visual review, inventory and character/chapter plans were aligned with this distinction.

### Consistency corrections after the first review

These corrections were agreed with the user. They update the specific passages, instead of relying only on a general precedence note.

| Point | Current handling |
|---|---|
| Dam materials | Milestone 2 with branches only. Before 3a, decide whether stones and mud are included and their role; the inventory distinguishes building candidates from decorative stones. These materials were not silently excluded. |
| Water leak | Removed from the first path and explicitly deferred to after the MVP. The visual change in the current remains. |
| Otter in the first reward | Celebration when the lake forms included in 3b, with task, inventory and completion criterion. |
| `3 / 8` counter | Mockup example, without fixing quantity or interface. Progress presentation to be tested in 3a; notes next to the mockups and references. |
| Animal requests | Deferred to after the MVP; summary updated where they were proposed. |
| Old references | Updated 02, 03, inventory, characters, environment and finalization to distinguish 3a from 3b. |
| Startup | "Final animations" distinguishes final production from the test model; summary includes the cube, three engine/language combinations and an effort limit. |
| Folders | `art/characters/` included in the table and in the startup asset task; `audio/source/` included in the production organization. |

The summary and the visual review preserve the history of the proposals. For the order of execution, milestones 3a/3b, the simplified help, the saving policy and the audio plan described in the updated roadmap take precedence over the earlier prototyping details. The scope and visual identity were not replaced.
