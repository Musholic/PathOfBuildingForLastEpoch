import yaml
import json

with open("originalAssets/MasterItemsList.asset", "r") as yamlFile:
    data = yaml.safe_load(yamlFile)["MonoBehaviour"]

itemBases = {
}

for itemData in data["EquippableItems"]:
    for subItemData in itemData["subItems"]:
        subItemName = subItemData["displayName"] or subItemData["name"]
        itemBase = {
            "type": itemData["displayName"],
            "baseTypeID": itemData["baseTypeID"],
            "subTypeID": subItemData["subTypeID"],
            "req": {
                "level": subItemData["levelRequirement"]
            },
            "affixEffectModifier": itemData["affixEffectModifier"],
            "implicits": []
        }
        if itemData["isWeapon"]:
            itemBase["weapon"] = {
                "AttackRateBase": subItemData["attackRate"],
                "Range": 1 + subItemData["addedWeaponRange"],
            }
        for implicit in subItemData["implicits"]:
            itemBase["implicits"].append({
                "property": implicit["property"],
                "min": implicit["implicitValue"],
                "max": implicit["implicitMaxValue"],
            })

        itemBases[subItemName] = itemBase

with open("../src/Data/Bases/bases.json", "w") as jsonFile:
    json.dump(itemBases, jsonFile, indent=4)

print("item bases processed with success")
