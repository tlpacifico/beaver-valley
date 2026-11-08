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

## Task 4 — startup wrap-up (8 November 2026)

- Started and closed the Godot editor twice in headless mode; this exercises startup, not a graphical editor session or a clean-cache rebuild. `./tools/castor.ps1 check` passed the cube, movement and static/animated asset checks.
- Re-exported Windows and Android debug builds. The Windows executable completed `--capture-movement` with exit code 0. Android export completed and signed the APK, while reporting that no project icon is configured; the latest APK was not reinstalled or tested on the phone. Earlier device validation remains valid for the build actually tested, not proof of this new build.
- Confirmed tracked project scenes, scripts, imported assets, Blender source/script, Fox source and license; `builds/` and Godot caches are ignored. Tool installations and export credentials remain local prerequisites documented in `how-to-run.md`. This was not a fresh checkout or a clean-machine reproduction.
- Decision: retain Godot 4.7.2, typed GDScript and Compatibility for milestone 2, based on the PC and real-device experiments. Detailed implementation sequence and checks added to `roadmaps/02-first-play.md`.
- Milestone 1 is complete based on the recorded real-device tests and startup reproduction. Open items: retest the renamed APK and debug marker on the POCO, investigate the darker Fox screenshot only if it recurs, choose the priority device after the child's play, and decide the origin and finish of final art. No child test or performance measurement was performed.

## Renamed Android build retest (8 November 2026)

- POCO X7 connected and authorized. Installed the current `builds/android/castor-debug.apk` with `adb install -r` and launched it successfully. The main scene was visible and a simulated ground tap moved the character and displayed a destination.
- Created the renamed `user://open-asset-test` marker; the asset scene opened with the branch and Fox visible. A simulated tap changed the displayed animation from Survey to Walk and moved the Fox. Removed the marker and relaunched the normal scene.
- This was an ADB-assisted check with screenshots, not a new hands-on touch or suspend/resume test; the earlier manual test is documented above. No child test or performance measurement was performed. Screenshots are in ignored `builds/android/`.

## Milestone 2 — provisional area (8 November 2026)

- Added simple water, bank and building-target markers to the existing movement scene. They are non-colliding visual placeholders: the water remains walkable and the target does not yet accept branches. The existing rock and navigation are unchanged.
- `./tools/castor.ps1 check` passed cube, movement and asset tests; Windows export and graphical movement capture succeeded. Android export succeeded with the existing missing-icon warning.
- Installed the new APK on the POCO X7; inspected the framed scene and confirmed movement after a simulated ADB tap. This does not replace a hands-on test or a play session with the child. Screenshots are in ignored `builds/android/`.
- Next: add three selectable branches and carrying behavior; placement, water-state changes, voice, and the full child test remain open.

## Milestone 2 — three-branch carrying increment (8 November 2026)

- Added `collectible_branch.tscn` using the existing Blender test branch and a simple area collider; the movement scene now contains three separate branch instances.
- A click/tap on a branch reserves it and sends the beaver to a reachable adjacent grid cell. The branch changes to carried and attaches visibly to the beaver only after arrival. Repeated selection does not create another branch; selecting a different branch swaps it and returns the previous one to its original position.
- The interaction status is in European Portuguese. Placement and the dam target remain non-interactive; no branch is consumed or duplicated.
- Extended `movement_test.gd` to cover ray selection, reservation during approach, carrying after arrival, swapping, and repeated selection. `./tools/castor.ps1 check` passed the cube, movement/branch and asset checks at 60 physics steps per second.
- No graphical capture, export, Android reinstall, hands-on touch test or child play session was done for this increment. Existing Android validation applies to an earlier build; retest this interaction on the POCO before considering the increment device-validated.
- Next: test whether the branch reads clearly while carried, then implement approach and placement in a separate increment.
- Follow-up fix: a valid ground destination now cancels a reserved pickup only after path validation; an invalid rock click preserves the approach and reservation. Selecting the already-carried branch during a different pending pickup cancels that pickup and stops the beaver while retaining the carried branch. The integration test covers these cases, and `./tools/castor.ps1 check` passed again.

## Milestone 2 — branch placement and water states (8 November 2026)

- Added a broad, selectable dam target. Tapping it with a carried branch routes the beaver to a reachable adjacent cell; the branch stays carried until arrival, then is placed in one of three visible positions.
- Repeated target taps while approaching are idempotent. The branch remains in the world's three-item inventory, and a placement without a carried branch or after all three placements is rejected. Existing branch swapping remains available before placement.
- Each completed placement advances the prepared water surface through three visible depth/color states. This remains a visual state change, not water simulation.
- Extended `movement_test.gd` to click the target through the camera ray, collect and place all three branches, repeat the target tap during approach, and verify arrival, branch ownership/count and each water state. `./tools/castor.ps1 check` passed the cube, movement/interaction and asset checks at 60 physics steps per second.
- No graphical play session, export, Android retest or hands-on touch test was done for this increment. The current placement build is not device-validated; earlier device tests do not cover it. Child observation, voice cues, adult restart and full-session checks remain open.
- Follow-up fix: placement now validates a reachable approach before canceling another reserved pickup. Integration scenarios cover carrying branch A, reserving branch B, tapping the target and ensuring only A is placed; when all placement approach cells are blocked, B's reservation and path remain intact. `./tools/castor.ps1 check` passed again.

## Review and device check — branch interaction (8 November 2026)

- Review found two cancellation defects: changing to a ground destination during collection could pick up a branch remotely, and requesting placement while approaching another branch could pick up and place the wrong branch. Both were corrected and covered by integration tests, including preservation of an existing route when a replacement is invalid.
- Ran `./tools/castor.ps1 check` successfully, exported Windows and Android, and inspected the Windows movement capture. Android export reported the existing missing-icon warning but completed.
- Installed the new APK on the POCO X7. Inspected the initial scene and used simulated ADB taps to collect and place one branch; the character carried it to the target and the water changed. This is not a full three-branch hands-on device test or a child play session. The branches appear small at the current camera distance; assess selection and readability during the planned playtest.

## Milestone 2 — provisional beaver volumes (8 November 2026)

- Replaced the upright capsule and rectangular tail in `prototype_actor.gd` with flat-colored primitive volumes: a low body, head, muzzle, paired incisors, ears, eyes, feet and a broad flattened paddle tail. The collision body, movement speed, facing logic and carried-branch anchor are unchanged.
- The primitives are authored directly in GDScript for this experiment; no third-party asset or final art source was introduced. This does not decide the final modeling origin or visual finish.
- `./tools/castor.ps1 check` passed cube smoke, movement/collection/placement and asset import checks at 60 physics ticks per second. Re-exported Windows and ran `Castor.exe -- --capture-movement`; the graphical capture succeeded and shows the beaver at the production camera distance. Screenshot: ignored `builds/windows/movement.png`.
- The pathing and interaction checks passed with the new visual. No Android export/install or real-device capture was done for this visual change, and no child play session assessed species recognition. The Android visual check and the art-origin/finish decision remain open.

## Milestone 2 — visual guidance and adult restart (8 November 2026)

- Added persistent ground rings around available branches and the dam target. A reserved branch receives a larger, brighter ring; unavailable branches lose their ring. Added a three-symbol placement progress indicator and a large Portuguese completion message with a brief scale pulse.
- Added adult-only restart access: hold the title area for 1.2 seconds to reveal a restart button, then confirm in a dialog. Desktop also supports Ctrl+R and the same confirmation. The title gesture does not issue a movement click.
- Extended `movement_test.gd` to verify branch cues and initial/completed progress, completion feedback, hidden normal restart control, adult reveal and confirmation. `./tools/castor.ps1 check` passed cube, movement/interaction and asset tests at 60 physics steps per second.
- No voice or third-party assets were added. Visual cues are provisional geometry/UI and do not validate readability with the child. No graphical capture, export, Android retest, hands-on touch test or child play session was performed for this increment.
- Remaining before the planned child test: decide and produce provisional voice, try the whole interaction on PC and Android, and observe whether the cues are understood without spoken explanation. The title hold and keyboard shortcut need usability confirmation with an adult; Android requires testing on the real device.
- Follow-up review: widened the branch selection area to 1.65 × 1.65 m so it covers the visible 0.78 m ring radius. The integration test now selects by raycast on the ring's outer edge, and the full movement/bounds checks still pass. Added a brief burst of five glowing spheres above the dam on completion, alongside the text; the test checks that the burst is hidden before completion and starts when all branches are placed. `./tools/castor.ps1 check` passed. Visual readability still needs an in-game/device observation.

## Visual feedback and beaver — review on POCO (8 November 2026)

- Re-ran `./tools/castor.ps1 check` successfully, exported and installed the Android debug build. The existing missing project icon warning remains.
- On the POCO, inspected the placeholder beaver and visual rings, and used an ADB-simulated tap to collect one branch. An ADB-simulated long press on the title revealed the adult restart button. The hold also changed the status message to an invalid-ground hint, but did not move the character; revisit input filtering if it causes confusion. The confirmation and full reset were not retested on the phone.
- No hands-on test, complete three-branch device run or child play session was performed for this version. Provisional voice and its source remain to be decided and implemented before the child test.

## Milestone 2 — provisional pt-PT voice (8 November 2026)

- Generated five Portuguese-European WAV cues (`dam_start`, `help_collect`, `help_place`, `first_placement`, `dam_completed`) with the Piper `pt_PT-tugão-medium` voice. Playback is local; neither the model nor TTS engine is part of the game.
- The model and Piper 1.3.0 were downloaded to an isolated `%LOCALAPPDATA%/Castor/piper-tts-1.3.0` folder. Piper's GPL-3.0-or-later license is recorded; only the WAV outputs are integrated. Model/dataset provenance and license notes are in `audio.md`.
- Added `tools/generate-provisional-voice.py` to reproduce the WAVs from a local model file. Direct model/config MD5 values match upstream `voices.json`; the model SHA-256 matches Hugging Face's published file hash.
- Added one `AudioStreamPlayer` for event lines. Repeating an event is ignored, a new event stops the previous one, and valid changes in movement, pickup or placement cancel outdated instructions. Completion replaces any earlier cue.
- Added integration assertions for event selection, duplicate help suppression, replacement of an outdated instruction and cancellation. `./tools/castor.ps1 check` passed after the audio integration (cube smoke, movement/interaction and asset checks at 60 physics ticks per second).
- No device speaker, Android build or hands-on listening check was performed for this audio change. Pronunciation, volume and timing with the visual cues remain open before the child session.

- Voice review: a finished help line originally remained blocked from repeating. Added a test of the player finished signal, observed it fail, and cleared the active event on completion; `./tools/castor.ps1 check` then passed. Pronunciation and volume still require listening on PC and the POCO.
- Exported the voice-enabled Android build and installed it on the connected POCO; the app launched in the foreground. Audio was not heard or assessed in this automated check. Android export still reported the missing project icon.
