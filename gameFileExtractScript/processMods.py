import yaml
import json
from natsort import natsorted

with open("originalAssets/MasterAffixesList.asset", "r") as yamlFile:
    data = yaml.safe_load(yamlFile)["MonoBehaviour"]

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
        modData = {
            "affix": affixData["affixTitle"],
            "value": valueRange + " " + affixData["affixName"]
        }
        if affixData["rollsOn"]:
            modData["type"] = "Prefix"
        else:
            modData["type"] = "Suffix"
        modList[str(affixData["affixId"]) + "_" + str(tier)] = modData

modList = dict(natsorted(modList.items()))

with open("../src/Data/ModItem.json", "w") as jsonFile:
    json.dump(modList, jsonFile, indent=4)

# Now for implicit properties
with open("originalAssets/MasterPropertyList.asset", "r") as yamlFile:
    data = yaml.safe_load(yamlFile)["MonoBehaviour"]

modList = {}

for affixData in data["propertyInfoList"]:
    modData = {
        "value": affixData["propertyName"],
        "isPercentage": bool(affixData["displayAddedAsPercentage"])
    }
    modList[str(affixData["property"])] = modData

modList = dict(natsorted(modList.items()))

with open("../src/Data/ImplicitModItem.json", "w") as jsonFile:
    json.dump(modList, jsonFile, indent=4)

print("item mods processed with success")
