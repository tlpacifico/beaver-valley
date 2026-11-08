# Castor — audio script and production

[Overall roadmap](roadmap.md) · [Production inventory](3d-production.md)

Status: milestone 2 provisional voice is generated as local WAV files from the Piper `pt_PT-tugão-medium` model. Event playback is integrated; pronunciation, volume and visual pairing still need listening checks on the PC and real Android device before the child's test.

## Deliverables

- [x] Before the milestone 2 test, write the list of voice lines per event and choose a verifiable `pt-PT` voice source.
- [x] Generate replaceable local files. Do not create a dependency on an online service to play.
- [ ] Test clarity on the device speaker, volume and pronunciation; pair the voice with a visual clue.
- [x] Ensure that repeating the help does not overlap voice lines and that changing situation cancels an outdated instruction.
- [ ] Expand the script in milestones 3a and 4, before their respective tests.
- [ ] Finalize recordings and mixing in milestone 5, without delaying the first use of the voice until then.

## Proposed initial script

| Identifier | Event | Initial line to try (Portuguese, as heard) | English gloss | Visual clue |
|---|---|---|---|---|
| dam_start | Entering the play | Vamos ajudar o castor a construir uma represa! | Let's help the beaver build a dam! | Branch and building zone visible |
| help_collect | Help request with no material | Escolhe um galho para levar. | Pick a branch to carry. | Outline on the reachable branch |
| help_place | Help request while carrying | Agora leva o galho até à represa. | Now take the branch to the dam. | Destination highlighted |
| first_placement | First piece placed | Olha, a água está a mudar! | Look, the water is changing! | Visible change in the water |
| dam_completed | Last piece | Fizeste uma represa! | You made a dam! | View of the build and lake |

These lines are proposals to test, not final text. Add lines for obstacles and transitions when the corresponding rules are defined.

## Inventory

| Category | Initial content | When |
|---|---|---|
| Voice lines | Instructions, help, reactions and story | Placeholder in 2; expand in 3a/4 |
| Effects | Collect, place, gnaw and build completed | Simple responses in 2; complete in 3b/4 |
| Ambience | River and nature, at a volume that does not drown out the voice lines | Try in 3b |

Keep voice and sound sources in `audio/source/` when they exist and import the playback files into `game/`. Record origin, author/performer, applicable license/permission, event and imported file. Music is not required in the MVP.

## Provisional voice source and event playback

- Model: [`pt/pt_PT/tugão/medium`](https://huggingface.co/rhasspy/piper-voices/tree/main/pt/pt_PT/tug%C3%A3o/medium), voice identifier `pt_PT-tugão-medium`, one speaker, medium quality, 22,050 Hz. The model card identifies Portuguese (Portugal), and the config identifies `pt_PT`.
- Dataset: [`Nabu Casa Voice Datasets`](https://github.com/OHF-Voice/voice-datasets), voice label `tugão`, collected for Home Assistant's Year of Voice; the repository states that these datasets are CC0. The model card points to this dataset and states CC0. The public catalog does not name an individual performer, so none is attributed here.
- License notes: Hugging Face labels the overall `rhasspy/piper-voices` repository MIT, while the individual model card describes the source dataset as CC0; it does not separately state a license for generated recordings. Piper 1.3.0 is GPL-3.0-or-later and was used only as a local offline authoring tool, not bundled into the game. Keep these clips within the family prototype unless redistribution rights for the model output are clarified.
- Local authoring environment: Piper 1.3.0 in an isolated Python 3.11 venv under `%LOCALAPPDATA%/Castor/piper-tts-1.3.0`; the ONNX model and JSON config are kept there, outside the repository. The downloader could not encode the accented voice name, so model and config were fetched from the model's direct Hugging Face URLs. Model SHA-256 `223a7aaca69a155c61897e8ada7c3b13bc306e16c72dbb9c2fed733e2b0927d4`; model and config MD5 digests match `voices.json`: `0642048511ffe36c3b519520614b53f4` and `c4113a1da477aa6db28420454c142ebd`.
- Regeneration script: `tools/generate-provisional-voice.py`; it loads the local ONNX file once and writes one WAV per event to `game/audio/voice/`. The game only loads these WAV files; it has no TTS runtime or network dependency.
- Event integration: `dam_start` plays on scene entry; `help_collect` plays when the dam is selected without a carried branch; `help_place` plays after pickup; `first_placement` plays on the first placed branch; `dam_completed` plays on the last branch. One `AudioStreamPlayer` serializes clips. Repeating the same event while it plays is ignored; after it finishes it can be requested again. A new event stops the old clip, and changing to valid movement, pickup or placement cancels outdated speech. The final completion cue replaces any earlier line.
- Listening checks remain open: check pronunciation, volume and timing against the visual cue on the PC and POCO X7 before the child play session.
