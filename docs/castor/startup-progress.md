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

- Follow-up: ignored mouse-button events Godot marks as touch-emulated, while preserving physical mouse clicks and direct screen-touch handling. The movement integration test now exercises the title-touch/emulated-mouse sequence, verifies adult restart appears without a ground status message or pending click, and checks physical mouse input remains active. `./tools/castor.ps1 check` passed. The behavior still needs a hands-on retest on the POCO.
- Follow-up on POCO dialog: set the confirmation buttons explicitly to `Recomeçar` and `Cancelar`, and increased the dialog minimum width so the Portuguese title fits. Integration assertions cover the title, both labels and minimum width; `./tools/castor.ps1 check` passed. Retest the rendered dialog on the device.

## Milestone 2 — provisional pt-PT voice (8 November 2026)

- Generated five Portuguese-European WAV cues (`dam_start`, `help_collect`, `help_place`, `first_placement`, `dam_completed`) with the Piper `pt_PT-tugão-medium` voice. Playback is local; neither the model nor TTS engine is part of the game.
- The model and Piper 1.3.0 were downloaded to an isolated `%LOCALAPPDATA%/Castor/piper-tts-1.3.0` folder. Piper's GPL-3.0-or-later license is recorded; only the WAV outputs are integrated. Model/dataset provenance and license notes are in `audio.md`.
- Added `tools/generate-provisional-voice.py` to reproduce the WAVs from a local model file. Direct model/config MD5 values match upstream `voices.json`; the model SHA-256 matches Hugging Face's published file hash.
- Added one `AudioStreamPlayer` for event lines. Repeating an event is ignored, a new event stops the previous one, and valid changes in movement, pickup or placement cancel outdated instructions. Completion replaces any earlier cue.
- Added integration assertions for event selection, duplicate help suppression, replacement of an outdated instruction and cancellation. `./tools/castor.ps1 check` passed after the audio integration (cube smoke, movement/interaction and asset checks at 60 physics ticks per second).
- No device speaker, Android build or hands-on listening check was performed for this audio change. Pronunciation, volume and timing with the visual cues remain open before the child session.

- Voice review: a finished help line originally remained blocked from repeating. Added a test of the player finished signal, observed it fail, and cleared the active event on completion; `./tools/castor.ps1 check` then passed. Pronunciation and volume still require listening on PC and the POCO.
- Exported the voice-enabled Android build and installed it on the connected POCO; the app launched in the foreground. Audio was not heard or assessed in this automated check. Android export still reported the missing project icon.

## First-play sequence and restart check (8 November 2026)

- Installed the touch-fix Android build on the POCO X7 and used ADB-simulated taps to collect and place all three branches. The completion message and three filled progress markers appeared. A long press revealed the adult control without changing the completion status.
- The first confirmation dialog showed English default buttons and a truncated title. Explicit Portuguese labels and a wider dialog were added and `./tools/castor.ps1 check` passed. Re-exported and installed the revised build; on the POCO the title and both buttons were visible in Portuguese, and confirming restart returned to the initial scene. The three-branch sequence was run before this last dialog-only change.
- These are simulated inputs and screenshot checks, not a hands-on assessment. Listening to the generated voice on PC and phone, the child session, camera-follow experiment and priority-device decision remain open. Android export continues to report the missing project icon.

## Manual first-play check on POCO

- The user confirmed manually collecting the branches on the POCO and reported no problems. This records the user's hands-on result; the earlier ADB check separately covered placement of all three branches and restart.
- The user did not report a separate assessment of voice pronunciation, volume or synchronization, or a child play session; those checks and the priority-device decision remain open.

## Camera follow comparison experiment (8 November 2026)

- Added an opt-in smooth follow camera with the existing fixed angle and orthographic projection. The normal `run` command retains the original fixed, whole-area camera; use `./tools/castor.ps1 follow` to compare the experiment and close/relaunch to switch back.
- Added integration checks that move the follow camera without changing its orientation, select a nearby branch through the new camera ray, and keep the beaver and dam target within the viewport when the beaver is near the dam. `./tools/castor.ps1 check` passed (cube, movement/interactions and asset imports).
- No graphical/handheld comparison or child observation was done. The automated checks establish ray selection and local framing only; distant branches may leave the viewport while following. Camera choice and milestone status remain open.

## Milestone 3b — first bank scenery experiment (8 November 2026)

- Added a short low bank edge, four scenery rocks and five small grass tufts as original, procedural Godot primitive geometry in `game/scripts/movement_world.gd`. No third-party assets or licenses are involved.
- Scenery is non-colliding and placed at the outer margins; branch, placement and water-state logic were not changed. This is an early visual experiment authorized ahead of 3a; the 3a playtest and other outstanding checks remain open.
- `./tools/castor.ps1 check`: pending. Windows capture and/or device readability check: pending. No milestone validation is claimed.

## Milestone 3a — playable dam implementation (9 November 2026)

- The author chose branches only and postponed collectible stones and mud. Added a thick branch that can be gnawed or swapped, a rotten branch that bends and must be swapped, and three normal branches so gnawing remains optional. Three placements complete the dam.
- Added contextual help on request and after two incompatible placement attempts, visual distinction and provisional pt-PT voice cues, a choice between two changeable finishes, and an invitation to build the home. Home gameplay itself is outside 3a.
- Added validated persistent progress for placements, gnawed/bent states, finish and completion. Reopening restores unplaced branches to their origins and a safe character position. Save writes via a temporary file and keeps a previous valid backup; errors are shown. Confirmed adult restart clears the save only after confirmation.
- `./tools/castor.ps1 check` passed including isolated save/recovery tests and movement/interaction tests; its deliberate save-failure case emits an expected warning. The Windows executable exported and graphical capture opened. The Android APK exported, but the POCO was not connected, so this 3a build has not been installed or tested on the real device.
- The stage still needs a complete adult playthrough, listening to the voice, and observation with the child. Do not mark the milestone validated or the child-understanding criteria complete. The camera comparison and priority-device decision remain open.
- Added four original procedural effects for collection, gnawing, placement and completion, using a separate player so speech is not interrupted. Regeneration is deterministic via `tools/generate-provisional-sfx.py`. Final `check` and Windows/Android exports passed; the Android exporter still reports the missing project icon. The phone was not connected and audio has not been listened to.

## Milestone 3b — first visual set (9 November 2026)

- Integrated project-authored Blender beaver with an eight-bone rig and looping Idle/Walk, with short interruptible code-driven gnaw and placement actions. The carried branch follows the actor orientation. Editable source, export and provenance are in `art/characters/beaver/` and `3d-production.md`.
- Added a small non-colliding bank, vegetation and progressive dam with water highlights, and original owl and otter primitives. Owl appears with help; otter celebrates completion. Visual state is rebuilt from the 3a save.
- `./tools/castor.ps1 check` passed actor loops/action interruption, support timing/no collisions, environment states and existing gameplay/save tests; deliberate failed-save test emits its expected warning. Windows export and graphical movement capture succeeded. Android APK exported with the existing missing-icon warning; ADB found no device, so this build has not been installed or assessed on Android.
- The work is not a validated milestone: 3a human/device checks, voice listening, priority-device selection, the 15-minute technical rehearsal with measurements, and child recognition remain open.
- Replaced the grey obstacle visually with project-authored faceted rocks; the original collision and path grid remain. Added progressive dam beams and finish colors, and verified scene integration, character support, animation interruptions, saves and navigation with the full check. Final Windows and Android debug exports passed after this change; Android still reported the missing project icon and no real device was connected.

## Milestone 3b — POCO X7 automated device check (9 November 2026)

- Installed the current Android debug APK and opened it on the connected POCO X7. The beaver, bank, water, rocks, branches and placement cue were visible in landscape.
- With ADB-simulated taps, collected and placed one normal branch, force-stopped and reopened the application, and observed that the placed branch, water and progress were restored. Placed the other two normal branches and observed completion and the full visual dam.
- Selected the green finish and reopened the app; the completed state and green dam detail remained. Tapping help displayed the owl. Screenshots are in ignored `builds/android/`. The completion text covers part of the scene; assess readability during hands-on play.
- This was a short automated device check, not a 15-minute adult rehearsal, a real-finger assessment, a listening check or a child play session. Otter celebration, thick/rotten interactions and performance/temperature were not assessed by this device check. The milestone remains unvalidated.

## Milestone 3b sequencing decision (9 November 2026)

- At the author's request, mark 3b closed for sequencing and move towards milestone 4. This decision does not claim that outstanding validation was performed or that the completion criterion was met.
- Carry forward the 15-minute adult device rehearsal and measurements, real-finger obstacle checks, voice listening, priority-device decision and child observation; 3a validation also remains open. The short POCO check is recorded above.

## Milestone 4 — initial play proposal (9 November 2026)

- Described provisional home and food interactions in `chapter-play-proposal.md`, including visible choices, reusable controls and continuity. These choices have not been tested with the child.
- Ran `./tools/castor.ps1 check` against the existing implementation; it passed, including the expected warning from the deliberate save-failure scenario. No chapter gameplay has been implemented or validated in this increment. The home prototype, food prototype, chapter saving, transitions and ending remain open.

## Milestone 4 — home prototype (9 November 2026)

- Added `game/scripts/home_stage.gd` and `game/scripts/home_part.gd`. The home becomes available when the dam is completed, or when a completed dam save is restored. It reuses the existing tap, carry and place verbs; no new interaction system was added.
- Three loose parts (rounded log bundle, light plank, mossy log bundle) and two visible positions (front wall and roof). Any part fits either position, so the decision is which part goes where. The remaining part loses its cue after completion. The placed part changes the wall or roof shape/colour; completing the second position adds a warm window, sparkles and the Portuguese message `A casa está pronta!`.
- Help with a carried part points to the house; help without a part highlights a loose part. An occupied position is refused with `Esta parte da casa já está cheia.`; a part can be swapped before placement. The home part and a branch cannot be carried at the same time.
- During the home stage the leftover branch cues and hit areas are disabled so they do not compete with the house. The dam, water, finish choice and save schema were not changed. Home progress is intentionally transient in this increment and resets when the application is reopened; the dam restore remains valid.
- Added `game/tests/home_stage_test.gd` to `./tools/castor.ps1 check`: activation from a completed dam, fixed-camera framing, real camera ray selection, carry, help, placement, occupied refusal, swap, completion, leftover part disabling and reload with a transient home. `./tools/castor.ps1 check` passed the cube, movement/dam, save, home, support, environment, beaver and asset checks; the deliberate save-failure case still emits its expected warning.
- Added an opt-in graphical verification, `Castor.exe -- --capture-home`, which saves `home.png` and `home_complete.png` to Godot's user data folder. The Windows build was exported and the exported executable completed this capture with exit code 0; the captures were inspected: the three parts read as different materials, the rings match the parts, and the completed lodge shows a different roof and a warm window. Copies are in ignored `builds/windows/`.
- Windows and Android debug exports completed; Android still reports the missing project icon. ADB found no connected device, so this build was not installed or tested on the POCO. No child play session, voice listening or device readability check was performed.
- Next: observe the home stage with the child before producing final elements, then prototype the food store. Home persistence, transitions, the ending and protected new adventure remain open.

## Beaver facing fix (9 November 2026)

- The first PC play showed the beaver walking backwards. The imported model's nose is at +Z in Godot after the Y-up export, while `prototype_actor.gd` rotates the body as if forward were -Z, leaving the nose opposite to movement.
- Rotated the visual node 180° around Y so the nose follows the actor's forward and the carried item stays in front. Action tweens remain on the model node and keep their axes. The asset notes in `art/characters/beaver/README.md` and `3d-production.md` now record the mapping.
- Extended `beaver_actor_test.gd` to require the nose ahead and the tail behind when moving toward +X and +Z. `./tools/castor.ps1 check` passed, including the home and existing dam scenarios.
- Re-exported Windows and checked `--capture-movement`: the nose leads toward the destination. The author then confirmed on the PC that the beaver now faces the movement direction. Android was re-exported but not installed or tested on the device; no child or device check was performed for this fix.

## Milestone 4 — lodge moved into the lake (9 November 2026)

- The author reported that the beaver's home was on the south grass, outside the lake. Moved the lodge to `(-2.0, -4.55)` inside the filled lake, to the west of the dam, and added a visible mound of branches and moss around the waterline. The wall position now faces the camera and the roof position stays above it.
- Kept the three parts on the bank at `z = -2.0`, so the child collects them on land and carries them into the water. The same tap/carry/place verbs, swap, occupied refusal, help and transient state are unchanged.
- Moved the dam completion, home invitation and home completion messages to the lower band of the screen so they no longer cover the lodge in the lake. The finish choice stays at the left.
- `home_stage_test.gd` now checks that the lodge center is inside the completed lake, that the mound exists and is visible, that the parts stay on the bank and that the wall/roof positions have the expected order.
- `./tools/castor.ps1 check` passed. Windows and Android debug exports completed (Android still reports the missing project icon and was not installed). `--capture-home` was inspected: the lodge sits on the mound surrounded by water, the completion messages are clear of it, and the updated images are in `builds/windows/home.png` and `home_complete.png`.
- No child or device test was performed for this correction. The home remains unsaved between sessions.

## Milestone 4 — food store prototype (9 November 2026)

- Added `game/scripts/food_stage.gd` and `game/scripts/food_bundle.gd`. When the lodge is completed, the food stage starts with five bundles on the bank: three thick leafy bundles and two visibly thin, pale ones. Three suitable bundles fill the store.
- Reused the tap, carry and place verbs. The child carries a bundle to a highlighted spot in the water next to the lodge; each placed bundle stays visible and the pile grows. A thin bundle is refused with `Este feixe é pequeno. Escolhe outro.` and can be swapped without a penalty. Help highlights the suitable bundles or the water target.
- The dam progress is replaced by `Comida guardada: ○○○` during the stage. Completing the third bundle shows `A comida está guardada!` and a short burst. The home completion message remains until the food is complete. Free leftover branches are hidden once the home stage starts, so they do not compete with the house or the food bundles.
- Generated five new provisional pt-PT voice lines (`food_invite`, `help_food_collect`, `help_food_place`, `food_unsuitable`, `food_complete`) with Piper, added them to `tools/generate-provisional-voice.py` and `provisional_voice.gd`, and recorded them in `audio.md`. Listening checks remain open.
- Added `game/tests/food_stage_test.gd` to `./tools/castor.ps1 check`: home-to-food transition, bundle counts and camera framing, thin refusal, suitable help, swap, real target ray, three placements, visible pile, progress, completion, unchanged dam/home and transient reload. The adult-restart test now checks the hold at 1.3 s instead of the exact 1.2 s threshold to remove a timing flake.
- `./tools/castor.ps1 check` passed the cube, movement/dam, save, home, food, support, environment, beaver and asset checks. Windows was exported and `--capture-food` completed with exit code 0; `food.png` and `food_complete.png` in `builds/windows/` show the bundles on the bank, the target by the lodge and the accumulating pile. Android was re-exported but not installed or tested on the device.
- Known limitations: food progress is transient and resets when the application is reopened; the beaver still walks on the water; no child or device test was performed. The home-complete capture now also shows the hand-over to food because the transition is immediate.

## Milestone 4 — chapter persistence (9 November 2026)

This supersedes the earlier notes that the home and food progress were transient.

- Extended the local save to schema 2 in the same `dam_save.json`, adding `home_slots` (the two placed home parts) and `food_placements` (the stored bundle IDs). The stage is derived from the saved progress: dam, home, food or food complete.
- Schema 1 saves are still read and migrated in memory to schema 2 with an empty home and food state; the next durable placement writes schema 2. The existing dam save is preserved. `save_state` only writes schema 2 and keeps the previous temporary-file and backup recovery.
- Validation enforces progression: home parts only after the dam, food only after both home positions, known IDs, no duplicates and only suitable food bundles. Carried or reserved items are never saved.
- Restore rebuilds the dam, restores the home parts into their slots, activates the food stage and rebuilds the pile at the saved count. The current progress line, invitation and completion message are restored without replaying completion sparkles or the food completion voice. The beaver returns to the initial safe position and no item stays in its paws.
- Saving now runs after every durable home and food placement as well as the existing dam actions. A failed write shows the existing Portuguese warning.
- `dam_save_test.gd` now covers schema 2 validation, progression rules, duplicate/unknown IDs, rejection of thin food bundles, a v1→v2 migration and rejection of schema 1 writes. The home test checks saved slots and reload restoration; the food test checks a saved first placement, an interrupted-session reload with one bundle, continued progress, the completed save and a final restore. The full `check` passed.
- `--capture-home` and `--capture-food` now use an isolated `user://capture_save/`; the real save hash was unchanged before and after the captures. Both captures completed with exit code 0 and the images were refreshed in `builds/windows/`.
- Remaining: the ending is not saved because it does not exist yet; the ending, protected new adventure, child/device tests and final art remain open. Android was re-exported with schema 2 but not installed or tested on the device.

## Milestone 4 — ending and protected new adventure (9 November 2026)

- Added `game/scripts/winter_scene.gd`: 48 falling snowflakes, snow patches on the grass, a snow cap on the lodge roof and three beaver clones by the lodge (one adult and two young). They are decorative only, with no collision or interaction. The wording avoids hibernation; the family is awake.
- After the third food bundle, the food completion message appears, then after about 1.2 s the winter ending: snow and family in the valley and an overlay with `O inverno chegou!`, `A família do castor está reunida. A casa está quente e a comida está guardada.`, `Continuar a visitar` and `Nova aventura`.
- `Continuar a visitar` closes the overlay and keeps the winter valley and family. A discreet `Nova aventura` button stays on screen; it opens the existing confirmation dialog with `Começar uma nova aventura?`, `Começar de novo` and `Cancelar`. Confirming clears the save and starts again; cancelling keeps the chapter. The adult restart gesture remains available mid-game.
- No schema change: a chapter with three food placements is the winter ending. Reopening restores snow, family, food progress and the small new-adventure button without replaying the overlay or the winter voice. A fresh completion plays the new provisional line `winter_arrived`.
- Added `ending_test.gd` to `check`: completed-chapter restore, winter visuals, no overlay replay, ending text without hibernation, protected new adventure, save kept on cancel and continue. Extended the food test for the fresh ending and the winter reload. Updated the restart-dialog assertions to the new wording. `./tools/castor.ps1 check` passed all nine test groups.
- Windows was exported and `--capture-ending` completed with exit code 0; `ending.png` and `ending_valley.png` in `builds/windows/` show the overlay and the winter valley with the family. The capture uses the isolated `user://capture_save/` and does not touch the normal save.
- Remaining: Android re-exported with the ending but not installed or tested on the device; final art and animation polish, child/device playtest, and the MVP presentation remain. No new maps or playable animals were added.

## Implementation review (9 November 2026)

- Reviewed the current working tree, including uncommitted chapter implementation, persistence, interaction routing, voice cues and automated checks. No gameplay code was changed and no commit was created.
- `./tools/castor.ps1 check` completed with exit code 0: bootstrap, movement, save, home, food, ending, support characters, environment, beaver and asset checks passed. The movement test deliberately exercises a save failure and emits a warning.
- Confirmed with isolated headless probes in ignored `builds/review/`: home pickup requests `help_place`, whose generated line directs the child to the dam rather than the home. Home help also reuses the branch collection line. Add stage-specific home voice cues.
- Confirmed with forced save rejection: home and food placement signals invoke persistence synchronously, but subsequent success status signals overwrite the save-failure warning in the same call. Preserve the warning independently or propagate the persistence result before presenting success.
- A malformed JSON `schema_version` containing an array produces a runtime script error in `DamSave._read_valid` before backup recovery. The tested backup still recovered; validate the version type before conversion in both read and validation entry points.
- Positive findings: stable asset IDs, schema migration, isolated test saves and durable stage reconstruction are already covered by executable checks. Home and food have separate stage scripts. The main world script remains responsible for UI, input routing, persistence orchestration and debug captures; extracting these responsibilities can be incremental.
- No real-device, child playtest, visual inspection or voice listening validation was performed in this review. Existing Android and human-validation items remain open.

## Implementation review follow-up (9 November 2026)

- Added the home-specific provisional voice events `help_home_collect` (`Escolhe uma peça para a casa.`) and `help_home_place` (`Leva a peça até à casa.`). Home help and pickup now use these events instead of dam help that points to the represa. Generated the clips with the documented local Piper model and imported their WAV resources; updated the voice map and `audio.md`. Listening checks remain open.
- Added a world-level save-warning latch so synchronous placement status messages and the home-to-food and food-to-winter transitions cannot overwrite a failed-save warning. A later successful save clears the latch.
- Extended home and food integration tests to force a failure on the final placement. They verify the warning through the home-to-food transition, the winter ending and continuing to visit, then save successfully to the isolated test directory. The deliberate failures emit expected warnings.
- Schema validation now checks the schema-version type before comparing it, accepts only exact supported numeric versions, rejects fractional/non-numeric versions, and avoids integer conversion on malformed JSON. Save validation and file loading share the safe type check. Added public validation and malformed-primary/backup-recovery coverage for an array schema version.
- `./tools/castor.ps1 check` passed all groups: bootstrap, movement/dam, save, home, food, ending, support characters, environment, beaver and asset imports. Windows and Android device checks, child play, and voice listening were not performed.


## Roadmap adjustment — visual valley composition (9 November 2026)

- At the author's request, added milestone 4b between the functional chapter and MVP finalization. The current implementation is not accepted as the final visual valley; historical 3b sequencing closure and passing functional tests do not imply visual acceptance.
- Added `roadmaps/04b-visual-valley.md` with a v3-reference visual contract, scope boundaries, five staged deliverables, code/asset work areas and explicit author, child and device acceptance criteria. Start with an in-engine simple-volume composition, then playable river/dam/routes, a coherent visual set, home/food/winter integration and full validation.
- Preserve existing mechanics and saved progress; keep required approaches off open water without adding swimming. Stones/mud do not become collectible merely because they appear in the reference. Exact composition and representative art are reviewed with the author before detailed production is replicated.
- Updated the main roadmap, chapter/MVP navigation, 3b carry-over, environment production track and mockup guidance. No game code, assets or completed validation statuses changed. No commit created.
- Validation: checked changed Markdown links and diff formatting; game tests were not rerun for this documentation-only change.

## Planned Higgsfield scenery pilot (9 November 2026)

- Added `higgsfield-asset-pilot.md` at the author's request and linked it from 4b V3. The experiment compares one generated tree and one generated rock with simple Blender equivalents in an isolated Godot scene beside the existing beaver.
- Defined starting prompts, source/export locations, bounded attempts and cleanup, active/waiting time and credit accounting, mesh/material inspection, repeat-instance comparison and an edit/re-export check. Generation requires an available route and a recorded credit ceiling before spending; no subscription or tool installation was performed.
- Adoption is decided separately for each asset category from visual acceptance, technical usability, provenance and total effort. Better appearance without reduced effort is recorded as a tradeoff; missing evidence remains inconclusive. The experiment does not block simple-volume valley composition.
- Documentation only: no assets generated, game code changed, credits consumed, device validation claimed or commit created. Checked local Markdown links and diff formatting; no game tests were rerun.

## Scenery plan adjustment — local Blender route (9 November 2026)

- The author showed a subscription checkout during Higgsfield Blender plugin connection: a three-day trial followed by a quoted EUR 97.17 charge with a one-cycle discount. This is evidence of that account flow, not a universal pricing statement. No purchase or completed generation was reported.
- Deferred the Higgsfield pilot and removed it as a prerequisite for 4b V3. Its tasks remain an inactive proposal, to revisit only at the author's request with access and spending limits established.
- Added `blender-scenery-sample-plan.md`: create one tree and one rock locally with Blender Python and editable sources, export GLB, inspect beside the beaver in an isolated Godot scene, check reuse and edit/re-export, then obtain visual acceptance before expanding the set. No paid service is required for this route.
- Documentation only; no models generated, tools changed, subscription started or commit created. Checked Markdown links and diff formatting; gameplay tests were not rerun.

## Golden tree reference (9 November 2026)

- Selected a golden rounded-canopy tree with a pale trunk for the first image-to-3D experiment at the author's request.
- Generated the isolated reference with the built-in OpenAI image generation tool and saved it as `art/environment/scenery-sample/references/golden-tree-v1.png`. This is a 2D concept input, not a validated 3D asset. No Meshy generation or credits were used by this action.

## Meshy tree received and prepared (9 November 2026)

- The author resumed an external generation trial using Meshy and reported Pro access; Higgsfield remains deferred. Received the tree GLB and preserved an unchanged copy under `art/environment/meshy-tree/originals/`.
- Confirmed 3112 triangles, 2626 exported vertices, one mesh and no materials. Prepared a reproducible editable Blender source and GLB with a ground-level origin, provisional 2.4 m height, seam welding, recalculated smooth normals and gold/beige material assignments. No further polygon reduction was required.
- Inspected a Blender render: the intended silhouette is present, with minor canopy irregularities still visible. Blender import/export/render and Godot resource import succeeded. Main scene and gameplay saves unchanged; no commit created.
- At this point, an in-game comparison and production adoption were pending. The later provisional valley integration and desktop capture are recorded below; author visual acceptance, device checks and generation-time licence confirmation remain pending. This user-supplied Meshy trial does not activate a Higgsfield subscription or authorize further purchases.

## Meshy golden tree integrated provisionally (9 November 2026)

- Integrated two instances of the prepared Meshy golden tree into the actual valley through `visual_environment.gd`, replacing two rear-side procedural bush clusters. Each is scaled to 0.68 of the prepared 2.4 m model. The trees are decorative only, add no physics blockers or targets, and persist in the shared environment during dam, home, food and winter progression.
- Kept both `art/environment/meshy-tree/golden_tree.blend` and its paired export `game/assets/environment/meshy_tree/golden_tree.glb`; the user-supplied original remains untouched. Updated the production inventory and asset README with current integration and pending provenance.
- Validation: `./tools/castor.ps1 check` passed all groups, including the visual-environment and asset-import checks. Re-exported the Windows build and captured the completed winter valley with Godot using the project scene and isolated `user://capture_save/`; inspected `builds/windows/ending_valley.png`. The two trees are visible at the actual gameplay camera distance and do not cover the lodge, food store, dam or branch targets in this view.
- Limits: desktop screenshot and automated checks only; no Android, phone performance, child or author visual acceptance. Generation-time licence/attribution remains unconfirmed; an earlier UI showed CC BY 4.0 and later Meshy Pro access is not treated as retroactive permission. This is provisional integration, not completion of 4b V3.


## Proposed playable valley relief (9 November 2026)

- Following the author's feedback that the tree integration improved the scene but it still reads as a board game, added `valley-relief-plan.md` and linked it from 4b and the main roadmap. The flat slab in the mockup is no longer the terrain target; palette and spatial relationships remain references.
- Proposed an authored terrain with a low central floor, enclosing hills, excavated riverbed, upstream lake basin and dry connected routes. The first delivery is a landform review and a slope-traversal sample, before further decoration.
- Identified flat-ground assumptions in input, path generation, actor arrival, spawn and item/stage heights. Proposed shared terrain/layout/navigation services, a height-aware route graph with edge clearance/slope checks, and preserved stable save IDs.
- Defined staged chapter integration, water/winter adaptation and save/input/device acceptance checks. Dimensions and slope limits are initial proposals, not validated performance or usability claims. No implementation or commit performed.
- Validation: checked local Markdown links and diff formatting. No game tests rerun for this documentation-only change.


## Valley relief R1 — landform preview (9 November 2026)

- Implemented the R1 review as an isolated scene, `valley_relief_preview.tscn` plus `valley_relief_preview.gd`, backed by `valley_terrain.gd` (deterministic height grid, visible mesh, water at three levels) and `valley_layout.gd` (five anchors, route and fit calculations). The chapter scene, saves, navigation and actor were not changed.
- Terrain is one 0.25 m grid: the visible mesh, `height_at`, water coverage and the fit evidence all use the same triangles. This removes the field-versus-mesh mismatch that would otherwise make R2 collision and anchors disagree by up to about 0.2 m. The footprint is an irregular oval of about 19 × 18.5 m around the 13 × 11 m playable rect; the river runs along the −X side, the near bank holds every activity, and hills enclose the −X/−Z sides.
- Three variants (`gentle`, `pronounced`, `wide_bank`) change hill height, channel depth, lake radii and river position. The fit report for all three passes: usable near bank 79.4–90.5 m², minimum usable width 6.5–7.8 m, route 12.1 m, route maximum 12.4–12.6°, positive zone clearance 0.3 m and no camera-hidden ground. The optional downstream crossing is not indicated.
- Added temporary route, blocked-slope and maximum-water overlays, a portrait check, a low-side diagnostic and a static beaver/two existing trees for scale. Added `--capture-relief` to the preview and `./tools/castor.ps1 relief` / `relief-capture`; added `--capture-initial` for a clean baseline of the current chapter start.
- Camera comparison uses the same position and target for both projections: orthographic size 15.0 versus perspective fov 36° from (9.5, 14.5, 13.0) toward (−1.5, 0.5, −2.0), preserving the game's 36.97° elevation. Perspective adds depth through the converging channel but exposes the outer terrain edge at the top of the frame; orthographic keeps target sizes equal and the whole terrain framed. The author chose **perspective** and the **`wide_bank`** variant on 9 November 2026; the preview now opens in that combination. For that variant the fit is 90.5 m² of usable bank, 7.8 m minimum width and 20.6° lodge near-side slope. Confirmation of the landform as the R2 base remains.
- Evidence: baseline captures in `builds/relief/baseline/`; variant, projection, overlay, portrait and low-side captures plus three contact sheets in `builds/relief/`; fit numbers in `builds/relief/fit_report.json`. `valley_terrain_test.gd` and `valley_preview_test.gd` pass; `./tools/castor.ps1 check` passed all existing groups. No commit created.
- Limits: R1 is visible geometry only. Collision, navigation, slope traversal and grounding wait for R2 after the shape is accepted. The preview uses simple volumes and does not validate child readability, device performance, final art or water behaviour. The `pronounced` near-bank slope has only about 1.3° of margin below the 36.97° camera elevation; that variant is not the chosen one but the limit remains if it is revisited.


## Valley relief R2 — traversal proof (9 November 2026)

- Added collision directly from the accepted `wide_bank` triangles (`ValleyTerrain.build_collision_body()`): one layer-1 `StaticBody3D` with a `ConcavePolygonShape3D` built from the exact visible mesh. Collision rays match `height_at` within 0.02 m at anchors, triangle interiors and boundaries and on the channel bank.
- Added `valley_navigation.gd`: one `AStarGrid2D` on 0.5 m cells over the 13 × 11 m bank (572 cells, 275 solid for `wide_bank`). Cells are solid outside the bank, in the channel or maximum lake footprint, above the 20° route limit, or within the actor's 0.26 m capsule plus 0.04 m margin of those. Paths are lifted with `height_at`; `find_path` is strict at the destination and `find_approach` is ready for R3.
- Added an isolated `valley_traversal_preview` with terrain collision, water, simple anchors/dam/lodge/food markers, the beaver and click/tap routing. A raised valid slope is accepted; water and inaccessible hills are refused. It does not touch the chapter scene, saves or stages.
- Adapted `prototype_actor.gd` with `floor_snap_length = 0.35`, `floor_max_angle = 40°`, `floor_constant_speed = true` and `floor_stop_on_slope = true`; waypoint arrival stays horizontal at 0.035 m and the visual body stays upright.
- `--capture-traversal` walked spawn → dam approach → lodge → food bank → spawn and saved five captures. The actor arrived at every anchor with terrain-following height (dam ≈ 0.44 m, lodge ≈ 0.71 m, food ≈ 0.61 m, spawn ≈ 0.68 m), climbed to the lodge and descended on the return; retargeting halfway up the slope and a repeated tap on the same destination both completed.
- Added `valley_collision_test.gd`, `valley_navigation_test.gd` and `valley_traversal_test.gd`: surface rays, water/steep/outside solidity, path continuity and determinism, approach resolution, uphill/downhill, grounding, water/hill refusal, screen-click routing, retargeting, repeated taps and floor settings. All pass, and `./tools/castor.ps1 check` still passes the chapter groups. No commit created.
- Limits: R2 is an isolated preview. The chapter still uses the old flat world and routing until R3; carrying a branch on a slope, dynamic obstacles and stage approaches remain to be integrated and tested. No Android, device or child validation was performed.
- The author tested the traversal preview on 10 November 2026 and accepted R1/R2. Next is R3: integrate the accepted terrain, collision and navigation into the chapter without changing save IDs or stage counts.


## Valley relief R3 — chapter integration (10 November 2026)

- Replaced the flat chapter world with the accepted `wide_bank` terrain, exact collision and shared 0.5 m navigation. The flat ground, boundary walls, central rock, one-metre stage paths and orthographic camera are gone; the play camera is the accepted perspective view (fov 36°, 9.5, 14.5, 13.0 → −1.5, 0.5, −2.0).
- Grounded the chapter from `ValleyLayout`/`ValleyTerrain`: five branches spread across the raised clearing, dam cue on the bank with placed branches across the dam line, three home-part clearings, five food bundles, owl/otter, trees, bushes, reeds, snow patches, roof cap and family. Stable save IDs, material counts, verbs and finishing choices are unchanged.
- Followed the author's beaver-fidelity correction: the lodge is hidden until the dam is complete, then appears as a stick-and-mud mound in the lake with a dark submerged entrance. Its compact floor sits above the highest sampled bed point under the footprint and below the initial water surface; the dry `lodge` anchor remains the beaver's approach. The food store is an underwater branch cache beside the lodge, still approached from the bank. The dam cue is hidden once the dam is complete.
- Removed the parallel stage route builders. `HomeStage` and `FoodStage` now use `ValleyNavigation.find_approach`; the world uses `find_path` and `is_walkable`; the absolute-height tap rejection became terrain-surface navigation, so water and steep banks are refused.
- Rewrote `movement_test.gd` for the terrain chapter: pre-dam lodge hidden, grounded spawn, water/outside refusal, real branch ray, thick-branch gnawing, three dam placements, home and food completion and winter. Updated `home_stage_test.gd`, `food_stage_test.gd`, `ending_test.gd`, `visual_environment_test.gd` and `support_characters_test.gd` where flat-world assertions no longer applied. `./tools/castor.ps1 check` passes every group; the deliberate save-failure cases still emit their expected warnings.
- Captured the integrated chapter from the play camera: `builds/relief/r3_initial.png`, `r3_home.png`, `r3_food.png` and `r3_winter_valley.png`. The chapter restores completed dams, home slots and food placements through the new anchors.
- Limits: R4 still owns prepared water-level behaviour and winter/basin presentation. The dam cue is on the bank about 4.6 m from the dam centre, so branches visibly travel to the dam; a closer clearing should be judged with the child. The underwater cache ring is partly behind the lodge from the play camera and needs a readability check. The accepted bank slopes kept the interaction rings readable, so no extra local terrain flattening was added; revisit if child testing shows clipping. The perspective camera still exposes the outer terrain edge in some views. No Android, device or child validation was performed. **Superseded for water, cache, snow and boundary presentation by the R4 notes below; human/device validation remains open.**


## Valley relief review fixes (10 November 2026)

- Added the R1 terrain, collision, navigation, traversal and preview tests to `./tools/castor.ps1 check`, with per-test exit handling. The traversal integration runs at a fixed 60 physics frames per second; the preview assertion now matches the accepted perspective camera (36°) and `wide_bank` variant.
- Restored movement regressions lost in the terrain rewrite: rotten branch refusal and bent-state persistence, carry swapping/cancellation/repeated targeting, three-normal-branch completion, saved finish choice and solved-obstacle restoration, and grounded fresh/restored spawns. Kept the voice/effect, help cues, branch selection and touch-versus-mouse restart gesture checks.
- Added lodge regressions that sample the complete floor footprint at up to 0.2 m intervals, check the submerged entrance, verify dry approaches for both home slots, and exercise the roof through the camera ray. The home stage remains gated until dam completion and is restored from a completed-dam save.
- Tightened terrain mesh tests for repeated mesh reuse and cache invalidation on variant changes. The capture path now prepares and saves a valid completed chapter in isolated `user://capture_save/` before home, food or ending captures; a capture setup/save failure exits with an error.
- Validation: `./tools/castor.ps1 check` passed with exit code 0 on Windows/Godot 4.7.2, including all five valley groups and all existing chapter, actor and asset groups. Home and food tests emitted their expected warnings while exercising deliberately forced save failures. Graphical capture runs validated separately by the capture agent; captures use an isolated save directory.
- Limits: these are automated desktop checks and captures. No Android/device, child or author visual acceptance was performed; no milestone or R4 validation status is claimed.


## Valley relief R4 — prepared water and winter (10 November 2026)

- Replaced the single water mesh with two prepared reaches. `ValleyTerrain.water_mesh_reach(level, upstream)` clips the water to the terrain triangles, so the shoreline follows the bank; the upstream lake uses the requested level and the downstream stream stays at the initial level. The combined `water_mesh` remains available for the preview and tests. The old sawtooth shore and the downstream lift are gone.
- The chapter now keeps `ValleyLake` (upstream) and `ValleyStream` (downstream) meshes. A placement swaps the upstream mesh and lifts it from the previous level over 0.7 s, so the new shore floods progressively; ripple rings and a spillway show the change. The third placement keeps the full level and completes the dam and celebration.
- A clear-water window is built around the food cache (lighter tint and lower vertex alpha); the cache has a surface ring of sticks, a submerged basket and a pile whose centres stay below the surface. It moved to the camera-facing side of the lodge, with a dedicated dry bank approach. The cache is visible in the overview capture without relying on the progress counter.
- The dam is a brush-and-mud structure on a horizontal crest with abutments, stakes, twigs, a mud bank and a spillway. Placed branches sit on the crest instead of under the full lake. Gameplay placement animates the branch from the beaver to the dam; restore and capture setup place instantly.
- The lodge floor is clamped below the full lake and above the sampled bed; the mound uses the full waterline. Added a rounded multi-lobe mud-and-stick shell, a visible above-water opening, woven sticks and a snow cap controlled by `HomeStage.set_snow()`. The snow cap follows the roof slot and stays hidden outside winter.
- Winter: snow patches are sampled on dry ground, aligned to the terrain normal and avoid the lodge, cache and dam; the family is chosen from dry bank candidates and faces the lodge; the finished dam gets snow caps; the sun and sky shift to a cooler palette. `SupportCharacters` places the otter on the full lake surface.
- Boundary treatment: `ValleyTerrain.boundary_skirt_mesh()` adds a soil/grass skirt around the exact terrain edge, and `VisualEnvironment` adds two layers of distant procedural hills. The hard oval cut against the background is much less visible from the play camera. A seam remains where the far terrain meets the backdrop in some views; it is scenery, not collision.
- Bank readability: the terrain wet band was muted, the water edge is clipped and shallower at the shore, and reeds and shore rocks follow the near lake bank. The lake remains blue upstream and the stream green downstream.
- Evidence: added `game/tests/valley_water_test.gd` and registered it in `check`; extended `valley_terrain_test`, `valley_preview_test`, `visual_environment_test`, `home_stage_test`, `food_stage_test`, `ending_test` and `movement_test`. `./tools/castor.ps1 check` passed all groups on 10 November 2026; the forced save-failure cases emitted their expected warnings.
- Captures in ignored `builds/relief/`: `r4_water_initial.png`, `r4_water_one.png`, `r4_water_two.png`, `r4_water_complete.png`, `r4_home.png`, `r4_home_complete.png`, `r4_food.png`, `r4_food_complete.png`, `r4_ending.png`, `r4_ending_valley.png` and the contact sheet `r4_sheet.png`. All use the play camera at 960 × 600 and the isolated `user://capture_save/`.
- Limits: automated desktop tests and captures only. No Android install, real-device rehearsal, child observation or author visual acceptance. The lake rise is a prepared mesh animation, not water simulation. The dam cue is still on the bank about 4.6 m from the centre; the flight animation makes the branch travel, but a closer work ledge or a different cue should be judged with the child. The clear-water cache and snow caps need reading checks on a phone and at the child's play distance. The backdrop seam and smooth distant hills are provisional. No frame-time, heating or device-performance measurement was made.


## Valley relief R5 — saves, build and remaining gates (10 November 2026)

- Added `game/tests/save_fixture_test.gd` and registered it in `check`. It writes isolated schema 1 and schema 2 fixtures for partial dam, completed dam with both finishes, partially built home, partial food and completed winter, instantiates the chapter on each, and verifies grounded safe spawn, stage activation, counts, finish, restored home/food IDs, winter family/snow and the protected new-adventure action.
- The fixture test compares the save file before and after restore: loading on the new terrain does not rewrite it. Schema 1 files stay schema 1 on disk and migrate to schema 2 only in memory, so the terrain and layout changes alone do not force a schema bump. All nine fixtures passed: `CASTOR_SAVE_FIXTURES_OK schema1 schema2 partial_dam finishes partial_home partial_food winter safe_spawn unchanged_files`.
- Extended `valley_traversal_test.gd` with a simulated-time slope measurement using `Engine.get_physics_frames()` rather than wall-clock time. The dam→lodge climb and the lodge→dam descent took 1233 ms each for a 3.41 m route; the expected time at 2.8 m/s is 1219 ms. Both directions stayed within the bounds and the ratio is essentially 1, so the accepted slopes show no excessive slowdown. Output: `CASTOR_TRAVERSAL_SPEED uphill_ms=1233 downhill_ms=1233 route_m=3.41 expected_ms=1219`.
- Exported the Windows debug build with `./tools/castor.ps1 export-windows`. Ran the exported `builds/windows/Castor.exe` with `--capture-initial`, `--capture-water`, `--capture-home`, `--capture-food` and `--capture-ending` one at a time with `Start-Process -Wait`; each ended with exit code 0 and printed its `CASTOR_GRAPHICS_OK` line. Captures were checked at 960 × 600 and inspected in `r5_exported_sheet.png`; they match the project captures for the initial marsh, dam growth, lake, lodge, food cache and winter.
- Exported-build inspection: the initial bank, branch cues and first dam placement are readable; the lake grows blue upstream while the downstream stream stays green; the lodge, cache marker and winter family are visible; no capture shows a required route crossing open water. Provisional differences remain: the far backdrop seam and smooth distant hills, the cabin-like lodge silhouette, the bright selection ring and the bank-side dam cue.
- `./tools/castor.ps1 check` passed all groups on 10 November 2026, including the new save fixtures and the slope-speed assertion. The forced save-failure cases emitted their expected warnings.
- Android gate: `adb devices` reported no attached device. No APK was installed or run, so Android remains unvalidated. No author visual acceptance, adult rehearsal, child observation, frame-time measurement or heating measurement was performed.
- Captures in ignored `builds/relief/`: `r5_exported_initial.png`, `r5_exported_water_initial.png`, `r5_exported_water_one.png`, `r5_exported_water_two.png`, `r5_exported_water_complete.png`, `r5_exported_home.png`, `r5_exported_home_complete.png`, `r5_exported_food.png`, `r5_exported_food_complete.png`, `r5_exported_ending.png`, `r5_exported_ending_valley.png` and the contact sheet `r5_exported_sheet.png`.
- Limits: this closes the automated/desktop evidence available without a device or a person. The Windows build is a debug export that was run, not installed on a store or device. R5 remains open for author visual acceptance, the 15-minute adult rehearsal, Android on the POCO and the child observation. The save fixtures cover the documented progression and both finishes; they do not replace a real interrupted session on a phone.


## Independent validation follow-up (10 November 2026)

- Independent validation returned **PASS WITH FINDINGS**. Progression, saves and the automated suite passed. The valid findings were addressed as follows.
- **P2 — branch orientation was not applied during flight.** `CollectibleBranch.place()` now interpolates the complete transform with `Basis.slerp` and sets the exact final transform at the end, so a thrown branch no longer keeps the beaver's facing. It also records `placed_slot`, and `_save_dam_state()` sorts placed materials by that explicit index instead of the in-flight X position. Added `game/tests/branch_flight_test.gd` to `check`; it verifies the final orientation, final position, slot index and instant-placement path. Output: `CASTOR_BRANCH_FLIGHT_OK orientation slot_index instant_return`.
- **P3 — cache depth.** The cache target is now clamped between the sampled lake bed and the full water level, and every placed bundle centre stays below the surface. Added an assertion for all placed bundle centres to the food test. The cache still reads as a surface basket because the visual tops and the surface marker are necessarily near the water; this is a readability tradeoff, not an above-water centre.
- **P3 — finish dominance.** The finish no longer repaints the full structural log. The logs keep their timber colour and the choice is a short 1.4 m crest accent. The movement test checks both accent colours; the environment test checks that the logs stay timber.
- **P3 — message overlap.** The home/food invitation moved above the beaver and the bottom completion messages sit on a translucent band with outlined text. The band is shown only for the larger completion messages, not for the invitation.
- **P3 — snow presentation.** Snow patches are smaller, more numerous and clustered in overlapping groups; they still read as patches rather than continuous snow cover, which remains a V3/V5 refinement.
- **P3 — dam marker and cache.** Added a second small ring on the dam crest so the destination is visible even though the approach cue stays on the bank. Reduced the placed bundle scale and kept every centre below the surface; the basket and leaf tops still sit near the surface because the cache water is shallow.
- **P3 — backdrop and lodge attempt.** Lightened the distant hills and added a sparse line of darker bushes on the far ridge; the seam is less harsh but still visible. A continuous ridge curtain was tried and reverted because it read as a picket fence. A single lodge dome was also reverted; the final lodge uses several mud-and-stick lobes, a front opening and woven sticks, so its silhouette is less cabin-like while the two build positions stay visible.
- Still open from the review: the far terrain/backdrop seam, the bank-side dam cue distance, the cache's surface-basket readability and the author's acceptance of the rounded lodge. A short fog trial blurred the whole scene and was reverted rather than degrading contrast.
- Re-ran `./tools/castor.ps1 check` after the fixes; all groups passed, including the new branch-flight test. Re-exported Windows and regenerated the R4/R5 captures and contact sheets. No Android, child or author acceptance was performed.

## Painted beaver candidate (10 November 2026)

- Used Blender to bake a single 1024 × 1024 base-colour texture onto the supplied Meshy model's UV layout, using the author-supplied illustration for the palette. The editable Blender file, texture, GLB, and capture are in the local `builds/beaver-paint-preview/` trial.
- Imported and rendered the candidate in a separate Godot 4.7.2 Compatibility project. The preview verified a 40-bone skeleton, the texture, and the two-second `Idle` clip. The branch is part of the candidate mesh. Gameplay integration, a walking clip, and real-device checks remain open.
- Created a branchless variant in `builds/beaver-branchless-preview/`. Removed the fused shaft and leaves, closed the cuts into one connected manifold surface, and rebaked the texture with UVs for the repaired faces. Reviewed front, side and three-quarter Godot captures. The paws retain their original grip pose and a faint join is visible between them at close range. The painted source with the branch is kept alongside the separate variant.
- Integrated the candidate into the playable valley through `./tools/castor.ps1 beaver-playtest`. The trial scales the visual to 72%, plays `Idle` and a provisional skeletal `Walk`, and aligns the separate dam branch with the candidate's paws. It uses a clean, isolated playtest save. The Windows chapter test passed with the painted rig, walking clip, branch pickup, gnawing, dam placement, lodge, food and winter progression. The play-camera capture with a carried branch is in `builds/beaver-branchless-preview/beaver-in-valley.png`. Author visual acceptance, Android and child checks remain open.
- `./tools/castor.ps1 check` passed on Windows with both chapter variants. The forced save-failure tests emitted their expected warnings.
- Compared the author-supplied `Meshy_AI_Cheerful_Little_Beave_1110220136_generate.glb` against the painted playtest candidate in the Windows valley at the same 1.224 m height, spawn and camera. The new 3,078-triangle mesh has UVs and a cleaner chest and paw silhouette, and it has no materials, textures, skeleton or clips. The side-by-side capture is in `builds/beaver-generation-comparison/`. The new mesh is a static comparison candidate pending rig and texture evaluation.

## Branchless character concept sheet (10 November 2026)

- Updated docs/castor/mockups/characters-concept-v3.png with the built-in image editor to remove the large beaver's held branch and leaves; its paws are now empty. Visually inspected the result: both beaver views are branchless, and the owl, otter, colourful layout and Portuguese labels remain present.
- This is a 2D reference edit only; no game assets, device validation or milestone status changed.

## New beaver rig trial (10 November 2026)

- Fitted a 13-bone rig and authored provisional `Idle` and `Walk` clips for the second Meshy mesh. Used automatic weights as a starting point, adjusted the arm-to-chest and leg-to-belly transitions, and normalized to four influences per vertex. Blender verified that both clips loop and deform the skin. The walk still has slight floor penetration in the sampled poses.
- Ran the rig in the real Windows valley with the isolated `builds/beaver-rig-preview/playtest.ps1` launcher. The test verified foot motion, collection, branch shaft alignment at both paws, and placement in the dam. The editable Blender source, GLB and captures are in that trial directory. The branch uses a fixed offset during carry, and the rig uses a neutral material pending texture work. Android and visual acceptance remain open.

## Painted Castor becomes the playable beaver (10 November 2026)

- Painted the second Meshy model from the branchless reference and baked a 1024 × 1024 base-colour texture. The playable valley now selects the painted 13-bone Castor by default. The source is `art/characters/castor/Castor.blend`, with the original GLB kept beside it in `originals/`. Carry offsets for dam branches, lodge parts and food bundles match the new paws.
- The graphical Windows check used the actual chapter asset, observed foot motion in `Walk`, collected a branch, checked both paw positions, and placed the branch in the dam. Captures are in `builds/castor-painted-v2/`. The full `./tools/castor.ps1 check` suite passed, including the complete chapter and save fixtures. The walking animation remains provisional. Android and author visual acceptance remain open.
