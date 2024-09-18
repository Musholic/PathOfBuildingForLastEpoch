import json
from natsort import natsorted
from common import *

construct_mod_data_list()


data = load_yaml_file_with_tag_error(monoPath + "AffixList/MasterAffixesList.asset")["MonoBehaviour"]

modList = {}

for affixData in data["singleAffixes"]:
    for tier, tierData in enumerate(affixData["tiers"]):
        affixData["value"] = tierData["minRoll"]
        affixData["maxValue"] = tierData["maxRoll"]
        modData = {
            "affix": affixData["affixTitle"],
            1: get_mod_value(affixData),
            "level": affixData["levelRequirement"],
            "statOrderKey": affixData["affixId"],
            "statOrder": [affixData["affixId"]],
            "tier": tier
        }
        if affixData["type"]:
            modData["type"] = "Prefix"
        else:
            modData["type"] = "Suffix"
        modList[str(affixData["affixId"]) + "_" + str(tier)] = modData

for affixData in data["multiAffixes"]:
    for tier, tierData in enumerate(affixData["tiers"]):
        affixData["affixProperties"][0]["value"] = tierData["minRoll"]
        affixData["affixProperties"][0]["maxValue"] = tierData["maxRoll"]
        value = get_mod_value(affixData["affixProperties"][0]) + "\n"
        affixData["affixProperties"][1]["value"] = tierData["extraRolls"][0]["minRoll"]
        affixData["affixProperties"][1]["maxValue"] = tierData["extraRolls"][0]["maxRoll"]
        value += get_mod_value(affixData["affixProperties"][1])
        modData = {
            "affix": affixData["affixTitle"],
            1: value,
            "level": affixData["levelRequirement"],
            "statOrderKey": affixData["affixId"],
            "statOrder": [affixData["affixId"]],
            "tier": tier
        }
        if affixData["type"]:
            modData["type"] = "Prefix"
        else:
            modData["type"] = "Suffix"
        modList[str(affixData["affixId"]) + "_" + str(tier)] = modData

modList = dict(natsorted(modList.items()))

with open("../src/Data/ModItem.json", "w") as jsonFile:
    json.dump(modList, jsonFile, indent=4)

print("item mods processed with success")
