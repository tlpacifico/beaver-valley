# Castor — audio script and production

[Overall roadmap](roadmap.md) · [Production inventory](3d-production.md)

Status: planning, no recordings produced. Voice is part of the interaction from milestone 2; the child should not depend on reading or on live explanations from her dad.

## Deliverables

- [ ] Before the milestone 2 test, write the list of voice lines per event and choose who or what produces the placeholder voice. Recording by a family member is a simple option, not a commitment already accepted by the author.
- [ ] Record or generate replaceable local files. Do not create a dependency on an online service to play.
- [ ] Test clarity on the device speaker, volume and pronunciation; pair the voice with a visual clue.
- [ ] Ensure that repeating the help does not overlap voice lines and that changing situation cancels an outdated instruction.
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
