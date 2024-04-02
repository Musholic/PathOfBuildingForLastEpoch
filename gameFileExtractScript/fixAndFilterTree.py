from common import *


# Read the YAML file
dataNodes = []
fix_and_filter_yaml_file(prefabPath + "PassiveTree2021.prefab", "generatedAssets/passiveTree.yaml")

print("passiveTree.yaml generated with success")