# Changelog

## [v0.2.0](https://github.com/Musholic/PathOfBuildingForLastEpoch/tree/v0.2.0) (2024/04/09)

[Full Changelog](https://github.com/Musholic/PathOfBuildingForLastEpoch/compare/v0.1.0...v0.2.0)

## What's Changed
This release introduces DPS calculation. It takes into account a large variety of skills, but it does not support yet a lot of mods.

So do not expect passives in the skill tree to have the intended effect for example. What is probably working is mods like "+x melee physical damage" or "x% increased fire damage"

* Basic DPS calculation support for several skills
* Fixed several mods from imported data (display value)
* A bit of cleaning (removing some irrelevant files)
* A few minor fixes (save/load fix, display of damage types in breakdown,...)

## [v0.1.0](https://github.com/Musholic/PathOfBuildingForLastEpoch/tree/v0.1.0) (2024/04/02)
First release, it started as a fork of [Path of Building](https://github.com/PathOfBuildingCommunity/PathOfBuilding) which is slowly adapted to Last Epoch so most content is not yet relevant to the game.

The following features are supported (or partially):
* Passive tree
* Character import: for offline character and from LE tools build planner
* Most stats and mods/affixes are not working correctly (either not recognized or not applied correctly)
* Items: Imported from character import and can be crafted / modified
* Unique items (no support for legendary yet)
* Basic support for following stat calculation: health, mana, armor, attributes
* Skills: Can select up to 5 skills which allows to spend points in the associated skill trees

Note that online character import is not directly available, but you can import from Last Epoch Tools build planner (which can do online character import). 
