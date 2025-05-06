using System.Text.Json.Serialization;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.IO;

internal static class Extracter
{
    public static void ExtractAll()
    {
        var options = new JsonSerializerOptions()
        {
            WriteIndented = true,
            ReferenceHandler = ReferenceHandler.IgnoreCycles,
            MaxDepth = 10,
            IncludeFields = true,
            Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        };
        string dirPath = Path.Combine(Environment.CurrentDirectory, "pob_extracts");
        Directory.CreateDirectory(dirPath);


        IList<CharacterTree> characterTrees = UnityEngine.Resources.FindObjectsOfTypeAll<CharacterTree>();
        foreach (var characterTree in characterTrees)
        {
            var passiveTreeNodes = new PassiveTreeNodes(characterTree);
            string json = JsonSerializer.Serialize(passiveTreeNodes, options);

            string filePath = Path.Combine(dirPath, "tree_" + (byte) characterTree.characterClass.classID + ".json");
            File.WriteAllText(filePath, json);
        }
    }
}

internal class PassiveTreeNodes
{
    public Dictionary<string, object> Nodes = new Dictionary<string, object>();

    public PassiveTreeNodes(CharacterTree characterTree)
    {
        MyUtils.InspectOnce(characterTree);
        foreach (var node in characterTree.nodeList)
        {
            string skill = characterTree.characterClass.className + "-" + node.id;
            Nodes[skill] = new PassiveTreeNode(skill, node);
        }
    }
}

internal class PassiveTreeNode
{
    public string Name;
    private string Skill;
    public byte MaxPoints;
    public List<string> Stats = new List<string>();

    public string ReminderText;
    public float X;
    public float Y;

    public PassiveTreeNode(string skill, SkillTreeNode node)
    {
        this.Name = node.nodeName;
        this.Skill = skill;
        this.MaxPoints = node.maxPoints;
        foreach (var stat in node.stats)
        {
            string statStr = stat.value + " " + stat.statName;
            this.Stats.Add(statStr);
        }
        this.X = node.transform.localPosition.x;
        this.Y = node.transform.localPosition.y;
        this.ReminderText = node.altText;
    }
}

internal static class MyUtils
{
    private static int inspect_count = 0;

    public static void InspectOnce(object node)
    {
        if (inspect_count == 0)
        {
            inspect_count++;
            UnityExplorer.InspectorManager.Inspect(node);
        }
    }
    public static void Log(string v)
    {
        UnityExplorer.ExplorerCore.Log(v);
    }
}