var passiveTreeNodes = new PassiveTreeNodes();

Il2CppSystem.Collections.Generic.List<GlobalTreeData.PassiveTreeData> passiveTrees = GlobalTreeData.get().passiveTrees;
foreach (var passiveTree in passiveTrees)
{
    var nodeNames = new List<string>();
    foreach (var node in passiveTree.nodes)
    {
        nodeNames.Add(node.name);
    }
    passiveTreeNodes.Nodes[passiveTree.name] = nodeNames;
}

// Serialize to JSON and write to file
string json = System.Text.Json.JsonSerializer.Serialize(passiveTreeNodes, new System.Text.Json.JsonSerializerOptions { WriteIndented = true });

string dirPath = System.IO.Path.Combine(Environment.CurrentDirectory, "pob_extracts");
System.IO.Directory.CreateDirectory(dirPath);

string filePath = System.IO.Path.Combine(dirPath, "PassiveTreeNodes.json");
System.IO.File.WriteAllText(filePath, json);
