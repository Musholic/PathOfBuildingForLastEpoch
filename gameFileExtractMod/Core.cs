using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using Il2Cpp;
using MelonLoader;
using PobfleExtractor;
using UnityEngine;

[assembly: MelonInfo(typeof(Core), "PobfleExtractor", "1.0.0", "Musholic", null)]
[assembly: MelonGame("Eleventh Hour Games", "Last Epoch")]

namespace PobfleExtractor
{
    public class Core : MelonMod
    {
        // Change this to another directory if you need to
        public static readonly string BaseSrcDir = Environment.CurrentDirectory + @"\src";

        public static MelonLogger.Instance Logger;
        public static readonly UpperCaseFirstNaturalComparer StringComparer = new();

        public static readonly JsonSerializerOptions JsonSerializerOptions = new()
        {
            WriteIndented = true,
            ReferenceHandler = ReferenceHandler.IgnoreCycles,
            IncludeFields = true,
            Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
        };

        private static int _genId;

        public override void OnInitializeMelon()
        {
            Logger = LoggerInstance;
            Logger.Msg("Initialized.");
        }

        public override void OnUpdate()
        {
            // Use a hot reloadable variable to allow multiple extracts per debugging session
            var targetId = 1;
            if (_genId != targetId && IsReady())
            {
                Logger.Msg("Starting extract...");
                _genId = targetId;
                Skills.Extract();
                Uniques.Extract();
                Mods.Extract();
                TreeData.Extract();
                ItemBases.Extract();
                Application.Quit();
            }
        }

        private static bool IsReady()
        {
            // Wait for the resources to be available
            var trees = Resources.FindObjectsOfTypeAll<CharacterTree>();
            Logger.Msg("Got tree count: " + trees.Length);

            return trees.Length > 0;
        }


        public static string GetModLine(SP property, AT tags, float minRoll, float maxRoll, byte specialTag,
            BaseStats.ModType modifierType)
        {
            // ReSharper disable once CompareOfFloatsByEqualityOperator
            var isRange = minRoll != maxRoll;
            // ReSharper disable once SwitchStatementMissingSomeEnumCasesNoDefault
            switch (property)
            {
                case SP.NegativePhysicalResistance:
                    property = SP.PhysicalResistance;
                    minRoll *= -1;
                    maxRoll *= -1;
                    break;
                case SP.NegativeArmour:
                    property = SP.Armour;
                    minRoll *= -1;
                    maxRoll *= -1;
                    break;
                case SP.NegativeFireResistance:
                    property = SP.FireResistance;
                    minRoll *= -1;
                    maxRoll *= -1;
                    break;
                case SP.NegativeColdResistance:
                    property = SP.ColdResistance;
                    minRoll *= -1;
                    maxRoll *= -1;
                    break;
                case SP.NegativeLightningResistance:
                    property = SP.LightningResistance;
                    minRoll *= -1;
                    maxRoll *= -1;
                    break;
                case SP.NegativeVoidResistance:
                    property = SP.VoidResistance;
                    minRoll *= -1;
                    maxRoll *= -1;
                    break;
                case SP.NegativeNecroticResistance:
                    property = SP.NecroticResistance;
                    minRoll *= -1;
                    maxRoll *= -1;
                    break;
                case SP.NegativePoisonResistance:
                    property = SP.PoisonResistance;
                    minRoll *= -1;
                    maxRoll *= -1;
                    break;
                case SP.NegativeElementalResistance:
                    property = SP.ElementalResistance;
                    minRoll *= -1;
                    maxRoll *= -1;
                    break;
            }

            var format = ModFormatting.FormatProperty(property, tags,
                specialTag,
                modifierType, minRoll, null, false, false, false, true, isRange,
                maxRoll);
            // Fix locale issue using ',' instead of '.'
            format = Regex.Replace(format, @"(\d),(\d)", "$1.$2");
            format = Regex.Replace(format, @"(\d+\.?\d*)(%?) to (\d+\.?\d*)%?", "($1-$3)$2");
            return format;
        }
    }
}