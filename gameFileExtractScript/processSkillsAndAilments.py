import json
from common import *

construct_mod_data_list()

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
            "stats": {}
        }
        match int(skillData['tags']):
            case val if val & 256:
                skill["baseFlags"]["spell"] = True
            case val if val & 512:
                skill["baseFlags"]["melee"] = True
                skill["baseFlags"]["attack"] = True
            case val if val & 1024:
                skill["baseFlags"]["projectile"] = True
                skill["baseFlags"]["attack"] = True
            case val if val & 2048:
                skill["baseFlags"]["projectile"] = True
                skill["baseFlags"]["attack"] = True
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
                    skill['stats']["damage_+%_per_" + attribute] = stats['increasedValue'] * 100
                # if stats['addedValue']:
                #     skill['stats'].append("added_damage_per_" + attribute)
                #     skill['level'][len(skill['stats'])] = stats['addedValue']
        for prefabSuffix in {"", "End", "Aoe", "Hit", " Damage"}:
            skillPrefabData = load_file_from_guid(skillData['abilityPrefab'], prefabSuffix)
            for data in skillPrefabData:
                if data.get('MonoBehaviour') and data['MonoBehaviour'].get('baseDamageStats'):
                    skillDamageData = data['MonoBehaviour']['baseDamageStats']
                    set_stats_from_damage_data(skill, skillDamageData, data['MonoBehaviour']['damageTags'])
                if data.get('MonoBehaviour') and data['MonoBehaviour'].get('ailments'):
                    for ailmentData in data['MonoBehaviour'].get('ailments'):
                        ailmentName = load_file_from_guid(ailmentData['ailment'])['MonoBehaviour']['m_Name']
                        skill['stats']["chance_to_cast_Ailment_" + ailmentName + "_on_hit_%"] = float(
                            ailmentData['chance']) * 100

        skills[skillData['playerAbilityID']] = skill
        maxCharges = skillData['maxCharges']
        if maxCharges:
            if skillData['channelled'] == 1:
                skill["castTime"] /= skillData['chargesGainedPerSecond']
            else:
                skill["stats"]['cooldown'] = 1 / skillData['chargesGainedPerSecond']

ailmentListData = load_yaml_file_with_tag_error(resourcesPath + "AilmentList.asset")['MonoBehaviour']['list']

for ailmentGuidData in ailmentListData:
    ailmentData = load_file_from_guid(ailmentGuidData)['MonoBehaviour']
    ailment = {
        "name": ailmentData['displayName'],
        "skillTypeTags": ailmentData['tags'],
        "baseFlags": {
            "duration": True,
            "ailment": True
        },
        "stats": {
            "base_skill_effect_duration": float(ailmentData['duration']) * 1000,
            "maximum_stacks": int(ailmentData['maxInstances']),
        },
    }
    if ailmentData['displayName'] != ailmentData['instanceName']:
        ailment["altName"] = ailmentData['instanceName']
    if ailmentData['buffs']:
        ailment['buffs'] = []
    for buffData in ailmentData['buffs']:
        if buffData['addedValue']:
            buffData['value'] = buffData['addedValue']
        if buffData['increasedValue']:
            buffData['value'] = buffData['increasedValue']
            buffData['modType'] = 1
        if buffData['moreValues']:
            buffData['value'] = buffData['moreValues'][0]
            buffData['modType'] = 2

        ailment['buffs'].append(get_mod_value(buffData))
    set_stats_from_damage_data(ailment, ailmentData['baseDamage'], ailmentData['tags'])
    skills["Ailment_" + ailmentData['m_Name']] = ailment
    # We consider that all ailments can stack for simplification
    ailment['stats']['dot_can_stack'] = 1

skills = dict(natsorted(skills.items()))

with open("../src/Data/skills.json", "w") as jsonFile:
    json.dump(skills, jsonFile, indent=4)

print("skills processed with success")