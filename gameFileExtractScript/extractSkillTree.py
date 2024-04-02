import yaml

extractedNodes = {
    "trees": {},
    "nodes": {}
}
transforms = {}
gameObjects = {}
with open("generatedAssets/skillTrees.yaml", "r") as yamlFile:
    for dataNode in yaml.load_all(yamlFile, Loader=yaml.BaseLoader):
        data = dataNode.get('MonoBehaviour')
        if data:
            if data.get('treeID'):
                extractedNodes["trees"][data.get('__fileId')] = data
            if data.get('masteryRequirement'):
                extractedNodes["nodes"][data.get('__fileId')] = data
        data = dataNode.get('RectTransform')
        if data:
            transforms[data.get('__fileId')] = data
        data = dataNode.get('GameObject')
        if data:
            gameObjects[data.get('__fileId')] = data

for nodeData in extractedNodes["nodes"].values():
    goId = nodeData['m_GameObject']['fileID']
    transformId = gameObjects[goId]['m_Component'][0]['component']['fileID']
    nodePosition = transforms[transformId]['m_LocalPosition']
    nodeData['x'] = float(nodePosition['x'])
    nodeData['y'] = float(nodePosition['y'])


with open("generatedAssets/skillTreesExtract.yaml", "w") as output:
    yaml.dump(extractedNodes, output)

print("skill tree extracted with success")
