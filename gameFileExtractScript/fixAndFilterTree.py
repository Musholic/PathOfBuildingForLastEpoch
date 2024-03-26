from common import *


# Read the YAML file
dataNodes = []
yamlFile = fix_and_filter_yaml_file(prefabPath + "PassiveTree2021.prefab")

with open("generatedAssets/passiveTree.yaml", "w") as yamlOutput:
    yamlOutput.write(yamlFile)

print("passiveTree.yaml generated with success")