import yaml
import json


def insert_newlines(string, every=128):
    return '\n'.join(string[i:i + every] for i in range(0, len(string), every))


with open("passiveTreeExtract.yaml", "r") as yamlFile:
    data = yaml.safe_load(yamlFile)

tree = {
    "classes": [
    ],
    "nodes": {
        "root": {
            "out": [],
            "in": []
        }
    }
}


for classInfo in data["trees"].values():
    classId = classInfo["treeID"]
    className = classId

    if classId == 'rg-1':
        className = "Rogue"

    tree["classes"].append({
        "name": className,
        "base_str": 14,
        "base_dex": 14,
        "base_int": 32,
        "ascendancies": []
    })

    tree["nodes"]["root"]["out"].append(classId)

    classStartIndex = len(tree["classes"]) - 1

    posX = 0
    posY = classStartIndex * 1000

    tree["nodes"][classId] = {
        "skill": classId,
        "name": classId,
        "classStartIndex": classStartIndex,
        "x": 0,
        "y": posY,
        "out": [],
        "in": []
    }

    masteryReq = 0

    for node in classInfo["nodeList"]:
        passiveId = node['fileID']
        passiveData = data["passives"][passiveId]

        tree["nodes"][classId]["out"].append(passiveId)

        if masteryReq != passiveData['masteryRequirement']:
            masteryReq = passiveData['masteryRequirement']
            posY = classStartIndex * 1000
            posX += 200
        else:
            posY += 200

        tree["nodes"][passiveId] = {
            "skill": passiveId,
            "name": passiveData["nodeName"],
            "x": posX,
            "y": posY,
            "stats": [],
            "reminderText": [
            #     insert_newlines(str(passiveData))
            ],
            "in": [],
            "out": [],
        }

        if not passiveData["requirements"]:
            tree["nodes"][passiveId]["in"].append(classId)
        else:
            for req in passiveData["requirements"]:
                reqId = req["node"]["fileID"]
                tree["nodes"][passiveId]["in"].append(reqId)

#TODO: Fix all out based on "in" property
for node in tree["nodes"].values():
    for req in node["in"]:
        tree["nodes"][req]["out"].append(node["skill"])

with open("../src/TreeData/1_0/tree.json", "w") as jsonFile:
    json.dump(tree, jsonFile, indent=4)

print("passive tree processed with success")
