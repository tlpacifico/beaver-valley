# Castor — MVP roadmap

Status: milestone 1 complete. Godot 4.7.2 and GDScript retained; movement and test assets were validated on Windows and the POCO X7. The renamed Android build was reinstalled and checked on the POCO. Milestone 2 is next; priority device and origin of the final models remain open. Milestone 2 has a provisional bank, water and building marker; there is no collecting/building yet. See [how to run](how-to-run.md).

## Goal

The MVP is delivered when your 6-year-old daughter can play the beaver chapter on your PC or Android phone: build the dam, build the home and store food, seeing her actions transform the valley. She should be able to stop and continue later and want to show what she built.

The first audience is your daughter, with her dad nearby. Publishing on a store is not part of this release. The original audience of ages 6 to 10 and the two targets, Android and desktop, remain the project's vision; for this MVP we choose a priority device after trying both.

You are a .NET/C# developer with no game development experience, and open to other technologies. Learning focuses on game concepts, not programming fundamentals. Standard Godot and GDScript chosen, according to the [technical decisions](technical-decisions.md).

References: [initial idea](brainstorm-summary.md) and [review and visual direction](review-and-visual-direction.md). The hypotheses below do not turn the recommendations in those documents into approved decisions.

## How to organize the work

We will work in small playable experiments. The alternative would be to produce programming, art and sound separately; that would delay the moment your daughter can try it. A third possibility would be to build the whole chapter right away, but it would increase the rework if the controls or the collecting did not work out.

Detail the first milestones and review the following ones in light of the tests. There are no promised dates. After the first play, use the time actually spent and the weekly availability to estimate the next milestones.

## Scope

**In:** a small 3D valley, a playable beaver, the three stages, visible consequences of building, visual and voice help, small obstacles without penalties, a finishing choice, local saving and returning to the valley after the ending.

**Later:** other chapters and playable animals, stores, accounts, online services, multiplayer, monetization, fully free building, physical water simulation and a collection of mini-games. The owl and the otter can appear as support with prepared actions, without complex behavior systems.

**Hypotheses to try:** diorama with an initially fixed camera; tap/click to move and interact; assisted building; water represented by prepared visual states. These are starting points for tests, not irrevocable choices.

**Dam materials:** milestone 2 uses only three branches to test the interaction. Before starting 3a, decide whether stones and mud come in as collectible/building materials in the MVP, including the role of each. Their presence on the concept map does not confirm implementation, and their absence from the prototype does not exclude them from the MVP. They are recorded as pending candidates in the inventory, separate from the decorative stones.

**Inclusion criterion:** each additional material must have a distinct role that the child understands through the game's actions and cues, without additional explanation from the adult. Mud only as a finish is a hypothesis, not a decision. Select candidates before 3a and validate that understanding with provisional shapes during 3a; if they do not add an understandable choice, postpone them and update the inventory.

**Presentation and content:** the otter's celebration when the lake forms comes in at 3b. The water leak as a challenge and the animals' secondary requests are left for after the MVP. The `3 / 8` counter in the mockups is a visual example: it does not fix eight materials nor require a numeric counter. The way to show progress will be tested in 3a; the three branches of milestone 2 do not fix the final size of the dam either.

**Role of the otter in the MVP:** celebrate the forming of the lake. In 3b a recognizable representation in a static celebration pose or with simple code-driven movement is enough; its own rig and animations are not a condition for moving on to the chapter. Action demonstrations are a future possibility, not an obligation of this MVP. The owl keeps the help role.

## Milestones and dependencies

| Milestone | Playable result | Condition to advance | Status |
|---|---|---|---|
| [1. First steps](roadmaps/01-first-steps.md) | Simple scene opened outside the editor, on the PC and on Android. | Viable export and engine chosen based on experience. | Complete: movement and test assets validated on Windows and POCO X7; startup reproduction and next increment recorded |
| [2. First play](roadmaps/02-first-play.md) | Collect and place three branches to form a small dam. | Your daughter understands the interaction; priority device chosen. | In progress: provisional area prepared; branch interaction remains |
| [3a. Playable dam](roadmaps/03a-playable-dam.md) | Complete stage with provisional shapes, obstacles, help, personalization and saving. | She can finish and resume the dam without getting stuck before the visual production. | Not started |
| [3b. Dam with visual presentation](roadmaps/03b-visual-dam.md) | Animated beaver and stretch of the valley integrated into the validated experience. | Readable art, interactions preserved and performance observed on the device. | Not started |
| [4. Chapter](roadmaps/04-chapter.md) | Dam, home, food and ending connected by the story. | Complete path, including returning to the valley and recovering progress. | Not started |
| [5. MVP](roadmaps/05-mvp.md) | Chapter presented and adjusted for her to play on the chosen device. | Delivery criteria below verified on an installed build. | Not started |

Sequence: 1 → 2 → 3a → 3b → 4 → 5. "Milestone 3" refers to the 3a + 3b set in the vision documents. Learning, provisional voice and observation accompany the milestones; they are not isolated phases at the end. The technical path for animations is tested in milestone 1 with a test asset; the finish of the game's characters comes in after validating the play.

## 3D production across the milestones

We need 3D models usable in the engine, not just the illustrated references. Modeling, preparing materials, creating a skeleton for animation, animating, exporting and integrating are distinct tasks. The environment also needs visual construction, collisions and walkable areas.

| Track | Milestones 1–2 | Milestone 3 | Milestone 4 | Milestone 5 |
|---|---|---|---|---|
| [3D characters](roadmaps/3d-characters.md) | Provisional shapes; animated import test; choice of origin and finish. | 3a: provisional volumes. 3b: animated beaver, simple owl and otter celebration. | Add only the actions used in the rest of the story. | Fix animations, materials and visual cost. |
| [Environment and buildings](roadmaps/3d-environment.md) | Valley with simple volumes, river and three branches. | One stretch with the intended look; dam and water states. | Home, food store, rest of the valley and snow. | Improve readability, lighting and performance. |

At the end of milestone 2, validate a beaver made of simple volumes in the real camera and record who produces the art and what finish is viable. In milestone 3b, validate **an animated beaver and a small stretch of the valley in the engine**, at the real camera distance and on the chosen device, before producing the whole set. These roadmaps are tracks of the same project, not additional phases at the end. The v3 illustration guides palette, silhouette and personality; reproducing its finish is not a requirement already assumed. Low-poly is an alternative to evaluate, not a decision made.

The origin of each asset can be own creation, adaptation of an existing asset or a combination of both. Record that choice and the license in the [asset inventory](3d-production.md). Do not assume modeling experience just because there is programming experience.

## How to know if the MVP is ready

- [ ] The build opens on the chosen device without depending on the editor.
- [ ] She can move, collect and build without mandatory written instructions or continuous explanation from her dad.
- [ ] She realizes that building changes the valley and recognizes at least one choice of her own.
- [ ] She can complete the three stages, using help when she needs it.
- [ ] She can experiment and correct without losing materials or getting stuck.
- [ ] Closing and reopening recovers progress; interrupting the application does not corrupt the save.
- [ ] The story has an ending and the valley can be revisited.
- [ ] The necessary characters, environment and buildings are integrated; there are no provisional shapes that hurt the understanding of the story.
- [ ] She shows interest in continuing, coming back or showing the building; also record it if this does not happen.

A test with your daughter validates this family MVP; it does not show that the game works for the whole 6-to-10 age range.

## Practical rules

A task should produce an observable change: "the beaver reaches the branch" is better than "study navigation". Learn scenes, coordinates, collisions, pathing, animation, interface and saving when they are needed for that change.

Start with simple shapes and provisional audio. The existing drawings are 2D references, not ready-made 3D models. Do not invest yet in a full production of characters and animations.

Test first without explaining the controls, but help if there is frustration. Record what she tried, the help given and the proposed change. Never turn the test into an obligation to finish.

If the work grows, reduce variety of materials, decoration, size of the valley and number of animations before adding systems. Reducing the MVP to just a dam would be a scope change to decide with you, not a silent change.

## Decisions at the right time

| Decision | When |
|---|---|
| Engine, language and export tools | Milestone 1, consulting current official documentation |
| Camera, interaction and priority device | Milestone 2, observing your daughter |
| Dam materials: branches, stones and mud; role of the candidates | Before starting 3a; update inventory and tasks with the decision |
| Size of the dam, number of obstacles and presentation of progress | Milestone 3a; `3 / 8` is only a mockup example |
| Home and food interactions; comfortable duration | Before and during milestone 4 |
| Production of models, animations and final voice | Models/animations in 3b–4; provisional voice from 2 and finish in 5 |
| Origin of the art and viable finish | By the end of milestone 2, before the milestone 3b production |
| Script per event and origin of the provisional voice | Milestone 2, before the test with your daughter |
| Other devices or public release | After the family MVP |

Next action: begin the first scoped increment in [milestone 2](roadmaps/02-first-play.md).

External review: see [assessment and handling of the suggestions](roadmap-review.md). The adjustments preserve the three stages of the MVP and do not choose an engine, final style or art supplier.
