# PobfleExtractor

This is a melon loader mod to extract all the game data required by this tool.

> [!WARNING]
> This is a Third Party Program, any issues or bugs a player might experience in game related to the use of this program
> are not the responsibility of EHG and EHG will not be able to assist.

## How to build and run

First you need to install melon loader **v0.7.0 Beta**, the simplest is to use the automated
installer (https://melonwiki.xyz/#/?id=automated-installation).

You also need to start the game once to let melon loader generated all the dlls for the project.

You don't need Unity to build the mod, the generated dlls are enough.

The .csproj file can be opened either with Visual Studio or with Jetbrains Rider.

Building the project will automatically copy the mod dll to
`C:\Program Files (x86)\Steam\steamapps\common\Last Epoch\Mods`

Then you can run the game to use the mod (in pure offline mode is fine, with the argument `--offline`).

> [!NOTE]
> The mod expect the working directory to be the root of this project (PathOfBuildingForLastEpoch) which is done
> automatically with the Rider run configuration in `./run`

## How to debug with the IDE

Debug support with the IDE (Rider or Visual Studio) is possible by adding the argument `--melonloader.debug`. Then you
can attach to the process. (c.f. https://melonwiki.xyz/#/modders/debugging?id=using-an-ide-to-debug-il2cpp-games)

You may also use the Rider run configuration in `./.run/`

## BepInEx vs MelonLoader

Both works fine, (at least with latest bleeding edge builds of BepInEx), but only Melon Loader has easy debugger
integration with the IDE.