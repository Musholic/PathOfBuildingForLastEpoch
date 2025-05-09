using System.Text.Json.Serialization;
using System.Text.Encodings.Web;
using System.Text.Json;
using Il2Cpp;

namespace PobfleExtractor
{
    public static class Extractor
    {
        public static void ExtractAll()
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
            string dirPath = Path.Combine(Environment.CurrentDirectory, "pob_extracts");
            Directory.CreateDirectory(dirPath);


            IList<CharacterTree> characterTrees = UnityEngine.Resources.FindObjectsOfTypeAll<CharacterTree>();
            foreach (var characterTree in characterTrees)
            {
                var passiveTreeNodes = new PassiveTreeNodes(characterTree);
                string json = JsonSerializer.Serialize(passiveTreeNodes, options);

                string filePath = Path.Combine(dirPath, "tree_" + (byte)characterTree.characterClass.classID + ".json");
                File.WriteAllText(filePath, json);
            }
        }
    }

    public class PassiveTreeNodes
    {
        public Dictionary<string, PassiveTreeNode> Nodes = new Dictionary<string, PassiveTreeNode>();

        public PassiveTreeNodes(CharacterTree characterTree)
        {
            CharacterClass characterClass = characterTree.characterClass;
            string className = characterClass.className;
            Nodes[className] = new PassiveTreeNode(characterClass);
            foreach (var node in characterTree.nodeList._items.OrderBy(n => n.id))
            {
                string skill = className + "-" + node.id;
                Nodes[skill] = new PassiveTreeNode(skill, node);
            }

            foreach (var node in characterTree.nodeList)
            {
                string skill = className + "-" + node.id;
                foreach (var req in node.requirements)
                {
                    string reqSkill = className + "-" + req.node.id;
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

    public class PassiveTreeNode
    {
        public string Skill;
        public string Name;
        public int? classStartIndex;
        public float X = 0;
        public float Y = 0;
        public byte? MaxPoints;
        public List<string> Stats;
        public List<string> NotScalingStats;
        public int? NoScalingPointThreshold;
        public List<string> In = new List<string>();
        public List<int> ReqPoints;
        public List<string> Out = new List<string>();
        public string Description;
        public List<string> ReminderText;

        public PassiveTreeNode(string skill, SkillTreeNode node)
        {
            this.Name = node.nodeName;
            this.Skill = skill;
            this.MaxPoints = node.maxPoints;
            this.Stats = new List<string>();
            this.NotScalingStats = new List<string>();
            foreach (var stat in node.stats)
            {
                string statStr = stat.value + " " + stat.statName;
                if (stat.noScaling)
                {
                    this.NotScalingStats.Add(statStr);
                }
                else
                {
                    this.Stats.Add(statStr);
                }
            }
            this.X = node.transform.localPosition.x * 4;
            this.Y = node.transform.localPosition.y * -4;
            this.NoScalingPointThreshold = node.noScalingPointThreshold;
            if (node.description != "")
            {
                this.Description = node.description;
            }
            if (node.altText != "")
            {
                this.ReminderText = new List<string>() { node.altText };
            }
            this.ReqPoints = new List<int>();
        }

        public PassiveTreeNode(CharacterClass characterClass)
        {
            this.Name = characterClass.className;
            this.Skill = characterClass.className;
            this.classStartIndex = (byte)characterClass.classID;
        }
    }
}
