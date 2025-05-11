using System.Runtime.InteropServices;
using System.Text.Encodings.Web;
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
        private static readonly string TreeDataDir = @"C:\Users\" + Environment.UserName +
                                                     @"\IdeaProjects\PathOfBuildingForLastEpoch\src\TreeData\1_1";

        public static void Extract()
        {
            var options = new JsonSerializerOptions()
            {
                WriteIndented = true,
                ReferenceHandler = ReferenceHandler.IgnoreCycles,
                IncludeFields = true,
                Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
            };
            var dirPath = Path.Combine(Environment.CurrentDirectory, "pob_extracts");
            Directory.CreateDirectory(dirPath);


            IList<CharacterTree> characterTrees = Resources.FindObjectsOfTypeAll<CharacterTree>();
            foreach (var characterTree in characterTrees)
            {
                var passiveTreeNodes = new PassiveTreeNodes(characterTree);
                var json = JsonSerializer.Serialize(passiveTreeNodes, options);

                var filePath = Path.Combine(TreeDataDir,
                    "tree_" + (byte)characterTree.characterClass.classID + ".json");
                Core.Logger.Msg("Writing file: " + filePath);
                File.WriteAllText(filePath, json);
            }
        }
    }

    public class PassiveTreeNodes
    {
        public SortedDictionary<string, PassiveTreeNode> Nodes = new(new NaturalStringComparer());

        public PassiveTreeNodes(CharacterTree characterTree)
        {
            var banners = Resources.FindObjectsOfTypeAll<MasteryBanner>();
            var characterClass = characterTree.characterClass;
            var banner = Array.Find<MasteryBanner>(banners, banner => banner.characterClass == characterClass);
            var className = characterClass.className;

            var index = 0;
            foreach (var masteryButton in banner.masteryButtons)
            {
                var mastery = characterClass.masteries[index];
                Nodes[mastery.LocalizedName] = new PassiveTreeNode(masteryButton, mastery);
                index++;
            }

            foreach (var node in characterTree.nodeList._items.OrderBy(n => n.id))
            {
                var skill = className + "-" + node.id;
                Nodes[skill] = new PassiveTreeNode(skill, node);
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

    public class PassiveTreeNode
    {
        public string AscendancyName;
        [JsonInclude] public int? ClassStartIndex;
        public List<string> Description;
        public SortedSet<string> In = new(new NaturalStringComparer());
        public bool? IsAscendancyStart;
        public byte? MaxPoints;
        public string Name;
        public int? NoScalingPointThreshold;
        public List<string> NotScalingStats;
        public SortedSet<string> Out = new(new NaturalStringComparer());
        public List<string> ReminderText;
        public List<int> ReqPoints;
        public string Skill;
        public List<string> Stats;
        [JsonInclude] public float X;
        [JsonInclude] public float Y;

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

        public PassiveTreeNode(MasteryButton masteryButton, Mastery mastery)
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
        }
    }
}