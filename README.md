# Castor

A small 3D game being made for a 6-year-old: a beaver explores a little valley, builds a dam, a lodge and a store of food for winter. It is a family project and a way for a .NET developer to learn game development, not a commercial release.

The game's on-screen text and voice are in European Portuguese; code and documentation are in English.

## Status

Milestone 1 (first steps) is in progress: a Godot 4.7.2 project with a placeholder beaver that walks where you click or tap, plus technical tests for importing a Blender-made prop and an animated third-party model. Tested on Windows and on an Android phone. There is no dam, collecting or final art yet.

See [`docs/castor/roadmap.md`](docs/castor/roadmap.md) for the plan and [`docs/castor/startup-progress.md`](docs/castor/startup-progress.md) for what has been done.

## Running it

Requires [Godot 4.7.2](https://godotengine.org/) (standard build). On Windows, from the repository root:

```powershell
./tools/castor.ps1 run      # main scene
./tools/castor.ps1 check    # automated tests
```

Tool locations, exports (Windows and Android) and Blender steps are in [`docs/castor/how-to-run.md`](docs/castor/how-to-run.md). Guidance for coding agents is in [`AGENTS.md`](AGENTS.md).

## Third-party assets

The animated test model "Fox" comes from the [Khronos glTF Sample Assets](https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/Fox) (CC0 and CC BY 4.0); attribution is in [`game/ASSET-CREDITS.txt`](game/ASSET-CREDITS.txt). Godot's license is in [`game/LICENSE-Godot.txt`](game/LICENSE-Godot.txt).

No license has been chosen yet for the project's own code and art.
