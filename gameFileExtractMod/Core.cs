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
        public static readonly string BaseSrcDir =
            @"C:\Users\" + Environment.UserName + @"\IdeaProjects\PathOfBuildingForLastEpoch\src";

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
            var format = ModFormatting.FormatProperty(property, tags,
                specialTag,
                modifierType, minRoll, null, false, false, false, true, isRange,
                maxRoll);
            format = Regex.Replace(format, @"(\d+\.?\d*)(%?) to (\d+\.?\d*)%?", "($1-$3)$2");
            return format;
        }
    }
}