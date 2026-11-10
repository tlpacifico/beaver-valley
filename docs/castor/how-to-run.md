# Running Castor's first steps

## What exists

Standard Godot **4.7.2.stable.official.ed1daf0bf**, typed GDScript and the Compatibility renderer. The main scene is the playable valley with the complete dam → home → food → winter chapter, click/tap movement on the authored terrain and the accepted perspective camera. The original cube scene is still available separately, as is a 3D asset test scene (Blender branch and third-party animated model; see below). The look is provisional, not final art.

Project: `game/project.godot`. Main scene: `game/scenes/movement.tscn`. World, chapter and input: `game/scripts/movement_world.gd`; terrain: `game/scripts/valley_terrain.gd`; anchors: `game/scripts/valley_layout.gd`; routing: `game/scripts/valley_navigation.gd`. Physics movement: `game/scripts/prototype_actor.gd`. Placeholder shapes: `game/scripts/prototype_shapes.gd`. Exports: `game/export_presets.cfg`. Cube preserved in `game/scenes/bootstrap.tscn`.

## Opening on the PC

At the repository root, in PowerShell:

```powershell
./tools/castor.ps1 run
./tools/castor.ps1 editor
./tools/castor.ps1 cube
./tools/castor.ps1 relief
./tools/castor.ps1 relief-capture
./tools/castor.ps1 traversal
./tools/castor.ps1 traversal-capture
```

Run one action at a time. You can also open `builds/windows/Castor.exe` directly, without the editor. Clicking a free spot on the bank makes the character walk to the yellow circle along the terrain; another valid click changes the destination. Water, the future lake footprint, steep banks and outside the valley are refused without cancelling the current path. Closing the window ends the test. In the `cube` scene, the button pauses and resumes the rotation.

Movement uses the shared 0.5 m `AStarGrid2D`, lifted onto the same triangles as the visible terrain and collision. The character follows slopes with floor snapping, and the camera keeps the accepted perspective framing; manual camera control is not needed. The look and the movement do not represent final presentation.

### Reviewing the valley relief (R1)

```powershell
./tools/castor.ps1 relief
```

Opens the isolated relief preview without touching the chapter scene or its save. Use `1`/`2`/`3` for the `gentle`, `pronounced` and `wide_bank` landforms, `O`/`P` for orthographic or narrow perspective, `W` for future routes, `B` for blocked slopes, `M` for the maximum lake footprint and `L` for a low-side diagnostic camera. Nothing in this scene has collision or navigation yet; it is a landform review.

`./tools/castor.ps1 relief-capture` runs the same scene, writes labelled 960 × 600 and 540 × 960 captures plus `fit_report.json` to Godot's `user://relief/` folder and exits. Copy them to ignored `builds/relief/` for review. The focused checks are `game/tests/valley_terrain_test.gd` and `game/tests/valley_preview_test.gd`; run them with the Godot console and `--headless --path game --script res://tests/...`.

### Reviewing slope traversal (R2)

```powershell
./tools/castor.ps1 traversal
```

Opens the isolated traversal preview on the accepted `wide_bank` terrain. Click or tap a spot on the bank; the beaver routes through the shared 0.5 m navigation and follows the collision surface. Water, the lake footprint, steep banks and outside terrain are refused with a message. The chapter scene is not touched.

`./tools/castor.ps1 traversal-capture` walks spawn → dam → lodge → food → spawn, writes five captures to `user://relief/` and exits. The focused checks are `valley_collision_test.gd`, `valley_navigation_test.gd` and `valley_traversal_test.gd`.

### Old follow-camera experiment

The `follow` tool action predates the terrain chapter and is not part of the current review. The accepted fixed perspective camera is what `run` opens; do not use the old follow experiment to judge the valley.

## Restarting the first-play experiment

On PC, press Ctrl+R and confirm. On a touchscreen, hold the title for about 1.2 seconds to reveal **Recomeçar (adulto)**, then press it and confirm. Restarting reloads the scene and returns the three branches to their starting positions.

## Checking and exporting

```powershell
./tools/castor.ps1 check
./tools/castor.ps1 export-windows
./tools/castor.ps1 export-android
```

The `check` command tests the cube, the terrain chapter route (real ray selection, water/steep refusal, gnawing, dam, home, food and winter), isolated save recovery, the home and food stage details, and static and animated asset imports. Success ends with `CASTOR_ASSETS_OK`. It does not validate real touch or understanding by the child.

For automatic graphical verification of the current executable, run `builds/windows/Castor.exe -- --capture-movement`; it sends a mouse event, checks that movement started, saves `movement.png` to Godot's user data folder and exits on its own. Run `builds/windows/Castor.exe -- --capture-initial` to capture the untouched chapter start with an isolated save. Run `builds/windows/Castor.exe -- --capture-home` to make the home stage available immediately, build it, and save `home.png` and `home_complete.png` to the same folder. Run `builds/windows/Castor.exe -- --capture-food` to build the home and the food store and save `food.png` and `food_complete.png`. Run `builds/windows/Castor.exe -- --capture-ending` to build the whole chapter and save `ending.png` and `ending_valley.png`. The capture modes use an isolated `user://capture_save/` and do not touch the normal chapter save. Do not pass those options for normal play. For the old cube test with the engine, use the explicit scene: `Godot_v4.7.2-stable_win64_console.exe --path game res://scenes/bootstrap.tscn -- --smoke-test`.

The debug exports generate `builds/windows/Castor.exe` and `builds/android/castor-debug.apk`. `builds/` and caches stay out of Git. The script does not install tools if they are missing.

## Local tools and reproduction

- Editor in `%LOCALAPPDATA%/Programs/Godot/4.7.2/`.
- Windows x86_64 and Android APK templates in `%APPDATA%/Godot/export_templates/4.7.2.stable/`, extracted from the official package after verifying SHA-512. The remaining targets were not extracted.
- Android SDK in `%LOCALAPPDATA%/Android/Sdk` and Java Temurin 17.0.17 configured in Godot's local export preferences. Those paths are not saved in the project.
- Build-tools 35.0.1 added to the existing SDK. The exporter of this version actually used build-tools 36.0.0, also already installed. The generated APK indicates target/compile SDK 36, minimum 24 and arm64-v8a architecture.
- APK export with a precompiled template, without custom Gradle. No new NDK/CMake versions were installed; they are not a dependency exercised by this test. Review the requirements if we start compiling templates/plugins.
- The global `JAVA_HOME` variable pointed sdkmanager to Java 11. Java 17 was selected only in the installation process; the global variable used by other projects was not changed. sdkmanager emitted XML schema warnings but finished successfully; it was not updated globally at this stage.
- Local debug key managed by Godot, outside the repository. This APK is for testing, not a store release.

On another PC, get the standard editor and the templates of the same version from the [official release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable), check the SHA-512 manifest and configure SDK/JDK in the export preferences. See [Android export 4.7](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html). The local paths are not assumed to exist on another machine.

## Test on the POCO X7

Result on 8/11/2026: see "Android validation results" at the end of this page.

Connect over USB, enable USB debugging in the developer options and accept this PC's authorization on the device. `adb devices` should show the device as `device`, not `unauthorized`. These settings were not changed remotely.

With only the intended device connected and authorized, install `builds/android/castor-debug.apk` using `adb install -r` with that path and open «Castor - Primeiro teste». If there are several devices, explicitly select the POCO with `adb -s`.

Check visible character, destination selection by touch, going around the rock, landscape framing and coming back after sending the app to the background. Exporting/signing an APK does not demonstrate that these tests pass on the phone.

### Opening the asset scene on the phone

On Android, the Godot activity ignores arguments sent from outside (`am start --esa command_line_params` has no effect on an exported activity), so `--asset-test` does not work. In debug builds, the main scene opens the asset scene if the marker file `user://open-asset-test` exists:

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb shell run-as org.thacio.castor.bootstrap touch files/open-asset-test
& $adb shell am force-stop org.thacio.castor.bootstrap
& $adb shell monkey -p org.thacio.castor.bootstrap -c android.intent.category.LAUNCHER 1
```

While the marker exists, the game always opens in that scene. To go back to normal: `& $adb shell run-as org.thacio.castor.bootstrap rm files/open-asset-test` and reopen the app. Release builds ignore the marker.

## Startup reproduction (8 November 2026)

The Godot editor was started and closed twice with `--headless --path game --editor --quit`; `./tools/castor.ps1 check` passed, both debug exports completed, and the Windows executable exited successfully after `--capture-movement`. This checks editor startup without a graphical editor session; it is not a clean-cache or clean-machine test. Android export reported that no project icon is configured but completed and signed the APK. At that point the new APK had not been installed; the subsequent POCO retest is recorded in the progress notes.

## Results of this stage

- Scene import by the editor without script errors.
- Windowless test: rotation and pause passed.
- Windows executable exported and run outside the editor: exit code 0 and the rotation/pause test passed; the renderer identified the RTX 3060.
- Executable screenshot inspected: ground, cube, shadow, text and button visible. Copy in `builds/windows/bootstrap.png`.
- ARM64 APK exported; signature verified by `apksigner` and metadata inspected with `aapt`.
- At that earlier stage ADB found no devices; subsequent POCO validation is recorded below.

## Results of the movement increment

- Integration tests passed at 30, 60 and 120 physics steps per second, including ground, boundaries, going around, redirection and projected mouse event.
- Windows executable updated: graphical test with a mouse event ended with `CASTOR_GRAPHICS_OK mouse_movement_capture`, exit code 0. Screenshot inspected; copy in `builds/windows/movement.png`.
- The cube test still passes. The main scene and the APK now open the movement.
- The updated APK was exported; subsequent POCO validation is recorded below.

## 3D test assets — branch and animated model

Separate scene: `game/scenes/asset_import_test.tscn` (script `game/scripts/asset_import_test.gd`; animated model in `game/scripts/animated_test_model.gd`). It shows the placeholder character (standing still, to compare scale), the branch exported from Blender and the animated «Fox» model. Clicking the ground makes the Fox walk in a straight line to the point; when stopped it goes back to idle. The movement scene and the cube scene were not replaced.

```powershell
./tools/castor.ps1 assets          # opens the asset scene with the engine
./tools/castor.ps1 branch-export   # re-exports the branch from the .blend and reimports it in Godot
./tools/castor.ps1 check           # cube + movement + assets
./tools/castor.ps1 export-windows
```

In the exported executable it is not possible to specify another scene on the command line (the official binary refuses to replace the scene). To open the asset scene: `builds/windows/Castor.exe -- --asset-test`. For the automatic graphical verification: `builds/windows/Castor.exe -- --asset-test --capture-assets`; it saves `assets-idle.png` and `assets-walk.png` to Godot's user data folder (`%APPDATA%/Godot/app_userdata/Castor — Primeiro teste/`), confirms idle → walk → idle and ends with `CASTOR_GRAPHICS_OK assets_idle_walk_capture`.

### Changing the branch

1. Open `art/props/test_branch.blend` in Blender 5.2.3 and modify it (do not edit the `.glb` in `game/`).
2. Export: `File → Export → glTF 2.0`, format "glTF Binary (.glb)", `+Y Up` enabled, to `game/assets/props/test_branch.glb`. Or save the `.blend` and run `./tools/castor.ps1 branch-export`.
3. The Godot editor reimports when it regains focus; without the editor, `branch-export` already runs `--import`.

The script `art/props/test_branch.py` recreates the branch from scratch (`-- create`), applies the test change (`-- alter`, adds two leaves) and exports (`-- export`). Exact commands in the script header.

### Blender

Portable Blender **5.2.3 LTS**, from the official server `download.blender.org/release/Blender5.2/`, file `blender-5.2.3-windows-x64.zip`. SHA-256 `723f08a4…75dc2fb`, matching the `blender-5.2.3.sha256` published in the same folder. Extracted to `%LOCALAPPDATA%/Programs/Blender/blender-5.2.3-windows-x64/`; no installer, no changes to PATH or file associations. The `.zip` was kept in `%LOCALAPPDATA%/Programs/Blender/downloads/`. On another PC, repeat the download and the verification; the path is used by `tools/castor.ps1 branch-export`.

## Results of the 3D assets increment (Windows)

- Branch created in Blender, exported to `.glb` and imported: 1.207 × 0.116 × 0.373 m (with leaves), length along +X, base at the origin height, no transform on the node, materials `Bark`, `CutTip` and `Leaf`.
- Visible change in the source (green leaves) re-exported: the `.glb` hash changed and, after `--import`, Godot went from 2 to 3 materials; the before/after screenshot shows the leaves.
- Fox imported with `Skeleton3D` (24 bones), texture and `Survey`/`Walk`/`Run` animations. Windowless test: idle when stopped, walk while moving with bones changing pose, back to idle on arrival.
- Full `check` passed (cube, movement at 60 steps/s, assets).
- Windows executable re-exported: the asset scene passed the graphical verification (exit code 0, OpenGL 3.3 on the RTX 3060); the movement scene still passes `--capture-movement`. Screenshots in `builds/windows/assets-idle.png` and `assets-walk.png`.
- APK re-exported successfully (exit code 0); validated on the phone later, see the next section.

## Android validation results (POCO X7)

Device connected over USB and authorized: POCO X7, Android 16 / API 36, MediaTek SoC, 2712 × 1220 screen. ARM64 debug APK installed with `adb install -r`.

Verified via ADB (screenshots in `builds/android/validation/`, outside Git):

- Startup outside the editor: OpenGL ES 3.2, Compatibility renderer, Mali-G615 MC2 GPU. Full scene in landscape, with side bars because the screen is wider than 16:10.
- Simulated tap (`adb shell input tap`) on a point on the ground: destination circle and character walking.
- Simulated tap on the rock: rejected with «Escolhe um sítio livre no chão.» ("Pick a free spot on the ground."); previous destination kept.
- Asset scene opened with the marker: branch with leaves and a light tip, Fox using `Walk` while walking, credits visible. After removing the marker, the app went back to the main scene.

Verified by hand by the user, with a finger:

- Main scene: going around the rock, changing destination, invalid taps, suspend/resume via the home screen and use for about a minute — no problems («está perfeito», "it's perfect").
- Asset scene: branch and Fox visible, idle when stopped, walking to the tap and back to idle, correct colors — no problems.

Unresolved observation: in one ADB screenshot the Fox, seen from behind while walking, looked darker than on the PC. The user confirmed on the device that the colors are correct; texture compression was not investigated. Revisit if a difference appears in future textures.

Not measured: frame times, temperature and power consumption. The assessment of smoothness is visual and brief. A test with the child has not been done yet; it is not part of milestone 1.
