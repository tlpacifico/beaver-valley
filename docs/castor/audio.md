# Castor — audio script and production

[Overall roadmap](roadmap.md) · [Production inventory](3d-production.md)

Status: milestones 2, 3a and the milestone 4 home, food and ending lines are generated as local WAV files from the Piper `pt_PT-tugão-medium` model. Playback is integrated; the lines still need pronunciation, volume and visual-pairing checks on the PC and real Android device before the child's test.

## Deliverables

- [x] Before the milestone 2 test, write the list of voice lines per event and choose a verifiable `pt-PT` voice source.
- [x] Generate replaceable local files. Do not create a dependency on an online service to play.
- [ ] Test clarity on the device speaker, volume and pronunciation; pair the voice with a visual clue.
- [x] Ensure that repeating the help does not overlap voice lines and that changing situation cancels an outdated instruction.
- [x] Add provisional lines and generated clips for the milestone 3a branch obstacles and home invitation.
- [ ] Connect the new event IDs to playback and listen for clarity, volume and timing before the child test.
- [ ] Finalize recordings and mixing in milestone 5, without delaying the first use of the voice until then.

## Proposed initial script

| Identifier | Event | Initial line to try (Portuguese, as heard) | English gloss | Visual clue |
|---|---|---|---|---|
| dam_start | Entering the play | Vamos ajudar o castor a construir uma represa! | Let's help the beaver build a dam! | Branch and building zone visible |
| help_collect | Help request with no material | Escolhe um ramo para levar. | Pick a branch to carry. | Outline on the reachable branch |
| help_place | Help request while carrying | Agora leva o ramo até à represa. | Now take the branch to the dam. | Destination highlighted |
| first_placement | First piece placed | Olha, a água está a mudar! | Look, the water is changing! | Visible change in the water |
| dam_completed | Last piece | Fizeste uma represa! | You made a dam! | View of the build and lake |

These are provisional lines, not final recordings. Milestone 3a adds lines for the defined branch obstacles and home invitation:

| Identifier | Event | Initial line to try (Portuguese, as heard) | English gloss | Visual clue |
|---|---|---|---|---|
| thick_branch | Thick branch collected | Este ramo é grosso. Podes roê-lo ou escolher outro. | This branch is thick. You can gnaw it or choose another. | Gnaw action and other branches are visible |
| rotten_branch | Rotten branch collected | O ramo podre dobrou! Vamos escolher outro. | The rotten branch bent! Let's choose another. | Bent branch remains visible in the beaver's paws |
| help_compatible | Second incompatible placement attempt | Escolhe o ramo verde para a represa. | Choose the green branch for the dam. | Suitable branch ring highlighted green |
| home_invite | Dam completed | Agora vamos construir a casa! | Now let's build the house! | Completed dam and home invitation |
| help_home_collect | Home help with no part | Escolhe uma peça para a casa. | Choose a part for the house. | Loose home parts highlighted |
| help_home_place | Home help while carrying a part | Leva a peça até à casa. | Take the part to the house. | Free lodge position highlighted |

Milestone 4 adds the food-store lines:

| Identifier | Event | Initial line to try (Portuguese, as heard) | English gloss | Visual clue |
|---|---|---|---|---|
| food_invite | Home completed | Agora vamos guardar comida para o inverno! | Now let's store food for the winter! | Bundles on the bank and target in the water |
| help_food_collect | Help without a bundle | Escolhe um feixe de ramos para guardar. | Choose a bundle of branches to store. | Suitable bundles highlighted |
| help_food_place | Help while carrying a suitable bundle | Leva o feixe até à água. | Take the bundle to the water. | Water target highlighted |
| food_unsuitable | Thin bundle refused | Este feixe é pequeno. Escolhe outro. | This bundle is small. Choose another. | Suitable bundles highlighted |
| food_complete | Third bundle stored | A comida está guardada! | The food is stored! | Pile visible in the water |
| winter_arrived | Chapter complete | O inverno chegou! A família do castor está reunida. | Winter has arrived! The beaver family is together. | Snow, family and winter valley |

## Inventory

| Category | Initial content | When |
|---|---|---|
| Voice lines | Instructions, obstacle help, reactions and story | Placeholder in 2; 3a script expanded; add stage 4 lines later |
| Effects | Collect, place, gnaw and build completed | Simple responses in 2; complete in 3b/4 |
| Ambience | River and nature, at a volume that does not drown out the voice lines | Try in 3b |

Keep voice and sound sources in `audio/source/` when they exist and import the playback files into `game/`. Record origin, author/performer, applicable license/permission, event and imported file. Music is not required in the MVP.

## Provisional voice source and event playback

- Model: [`pt/pt_PT/tugão/medium`](https://huggingface.co/rhasspy/piper-voices/tree/main/pt/pt_PT/tug%C3%A3o/medium), voice identifier `pt_PT-tugão-medium`, one speaker, medium quality, 22,050 Hz. The model card identifies Portuguese (Portugal), and the config identifies `pt_PT`.
- Dataset: [`Nabu Casa Voice Datasets`](https://github.com/OHF-Voice/voice-datasets), voice label `tugão`, collected for Home Assistant's Year of Voice; the repository states that these datasets are CC0. The model card points to this dataset and states CC0. The public catalog does not name an individual performer, so none is attributed here.
- License notes: Hugging Face labels the overall `rhasspy/piper-voices` repository MIT, while the individual model card describes the source dataset as CC0; it does not separately state a license for generated recordings. Piper 1.3.0 is GPL-3.0-or-later and was used only as a local offline authoring tool, not bundled into the game. Keep these clips within the family prototype unless redistribution rights for the model output are clarified.
- Local authoring environment: Piper 1.3.0 in an isolated Python 3.11 venv under `%LOCALAPPDATA%/Castor/piper-tts-1.3.0`; the ONNX model and JSON config are kept there, outside the repository. The downloader could not encode the accented voice name, so model and config were fetched from the model's direct Hugging Face URLs. Model SHA-256 `223a7aaca69a155c61897e8ada7c3b13bc306e16c72dbb9c2fed733e2b0927d4`; model and config MD5 digests match `voices.json`: `0642048511ffe36c3b519520614b53f4` and `c4113a1da477aa6db28420454c142ebd`.
- Regeneration script: `tools/generate-provisional-voice.py`; it loads the local ONNX file once and writes one WAV per event to `game/audio/voice/`. The game only loads these WAV files; it has no TTS runtime or network dependency.
- Regenerate on the authoring PC with PowerShell: `& "$env:LOCALAPPDATA\Castor\piper-tts-1.3.0\venv\Scripts\python.exe" tools/generate-provisional-voice.py --model "$env:LOCALAPPDATA\Castor\piper-tts-1.3.0\voices\pt_PT-tugão-medium.onnx" --output-dir game/audio/voice`. The new WAV files have Godot `.import` sidecars; run the editor import scan after regeneration when adding new event files.
- Event integration: `dam_start` plays on scene entry; `help_collect` plays when the dam is selected without a carried branch; `help_place` plays after pickup; `first_placement` plays on the first placed branch; `dam_completed` plays on the last branch. The 3a audio IDs `thick_branch`, `rotten_branch` and `help_compatible` are connected to their respective obstacle and help events. `home_invite` plays after `dam_completed` finishes so the lines do not overlap. The home IDs `help_home_collect` and `help_home_place` direct the child to the lodge parts and free lodge position. The milestone 4 food IDs `food_invite`, `help_food_collect`, `help_food_place`, `food_unsuitable` and `food_complete` are connected to the food stage. `winter_arrived` plays when the ending overlay opens, not when a completed chapter is reopened. One `AudioStreamPlayer` serializes clips. Repeating the same event while it plays is ignored; after it finishes it can be requested again. A new event stops the old clip, and changing to valid movement, pickup or placement cancels outdated speech.
- Listening checks remain open: check pronunciation, volume and timing against the visual cue on the PC and POCO X7 before the child play session.

## Provisional sound effects

Four original procedural WAVs (`collect`, `gnaw`, `place`, `complete`) are generated deterministically by `tools/generate-provisional-sfx.py` into `game/audio/effects/`. They are project-authored, with no third-party sample or external license. A separate SFX player at -10 dB allows effects and voice to play concurrently. The final balance and clarity still need listening on the PC and real Android device.
