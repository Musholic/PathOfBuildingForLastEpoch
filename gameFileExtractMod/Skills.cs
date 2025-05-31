using System.Text.Json;
using Il2Cpp;
using UnityEngine;

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
            var actors = Resources.FindObjectsOfTypeAll<Actor>();
            ISet<string> minionNames = new HashSet<string>();
            foreach (var skillTree in allSkillTrees)
            {
                var skill = new Skill(skillTree.ability);
                skills.Add(skillTree.treeID, skill);
                if (skill.MinionList != null)
                {
                    foreach (var minion in skill.MinionList)
                    {
                        minionNames.Add(minion);
                    }
                }
            }

            var minions = new SortedDictionary<string, Minion>(Core.StringComparer);
            foreach (var actor in actors)
            {
                if (minionNames.Contains(actor.name))
                {
                    minions[actor.name] = new Minion(actor);
                    foreach (var abilityRef in actor.GetAbilityList().abilityRefs)
                    {
                        var ability = abilityRef.GetAbility();
                        if (ability.abilityName != "")
                        {
                            skills[ability.name] = new Skill(ability);
                        }
                    }
                }
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

            json = JsonSerializer.Serialize(minions, Core.JsonSerializerOptions);
            filePath = Path.Combine(SkillsDir, "minions.json");
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
        public readonly List<string> BaseMods;
        public string AltName;
        public readonly List<string> Buffs;
        public List<string> MinionList;

        public Skill(Ability ability)
        {
            Name = ability.abilityName;
            SkillTypeTags = (int)ability.tags;

            foreach (var attributeScaling in ability.attributeScaling)
            {
                if (attributeScaling.stats.Count > 0)
                {
                    var attribute = attributeScaling.attribute.ToString();
                    var increasedValue = attributeScaling.stats._items[0].increasedValue;
                    foreach (var stat in attributeScaling.stats)
                    {
                        var value = stat.addedValue;
                        var modifierType = BaseStats.ModType.ADDED;
                        if (value == 0)
                        {
                            value = stat.increasedValue;
                            modifierType = BaseStats.ModType.INCREASED;
                        }

                        var modLine = Core.GetModLine(stat.property, stat.tags, value, value, stat.specialTag,
                            modifierType);
                        modLine += " per " + attribute;
                        BaseMods ??= [];
                        BaseMods.Add(modLine);
                    }
                }
            }

            processAbility(ability);

            CastTime = ability.useDuration / (ability.speedMultiplier * 1.1f);
            if (ability.maxCharges > 0)
            {
                if (ability.channelled)
                {
                    CastTime /= ability.chargesGainedPerSecond;
                }
                else
                {
                    Stats["cooldown"] = 1 / ability.chargesGainedPerSecond;
                }
            }
        }

        private void processAbility(Ability ability)
        {
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
            var components = abilityPrefab.GetComponents<MonoBehaviour>();

            // TODO
            var buffParent = ability.abilityPrefab.GetComponent<BuffParent>();
            var damageStatsHolder = ability.abilityPrefab.GetComponent<DamageStatsHolder>();
            if (damageStatsHolder)
            {
                var baseDamageStats = damageStatsHolder.baseDamageStats;
                SetStatsFromDamageData(baseDamageStats, damageStatsHolder.damageTags);
            }

            var summonEntityOnDeath = ability.abilityPrefab.GetComponent<SummonEntityOnDeath>();
            if (summonEntityOnDeath)
            {
                BaseFlags["minion"] = true;
                MinionList ??= [];
                MinionList.Add(summonEntityOnDeath.ActorReference.name);
            }

            var chanceToApplyAilmentsOnHit = ability.abilityPrefab.GetComponent<ChanceToApplyAilmentsOnHit>();
            if (chanceToApplyAilmentsOnHit)
            {
                foreach (var ailmentApplication in chanceToApplyAilmentsOnHit.ailments)
                {
                    var ailmentName = ailmentApplication.ailment.name;
                    Stats["chance_to_cast_Ailment_" + ailmentName + "_on_hit_%"] = ailmentApplication.chance * 100;
                }
            }

            var repeatedlyApplyAilmentsList = ability.abilityPrefab.GetComponents<RepeatedlyApplyAilmentsInRadius>();
            foreach (var repeatedlyApplyAilments in repeatedlyApplyAilmentsList)
            {
                foreach (var ailmentApplication in repeatedlyApplyAilments.ailments)
                {
                    var ailmentName = ailmentApplication.ailment.name;
                    // TODO: probably wrong stat here
                    Stats["chance_to_cast_Ailment_" + ailmentName + "_on_hit_%"] = ailmentApplication.chance * 100;
                }
            }

            var createRandomAbilityObjectOnDeath = abilityPrefab.GetComponent<CreateRandomAbilityObjectOnDeath>();
            if (createRandomAbilityObjectOnDeath)
            {
                foreach (var possibleAbility in createRandomAbilityObjectOnDeath.possibleAbilities)
                {
                    processAbility(possibleAbility);
                }
            }

            var createAbilityObjectOnDeath = abilityPrefab.GetComponent<CreateAbilityObjectOnDeath>();
            if (createAbilityObjectOnDeath)
            {
                processAbility(createAbilityObjectOnDeath.abilityToInstantiateRef.GetAbility());
            }

            var castAfterDuration = ability.abilityPrefab.GetComponent<CastAfterDuration>();
            if (castAfterDuration)
            {
                processAbility(castAfterDuration.abilityRef.GetAbility());
            }

            var castAtRandomPointAfterDuration = ability.abilityPrefab.GetComponent<CastAtRandomPointAfterDuration>();
            if (castAtRandomPointAfterDuration)
            {
                processAbility(castAtRandomPointAfterDuration.abilityRef.GetAbility());
            }


            var destroyAfterDuration = ability.abilityPrefab.GetComponent<DestroyAfterDuration>();
            if (destroyAfterDuration)
            {
                Stats["base_skill_effect_duration"] = destroyAfterDuration.duration * 1000;
            }

            var repeatedlyDamageEnemiesWithinRadius =
                ability.abilityPrefab.GetComponent<RepeatedlyDamageEnemiesWithinRadius>();
            if (repeatedlyDamageEnemiesWithinRadius)
            {
                Stats["damage_interval"] = repeatedlyDamageEnemiesWithinRadius.damageInterval * 1000;
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

            if ((tags & AT.Spell) > 0)
            {
                damageTag = "spell";
                BaseFlags["spell"] = true;
            }

            if ((tags & AT.DoT) > 0)
            {
                damageTag = "dot";
                BaseFlags["dot"] = true;
                // We consider that all dots can stack for simplification (until proven otherwise)
                Stats["dot_can_stack"] = 1;
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
                Stats["base_critical_strike_multiplier_+"] = baseDamageStats.critMultiplier * 100 - 100;
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
                    if (buff.addedValue != 0)
                    {
                        value = buff.addedValue;
                    }

                    if (buff.increasedValue != 0)
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

    public class Minion
    {
        public readonly List<string> SkillList = [];
        public readonly List<string> ModList = [];
        public string Name;
        public string Life;

        public Minion(Actor actor)
        {
            Name = actor.name;
            Life = actor.health.maxHealth.ToString();
            foreach (var abilityRef in actor.GetAbilityList().abilityRefs)
            {
                SkillList.Add(abilityRef.GetAbility().name);
            }
        }
    }
}