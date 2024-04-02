from common import *
import yaml
import json
from natsort import natsorted

with open("generatedAssets/passiveTreeExtract.yaml", "r") as yamlFile:
    data = yaml.safe_load(yamlFile)

with open("generatedAssets/skillTreesExtract.yaml", "r") as yamlFile:
    skillTreesData = yaml.safe_load(yamlFile)

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

    if classId == 'pr-1':
        className = "Primalist"
        classStartIndex = 0
    elif classId == 'mg-1':
        className = "Mage"
        classStartIndex = 1
    elif classId == 'kn-1':
        className = "Sentinel"
        classStartIndex = 2
    elif classId == 'ac-1':
        className = "Acolyte"
        classStartIndex = 3
    else:
        className = "Rogue"
        classStartIndex = 4

    classes[className] = {
        "name": className,
        "ascendancies": []
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
        nodeData['x'] *= 5
        nodeData['y'] *= -15
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

        for nbPoint in range(int(passiveData['maxPoints'])):
            posY += 100
            passiveId = className + "-" + passiveData["id"] + "-" + str(nbPoint)
            tree["nodes"][passiveId] = {
                "skill": passiveId,
                "name": passiveData["nodeName"] + "#" + str(nbPoint + 1),
                "x": posX,
                "y": posY,
                "stats": [],
                "reminderText": [
                ],
                "in": [],
                "out": [],
            }

            for statData in passiveData["stats"]:
                stat = ""
                if statData["value"]:
                    stat = statData["value"] + " "
                stat += statData["statName"]
                tree["nodes"][passiveId]["stats"].append(stat)

            if nbPoint == 0:
                if not passiveData["requirements"]:
                    tree["nodes"][passiveId]["in"].append(className)
                else:
                    for req in passiveData["requirements"]:
                        reqId = className + "-" + data["passives"][req["node"]["fileID"]]["id"] + "-" + str(
                            int(req["requirement"]) - 1)
                        tree["nodes"][passiveId]["in"].append(reqId)
            else:
                previousPassiveId = className + "-" + passiveData["id"] + "-" + str(nbPoint - 1)
                tree["nodes"][passiveId]["in"].append(previousPassiveId)

    minPosX = 0
    minPosY = 0
    for skillTreeData in skillTreesData['trees'].values():
        if skillTreeData["ability"]["guid"] in classes[className]["skillIds"]:
            nodeList = []
            for node in skillTreeData["nodeList"]:
                nodeData = skillTreesData['nodes'][node['fileID']]
                nodeData['x'] *= 5
                nodeData['y'] *= -15
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
                for nbPoint in range(maxPoints):
                    skillId = skillTreeData['treeID'] + "-" + skillData['id'] + "-" + str(nbPoint)
                    posY += 100
                    tree["nodes"][skillId] = {
                        "skill": skillId,
                        "name": skillData["nodeName"] + "#" + str(nbPoint + 1),
                        "x": posX,
                        "y": posY,
                        "stats": [],
                        "reminderText": [
                        ],
                        "in": [],
                        "out": [],
                    }
                    for statData in skillData["stats"]:
                        stat = ""
                        if statData["value"]:
                            stat = statData["value"] + " "
                        stat += statData["statName"]
                        tree["nodes"][skillId]["stats"].append(stat)

                    if nbPoint == 0:
                        if not skillData["requirements"]:
                            tree["nodes"][skillId]["in"].append(className)
                        else:
                            for req in skillData["requirements"]:
                                reqId = (skillTreeData['treeID'] + "-" +
                                         skillTreesData["nodes"][req["node"]["fileID"]]["id"] + "-0")
                                tree["nodes"][skillId]["in"].append(reqId)
                    else:
                        previousSkillId = (skillTreeData['treeID'] + "-" + skillData['id'] + "-"
                                           + str(nbPoint - 1))
                        tree["nodes"][skillId]["in"].append(previousSkillId)

    tree["nodes"] = dict(natsorted(tree["nodes"].items()))
    del classes[className]["skillIds"]
    tree["classes"] = [classes[className]]

    for node in tree["nodes"].values():
        for req in node["in"]:
            tree["nodes"][req]["out"].append(node["skill"])

    with open("../src/TreeData/1_0/tree_" + str(classStartIndex) + ".json", "w") as jsonFile:
        json.dump(tree, jsonFile, indent=4)

print("passive tree processed with success")
