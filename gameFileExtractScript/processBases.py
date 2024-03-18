import yaml
import json

with open("originalAssets/MasterItemsList.asset", "r") as yamlFile:
    data = yaml.safe_load(yamlFile)

itemBases = {
}

for itemData in data["MonoBehaviour"]["EquippableItems"]:
    for subItemData in itemData["subItems"]:
        subItemName = subItemData["displayName"] or subItemData["name"]
        itemBases[subItemName] = {
            "type": itemData["displayName"],
            "baseTypeID": itemData["baseTypeID"],
            "subTypeID": subItemData["subTypeID"],
            "req": {
                "level": subItemData["levelRequirement"]
            }
        }
        if itemData["isWeapon"]:
            itemBases[subItemName]["weapon"] = {
                "AttackRateBase": subItemData["attackRate"],
                "Range": 1 + subItemData["addedWeaponRange"]
            }


with open("../src/Data/Bases/bases.json", "w") as jsonFile:
    json.dump(itemBases, jsonFile, indent=4)

print("item bases processed with success")
