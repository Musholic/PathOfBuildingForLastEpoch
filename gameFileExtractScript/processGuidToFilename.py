from glob import glob
from common import *

metaFileNames = glob(monoPath + "*/*.asset.meta")
metaFileNames += glob(prefabPath + "*.prefab.meta")

guidToFilename = {}

for metaFileName in metaFileNames:
    with open(metaFileName, "r") as yamlFile:
        metaData = yaml.safe_load(yamlFile)
        guidToFilename[metaData['guid']] = metaFileName.replace(".meta", "")

with open("generatedAssets/guidToFilenames.yaml", "w") as output:
    yaml.dump(guidToFilename, output, width=1000)
