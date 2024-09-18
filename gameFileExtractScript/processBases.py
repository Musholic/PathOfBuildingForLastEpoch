import json
from common import *

construct_mod_data_list()

data = load_yaml_file_with_tag_error(monoPath + "ItemList/MasterItemsList.asset")["MonoBehaviour"]

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
            itemBase["implicits"].append(get_mod_value(implicit))

        itemBases[subItemName] = itemBase

with open("../src/Data/Bases/bases.json", "w") as jsonFile:
    json.dump(itemBases, jsonFile, indent=4)

print("item bases processed with success")
