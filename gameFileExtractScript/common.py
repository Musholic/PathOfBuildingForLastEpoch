import os
import yaml
import re
from natsort import natsorted

extractPath = os.getenv("LE_EXTRACT_DIR")
prefabPath = extractPath + "PrefabInstance/"
monoPath = extractPath + "MonoBehaviour/"
resourcesPath = extractPath + "Resources/"


def fix_and_filter_yaml_file(filepath, output_file_name):
    source_file = open(filepath, 'r', encoding='utf-8')
    output_file = open(output_file_name, 'w', encoding='utf-8')
    next_id = None
    discard = False

    for lineNumber, line in enumerate(source_file.readlines()):
        if line.startswith('--- !u!'):
            next_id = line.split(' ')[2]  # remove the tag, but keep file ID
            discard = False
        else:
            if not discard:
                if next_id and not (line.startswith("MonoBehaviour") or line.startswith("GameObject")
                                    or line.startswith("RectTransform")):
                    discard = True
                elif next_id:
                    output_file.write("--- " + next_id)
                    output_file.write(line)
                    output_file.write("  __fileId: " + next_id.replace("&", ""))
                    next_id = None
                elif not line.endswith("{fileID: 0}\n") or (line.replace(" ", "").startswith("-")
                                                            and not line.replace(" ", "").startswith("-{fileID:0}")):
                    output_file.write(line)

    source_file.close()
    output_file.close()


def load_yaml_file_with_tag_error(filepath):
    if not os.path.isfile(filepath):
        return {}
    fixed_filepath = filepath + '-fixed.yaml'
    if not os.path.isfile(fixed_filepath):
        fix_and_filter_yaml_file(filepath, fixed_filepath)
    with open(fixed_filepath, "r", encoding='utf-8') as yamlFile:
        if filepath.endswith(".asset"):
            return yaml.safe_load(yamlFile)
        else:
            result = []
            for data in yaml.load_all(yamlFile, Loader=yaml.BaseLoader):
                result.append(data)
            return result


def insert_newlines(string, every=128):
    return '\n'.join(string[i:i + every] for i in range(0, len(string), every))


def get_value_range(mod_data, mod_type):
    min_roll = mod_data.get("value") or mod_data.get("implicitValue") or 0
    if mod_data.get('canRoll') == 0:
        max_roll = min_roll
    else:
        max_roll = mod_data.get("maxValue")
    if max_roll is None:
        max_roll = mod_data.get("implicitMaxValue")
    if max_roll is None:
        max_roll = min_roll
    is_percentage = isinstance(min_roll, float) or isinstance(max_roll, float)
    if is_percentage:
        min_roll = 100 * float(min_roll)
        max_roll = 100 * float(max_roll)

    modifier = ""
    if mod_type == 1:
        if float(min_roll) > 0:
            modifier = " increased"
        else:
            modifier = " reduced"
            min_roll = float(min_roll) * -1
            max_roll = float(max_roll) * -1
    elif mod_type == 2:
        if float(min_roll) > 0:
            modifier = " more"
        else:
            modifier = " less"
            min_roll = float(min_roll) * -1
            max_roll = float(max_roll) * -1

    if round(min_roll, 5).is_integer() and round(max_roll, 5).is_integer():
        min_roll = round(min_roll)
        max_roll = round(max_roll)

    if abs(min_roll) >= abs(max_roll):
        value_range = str(min_roll)
    else:
        value_range = "(" + str(min_roll) + "-" + str(max_roll) + ")"
    if is_percentage or mod_type > 0:
        value_range += "%"

    if not modifier and float(min_roll) > 0:
        value_range = "+" + value_range
    return value_range + modifier


def get_mod_value(mod_data):
    apply_tags = False
    apply_special_tag = False
    mod_key = str(mod_data["property"]) + "_" + str(mod_data.get("specialTag") or 0) + "_" + str(mod_data["tags"])
    if mod_key not in modDataList:
        apply_tags = True
        mod_key = str(mod_data["property"]) + "_" + str(mod_data.get("specialTag") or 0) + "_0"
    if mod_key not in modDataList:
        apply_tags = True
        apply_special_tag = True
        mod_key = str(mod_data["property"]) + "_0_0"
    if mod_key not in modDataList:
        mod_base_data = {
            "name": mod_data.get("statName") or propertiesEnum[mod_data["property"]]
        }
    else:
        mod_base_data = modDataList[mod_key]
    if mod_base_data['name'].lower().startswith("negative ") and mod_data.get('value'):
        mod_data['value'] = mod_data['value'] * -1
        mod_base_data['name'] = mod_base_data['name'][9:]
        pass

    if "modifierType" in mod_data:
        modifier_type = mod_data.get("modifierType")
    elif "type" in mod_data:
        modifier_type = mod_data.get("type")
    else:
        modifier_type = mod_base_data.get("modType") or 0
    value_range = get_value_range(mod_data, modifier_type)
    stat_name = mod_base_data['name']
    if apply_tags or mod_base_data.get('needs_tag_apply'):
        stat_name = add_tags_modifier(stat_name, mod_data["tags"])
    if apply_special_tag or mod_base_data.get('needs_tag_apply'):
        stat_name = add_special_tag_modifier(stat_name, mod_data['specialTag'])
    return value_range + " " + stat_name


skillTypes = {
    "Physical": 1,
    "Lightning": 2,
    "Cold": 4,
    "Fire": 8,
    "Void": 16,
    "Necrotic": 32,
    "Poison": 64,
    "Elemental": 128,
    "Spell": 256,
    "Melee": 512,
    "Throwing": 1024,
    "Bow": 2048,
    "Damage over Time": 4096,
    "Minion": 8192,
    "Totem": 16384,
    "PetResisted": 32768,
    "Potion": 65536,
    "Buff": 131072,
    "Channelling": 262144,
    "Transform": 524288,
    "LowLife": 1048576,
    "HighLife": 2097152,
    "FullLife": 4194304,
    "Hit": 8388608,
    "Curse": 16777216,
    "Ailment": 33554432,
    # Custom addition
    "Companion": 67108864
}
ailmentTags = ["None",
               "Ignite",
               "Bleed",
               "Chill",
               "Possess",
               "Shock",
               "Slow",
               "Poison",
               "ArmourShred",
               "TimeRot",
               "FutureAttack",
               "Laceration",
               "AbyssalDecay",
               "StackingAbyssalDecay",
               "Blind",
               "SerpentVenom",
               "Frailty",
               "MarkedForDeath",
               "Plague",
               "Ravage",
               "Root",
               "Fear",
               "DamageBoost",
               "Frostbite",
               "SpreadingFlames",
               "FireballStackForExplosion",
               "VoidEssence",
               "HolyAuraStackForFlamBurst",
               "PoisonResShred",
               "NecroticResShred",
               "VoidResShred",
               "Stagger",
               "DivineEssence",
               "Haste",
               "Frenzy",
               "Swiftness",
               "PoisonStackForExplosion",
               "AvalancheStackForFissure",
               "TempestsMight",
               "Damned",
               "Pestilence",
               "DisintegrateStackForExplosion",
               "FireResShred",
               "MeleeDefShred",
               "Stalwart",
               "Inspiration",
               "DummyHealingWhileNotTakingDamage",
               "Deadly",
               "AspectOfTheBoarVisuals",
               "AspectOfTheSharkVisuals",
               "StackingAspectOfTheSharkVisuals",
               "AspectOfTheViperVisuals",
               "AspectOfTheLynxVisuals",
               "ArcaneMark",
               "Immobilized",
               "SparkCharge",
               "CriticalEffluence",
               "ArcaneAscendance",
               "BoneCurse",
               "SpiritPlague",
               "ShrineHaste",
               "Contempt",
               "ShrineReflect",
               "ShrineStun",
               "ShrineCrit",
               "ShrineManatee",
               "Shapeshifter",
               "Ferocity",
               "DoomBrand",
               "NecroticBoneCurse",
               "Apocalypse",
               "Flurry1Tag",
               "Flurry2Tag",
               "PhysicalResShred",
               "ColdResShred",
               "LightningResShred",
               "Enrage",
               "LightningInfusion",
               "EfficaciousToxin",
               "ShadowDaggers",
               "MirageForm",
               "SilverShroud",
               "DuskShroud",
               "CrimsonShroud",
               "SmokeBlades",
               "CriticalVulnerability",
               "Sharpshooter",
               "ShrineExperienceBuff",
               "AspectOfTheCrow",
               "AncientFlight",
               "Doom",
               "MoltenInfusion",
               "StoneStare",
               "Electrify",
               "TotemArmor",
               "SciurineRage",
               "Darkness",
               "CorruptedHeraldry",
               "MimicFeast",
               "VoidBarrierVisuals",
               "Immunity",
               "SnakeInfection",
               "AmbushBuff",
               "AspectOfTheSpider",
               "TempestPaws",
               "BrandOfTrespass",
               "BrandOfSubjugation",
               "BrandOfDeception",
               "RunewordCataclysm",
               "RunewordHurricane",
               "RunewordAvalanche",
               "RunewordInferno",
               "UNUSED",
               "Decrepify",
               "SpiritKindling",
               "Withering",
               "Revolution",
               "Penance",
               "Torment",
               "UNUSED2",
               "AcidSkin",
               "Anguish",
               "Witchfire",
               "Chained",
               "TheGate",
               "FalconMark",
               "Netted",
               "TalonBlades",
               "HealingHandsHealOverTime"]

propertiesEnum = ["Damage",
                  "AilmentChance",
                  "AttackSpeed",
                  "CastSpeed",
                  "CriticalChance",
                  "CriticalMultiplier",
                  "DamageTaken",
                  "Health",
                  "Mana",
                  "Movespeed",
                  "Armour",
                  "DodgeRating",
                  "StunAvoidance",
                  "FireResistance",
                  "ColdResistance",
                  "LightningResistance",
                  "WardRetention",
                  "HealthRegen",
                  "ManaRegen",
                  "Strength",
                  "Vitality",
                  "Intelligence",
                  "Dexterity",
                  "Attunement",
                  "ManaBeforeHealthPercent",
                  "ChannelCost",
                  "VoidResistance",
                  "NecroticResistance",
                  "PoisonResistance",
                  "BlockChance",
                  "AllResistances",
                  "DamageTakenAsPhysical",
                  "DamageTakenAsFire",
                  "DamageTakenAsCold",
                  "DamageTakenAsLightning",
                  "DamageTakenAsNecrotic",
                  "DamageTakenAsVoid",
                  "DamageTakenAsPoison",
                  "HealthGain",
                  "WardGain",
                  "ManaGain",
                  "AdaptiveSpellDamage",
                  "IncreasedAilmentDuration",
                  "IncreasedAilmentEffect",
                  "IncreasedHealing",
                  "IncreasedStunChance",
                  "AllAttributes",
                  "IncreasedPotionDropRate",
                  "PotionHealth",
                  "PotionSlots",
                  "HasteOnHitChance",
                  "HealthLeech",
                  "ElementalResistance",
                  "BlockEffectiveness",
                  "None",
                  "IncreasedStunImmunityDuration",
                  "StunImmunity",
                  "ManaDrain",
                  "AbilityProperty",
                  "Penetration",
                  "CurrentHealthDrain",
                  "MaximumCompanions",
                  "GlancingBlowChance",
                  "CullPercentFromPassives",
                  "PhysicalResistance",
                  "CullPercentFromWeapon",
                  "ManaCost",
                  "FreezeRateMultiplier",
                  "IncreasedChanceToBeFrozen",
                  "ManaEfficiency",
                  "IncreasedCooldownRecoverySpeed",
                  "ReceivedStunDuration",
                  "NegativePhysicalResistance",
                  "ChillRetaliationChance",
                  "SlowRetaliationChance",
                  "Endurance",
                  "EnduranceThreshold",
                  "NegativeArmour",
                  "NegativeFireResistance",
                  "NegativeColdResistance",
                  "NegativeLightningResistance",
                  "NegativeVoidResistance",
                  "NegativeNecroticResistance",
                  "NegativePoisonResistance",
                  "NegativeElementalResistance",
                  "Thorns",
                  "PercentReflect",
                  "ShockRetaliationChance",
                  "LevelOfSkills",
                  "CritAvoidance",
                  "PotionHealthConvertedToWard",
                  "WardOnPotionUse",
                  "WardRegen",
                  "OverkillLeech",
                  "ManaBeforeWardPercent",
                  "IncreasedStunDuration",
                  "MaximumHealthGainedAsEnduranceThreshold",
                  "ChanceToGain30WardWhenHit",
                  "PlayerProperty",
                  "ManaSpentGainedAsWard",
                  "AilmentConversion",
                  "PerceivedUnimportanceModifier",
                  "IncreasedLeechRate",
                  "MoreFreezeRatePerStackOfChill",
                  "IncreasedDropRate",
                  "IncreasedExperience",
                  "PhysicalAndVoidResistance",
                  "NecroticAndPoisonResistance",
                  "DamageTakenBuff",
                  "IncreasedChanceToBeStunned",
                  "DamageTakenFromNearbyEnemies",
                  "BlockChanceAgainstDistantEnemies",
                  "ChanceToBeCrit",
                  "DamageTakenWhileMoving",
                  "ReducedBonusDamageTakenFromCrits",
                  "DamagePerStackOfAilment",
                  "IncreasedAreaForAreaSkills",
                  "GlobalConditionalDamage",
                  "ArmourMitigationAppliesToDamageOverTime",
                  "WardDecayThreshold",
                  "EffectOfAilmentOnYou",
                  "ParryChance",
                  "CircleOfFortuneLensEffect"]

for i, property in enumerate(propertiesEnum):
    propertiesEnum[i] = re.sub('(.)([A-Z]+)', r'\1 \2',property)

def add_tags_modifier(stat_name, tags):
    for k, v in skillTypes.items():
        stat_name = add_tag_modifier(stat_name, tags, v, k)
    return stat_name


def add_special_tag_modifier(stat_name, special_tag):
    for ailmentId, v in enumerate(ailmentTags):
        if special_tag == ailmentId:
            stat_name = stat_name.replace("Ailment", v)
    return stat_name


def add_tag_modifier(stat_name, tags, tag_value, tag_name):
    if tags & tag_value and tag_name not in stat_name:
        stat_name = tag_name + " " + stat_name
    return stat_name


modDataList = {}


def construct_mod_data_list():
    global modDataList
    mod_data_list0 = load_yaml_file_with_tag_error(extractPath + "Resources/MasterAffixesList.asset")["MonoBehaviour"]

    affix_keys_data = load_yaml_file_with_tag_error("originalAssets/Item_Affixes Shared Data.asset")["MonoBehaviour"][
        "m_Entries"]

    affix_strings_data = load_yaml_file_with_tag_error("originalAssets/Item_Affixes_en.asset")["MonoBehaviour"][
        "m_TableData"]

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

    property_data_list0 = \
        load_yaml_file_with_tag_error(extractPath + "Resources/MasterPropertyList.asset")["MonoBehaviour"][
            "propertyInfoList"]

    for propertyData in property_data_list0:
        mod_key = str(propertyData["property"]) + "_0_0"
        propertyData["name"] = propertyData["propertyName"]
        if mod_key not in modDataList:
            modDataList[mod_key] = propertyData
        for altText in propertyData["altTextOverrides"]:
            mod_key = str(altText["property"]) + "_" + str(altText["specialTag"]) + "_" + str(altText["tags"])
            if mod_key not in modDataList:
                modDataList[mod_key] = propertyData.copy()
                modDataList[mod_key]["modifierType"] = altText["modType"]
                modDataList[mod_key]["needs_tag_apply"] = True

    player_property_data_list0 = \
        load_yaml_file_with_tag_error(extractPath + "Resources/PlayerPropertyList.asset")["MonoBehaviour"]["list"]

    for idx, propertyData in enumerate(player_property_data_list0):
        mod_key = "98_0_" + str(idx)
        if mod_key not in modDataList:
            modDataList[mod_key] = propertyData
            propertyData["name"] = propertyData["propertyName"]

    player_property_ability_list = \
        load_yaml_file_with_tag_error(extractPath + "Resources/AbilityPropertyList.asset")["MonoBehaviour"]["list"]

    for abilityData in player_property_ability_list:
        for idx, propertyData in enumerate(abilityData['properties']):
            mod_key = "58_" + str(idx) + "_" + str(abilityData['abilityID'])
            modDataList[mod_key] = propertyData
            propertyData["name"] = propertyData["propertyName"]

    modDataList = dict(natsorted(modDataList.items()))


def set_stats_from_damage_data(skill, damage_data, skill_tags):
    damage_effectiveness = float(damage_data['addedDamageScaling'])
    if damage_effectiveness > 0:
        skill['stats']['damageEffectiveness'] = damage_effectiveness
    if damage_data['isHit'] == "1":
        skill["baseFlags"]["hit"] = True
    match int(skill_tags):
        case val if val & 4096:
            damage_tag = "dot"
            skill["baseFlags"]["dot"] = True
        case val if val & 256:
            damage_tag = "spell"
            skill["baseFlags"]["spell"] = True
        case val if val & 512:
            damage_tag = "melee"
            skill["baseFlags"]["melee"] = True
            skill["baseFlags"]["attack"] = True
        case val if val & 1024:
            damage_tag = "throwing"
            skill["baseFlags"]["projectile"] = True
            skill["baseFlags"]["attack"] = True
        case val if val & 2048:
            damage_tag = "bow"
            skill["baseFlags"]["projectile"] = True
            skill["baseFlags"]["attack"] = True
        case other:
            damage_tag = str(other)
    for i, damageStr in enumerate(damage_data['damage']):
        damage = float(damageStr)
        if damage:
            match i:
                case 0:
                    damage_type = "physical"
                case 1:
                    damage_type = "fire"
                case 2:
                    damage_type = "cold"
                case 3:
                    damage_type = "lightning"
                case 4:
                    damage_type = "necrotic"
                case 5:
                    damage_type = "void"
                case _:
                    damage_type = "poison"
            skill['stats'][damage_tag + "_base_" + damage_type + "_damage"] = damage
    crit_multiplier = float(damage_data['critMultiplier']) * 100 - 100
    if crit_multiplier == -100:
        skill['stats']['no_critical_strike_multiplier'] = 1
    elif crit_multiplier:
        skill['stats']['base_critical_strike_multiplier_+'] = crit_multiplier
    crit_chance = float(damage_data['critChance']) * 100
    if crit_chance:
        skill["stats"]['critChance'] = crit_chance
