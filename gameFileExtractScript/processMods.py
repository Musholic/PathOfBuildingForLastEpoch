import yaml
import json
import re
from natsort import natsorted

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
    match = re.search(r'Item_Affix_(\d+)_DisplayName', affixKeyData["m_Key"])
    if match:
        affixId = match.group(1)
        affixStrings[affixId] = affixStringsById[affixKeyData["m_Id"]]

modList = {}

for affixData in data["singleAffixes"]:
    for tier, tierData in enumerate(affixData["tiers"]):
        minRoll = tierData["minRoll"]
        maxRoll = tierData["maxRoll"]
        isPercentage = isinstance(minRoll, float)
        if isPercentage:
            minRoll = int(100 * minRoll)
            maxRoll = int(100 * maxRoll)
        valueRange = "+(" + str(minRoll) + "-" + str(maxRoll) + ")"
        if isPercentage:
            valueRange += "%"
        affixName = affixStrings[str(affixData["affixId"])]
        modData = {
            "affix": affixData["affixTitle"],
            "value": valueRange + " " + affixName,
            "level": affixData["levelRequirement"]
        }
        if affixData["rollsOn"]:
            modData["type"] = "Prefix"
        else:
            modData["type"] = "Suffix"
        modList[str(affixData["affixId"]) + "_" + str(tier)] = modData

modList = dict(natsorted(modList.items()))

with open("../src/Data/ModItem.json", "w") as jsonFile:
    json.dump(modList, jsonFile, indent=4)

print("item mods processed with success")
