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
        public float CastTime;
        public readonly Dictionary<string, bool> BaseFlags = new();
        public readonly Dictionary<string, float> Stats = new();

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
                if (baseDamageStats.addedDamageScaling > 0)
                {
                    Stats["damageEffectiveness"] = baseDamageStats.addedDamageScaling;
                }

                if (baseDamageStats.isHit)
                {
                    BaseFlags["hit"] = true;
                }

                var damageTags = damageStatsHolder.damageTags;
                var damageTag = damageTags.ToString();
                if ((damageTags & AT.DoT) > 0)
                {
                    damageTag = "dot";
                    BaseFlags["dot"] = true;
                }

                if ((damageTags & AT.Spell) > 0)
                {
                    damageTag = "spell";
                    BaseFlags["spell"] = true;
                }

                if ((damageTags & AT.Melee) > 0)
                {
                    damageTag = "melee";
                    BaseFlags["melee"] = true;
                    BaseFlags["attack"] = true;
                }

                if ((damageTags & AT.Throwing) > 0)
                {
                    damageTag = "throwing";
                    BaseFlags["projectile"] = true;
                    BaseFlags["attack"] = true;
                }

                if ((damageTags & AT.Bow) > 0)
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
                else
                {
                    Stats["base_critical_strike_multiplier"] = baseDamageStats.critMultiplier * 100 - 100;
                }

                if (baseDamageStats.critChance > 0)
                {
                    Stats["critChance"] = baseDamageStats.critChance * 100;
                }
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
    }
}