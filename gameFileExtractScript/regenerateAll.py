import subprocess

filepaths = [
    "fixAndFilterTree.py",
    "extractTree.py",
    "fixAndFilterSkillTree.py",
    "extractSkillTree.py",
    "processGuidToFilename.py",
    "processTree.py",
    "processMods.py",
    "processBases.py",
    "processUniques.py",
    "processSkillsAndAilments.py",
]

for filepath in filepaths:
    print("Running script: " + filepath)
    subprocess.call(["../venv/Scripts/python.exe", filepath])
