import json
from common import *


def load_file_from_guid(ability_guid):
    return load_yaml_file_with_tag_error(guidToFilenames[ability_guid['guid']])


with open("generatedAssets/skillTreesExtract.yaml", "r") as yamlFile:
    skillTreesData = yaml.safe_load(yamlFile)['trees'].values()

with open("generatedAssets/guidToFilenames.yaml", "r", encoding='utf-8') as yamlFile:
    guidToFilenames = yaml.safe_load(yamlFile)

skills = {
}

for skillTreeData in skillTreesData:
    skillData = load_file_from_guid(skillTreeData['ability'])["MonoBehaviour"]
    if skillData.get('playerAbilityID'):
        skillPrefabData = load_file_from_guid(skillData['abilityPrefab'])
        skill = {
            "name": skillData['abilityName'],
            "skillTypeTags": skillData['tags'],
            "baseFlags": {},
            "stats": [],
            "level": []
        }
        for data in skillPrefabData:
            if data.get('MonoBehaviour') and data['MonoBehaviour'].get('baseDamageStats'):
                skillDamageData = data['MonoBehaviour']['baseDamageStats']
                if skillDamageData['isHit']:
                    skill["baseFlags"]["hit"] = True
                for i, damageStr in enumerate(skillDamageData['damage']):
                    damage = float(damageStr)
                    if damage:
                        match i:
                            case 0:
                                damageType = "physical"
                            case 1:
                                damageType = "fire"
                            case 2:
                                damageType = "cold"
                            case 3:
                                damageType = "lightning"
                            case 4:
                                damageType = "necrotic"
                            case 5:
                                damageType = "void"
                            case _:
                                damageType = "poison"
                        skill['stats'].append("spell_minimum_base_" + damageType + "_damage")
                        skill['stats'].append("spell_maximum_base_" + damageType + "_damage")
                        skill['level'].append(damage)
                        skill['level'].append(damage)
        skills[skillData['playerAbilityID']] = skill


skills = dict(natsorted(skills.items()))

with open("../src/Data/skills.json", "w") as jsonFile:
    json.dump(skills, jsonFile, indent=4)

print("skills processed with success")
