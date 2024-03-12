import yaml

extractedNodes = {
    "trees": {},
    "passives": {}
}
with open("passiveTree.yaml", "r") as yamlFile:
    for dataNode in yaml.load_all(yamlFile, Loader=yaml.BaseLoader):
        data = dataNode.get('MonoBehaviour')
        if data:
            if data.get('treeID'):
                extractedNodes["trees"][data.get('__fileId')] = data
            if data.get('masteryRequirement'):
                extractedNodes["passives"][data.get('__fileId')] = data


with open("passiveTreeExtract.yaml", "w") as output:
    yaml.dump(extractedNodes, output)

print("passive tree extracted with success")
