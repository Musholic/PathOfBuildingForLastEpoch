import json
from common import *


def load_file_from_guid(ability_guid, suffix=None):
    filepath = guidToFilenames[ability_guid['guid']]
    if suffix:
        filepath = filepath.replace(".prefab", suffix + ".prefab")
    return load_yaml_file_with_tag_error(filepath)


with open("generatedAssets/guidToFilenames.yaml", "r", encoding='utf-8') as yamlFile:
    guidToFilenames = yaml.safe_load(yamlFile)

ailmentListData = load_yaml_file_with_tag_error(resourcesPath + "AilmentList.asset")['MonoBehaviour']['list']

ailments = {}

for ailmentGuidData in ailmentListData:
    ailmentData = load_file_from_guid(ailmentGuidData)['MonoBehaviour']
    ailment = {
        "name": ailmentData['displayName'],
        "tags": ailmentData['tags'],
        "stats": [],
        "level": {}
    }
    damageData = ailmentData['baseDamage']
    if float(damageData['addedDamageScaling']) > 0:
        ailment["level"]['damageEffectiveness'] = float(damageData['addedDamageScaling'])
    match int(ailmentData['tags']):
        case val if val & 256:
            damageTag = "spell"
        case val if val & 512:
            damageTag = "melee"
        case val if val & 1024:
            damageTag = "throwing"
        case val if val & 2048:
            damageTag = "bow"
        case val if val & 4096:
            damageTag = "dot"
        case other:
            damageTag = str(other)
    for i, damageStr in enumerate(damageData['damage']):
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
            ailment['stats'].append(damageTag + "_base_" + damageType + "_damage")
            ailment['level'][len(ailment['stats'])] = damage
    ailments[ailmentData['m_Name']] = ailment

ailments = dict(natsorted(ailments.items()))

with open("../src/Data/ailments.json", "w") as jsonFile:
    json.dump(ailments, jsonFile, indent=4)

print("ailments processed with success")
