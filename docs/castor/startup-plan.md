# Castor — project startup plan

> **For execution by agents:** follow the `superpowers:executing-plans` skill, task by task, respecting the project's current instructions. This plan prepares the first project and the 3D production; it is not an implementation plan for the whole chapter.

**Goal:** get a 3D scene exportable to PC and Android and prepare a repeatable way to produce and import assets.

**Architecture:** a game project in `game/`, art sources in `art/` and documentation in `docs/castor/`. Start with a small scene and placeholder volumes; choose the engine-specific details in task 1 before creating implementation files.

**Chosen technology:** standard Godot 4.7.2, typed GDScript and Compatibility. Windows and Android device tests and the Blender/glTF import pipeline are recorded in [progress](startup-progress.md). The team will continue with this choice.

**Execution complete:** see [progress](startup-progress.md) and [commands/results](how-to-run.md). The next increment is scoped in [milestone 2](roadmaps/02-first-play.md).

**Execution update:** the cube scene was preserved; the movement and asset test scenes were subsequently validated on Windows and the POCO X7. The APK generated after the English rename was subsequently reinstalled and checked on the POCO.

**Reference:** [roadmap](roadmap.md), [first steps](roadmaps/01-first-steps.md) and [3D production](3d-production.md).

## Constraints

- Family MVP for the 6-year-old daughter; no store publishing at this stage.
- Test PC and Android early; select the priority device after the first play session (milestone 2).
- No reading or manual camera control will be required in the first play session.
- Water with prepared states; no complex physics simulation.
- Do not produce all the final models before validating the interaction.

## Files and responsibility

| File/folder to create during execution | Responsibility |
|---|---|
| `docs/castor/technical-decisions.md` | Hardware, verified alternatives, versions and choices. |
| `docs/castor/how-to-run.md` | Open the project, run, export and install; concrete commands for the chosen engine. |
| `.gitignore` | Exclude caches, local files and generated builds according to the engine. |
| `game/` | Project and first scene, with specific paths defined in task 1. |
| `art/props/` | Source of the first test branch, if it is created in an external tool. |
| `art/characters/` | Source and license of the animated test model, separate from the final characters. |
| `docs/castor/3d-production.md` | Inventory and proven import conventions. |

The files above do not necessarily exist yet. Do not invent extensions, APIs or commands before choosing the engine.

## Priority checks

1. A scene that works in the editor also opens outside it — task 2.
2. Scale, orientation, materials, skeleton and animations survive the import — task 3.
3. The beaver respects the ground and boundaries and does not change speed with the frame rate — task 2.
4. The scene is not cut off or unreadable on the Android screen and comes back after suspend — task 2.
5. Another editor startup can rebuild the same experience without assets in personal folders — task 4.

## Task 1 — Record hardware and select a candidate

**Files:** create `docs/castor/technical-decisions.md`; fill in the engine-specific paths in this plan before task 2.

- [ ] Inspect the PC and installed tools; get the phone's Android model and version without assuming them.
- [ ] Record the PC GPU, access to the Android device and the state of the connection for testing. Collect weekly availability and art production possibilities when available; this data informs estimates, it does not block the first technical experiment.
- [ ] Consult current official Godot and Unity documentation for the relevant combinations of language, Android/desktop export, requirements and licenses. Record links and the date consulted.
- [ ] Explicitly compare Godot/GDScript, Godot/C# and Unity/C#. Weigh the experimental Android support of Godot/C# stated in the [official documentation consulted](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/index.html), without assuming a specific version from the `stable` address. Confirm the requirements of the version actually installed.
- [ ] Before setup, define and record an effort limit for investigating export problems. When it is reached, record the error and reassess the engine/language combination instead of insisting indefinitely; distinguish device connection problems from engine limitations.
- [ ] Choose a candidate and language based on ease of export, iteration, model import and learning effort; explain the decision.
- [ ] Define versions and paths for the scene, movement and assets in the chosen project. Do not implement a generic layer to support several engines.

**Verifiable deliverable:** technical note with hardware, candidate engine, language, versions, requirements and a map of the first files. The choice is only consolidated when the task 2 export works.

## Task 2 — Create and export the first scene

**Files:** create `game/`, `.gitignore` and `docs/castor/how-to-run.md`, using the map defined in task 1.

- [ ] Prepare tools and version control, preserving the existing documents. Check the repository state before initializing Git or creating commits.
- [ ] Before adding movement, export a minimal scene with a cube rotating as a function of time and confirm that it opens outside the editor. This isolates installation/export from gameplay errors.
- [ ] Create a scene with ground, boundaries, light, tilted camera and placeholder beaver.
- [ ] Implement placeholder movement; document the controls. Check ground, boundaries and speed based on elapsed time.
- [ ] Generate a desktop build and open it without the editor.
- [ ] Generate an Android build and install it on a device connected and authorized for testing. Without access to the device, record the check as pending; do not declare Android validated.
- [ ] Check framing, basic input and suspend/resume on Android.
- [ ] Document the steps and commands actually used, with versions and the result on each device.

**Verifiable deliverable:** scene runnable outside the editor on the tested devices. Manual testing is enough for this placeholder scene; do not create a test suite that merely replicates the configuration.

## Task 3 — Prove the pipeline for static and animated assets

**Files:** add the branch source to `art/props/`, the animated model's source/license to `art/characters/`, import the assets into `game/` and update `docs/castor/3d-production.md`.

- [ ] Choose a tool and produce or adapt a simple branch with documented origin; without modeling the final beaver yet.
- [ ] Export and import that branch into the engine.
- [ ] Check scale, orientation, origin point, colors and materials next to the placeholder beaver.
- [ ] Change the source, repeat the export/import and check that the game receives the change.
- [ ] Confirm the asset in the installed build and record tool, format and conventions in the inventory.
- [ ] Get a simple test model with a skeleton and idle/walk animations, checking license and origin. It can be an animal, but do not spend time looking for the ideal beaver or require a quadruped to validate the import.
- [ ] Import the model and switch idle/walk in the engine; test hooking it up to placeholder movement and running it in the installed build. Record deformations, orientation and results on each accessible device.
- [ ] Keep the test asset's source/license in `art/characters/` and distinguish it from the final assets in the inventory.

**Verifiable deliverable:** a static asset that can be changed and reimported and an animated model that switches idle/walk in the installed build. This validates the technical pipeline for animations; it does not yet demonstrate the ability to produce the final beaver or to reproduce the finish of the v3 reference.

## Task 4 — Close the startup and prepare the first play session

**Files:** update `how-to-run.md`, `technical-decisions.md`, the status of milestone 1 and `roadmaps/02-first-play.md`.

- [x] Close and reopen the editor, run and generate the scene again from the project files.
- [x] Confirm that the required sources and assets are in the project and that caches/generated builds are not confused with sources.
- [x] Record what was validated, what remained pending and whether the candidate engine will be kept.
- [x] Adapt the tap/click, path, collection and placement tasks of milestone 2 to the chosen engine, with concrete files and checks.

**Verifiable deliverable:** reproducible instructions and a scoped next increment. Mark milestone 1 complete only when its criteria are met; device pending items remain visible.

## Scope of this deliverable

This plan records the completed startup work, not implementation of the complete chapter. See the progress notes for actual verification and remaining limitations.
