using System.Text.Json;
using System.Text.Json.Serialization;
using Il2Cpp;

// ReSharper disable NotAccessedField.Global
// ReSharper disable MemberCanBePrivate.Global
// ReSharper disable CollectionNeverQueried.Global

namespace PobfleExtractor
{
    public static class Mods
    {
        private static readonly string ModsDir = Core.BaseSrcDir + @"\Data";

        public static void Extract()
        {
            var mods = new SortedDictionary<string, Mod>(Core.StringComparer);
            var affixList = AffixList.instance;
            foreach (var affix in affixList.singleAffixes)
            {
                var i = 0;
                foreach (var affixTier in affix.tiers)
                {
                    mods.Add(affix.affixId + "_" + i, new Mod(affix, affixTier, i));
                    i++;
                }
            }

            foreach (var affix in affixList.multiAffixes)
            {
                var i = 0;
                foreach (var affixTier in affix.tiers)
                {
                    mods.Add(affix.affixId + "_" + i, new Mod(affix, affixTier, i));
                    i++;
                }
            }

            var json = JsonSerializer.Serialize(mods, Core.JsonSerializerOptions);

            var filePath = Path.Combine(ModsDir, "ModItem.json");
            Core.Logger.Msg("Writing file: " + filePath);
            File.WriteAllText(filePath, json);
        }
    }

    public class Mod
    {
        [JsonIgnore(Condition = JsonIgnoreCondition.Never)]
        public string Affix;

        [JsonPropertyName("1")] public string ModLine;
        public int Level;
        public int StatOrderKey;
        public readonly List<int> StatOrder = [];
        public int Tier;
        public string Type;

        public Mod(AffixList.Affix affix, int tier)
        {
            if (affix.affixTitle != "")
            {
                Affix = affix.affixTitle;
            }

            Level = affix.levelRequirement;
            StatOrderKey = affix.affixId;
            StatOrder.Add(affix.affixId);
            Tier = tier;
            switch (affix.type)
            {
                case AffixList.AffixType.PREFIX:
                    Type = "Suffix";
                    break;
                case AffixList.AffixType.SUFFIX:
                    Type = "Prefix";
                    break;
            }
        }

        public Mod(AffixList.SingleAffix affix, AffixList.Tier affixTier, int tier)
            : this(affix, tier)
        {
            ModLine = Core.GetModLine(affix.property, affix.tags, affixTier.minRoll, affixTier.maxRoll,
                affix.specialTag, affix.modifierType);
        }

        public Mod(AffixList.MultiAffix affix, AffixList.Tier affixTier, int tier)
            : this(affix, tier)
        {
            ModLine = "";
            var i = 0;
            foreach (var affixProperty in affix.affixProperties)
            {
                var minRoll = affixTier.minRoll;
                var maxRoll = affixTier.maxRoll;
                if (i > 0)
                {
                    ModLine += "\n";
                    minRoll = affixTier.extraRolls._items[i - 1].minRoll;
                    maxRoll = affixTier.extraRolls._items[i - 1].maxRoll;
                }

                ModLine += Core.GetModLine(affixProperty.property, affixProperty.tags, minRoll,
                    maxRoll, affixProperty.specialTag, affixProperty.modifierType);
                i++;
            }
        }
    }
}