import json
from common import *

construct_mod_data_list()

skillData = load_yaml_file_with_tag_error(monoPath + "Lunge.asset")["MonoBehaviour"]

skills = {
}

skills[skillData['playerAbilityID']] = {
    "name": skillData['abilityName'],
    "skillTypes": [],
    "baseFlags": [],
    "stats": [],
}

with open("../src/Data/skills.json", "w") as jsonFile:
    json.dump(skills, jsonFile, indent=4)

print("skills processed with success")
