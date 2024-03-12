import yaml
import json

with open("passiveTreeExtract.yaml", "r") as yamlFile:
    data = yaml.safe_load(yamlFile)

firstTree = next(iter(data["trees"]))
passiveId = data["trees"][firstTree]["nodeList"][0]['fileID']
passiveData = data["passives"][passiveId]

tree = {
    "classes": [
        {
            "name": "Witch",
            "base_str": 14,
            "base_dex": 14,
            "base_int": 32,
            "ascendancies": []
        }
    ],
    "nodes": {}
}
tree["nodes"]["root"] = {
    "out": [1]
}

tree["nodes"][1] = {
    "skill": 1,
    "name": "Witch",
    "classStartIndex": 0,
    "x": 0,
    "y": 0,
    "out": [passiveId]
}

tree["nodes"][passiveId] = {
    "skill": passiveId,
    "name": passiveData["nodeName"],
    "x": 500,
    "y": 500,
    "in": [1],
    "stats": []
}

with open("../src/TreeData/1_0/tree.json", "w") as jsonFile:
    json.dump(tree, jsonFile, indent=4)

print("passive tree processed with success")
