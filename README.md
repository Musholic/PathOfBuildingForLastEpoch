# Path of Building For Last Epoch

This is a fork of Path Of Building adapted to work for the game **Last Epoch**.

> [!WARNING]
> This is a Third Party Program, any issues or bugs a player might experience in game related to the use of this program
> are not the responsibility of EHG and EHG will not be able to assist.

The following features are supported (or partially):
* Passive tree
* Character import: for offline character and from LE tools build planner
* A lot of stats and mods/affixes are not working correctly (either not recognized or not applied correctly)
* Items: Imported from character import and can be crafted / modified
* Unique items
* Legendary items supported through LE tools import
* Basic support for following stat calculation: health, mana, armor, attributes
* Skills: Can select up to 5 skills which allows to spend points in the associated skill trees
* DPS calculation: support for several skills
* Support for ailments chance
* Support for debuffs effects (resistance shred, chill, ...)

Note that **most content (docs or code) is outdated** since they only apply to the original project. Everything should be migrated as time goes by.

## Running
The current build can be run by running `./runtime/Path of Building for Last Epoch.exe`. 

## Linux support
For linux, there may be a native support in the future but for now it runs fine with wine

## Roadmap
* Legendary items (for offline import)
* Web version
* Blessings support
* Have a selected skill dps correctly computed
* Points requirements and constraints in skills and passives
* Work on other stats (ward, ...)
* Work on other skills ...

## Features to be (possibly) automated from game files extracts
* Passive tree and skills sprites
* Any incorrect display names
* Item sprites
* Some stats formula data may be extracted
* Any missing stats on items or passives
* Skills info that would help in dps calculation

## Contribute
You can find instructions on how to contribute code and bug reports [here](CONTRIBUTING.md).

## Contributors
Special thanks for all the work made prior to this fork (and also to all future work that may be integrated in some ways) to the Path of Building Community contributors at https://github.com/PathOfBuildingCommunity/PathOfBuilding

## Changelog
You can find the full version history [here](CHANGELOG.md).

## Licence

[MIT](https://opensource.org/licenses/MIT)

For 3rd-party licences, see [LICENSE](LICENSE.md).
The licencing information is considered to be part of the documentation.
