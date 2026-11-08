# Progress — Castor startup plan

Plan: [startup-plan.md](startup-plan.md).

- Choice authorized by the user: standard Godot with GDScript.
- Version confirmed on the official page and the releases API: 4.7.2-stable, no pre-release.
- Editor downloaded from the official release; SHA-512 compared with the manifest of the same release.
- The repository did not exist: Git initialized on the `codex/castor-bootstrap` branch, preserving the documentation. No commits or remote created.
- Execution decision: the increment for this session is the cube and the PC/Android export. Movement, external models and the remaining milestone 1 tasks still come after export validation, as the plan determines.
- Verification: use execution and an integration test of the placeholder scene, in line with the plan's manual testing exception; do not create a unit test suite for generated configuration.
- Android: ADB started; no device detected on the first query. Connection and authorization requested from the user.
- Effort limit adopted: two hours of active investigation of export failures, not counting downloads or waiting for the device.
- Official templates verified by SHA-512; only Windows x86_64 and Android APK extracted.
- Scene imported and windowless test passed; Windows executable passed with exit code 0 and rendering on the RTX 3060, screenshot inspected.
- First Android export rejected because ETC2/ASTC was disabled; option enabled in the project and export repeated successfully.
- ARM64 APK verified with apksigner and aapt: package `org.thacio.castor.bootstrap`, minimum 24, target/compile 36.
- sdkmanager initially used Java 11 through JAVA_HOME; fixed only within the process to Java 17. Build-tools 35.0.1 installed; the exporter used 36.0.0. NDK/CMake not changed.
- Pending: ADB device, real Android test, movement/collisions and static/animated import. Milestone 1 remains in progress. No review or test with children was carried out.

## Next increment — movement on the PC

- The user reported that the phone is unavailable and authorized moving forward on the PC. Android validation no longer blocks this increment, but remains pending; do not repeat connection requests while it is unavailable.
- New scene `movement.tscn`, separate from the cube, is now the main scene. Character made of simple volumes, fixed diorama camera, ground, boundaries and central rock.
- Decision: in the flat placeholder valley use AStarGrid2D on the XZ plane and CharacterBody3D for collisions. Destinations snapped to the centers of 1-meter cells, without diagonals; continuous movement between points. This is not the final navigation decision for the art valley.
- Clicks are projected through the camera and processed in the physics step; reject the rock and outside the ground, preserve the path on invalid clicks and allow changing destination while walking.
- Test written before the scene and observed failing because the scene did not exist. Afterwards it passed for going around the obstacle, boundaries, ground and changing destination.
- An additional mouse event test revealed a headless virtual size of 64x64. The test window size was fixed to 960x600, without changing the production mapping to compensate for the test.
- Integration verified at 30, 60 and 120 physics steps per second, including a 2-meter path, projected click and rock rejection. Cube test preserved.
- External model import and the phone test remain pending. This increment does not implement collection or building.

## Next increment — 3D asset pipeline on the PC (task 3)

- Phone still unavailable; work authorized on the PC. Android not validated.
- Blender was not installed. Got portable Blender 5.2.3 LTS from the official server; SHA-256 checked against the published `.sha256` file. No installer and no global changes.
- Test branch created in Blender by a reproducible script (`art/props/test_branch.py`), saved in `art/props/test_branch.blend` and exported to `game/assets/props/test_branch.glb`.
- The first import revealed unapplied rotation (the node reached Godot with −90° on Z). Fixed by applying rotation/scale before exporting; the test now requires an identity transform. Object name changed to `Branch` so it does not collide with the file name.
- Bark color darkened after the first visual inspection: Blender values are linear and the initial brown looked beige in the engine.
- Visible change in the source (two leaves) made on the `.blend`, re-exported and reimported: different `.glb` hash and 2 → 3 materials in Godot; before/after inspected in the screenshot.
- Animated model: «Fox» from the official Khronos glTF Sample Assets repository (CC0 + CC BY 4.0, attribution recorded and included in the executable). Chosen for its clear license and skeleton/animations already in glTF; it is a technical asset, not an art reference for Castor.
- Fox imported with 24 bones and texture; scale 0.005 in the engine. `Survey` used as idle and `Walk` as walk, with looping enabled in the engine. Movement in this scene is in a straight line by click, not the AStar path of the main scene.
- New test `game/tests/asset_import_test.gd` (included in `check`): scale, orientation, origin, materials of the branch; skeleton, texture, height, idle/walk/idle and bone pose changes. It has a 20 s limit so it does not hang if there is a runtime error.
- The exported executable refuses a scene path on the command line; added the user option `--asset-test` in the main scene to open the asset scene without changing the normal behavior.
- Windows validation: `check` passed; executable with `--asset-test --capture-assets` ended with exit code 0 and screenshots inspected (branch with leaves, Fox idle and walking in the direction of movement); `--capture-movement` still passes. APK re-exported, not installed.
- Pending: running on the POCO X7 (main scene, touch, suspend/resume and this asset scene). Milestone 1 remains in progress. The beaver's own rig and animation are left for 3b.

## Android validation on the POCO X7

- Phone connected over USB and authorized: POCO X7, Android 16 / API 36, Mali-G615 MC2.
- Debug APK installed via ADB. Startup with OpenGL ES 3.2 and Compatibility; full scene in landscape, with side bars.
- Via ADB: a simulated tap on the ground starts the path; a tap on the rock is rejected and keeps the destination.
- During the automated test the notification panel opened (the phone was being used); screenshots with personal notifications deleted and the remaining tests done by hand by the user.
- The user confirmed by hand: going around the rock, changing destination, invalid taps, suspend/resume and about a minute of use without problems.
- `--asset-test` does not reach the game on Android: the exported activity of Godot 4.7.2 strips `command_line_params` for security (verified in `GodotActivity.kt` at the 4.7.2-stable tag). Added the marker `user://open-asset-test`, only in debug builds, created/removed with `adb shell run-as`. `check` still passes.
- Asset scene on the phone: branch, Fox, idle/walk and colors confirmed by the user. One ADB screenshot showed the Fox darker, from behind; the user saw the correct colors on the device. Not investigated.
- Marker removed; the app went back to opening the main scene.
- Not measured: frame times, temperature, power consumption. No test with the child.
- Milestone 1 criteria in `roadmaps/01-first-steps.md` met. Task 4 of the startup plan is still missing (reopen the editor and rebuild from the files, confirm sources in the project, prepare the milestone 2 tasks) before declaring the milestone complete.

## English conversion (code, names and documentation)

- Author's rule, recorded in `AGENTS.md` (with `CLAUDE.md` importing it): English for code, identifiers, comments, file names, logs and documentation; European Portuguese for everything the child sees or hears (on-screen text, app name, voice lines, text inside mockups).
- Files renamed with `git mv` (docs, roadmaps, mockups, art and game assets). Blender object/materials renamed (`Branch`, `Bark`, `CutTip`, `Leaf`) by regenerating `art/props/test_branch.blend` from its script; Godot import files for the renamed assets regenerated. The Android debug marker is now `user://open-asset-test`.
- Mockup generators now write the English file names; regenerated SVGs are byte-identical to the previous ones.
- `check` passed after the rename (cube, movement, assets with the new material names). Android APK re-exported; not reinstalled, because the phone was no longer connected, so the renamed marker has not been tried on the device.
- `branch-export` failed once in the Godot `--import` step without a saved log, then passed twice in a row; not reproduced.
