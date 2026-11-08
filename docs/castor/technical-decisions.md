# Castor — hardware and technical decisions

## Status

Initial inventory collected on the PC and from the image provided by the user. Documentation comparison complete: [engine comparison](engine-comparison.md). The user confirmed Godot/GDScript. Standard Godot 4.7.2-stable prepared with typed GDScript and Compatibility; Windows executable tested; APK installed and validated on the POCO X7 on 8/11/2026 (tap via ADB and by hand, suspend/resume). See [instructions and results](how-to-run.md).

**Decision after milestone 1:** keep standard Godot 4.7.2, typed GDScript and Compatibility for milestone 2. Exports, movement and static/animated imports have been exercised on both target devices; revisit the choice if later tests expose a concrete limitation. The renamed APK was subsequently reinstalled and checked on the POCO; see the progress notes for the scope.

## Development PC — observed locally

| Component | Result |
|---|---|
| System | Windows 11 Enterprise, 64-bit, version 10.0.26300, build 26300 |
| Processor | Intel Core i7-12700H, 14 cores and 20 logical processors |
| Memory | 31.7 GiB reported by the system |
| Dedicated GPU | NVIDIA GeForce RTX 3060 Laptop GPU, 6144 MiB of graphics memory |
| Integrated GPU | Intel Iris Xe Graphics |
| Project volume | C:, 946.8 GiB total, 66.6 GiB free at the time of inspection |

Sources: Windows CIM and name/memory query through `nvidia-smi`. Do not assume that the editor automatically uses the dedicated GPU; check during the first test.

## Tools found

- Git available on the PATH.
- .NET SDKs present: 5.0.408; 8.0.100-rc.2.23502.2; 8.0.206; 8.0.427; 9.0.123; 9.0.315; 10.0.204; 10.0.401; 11.0.100-rc.3.26522.148. No SDK was selected for the game.
- Visual Studio Community 2022 and 2026, including an Insiders installation, registered on the system.
- Android Studio 2025.1 registered on the system.
- JDK on the PATH: Eclipse Temurin OpenJDK 17.0.17.
- Android SDK in the user's local folder; installed platforms: API 30, 31, 33, 34, 35 and 36.
- Android build-tools: 30.0.2, 30.0.3, 33.0.1, 34.0.0, 35.0.0 and 36.0.0.
- ADB 1.0.41, platform-tools 36.0.0; cmdline-tools in a `latest` folder (exact version not inspected).
- Godot, Unity and Blender not found on the PATH, in the standard locations consulted or among the registered application names. This does not rule out portable versions or installations in other folders.

The existence of these tools does not prove compatibility with the engine version to be chosen. Confirm official requirements before configuring the export; do not replace the SDKs used by other projects without need.

## Phone — image provided by the user

| Field | Value shown |
|---|---|
| Device name shown | POCO X7 |
| Android | 16 (API 36) |
| Hardware (from ADB) | MediaTek SoC, Mali-G615 MC2 GPU, arm64-v8a, 2712 × 1220 screen |

Build number, OS version string, storage and security patch date were recorded locally but left out of the public documentation.

The image does not report RAM, processor/GPU, USB debugging or ADB authorization. No connected device was queried and debugging was not enabled. The name shown on the page does not replace confirmation of the model's technical identifier, if needed to diagnose incompatibilities.

## Next decisions and checks

- [x] Compare Godot/GDScript, Godot/C# and Unity/C# with current official documentation: see [result and sources](engine-comparison.md).
- [x] Choose candidate engine, version, language and effort limit: standard Godot 4.7.2, typed GDScript, two hours of active investigation of export failures (excluding downloads/waiting for the device).
- [ ] Check the space required by the chosen installation and by the generated files; there are 66.6 GiB free at inspection, not the full volume available.
- [x] Check connection and authorization of the POCO X7: connected over USB, `adb devices` with state `device`.
- [x] Run outside the editor on the PC and on the phone: cube and movement on Windows; movement scene and asset scene on the POCO X7 (the current APK opens the movement, not the cube).
- [ ] Collect weekly availability and art origin for later estimates.

Initial assessment: the PC has adequate resources to start a small 3D prototype. Validation of the engine, the export and the performance on the devices still depends on the planned tests.

## Changes after the initial inventory

Movement increment authorized while the phone is unavailable: main scene with CharacterBody3D, AStarGrid2D pathfinding on the XZ plane and fixed camera. Navigation and mouse events tested on Windows; Android remains pending. A 1-meter grid and movement without diagonals are prototype choices, not requirements of the final valley.

Official editor and templates installed in the user's local folders, with SHA-512 verified. Build-tools 35.0.1 added to the Android SDK; the exporter used 36.0.0. Godot preferences configured for the existing SDK and Java 17. The global JAVA_HOME variable was not changed. ADB queried, no device detected. The tool details above describe the initial inspection, not the current absence of Godot.

## Modeling tool — milestone 1, task 3

Blender 5.2.3 LTS (portable, official source, SHA-256 verified) for the test branch; binary glTF export (`.glb`), recommended by the Godot documentation. Direct `.blend` import in Godot was not used: exporting to `.glb` keeps the game project independent of the installed Blender. Conventions in [3D production](3d-production.md). The animated test model is third-party (Khronos «Fox»); it does not decide the origin or the style of the final art, which remain undecided until the end of milestone 2.
