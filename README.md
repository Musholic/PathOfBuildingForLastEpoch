# Path of Building Community Fork *For Last Epoch*

This is a fork of Path Of Building adapted to work for the game Last Epoch. The following features are supported (or partially):
* Passive tree: stats are displayed but most of them have no effect (or not the intended one)
* Character import: for offline character
* Items: Imported from character import (not all stats have effect)

Note that **most content (docs or code) is outdated** since they only apply to the original project. Everything should be migrated as time goes by.

## Running
The current build can be run by running `./runtime/Path{space}of{space}Building.exe`. 

## Roadmap
* Have total health correctly computed from imported passives and items (including idols)
* Add online character import
* Add skills passives
* Have a selected skill dps correctly computed
* Work on other stats (ward, ...)
* Work on other skills ...

## Features to be (possibly) automated from game files extracts
* Passive tree and skills sprites and relative positions
* Any incorrect display names
* Item sprites
* Some stats formula data may be extracted
* Any missing stats on items or passives

## Contribute
You can find instructions on how to contribute code and bug reports [here](CONTRIBUTING.md).

## Changelog
You can find the full version history [here](CHANGELOG.md).

## Licence

[MIT](https://opensource.org/licenses/MIT)

For 3rd-party licences, see [LICENSE](LICENSE.md).
The licencing information is considered to be part of the documentation.
