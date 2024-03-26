from common import *


# Read the YAML file
dataNodes = []
fix_and_filter_yaml_file(prefabPath + "Skill Trees.prefab", "generatedAssets/skillTrees.yaml")

print("skillTrees.yaml generated with success")
