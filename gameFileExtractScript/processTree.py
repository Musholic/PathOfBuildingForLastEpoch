import yaml
import json


def insert_newlines(string, every=128):
    return '\n'.join(string[i:i + every] for i in range(0, len(string), every))


with open("passiveTreeExtract.yaml", "r") as yamlFile:
    data = yaml.safe_load(yamlFile)

tree = {
    "nodes": {
        "root": {
            "out": [],
            "in": []
        }
    }
}

classes = {}

for classInfo in data["trees"].values():
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
        "base_str": 14,
        "base_dex": 14,
        "base_int": 32,
        "ascendancies": []
    }

    tree["nodes"]["root"]["out"].append(className)

    posX = 0
    posY = classStartIndex * 6000

    tree["nodes"][className] = {
        "skill": className,
        "name": className,
        "classStartIndex": classStartIndex,
        "x": 0,
        "y": posY,
        "out": [],
        "in": []
    }

    masteryReq = 0

    for node in classInfo["nodeList"]:
        passiveData = data["passives"][node['fileID']]

        if masteryReq != passiveData['masteryRequirement']:
            masteryReq = passiveData['masteryRequirement']
            posY = classStartIndex * 6000
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
                    #     insert_newlines(str(passiveData))
                ],
                "in": [],
                "out": [],
            }

            for statData in passiveData["stats"]:
                stat = ""
                if (statData["value"]):
                    stat = statData["value"] + " "
                stat += statData["statName"]
                tree["nodes"][passiveId]["stats"].append(stat)

            if nbPoint == 0:
                if not passiveData["requirements"]:
                    tree["nodes"][passiveId]["in"].append(className)
                else:
                    for req in passiveData["requirements"]:
                        reqId = className + "-" + data["passives"][req["node"]["fileID"]]["id"] + "-" + str(int(req["requirement"]) - 1)
                        tree["nodes"][passiveId]["in"].append(reqId)
            else:
                previousPassiveId = className + "-" + passiveData["id"] + "-" + str(nbPoint - 1)
                tree["nodes"][passiveId]["in"].append(previousPassiveId)

for node in tree["nodes"].values():
    for req in node["in"]:
        tree["nodes"][req]["out"].append(node["skill"])

# Add the classes in the correct order
tree["classes"] = [
    classes["Primalist"],
    classes["Mage"],
    classes["Sentinel"],
    classes["Acolyte"],
    classes["Rogue"],
]

with open("../src/TreeData/1_0/tree.json", "w") as jsonFile:
    json.dump(tree, jsonFile, indent=4)

print("passive tree processed with success")
