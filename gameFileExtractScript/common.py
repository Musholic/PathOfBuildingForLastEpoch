import os
import yaml
import re
from natsort import natsorted

extractPath = os.getenv("LE_EXTRACT_DIR")
prefabPath = extractPath + "PrefabInstance/"
monoPath = extractPath + "MonoBehaviour/"


def fix_and_filter_yaml_file(filepath, output_file_name):
    source_file = open(filepath, 'r')
    output_file = open(output_file_name, 'w')
    next_id = None
    discard = False

    for lineNumber, line in enumerate(source_file.readlines()):
        if line.startswith('--- !u!'):
            next_id = line.split(' ')[2]  # remove the tag, but keep file ID
            discard = False
        else:
            if not discard:
                if next_id and not (line.startswith("MonoBehaviour") or line.startswith("GameObject") or line.startswith("RectTransform")):
                    discard = True
                elif next_id:
                    output_file.write("--- " + next_id)
                    output_file.write(line)
                    output_file.write("  __fileId: " + next_id.replace("&", ""))
                    next_id = None
                elif not line.endswith("{fileID: 0}\n") or line.replace(" ", "").startswith("-"):
                    output_file.write(line)

    source_file.close()
    output_file.close()


def load_yaml_file_with_tag_error(filepath):
    fixed_filepath = filepath + '-fixed.yaml'
    if not os.path.isfile(fixed_filepath):
        fix_and_filter_yaml_file(filepath, fixed_filepath)
    with open(fixed_filepath, "r", encoding='utf-8') as yamlFile:
        return yaml.safe_load(yamlFile)


def insert_newlines(string, every=128):
    return '\n'.join(string[i:i + every] for i in range(0, len(string), every))


def get_value_range(mod_data, is_increased):
    min_roll = mod_data.get("value") or mod_data["implicitValue"]
    max_roll = mod_data.get("maxValue")
    if max_roll is None:
        max_roll = mod_data["implicitMaxValue"]
    is_percentage = isinstance(min_roll, float) or isinstance(max_roll, float)
    if is_percentage:
        min_roll = int(100 * min_roll)
        max_roll = int(100 * max_roll)
    if min_roll >= max_roll:
        value_range = str(min_roll)
    else:
        value_range = "(" + str(min_roll) + "-" + str(max_roll) + ")"
    if is_percentage or is_increased:
        value_range += "%"
    if is_increased:
        value_range += " increased"
    else:
        value_range = "+" + value_range
    return value_range


def get_mod_value(mod_data):
    mod_key = str(mod_data["property"]) + "_" + str(mod_data["specialTag"]) + "_" + str(mod_data["tags"])
    if mod_key not in modDataList:
        mod_key = str(mod_data["property"]) + "_" + str(mod_data["specialTag"]) + "_0"
    if mod_key not in modDataList:
        mod_key = str(mod_data["property"]) + "_0_0"
    mod_base_data = modDataList[mod_key]
    modifier_type = mod_data.get("modifierType")
    if modifier_type is None:
        modifier_type = mod_base_data.get("modifierType") or 0
    value_range = get_value_range(mod_data, modifier_type)
    return value_range + " " + mod_base_data["name"]


modDataList = {}


def construct_mod_data_list():
    global modDataList
    with open(extractPath + "Resources/MasterAffixesList.asset", "r") as yamlFile:
        mod_data_list0 = yaml.safe_load(yamlFile)["MonoBehaviour"]

    with open("originalAssets/Item_Affixes Shared Data.asset", "r") as yamlFile:
        affix_keys_data = yaml.safe_load(yamlFile)["MonoBehaviour"]["m_Entries"]

    with open("originalAssets/Item_Affixes_en.asset", "r") as yamlFile:
        affix_strings_data = yaml.safe_load(yamlFile)["MonoBehaviour"]["m_TableData"]

    affix_strings_by_id = {}
    for affixStringData in affix_strings_data:
        affix_strings_by_id[affixStringData["m_Id"]] = affixStringData["m_Localized"]
    affix_strings = {}
    for affixKeyData in affix_keys_data:
        match = re.search(r'Item_?Affix_(\d+)_Affix_([AB])', affixKeyData["m_Key"])
        if match:
            affix_id = match.group(1)
            affix_ab = match.group(2)
            affix_strings[affix_id + "_" + affix_ab] = affix_strings_by_id[affixKeyData["m_Id"]]

    for mod_data in mod_data_list0["singleAffixes"]:
        modDataList[
            str(mod_data["property"]) + "_" + str(mod_data["specialTag"]) + "_" + str(mod_data["tags"])] = mod_data
        mod_data["name"] = affix_strings[str(mod_data["affixId"]) + "_A"]
    for mod_data in mod_data_list0["multiAffixes"]:
        mod_data0 = mod_data["affixProperties"][0]
        mod_data1 = mod_data["affixProperties"][1]
        modDataList[
            str(mod_data0["property"]) + "_" + str(mod_data0["specialTag"]) + "_" + str(mod_data0["tags"])] = mod_data0
        mod_data0["name"] = affix_strings[str(mod_data["affixId"]) + "_A"]
        modDataList[
            str(mod_data1["property"]) + "_" + str(mod_data1["specialTag"]) + "_" + str(mod_data1["tags"])] = mod_data1
        mod_data1["name"] = affix_strings[str(mod_data["affixId"]) + "_B"]

    with open(extractPath + "Resources/MasterPropertyList.asset", "r") as yamlFile:
        property_data_list0 = yaml.safe_load(yamlFile)["MonoBehaviour"]["propertyInfoList"]

    for propertyData in property_data_list0:
        mod_key = str(propertyData["property"]) + "_0_0"
        if mod_key not in modDataList:
            modDataList[mod_key] = propertyData
            propertyData["name"] = propertyData["propertyName"]
        for altText in propertyData["altTextOverrides"]:
            mod_key = str(altText["property"]) + "_" + str(altText["specialTag"]) + "_" + str(altText["tags"])
            if mod_key not in modDataList:
                modDataList[mod_key] = propertyData
                modDataList[mod_key]["name"] = altText["overrideAltText"]

    with open(extractPath + "Resources/PlayerPropertyList.asset", "r") as yamlFile:
        player_property_data_list0 = yaml.safe_load(yamlFile)["MonoBehaviour"]["list"]

    for idx, propertyData in enumerate(player_property_data_list0):
        mod_key = "98_0_" + str(idx)
        if mod_key not in modDataList:
            modDataList[mod_key] = propertyData
            propertyData["name"] = propertyData["propertyName"]

    modDataList = dict(natsorted(modDataList.items()))
