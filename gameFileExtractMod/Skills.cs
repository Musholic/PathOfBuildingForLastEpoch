using System.Text.Json;
using Il2Cpp;
using UnityEngine;
using Object = UnityEngine.Object;

// ReSharper disable NotAccessedField.Global
// ReSharper disable MemberCanBePrivate.Global
// ReSharper disable CollectionNeverQueried.Global

namespace PobfleExtractor
{
    public static class Skills
    {
        private static readonly string SkillsDir = Core.BaseSrcDir + @"\Data";

        public static void Extract()
        {
            var skills = new SortedDictionary<string, Skill>(Core.StringComparer);

            var allSkillTrees = Resources.FindObjectsOfTypeAll<SkillTree>();
            foreach (var skillTree in allSkillTrees)
            {
                skills.Add(skillTree.treeID, new Skill(skillTree.ability));
            }

            var ailmentList = AilmentList.instance.list;
            foreach (var ailment in ailmentList)
            {
                skills.TryAdd("Ailment_" + ailment.name, new Skill(ailment));
            }

            var json = JsonSerializer.Serialize(skills, Core.JsonSerializerOptions);

            var filePath = Path.Combine(SkillsDir, "skills.json");
            Core.Logger.Msg("Writing file: " + filePath);
            File.WriteAllText(filePath, json);
        }
    }

    public class Skill
    {
        public string Name;
        public int SkillTypeTags;
        public float? CastTime;
        public readonly Dictionary<string, bool> BaseFlags = new();
        public readonly Dictionary<string, float> Stats = new();
        public string AltName;
        public readonly List<string> Buffs;

        public Skill(Ability ability)
        {
            Name = ability.abilityName;
            SkillTypeTags = (int)ability.tags;

            foreach (var attributeScaling in ability.attributeScaling)
            {
                if (attributeScaling.stats.Count > 0)
                {
                    var attribute = attributeScaling.attribute switch
                    {
                        CoreAttribute.Attribute.Strength => "str",
                        CoreAttribute.Attribute.Vitality => "vit",
                        CoreAttribute.Attribute.Intelligence => "int",
                        CoreAttribute.Attribute.Dexterity => "dex",
                        CoreAttribute.Attribute.Attunement => "att",
                        _ => null
                    };
                    var increasedValue = attributeScaling.stats._items[0].increasedValue;
                    if (increasedValue > 0)
                    {
                        Stats["damage_+%_per_" + attribute] = increasedValue * 100;
                    }
                }
            }

            if ((ability.tags & AT.Spell) > 0)
            {
                BaseFlags["spell"] = true;
            }

            if ((ability.tags & AT.Melee) > 0)
            {
                BaseFlags["melee"] = true;
                BaseFlags["attack"] = true;
            }

            if ((ability.tags & AT.Throwing) > 0)
            {
                BaseFlags["projectile"] = true;
                BaseFlags["attack"] = true;
            }

            if ((ability.tags & AT.Bow) > 0)
            {
                BaseFlags["projectile"] = true;
                BaseFlags["attack"] = true;
            }

            var abilityPrefab = ability.abilityPrefab;
            var components = abilityPrefab.GetComponents<Object>();
            var damageStatsHolder = ability.abilityPrefab.GetComponent<DamageStatsHolder>();
            if (damageStatsHolder)
            {
                var baseDamageStats = damageStatsHolder.baseDamageStats;
                SetStatsFromDamageData(baseDamageStats, damageStatsHolder.damageTags);
            }

            CastTime = ability.useDuration / (ability.speedMultiplier * 1.1f);
            if (ability.maxCharges > 0)
            {
                if (ability.channelled)
                {
                    CastTime /= ability.chargesGainedPerSecond;
                }
                else
                {
                    Stats.Add("cooldown", 1 / ability.chargesGainedPerSecond);
                }
            }
        }

        private void SetStatsFromDamageData(DamageStatsHolder.BaseDamageStats baseDamageStats, AT tags)
        {
            if (baseDamageStats.addedDamageScaling > 0)
            {
                Stats["damageEffectiveness"] = baseDamageStats.addedDamageScaling;
            }

            if (baseDamageStats.isHit)
            {
                BaseFlags["hit"] = true;
            }

            var damageTag = tags.ToString();
            if ((tags & AT.DoT) > 0)
            {
                damageTag = "dot";
                BaseFlags["dot"] = true;
            }

            if ((tags & AT.Spell) > 0)
            {
                damageTag = "spell";
                BaseFlags["spell"] = true;
            }

            if ((tags & AT.Melee) > 0)
            {
                damageTag = "melee";
                BaseFlags["melee"] = true;
                BaseFlags["attack"] = true;
            }

            if ((tags & AT.Throwing) > 0)
            {
                damageTag = "throwing";
                BaseFlags["projectile"] = true;
                BaseFlags["attack"] = true;
            }

            if ((tags & AT.Bow) > 0)
            {
                damageTag = "bow";
                BaseFlags["projectile"] = true;
                BaseFlags["attack"] = true;
            }

            var i = 0;
            foreach (var damage in baseDamageStats.damage)
            {
                if (damage > 0)
                {
                    var damageType = i switch
                    {
                        0 => "physical",
                        1 => "fire",
                        2 => "cold",
                        3 => "lightning",
                        4 => "necrotic",
                        5 => "void",
                        _ => "poison"
                    };
                    Stats[damageTag + "_base_" + damageType + "_damage"] = damage;
                }

                i++;
            }

            if (baseDamageStats.critMultiplier == 0)
            {
                Stats["no_critical_strike_multiplier"] = 1;
            }
            // ReSharper disable once CompareOfFloatsByEqualityOperator
            else if (baseDamageStats.critMultiplier != 1)
            {
                Stats["base_critical_strike_multiplier"] = baseDamageStats.critMultiplier * 100 - 100;
            }

            if (baseDamageStats.critChance > 0)
            {
                Stats["critChance"] = baseDamageStats.critChance * 100;
            }
        }

        public Skill(Ailment ailment)
        {
            Name = ailment.displayName;
            SkillTypeTags = (int)ailment.tags;
            BaseFlags["duration"] = true;
            BaseFlags["ailment"] = true;
            Stats["base_skill_effect_duration"] = ailment.duration * 1000;
            Stats["maximum_stacks"] = ailment.maxInstances;
            if (ailment.displayName != ailment.instanceName)
            {
                AltName = ailment.instanceName;
            }

            if (ailment.buffs.Count > 0)
            {
                Buffs = [];
                foreach (var buff in ailment.buffs)
                {
                    var value = 0f;
                    var modifierType = BaseStats.ModType.ADDED;
                    if (buff.addedValue > 0)
                    {
                        value = buff.addedValue;
                    }

                    if (buff.increasedValue > 0)
                    {
                        modifierType = BaseStats.ModType.INCREASED;
                        value = buff.increasedValue;
                    }

                    if (buff.moreValues.Count > 0)
                    {
                        modifierType = BaseStats.ModType.MORE;
                        value = buff.moreValues._items[0];
                    }

                    Buffs.Add(Core.GetModLine(buff.property, buff.tags, value, value, buff.specialTag, modifierType));
                }
            }

            SetStatsFromDamageData(ailment.baseDamage, ailment.tags);

            // We consider that all ailments can stack for simplification
            Stats["dot_can_stack"] = 1;
        }
    }
}