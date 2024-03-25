import yaml
import json
import re
from natsort import natsorted


def get_value_range(tier_data, is_increased):
    min_roll = tier_data["minRoll"]
    max_roll = tier_data["maxRoll"]
    is_percentage = isinstance(min_roll, float)
    if is_percentage:
        min_roll = int(100 * min_roll)
        max_roll = int(100 * max_roll)
    value_range = "(" + str(min_roll) + "-" + str(max_roll) + ")"
    if is_percentage:
        value_range += "%"
    if is_increased:
        value_range += " increased"
    else:
        value_range = "+" + value_range
    return value_range


# Implicit properties
with open("originalAssets/MasterPropertyList.asset", "r") as yamlFile:
    data = yaml.safe_load(yamlFile)["MonoBehaviour"]

implicitModList = {}

for affixData in data["propertyInfoList"]:
    modData = {
        "value": affixData["propertyName"],
        "isPercentage": bool(affixData["displayAddedAsPercentage"])
    }
    implicitModList[str(affixData["property"])] = modData

implicitModList = dict(natsorted(implicitModList.items()))

with open("../src/Data/ImplicitModItem.json", "w") as jsonFile:
    json.dump(implicitModList, jsonFile, indent=4)

# Explicit affixes
with open("originalAssets/MasterAffixesList.asset", "r") as yamlFile:
    data = yaml.safe_load(yamlFile)["MonoBehaviour"]

with open("originalAssets/Item_Affixes Shared Data.asset", "r") as yamlFile:
    affixKeysData = yaml.safe_load(yamlFile)["MonoBehaviour"]["m_Entries"]

with open("originalAssets/Item_Affixes_en.asset", "r") as yamlFile:
    affixStringsData = yaml.safe_load(yamlFile)["MonoBehaviour"]["m_TableData"]

affixStringsById = {}
for affixStringData in affixStringsData:
    affixStringsById[affixStringData["m_Id"]] = affixStringData["m_Localized"]
affixStrings = {}
for affixKeyData in affixKeysData:
    match = re.search(r'Item_?Affix_(\d+)_Affix_([AB])', affixKeyData["m_Key"])
    if match:
        affixId = match.group(1)
        affixAB = match.group(2)
        affixStrings[affixId + "_" + affixAB] = affixStringsById[affixKeyData["m_Id"]]

modList = {}

for affixData in data["singleAffixes"]:
    for tier, tierData in enumerate(affixData["tiers"]):
        valueRange = get_value_range(tierData, affixData["modifierType"])
        affixName = affixStrings[str(affixData["affixId"]) + "_A"]
        modData = {
            "affix": affixData["affixTitle"],
            1: valueRange + " " + affixName,
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
        valueRange = get_value_range(tierData, affixData["affixProperties"][0]["modifierType"])
        affixName = affixStrings[str(affixData["affixId"]) + "_A"]
        value = valueRange + " " + affixName + "\n"
        valueRange = get_value_range(tierData["extraRolls"][0], affixData["affixProperties"][0]["modifierType"])
        affixName = affixStrings[str(affixData["affixId"]) + "_B"]
        value += valueRange + " " + affixName
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
