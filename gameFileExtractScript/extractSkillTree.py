import yaml

extractedNodes = {
    "trees": {},
    "nodes": {}
}
with open("generatedAssets/skillTrees.yaml", "r") as yamlFile:
    for dataNode in yaml.load_all(yamlFile, Loader=yaml.BaseLoader):
        data = dataNode.get('MonoBehaviour')
        if data:
            if data.get('treeID'):
                extractedNodes["trees"][data.get('__fileId')] = data
            if data.get('masteryRequirement'):
                extractedNodes["nodes"][data.get('__fileId')] = data


with open("generatedAssets/skillTreesExtract.yaml", "w") as output:
    yaml.dump(extractedNodes, output)

print("skill tree extracted with success")
