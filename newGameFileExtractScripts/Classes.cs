using System.Text.Json.Serialization;

public class PassiveTreeNodes
{
    [JsonPropertyName("nodes")]
    public Dictionary<string, object> Nodes { get; set; } = new Dictionary<string, object>();
}
