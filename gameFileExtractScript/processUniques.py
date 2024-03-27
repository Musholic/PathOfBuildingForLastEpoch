import yaml
import json
from common import *

with open(extractPath + "Resources/UniqueList.asset", "r", encoding='utf-8') as yamlFile:
    data = yaml.safe_load(yamlFile)["MonoBehaviour"]['uniques']

uniques = {
}

for itemData in data:
    subItemName = itemData["displayName"] or itemData["name"]
    itemBase = {
        "name": subItemName,
        "baseTypeID": itemData["baseType"],
        "subTypeID": int(str(itemData["subTypes"]), 16),
        "req": {
            "level": itemData["levelRequirement"]
        },
        "mods": []
    }
    for mod in itemData["mods"]:
        itemBase["mods"].append({
            "property": mod["property"],
            "min": mod["value"],
            "max": mod["maxValue"],
        })

    uniques[itemData["uniqueID"]] = itemBase

with open("../src/Data/Uniques/uniques.json", "w") as jsonFile:
    json.dump(uniques, jsonFile, indent=4)

print("uniques processed with success")
