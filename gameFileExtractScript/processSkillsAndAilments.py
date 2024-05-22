import json
from common import *

abilityKeyedArray = load_yaml_file_with_tag_error(resourcesPath + "Ability Manager.asset")["MonoBehaviour"][
    "keyedArray"]

keyToGuid = {}

for key in abilityKeyedArray:
    keyToGuid[key["key"]] = key["ability"]
    pass

construct_mod_data_list()


def load_file_from_guid(ability_guid):
    filepath = guidToFilenames[ability_guid['guid']]
    return load_yaml_file_with_tag_error(filepath)


with open("generatedAssets/skillTreesExtract.yaml", "r") as yamlFile:
    skillTreesData = yaml.safe_load(yamlFile)['trees'].values()

with open("generatedAssets/guidToFilenames.yaml", "r", encoding='utf-8') as yamlFile:
    guidToFilenames = yaml.safe_load(yamlFile)

skills = {
}


def process_skill_data(skill_data, skill=None):
    if skill_data.get('playerAbilityID') or skill is not None:
        if skill is None:
            skill = {
                "name": skill_data['abilityName'],
                "skillTypeTags": skill_data['tags'],
                "castTime": skill_data['useDuration'] / (skill_data['speedMultiplier'] * 1.1),
                "baseFlags": {},
                "stats": {}
            }
            skills[skill_data['playerAbilityID']] = skill
            for attributeScalingData in skill_data['attributeScaling']:
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
        match int(skill_data['tags']):
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
                # if stats['addedValue']:
                #     skill['stats'].append("added_damage_per_" + attribute)
                #     skill['level'][len(skill['stats'])] = stats['addedValue']
        skill_prefab_data = load_file_from_guid(skill_data['abilityPrefab'])
        for data in skill_prefab_data:
            if data.get('MonoBehaviour') and data['MonoBehaviour'].get('baseDamageStats'):
                skill_damage_data = data['MonoBehaviour']['baseDamageStats']
                set_stats_from_damage_data(skill, skill_damage_data, data['MonoBehaviour']['damageTags'])
            if data.get('MonoBehaviour') and data['MonoBehaviour'].get('ailments'):
                for ailment_data in data['MonoBehaviour'].get('ailments'):
                    ailment_name = load_file_from_guid(ailment_data['ailment'])['MonoBehaviour']['m_Name']
                    skill['stats']["chance_to_cast_Ailment_" + ailment_name + "_on_hit_%"] = float(
                        ailment_data['chance']) * 100
            if data.get('MonoBehaviour') and data['MonoBehaviour'].get('abilityToInstantiateRef'):
                ref_skill_data = load_file_from_guid(keyToGuid[int(data['MonoBehaviour']['abilityToInstantiateRef']['key'])])["MonoBehaviour"]
                process_skill_data(ref_skill_data, skill)
            if data.get('MonoBehaviour') and data['MonoBehaviour'].get('abilityRef'):
                key = int(data['MonoBehaviour']['abilityRef']['key'])
                if key != 0:
                    ref_skill_data = load_file_from_guid(keyToGuid[key])["MonoBehaviour"]
                    if ref_skill_data != skill_data:
                        process_skill_data(ref_skill_data, skill)
        max_charges = skill_data['maxCharges']
        if max_charges:
            if skill_data['channelled'] == 1:
                skill["castTime"] /= skill_data['chargesGainedPerSecond']
            else:
                skill["stats"]['cooldown'] = 1 / skill_data['chargesGainedPerSecond']


for skillTreeData in skillTreesData:
    skillData = load_file_from_guid(skillTreeData['ability'])["MonoBehaviour"]
    process_skill_data(skillData)

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
