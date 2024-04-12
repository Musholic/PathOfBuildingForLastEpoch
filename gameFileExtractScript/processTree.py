from common import *
import yaml
import json
from natsort import natsorted


def get_tree_mod_value(stat_data):
    value = str(stat_data['value'])
    if not value:
        return stat_data['statName']
    value = float(value.replace("+", "").replace("%", "").replace("#", "")
                  .replace('s', '').replace('x', '').replace('m', '') or 0)
    if "%" in str(stat_data['value']):
        value /= 100
    elif int(value) == value:
        value = int(value)
    stat_data['baseValue'] = stat_data['value']
    stat_data['value'] = value
    if "Increased" in stat_data['statName']:
        stat_data['type'] = 1
    stat_data['tags'] = int(stat_data['tags'])
    for k, v in skillTypes.items():
        if k in stat_data['statName']:
            stat_data['tags'] |= v
    return get_mod_value(stat_data)


with open("generatedAssets/passiveTreeExtract.yaml", "r") as yamlFile:
    data = yaml.safe_load(yamlFile)

with open("generatedAssets/skillTreesExtract.yaml", "r") as yamlFile:
    skillTreesData = yaml.safe_load(yamlFile)

construct_mod_data_list()

masteryClassToMods = {}

for masteryClassData in data["masteryClasses"]:
    key = (masteryClassData['classDescriptionLocalizationKey'].replace("Mastery_", "").replace("_Description", "")
           .replace("Class_", "").replace("MasteryPanel_", ""))
    masteryClassToMods[key] = masteryClassData['passiveBonuses']

for classInfo in data["trees"].values():
    tree = {
        "nodes": {
            "root": {
                "out": [],
                "in": []
            }
        }
    }
    classes = {}
    classId = classInfo["treeID"]
    className = classId
    ascendancies = []

    if classId == 'pr-1':
        className = "Primalist"
        classStartIndex = 0
        ascendancies = [
            {
                "id": "Beastmaster",
                "name": "Beastmaster"
            },
            {
                "id": "Shaman",
                "name": "Shaman"
            },
            {
                "id": "Druid",
                "name": "Druid"
            }
        ]
    elif classId == 'mg-1':
        className = "Mage"
        classStartIndex = 1
        ascendancies = [
            {
                "id": "Sorcerer",
                "name": "Sorcerer"
            },
            {
                "id": "Spellblade",
                "name": "Spellblade"
            },
            {
                "id": "Runemaster",
                "name": "Runemaster"
            }
        ]
    elif classId == 'kn-1':
        className = "Sentinel"
        classStartIndex = 2
        ascendancies = [
            {
                "id": "VoidKnight",
                "name": "Void Knight"
            },
            {
                "id": "Forge_Guard",
                "name": "Forge Guard"
            },
            {
                "id": "Paladin",
                "name": "Paladin"
            }
        ]
    elif classId == 'ac-1':
        className = "Acolyte"
        classStartIndex = 3
        ascendancies = [
            {
                "id": "Necromancer",
                "name": "Necromancer"
            },
            {
                "id": "Lich",
                "name": "Lich"
            },
            {
                "id": "Warlock",
                "name": "Warlock"
            }
        ]
    else:
        className = "Rogue"
        classStartIndex = 4
        ascendancies = [
            {
                "id": "Bladedancer",
                "name": "Bladedancer"
            },
            {
                "id": "Marksman",
                "name": "Marksman"
            },
            {
                "id": "Falconer",
                "name": "Falconer"
            }
        ]

    classes[className] = {
        "name": className,
        "ascendancies": ascendancies
    }

    with open(extractPath + "MonoBehaviour/" + className + ".asset", "r") as yamlFile:
        classData = yaml.safe_load(yamlFile)
        classData = classData["MonoBehaviour"]
        classes[className]["base_str"] = classData["baseStrength"]
        classes[className]["base_dex"] = classData["baseDexterity"]
        classes[className]["base_int"] = classData["baseIntelligence"]
        classes[className]["base_att"] = classData["baseAttunement"]
        classes[className]["base_vit"] = classData["baseVitality"]
        classes[className]["skills"] = []
        classes[className]["skillIds"] = []
        for abilityData in classData["unlockableAbilities"]:
            classes[className]["skillIds"].append(abilityData['ability']['guid'])
        for abilityData in classData["knownAbilities"]:
            classes[className]["skillIds"].append(abilityData['guid'])
        for masteryData in classData["masteries"]:
            guid = masteryData['masteryAbility'].get('guid')
            if guid:
                classes[className]["skillIds"].append(guid)
            for abilityData in masteryData["abilities"]:
                classes[className]["skillIds"].append(abilityData['ability']['guid'])

    tree["nodes"]["root"]["out"].append(className)

    tree["nodes"][className] = {
        "skill": className,
        "name": className,
        "classStartIndex": classStartIndex,
        "x": 0,
        "y": 0,
        "out": [],
        "in": []
    }

    for ascendancy in ascendancies:
        tree["nodes"][ascendancy['id']] = {
            "skill": ascendancy['id'],
            "name": ascendancy['name'],
            "ascendancyName": ascendancy['name'],
            "isAscendancyStart": True,
            "stats": masteryClassToMods[ascendancy['id']],
            "x": 0,
            "y": 0,
            "out": [],
            "in": []
        }

    posX = 0
    posY = 0
    mastery = '0'
    posYMastery = 0
    maxPosY = 0
    maxPosX = 0
    minPosY = 0
    masteryReq = '0'

    nodeList = []
    for node in classInfo["nodeList"]:
        nodeData = data["passives"][node['fileID']]
        nodeData['x'] *= 4
        nodeData['y'] *= -4
        nodeList.append(nodeData)
        if minPosY > nodeData['y']:
            minPosY = nodeData['y']

    nodeList = natsorted(nodeList, key=lambda x: x['mastery'] + "_" + x['masteryRequirement'])
    for passiveData in nodeList:
        if maxPosX < posX:
            maxPosX = posX
        if maxPosY < posY:
            maxPosY = posY

        posX = passiveData['x']
        if mastery != passiveData['mastery']:
            mastery = passiveData['mastery']
            masteryReq = '0'
            posYMastery = (maxPosY - minPosY) + 1600
        elif masteryReq != passiveData['masteryRequirement']:
            masteryReq = passiveData['masteryRequirement']

        posY = posYMastery + passiveData['y']

        maxPoints = int(passiveData['maxPoints'])
        passiveId = className + "-" + passiveData["id"]
        tree["nodes"][passiveId] = {
            "skill": passiveId,
            "name": passiveData["nodeName"],
            "x": posX,
            "y": posY,
            "maxPoints": maxPoints,
            "stats": [],
            "reminderText": [
            ],
            "in": [],
            "reqPoints": [],
            "out": [],
        }

        for statData in passiveData["stats"]:
            stat = ""
            if statData["value"]:
                stat = statData["value"] + " "
            stat += statData["statName"]
            tree["nodes"][passiveId]["stats"].append(stat)
            # tree["nodes"][passiveId]["stats"].append(get_tree_mod_value(statData.copy()))

        if not passiveData["requirements"]:
            tree["nodes"][passiveId]["in"].append(className)
            tree["nodes"][passiveId]["reqPoints"].append(1)
        else:
            for req in passiveData["requirements"]:
                reqId = className + "-" + data["passives"][req["node"]["fileID"]]["id"]
                tree["nodes"][passiveId]["reqPoints"].append(req["requirement"])
                tree["nodes"][passiveId]["in"].append(reqId)

    minPosX = 0
    minPosY = 0
    for skillTreeData in skillTreesData['trees'].values():
        if skillTreeData["ability"]["guid"] in classes[className]["skillIds"]:
            nodeList = []
            for node in skillTreeData["nodeList"]:
                nodeData = skillTreesData['nodes'][node['fileID']]
                nodeData['x'] *= 4
                nodeData['y'] *= -4
                nodeList.append(nodeData)
                if minPosX > nodeData['x']:
                    minPosX = nodeData['x']

            classes[className]["skills"].append({
                "label": nodeList[0]["nodeName"],
                "treeId": skillTreeData['treeID']
            })
            for skillData in nodeList:
                posX = (maxPosX - minPosX) + 2000 + skillData['x']
                posY = skillData['y']
                maxPoints = int(skillData['maxPoints'])
                if maxPoints == 0:
                    maxPoints = 1
                skillId = skillTreeData['treeID'] + "-" + skillData['id']
                tree["nodes"][skillId] = {
                    "skill": skillId,
                    "name": skillData["nodeName"],
                    "x": posX,
                    "y": posY,
                    "maxPoints": maxPoints,
                    "stats": [],
                    "reminderText": [
                    ],
                    "in": [],
                    "reqPoints": [],
                    "out": [],
                }
                for statData in skillData["stats"]:
                    stat = ""
                    if statData["value"]:
                        stat = statData["value"] + " "
                    stat += statData["statName"]
                    tree["nodes"][skillId]["stats"].append(stat)
                    # tree["nodes"][skillId]["stats"].append(get_tree_mod_value(statData.copy()))

                if not skillData["requirements"]:
                    tree["nodes"][skillId]["in"].append(className)
                    tree["nodes"][skillId]["reqPoints"].append(1)
                else:
                    for req in skillData["requirements"]:
                        reqId = (skillTreeData['treeID'] + "-" +
                                 skillTreesData["nodes"][req["node"]["fileID"]]["id"])
                        tree["nodes"][skillId]["reqPoints"].append(req["requirement"])
                        tree["nodes"][skillId]["in"].append(reqId)

    tree["nodes"] = dict(natsorted(tree["nodes"].items()))
    del classes[className]["skillIds"]
    tree["classes"] = [classes[className]]

    for node in tree["nodes"].values():
        for req in node["in"]:
            tree["nodes"][req]["out"].append(node["skill"])

    with open("../src/TreeData/1_0/tree_" + str(classStartIndex) + ".json", "w") as jsonFile:
        json.dump(tree, jsonFile, indent=4)

print("passive tree processed with success")
