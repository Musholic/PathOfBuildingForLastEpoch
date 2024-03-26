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
        for abilityData in classData["unlockableAbilities"]:
            classes[className]["skills"].append(abilityData['ability']['guid'])
        for abilityData in classData["knownAbilities"]:
            classes[className]["skills"].append(abilityData['guid'])
        for masteryData in classData["masteries"]:
            guid = masteryData['masteryAbility'].get('guid')
            if guid:
                classes[className]["skills"].append(guid)
            for abilityData in masteryData["abilities"]:
                classes[className]["skills"].append(abilityData['ability']['guid'])

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
    masteryReq = '0'

    nodeList = []
    for node in classInfo["nodeList"]:
        nodeList.append(data["passives"][node['fileID']])
    nodeList = natsorted(nodeList, key=lambda x: x['mastery']+"_"+x['masteryRequirement'])
    for passiveData in nodeList:
        if maxPosY < posY:
            maxPosY = posY

        if mastery != passiveData['mastery']:
            mastery = passiveData['mastery']
            masteryReq = '0'
            posYMastery = maxPosY + 400
            posY = posYMastery
            posX = 0
        elif masteryReq != passiveData['masteryRequirement']:
            masteryReq = passiveData['masteryRequirement']
            posY = posYMastery
            posX += 200
        else:
            posY += 200

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

    posYStart = -800

    for skillTreeData in skillTreesData['trees'].values():
        posX = 3000
        posYStart += 800
        if skillTreeData["ability"]["guid"] in classes[className]["skills"]:
            nodeList = []
            for node in skillTreeData["nodeList"]:
                nodeList.append(skillTreesData['nodes'][node['fileID']])
            nodeList = natsorted(nodeList, key=lambda x: x['id'])
            for skillData in nodeList:
                posY = posYStart
                posX += 200
                maxPoints = int(skillData['maxPoints'])
                if maxPoints == 0:
                    maxPoints = 1
                for nbPoint in range(maxPoints):
                    skillId = className + "-" + skillTreeData['treeID'] + "-" + skillData['id'] + "-" + str(nbPoint)
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
                                reqPoints = int(req["requirement"])
                                if reqPoints == 0:
                                    reqPoints = 1
                                reqId = (className + "-" + skillTreeData['treeID'] + "-" +
                                         skillTreesData["nodes"][req["node"]["fileID"]]["id"] + "-"
                                         + str(reqPoints - 1))
                                tree["nodes"][skillId]["in"].append(reqId)
                    else:
                        previousSkillId = (className + "-" + skillTreeData['treeID'] + "-" + skillData['id'] + "-"
                                           + str(nbPoint - 1))
                        tree["nodes"][skillId]["in"].append(previousSkillId)

    tree["nodes"] = dict(natsorted(tree["nodes"].items()))
    tree["classes"] = [classes[className]]

    for node in tree["nodes"].values():
        for req in node["in"]:
            tree["nodes"][req]["out"].append(node["skill"])

    with open("../src/TreeData/1_0/tree_" + str(classStartIndex) + ".json", "w") as jsonFile:
        json.dump(tree, jsonFile, indent=4)

print("passive tree processed with success")
