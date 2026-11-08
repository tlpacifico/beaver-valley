# Castor — engine comparison

Consulted: November 8, 2026. Scope: Godot/GDScript, Godot/C# and Unity/C# for the family MVP. This is a documentation comparison, not an executed test nor a choice already confirmed by the user.

**Later update:** the user accepted the recommendation; standard Godot 4.7.2 prepared. The comparison below preserves the reasoning prior to the choice. The tests and the current status are in [how to run](how-to-run.md) and [technical decisions](technical-decisions.md).

## Recommendation

**First candidate: Godot with typed GDScript. Alternative: Unity with C#.** Godot/C# comes third for this project due to the documented experimental Android support.

This ranking is an assessment for Castor: small valley, simple interaction, state-based water, solo development and a wish to learn other technologies. The priority is to get early to a play session on the real device, keeping few dependencies. Knowledge of C# favors Unity, but does not remove the need to learn scenes, components, movement, animation and export. A technology standard from other projects was not applied to override this openness of the user.

## Comparison

| Criterion | Godot + GDScript | Godot + C# | Unity + C# |
|---|---|---|---|
| Learning | New language; direct integration with the editor. I propose explicit types. | Familiar language, but new API and scene model. | Familiar language, but new components, editor and APIs. |
| Android | Normal documented export path. | Supported, with an official warning that it is experimental. | Documented support with the Android Build Support module. |
| Initial dependencies | Standard editor, export templates and Android tools. | .NET editor, compatible .NET SDK and Android tools. | Editor/installation through the Hub and the corresponding Android modules/dependencies. |
| Models and animations | 3D import; glTF/GLB recommended by the documentation. | Same visual system and importer as Godot; C# does not by itself improve the art. | Importer with configuration of models, rigs, animations and materials. |
| License | MIT; include license notices when distributing the engine with the game. | The same license as Godot. | Unity Personal free under the current eligibility criteria. |
| Main cost for you | Learning GDScript and the engine concepts. | Investigating possible Android problems on top of learning the engine. | Learning the editor's organization and managing the installation and modules, even knowing C#. |
| Proposed role | First cube test and, if it passes, prototype. | Reconsider if there is a concrete reason to use .NET in Godot. | Alternative if the initial Godot path fails or the C# workflow turns out to be a priority. |

Godot recommends GDScript for those starting out because of its design and integration with the engine; static typing can also be used. The recommendation here takes into account that you already know how to program, although game concepts are new. [Godot languages](https://docs.godotengine.org/en/stable/getting_started/step_by_step/scripting_languages.html).

The standard Godot editor does not include C#: the .NET edition is required. Android support for C# projects is still identified as experimental on the page consulted. This does not mean it does not work, but it adds uncertainty precisely on an important target for Castor. [Godot C#/.NET](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/index.html).

## Fit with your hardware

The [local inventory](technical-decisions.md) shows an i7-12700H, about 32 GB of RAM and an RTX 3060 Laptop with 6 GB. There is no reason, in the data collected, to exclude a candidate before testing. The 66.6 GiB free justify installing only the chosen candidate and the necessary modules, without keeping three experimental environments in parallel. I did not measure the final size of any installation.

The POCO X7 shows Android 16, but has not been connected/tested yet. A recent Android version does not prove graphics compatibility, smoothness or absence of driver problems. All options need the test on the device.

### Making use of the existing Android tools

**Godot:** the documentation consulted recommends JDK 17 and lists specific versions of the Android packages. Java 17, platform API 35 and platform-tools 36 already exist. The page asks for build-tools 35.0.1, which did not appear in the inventory; having 35.0.0 or 36.0.0 does not prove that they replace that dependency. NDK/CMake exist as folders, but their versions have not been checked yet. Confirm everything against the exact editor version before installing whatever is missing. [Godot Android export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html).

**Unity:** needs Android Build Support, SDK, NDK and JDK. I propose using the dependencies matching the editor version, installed through the Hub, instead of assuming that the existing global SDKs will do. This may duplicate tools and consume additional space, without being an obstacle in itself. [Unity 6.3 Android setup](https://docs.unity.com/en-us/engine/6000.3/manual/platform-specific/android/getting-started/sdksetup).

## 3D production and presentation

Godot recommends glTF 2.0 and supports `.glb`; direct `.blend` import depends on Blender being installed. For the experiment, I propose a separate art source and an exported file in the game. [Godot 3D formats](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html).

Unity provides import of models, skeletons, animations and materials, including settings for non-humanoid characters. This covers the need to test an animated character, but does not automatically provide the beaver. [Unity model import](https://docs.unity.com/en-us/engine/6000.0/manual/assets-and-media/asset-types/models/importing/class-fbximporter).

**Inference for the project:** both engines offer a plausible path for the MVP art; the risk of producing the models remains in both. I did not evaluate specific commercial packages nor assume that any contains characters compatible with the v3 direction.

For the first Godot test, I propose starting with Compatibility, suited to desktop/mobile hardware with modest graphics requirements. Mobile is an alternative to measure if the visual needs justify it. Do not choose Forward+ just because the PC has an RTX. This initial choice favors simplicity of requirements; it does not claim that Compatibility will be faster on the POCO. [Godot renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html).

## Costs and license

Godot is free software under MIT; the game can have its own license and must include the applicable engine notices. [Godot license](https://godotengine.org/license/).

Unity Personal is free within the published financial criteria, with a threshold of USD 200 thousand; the former Runtime Fee was canceled. A non-commercial family project points to Personal, but eligibility must be confirmed when activating the license. There is no reason to buy Pro to run this test based on the requirements described. [Unity terms and pricing](https://unity.com/products/pricing-updates).

## Execution proposal after the choice

1. Pin a stable version of standard Godot and templates of the same version, consulting the official distribution page at installation time. Do not infer the version number from `stable` URLs; do not use pre-releases.
2. Confirm the Android dependencies required by that version and install only the missing ones, preserving the SDKs of other projects.
3. Create the cube in typed GDScript and Compatibility, export to Windows and produce a test APK for the POCO X7.
4. Check execution outside the editor, image, basic interaction and suspend/resume. Without a device connected/authorized, mark Android pending.
5. Proceed to movement and static/animated import only after validating the export base.

**Proposed effort limit:** two hours of active investigation of an export failure, excluding downloads and waiting for the device. When that limit is reached, record the error and reassess. Cable problems, USB authorization or missing packages do not demonstrate an engine limitation. Faced with a reproducible engine blocker after checking requirements, evaluate Unity/C# with a maintained LTS version, without converting the whole game nor keeping two implementations.

## What this comparison does not decide

The engine was not installed nor approved by a real export. The exact version, the priority device, the modeling tool, the finish and the origin of the art remain subject to the roadmap's decisions and tests. The GDScript recommendation is reversible at this stage; changing after producing the chapter would have a higher cost.
