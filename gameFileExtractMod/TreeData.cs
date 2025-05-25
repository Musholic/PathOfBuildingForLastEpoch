using System.Runtime.InteropServices;
using System.Text.Json;
using System.Text.Json.Serialization;
using Il2Cpp;
using UnityEngine;
using Array = System.Array;
using Environment = System.Environment;

// ReSharper disable NotAccessedField.Global
// ReSharper disable MemberCanBePrivate.Global
// ReSharper disable CollectionNeverQueried.Global

namespace PobfleExtractor
{
    public static class TreeData
    {
        private static readonly string TreeDataDir = Core.BaseSrcDir + @"\TreeData\1_1";

        public static void Extract()
        {
            var dirPath = Path.Combine(Environment.CurrentDirectory, "pob_extracts");
            Directory.CreateDirectory(dirPath);

            IList<CharacterTree> characterTrees = Resources.FindObjectsOfTypeAll<CharacterTree>();
            foreach (var characterTree in characterTrees)
            {
                var passiveTreeNodes = new PassiveTreeNodes(characterTree);
                var json = JsonSerializer.Serialize(passiveTreeNodes, Core.JsonSerializerOptions);

                var filePath = Path.Combine(TreeDataDir,
                    "tree_" + (byte)characterTree.characterClass.classID + ".json");
                Core.Logger.Msg("Writing file: " + filePath);
                File.WriteAllText(filePath, json);
            }
        }
    }

    public class PassiveTreeNodes
    {
        public readonly SortedDictionary<string, PassiveTreeNode> Nodes = new(Core.StringComparer);
        public readonly List<PassiveTreeClass> Classes = [];

        public PassiveTreeNodes(CharacterTree characterTree)
        {
            var banners = Resources.FindObjectsOfTypeAll<MasteryBanner>();
            var characterClass = characterTree.characterClass;
            var banner = Array.Find<MasteryBanner>(banners, banner => banner.characterClass == characterClass);
            var className = characterClass.className;

            var allSkillTrees = Resources.FindObjectsOfTypeAll<SkillTree>();
            var skillTrees = Array.FindAll<SkillTree>(allSkillTrees, s => HasAbility(characterClass, s.ability));

            Classes.Add(new PassiveTreeClass(characterClass, skillTrees));

            var index = 0;
            foreach (var masteryButton in banner.masteryButtons)
            {
                var mastery = characterClass.masteries[index];
                Nodes[mastery.LocalizedName] = new PassiveTreeNode(masteryButton, mastery, characterClass);
                index++;
            }


            var minPosY = 0f;
            foreach (var node in characterTree.nodeList)
            {
                var skill = className + "-" + node.id;
                Nodes[skill] = new PassiveTreeNode(skill, node);
                if (Nodes[skill].Y > minPosY)
                {
                    minPosY = Nodes[skill].Y;
                }
            }

            var maxPosX = 0f;
            var maxPosY = 0f;
            var masteryIndex = 0;
            var posYMastery = 0f;
            foreach (var node in characterTree.nodeList._items.OrderBy(n => n.id + 1000 * n.mastery))
            {
                var skill = className + "-" + node.id;

                if (masteryIndex != node.mastery)
                {
                    masteryIndex = node.mastery;
                    posYMastery = (maxPosY - minPosY) + 1600;
                }

                Nodes[skill].Y += posYMastery;

                if (maxPosX < Nodes[skill].X)
                {
                    maxPosX = Nodes[skill].X;
                }

                if (maxPosY < Nodes[skill].Y)
                {
                    maxPosY = Nodes[skill].Y;
                }
            }

            var minPosX = 0f;
            foreach (var skillTree in skillTrees)
            {
                foreach (var node in skillTree.nodeList)
                {
                    var skill = skillTree.treeID + "-" + node.id;
                    Nodes[skill] = new PassiveTreeNode(skill, node);
                    if (minPosX > Nodes[skill].X)
                    {
                        minPosX = Nodes[skill].X;
                    }
                }
            }

            foreach (var skillTree in skillTrees)
            {
                foreach (var node in skillTree.nodeList)
                {
                    var skill = skillTree.treeID + "-" + node.id;
                    Nodes[skill].X += 2000 + maxPosX - minPosX;
                }
            }

            foreach (var node in characterTree.nodeList)
            {
                var skill = className + "-" + node.id;
                foreach (var req in node.requirements)
                {
                    var reqSkill = className + "-" + req.node.id;
                    Nodes[skill].In.Add(reqSkill);
                    Nodes[skill].ReqPoints.Add(req.requirement);
                    Nodes[reqSkill].Out.Add(skill);
                }

                if (node.requirements.isNullOrEmpty())
                {
                    Nodes[skill].In.Add(className);
                    Nodes[skill].ReqPoints.Add(1);
                    Nodes[className].Out.Add(skill);
                }
            }

            foreach (var skillTree in skillTrees)
            {
                foreach (var node in skillTree.nodeList)
                {
                    var skill = skillTree.treeID + "-" + node.id;
                    foreach (var req in node.requirements)
                    {
                        var reqSkill = skillTree.treeID + "-" + req.node.id;
                        Nodes[skill].In.Add(reqSkill);
                        Nodes[skill].ReqPoints.Add(req.requirement);
                        Nodes[reqSkill].Out.Add(skill);
                    }

                    if (node.requirements.isNullOrEmpty())
                    {
                        Nodes[skill].In.Add(className);
                        Nodes[skill].ReqPoints.Add(1);
                        Nodes[className].Out.Add(skill);
                    }
                }
            }
        }

        private static bool HasAbility(CharacterClass characterClass, Ability ability)
        {
            return characterClass.defaultAbilities.Contains(ability)
                   || characterClass.unlockableAbilities._items.Any(a => a.ability == ability)
                   || characterClass.masteries.Any(m => m.masteryAbility == ability)
                   || characterClass.masteries.Any(m =>
                       m.abilities._items.Any(a => a.ability == ability));
        }
    }

    public class PassiveTreeClass
    {
        public readonly string Name;
        public readonly List<PassiveTreeAscendancy> Ascendancies = [];
        public int Base_str;
        public int Base_dex;
        public int Base_int;
        public int Base_att;
        public int Base_vit;
        public readonly SortedSet<PassiveTreeSkill> Skills = [];

        public PassiveTreeClass(CharacterClass characterClass, SkillTree[] skillTrees)
        {
            Name = characterClass.className;
            Base_str = characterClass.baseStrength;
            Base_dex = characterClass.baseDexterity;
            Base_int = characterClass.baseIntelligence;
            Base_att = characterClass.baseAttunement;
            Base_vit = characterClass.baseVitality;

            foreach (var skillTree in skillTrees)
            {
                Skills.Add(new PassiveTreeSkill(skillTree.ability));
            }

            foreach (var mastery in characterClass.masteries)
            {
                if (mastery.LocalizedName != Name)
                {
                    Ascendancies.Add(new PassiveTreeAscendancy(mastery));
                }
            }
        }
    }

    public class PassiveTreeSkill : IComparable<PassiveTreeSkill>
    {
        public string Label;
        public readonly string TreeId;

        public PassiveTreeSkill(Ability ability)
        {
            Label = ability.abilityName;
            TreeId = ability.playerAbilityID;
        }

        public int CompareTo(PassiveTreeSkill other)
        {
            if (ReferenceEquals(this, other)) return 0;
            if (other is null) return 1;
            return Core.StringComparer.Compare(TreeId, other.TreeId);
        }
    }

    public class PassiveTreeAscendancy
    {
        public readonly string Id;
        public string Name;

        public PassiveTreeAscendancy(Mastery mastery)
        {
            Id = mastery.LocalizedName;
            Name = Id;
        }
    }

    public class NaturalStringComparer : IComparer<string>
    {
        public int Compare(string x, string y)
        {
            return StrCmpLogicalW(x, y);
        }

        [DllImport("shlwapi.dll", CharSet = CharSet.Unicode)]
        private static extern int StrCmpLogicalW(string psz1, string psz2);
    }

    public class UpperCaseFirstNaturalComparer : IComparer<string>
    {
        private readonly NaturalStringComparer _naturalComparer = new NaturalStringComparer();

        public int Compare(string x, string y)
        {
            if (string.IsNullOrEmpty(x) && string.IsNullOrEmpty(y)) return 0;
            if (string.IsNullOrEmpty(x)) return -1; // Null or empty strings come first (or last, adjust as needed)
            if (string.IsNullOrEmpty(y)) return 1;

            var xStartsWithUpper = char.IsUpper(x[0]);
            var yStartsWithUpper = char.IsUpper(y[0]);

            // If x starts with uppercase and y does not, x comes first
            if (xStartsWithUpper && !yStartsWithUpper)
            {
                return -1;
            }

            // If y starts with uppercase and x does not, y comes first
            if (!xStartsWithUpper && yStartsWithUpper)
            {
                return 1;
            }

            // If both start with the same case (or neither starts with a letter that has case),
            // then fall back to the natural string comparison.
            // This also handles cases where the first char might not be a letter.
            return _naturalComparer.Compare(x, y);
        }
    }

    public class PassiveTreeNode
    {
        public string Skill;
        public string Name;
        public string AscendancyName;
        [JsonInclude] public int? ClassStartIndex;
        [JsonInclude] public float X;
        [JsonInclude] public float Y;
        public bool? IsAscendancyStart;
        public byte? MaxPoints;
        public readonly List<string> Stats;
        public readonly List<string> NotScalingStats;
        public int? NoScalingPointThreshold;
        public readonly SortedSet<string> In = new(Core.StringComparer);
        public readonly List<int> ReqPoints;
        public readonly SortedSet<string> Out = new(Core.StringComparer);
        public List<string> Description;
        public List<string> ReminderText;

        public PassiveTreeNode(string skill, SkillTreeNode node)
        {
            Name = node.nodeName;
            Skill = skill;
            MaxPoints = node.maxPoints;
            Stats = [];
            NotScalingStats = [];
            foreach (var stat in node.stats)
            {
                var statStr = stat.value + " " + stat.statName;
                if (stat.noScaling)
                {
                    NotScalingStats.Add(statStr);
                }
                else
                {
                    Stats.Add(statStr);
                }
            }

            X = node.transform.localPosition.x * 4;
            Y = node.transform.localPosition.y * -4;
            NoScalingPointThreshold = node.noScalingPointThreshold;
            if (node.description != "")
            {
                Description = [node.description];
            }

            if (node.altText != "")
            {
                ReminderText = [node.altText];
            }

            ReqPoints = [];
        }

        public PassiveTreeNode(CharacterClass characterClass)
        {
            Name = characterClass.className;
            Skill = characterClass.className;
            ClassStartIndex = (byte)characterClass.classID;
        }

        public PassiveTreeNode(MasteryButton masteryButton, Mastery mastery, CharacterClass characterClass)
        {
            Name = mastery.LocalizedName;
            Skill = mastery.LocalizedName;
            if (masteryButton.isMasteryClass)
            {
                AscendancyName = mastery.LocalizedName;
                IsAscendancyStart = true;
                Stats = [];
                foreach (var bonus in masteryButton.passiveBonuses)
                {
                    Stats.Add(bonus);
                }
            }
            else
            {
                ClassStartIndex = (byte)characterClass.classID;
            }
        }
    }
}