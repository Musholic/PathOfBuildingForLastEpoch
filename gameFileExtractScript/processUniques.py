import json
from common import *

construct_mod_data_list()

data = load_yaml_file_with_tag_error(monoPath + "UniqueList/UniqueList.asset")["MonoBehaviour"]['uniques']

uniques = {
}


for itemData in data:
    subItemName = itemData["displayName"] or itemData["name"]
    itemBase = {
        "name": subItemName,
        "baseTypeID": itemData["baseType"],
        "subTypeID": int(str(itemData["subTypes"][0])),
        "req": {
            "level": itemData["levelRequirement"]
        },
        "mods": []
    }
    for mod in itemData["mods"]:
        modValue = get_mod_value(mod)
        itemBase["mods"].append(modValue)

    uniques[itemData["uniqueID"]] = itemBase

with open("../src/Data/Uniques/uniques.json", "w") as jsonFile:
    json.dump(uniques, jsonFile, indent=4)

print("uniques processed with success")
