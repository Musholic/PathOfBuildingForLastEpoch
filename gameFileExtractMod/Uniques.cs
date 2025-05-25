using System.Text.Json;
using Il2Cpp;

// ReSharper disable NotAccessedField.Global
// ReSharper disable MemberCanBePrivate.Global
// ReSharper disable CollectionNeverQueried.Global

namespace PobfleExtractor
{
    public static class Uniques
    {
        private static readonly string UniquesDir = Core.BaseSrcDir + @"\Data\Uniques";

        public static void Extract()
        {
            var uniqueList = UniqueList.instance;
            var uniques = new Dictionary<string, Unique>();
            foreach (var unique in uniqueList.uniques)
            {
                uniques.Add(unique.uniqueID.ToString(), new Unique(unique));
            }

            var json = JsonSerializer.Serialize(uniques, Core.JsonSerializerOptions);

            var filePath = Path.Combine(UniquesDir, "uniques.json");
            Core.Logger.Msg("Writing file: " + filePath);
            File.WriteAllText(filePath, json);
        }
    }

    public class Unique
    {
        public string Name;
        public int BaseTypeID;
        public int SubTypeID;
        public readonly Dictionary<string, int> Req = new();
        public readonly List<string> Mods = [];

        public Unique(UniqueList.Entry unique)
        {
            Name = unique.name;
            if (unique.displayName != "")
            {
                Name = unique.displayName;
            }

            BaseTypeID = unique.baseType;
            SubTypeID = unique.subTypes._items[0];
            Req.Add("level", unique.levelRequirement);
            foreach (var mod in unique.mods)
            {
                var modMaxValue = mod.maxValue;
                if (!mod.canRoll)
                {
                    modMaxValue = mod.value;
                }

                Mods.Add(Core.GetModLine(mod.property, mod.tags, mod.value, modMaxValue,
                    mod.specialTag, mod.type));
            }
        }
    }
}