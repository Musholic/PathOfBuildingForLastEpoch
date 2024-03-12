def fixAndFilterYamlFile(filepath):
    result = str()
    sourceFile = open(filepath, 'r')
    nextId = None
    discard = False

    for lineNumber,line in enumerate( sourceFile.readlines() ):
        if line.startswith('--- !u!'):
            nextId = line.split(' ')[2]   # remove the tag, but keep file ID
            discard = False
        else:
            if not discard:
                if nextId and not line.startswith("MonoBehaviour"):
                    discard = True
                elif nextId:
                    result += "--- " + nextId
                    result += line
                    result += "  __fileId: " + nextId.replace("&", "");
                    nextId = None
                elif not line.endswith("{fileID: 0}\n"):
                    result += line

    sourceFile.close()

    return result


# Read the YAML file
dataNodes = []
yamlFile = fixAndFilterYamlFile("PassiveTree2021.prefab")

with open("passiveTree.yaml", "w") as yamlOutput:
    yamlOutput.write(yamlFile)

print("passiveTree.yaml generated with success")