import json
from common import *


def load_file_from_guid(ability_guid, suffix=None):
    filepath = guidToFilenames[ability_guid['guid']]
    if suffix:
        filepath = filepath.replace(".prefab", suffix + ".prefab")
    return load_yaml_file_with_tag_error(filepath)


with open("generatedAssets/skillTreesExtract.yaml", "r") as yamlFile:
    skillTreesData = yaml.safe_load(yamlFile)['trees'].values()

with open("generatedAssets/guidToFilenames.yaml", "r", encoding='utf-8') as yamlFile:
    guidToFilenames = yaml.safe_load(yamlFile)

skills = {
}

for skillTreeData in skillTreesData:
    skillData = load_file_from_guid(skillTreeData['ability'])["MonoBehaviour"]
    if skillData.get('playerAbilityID'):
        skill = {
            "name": skillData['abilityName'],
            "skillTypeTags": skillData['tags'],
            "castTime": skillData['useDuration'] / (skillData['speedMultiplier'] * 1.1),
            "baseFlags": {},
            "stats": [],
            "level": {}
        }
        for attributeScalingData in skillData['attributeScaling']:
            if len(attributeScalingData['stats']):
                match int(attributeScalingData['attribute']):
                    case 0:
                        attribute = "str"
                    case 1:
                        attribute = "vit"
                    case 2:
                        attribute = "int"
                    case 3:
                        attribute = "dex"
                    case 4:
                        attribute = "att"
                    case other:
                        attribute = str(other)
                stats = attributeScalingData['stats'][0]
                if stats['increasedValue']:
                    skill['stats'].append("damage_+%_per_" + attribute)
                    skill['level'][len(skill['stats'])] = stats['increasedValue'] * 100
                # if stats['addedValue']:
                #     skill['stats'].append("added_damage_per_" + attribute)
                #     skill['level'][len(skill['stats'])] = stats['addedValue']
        for prefabSuffix in {"", "End", "Aoe"}:
            skillPrefabData = load_file_from_guid(skillData['abilityPrefab'], prefabSuffix)
            for data in skillPrefabData:
                if data.get('MonoBehaviour') and data['MonoBehaviour'].get('baseDamageStats'):
                    skillDamageData = data['MonoBehaviour']['baseDamageStats']
                    skill["level"]['damageEffectiveness'] = float(skillDamageData['addedDamageScaling'])
                    if skillDamageData['isHit'] == "1":
                        skill["baseFlags"]["hit"] = True
                    match int(data['MonoBehaviour']['damageTags']):
                        case val if val & 256:
                            damageTag = "spell"
                            skill["baseFlags"]["spell"] = True
                        case val if val & 512:
                            damageTag = "melee"
                            skill["baseFlags"]["melee"] = True
                            skill["baseFlags"]["attack"] = True
                        case val if val & 1024:
                            damageTag = "throwing"
                            skill["baseFlags"]["projectile"] = True
                            skill["baseFlags"]["attack"] = True
                        case val if val & 2048:
                            damageTag = "bow"
                            skill["baseFlags"]["projectile"] = True
                            skill["baseFlags"]["attack"] = True
                        case val if val & 4096:
                            damageTag = "dot"
                        case other:
                            damageTag = str(other)
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
                            skill['stats'].append(damageTag + "_base_" + damageType + "_damage")
                            skill['level'][len(skill['stats'])] = damage
                    critMultiplier = float(skillDamageData['critMultiplier']) * 100 - 100
                    if critMultiplier == -100:
                        skill['stats'].append('no_critical_strike_multiplier')
                    elif critMultiplier:
                        skill['stats'].append('base_critical_strike_multiplier_+')
                        skill["level"][len(skill['stats'])] = critMultiplier
                    critChance = float(skillDamageData['critChance']) * 100
                    if critChance:
                        skill["level"]['critChance'] = critChance
        skills[skillData['playerAbilityID']] = skill
        maxCharges = skillData['maxCharges']
        if maxCharges:
            skill["level"]['cooldown'] = 1 / skillData['chargesGainedPerSecond']


skills = dict(natsorted(skills.items()))

with open("../src/Data/skills.json", "w") as jsonFile:
    json.dump(skills, jsonFile, indent=4)

print("skills processed with success")
