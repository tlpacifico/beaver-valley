# Agent guide — Castor

Castor is a small 3D game for the author's 6-year-old daughter: a beaver in a small valley builds a dam, a lodge and a winter food store. It is a family MVP, not a commercial release. The author is a .NET/C# developer learning game development.

## Language

- **English** for everything developers read: code, identifiers, comments, commit messages, file and folder names, test messages, logs, scripts and documentation.
- **European Portuguese** for everything the child sees or hears: on-screen text, the application name, voice lines, in-game credits shown on screen and text inside mockup images. Keep these strings in Portuguese even when the surrounding code is English.
- Conversation with the author may be in Portuguese; that does not change the rules above.

## Layout

| Path | Contents |
|---|---|
| `docs/castor/` | Vision, roadmap, plans, decisions, progress and how-to-run. Start with `roadmap.md` and `startup-plan.md`. |
| `docs/castor/roadmaps/` | One file per milestone (1, 2, 3a, 3b, 4, 5) plus the 3D characters and environment tracks. |
| `docs/castor/mockups/` | 2D concept studies and their generator scripts. Not implementation specs. |
| `game/` | Godot 4.7.2 project (typed GDScript, Compatibility renderer). |
| `art/` | Editable art sources (`.blend`, third-party originals and licenses). Never edit only the exported file in `game/`. |
| `tools/castor.ps1` | Run, test, export and asset commands. |
| `builds/` | Generated builds and captures; ignored by Git. |

`docs/cantar/` (if present locally) belongs to a different project, is ignored by Git and is out of scope.

## Commands (PowerShell, repository root)

```powershell
./tools/castor.ps1 run              # main scene
./tools/castor.ps1 assets           # 3D asset test scene
./tools/castor.ps1 check            # cube smoke test + movement + asset tests
./tools/castor.ps1 export-windows
./tools/castor.ps1 export-android
./tools/castor.ps1 branch-export    # re-export the test branch from Blender and reimport
```

Details, tool locations and device steps: `docs/castor/how-to-run.md`.

## Working rules

- Keep each change small and verifiable; record results and open items in `docs/castor/startup-progress.md` (or the current milestone's progress notes).
- Do not mark Android or a milestone as validated without running it on the real device.
- Do not change global tools or settings used by other projects (for example `JAVA_HOME`, global SDK updates).
- Record origin, author, licence and attribution for every third-party asset in `docs/castor/3d-production.md`.
- Commit only when the author asks.
